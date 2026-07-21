import { requireAdmin } from '../../_lib/admin-auth.js';

const csvCell = (value) => `"${String(value ?? '').replace(/"/g, '""')}"`;

export async function onRequestGet(context) {
  const unauthorized = await requireAdmin(context);
  if (unauthorized) return unauthorized;
  if (!context.env.VOKE_FEEDBACK) {
    return new Response('反馈数据库尚未连接。', { status: 503 });
  }

  const { results = [] } = await context.env.VOKE_FEEDBACK.prepare(`
    SELECT id, message, name, contact, status, source, created_at
    FROM feedback
    ORDER BY created_at DESC
  `).all();

  const rows = [
    ['编号', '建议', '称呼', '联系方式', '状态', '来源', '提交时间'],
    ...results.map((item) => [
      item.id,
      item.message,
      item.name,
      item.contact,
      item.status,
      item.source,
      item.created_at,
    ]),
  ];

  const csv = `\uFEFF${rows.map((row) => row.map(csvCell).join(',')).join('\r\n')}`;
  return new Response(csv, {
    headers: {
      'Content-Type': 'text/csv; charset=utf-8',
      'Content-Disposition': 'attachment; filename="voke-feedback.csv"',
      'Cache-Control': 'no-store',
    },
  });
}
