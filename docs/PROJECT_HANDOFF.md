# Voke 项目交接文档

> 最后核对时间：2026-07-22（Asia/Shanghai）
> 文档用途：帮助新的开发者在不丢失现有用户配置、不破坏已验证输入行为的前提下继续开发、测试与发布 Voke。

## 1. 一页结论

Voke 是一个原生 macOS 外设动作映射工具。当前已经完成可用的功能型原型：游戏手柄和外接 HID 小键盘可以按设备保存配置，把按钮或摇杆方向映射为键盘快捷键、连续滚动、系统 App 切换、全屏截图或 ZSH 命令。

核心输入链路和主要回归问题已经解决，并有 55 项单元测试覆盖关键逻辑。项目现在处于“功能主干完成，正式产品化未完成”的阶段。

本机开发安装已改用固定的自签名身份，并停止在覆盖安装时清空 TCC 权限。正式分发仍需完成 Developer ID 签名、公证、安装包、Bundle ID 数据迁移和真实设备回归。

### 2026-07-20 界面与快捷键追加更新

- ESC 不再被录制器强制解释为“取消”，可以像普通按键一样映射。
- 新增“切换中英文”动作，在 macOS 已启用的中文与英文输入源之间直接切换。
- 设备切换提升到全局胶囊导航；主区改为可点击手柄映射图，右侧只编辑当前按键。
- Profile 继续保留在 v2 备份结构中，并重新作为 App 情景方案的配置基础。
- 活动记录、权限、主题、导入导出和诊断已移入独立设置页。
- 映射默认在应用重启后恢复；关闭主窗口继续后台运行；设置页可管理登录 Mac 时自动启动。

### 2026-07-22 通用 App 情景方案与后台按键修复

- 新增按当前前台 App 自动选择 Profile 的通用路由；手柄、外接 HID 键盘和鼠标按键共享同一套逻辑，没有对某个 App 硬编码。
- Profile 可按 macOS Bundle ID 绑定到一个或多个 App；没有专属绑定时自动回退到设备的通用方案。
- 主界面新增 `APP ROUTE` 情景条，可绑定已有方案、复制当前方案为 App 专属方案、解除绑定并查看当前路由结果。
- 设置页提供完整方案管理：重命名、删除、选择通用回退方案、查看和清除 App 绑定。
- Voke 自己成为前台时保留最近一个外部目标 App，使用户可以回到 Voke 配置刚才使用的软件。
- 前台 App 改变时先释放所有持续输出，再切换方案，避免按住状态跨方案残留。
- ESC、Return 和其他键盘映射统一改为系统级事件，修复 Voke 在后台时部分浮层或录音面板无法稳定响应的问题。
- 通用回退方案与 App 专属方案强制分离；专属方案只能绑定一个 App，不能被误设为其他应用的通用方案。
- ChatGPT / Codex 专属方案提供当前 App 动作；映射保存 command ID，并自动监听当前用户 `CODEX_HOME/keybindings.json`，无需在 Voke 重复绑定快捷键。

## 2. 当前快照

| 项目 | 当前状态 |
|---|---|
| 仓库路径 | `/Users/dolphin/Desktop/Dolphin/voke` |
| Git 分支 | `main` |
| 当前 HEAD | 以 GitHub `main` 分支为准 |
| 最近公开标签 | `v0.4.0`，公开测试版 Build 9 |
| GitHub | `https://github.com/dolphin-molt/voke` |
| Xcode 工程 | `Voke.xcodeproj` |
| Target / Scheme / Module | `Voke` |
| 测试 Target | `VokeTests` |
| 最低系统版本 | macOS 14.0 |
| Swift 配置 | Swift 5，Strict Concurrency 为 `minimal` |
| 工程生成方式 | XcodeGen，权威配置为 `project.yml` |
| 应用显示名 | `Voke` |
| Marketing Version | `0.4.0` |
| Build Version | `9` |
| 当前 Bundle ID | `com.dolphin.ai-command-controller`，为了保留原配置暂未改名 |
| App Sandbox | 关闭 |
| 当前签名 | 固定本地自签名 `Voke Local Development`，无 Apple Team ID |
| 可用签名身份 | `7F70474A20654D2833B2052B68EDCFBD694CBFFB`（仅此开发机） |
| Release 产物 | `build/Build/Products/Release/Voke.app` |
| 当前安装状态 | `/Applications/Voke.app`，安装脚本会自动覆盖并启动 |

