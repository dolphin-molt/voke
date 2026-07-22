# Codex / ChatGPT 控制能力调研

> 核对时间：2026-07-22（Asia/Shanghai）

## 结论

Voke 可以可靠实现“按当前 App 自动切换设备方案”，并通过动作 ID 控制 Codex、ChatGPT 或其他应用。它是一套通用能力，适用于手柄、外接 HID 键盘和鼠标按键。

本机 ChatGPT/Codex 客户端提供“新建任务”“模型与推理选择器”“听写”和“语音模式”的默认快捷键，Voke 已将它们加入当前 App 动作。客户端也定义了提高、降低和循环推理强度命令，但默认没有分配快捷键；用户只需在 Codex 设置一次，Voke 会从 `keybindings.json` 自动同步，不通过不稳定的坐标点击伪造直接控制。

## 已确认可以稳定实现

- 按前台 App 的 Bundle ID 自动选择专属方案。
- 同一输入设备为不同 App 保存不同映射。
- 手柄、外接 HID 键盘和鼠标按键使用同一套方案模型。
- 使用系统级键盘事件发送目标 App 已支持的单键、组合键和修饰键。
- 在 App 切换时释放持续按下的输出，避免状态跨方案残留。
- 通过 JSON v2 备份并恢复 App 绑定；旧 v2 配置继续兼容。

## Codex 当前观察结果

- 本机客户端的 macOS 菜单提供“Keyboard Shortcuts”，但没有“Reasoning Effort”或推理强度菜单命令。
- 本机客户端资源中存在听写相关命令标识，例如开始听写、全局按住听写和全局切换听写。
- 客户端资源中存在可用推理强度选择设置，并会按模型能力展示不同档位；这是应用内部 UI，不等同于公开外部控制接口。
- 本机客户端当前默认快捷键：新建任务 `⌘N`、模型与推理选择器 `⌃⇧M`、开始听写 `⌃⇧D`、语音模式 `⌃⇧V`。
- `increaseReasoningEffort`、`decreaseReasoningEffort`、`cycleReasoningEffort` 命令存在，但当前版本没有默认快捷键。
- Codex 客户端源码确认自定义快捷键保存在 `CODEX_HOME/keybindings.json`；未设置 `CODEX_HOME` 时使用当前 macOS 用户的 `~/.codex/keybindings.json`。
- 文件格式是 `{ "command": String, "key": String? }` 数组；同一 command 可以有多个键，`key: null` 表示显式禁用该动作的快捷键。
- Codex 设置页通过 `set-codex-command-keybinding` 更新该文件；Voke 不修改它，只读取并监听所在目录的文件系统事件。
- Codex 官方用例资料包含 Computer Use 驱动 Mac 界面的工作流，但这不构成面向 Voke 的稳定推理强度 API。

## Codex Micro 本机对标结果

本机安装的 Codex `26.715.70719` 已包含 Codex Micro 的布局和设备服务。Voke 以其中的 command ID 为准建立“Codex Micro 高频核心”和“Codex Micro 同款动作”两组入口，而不是根据宣传图片猜测键帽含义。

已纳入 Voke 的 command-backed 动作包括：

- Fast mode、接受、拒绝、分支任务、按住说话、发送、新建任务。
- 提高和降低推理强度。
- 反馈、终端、复制任务 Markdown、归档、浏览器标签、置顶、审查面板。
- 环境动作、Git 提交、创建 Pull Request、添加图片、设置、侧边任务、任务管理。
- 打开文件夹、添加文件和 Skills。

Codex Micro 还包含打开外部网址、向输入框写入固定文本及纯自定义快捷键键帽。这三类不是 Codex command，因此继续由 Voke 现有的系统、快捷键和终端命令能力承载，不伪装成可自动同步的 Codex 动作。

Voke 当前不能复制 Codex Micro 的六个任务状态灯和直接 HID 命令通道。Codex Micro 使用专用设备协议接收任务状态并直接调用内部 command；普通手柄只能通过用户当前的 Codex 快捷键间接触发。因此，没有默认快捷键的动作会明确显示“需先在 Codex 设置”，设置后由 Voke 自动同步。

## 产品实现原则

1. Codex 动作映射保存 command ID；快捷键只存在于运行时缓存，不作为 Voke 配置的事实来源。
2. 首次启动读取配置，文件创建、写入、原子替换、删除时即时刷新；前台 App 变化时再做一次兜底校验。手柄触发只查内存，不临时读盘。
3. 路径优先使用进程环境中的 `CODEX_HOME`，再使用当前用户 Home 和 Application Support 候选目录；不写死用户名。
4. 目标 App 提供 URL Scheme、App Intent、AppleScript、CLI 或公开 API 时：再增加对应的通用动作适配器。
5. 只有内部 UI、没有稳定接口时：可以做明确标注的实验性自动化，但不能默认开启，也不能承诺跨版本稳定。
6. Voke 只读快捷键配置，不修改 Codex 文件，也不把配置文件当作绕过目标 App 权限的接口。

## 后续启用条件

当 Codex 为听写、模型或推理强度提供公开快捷键或自动化接口后，只需要在 Voke 的现有动作层增加对应适配，不需要重做 App 情景方案和设备模型。
