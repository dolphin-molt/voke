import AppKit
import Foundation

enum ApplicationActionInteraction: Equatable {
    case tap
    case pressAndHold
}

enum ApplicationActionGroup: String, CaseIterable, Identifiable {
    case codexMicroCore
    case codexMicroLibrary
    case codexGeneral

    var id: String { rawValue }

    var title: String {
        switch self {
        case .codexMicroCore: "Codex Micro 高频核心"
        case .codexMicroLibrary: "Codex Micro 同款动作"
        case .codexGeneral: "更多 Codex 动作"
        }
    }
}

struct ApplicationActionPreset: Identifiable, Equatable {
    let id: String
    let commandID: String
    let title: String
    let detail: String
    let group: ApplicationActionGroup
    let bundleIdentifiers: Set<String>
    let fallbackAccelerators: [String]
    let interaction: ApplicationActionInteraction

    func supports(_ bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return bundleIdentifiers.contains(bundleIdentifier)
    }

    /// Used only when Codex has no custom entry in keybindings.json.
    var defaultShortcut: KeyboardShortcut? {
        fallbackAccelerators.lazy.compactMap(CodexAcceleratorParser.parse).first
    }
}

enum ApplicationActionRegistry {
    static let chatGPTBundleIdentifiers: Set<String> = [
        "com.openai.codex",
        "com.openai.chat"
    ]

    // This list mirrors the command-backed keycaps bundled with Codex Micro in
    // the installed Codex app. Voke stores these stable command IDs and resolves
    // the user's current shortcut only when the mapping is executed.
    private static let codexMicroCorePresets: [ApplicationActionPreset] = [
        chatGPT("chatgpt.toggleFastMode", "composer.toggleFastMode", "切换快速模式", "打开或关闭 Fast mode", group: .codexMicroCore),
        chatGPT("chatgpt.approve", "approval.approve", "接受修改", "接受当前等待中的修改或请求", ["Enter"], group: .codexMicroCore),
        chatGPT("chatgpt.decline", "approval.decline", "拒绝输出", "拒绝当前等待中的修改或请求", ["Escape"], group: .codexMicroCore),
        chatGPT("chatgpt.forkThread", "forkThread", "继续到新任务", "从当前任务分支出一个新任务", group: .codexMicroCore),
        chatGPT(
            "chatgpt.startDictation",
            "composer.startDictation",
            "按住说话",
            "按住控制器按键开始听写，松开结束",
            ["Ctrl+Shift+D"],
            group: .codexMicroCore,
            interaction: .pressAndHold
        ),
        chatGPT("chatgpt.submit", "composer.submit", "发送消息", "发送当前输入内容", group: .codexMicroCore),
        chatGPT("chatgpt.newTask", "newTask", "新建任务", "新建一个 Codex 任务", ["CmdOrCtrl+N", "CmdOrCtrl+Shift+O"], group: .codexMicroCore),
        chatGPT("chatgpt.increaseReasoning", "composer.increaseReasoningEffort", "提高推理强度", "提高当前任务的推理强度", group: .codexMicroCore),
        chatGPT("chatgpt.decreaseReasoning", "composer.decreaseReasoningEffort", "降低推理强度", "降低当前任务的推理强度", group: .codexMicroCore)
    ]

    private static let codexMicroLibraryPresets: [ApplicationActionPreset] = [
        chatGPT("chatgpt.feedback", "feedback", "发送反馈", "打开 Codex 反馈入口", group: .codexMicroLibrary),
        chatGPT("chatgpt.toggleTerminal", "toggleTerminal", "打开终端", "打开或关闭终端面板", ["Control+`"], group: .codexMicroLibrary),
        chatGPT("chatgpt.copyConversationMarkdown", "copyConversationMarkdown", "复制任务 Markdown", "以 Markdown 格式复制当前任务", group: .codexMicroLibrary),
        chatGPT("chatgpt.archiveThread", "archiveThread", "归档任务", "归档当前任务", ["CmdOrCtrl+Shift+A"], group: .codexMicroLibrary),
        chatGPT("chatgpt.openBrowserTab", "openBrowserTab", "新建浏览器标签", "在 Codex 内打开浏览器标签", ["CmdOrCtrl+T"], group: .codexMicroLibrary),
        chatGPT("chatgpt.toggleThreadPin", "toggleThreadPin", "切换置顶状态", "置顶或取消置顶当前任务", ["CmdOrCtrl+Alt+P"], group: .codexMicroLibrary),
        chatGPT("chatgpt.toggleReviewTab", "toggleReviewTab", "切换审查面板", "打开或关闭代码审查面板", group: .codexMicroLibrary),
        chatGPT("chatgpt.environmentAction1", "environmentAction1", "运行环境动作", "运行当前环境的第一个动作", ["Command+Shift+D"], group: .codexMicroLibrary),
        chatGPT("chatgpt.gitCommit", "git.commit", "创建 Git 提交", "在当前工作区创建提交", group: .codexMicroLibrary),
        chatGPT("chatgpt.createPullRequest", "git.createPullRequest", "创建 Pull Request", "为当前分支创建 Pull Request", group: .codexMicroLibrary),
        chatGPT("chatgpt.addPhotos", "composer.addPhotos", "添加图片", "向当前任务添加图片", group: .codexMicroLibrary),
        chatGPT("chatgpt.settings", "settings", "打开设置", "打开 Codex 设置", ["CmdOrCtrl+,"], group: .codexMicroLibrary),
        chatGPT("chatgpt.openSideChat", "openSideChat", "作为侧边任务打开", "把当前任务作为侧边任务打开", ["CmdOrCtrl+Alt+S"], group: .codexMicroLibrary),
        chatGPT("chatgpt.manageTasks", "manageTasks", "管理任务", "打开 Codex 任务管理", group: .codexMicroLibrary),
        chatGPT("chatgpt.openFolder", "openFolder", "打开文件夹", "在 Codex 中打开文件夹", ["CmdOrCtrl+O"], group: .codexMicroLibrary),
        chatGPT("chatgpt.addFiles", "composer.addFiles", "添加文件", "向当前任务添加文件或文件夹", group: .codexMicroLibrary),
        chatGPT("chatgpt.openSkills", "openSkills", "打开 Skills", "打开 Codex Skills 页面", group: .codexMicroLibrary)
    ]

