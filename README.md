# Voke

把游戏手柄变成通用的 macOS 动作控制台：每个按钮和摇杆方向都可以映射成键盘操作、组合键、页面滚动、App 切换或终端命令。

项目现状、已完成/未完成范围、数据迁移、风险和接手步骤见 [`docs/PROJECT_HANDOFF.md`](docs/PROJECT_HANDOFF.md)。

## v0.3.1

- 同时发现多个 macOS GameController 手柄，并在设备菜单中切换
- 发现外接 HID 键盘/三键、五键小键盘；首次实际按下时学习为 K1–K12，按设备保存
- 每个设备拥有完全独立的映射，并可复制、重命名、切换和删除多套方案
- 实时显示 A/B/X/Y、肩键、扳机、十字键和双摇杆
- 可旋转、缩放的原生 3D Switch Pro Controller 比例模型，按 152 × 106 × 60 mm 外廓和任天堂按键布局重建，按键与摇杆实时联动
- Mapping Studio 支持为 A/B/X/Y、肩键、扳机、摇杆按下、摇杆八个方向、十字键、HOME 与 Capture 独立配置动作
- Capture 默认执行 macOS 全屏截图，也可像其他按键一样改成任意动作
- 支持录制单键、组合键、左右修饰键，并选择“点按一次”或“按住 / 松开”
- 左摇杆默认连续滚动页面；右摇杆左右方向默认按 macOS 最近使用顺序切换 App
- 支持按键触发自定义 `/bin/zsh -lc` 终端命令，并在事件日志显示退出码和输出
- 支持包含所有设备和方案的 JSON v2 备份、旧版 v1 导入，以及可复制的运行诊断报告
- 提供明亮、石墨、深海三套界面主题；默认使用明亮主题
- 配置自动持久化；已有用户配置升级时会保留
- 手柄断连、关闭映射或应用退出时强制释放所有仍处于按下状态的键
- 在应用中引导开启 macOS 辅助功能权限
- 首次启动时自动触发 macOS 辅助功能授权提示，并可直达系统设置
- 响应式窗口布局：宽屏双栏，窄屏自动切换为纵向控制台，3D 手柄随可用空间缩放
- 自动化测试覆盖左右修饰键组合、按键连发、摇杆死区和配置备份

## 开发运行

```bash
cd /Users/dolphin/Desktop/Dolphin/voke
xcodegen generate
open Voke.xcodeproj
```

也可以直接构建：

```bash
xcodebuild -project Voke.xcodeproj -scheme Voke -configuration Debug build
```

运行自动化测试：

```bash
xcodebuild test -project Voke.xcodeproj -scheme Voke -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO
```

首次发送快捷键前，需要在“系统设置 → 隐私与安全性 → 辅助功能”中允许 Voke。
应用启动时会自动触发系统授权提示，但 macOS 不允许应用代替用户打开权限开关；未授权时可通过应用内按钮直达对应设置页。

外接小键盘还需要“系统设置 → 隐私与安全性 → 输入监控”权限。当前使用监听模式：映射动作会执行，但小键盘本来的按键仍会同时传给前台应用，不会被拦截或吞掉。

当前 3D 手柄是按 Pro Controller 外观比例和真实按键布局制作的交互模型，不是可用于开模制造的工业 CAD。制造级 1:1 需要实物尺寸、六视图照片或扫描数据，再替换为 USDZ/RealityKit 模型；现有输入节点命名可以继续复用。

## 安全设计

应用默认暂停映射，只监听设备，不执行任何映射。主动打开“映射”开关后才允许执行快捷键和终端命令。任何断连、关闭或退出都会释放仍处于按下状态的键，避免修饰键卡住。

键盘快捷键需要 macOS 辅助功能权限；终端命令不依赖该权限。终端动作拥有当前用户权限，请只配置你理解并信任的命令。单独的 Command、Shift、Option、Control 使用 macOS `flagsChanged` 事件，左右修饰键可以分别录制。

普通按键和组合键会直接投递给当前前台应用；单独的修饰键使用系统级投递。“点按一次”会保持 60ms 的按下时间，兼容 Electron 和 Web 输入框。
