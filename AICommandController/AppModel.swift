import AppKit
import Combine
import Foundation
import GameController

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
            if !mappingEnabled { keyboard.releaseAll() }
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
    private var observers: [NSObjectProtocol] = []
    private var audioTimer: Timer?
    private var appTimer: Timer?
    private var started = false

    var inputDevices: [AudioDeviceInfo] { audioDevices.filter(\.hasInput) }
    var outputDevices: [AudioDeviceInfo] { audioDevices.filter(\.hasOutput) }
    var defaultInput: AudioDeviceInfo? { inputDevices.first(where: \.isDefaultInput) }
    var defaultOutput: AudioDeviceInfo? { outputDevices.first(where: \.isDefaultOutput) }

    func start() {
        guard !started else { return }
        started = true
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
        keyboard.releaseAll()
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
            Task { @MainActor in self?.leftStick = CGPoint(x: CGFloat(x), y: CGFloat(y)) }
        }
        gamepad.rightThumbstick.valueChangedHandler = { [weak self] _, x, y in
            Task { @MainActor in self?.rightStick = CGPoint(x: CGFloat(x), y: CGFloat(y)) }
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
            if !pressed { keyboard.release(id: outputID) }
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
                    keyboard.tap(shortcut)
                    addEvent("\(control.rawValue) → \(shortcut.displayName)")
                }
            case .hold:
                if pressed {
                    keyboard.press(shortcut, id: outputID)
                    addEvent("\(control.rawValue) → \(shortcut.displayName) DOWN")
                } else {
                    keyboard.release(id: outputID)
                    addEvent("\(control.rawValue) → \(shortcut.displayName) UP")
                }
            }
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
        keyboard.releaseAll()
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

    private func refreshActiveApplication() {
        activeApplication = NSWorkspace.shared.frontmostApplication?.localizedName ?? "桌面"
    }

    private func addEvent(_ message: String) {
        events.insert(ControlEvent(message: message), at: 0)
        if events.count > 8 { events.removeLast(events.count - 8) }
    }
}

struct ControlEvent: Identifiable {
    let id = UUID()
    let message: String
    let date = Date()
}
