import {
  createSession,
  hasAdminConfig,
  json,
  sessionCookie,
  verifyPassword,
} from '../../_lib/admin-auth.js';

export async function onRequestPost(context) {
  if (!hasAdminConfig(context.env)) return json({ message: '管理页尚未配置。' }, 503);

  let body;
  try {
    body = await context.request.json();
  } catch {
    return json({ message: '登录信息无法读取。' }, 400);
  }

  if (!verifyPassword(body.password, context.env)) {
    return json({ message: '密码不正确。' }, 401);
  }

  const token = await createSession(context.env);
  return json(
    { ok: true },
    200,
    { 'Set-Cookie': sessionCookie(token, context.request) },
  );
}
