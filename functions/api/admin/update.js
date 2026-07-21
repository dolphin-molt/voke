import { json, requireAdmin } from '../../_lib/admin-auth.js';

const VALID_STATUSES = new Set(['new', 'reviewing', 'done']);

export async function onRequestPost(context) {
  const unauthorized = await requireAdmin(context);
  if (unauthorized) return unauthorized;
  if (!context.env.VOKE_FEEDBACK) return json({ message: '反馈数据库尚未连接。' }, 503);

  let body;
  try {
    body = await context.request.json();
  } catch {
    return json({ message: '更新内容无法读取。' }, 400);
  }

  const id = Number(body.id);
  if (!Number.isInteger(id) || id < 1 || !VALID_STATUSES.has(body.status)) {
    return json({ message: '更新内容不正确。' }, 400);
  }

  const result = await context.env.VOKE_FEEDBACK.prepare(`
    UPDATE feedback SET status = ? WHERE id = ?
  `).bind(body.status, id).run();

  if (!result.meta?.changes) return json({ message: '没有找到这条反馈。' }, 404);
  return json({ ok: true });
}
