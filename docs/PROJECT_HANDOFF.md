# Voke 项目交接文档

> 最后核对时间：2026-07-20（Asia/Shanghai）
> 文档用途：帮助新的开发者在不丢失现有用户配置、不破坏已验证输入行为的前提下继续开发、测试与发布 Voke。

## 1. 一页结论

Voke 是一个原生 macOS 外设动作映射工具。当前已经完成可用的功能型原型：游戏手柄和外接 HID 小键盘可以按设备保存配置，把按钮或摇杆方向映射为键盘快捷键、连续滚动、系统 App 切换、全屏截图或 ZSH 命令。

核心输入链路和主要回归问题已经解决，并有 12 项单元测试覆盖关键逻辑。项目现在处于“功能主干完成，正式产品化未完成”的阶段。

接手后的第一优先级不是继续增加映射动作，而是完成稳定签名、公证、安装包、Bundle ID 数据迁移和真实设备回归。否则每次临时打包都有可能重新触发 macOS 权限问题。

## 2. 当前快照

| 项目 | 当前状态 |
|---|---|
| 仓库路径 | `/Users/dolphin/Desktop/Dolphin/voke` |
| Git 分支 | `main` |
| 当前 HEAD | `b691db3 refactor: rename project structure to Voke` |
| 最近正式标签 | `v0.3.1`，指向品牌改名前的 `24306cd` |
| 当前描述 | `v0.3.1-2-gb691db3` |
| Xcode 工程 | `Voke.xcodeproj` |
| Target / Scheme / Module | `Voke` |
| 测试 Target | `VokeTests` |
| 最低系统版本 | macOS 14.0 |
| Swift 配置 | Swift 5，Strict Concurrency 为 `minimal` |
| 工程生成方式 | XcodeGen，权威配置为 `project.yml` |
| 应用显示名 | `Voke` |
| Marketing Version | `0.3.1` |
| Build Version | `6` |
| 当前 Bundle ID | `com.dolphin.ai-command-controller`，为了保留原配置暂未改名 |
| App Sandbox | 关闭 |
| 当前签名 | ad hoc 临时签名，无 Team ID |
| 可用签名身份 | 当前机器检查结果为 `0 valid identities found` |
| Release 产物 | `build/Build/Products/Release/Voke.app` |
| 当前安装状态 | 核对时未在 `/Applications` 中发现 Voke，只有仓库内 Release 产物 |

## 3. 产品边界

### 3.1 当前产品解决什么

- 将 Switch Pro 等 macOS `GameController` 兼容手柄转成通用动作入口。
- 将三键、五键等外接 HID 小键盘学习为 K1–K12，并为每台设备保存独立映射。
- 允许用户自己配置动作，不与闪电说、微信、ChatGPT 或其他具体 App 强绑定。
- 在 Voke 位于后台时继续接收手柄输入，并把快捷键投递给当前前台应用。

### 3.2 当前支持的动作

| 动作 | 实现状态 | 说明 |
|---|---|---|
| 无动作 | 已完成 | 按键不产生输出 |
| 键盘快捷键 | 已完成 | 支持单键、组合键、左右修饰键和 Fn 标记的录制 |
| 页面滚动 | 已完成 | 支持上、下、左、右，按住连续滚动 |
| 系统 App 切换 | 已完成 | 打开原生切换条，左右移动选择；映射的 Return 确认，Esc 取消 |
| 全屏截图 | 已完成 | 发送 macOS 全屏截图快捷键，保存到系统默认位置 |
| ZSH 命令 | 已完成 | 通过 `/bin/zsh -lc` 以当前用户权限执行 |

### 3.3 当前支持的输入

- 手柄：A/B/X/Y、L/R、ZL/ZR、L3/R3、十字键、左右摇杆八个方向、`+`、`−`、HOME、CAPTURE。
- 外接 HID 键盘/小键盘：首次按下时按顺序学习为 K1–K12。
- 内建 Mac 键盘会被明确排除，不作为可映射输入设备。
- 同一 HID 小键盘原始按键不会被拦截；Voke 采用监听模式，会额外执行映射动作。

