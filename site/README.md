# Voke 落地页

这是无需构建工具的静态落地页，内容保持简短，主要介绍用手柄控制 Mac。

本地预览：

```bash
python3 -m http.server 4173 --directory site
```

打开 <http://127.0.0.1:4173/>。

页面中的下载按钮固定指向 GitHub 最新 Release 的 `Voke.dmg`：

```text
https://github.com/dolphin-molt/voke/releases/download/v0.1.0/Voke.dmg
```

因此每个 GitHub Release 都应上传一个同名的 `Voke.dmg` 文件。