## 3. 产品边界

### 3.1 当前产品解决什么

- 将 Switch Pro 等 macOS `GameController` 兼容手柄转成通用动作入口。
- 将三键、五键等外接 HID 小键盘学习为 K1–K12，并为每台设备保存独立映射。
- 识别键盘类和鼠标类 HID 设备，按实际设备切换对应的手绘映射面。
- 允许用户自己配置动作和按 App 自动切换的情景方案，但不为闪电说、微信、ChatGPT 或其他具体 App 写专用逻辑。
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
| 鼠标移动/点击 | 已完成 | 手柄右摇杆连续移动光标，按键可执行鼠标左键 |
| 中英文输入源 | 已完成 | 直接切换已启用的中英文输入源 |

### 3.3 当前支持的输入

- 手柄：A/B/X/Y、L/R、ZL/ZR、L3/R3、十字键、左右摇杆八个方向、`+`、`−`、HOME、CAPTURE。
- 外接 HID 键盘/小键盘：首次按下时按顺序学习为 K1–K12。
- 鼠标：左键、右键、中键和可识别的侧键。
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
- 映射默认在启动后自动恢复；用户可以在设置中关闭“启动后自动运行映射”。

### 4.2 App 切换和摇杆

- 左摇杆四方向默认映射为连续页面滚动。
- 右摇杆左右默认映射为系统 App 切换条的上一个/下一个选择。
- App 切换会保持 Command 按下，直到用户用 Return 确认或 Esc 取消。
- R3 可以配置为 Return，用于确认当前选择。
- 摇杆方向使用死区与回滞处理，避免中心附近抖动反复触发。

限制：某些菜单栏应用、浮层应用或特殊窗口即使在切换条中确认，也不一定成为普通前台窗口。这项“特殊窗口强制前置”曾讨论过，但明确暂缓，当前没有实现。

### 4.3 多设备与配置

- 同时发现多个 `GCController` 手柄，并在设备菜单中切换。
- 每个设备拥有独立 `DeviceMappingConfiguration`。
- 主界面通过 `APP ROUTE` 展示当前生效方案；底层 v2 Profile 可以按 Bundle ID 绑定 App，也始终保留一个通用回退方案。
- 切换前台 App 时自动解析绑定方案；关闭情景跟随不会删除已有绑定。
- HID 小键盘按 Vendor ID、Product ID、Serial 或 Location ID 组成设备 ID。
- 已连接和历史离线设备都会保留在配置中。

### 4.4 配置、备份与诊断

- 当前持久化结构为 `deviceConfigurations.v2`。
- 支持 JSON v2 导出，内容包括全部设备及其全部 Profile。
- 支持导入旧版 v1 单设备映射。
- 导入时校验不支持的版本、重复设备和重复按键。
- 运行事件持久写入 `~/Library/Logs/Voke/`，跨重启保留并按大小轮转。
- 设置页支持“导出日志”，内容包括版本、应用路径、权限状态、当前设备、前台 App、映射摘要、历史日志和近期崩溃报告。
- 诊断导出会隐藏终端命令正文和命令输出，避免直接泄露 Shell 配置。

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
- 已提供明亮、石墨、素描胶囊三套主题。
- 已实现手绘风格的手柄、键盘和鼠标映射面，并使用胶囊控件展示设备和当前动作。
- 手柄外廓和按键布局参考 Switch Pro Controller，但不是任天堂官方资产，也不是工业 CAD。