## 4. 已经完成并验证的工作

### 4.1 基础映射与输出

- 已完成动态按键配置，不存在针对闪电说等具体应用的硬编码绑定。
- 已完成按键录制和常用修饰键预设。
- 已完成左/右 Command、Control、Option、Shift 的区分。
- 已解决“单独修饰键可以触发，但和普通键无法组合”的问题。
- 已解决 ZL + A 等按住修饰键再按普通键的组合问题。
- 已解决 ZR 映射右 Control/Command 后单独触发目标应用热键的问题。
- 已完成 tap 与 hold 两种触发方式。
- 已完成长按普通键的连续脉冲输出，Delete 等文本编辑键可连续触发。
- 设备断开、关闭映射或应用退出时会释放全部仍处于按下状态的键，降低“卡键”风险。
- 映射总开关每次启动默认为关闭，这是安全设计，不是配置丢失。

### 4.2 App 切换和摇杆

- 左摇杆四方向默认映射为连续页面滚动。
- 右摇杆左右默认映射为系统 App 切换条的上一个/下一个选择。
- App 切换会保持 Command 按下，直到用户用 Return 确认或 Esc 取消。
- R3 可以配置为 Return，用于确认当前选择。
- 摇杆方向使用死区与回滞处理，避免中心附近抖动反复触发。

限制：某些菜单栏应用、浮层应用或特殊窗口即使在切换条中确认，也不一定成为普通前台窗口。这项“特殊窗口强制前置”曾讨论过，但明确暂缓，当前没有实现。

### 4.3 多设备与多方案

- 同时发现多个 `GCController` 手柄，并在设备菜单中切换。
- 每个设备拥有独立 `DeviceMappingConfiguration`。
- 每个设备可以创建、复制、重命名、切换和删除多套 Profile。
- HID 小键盘按 Vendor ID、Product ID、Serial 或 Location ID 组成设备 ID。
- 已连接和历史离线设备都会保留在配置中。

### 4.4 配置、备份与诊断

- 当前持久化结构为 `deviceConfigurations.v2`。
- 支持 JSON v2 导出，内容包括全部设备及其全部 Profile。
- 支持导入旧版 v1 单设备映射。
- 导入时校验不支持的版本、重复设备和重复按键。
- 支持复制诊断报告，包含版本、应用路径、权限状态、当前设备、前台 App、映射摘要和最近事件。
- 诊断报告会隐藏终端命令正文和命令输出，避免复制敏感内容。

### 4.5 权限与安全

- 应用启动约 700 ms 后，如果没有辅助功能权限，会请求系统授权。
- UI 提供直达“系统设置 → 隐私与安全性 → 辅助功能”的入口。
- 快捷键、滚动、App 切换和截图需要辅助功能权限。
- 外接 HID 小键盘需要“输入监控”权限。
- 终端命令不依赖辅助功能权限。
- 终端命令以当前登录用户权限执行；应用未启用 Sandbox，因此必须把命令输入视为高权限能力。

### 4.6 界面与品牌

- 已把对外应用名、界面品牌和诊断标题改为 `Voke`。
- 已把仓库、Xcode 工程、Target、Scheme、Module、源码目录和测试目录统一改为 Voke。
- 已实现宽屏双栏和窄屏纵向响应式布局。
- 已提供明亮、石墨、深海三套主题，默认明亮。
- 已实现原生 SceneKit 交互手柄模型，支持旋转、缩放和实时按键反馈。
- 手柄外廓和按键布局参考 Switch Pro Controller，但不是任天堂官方资产，也不是工业 CAD。

### 4.7 自动化测试

当前共有 12 项 XCTest，最近一次实跑全部通过：

