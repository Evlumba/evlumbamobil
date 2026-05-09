declare const Deno: {
  env: { get(name: string): string | undefined };
  serve(handler: (req: Request) => Response | Promise<Response>): void;
};

export {};

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, x-message-notification-secret',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

type MessageRow = {
  id: string;
  conversation_id: string;
  sender_id: string;
  body: string | null;
  created_at?: string;
};

type ConversationRow = {
  id: string;
  homeowner_id: string | null;
  designer_id: string | null;
};

type ProfileRow = {
  id: string;
  full_name: string | null;
  business_name: string | null;
  avatar_url: string | null;
  specialty: string | null;
};

type PushTokenRow = {
  token: string;
};

type ServiceAccount = {
  project_id?: string;
  client_email?: string;
  private_key?: string;
};

type ApiError = {
  status: number;
  code?: string;
  message: string;
};

let cachedAccessToken: { token: string; expiresAt: number } | null = null;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ ok: false, message: 'Method not allowed.' }, 405);
  }

  const supabaseUrl = getEnv('SUPABASE_URL');
  const serviceRoleKey = getEnv('SUPABASE_SERVICE_ROLE_KEY', 'SB_SECRET_KEY');
  const serviceAccountJson = getEnv('FIREBASE_SERVICE_ACCOUNT_JSON');
  if (!supabaseUrl || !serviceRoleKey || !serviceAccountJson) {
    return jsonResponse(
      { ok: false, message: 'Bildirim servisi yapilandirilmamis.' },
      503,
    );
  }

  try {
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const messageId = typeof body.messageId === 'string' ? body.messageId : '';
    if (!isUuid(messageId)) {
      return jsonResponse({ ok: false, message: 'Gecersiz mesaj id.' }, 400);
    }

    const message = await selectSingle<MessageRow>(
      supabaseUrl,
      serviceRoleKey,
      'messages',
      'id,conversation_id,sender_id,body,created_at',
      { id: `eq.${messageId}` },
    );
    if (!message) {
      return jsonResponse({ ok: false, message: 'Mesaj bulunamadi.' }, 404);
    }

    const authorized = await canSendForMessage(req, supabaseUrl, serviceRoleKey, message);
    if (!authorized) {
      return jsonResponse({ ok: false, message: 'Yetkisiz istek.' }, 401);
    }

    const conversation = await selectSingle<ConversationRow>(
      supabaseUrl,
      serviceRoleKey,
      'conversations',
      'id,homeowner_id,designer_id',
      { id: `eq.${message.conversation_id}` },
    );
    if (!conversation) {
      return jsonResponse({ ok: false, message: 'Konusma bulunamadi.' }, 404);
    }

    const recipientId = recipientFor(conversation, message.sender_id);
    if (!recipientId) {
      return jsonResponse({ ok: true, sent: 0, skipped: 'recipient_not_found' });
    }

    const [sender, tokens] = await Promise.all([
      selectSingle<ProfileRow>(
        supabaseUrl,
        serviceRoleKey,
        'profiles',
        'id,full_name,business_name,avatar_url,specialty',
        { id: `eq.${message.sender_id}` },
      ),
      selectMany<PushTokenRow>(
        supabaseUrl,
        serviceRoleKey,
        'push_tokens',
        'token',
        {
          user_id: `eq.${recipientId}`,
          is_active: 'eq.true',
        },
      ),
    ]);

    if (tokens.length === 0) {
      return jsonResponse({ ok: true, sent: 0, skipped: 'no_active_token' });
    }

    const serviceAccount = parseServiceAccount(serviceAccountJson);
    const accessToken = await getFcmAccessToken(serviceAccount);
    const projectId = serviceAccount.project_id ?? getEnv('FIREBASE_PROJECT_ID');
    if (!projectId) throw new Error('Firebase project id bulunamadi.');

    const title = profileName(sender);
    const notificationBody = truncateText(message.body, 140) ?? 'Yeni bir mesajın var.';
    const payload = {
      type: 'message',
      messageId: message.id,
      conversationId: message.conversation_id,
      senderId: message.sender_id,
      senderName: title,
      avatar: sender?.avatar_url ?? '',
      specialty: sender?.specialty ?? '',
      body: notificationBody,
    };

    const results = await Promise.allSettled(
      tokens.map((row) =>
        sendFcmMessage(projectId, accessToken, row.token, title, notificationBody, payload)
          .catch(async (error) => {
            if (isInvalidTokenError(error)) {
              await deactivateToken(supabaseUrl, serviceRoleKey, row.token);
            }
            throw error;
          })
      ),
    );

    const sent = results.filter((result) => result.status === 'fulfilled').length;
    const failed = results.length - sent;
    return jsonResponse({ ok: true, sent, failed });
  } catch (error) {
    return jsonResponse({
      ok: false,
      message: error instanceof Error ? error.message : 'Bildirim gonderilemedi.',
    }, 500);
  }
});

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

function restUrl(
  supabaseUrl: string,
  table: string,
  select: string,
  params: Record<string, string>,
) {
  const search = new URLSearchParams({ select, ...params });
  return `${supabaseUrl}/rest/v1/${table}?${search.toString()}`;
}

async function readApiError(response: Response): Promise<ApiError> {
  const text = await response.text();
  if (!text) return { status: response.status, message: response.statusText };
  try {
    const data = JSON.parse(text) as {
      code?: string;
      error?: { message?: string; status?: string };
      error_description?: string;
      message?: string;
      msg?: string;
    };
    return {
      status: response.status,
      code: data.code ?? data.error?.status,
      message:
        data.error?.message ??
        data.error_description ??
        data.message ??
        data.msg ??
        text,
    };
  } catch (_) {
    return { status: response.status, message: text };
  }
}