### 4.7 自动化测试

当前共有 55 项 XCTest，最近一次实跑全部通过。除原有快捷键、摇杆、HID 和备份测试外，现已覆盖：

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
- 旧 Profile 数据兼容与设备独立配置。
- 拒绝重复设备。
- ESC 预设作为普通键并正确显示。
- 中英文输入源动作的 JSON v2 备份往返。
- 鼠标移动规划、HID 鼠标/键盘类型识别。
- 深海主题偏好迁移为素描胶囊主题。
- 持久日志跨实例读取、轮转和终端命令脱敏。
- 前台 App 自动解析专属 Profile，并在无绑定时回退通用方案。
- 为当前 App 绑定、解除绑定已有 Profile。
- 暂停情景跟随后使用通用方案且不删除原有 App 绑定。
- App 绑定跨重启持久化，不同输入设备之间保持隔离。
- 删除 App 专属方案后安全回退到通用方案。
- 旧版 v2 Profile 没有 App 绑定字段时仍可导入。
- 拒绝同一设备内多个 Profile 重复绑定同一个 App。
- ChatGPT 专属方案不能成为微信等其他 App 的通用回退，也不能再次绑定给第二个 App。
- ChatGPT 当前 App 动作的默认快捷键注册与非 ChatGPT 隔离。
- Codex command ID 到快捷键的解析、自定义禁用、跨用户路径定位和文件修改实时刷新。
- 运行状态能够区分映射暂停、设备未连接、缺少输入监控、缺少辅助功能和真正就绪。

这些测试主要是逻辑单元测试，不等同于真实手柄、TCC 权限或 UI 自动化测试。

## 5. 没有完成的工作

真实设备与权限回归的当期执行结果、证据边界和待完成手柄清单见 [`REAL_DEVICE_PERMISSION_REGRESSION.md`](REAL_DEVICE_PERMISSION_REGRESSION.md)。

### 5.1 发布与升级链路（最高优先级）

- 没有 Apple Developer 证书。
- 没有 Developer ID Application 正式签名。
- 本地安装脚本会临时加上 Hardened Runtime，但没有基于 Developer ID 的正式签名、公证和 Stapling 流程。
- 已有通用架构测试 DMG；尚无 Developer ID 签名、公证的正式安装包或 PKG。
- 没有自动更新机制。
- 首次公开测试版使用 `v0.1.0`；早期 v0.2/v0.3 标签仅属于本地开发历史，没有推送到公开仓库。
- 本机 Release 已有固定自签名和固定安装路径；这不等同于可对外分发的 Apple Developer ID 签名。

### 5.2 Bundle ID 正式迁移

当前仍使用 `com.dolphin.ai-command-controller`，目的是继续读取旧 UserDefaults 并尽量延续权限。

正式发布前预计会改成类似 `com.dolphin.voke`，但不能直接改。直接修改会产生以下结果：

- 原映射、Profile、主题和 HID 学习结果不会自动出现在新域。
- 辅助功能和输入监控需要重新授权。
- macOS 会把新应用视为不同产品。

正确做法是在旧 Bundle ID 的最后一个版本或新版本首次启动时加入明确的数据迁移，并在真实签名条件下测试权限升级路径。

### 5.3 更多外设类型

当前支持 `GameController` 手柄，以及外接 HID 键盘类和鼠标类设备。以下没有实现：

- 鼠标滚轮作为独立输入源。
- MIDI 控制器。
- 旋钮、宏键盘等 Consumer Control/HID 非键盘 Usage Page 设备。
- Stream Deck 类专用协议设备。
- 内建 Mac 键盘作为可独立配置设备。

### 5.4 输入法/地球键专属动作

