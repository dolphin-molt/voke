# AI Command Controller

把游戏手柄变成面向 AI 工作流的 macOS 输入控制台：嘴负责内容，耳机负责反馈，手柄负责意图。

## 当前 MVP

- 自动发现 macOS GameController 支持的手柄
- 实时显示 A/B/X/Y、肩键、扳机、十字键和双摇杆
- 枚举当前音频输入/输出设备，并标记系统默认设备
- 总开关开启后，按住 ZR 发送 Command Key Down，松开时发送 Command Key Up
- 手柄断连、关闭映射或应用退出时强制释放 Command
- 在应用中引导开启 macOS 辅助功能权限

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

## 安全设计

应用默认处于 SAFE 模式，不会向其他应用发送任何键盘事件。只有主动开启 OUTPUT 后，ZR 才会映射为 Command。任何断连或关闭操作都会发送 Command Key Up，避免修饰键卡住。