async function selectSingle<T>(
  supabaseUrl: string,
  serviceRoleKey: string,
  table: string,
  select: string,
  params: Record<string, string>,
) {
  const rows = await selectMany<T>(supabaseUrl, serviceRoleKey, table, select, {
    ...params,
    limit: '1',
  });
  return rows[0] ?? null;
}

async function selectMany<T>(
  supabaseUrl: string,
  serviceRoleKey: string,
  table: string,
  select: string,
  params: Record<string, string>,
) {
  const response = await fetch(restUrl(supabaseUrl, table, select, params), {
    headers: serviceHeaders(serviceRoleKey),
  });
  if (!response.ok) throw new Error((await readApiError(response)).message);
  return await response.json() as T[];
}

async function canSendForMessage(
  req: Request,
  supabaseUrl: string,
  serviceRoleKey: string,
  message: MessageRow,
) {
  const secret = getEnv('MESSAGE_NOTIFICATION_SECRET');
  if (secret && req.headers.get('x-message-notification-secret') === secret) {
    return true;
  }

  const authorization = req.headers.get('authorization') ?? '';
  const token = authorization.replace(/^Bearer\s+/i, '').trim();
  if (token === serviceRoleKey) return true;
  if (!authorization) return false;

  const response = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: {
      apikey: serviceRoleKey,
      authorization,
    },
  });
  if (!response.ok) return false;

  const data = await response.json() as { id?: string };
  return data.id === message.sender_id;
}

function recipientFor(conversation: ConversationRow, senderId: string) {
  if (conversation.homeowner_id === senderId) return conversation.designer_id;
  if (conversation.designer_id === senderId) return conversation.homeowner_id;
  return null;
}

function profileName(profile: ProfileRow | null) {
  const name = profile?.business_name?.trim() || profile?.full_name?.trim();
  return name && name.length > 0 ? name : 'Evlumba';
}

function truncateText(value: string | null | undefined, max: number) {
  const normalized = value?.replace(/\s+/g, ' ').trim();
  if (!normalized) return null;
  return normalized.length <= max ? normalized : `${normalized.slice(0, max - 3)}...`;
}

function isUuid(value: string) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

function parseServiceAccount(raw: string): ServiceAccount {
  const parsed = JSON.parse(raw) as ServiceAccount;
  if (!parsed.client_email || !parsed.private_key) {
    throw new Error('Firebase service account eksik.');
  }
  return parsed;
}

async function getFcmAccessToken(serviceAccount: ServiceAccount) {
  const now = Math.floor(Date.now() / 1000);
  if (cachedAccessToken && cachedAccessToken.expiresAt > now + 60) {
    return cachedAccessToken.token;
  }

  const header = { alg: 'RS256', typ: 'JWT' };
  const claims = {
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };
  const signingInput = `${base64Url(JSON.stringify(header))}.${base64Url(JSON.stringify(claims))}`;
  const signature = await signJwt(signingInput, serviceAccount.private_key!);
  const assertion = `${signingInput}.${signature}`;

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  if (!response.ok) throw new Error((await readApiError(response)).message);

  const data = await response.json() as { access_token?: string; expires_in?: number };
  if (!data.access_token) throw new Error('Firebase access token alinamadi.');

  cachedAccessToken = {
    token: data.access_token,
    expiresAt: now + (data.expires_in ?? 3600),
  };
  return data.access_token;
}

async function signJwt(input: string, privateKeyPem: string) {
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(privateKeyPem),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(input),
  );
  return base64Url(signature);
}

function pemToArrayBuffer(pem: string) {
  const base64 = pem
    .replace(/\\n/g, '\n')
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\s/g, '');
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

function base64Url(value: string | ArrayBuffer) {
  const bytes = typeof value === 'string'
    ? new TextEncoder().encode(value)
    : new Uint8Array(value);
  let binary = '';
  for (let i = 0; i < bytes.length; i += 1) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

async function sendFcmMessage(
  projectId: string,
  accessToken: string,
  token: string,
  title: string,
  body: string,
  data: Record<string, string>,
) {
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          data,
          android: {
            priority: 'HIGH',
            notification: {
              channel_id: 'evlumba_messages',
              click_action: 'FLUTTER_NOTIFICATION_CLICK',
              default_vibrate_timings: true,
              notification_priority: 'PRIORITY_HIGH',
              sound: 'default',
            },
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
                badge: 1,
              },
            },
          },
        },
      }),
    },
  );

  if (!response.ok) {
    const apiError = await readApiError(response);
    throw new Error(`${apiError.code ?? response.status}: ${apiError.message}`);
  }
}

function isInvalidTokenError(error: unknown) {
  const message = error instanceof Error ? error.message : String(error);
  return (
    message.includes('UNREGISTERED') ||
    message.includes('INVALID_ARGUMENT') ||
    message.includes('registration-token-not-registered')
  );
}

async function deactivateToken(
  supabaseUrl: string,
  serviceRoleKey: string,
  token: string,
) {
  const response = await fetch(restUrl(supabaseUrl, 'push_tokens', 'id', {
    token: `eq.${token}`,
  }), {
    method: 'PATCH',
    headers: {
      ...serviceHeaders(serviceRoleKey),
      Prefer: 'return=minimal',
    },
    body: JSON.stringify({
      is_active: false,
      last_seen_at: new Date().toISOString(),
    }),
  });
  if (!response.ok) {
    console.warn('Token pasiflestirilemedi', await response.text());
  }
}
