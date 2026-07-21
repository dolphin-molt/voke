# Voke 落地页

这是 Voke 的轻量落地页，主要介绍用手柄控制 Mac，并提供站内功能建议表单。表单由 Cloudflare Pages Functions 接收，数据保存在 D1 的 `feedback` 表中。

本地预览：

```bash
wrangler pages dev site \
  --d1 VOKE_FEEDBACK=64eda256-a054-4acb-83bc-a837de2dcb62 \
  --port 4173
```

打开 <http://127.0.0.1:4173/>。

页面中的下载按钮固定指向带版本号的 GitHub Release 文件：

```text
https://github.com/dolphin-molt/voke/releases/download/v0.1.1/Voke-v0.1.1.dmg
```

发布新版本时需要同时更新 Release 标签、DMG 文件名和页面下载链接，避免浏览器或 macOS 继续使用旧缓存。

查看线上建议：

```bash
wrangler d1 execute voke-feedback --remote --command "SELECT * FROM feedback ORDER BY created_at DESC;"
```

也可以打开受密码保护的管理页：

```text
https://voke.theopcapp.com/admin/
```

管理密码与会话签名密钥保存在 Cloudflare Pages Secrets 中，不应提交到仓库：

```bash
wrangler pages secret put ADMIN_PASSWORD --project-name voke
wrangler pages secret put ADMIN_SESSION_SECRET --project-name voke
```