- 右 Control 的侧别标记与组合键通用 flags。
- 左 Command + A 组合。
- tap 与长按重复继承当前修饰键。
- 重复按下去重，以及 `releaseAll` 清理状态。
- App 切换保持 Command，直到确认。
- 摇杆死区和回滞。
- 新配置的摇杆、App 切换和截图默认值。
- JSON v2 导出/导入往返。
- 拒绝不支持的备份版本且不污染当前配置。
- 不同设备保持独立映射。
- Profile 复制与切换。
- 拒绝重复设备。

这些测试主要是逻辑单元测试，不等同于真实手柄、TCC 权限或 UI 自动化测试。

## 5. 没有完成的工作

### 5.1 发布与升级链路（最高优先级）

- 没有 Apple Developer 证书。
- 没有 Developer ID Application 正式签名。
- 没有 Hardened Runtime、公证和 Stapling。
- 没有 DMG/PKG 安装包。
- 没有自动更新机制。
- 没有正式 Release 标签覆盖 Voke 品牌重构；最近标签仍为 `v0.3.1`。
- 当前 Release 只是手工 ad hoc 签名，不能保证辅助功能/输入监控授权在每次构建后稳定延续。

### 5.2 Bundle ID 正式迁移

当前仍使用 `com.dolphin.ai-command-controller`，目的是继续读取旧 UserDefaults 并尽量延续权限。

正式发布前预计会改成类似 `com.dolphin.voke`，但不能直接改。直接修改会产生以下结果：

- 原映射、Profile、主题和 HID 学习结果不会自动出现在新域。
- 辅助功能和输入监控需要重新授权。
- macOS 会把新应用视为不同产品。

正确做法是在旧 Bundle ID 的最后一个版本或新版本首次启动时加入明确的数据迁移，并在真实签名条件下测试权限升级路径。

### 5.3 更多外设类型

当前只支持 `GameController` 手柄和外接 HID 键盘类设备。以下没有实现：

- 鼠标按钮或滚轮作为输入源。
- MIDI 控制器。
- 旋钮、宏键盘等 Consumer Control/HID 非键盘 Usage Page 设备。
- Stream Deck 类专用协议设备。
- 内建 Mac 键盘作为可独立配置设备。

### 5.4 输入法/地球键专属动作

历史上曾加入“输入源切换动作”，随后因修饰键行为回归被整体回退。当前快捷键模型能够记录 Fn flags 和 keyCode 63，但没有独立、经过真实苹果键盘验证的“地球键/中英切换”动作。

不要把“录制器能显示 Fn”当作“已完整支持苹果地球键”。该能力需要单独设计和真机测试。

### 5.5 音频设备功能

`AudioDeviceService` 已经能够枚举输入/输出设备并识别系统默认设备，`AppModel` 每 2 秒刷新一次，但当前 Dashboard 没有展示这些数据，也没有切换输入/输出设备的动作。

因此，大疆 Mic Mini、索尼耳机等音频外设目前只能被底层识别，不能在 Voke 中配置或切换。`NSMicrophoneUsageDescription` 已存在，但应用当前没有录音功能。

### 5.6 截图能力

当前只有“截取当前屏幕”的单一动作。以下没有实现：

- 截取选定区域。
- 截取指定窗口。
- 录屏。
- 自定义保存路径或复制到剪贴板。

### 5.7 UI 和 3D 模型

- 当前界面已经过一次简化，但高级功能、活动记录、设备/Profile、备份与诊断仍集中在单窗口内，尚未进行正式可用性测试。
- 没有首次使用向导。
- 没有明确区分“基础模式”和“高级模式”。
- 3D 手柄只是交互示意模型，不是扫描级 1:1 模型，不能用于开模制造。
- 没有导入 USDZ/RealityKit 工业模型的资源管线。

### 5.8 自动化测试缺口

- 没有 XCUITest。
- 没有真实 GameController 自动化测试。
- 没有 IOHID 外接小键盘集成测试。
- 没有 TCC 辅助功能和输入监控权限测试。
- 没有 App 切换条端到端测试。
- 没有截图和终端命令动作测试。
- 没有构建、签名、公证的 CI。
- 没有备份文件兼容性的固定 fixture 测试。

## 6. 明确暂缓或不做的事项

