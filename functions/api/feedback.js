const json = (data, status = 200) => new Response(JSON.stringify(data), {
  status,
  headers: {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
  },
});

const clean = (value, maxLength) => typeof value === 'string'
  ? value.trim().slice(0, maxLength)
  : '';

export async function onRequestPost(context) {
  let body;

  try {
    body = await context.request.json();
  } catch {
    return json({ message: '提交内容无法读取，请刷新后重试。' }, 400);
  }

  if (clean(body.website, 200)) return json({ ok: true });

  const message = clean(body.message, 1000);
  const name = clean(body.name, 60);
  const contact = clean(body.contact, 120);

  if (message.length < 4) return json({ message: '请再多写一点，让我能看懂你的想法。' }, 400);
  if (!context.env.VOKE_FEEDBACK) return json({ message: '建议箱暂时没有连接好，请稍后再试。' }, 503);

  const source = new URL(context.request.url).hostname;
  const createdAt = new Date().toISOString();

  try {
    await context.env.VOKE_FEEDBACK.prepare(`
      INSERT INTO feedback (message, name, contact, source, status, created_at)
      VALUES (?, ?, ?, ?, 'new', ?)
    `).bind(message, name || null, contact || null, source, createdAt).run();
  } catch (error) {
    console.error('feedback insert failed', error);
    return json({ message: '建议暂时没有保存成功，请稍后再试。' }, 500);
  }

  return json({ ok: true, message: '收到了，谢谢你。' }, 201);
}
