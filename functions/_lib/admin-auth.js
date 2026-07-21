const COOKIE_NAME = 'voke_admin_session';
const SESSION_SECONDS = 60 * 60 * 24 * 7;

const encoder = new TextEncoder();

const base64Url = (bytes) => {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
};

const sign = async (value, secret) => {
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  return base64Url(new Uint8Array(await crypto.subtle.sign('HMAC', key, encoder.encode(value))));
};

const constantTimeEqual = (left, right) => {
  const leftBytes = encoder.encode(left);
  const rightBytes = encoder.encode(right);
  const length = Math.max(leftBytes.length, rightBytes.length);
  let difference = leftBytes.length ^ rightBytes.length;

  for (let index = 0; index < length; index += 1) {
    difference |= (leftBytes[index] || 0) ^ (rightBytes[index] || 0);
  }

  return difference === 0;
};

const readCookie = (request, name) => {
  const cookieHeader = request.headers.get('Cookie') || '';
  for (const part of cookieHeader.split(';')) {
    const [key, ...value] = part.trim().split('=');
    if (key === name) return value.join('=');
  }
  return '';
};

export const json = (data, status = 200, headers = {}) => new Response(JSON.stringify(data), {
  status,
  headers: {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    ...headers,
  },
});

export const hasAdminConfig = (env) => Boolean(env.ADMIN_PASSWORD && env.ADMIN_SESSION_SECRET);

export const verifyPassword = (password, env) => (
  typeof password === 'string'
  && hasAdminConfig(env)
  && constantTimeEqual(password, env.ADMIN_PASSWORD)
);

export const createSession = async (env) => {
  const expiresAt = Math.floor(Date.now() / 1000) + SESSION_SECONDS;
  const signature = await sign(String(expiresAt), env.ADMIN_SESSION_SECRET);
  return `${expiresAt}.${signature}`;
};

export const isAdmin = async (request, env) => {
  if (!hasAdminConfig(env)) return false;

  const token = readCookie(request, COOKIE_NAME);
  const separator = token.indexOf('.');
  if (separator < 1) return false;

  const expiresAt = token.slice(0, separator);
  const signature = token.slice(separator + 1);
  if (!/^\d+$/.test(expiresAt) || Number(expiresAt) <= Math.floor(Date.now() / 1000)) return false;

  const expected = await sign(expiresAt, env.ADMIN_SESSION_SECRET);
  return constantTimeEqual(signature, expected);
};

export const requireAdmin = async (context) => {
  if (!hasAdminConfig(context.env)) {
    return json({ message: '管理页尚未配置。' }, 503);
  }
  if (!await isAdmin(context.request, context.env)) {
    return json({ message: '请先登录。' }, 401);
  }
  return null;
};

export const sessionCookie = (token, request) => {
  const secure = new URL(request.url).protocol === 'https:' ? '; Secure' : '';
  return `${COOKIE_NAME}=${token}; Path=/; HttpOnly${secure}; SameSite=Strict; Max-Age=${SESSION_SECONDS}`;
};

export const clearSessionCookie = () => (
  `${COOKIE_NAME}=; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=0`
);