以下是讨论后明确暂缓的范围，不应在没有重新确认产品方向时自行扩张：

- 针对闪电说、Worldbody 等特殊应用做强制窗口前置。
- 为某个 App 自动切换专属 Profile。
- 与闪电说或其他语音软件做硬编码绑定。
- 在手柄完成前继续大规模扩展其他外设类别。
- 制造级手柄建模。

产品原则仍然是：用户配置通用输入与动作，Voke 不绑定某个具体 AI 或语音应用。

## 7. 已知问题与技术风险

### P0：发布签名不稳定

当前没有有效签名身份。ad hoc 签名的 CodeDirectory 会随构建变化，可能让 macOS 权限记录失效或出现“系统设置已开启，但应用仍判断未授权”的现象。

### P0：同 Bundle ID 多副本

旧版 `AI Command Controller.app` 和新版 `Voke.app` 如果同时存在或同时运行，由于 Bundle ID 相同，LaunchServices 和 TCC 可能识别到错误副本。测试前要完全退出旧版，并只保留一个待测副本。

### P1：相同型号多手柄的设备 ID 不稳定

GameController 设备 ID 主要根据设备名生成；同名设备通过连接顺序追加 `.2`、`.3`。如果多只相同型号手柄的连接顺序变化，Profile 可能对应到另一只实体手柄。需要寻找更稳定的硬件标识，或提供用户确认/重新绑定机制。

### P1：HID 设备 Location ID 可能变化

没有序列号的 HID 小键盘会使用 Location ID。更换 USB 端口、扩展坞或连接拓扑后，系统可能生成新的设备 ID，从而看起来像新设备。

### P1：小键盘原始输入不会被吞掉

当前是 IOHID 监听而非独占/拦截。映射会执行，但原始字符也会传给前台应用。要实现“只执行映射、不输入原字符”，需要更底层的事件抑制方案，并重新评估权限和安全性。

### P1：特殊 App 窗口前置不保证

标准 Chrome、ChatGPT、微信等通常可以从切换条前置；菜单栏工具、浮层、无普通主窗口或自定义激活策略的 App 可能无法前置。这不是当前 App 切换实现可以普遍保证的能力。

### P1：命令执行边界

Shell 动作不经过 Sandbox，以当前用户权限执行。导入配置也可能带入 Shell 命令。当前导入流程没有逐条命令确认或信任提示，应在公开分发前补充安全设计。

### P2：品牌残留字符串

代码里仍有两处旧品牌残留，需要清理：

- `AppModel.activeApplication` 的初始值为 `AI COMMAND`。
- 导出文件默认名为 `AI-Command-Controller-配置.json`。

### P2：版本状态不一致

工程已完成 Voke 重命名，但 Marketing Version 和最近标签仍为 0.3.1。不要仅根据标签判断当前源码是否包含品牌重构。

## 8. 数据与迁移说明

### 8.1 UserDefaults 域

因为 Bundle ID 未变，当前数据位于：

```text
com.dolphin.ai-command-controller
```

主要键：

| Key | 内容 |
|---|---|
| `deviceConfigurations.v2` | 所有设备、Profile 和映射 |
| `selectedInputDevice.v2` | 当前选择的输入设备 |
| `controllerMappings.v1` | 旧版单设备映射，仅用于迁移读取 |
| `hidKeyboardAssignments.v1` | HID usage 到 K1–K12 的学习结果 |
| `appearanceTheme` | UI 主题 |

`mappingEnabled` 没有持久化，每次启动为 `false`。

### 8.2 备份格式

- 当前导出格式：JSON，`formatVersion = 2`。
- v2 包含全部 `DeviceMappingConfiguration`。
- 仍接受 v1 的单一 `[ButtonMapping]`。
- 导入 v2 会用导入内容替换当前全部配置，不是合并导入。

### 8.3 交接前不要做

