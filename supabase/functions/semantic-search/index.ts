declare const Deno: {
  env: { get(name: string): string | undefined };
  serve(handler: (req: Request) => Response | Promise<Response>): void;
};

export {};

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

type SearchMode = 'projects' | 'designers';

type MatchRow = {
  project_id: string;
  designer_id: string | null;
  similarity: number;
};

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });
}

function getEnv(name: string, fallbackName?: string) {
  return Deno.env.get(name) ?? (fallbackName ? Deno.env.get(fallbackName) : null);
}

function normalizeQuery(value: unknown) {
  if (typeof value !== 'string') return '';
  return value.replace(/\s+/g, ' ').trim().slice(0, 500);
}

function optionalString(value: unknown) {
  if (typeof value !== 'string') return null;
  const trimmed = value.replace(/\s+/g, ' ').trim();
  return trimmed.length > 0 ? trimmed.slice(0, 120) : null;
}

function normalizeMode(value: unknown): SearchMode {
  return value === 'designers' ? 'designers' : 'projects';
}

function numberParam(value: unknown, fallback: number, min: number, max: number) {
  if (typeof value !== 'number' || !Number.isFinite(value)) return fallback;
  return Math.min(Math.max(Math.round(value), min), max);
}

function embeddingModel() {
  const model = getEnv('OPENAI_EMBEDDING_MODEL') ?? '';
  return model.startsWith('text-embedding-') ? model : 'text-embedding-3-small';
}

async function readError(response: Response) {
  const text = await response.text();
  if (!text) return response.statusText;

  try {
    const data = JSON.parse(text) as { error?: { message?: string }; message?: string };
    return data.error?.message ?? data.message ?? text;
  } catch (_) {
    return text;
  }
}

async function createEmbedding(openAiKey: string, model: string, input: string) {
  const response = await fetch('https://api.openai.com/v1/embeddings', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${openAiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ model, input }),
  });

  if (!response.ok) {
    throw new Error(await readError(response));
  }

  const data = await response.json() as {
    data?: Array<{ embedding?: number[] }>;
  };
  const embedding = data.data?.[0]?.embedding;
  if (!embedding?.length) {
    throw new Error('Embedding yaniti bos geldi.');
  }
  return embedding;
}

async function matchProjects(
  supabaseUrl: string,
  serviceRoleKey: string,
  embedding: number[],
  limit: number,
  projectType: string | null,
  budgetLevel: string | null,
  city: string | null,
) {
  const response = await fetch(
    `${supabaseUrl}/rest/v1/rpc/match_designer_project_documents`,
    {
      method: 'POST',
      headers: {
        apikey: serviceRoleKey,
        authorization: `Bearer ${serviceRoleKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        query_embedding: embedding,
        match_count: limit,
        match_threshold: Number(getEnv('SEARCH_MATCH_THRESHOLD') ?? '0.12'),
        p_project_type: projectType,
        p_budget_level: budgetLevel,
        p_city: city,
      }),
    },
  );

  if (!response.ok) {
    throw new Error(await readError(response));
  }

  return await response.json() as MatchRow[];
}

function aggregateDesignerIds(matches: MatchRow[], limit: number) {
  const scores = new Map<string, number>();

  for (const match of matches) {
    if (!match.designer_id) continue;
    const current = scores.get(match.designer_id) ?? -Infinity;
    if (match.similarity > current) scores.set(match.designer_id, match.similarity);
  }

  return [...scores.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, limit)
    .map(([designerId]) => designerId);
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ ok: false, message: 'Method not allowed.' }, 405);
  }

  const supabaseUrl = getEnv('SUPABASE_URL');
  const serviceRoleKey = getEnv('SUPABASE_SERVICE_ROLE_KEY', 'SB_SECRET_KEY');
  const openAiKey = getEnv('OPENAI_API_KEY');
  const model = embeddingModel();

  if (!supabaseUrl || !serviceRoleKey || !openAiKey) {
    return jsonResponse(
      { ok: false, message: 'Semantic search servisi yapilandirilmamis.' },
      503,
    );
  }

  try {
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const query = normalizeQuery(body.query);
    const mode = normalizeMode(body.mode);
    const limit = numberParam(body.limit, mode === 'designers' ? 80 : 24, 1, 120);
    const projectType = optionalString(body.projectType);
    const budgetLevel = optionalString(body.budgetLevel);
    const city = optionalString(body.city);

    if (query.length < 2) {
      return jsonResponse({
        ok: true,
        mode,
        projectIds: [],
        designerIds: [],
        matches: [],
      });
    }

    const embedding = await createEmbedding(openAiKey, model, query);
    const matchLimit = mode === 'designers' ? Math.min(limit * 6, 200) : limit;
    const matches = await matchProjects(
      supabaseUrl,
      serviceRoleKey,
      embedding,
      matchLimit,
      projectType,
      budgetLevel,
      city,
    );

    return jsonResponse({
      ok: true,
      mode,
      projectIds: matches.map((match) => match.project_id),
      designerIds: aggregateDesignerIds(matches, limit),
      matches: matches.map((match) => ({
        projectId: match.project_id,
        designerId: match.designer_id,
        similarity: match.similarity,
      })),
    });
  } catch (e) {
    return jsonResponse({
      ok: false,
      message: e instanceof Error ? e.message : 'Arama tamamlanamadi.',
    }, 500);
  }
});
