import { json, requireAdmin } from '../../_lib/admin-auth.js';

const VALID_STATUSES = new Set(['all', 'new', 'reviewing', 'done']);

export async function onRequestGet(context) {
  const unauthorized = await requireAdmin(context);
  if (unauthorized) return unauthorized;
  if (!context.env.VOKE_FEEDBACK) return json({ message: '反馈数据库尚未连接。' }, 503);

  const requestedStatus = new URL(context.request.url).searchParams.get('status') || 'all';
  const status = VALID_STATUSES.has(requestedStatus) ? requestedStatus : 'all';

  const itemsQuery = status === 'all'
    ? context.env.VOKE_FEEDBACK.prepare(`
        SELECT id, message, name, contact, source, status, created_at
        FROM feedback
        ORDER BY created_at DESC
        LIMIT 200
      `)
    : context.env.VOKE_FEEDBACK.prepare(`
        SELECT id, message, name, contact, source, status, created_at
        FROM feedback
        WHERE status = ?
        ORDER BY created_at DESC
        LIMIT 200
      `).bind(status);

  const [itemsResult, countsResult] = await context.env.VOKE_FEEDBACK.batch([
    itemsQuery,
    context.env.VOKE_FEEDBACK.prepare(`
      SELECT status, COUNT(*) AS count
      FROM feedback
      GROUP BY status
    `),
  ]);

  const counts = { all: 0, new: 0, reviewing: 0, done: 0 };
  for (const row of countsResult.results || []) {
    if (row.status in counts) counts[row.status] = Number(row.count) || 0;
  }
  counts.all = counts.new + counts.reviewing + counts.done;

  return json({ items: itemsResult.results || [], counts });
}