    private static let codexGeneralPresets: [ApplicationActionPreset] = [
        chatGPT("chatgpt.newStandaloneTask", "newProjectlessTask", "新建独立任务", "在项目之外新建任务", ["CmdOrCtrl+Alt+O"]),
        chatGPT("chatgpt.openModelPicker", "composer.openModelPicker", "模型与推理选择器", "打开模型与推理强度选择器", ["Ctrl+Shift+M"]),
        chatGPT("chatgpt.cycleReasoning", "composer.cycleReasoningEffort", "循环推理强度", "在可用推理强度之间循环"),
        chatGPT("chatgpt.togglePlanMode", "composer.togglePlanMode", "切换计划模式", "打开或关闭 Plan mode"),
        chatGPT("chatgpt.toggleVoiceMode", "composer.startVoiceMode", "切换语音模式", "打开或关闭语音模式", ["Ctrl+Shift+V"]),
        chatGPT("chatgpt.toggleSidebar", "toggleSidebar", "切换侧边栏", "显示或隐藏侧边栏", ["CmdOrCtrl+B"])
    ]

    static let presets = codexMicroCorePresets + codexMicroLibraryPresets + codexGeneralPresets

    static func actions(for bundleIdentifier: String?) -> [ApplicationActionPreset] {
        presets.filter { $0.supports(bundleIdentifier) }
    }

    static func preset(id: String?) -> ApplicationActionPreset? {
        guard let id else { return nil }
        return presets.first { $0.id == id }
    }

    private static func chatGPT(
        _ id: String,
        _ commandID: String,
        _ title: String,
        _ detail: String,
        _ fallbackAccelerators: [String] = [],
        group: ApplicationActionGroup = .codexGeneral,
        interaction: ApplicationActionInteraction = .tap
    ) -> ApplicationActionPreset {
        ApplicationActionPreset(
            id: id,
            commandID: commandID,
            title: title,
            detail: detail,
            group: group,
            bundleIdentifiers: chatGPTBundleIdentifiers,
            fallbackAccelerators: fallbackAccelerators,
            interaction: interaction
        )
    }
}

enum CodexAcceleratorParser {
    static func parse(_ accelerator: String) -> KeyboardShortcut? {
        let trimmed = accelerator.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(" ") else { return nil }

        let components = trimmed.split(separator: "+").map(String.init)
        guard let keyToken = components.last, !keyToken.isEmpty else { return nil }

        var modifiers: NSEvent.ModifierFlags = []
        for rawModifier in components.dropLast() {
            switch rawModifier.lowercased() {
            case "cmd", "command", "meta", "super", "cmdorctrl", "commandorcontrol":
                modifiers.insert(.command)
            case "ctrl", "control":
                modifiers.insert(.control)
            case "alt", "option":
                modifiers.insert(.option)
            case "shift":
                modifiers.insert(.shift)
            case "fn", "function":
                modifiers.insert(.function)
            default:
                return nil
            }
        }

        guard let keyCode = keyCode(for: keyToken) else { return nil }
        return KeyboardShortcut(keyCode: keyCode, modifierFlags: modifiers.rawValue, modifierOnly: false)
    }

    private static func keyCode(for token: String) -> UInt16? {
        let normalized = token.lowercased()
        if normalized.count == 1, let character = normalized.first {
            let characters: [Character: UInt16] = [
                "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
                "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
                "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
                "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,
                "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "l": 37,
                "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44,
                "n": 45, "m": 46, ".": 47, "`": 50
            ]
            return characters[character]
        }

        return [
            "enter": 36, "return": 36, "tab": 48, "space": 49,
            "backspace": 51, "delete": 51, "escape": 53, "esc": 53,
            "left": 123, "arrowleft": 123, "right": 124, "arrowright": 124,
            "down": 125, "arrowdown": 125, "up": 126, "arrowup": 126,
            "home": 115, "end": 119, "pageup": 116, "pagedown": 121,
            "forwarddelete": 117
        ][normalized]
    }
}
