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

async function selectIds(
  supabaseUrl: string,
  serviceRoleKey: string,
  table: string,
  params: Record<string, string>,
) {
  const response = await fetch(restUrl(supabaseUrl, table, { select: 'id', ...params }), {
    headers: serviceHeaders(serviceRoleKey),
  });

  if (!response.ok) {
    const error = await readApiError(response);
    if (isMissingSchema(error)) return [];
    throw new Error(error.message);
  }

  const data = await response.json() as Array<{ id?: string }>;
  return data.map((row) => row.id).filter((id): id is string => Boolean(id));
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

async function listStoragePaths(
  supabaseUrl: string,
  serviceRoleKey: string,
  bucket: string,
  prefix: string,
) {
  const response = await fetch(`${supabaseUrl}/storage/v1/object/list/${bucket}`, {
    method: 'POST',
    headers: serviceHeaders(serviceRoleKey),
    body: JSON.stringify({ prefix, limit: 1000 }),
  });

  if (!response.ok) return [];

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
  await assertOk(response);
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

  try {
    const userId = user.id;

    const [collectionIds, projectIds, conversationIds, blogPostIds, topicIds] =
      await Promise.all([
        selectIds(supabaseUrl, serviceRoleKey, 'collections', {
          user_id: `eq.${userId}`,
        }),
        selectIds(supabaseUrl, serviceRoleKey, 'designer_projects', {
          designer_id: `eq.${userId}`,
        }),
        selectIds(supabaseUrl, serviceRoleKey, 'conversations', {
          or: `(homeowner_id.eq.${userId},designer_id.eq.${userId})`,
        }),
        selectIds(supabaseUrl, serviceRoleKey, 'blog_posts', {
          author_id: `eq.${userId}`,
        }),
        selectIds(supabaseUrl, serviceRoleKey, 'forum_topics', {
          created_by: `eq.${userId}`,
        }),
      ]);

    const projectImagePaths = await listStoragePaths(
      supabaseUrl,
      serviceRoleKey,
      'project-images',
      `projects/${userId}`,
    );
    await Promise.all([
      removeStoragePaths(supabaseUrl, serviceRoleKey, 'project-images', projectImagePaths),
      removeStoragePaths(supabaseUrl, serviceRoleKey, 'avatars', [
        `avatars/${userId}.jpg`,
        `avatars/${userId}.jpeg`,
        `avatars/${userId}.png`,
        `avatars/${userId}.webp`,
      ]),
    ]);

    await deleteRowsByIds(
      supabaseUrl,
      serviceRoleKey,
      'collection_items',
      'collection_id',
      collectionIds,
    );

    if (projectIds.length > 0) {
      await Promise.all([
        deleteRowsByIds(
          supabaseUrl,
          serviceRoleKey,
          'designer_project_shop_links',
          'project_id',
          projectIds,
        ),
        deleteRowsByIds(
          supabaseUrl,
          serviceRoleKey,
          'designer_project_images',
          'project_id',
          projectIds,
        ),
        deleteRowsByIds(
          supabaseUrl,
          serviceRoleKey,
          'collection_items',
          'design_id',
          projectIds,
        ),
      ]);
    }

    if (conversationIds.length > 0) {
      await deleteRowsByIds(
        supabaseUrl,
        serviceRoleKey,
        'messages',
        'conversation_id',
        conversationIds,
      );
    }

    if (blogPostIds.length > 0) {
      await Promise.all([
        deleteRowsByIds(
          supabaseUrl,
          serviceRoleKey,
          'blog_post_likes',
          'post_id',
          blogPostIds,
        ),
        deleteRowsByIds(
          supabaseUrl,
          serviceRoleKey,
          'blog_post_comments',
          'post_id',
          blogPostIds,
        ),
      ]);
    }

    if (topicIds.length > 0) {
      await Promise.all([
        deleteRowsByIds(supabaseUrl, serviceRoleKey, 'forum_posts', 'topic_id', topicIds),
        deleteRowsByIds(supabaseUrl, serviceRoleKey, 'forum_topics', 'id', topicIds),
      ]);
    }

    await Promise.all([
      deleteRows(supabaseUrl, serviceRoleKey, 'blog_post_likes', {
        user_id: `eq.${userId}`,
      }),
      deleteRows(supabaseUrl, serviceRoleKey, 'blog_post_comments', {
        user_id: `eq.${userId}`,
      }),
      deleteRows(supabaseUrl, serviceRoleKey, 'blog_posts', {
        author_id: `eq.${userId}`,
      }),
      deleteRows(supabaseUrl, serviceRoleKey, 'forum_posts', {
        author_id: `eq.${userId}`,
      }),
      deleteRows(supabaseUrl, serviceRoleKey, 'forum_members', {
        user_id: `eq.${userId}`,
      }),
      deleteRows(supabaseUrl, serviceRoleKey, 'messages', {
        sender_id: `eq.${userId}`,
      }),
      deleteRows(supabaseUrl, serviceRoleKey, 'conversations', {
        or: `(homeowner_id.eq.${userId},designer_id.eq.${userId})`,
      }),
      deleteRows(supabaseUrl, serviceRoleKey, 'designer_reviews', {
        homeowner_id: `eq.${userId}`,
      }),
      deleteRows(supabaseUrl, serviceRoleKey, 'designer_reviews', {
        designer_id: `eq.${userId}`,
      }),
      deleteRows(supabaseUrl, serviceRoleKey, 'collections', {
        user_id: `eq.${userId}`,
      }),
      deleteRows(supabaseUrl, serviceRoleKey, 'blocked_users', {
        blocker_id: `eq.${userId}`,
      }),
      deleteRows(supabaseUrl, serviceRoleKey, 'blocked_users', {
        blocked_user_id: `eq.${userId}`,
      }),
      deleteRows(supabaseUrl, serviceRoleKey, 'content_reports', {
        reporter_id: `eq.${userId}`,
      }),
      deleteRows(supabaseUrl, serviceRoleKey, 'content_reports', {
        content_owner_id: `eq.${userId}`,
      }),
      deleteRows(supabaseUrl, serviceRoleKey, 'user_terms_acceptances', {
        user_id: `eq.${userId}`,
      }),
      deleteRows(supabaseUrl, serviceRoleKey, 'profiles', {
        id: `eq.${userId}`,
      }),
    ]);

    await deleteAuthUser(supabaseUrl, serviceRoleKey, userId);

    return jsonResponse({ ok: true });
  } catch (error) {
    const message =
      error instanceof Error ? error.message : 'Hesap silinemedi.';
    return jsonResponse({ ok: false, message }, 500);
  }
});