- 不要删除 `com.dolphin.ai-command-controller` 的 UserDefaults 域。
- 不要在没有迁移代码和备份的情况下修改 App Bundle ID。
- 不要用 `defaults delete` 清理权限问题；TCC 权限和 UserDefaults 是两套不同数据。
- 不要在旧版和新版同时运行时判断配置是否丢失。

## 9. 代码结构

```mermaid
flowchart LR
    GC[GameController] --> AM[AppModel]
    HID[IOHID 外接键盘] --> AM
    AM --> MS[MappingStore]
    MS --> UD[UserDefaults / JSON Backup]
    AM --> KO[KeyboardOutputService]
    KO --> KP[KeyboardEventPlanner]
    KO --> CG[CGEvent 键盘输出]
    AM --> SO[ScrollOutputService]
    SO --> CGS[CGEvent 滚动输出]
    AM --> SH[ShellCommandService]
    SH --> ZSH[/bin/zsh -lc]
    AM --> UI[SwiftUI Dashboard]
    UI --> SCN[SceneKit 手柄模型]
```

主要文件职责：

| 文件 | 职责 |
|---|---|
| `Voke/VokeApp.swift` | SwiftUI 应用入口和窗口配置 |
| `Voke/AppModel.swift` | 设备生命周期、事件分发、动作执行、备份和诊断 |
| `Voke/Models/MappingModels.swift` | 输入、动作、快捷键、设备与 Profile 数据模型 |
| `Voke/Services/MappingStore.swift` | 映射持久化、默认值、Profile、导入导出 |
| `Voke/Services/KeyboardEventPlanner.swift` | 纯逻辑键盘状态机，处理按下、松开、修饰键组合和重复 |
| `Voke/Services/KeyboardOutputService.swift` | CGEvent 发送、连发和 App 切换条状态 |
| `Voke/Services/HIDKeyboardService.swift` | 外接 HID 键盘发现、权限、K1–K12 学习 |
| `Voke/Services/ScrollOutputService.swift` | 连续滚动任务 |
| `Voke/Services/ShellCommandService.swift` | ZSH 命令执行 |
| `Voke/Services/AudioDeviceService.swift` | 音频设备枚举，目前没有产品 UI |
| `Voke/Views/DashboardView.swift` | 响应式主界面、设备/Profile、工具栏和权限提示 |
| `Voke/Views/MappingStudio.swift` | 映射编辑器和快捷键录制 |
| `Voke/Views/Controller3DView.swift` | SceneKit 手柄模型 |
| `VokeTests/*` | 关键映射逻辑与持久化单元测试 |

## 10. 构建、测试和生成工程

### 10.1 环境

- Xcode 安装在 `/Applications/Xcode.app`。
- 需要 XcodeGen：当前机器路径为 `/opt/homebrew/bin/xcodegen`。
- 项目最低 macOS 14.0。

### 10.2 重新生成工程

`project.yml` 是工程配置的权威来源。修改 target、版本、Bundle ID 或 Info.plist 项目后必须重新生成：

```bash
cd /Users/dolphin/Desktop/Dolphin/voke
xcodegen generate
open Voke.xcodeproj
```

不要只编辑 `Voke.xcodeproj/project.pbxproj`，否则下次 XcodeGen 会覆盖修改。

### 10.3 自动化测试

```bash
xcodebuild test \
  -project Voke.xcodeproj \
  -scheme Voke \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO
```

交接文档编写前的最近一次结果：12 tests，0 failures。

### 10.4 Release 构建

```bash
xcodebuild \
  -project Voke.xcodeproj \
  -scheme Voke \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  build
```

当前临时签名方式仅用于本机测试：

```bash
APP_PATH='/Users/dolphin/Desktop/Dolphin/voke/build/Build/Products/Release/Voke.app'
codesign --force --deep --sign - \
  --identifier com.dolphin.ai-command-controller \
  "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
```

不要把这套 ad hoc 签名当作正式发布方案。

## 11. 建议的后续执行顺序

### P0：先让发布身份稳定

