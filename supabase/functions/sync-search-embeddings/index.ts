declare const Deno: {
  env: { get(name: string): string | undefined };
  serve(handler: (req: Request) => Response | Promise<Response>): void;
};

export {};

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, x-sync-secret',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

type SearchDocument = {
  id: string;
  content: string;
};

type User = {
  id?: string;
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

async function fetchPendingDocuments(
  supabaseUrl: string,
  serviceRoleKey: string,
  limit: number,
  projectId?: string,
) {
  const params = new URLSearchParams({
    select: 'id,content',
    source_table: 'eq.designer_projects',
    is_published: 'eq.true',
    embedding: 'is.null',
    order: 'updated_at.asc',
    limit: String(limit),
  });
  if (projectId) {
    params.set('source_id', `eq.${projectId}`);
    params.set('limit', '1');
  }

  const response = await fetch(
    `${supabaseUrl}/rest/v1/search_documents?${params.toString()}`,
    {
      headers: {
        apikey: serviceRoleKey,
        authorization: `Bearer ${serviceRoleKey}`,
      },
    },
  );

  if (!response.ok) {
    throw new Error(await readError(response));
  }

  return await response.json() as SearchDocument[];
}

async function getCurrentUser(
  supabaseUrl: string,
  anonKey: string,
  authorization: string,
) {
  if (!authorization.startsWith('Bearer ')) return null;

  const response = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: {
      apikey: anonKey,
      authorization,
    },
  });

  if (!response.ok) return null;

  return await response.json() as User;
}

async function assertProjectOwner(
  supabaseUrl: string,
  serviceRoleKey: string,
  projectId: string,
  userId: string,
) {
  const params = new URLSearchParams({
    select: 'id',
    id: `eq.${projectId}`,
    designer_id: `eq.${userId}`,
    limit: '1',
  });

  const response = await fetch(
    `${supabaseUrl}/rest/v1/designer_projects?${params.toString()}`,
    {
      headers: {
        apikey: serviceRoleKey,
        authorization: `Bearer ${serviceRoleKey}`,
      },
    },
  );

  if (!response.ok) {
    throw new Error(await readError(response));
  }

  const rows = await response.json() as Array<{ id?: string }>;
  return rows.length > 0;
}

async function createEmbeddings(openAiKey: string, model: string, inputs: string[]) {
  const response = await fetch('https://api.openai.com/v1/embeddings', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${openAiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ model, input: inputs }),
  });

  if (!response.ok) {
    throw new Error(await readError(response));
  }

  const data = await response.json() as {
    data?: Array<{ index: number; embedding?: number[] }>;
  };

  return (data.data ?? [])
    .sort((a, b) => a.index - b.index)
    .map((item) => item.embedding ?? []);
}

async function updateDocumentEmbedding(
  supabaseUrl: string,
  serviceRoleKey: string,
  id: string,
  embedding: number[],
  model: string,
) {
  const response = await fetch(
    `${supabaseUrl}/rest/v1/search_documents?id=eq.${id}`,
    {
      method: 'PATCH',
      headers: {
        apikey: serviceRoleKey,
        authorization: `Bearer ${serviceRoleKey}`,
        'Content-Type': 'application/json',
        Prefer: 'return=minimal',
      },
      body: JSON.stringify({
        embedding,
        embedding_model: model,
        embedded_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      }),
    },
  );

  if (!response.ok) {
    throw new Error(await readError(response));
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ ok: false, message: 'Method not allowed.' }, 405);
  }

  const supabaseUrl = getEnv('SUPABASE_URL');
  const anonKey = getEnv('SUPABASE_ANON_KEY', 'SB_PUBLISHABLE_KEY');
  const serviceRoleKey = getEnv('SUPABASE_SERVICE_ROLE_KEY', 'SB_SECRET_KEY');
  const openAiKey = getEnv('OPENAI_API_KEY');
  const model = embeddingModel();

  if (!supabaseUrl || !anonKey || !serviceRoleKey || !openAiKey) {
    return jsonResponse(
      { ok: false, message: 'Embedding sync servisi yapilandirilmamis.' },
      503,
    );
  }

  try {
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const syncSecret = getEnv('SEARCH_SYNC_SECRET');
    const hasSyncSecret = Boolean(syncSecret && req.headers.get('x-sync-secret') === syncSecret);
    const projectId =
      typeof body.projectId === 'string' && body.projectId.trim().length > 0
        ? body.projectId.trim()
        : undefined;

    if (!hasSyncSecret) {
      if (!projectId) {
        return jsonResponse({ ok: false, message: 'Yetkisiz istek.' }, 401);
      }

      const user = await getCurrentUser(
        supabaseUrl,
        anonKey,
        req.headers.get('authorization') ?? '',
      );
      if (!user?.id) {
        return jsonResponse({ ok: false, message: 'Oturum gerekli.' }, 401);
      }

      const isOwner = await assertProjectOwner(
        supabaseUrl,
        serviceRoleKey,
        projectId,
        user.id,
      );
      if (!isOwner) {
        return jsonResponse({ ok: false, message: 'Bu proje icin yetkin yok.' }, 403);
      }
    }

    const limit = numberParam(body.limit, 50, 1, 100);
    const documents = await fetchPendingDocuments(
      supabaseUrl,
      serviceRoleKey,
      limit,
      projectId,
    );

    if (documents.length === 0) {
      return jsonResponse({ ok: true, processed: 0, remainingHint: false });
    }

    const embeddings = await createEmbeddings(
      openAiKey,
      model,
      documents.map((document) => document.content),
    );

    let processed = 0;
    for (let i = 0; i < documents.length; i++) {
      const embedding = embeddings[i];
      if (!embedding?.length) continue;
      await updateDocumentEmbedding(
        supabaseUrl,
        serviceRoleKey,
        documents[i].id,
        embedding,
        model,
      );
      processed++;
    }

    return jsonResponse({
      ok: true,
      processed,
      remainingHint: processed === limit,
    });
  } catch (e) {
    return jsonResponse({
      ok: false,
      message: e instanceof Error ? e.message : 'Embedding sync tamamlanamadi.',
    }, 500);
  }
});