当前已提供独立的“中 / EN”输入源切换动作，但苹果地球键本身仍没有经过真实苹果键盘验证。快捷键模型能够记录 Fn flags 和 keyCode 63，这不等同于完整模拟地球键。

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

- 当前界面已经过一次简化；设备与 App 情景方案留在主界面，活动记录、备份和诊断集中到设置窗口，但尚未进行正式可用性测试。
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
- 为具体 App 编写不可配置的专用集成或控制协议。
- 与闪电说或其他语音软件做硬编码绑定。
- 在手柄完成前继续大规模扩展其他外设类别。
- 制造级手柄建模。

产品原则仍然是：用户配置通用输入与动作，Voke 不绑定某个具体 AI 或语音应用。

## 7. 已知问题与技术风险

### P0：缺少正式发布签名

本机安装脚本会复用固定的 `Voke Local Development` 自签名，因此开发机反复覆盖安装不再主动破坏权限记录。但它没有 Apple Team ID，不能替代 Developer ID、公证和面向其他 Mac 的升级验证。

2026-07-21 实测：`codesign` 验证通过且启用了 Hardened Runtime，但 `spctl --assess` 返回 `rejected`，`stapler validate` 确认没有公证票据。当前包不能视为可直接双击分发的外部测试安装包。

### P0：同 Bundle ID 多副本

旧版 `AI Command Controller.app` 和新版 `Voke.app` 如果同时存在或同时运行，由于 Bundle ID 相同，LaunchServices 和 TCC 可能识别到错误副本。测试前要完全退出旧版，并只保留一个待测副本。

### P1：相同型号多手柄的设备 ID 不稳定

GameController 设备 ID 主要根据设备名生成；同名设备通过连接顺序追加 `.2`、`.3`。如果多只相同型号手柄的连接顺序变化，Profile 可能对应到另一只实体手柄。需要寻找更稳定的硬件标识，或提供用户确认/重新绑定机制。

### P1：HID 设备 Location ID 可能变化

没有序列号的 HID 小键盘会使用 Location ID。更换 USB 端口、扩展坞或连接拓扑后，系统可能生成新的设备 ID，从而看起来像新设备。

### P1：小键盘原始输入不会被吞掉

当前是 IOHID 监听而非独占/拦截。映射会执行，但原始字符也会传给前台应用。要实现“只执行映射、不输入原字符”，需要更底层的事件抑制方案，并重新评估权限和安全性。

鼠标按键同样采用监听模式，原始点击可能与映射动作同时发生。鼠标移动和滚轮目前也不能作为独立触发器。

### P1：App 情景切换尚缺真实端到端回归

Bundle ID 路由和配置持久化已有单元测试，但尚未用闪电说、ChatGPT、浏览器浮层等多类真实 App 完成端到端回归。Voke 会忽略自身前台状态并保留最近的外部目标 App；如果目标 App 没有标准 Bundle ID，则只能使用通用方案。

### P1：特殊 App 窗口前置不保证

标准 Chrome、ChatGPT、微信等通常可以从切换条前置；菜单栏工具、浮层、无普通主窗口或自定义激活策略的 App 可能无法前置。这不是当前 App 切换实现可以普遍保证的能力。

### P1：命令执行边界

Shell 动作不经过 Sandbox，以当前用户权限执行。导入配置也可能带入 Shell 命令。当前导入流程没有逐条命令确认或信任提示，应在公开分发前补充安全设计。

### P2：公开版与内部开发历史

首次公开版本从 `v0.1.0` 开始。仓库历史中的早期 v0.2/v0.3 标记仅用于开发阶段，不代表已经对外发布。

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
| `contextualProfilesEnabled.v1` | 是否根据当前前台 App 自动选择情景方案 |

