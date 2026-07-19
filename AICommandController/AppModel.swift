import AppKit
import Combine
import Foundation
import GameController
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    @Published var controllerName = "等待手柄"
    @Published var controllerConnected = false
    @Published var pressedButtons: Set<String> = []
    @Published var leftStick = CGPoint.zero
    @Published var rightStick = CGPoint.zero
    @Published var leftTrigger: Float = 0
    @Published var rightTrigger: Float = 0
    @Published var mappingEnabled = false {
        didSet {
            if !mappingEnabled {
                releaseAllOutputs()
            }
            addEvent(mappingEnabled ? "映射已启用" : "映射已安全关闭")
        }
    }
    @Published var events: [ControlEvent] = []
    @Published var audioDevices: [AudioDeviceInfo] = []
    @Published var activeApplication = "AI COMMAND"
    @Published var selectedControl: ControllerControl = .rightTrigger

    let keyboard = KeyboardOutputService()
    let mappingStore = MappingStore()
    private let audio = AudioDeviceService()
    private let shell = ShellCommandService()
    private let scroll = ScrollOutputService()
    private var observers: [NSObjectProtocol] = []
    private var audioTimer: Timer?
    private var appTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []
    private var started = false

    var inputDevices: [AudioDeviceInfo] { audioDevices.filter(\.hasInput) }
    var outputDevices: [AudioDeviceInfo] { audioDevices.filter(\.hasOutput) }
    var defaultInput: AudioDeviceInfo? { inputDevices.first(where: \.isDefaultInput) }
    var defaultOutput: AudioDeviceInfo? { outputDevices.first(where: \.isDefaultOutput) }

    init() {
        mappingStore.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    func start() {
        guard !started else { return }
        started = true
        // Since macOS 11.3, GameController stops delivering input while the app
        // is not frontmost unless background monitoring is explicitly enabled.
        // This app is designed to control whichever application is in front.
        GCController.shouldMonitorBackgroundEvents = true
        refreshAudio()
        refreshActiveApplication()
        observeControllers()

        audioTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshAudio() }
        }
        appTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshActiveApplication() }
        }

        GCController.startWirelessControllerDiscovery { [weak self] in
            Task { @MainActor in self?.attachFirstController() }
        }
        attachFirstController()
        addEvent("控制台已启动")

        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            guard let self, !self.keyboard.isAccessibilityTrusted else { return }
            self.keyboard.requestAccessibilityPermission()
            self.addEvent("已请求辅助功能权限")
        }
    }

    func stop() {
        releaseAllOutputs()
        audioTimer?.invalidate()
        appTimer?.invalidate()
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        GCController.stopWirelessControllerDiscovery()
        started = false
    }

    func requestAccessibility() {
        keyboard.requestAccessibilityPermission()
        objectWillChange.send()
    }

    func openAccessibilitySettings() {
        keyboard.openAccessibilitySettings()
    }

    private func observeControllers() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] note in
            guard let controller = note.object as? GCController else { return }
            Task { @MainActor in self?.configure(controller) }
        })
        observers.append(center.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] note in
            guard let controller = note.object as? GCController else { return }
            Task { @MainActor in self?.handleDisconnect(controller) }
        })
        observers.append(center.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.releaseAllOutputs() }
        })
    }

    private func attachFirstController() {
        if let controller = GCController.controllers().first { configure(controller) }
    }

    private func configure(_ controller: GCController) {
        controllerName = controller.vendorName ?? "游戏手柄"
        controllerConnected = true
        addEvent("已连接 \(controllerName)")

        guard let gamepad = controller.extendedGamepad else {
            addEvent("手柄不支持扩展按键协议")
            return
        }

        bind(gamepad.buttonA, name: "A")
        bind(gamepad.buttonB, name: "B")
        bind(gamepad.buttonX, name: "X")
        bind(gamepad.buttonY, name: "Y")
        bind(gamepad.leftShoulder, name: "L")
        bind(gamepad.rightShoulder, name: "R")
        bind(gamepad.leftThumbstickButton, name: "L3")
        bind(gamepad.rightThumbstickButton, name: "R3")
        bind(gamepad.buttonMenu, name: "+")
        bind(gamepad.buttonOptions, name: "−")
        if let home = gamepad.buttonHome { bind(home, name: "HOME") }

        gamepad.leftTrigger.valueChangedHandler = { [weak self] _, value, pressed in
            Task { @MainActor in
                self?.leftTrigger = value
                self?.setButton("ZL", pressed: pressed)
            }
        }
        gamepad.rightTrigger.valueChangedHandler = { [weak self] _, value, pressed in
            Task { @MainActor in
                guard let self else { return }
                self.rightTrigger = value
                self.setButton("ZR", pressed: pressed)
            }
        }
        gamepad.leftThumbstick.valueChangedHandler = { [weak self] _, x, y in
            Task { @MainActor in
                guard let self else { return }
                self.leftStick = CGPoint(x: CGFloat(x), y: CGFloat(y))
                self.updateStickDirections(x: x, y: y, left: true)
            }
        }
        gamepad.rightThumbstick.valueChangedHandler = { [weak self] _, x, y in
            Task { @MainActor in
                guard let self else { return }
                self.rightStick = CGPoint(x: CGFloat(x), y: CGFloat(y))
                self.updateStickDirections(x: x, y: y, left: false)
            }
        }
        gamepad.dpad.valueChangedHandler = { [weak self] _, x, y in
            Task { @MainActor in
                self?.setButton("↑", pressed: y > 0.5)
                self?.setButton("↓", pressed: y < -0.5)
                self?.setButton("→", pressed: x > 0.5)
                self?.setButton("←", pressed: x < -0.5)
            }
        }
    }

    private func bind(_ input: GCControllerButtonInput?, name: String) {
        input?.valueChangedHandler = { [weak self] _, _, pressed in
            Task { @MainActor in self?.setButton(name, pressed: pressed) }
        }
    }

    private func updateStickDirections(x: Float, y: Float, left: Bool) {
        let controls: [(ControllerControl, Float)] = left
            ? [(.leftStickUp, y), (.leftStickDown, -y), (.leftStickLeft, -x), (.leftStickRight, x)]
            : [(.rightStickUp, y), (.rightStickDown, -y), (.rightStickLeft, -x), (.rightStickRight, x)]
        for (control, value) in controls {
            let currentlyPressed = pressedButtons.contains(control.rawValue)
            setButton(
                control.rawValue,
                pressed: StickDirectionResolver.isPressed(value: value, currentlyPressed: currentlyPressed)
            )
        }
    }

    func exportMappings() {
        let panel = NSSavePanel()
        panel.title = "导出手柄配置"
        panel.nameFieldStringValue = "AI-Command-Controller-配置.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try mappingStore.exportData().write(to: url, options: .atomic)
            addEvent("配置已导出 · \(url.lastPathComponent)")
        } catch {
            addEvent("配置导出失败 · \(error.localizedDescription)")
        }
    }

    func importMappings() {
        let panel = NSOpenPanel()
        panel.title = "导入手柄配置"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try mappingStore.importData(Data(contentsOf: url))
            releaseAllOutputs()
            addEvent("配置已导入 · \(url.lastPathComponent)")
        } catch {
            addEvent("配置导入失败 · \(error.localizedDescription)")
        }
    }

    func copyDiagnostics() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(diagnosticReport(), forType: .string)
        addEvent("诊断信息已复制")
    }

    func diagnosticReport() -> String {
        let bundle = Bundle.main
        let shortVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let buildVersion = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        let bundleIdentifier = bundle.bundleIdentifier ?? "unknown"
        let configured = ControllerControl.allCases.compactMap { control -> String? in
            let mapping = mappingStore.mapping(for: control)
            guard mapping.actionKind != .none else { return nil }
            if mapping.actionKind == .shell {
                return "- \(control.rawValue): terminal command [redacted]"
            }
            return "- \(control.rawValue): \(mapping.summary) [\(mapping.triggerBehavior.rawValue)]"
        }
        let recentEvents = events.prefix(20).map {
            let message: String
            if $0.message.contains("→ $") {
                message = "terminal command invoked [redacted]"
            } else if $0.message.hasPrefix("命令退出") {
                message = "terminal command completed [output redacted]"
            } else {
                message = $0.message
            }
            return "- \($0.date.formatted(.iso8601)): \(message)"
        }
        return ([
            "AI Command Controller 诊断",
            "generatedAt: \(Date().formatted(.iso8601))",
            "appVersion: \(shortVersion) (\(buildVersion))",
            "bundleID: \(bundleIdentifier)",
            "appPath: \(bundle.bundleURL.path)",
            "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "accessibilityTrusted: \(keyboard.isAccessibilityTrusted)",
            "controllerConnected: \(controllerConnected)",
            "controllerName: \(controllerName)",
            "mappingEnabled: \(mappingEnabled)",
            "activeOutputCount: \(keyboard.activeOutputCount)",
            "frontmostApp: \(activeApplication)",
            "",
            "Configured mappings:"
        ] + configured + ["", "Recent events:"] + recentEvents).joined(separator: "\n")
    }

    private func setButton(_ name: String, pressed: Bool) {
        let changed: Bool
        if pressed {
            changed = pressedButtons.insert(name).inserted
        } else {
            changed = pressedButtons.remove(name) != nil
        }
        guard changed else { return }
        addEvent("\(name) \(pressed ? "按下" : "松开")")
        guard let control = ControllerControl(rawValue: name) else { return }
        if pressed { selectedControl = control }
        dispatchMapping(control, pressed: pressed)
    }

    private func dispatchMapping(_ control: ControllerControl, pressed: Bool) {
        let mapping = mappingStore.mapping(for: control)
        let outputID = "controller.\(control.rawValue)"

        guard mappingEnabled else {
            if !pressed {
                keyboard.release(id: outputID)
                scroll.release(id: outputID)
            }
            return
        }

        switch mapping.actionKind {
        case .none:
            return
        case .shortcut:
            guard let shortcut = mapping.shortcut else {
                if pressed { addEvent("\(control.rawValue) 尚未录制快捷键") }
                return
            }
            guard keyboard.isAccessibilityTrusted else {
                if pressed {
                    addEvent("\(control.rawValue) 被阻止 · 需要辅助功能权限")
                    keyboard.requestAccessibilityPermission()
                }
                return
            }
            switch mapping.triggerBehavior {
            case .tap:
                if pressed {
                    let resolvedName = keyboard.resolvedDisplayName(for: shortcut)
                    keyboard.tap(shortcut)
                    addEvent("\(control.rawValue) → \(resolvedName) @ \(activeApplication)")
                }
            case .hold:
                if pressed {
                    let resolvedName = keyboard.resolvedDisplayName(for: shortcut)
                    keyboard.press(shortcut, id: outputID)
                    addEvent("\(control.rawValue) → \(resolvedName) DOWN @ \(activeApplication)")
                } else {
                    keyboard.release(id: outputID)
                    addEvent("\(control.rawValue) → \(shortcut.displayName) UP")
                }
            }
        case .scroll:
            guard keyboard.isAccessibilityTrusted else {
                if pressed {
                    addEvent("\(control.rawValue) 滚动被阻止 · 需要辅助功能权限")
                    keyboard.requestAccessibilityPermission()
                }
                return
            }
            let direction = mapping.scrollDirection ?? control.defaultScrollDirection ?? .down
            if pressed {
                scroll.press(direction: direction, id: outputID)
                addEvent("\(control.rawValue) → 滚动\(direction.title)")
            } else {
                scroll.release(id: outputID)
            }
        case .appSwitch:
            guard pressed else { return }
            guard keyboard.isAccessibilityTrusted else {
                addEvent("\(control.rawValue) 切换被阻止 · 需要辅助功能权限")
                keyboard.requestAccessibilityPermission()
                return
            }
            let direction = mapping.appSwitchDirection ?? .next
            let modifiers: NSEvent.ModifierFlags = direction == .next ? [.command] : [.command, .shift]
            let shortcut = KeyboardShortcut(keyCode: 48, modifierFlags: modifiers.rawValue, modifierOnly: false)
            keyboard.tapGlobal(shortcut)
            addEvent("\(control.rawValue) → \(direction.title)")
        case .shell:
            guard pressed else { return }
            let command = mapping.shellCommand.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !command.isEmpty else {
                addEvent("\(control.rawValue) 尚未填写终端命令")
                return
            }
            addEvent("\(control.rawValue) → $ \(command)")
            Task { [weak self] in
                guard let self else { return }
                let result = await self.shell.run(command)
                let detail = result.output.isEmpty ? "无输出" : result.output.replacingOccurrences(of: "\n", with: " · ")
                self.addEvent("命令退出 \(result.exitCode) · \(detail)")
            }
        }
    }

    private func handleDisconnect(_ controller: GCController) {
        releaseAllOutputs()
        controllerConnected = false
        controllerName = "等待手柄"
        pressedButtons.removeAll()
        leftTrigger = 0
        rightTrigger = 0
        addEvent("手柄已断开 · 按键已释放")
        attachFirstController()
    }

    private func refreshAudio() {
        audioDevices = audio.readDevices()
    }

    private func releaseAllOutputs() {
        keyboard.releaseAll()
        scroll.releaseAll()
    }

    private func refreshActiveApplication() {
        activeApplication = NSWorkspace.shared.frontmostApplication?.localizedName ?? "桌面"
    }

    private func addEvent(_ message: String) {
        events.insert(ControlEvent(message: message), at: 0)
        if events.count > 100 { events.removeLast(events.count - 100) }
    }
}

struct ControlEvent: Identifiable {
    let id = UUID()
    let message: String
    let date = Date()
}