1. 申请/配置 Apple Developer Program 和 Developer ID Application 证书。
2. 确定正式 Bundle ID。
3. 设计旧 Bundle ID 到新 Bundle ID 的数据迁移。
4. 增加 Hardened Runtime、正式签名、公证和 Stapling。
5. 制作 DMG，并在一台未授权过的 Mac 用户环境做首次安装测试。
6. 测试升级安装后映射、Profile、主题、辅助功能和输入监控是否保持或得到清晰引导。

验收标准：同一个正式签名版本反复覆盖安装不会随机丢失 TCC 权限；升级后用户映射不丢失。

### P1：建立真实设备回归清单

至少覆盖：

- Switch Pro Controller 的所有可见按键。
- ZR 单独触发右 Control/Command 类热键。
- ZL + A 等组合键。
- Delete 长按连续删除。
- 左摇杆四方向滚动。
- 右摇杆打开切换条、连续选择、Return 确认、Esc 取消。
- Capture 截图。
- 两只手柄的独立配置。
- 三键/五键 HID 小键盘学习、重连和更换 USB 端口。
- 导出、清空测试环境、导入恢复。

### P1：清理并加固现有产品

1. 清理旧品牌字符串和导出文件名。
2. 为 Shell 配置导入增加明确警告或信任确认。
3. 处理相同型号多手柄的稳定身份问题。
4. 给配置导入增加固定 fixture 和向后兼容测试。
5. 增加首次使用向导，把辅助功能、输入监控和映射总开关解释清楚。

### P2：再决定功能扩展

产品确认后再选择：

- 音频设备展示和切换动作。
- 苹果地球键/输入源专属动作。
- 鼠标、MIDI、旋钮和其他 HID 类型。
- 区域/窗口截图。
- 基础模式与高级模式。
- 更真实的 USDZ/RealityKit 手柄模型。

## 12. 关键提交与里程碑

| 版本/提交 | 内容 |
|---|---|
| `3a2e355` | 首个 macOS MVP |
| `86fc42b` | 可配置 Mapping Studio |
| `590d694` | 手柄按住修饰键时组合普通键 |
| `584da8b`–`8f48f85` | 长按连发和文本输入兼容修复 |
| `v0.2.0 / 62e49c9` | 摇杆动作、诊断与回归测试 |
| `v0.2.1 / 83265b5` | App 切换确认机制修复 |
| `v0.2.2 / 46add5e` | 保持原生 App 切换条直到 Return |
| `v0.3.0 / b1ee26c` | 多设备、HID 小键盘、独立 Profile、主题 |
| `v0.3.1 / 24306cd` | 手柄模型轮廓调整 |
| `deee940` | 对外应用名改为 Voke |
| `b691db3` | 工程、Module、目录全面改为 Voke |

## 13. 接手人首日检查清单

- [ ] 阅读本文件和 `README.md`。
- [ ] 确认 `git status` 干净，记录当前 HEAD。
- [ ] 执行 `xcodegen generate`。
- [ ] 跑完 12 项测试。
- [ ] 用当前 Release 构建确认 Bundle ID 仍为旧值。
- [ ] 在改 Bundle ID 前导出一份真实用户 JSON v2 配置。
- [ ] 确认系统中没有旧版和新版 App 同时运行。
- [ ] 用实际 Pro 手柄完成一轮关键链路测试。
- [ ] 明确 Apple Developer 账号与证书负责人。
- [ ] 在开始新功能前，先决定正式签名、Bundle ID 和升级迁移方案。

## 14. 最重要的维护原则

1. 不要为某个语音软件硬编码按键；所有行为继续走通用映射模型。
2. 不要破坏按下/松开成对状态；任何异常退出路径都必须释放输出。
3. 不要把辅助功能、输入监控、UserDefaults 和代码签名混为一谈，它们是不同层的问题。
4. 不要在没有迁移方案的情况下修改 Bundle ID。
5. 不要把单元测试通过等同于真实外设和 TCC 权限链路通过。
6. 不要把当前 3D 模型描述为任天堂官方模型或制造级 1:1 CAD。
7. 先稳定安装、权限和升级，再扩展更多外设。