`mappingEnabled` 没有直接持久化；是否在启动后自动恢复由启动设置控制。

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
    HID[IOHID 键盘与鼠标] --> AM
    WS[NSWorkspace 前台 App] --> AM
    AM --> MS[MappingStore]
    MS --> UD[UserDefaults / JSON Backup]
    AM --> KO[KeyboardOutputService]
    KO --> KP[KeyboardEventPlanner]
    KO --> CG[CGEvent 键盘输出]
    AM --> SO[ScrollOutputService]
    SO --> CGS[CGEvent 滚动输出]
    AM --> MO[MouseOutputService]
    MO --> CGM[CGEvent 鼠标输出]
    AM --> DL[DiagnosticLogStore]
    DL --> LOG[Library/Logs/Voke]
    AM --> SH[ShellCommandService]
    SH --> ZSH[/bin/zsh -lc]
    AM --> UI[SwiftUI Dashboard]
    UI --> SURFACE[手绘手柄 / 键盘 / 鼠标映射面]
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
| `Voke/Services/HIDKeyboardService.swift` | 外接 HID 键盘/鼠标发现、分类、权限与按键学习 |
| `Voke/Services/ScrollOutputService.swift` | 连续滚动任务 |
| `Voke/Services/MouseOutputService.swift` | 连续鼠标移动和点击输出 |
| `Voke/Services/DiagnosticLogStore.swift` | 持久日志、轮转、脱敏与诊断导出 |
| `Voke/Services/ShellCommandService.swift` | ZSH 命令执行 |
| `Voke/Services/AudioDeviceService.swift` | 音频设备枚举，目前没有产品 UI |
| `Voke/Views/DashboardView.swift` | 响应式主界面、设备切换、工具栏和权限提示 |
| `Voke/Views/MappingStudio.swift` | 映射编辑器和快捷键录制 |
| `Voke/Views/*MappingSurface.swift` | 手绘手柄、键盘和鼠标映射面 |
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

最近一次结果：55 tests，0 failures。

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

本机测试请统一使用安装脚本；它会创建或复用固定的本地签名身份：

```bash
./scripts/install-local-app.sh
codesign --verify --deep --strict --verbose=2 /Applications/Voke.app
```

不要把这套本地自签名当作正式发布方案。

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
- 鼠标左右键、滚轮按键和侧键识别。
- 右摇杆连续移动鼠标、按压点击。
- 导出、清空测试环境、导入恢复。
- 重启应用后导出日志，确认能看到重启前后的事件。

### P1：清理并加固现有产品

1. 为 Shell 配置导入增加明确警告或信任确认。
2. 处理相同型号多手柄的稳定身份问题。
3. 给配置导入增加固定 fixture 和向后兼容测试。
4. 增加首次使用向导，把辅助功能、输入监控和映射总开关解释清楚。

### P2：再决定功能扩展

产品确认后再选择：

- 音频设备展示和切换动作。
- 苹果地球键/输入源专属动作。
- MIDI、旋钮和其他 HID 类型。
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
| `62e49c9` | 摇杆动作、诊断与回归测试（内部里程碑） |
| `83265b5` | App 切换确认机制修复（内部里程碑） |
| `46add5e` | 保持原生 App 切换条直到 Return（内部里程碑） |
| `b1ee26c` | 多设备、HID 小键盘、独立 Profile、主题（内部里程碑） |
| `24306cd` | 手柄模型轮廓调整（内部里程碑） |
| `deee940` | 对外应用名改为 Voke |
| `b691db3` | 工程、Module、目录全面改为 Voke |
| `v0.1.0` | 首次公开测试版与 GitHub DMG |
| `v0.1.1` | 修复公开测试包图标与下载缓存问题，升级至 Build 8 |
| `v0.4.0` | App 情景方案、Codex 动作、后台按键修复、真实设备与权限状态补强，升级至 Build 9 |

## 13. 接手人首日检查清单

- [ ] 阅读本文件和 `README.md`。
- [ ] 确认 `git status` 干净，记录当前 HEAD。
- [ ] 执行 `xcodegen generate`。
- [ ] 跑完 55 项测试。
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
