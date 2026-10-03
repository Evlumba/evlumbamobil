const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

type ApiError = {
  status: number;
  code?: string;
  message: string;
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

function serviceHeaders(serviceRoleKey: string) {
  return {
    apikey: serviceRoleKey,
    authorization: `Bearer ${serviceRoleKey}`,
    'Content-Type': 'application/json',
  };
}

async function readApiError(response: Response): Promise<ApiError> {
  const text = await response.text();
  if (!text) {
    return { status: response.status, message: response.statusText };
  }

  try {
    const data = JSON.parse(text) as { code?: string; msg?: string; message?: string };
    return {
      status: response.status,
      code: data.code,
      message: data.message ?? data.msg ?? text,
    };
  } catch (_) {
    return { status: response.status, message: text };
  }
}

function isMissingSchema(error: ApiError) {
  const code = error.code ?? '';
  const message = error.message.toLowerCase();
  return (
    error.status === 404 ||
    code === '42P01' ||
    code === '42703' ||
    code === 'PGRST200' ||
    code === 'PGRST204' ||
    code === 'PGRST205' ||
    message.includes('does not exist') ||
    message.includes('could not find')
  );
}

async function assertOk(response: Response, ignoreMissing = true) {
  if (response.ok) return;
  const error = await readApiError(response);
  if (ignoreMissing && isMissingSchema(error)) return;
  throw new Error(error.message);
}

async function getCurrentUser(
  supabaseUrl: string,
  anonKey: string,
  authorization: string,
) {
  const response = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: {
      apikey: anonKey,
      authorization,
    },
  });

  if (!response.ok) return null;

  const data = await response.json() as { id?: string };
  return data.id ? data : null;
}

function restUrl(supabaseUrl: string, table: string, params: Record<string, string>) {
  const search = new URLSearchParams(params);
  return `${supabaseUrl}/rest/v1/${table}?${search.toString()}`;
}

async function selectColumn(
  supabaseUrl: string,
  serviceRoleKey: string,
  table: string,
  column: string,
  params: Record<string, string>,
) {
  const response = await fetch(restUrl(supabaseUrl, table, { select: column, ...params }), {
    headers: serviceHeaders(serviceRoleKey),
  });

  if (!response.ok) {
    const error = await readApiError(response);
    if (isMissingSchema(error)) return [];
    throw new Error(error.message);
  }

  const data = await response.json() as Array<Record<string, unknown>>;
  return data
    .map((row) => row[column])
    .filter((value): value is string => typeof value === 'string' && value.length > 0);
}

function selectIds(
  supabaseUrl: string,
  serviceRoleKey: string,
  table: string,
  params: Record<string, string>,
) {
  return selectColumn(supabaseUrl, serviceRoleKey, table, 'id', params);
}

async function deleteRows(
  supabaseUrl: string,
  serviceRoleKey: string,
  table: string,
  params: Record<string, string>,
) {
  const response = await fetch(restUrl(supabaseUrl, table, params), {
    method: 'DELETE',
    headers: {
      ...serviceHeaders(serviceRoleKey),
      Prefer: 'return=minimal',
    },
  });
  await assertOk(response);
}

async function deleteRowsByIds(
  supabaseUrl: string,
  serviceRoleKey: string,
  table: string,
  column: string,
  ids: string[],
) {
  if (ids.length === 0) return;
  await deleteRows(supabaseUrl, serviceRoleKey, table, {
    [column]: `in.(${ids.join(',')})`,
  });
}

async function clearColumn(
  supabaseUrl: string,
  serviceRoleKey: string,
  table: string,
  column: string,
  userId: string,
) {
  const response = await fetch(restUrl(supabaseUrl, table, { [column]: `eq.${userId}` }), {
    method: 'PATCH',
    headers: {
      ...serviceHeaders(serviceRoleKey),
      Prefer: 'return=minimal',
    },
    body: JSON.stringify({ [column]: null }),
  });
  await assertOk(response);
}

async function listStoragePaths(
  supabaseUrl: string,
  serviceRoleKey: string,
  bucket: string,
  prefix: string,
  search?: string,
) {
  const response = await fetch(`${supabaseUrl}/storage/v1/object/list/${bucket}`, {
    method: 'POST',
    headers: serviceHeaders(serviceRoleKey),
    body: JSON.stringify({ prefix, limit: 1000, ...(search ? { search } : {}) }),
  });

  if (!response.ok) {
    const error = await readApiError(response);
    throw new Error(`${bucket}: ${error.message}`);
  }

  const data = await response.json() as Array<{ name?: string }>;
  return data
    .map((item) => item.name)
    .filter((name): name is string => Boolean(name) && name !== '.emptyFolderPlaceholder')
    .map((name) => `${prefix}/${name}`);
}

