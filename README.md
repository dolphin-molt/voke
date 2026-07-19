# AI Command Controller

把游戏手柄变成面向 AI 工作流的 macOS 输入控制台：嘴负责内容，耳机负责反馈，手柄负责意图。

## 当前 MVP

- 自动发现 macOS GameController 支持的手柄
- 实时显示 A/B/X/Y、肩键、扳机、十字键和双摇杆
- 可旋转、缩放的原生 3D Pro Controller 比例模型，按键与摇杆实时联动
- 枚举当前音频输入/输出设备，并标记系统默认设备
- 总开关开启后，按住 ZR 发送 Command Key Down，松开时发送 Command Key Up
- 手柄断连、关闭映射或应用退出时强制释放 Command
- 在应用中引导开启 macOS 辅助功能权限
- 首次启动时自动触发 macOS 辅助功能授权提示，并可直达系统设置
- 响应式窗口布局：宽屏动态三栏，窄屏自动切换为纵向控制台，3D 手柄随可用空间缩放

## 开发运行

```bash
cd /Users/dolphin/Desktop/Dolphin/ai-command-controller
xcodegen generate
open AICommandController.xcodeproj
```

也可以直接构建：

```bash
xcodebuild -project AICommandController.xcodeproj -scheme AICommandController -configuration Debug build
```

首次发送快捷键前，需要在“系统设置 → 隐私与安全性 → 辅助功能”中允许 AI Command Controller。
应用启动时会自动触发系统授权提示，但 macOS 不允许应用代替用户打开权限开关；未授权时可通过应用内按钮直达对应设置页。

当前 3D 手柄是按 Pro Controller 外观比例和真实按键布局制作的交互模型，不是可用于开模制造的工业 CAD。制造级 1:1 需要实物尺寸、六视图照片或扫描数据，再替换为 USDZ/RealityKit 模型；现有输入节点命名可以继续复用。

## 安全设计

应用默认处于 SAFE 模式，不会向其他应用发送任何键盘事件。只有主动开启 OUTPUT 后，ZR 才会映射为 Command。任何断连或关闭操作都会发送 Command Key Up，避免修饰键卡住。
未授予辅助功能权限时 OUTPUT 会保持锁定，防止界面显示 ARMED 但事件实际被 macOS 拦截。单独的 Command 使用 macOS `flagsChanged` 修饰键事件发送，以兼容监听“按住 Command”的语音工具。