async function removeStoragePaths(
  supabaseUrl: string,
  serviceRoleKey: string,
  bucket: string,
  paths: string[],
) {
  if (paths.length === 0) return;

  const response = await fetch(`${supabaseUrl}/storage/v1/object/${bucket}`, {
    method: 'DELETE',
    headers: serviceHeaders(serviceRoleKey),
    body: JSON.stringify({ prefixes: paths }),
  });

  if (!response.ok) {
    const error = await readApiError(response);
    throw new Error(`${bucket}: ${error.message}`);
  }
}

async function deleteAuthUser(
  supabaseUrl: string,
  serviceRoleKey: string,
  userId: string,
) {
  const response = await fetch(`${supabaseUrl}/auth/v1/admin/users/${userId}`, {
    method: 'DELETE',
    headers: serviceHeaders(serviceRoleKey),
  });
  await assertOk(response, false);
}

class StepError extends Error {
  constructor(readonly step: string, message: string) {
    super(message);
  }
}

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : String(error);
}

async function step(name: string, action: () => Promise<void>) {
  try {
    await action();
  } catch (error) {
    throw new StepError(name, errorMessage(error));
  }
}

// Depolama ve yönetici referansları silmeyi asla durdurmaz; hata loglanıp geçilir.
async function softStep(name: string, action: () => Promise<void>) {
  try {
    await action();
  } catch (error) {
    console.warn(`[delete-account] ${name} atlandı: ${errorMessage(error)}`);
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ ok: false, message: 'Method not allowed.' }, 405);
  }

  const authorization = req.headers.get('authorization') ?? '';
  if (!authorization.startsWith('Bearer ')) {
    return jsonResponse({ ok: false, message: 'Oturum gerekli.' }, 401);
  }

  const supabaseUrl = getEnv('SUPABASE_URL');
  const anonKey = getEnv('SUPABASE_ANON_KEY', 'SB_PUBLISHABLE_KEY');
  const serviceRoleKey = getEnv('SUPABASE_SERVICE_ROLE_KEY', 'SB_SECRET_KEY');

  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return jsonResponse(
      { ok: false, message: 'Hesap silme servisi yapılandırılmamış.' },
      500,
    );
  }

  const user = await getCurrentUser(supabaseUrl, anonKey, authorization);
  if (!user?.id) {
    return jsonResponse({ ok: false, message: 'Oturum doğrulanamadı.' }, 401);
  }

  const userId = user.id;
  const url = supabaseUrl;
  const key = serviceRoleKey;
  const del = (table: string, params: Record<string, string>) =>
    deleteRows(url, key, table, params);
  const delIn = (table: string, column: string, ids: string[]) =>
    deleteRowsByIds(url, key, table, column, ids);
  const byUser = (column: string) => ({ [column]: `eq.${userId}` });
  const ownConversations = {
    or: `(homeowner_id.eq.${userId},designer_id.eq.${userId})`,
  };

  try {
    let collectionIds: string[] = [];
    let projectIds: string[] = [];
    let conversationIds: string[] = [];
    let listingIds: string[] = [];
    let blogPostIds: string[] = [];
    let topicIds: string[] = [];
    let cvPaths: string[] = [];

    await step('collect', async () => {
      collectionIds = await selectIds(url, key, 'collections', byUser('user_id'));
      projectIds = await selectIds(url, key, 'designer_projects', byUser('designer_id'));
      conversationIds = await selectIds(url, key, 'conversations', ownConversations);
      listingIds = await selectIds(url, key, 'listings', byUser('owner_id'));
      blogPostIds = await selectIds(url, key, 'blog_posts', byUser('author_id'));
      topicIds = await selectIds(url, key, 'forum_topics', byUser('created_by'));
      cvPaths = await selectColumn(
        url,
        key,
        'career_job_applications',
        'cv_file_path',
        byUser('applicant_id'),
      );
    });

    await softStep('storage:project-images', async () => {
      const paths = await listStoragePaths(url, key, 'project-images', `projects/${userId}`);
      await removeStoragePaths(url, key, 'project-images', paths);
    });
    await softStep('storage:avatars', async () => {
      const paths = await listStoragePaths(url, key, 'avatars', 'avatars', userId);
      await removeStoragePaths(
        url,
        key,
        'avatars',
        paths.filter((path) => path.startsWith(`avatars/${userId}.`)),
      );
    });
    await softStep('storage:career-cvs', () =>
      removeStoragePaths(url, key, 'career-cvs', cvPaths)
    );

    // Çocuk tablolar önce, profiles ve auth en son; sıralı (FK yarışı yok).
    await step('collection_items', async () => {
      await delIn('collection_items', 'collection_id', collectionIds);
      await delIn('collection_items', 'design_id', projectIds);
    });
    await step('collections', () => del('collections', byUser('user_id')));

    await step('designer_project_children', async () => {
      await delIn('designer_project_shop_links', 'project_id', projectIds);
      await delIn('designer_project_images', 'project_id', projectIds);
      await delIn('designer_reviews', 'project_id', projectIds);
    });
    await step('designer_reviews', async () => {
      await del('designer_reviews', byUser('designer_id'));
      await del('designer_reviews', byUser('homeowner_id'));
    });
    await step('search_documents', async () => {
      await delIn('search_documents', 'source_id', projectIds);
      await del('search_documents', byUser('designer_id'));
    });
    await step('designer_projects', () => del('designer_projects', byUser('designer_id')));

    await step('messages', async () => {
      await delIn('messages', 'conversation_id', conversationIds);
      await del('messages', byUser('sender_id'));
    });
    await step('conversations', () => del('conversations', ownConversations));
    await step('saved_designers', async () => {
      await del('saved_designers', byUser('homeowner_id'));
      await del('saved_designers', byUser('designer_id'));
    });

    await step('listing_children', async () => {
      await delIn('listing_bookmarks', 'listing_id', listingIds);
      await delIn('listing_applications', 'listing_id', listingIds);
      await del('listing_bookmarks', byUser('user_id'));
      await del('listing_applications', byUser('applicant_id'));
    });
    await step('listings', () => del('listings', byUser('owner_id')));

    await step('blog', async () => {
      await delIn('blog_post_likes', 'post_id', blogPostIds);
      await delIn('blog_post_comments', 'post_id', blogPostIds);
      await del('blog_post_likes', byUser('user_id'));
      await del('blog_post_comments', byUser('user_id'));
      await del('blog_posts', byUser('author_id'));
    });

    await step('forum', async () => {
      await delIn('forum_posts', 'topic_id', topicIds);
      await delIn('forum_topics', 'id', topicIds);
      await del('forum_posts', byUser('author_id'));
      await del('forum_members', byUser('user_id'));
    });

    await step('blocked_users', async () => {
      await del('blocked_users', byUser('blocker_id'));
      await del('blocked_users', byUser('blocked_user_id'));
    });
    await step('content_reports', async () => {
      await del('content_reports', byUser('reporter_id'));
      await del('content_reports', byUser('content_owner_id'));
    });
    await step('user_terms_acceptances', () => del('user_terms_acceptances', byUser('user_id')));
    await step('push_tokens', () => del('push_tokens', byUser('user_id')));
    await step('career_job_applications', () =>
      del('career_job_applications', byUser('applicant_id'))
    );
    await step('designer_verification_requests', () =>
      del('designer_verification_requests', byUser('user_id'))
    );

    const adminReferences: Array<[string, string]> = [
      ['designer_verification_requests', 'reviewed_by'],
      ['content_reports', 'reviewer_id'],
      ['career_job_posts', 'created_by'],
      ['popup_banners', 'created_by'],
      ['onboarding_flows', 'created_by'],
      ['user_moderation_states', 'updated_by'],
    ];
    for (const [table, column] of adminReferences) {
      await softStep(`detach:${table}.${column}`, () =>
        clearColumn(url, key, table, column, userId)
      );
    }
    await step('admin_users', () => del('admin_users', byUser('user_id')));

    await step('user_moderation_states', () => del('user_moderation_states', byUser('user_id')));
    await step('profiles', () => del('profiles', byUser('id')));
    await step('auth', () => deleteAuthUser(url, key, userId));

    return jsonResponse({ ok: true });
  } catch (error) {
    const failedStep = error instanceof StepError ? error.step : 'unknown';
    console.error(`[delete-account] ${failedStep} başarısız: ${errorMessage(error)}`);
    return jsonResponse(
      {
        ok: false,
        step: failedStep,
        message:
          'Hesap silinemedi. Lütfen tekrar deneyin; sorun sürerse info@evlumba.com adresine yazın.',
      },
      500,
    );
  }
});
