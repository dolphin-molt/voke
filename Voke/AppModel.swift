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
    @Published var launchMappingAutomatically = UserDefaults.standard.object(forKey: "launchMappingAutomatically.v1") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(launchMappingAutomatically, forKey: "launchMappingAutomatically.v1")
            if launchMappingAutomatically { mappingEnabled = true }
        }
    }
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var launchAtLoginStatus = "正在读取状态"
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
    @Published var activeApplication = "桌面"
    @Published var selectedControl: ControllerControl = .rightTrigger
    @Published private(set) var devices: [InputDeviceDescriptor] = []
    @Published private(set) var selectedDeviceID: String?

    let keyboard = KeyboardOutputService()
    let mappingStore = MappingStore()
    private let audio = AudioDeviceService()
    private let shell = ShellCommandService()
    private let scroll = ScrollOutputService()
    private let mouse = MouseOutputService()
    private let inputSource = InputSourceService()
    private let launchAtLogin = LaunchAtLoginService()
    private let diagnosticLog = DiagnosticLogStore()
    private let hid = HIDInputService()
    private var controllerDeviceIDs: [ObjectIdentifier: String] = [:]
    private var pressedByDevice: [String: Set<String>] = [:]
    private var observers: [NSObjectProtocol] = []
    private var audioTimer: Timer?
    private var appTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []
    private var started = false

    var inputDevices: [AudioDeviceInfo] { audioDevices.filter(\.hasInput) }
    var outputDevices: [AudioDeviceInfo] { audioDevices.filter(\.hasOutput) }
    var defaultInput: AudioDeviceInfo? { inputDevices.first(where: \.isDefaultInput) }
    var defaultOutput: AudioDeviceInfo? { outputDevices.first(where: \.isDefaultOutput) }
    var selectedDevice: InputDeviceDescriptor? { devices.first { $0.id == selectedDeviceID } }
    var selectedDeviceControls: [ControllerControl] { selectedDevice?.controls ?? ControllerControl.gamepadControls }
    var inputMonitoringGranted: Bool { hid.inputMonitoringGranted }

    init() {
        mappingStore.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        hid.onDevicesChanged = { [weak self] devices in
            self?.updateHIDDevices(devices)
        }
        hid.onControlChanged = { [weak self] deviceID, control, pressed in
            self?.setButton(control.rawValue, pressed: pressed, deviceID: deviceID)
        }
    }

    func start() {
        guard !started else { return }
        started = true
        mappingEnabled = launchMappingAutomatically
        refreshLaunchAtLoginStatus()
        // Since macOS 11.3, GameController stops delivering input while the app
        // is not frontmost unless background monitoring is explicitly enabled.
        // This app is designed to control whichever application is in front.
        GCController.shouldMonitorBackgroundEvents = true
        refreshAudio()
        refreshActiveApplication()
        observeControllers()
        hid.start()

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
        hid.stop()
        started = false
    }

    func requestAccessibility() {
        keyboard.requestAccessibilityPermission()
        objectWillChange.send()
    }

    func openAccessibilitySettings() {
        keyboard.openAccessibilitySettings()
    }

    func requestInputMonitoring() {
        hid.requestInputMonitoring()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
        objectWillChange.send()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try launchAtLogin.setEnabled(enabled)
            refreshLaunchAtLoginStatus()
            addEvent(enabled ? "已启用登录时自动启动" : "已关闭登录时自动启动")
        } catch {
            refreshLaunchAtLoginStatus()
            addEvent("无法修改登录启动项 · \(error.localizedDescription)")
        }
    }

    func selectDevice(_ deviceID: String) {
        guard let device = devices.first(where: { $0.id == deviceID }) else { return }
        selectedDeviceID = deviceID
        mappingStore.selectDevice(deviceID)
        pressedButtons = pressedByDevice[deviceID] ?? []
        if !device.controls.contains(selectedControl) {
            selectedControl = device.controls.first ?? .rightTrigger
        }
        addEvent("正在配置 \(device.name)")
    }

    func controlLabel(_ control: ControllerControl) -> String {
        selectedDevice?.controlLabels[control] ?? control.compactLabel
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
        GCController.controllers().forEach(configure)
    }

    private func configure(_ controller: GCController) {
        let objectID = ObjectIdentifier(controller)
        let deviceID: String
        if let existing = controllerDeviceIDs[objectID] {
            deviceID = existing
        } else {
            let name = controller.vendorName ?? controller.productCategory
            let base = "gamepad.\(Self.identifierComponent(name))"
            let used = Set(controllerDeviceIDs.values)
            var candidate = base
            var suffix = 2
            while used.contains(candidate) {
                candidate = "\(base).\(suffix)"
                suffix += 1
            }
            deviceID = candidate
            controllerDeviceIDs[objectID] = deviceID
        }

        let baseName = controller.vendorName ?? "游戏手柄"
        let baseID = "gamepad.\(Self.identifierComponent(baseName))"
        let suffix = deviceID == baseID ? nil : deviceID.split(separator: ".").last.map(String.init)
        controllerName = suffix.map { "\(baseName) · \($0)" } ?? baseName
        controllerConnected = true
        let descriptor = InputDeviceDescriptor(
            id: deviceID,
            name: controllerName,
            kind: .gameController,
            connected: true,
            controls: ControllerControl.gamepadControls
        )
        upsertDevice(descriptor)
        mappingStore.registerDevice(descriptor)
        synchronizeSelectedDevice(preferredConnectedID: deviceID)
        addEvent("已连接 \(controllerName)")

        guard let gamepad = controller.extendedGamepad else {
            addEvent("手柄不支持扩展按键协议")
            return
        }

        bind(gamepad.buttonA, name: "A", deviceID: deviceID)
        bind(gamepad.buttonB, name: "B", deviceID: deviceID)
        bind(gamepad.buttonX, name: "X", deviceID: deviceID)
        bind(gamepad.buttonY, name: "Y", deviceID: deviceID)
        bind(gamepad.leftShoulder, name: "L", deviceID: deviceID)
        bind(gamepad.rightShoulder, name: "R", deviceID: deviceID)
        bind(gamepad.leftThumbstickButton, name: "L3", deviceID: deviceID)
        bind(gamepad.rightThumbstickButton, name: "R3", deviceID: deviceID)
        bind(gamepad.buttonMenu, name: "+", deviceID: deviceID)
        bind(gamepad.buttonOptions, name: "−", deviceID: deviceID)
        if let home = gamepad.buttonHome { bind(home, name: "HOME", deviceID: deviceID) }
        if let share = controller.physicalInputProfile.buttons[GCInputButtonShare] {
            bind(share, name: "CAPTURE", deviceID: deviceID)
        }

        gamepad.leftTrigger.valueChangedHandler = { [weak self] _, value, pressed in
            Task { @MainActor in
                self?.leftTrigger = value
                self?.setButton("ZL", pressed: pressed, deviceID: deviceID)
            }
        }
        gamepad.rightTrigger.valueChangedHandler = { [weak self] _, value, pressed in
            Task { @MainActor in
                guard let self else { return }
                self.rightTrigger = value
                self.setButton("ZR", pressed: pressed, deviceID: deviceID)
            }
        }
        gamepad.leftThumbstick.valueChangedHandler = { [weak self] _, x, y in
            Task { @MainActor in
                guard let self else { return }
                self.leftStick = CGPoint(x: CGFloat(x), y: CGFloat(y))
                self.updateStickDirections(x: x, y: y, left: true, deviceID: deviceID)
            }
        }
        gamepad.rightThumbstick.valueChangedHandler = { [weak self] _, x, y in
            Task { @MainActor in
                guard let self else { return }
                self.rightStick = CGPoint(x: CGFloat(x), y: CGFloat(y))
                self.mouse.updateStick(
                    x: x,
                    y: y,
                    enabled: self.mappingEnabled && self.rightStickControlsMouse(deviceID: deviceID)
                )
                self.updateStickDirections(x: x, y: y, left: false, deviceID: deviceID)
            }
        }
        gamepad.dpad.valueChangedHandler = { [weak self] _, x, y in
            Task { @MainActor in
                self?.setButton("↑", pressed: y > 0.5, deviceID: deviceID)
                self?.setButton("↓", pressed: y < -0.5, deviceID: deviceID)
                self?.setButton("→", pressed: x > 0.5, deviceID: deviceID)
                self?.setButton("←", pressed: x < -0.5, deviceID: deviceID)
            }
        }
    }

    private func bind(_ input: GCControllerButtonInput?, name: String, deviceID: String) {
        input?.valueChangedHandler = { [weak self] _, _, pressed in
            Task { @MainActor in self?.setButton(name, pressed: pressed, deviceID: deviceID) }
        }
    }

    private func updateStickDirections(x: Float, y: Float, left: Bool, deviceID: String) {
        let controls: [(ControllerControl, Float)] = left
            ? [(.leftStickUp, y), (.leftStickDown, -y), (.leftStickLeft, -x), (.leftStickRight, x)]
            : [(.rightStickUp, y), (.rightStickDown, -y), (.rightStickLeft, -x), (.rightStickRight, x)]
        for (control, value) in controls {
            let currentlyPressed = pressedByDevice[deviceID, default: []].contains(control.rawValue)
            setButton(
                control.rawValue,
                pressed: StickDirectionResolver.isPressed(value: value, currentlyPressed: currentlyPressed),
                deviceID: deviceID
            )
        }
    }

    func exportMappings() {
        let panel = NSSavePanel()
        panel.title = "导出手柄配置"
        panel.nameFieldStringValue = "Voke-配置.json"
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

    func exportDiagnostics() {
        let panel = NSSavePanel()
        panel.title = "导出 Voke 日志"
        panel.nameFieldStringValue = "Voke-诊断-\(Self.exportTimestamp()).txt"
        panel.allowedContentTypes = [.plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let contents = diagnosticLog.exportText(diagnosticReport: diagnosticReport())
            try contents.write(to: url, atomically: true, encoding: .utf8)
            addEvent("诊断日志已导出 · \(url.lastPathComponent)")
        } catch {
            addEvent("诊断日志导出失败 · \(error.localizedDescription)")
        }
    }

    func diagnosticReport() -> String {
        let bundle = Bundle.main
        let shortVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let buildVersion = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        let bundleIdentifier = bundle.bundleIdentifier ?? "unknown"
        let configured = mappingStore.mappings.values.sorted { $0.control.rawValue < $1.control.rawValue }.compactMap { mapping -> String? in
            guard mapping.actionKind != .none else { return nil }
            if mapping.actionKind == .shell {
                return "- \(mapping.control.rawValue): terminal command [redacted]"
            }
            return "- \(mapping.control.rawValue): \(mapping.summary) [\(mapping.triggerBehavior.rawValue)]"
        }
        let recentEvents = events.prefix(20).map {
            "- \($0.date.formatted(.iso8601)): \(DiagnosticLogStore.redact($0.message))"
        }
        return ([
            "Voke 诊断",
            "generatedAt: \(Date().formatted(.iso8601))",
            "appVersion: \(shortVersion) (\(buildVersion))",
            "bundleID: \(bundleIdentifier)",
            "appPath: \(bundle.bundleURL.path)",
            "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "accessibilityTrusted: \(keyboard.isAccessibilityTrusted)",
            "inputMonitoringGranted: \(inputMonitoringGranted)",
            "controllerConnected: \(controllerConnected)",
            "controllerName: \(controllerName)",
            "selectedDevice: \(selectedDevice?.name ?? "none") [\(selectedDeviceID ?? "none")]",
            "selectedDeviceKind: \(selectedDevice?.kind.rawValue ?? "none")",
            "activeProfile: \(mappingStore.activeProfileName)",
            "knownDevices: \(devices.map { "\($0.name):\($0.connected ? "connected" : "offline")" }.joined(separator: ", "))",
            "mappingEnabled: \(mappingEnabled)",
            "activeOutputCount: \(keyboard.activeOutputCount)",
            "frontmostApp: \(activeApplication)",
            "persistentLogDirectory: \(diagnosticLog.logDirectoryPath)",
            "",
            "Configured mappings:"
        ] + configured + ["", "Recent events:"] + recentEvents).joined(separator: "\n")
    }

    private func setButton(_ name: String, pressed: Bool, deviceID: String) {
        var deviceButtons = pressedByDevice[deviceID, default: []]
        let changed: Bool
        if pressed {
            changed = deviceButtons.insert(name).inserted
        } else {
            changed = deviceButtons.remove(name) != nil
        }
        pressedByDevice[deviceID] = deviceButtons
        if deviceID == selectedDeviceID { pressedButtons = deviceButtons }
        guard changed else { return }
        addEvent("\(name) \(pressed ? "按下" : "松开")")
        guard let control = ControllerControl(rawValue: name) else { return }
        if pressed, deviceID == selectedDeviceID { selectedControl = control }
        dispatchMapping(control, pressed: pressed, deviceID: deviceID)
    }

    private func dispatchMapping(_ control: ControllerControl, pressed: Bool, deviceID: String) {
        let mapping = mappingStore.mapping(for: control, deviceID: deviceID)
        let outputID = "input.\(deviceID).\(control.rawValue)"

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
            if pressed {
                switch keyboard.handleApplicationSwitcherShortcut(shortcut) {
                case .confirmed:
                    addEvent("\(control.rawValue) → 确认 App 选择")
                    return
                case .cancelled:
                    addEvent("\(control.rawValue) → 取消 App 选择")
                    return
                case .none:
                    break
                }
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
        case .inputSource:
            guard pressed else { return }
            if let selectedName = inputSource.toggleChineseEnglish() {
                addEvent("\(control.rawValue) → 切换到 \(selectedName)")
            } else {
                addEvent("\(control.rawValue) → 未找到可切换的中英文输入源")
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
        case .mouseMove:
            // Raw thumbstick values drive the cursor continuously in the
            // controller callback; directional transitions only update UI.
            return
        case .mouseClick:
            guard pressed else { return }
            guard keyboard.isAccessibilityTrusted else {
                addEvent("\(control.rawValue) 点击被阻止 · 需要辅助功能权限")
                keyboard.requestAccessibilityPermission()
                return
            }
            mouse.clickLeft()
            addEvent("\(control.rawValue) → 鼠标左键")
        case .appSwitch:
            guard pressed else { return }
            guard keyboard.isAccessibilityTrusted else {
                addEvent("\(control.rawValue) 切换被阻止 · 需要辅助功能权限")
                keyboard.requestAccessibilityPermission()
                return
            }
            let direction = mapping.appSwitchDirection ?? .next
            keyboard.showApplicationSwitcher(direction)
            addEvent("\(control.rawValue) → \(direction.title)")
        case .screenshot:
            guard pressed else { return }
            guard keyboard.isAccessibilityTrusted else {
                addEvent("\(control.rawValue) 截图被阻止 · 需要辅助功能权限")
                keyboard.requestAccessibilityPermission()
                return
            }
            keyboard.tapGlobal(KeyboardShortcut(
                keyCode: 20,
                modifierFlags: NSEvent.ModifierFlags([.command, .shift]).rawValue,
                modifierOnly: false
            ))
            addEvent("\(control.rawValue) → 截取当前屏幕")
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
        if let deviceID = controllerDeviceIDs.removeValue(forKey: ObjectIdentifier(controller)),
           let index = devices.firstIndex(where: { $0.id == deviceID }) {
            devices[index].connected = false
            pressedByDevice[deviceID] = []
        }
        controllerConnected = devices.contains { $0.kind == .gameController && $0.connected }
        controllerName = selectedDevice?.name ?? "等待手柄"
        pressedButtons = selectedDeviceID.flatMap { pressedByDevice[$0] } ?? []
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
        mouse.stopMoving()
    }

    private func rightStickControlsMouse(deviceID: String) -> Bool {
        [ControllerControl.rightStickUp, .rightStickDown, .rightStickLeft, .rightStickRight]
            .contains { mappingStore.mapping(for: $0, deviceID: deviceID).actionKind == .mouseMove }
    }

    private func updateHIDDevices(_ hidDevices: [HIDInputDevice]) {
        let connectedIDs = Set(hidDevices.map(\.descriptor.id))
        for index in devices.indices where devices[index].kind.isHID {
            devices[index].connected = connectedIDs.contains(devices[index].id)
        }
        for device in hidDevices {
            upsertDevice(device.descriptor)
            mappingStore.registerDevice(device.descriptor)
        }
        synchronizeSelectedDevice(preferredConnectedID: hidDevices.first?.descriptor.id)
        if let selectedDevice, selectedDevice.kind.isHID,
           !selectedDevice.controls.isEmpty,
           !selectedDevice.controls.contains(selectedControl) {
            selectedControl = selectedDevice.controls[0]
        }
    }

    private func upsertDevice(_ device: InputDeviceDescriptor) {
        if let index = devices.firstIndex(where: { $0.id == device.id }) {
            devices[index] = device
        } else {
            devices.append(device)
            devices.sort {
                if $0.connected != $1.connected { return $0.connected && !$1.connected }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }
    }

    private func synchronizeSelectedDevice(preferredConnectedID: String?) {
        if let savedID = mappingStore.selectedDeviceID,
           devices.contains(where: { $0.id == savedID && $0.connected }) {
            if selectedDeviceID != savedID { selectDevice(savedID) }
            return
        }
        if selectedDeviceID == nil,
           let deviceID = preferredConnectedID ?? devices.first(where: \.connected)?.id {
            selectDevice(deviceID)
        }
    }

    private static func identifierComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics
        let scalars = value.lowercased().unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "-" }
        return String(scalars).replacingOccurrences(of: "--", with: "-")
    }

    private func refreshActiveApplication() {
        activeApplication = NSWorkspace.shared.frontmostApplication?.localizedName ?? "桌面"
    }

    private func refreshLaunchAtLoginStatus() {
        launchAtLoginEnabled = launchAtLogin.isEnabled
        launchAtLoginStatus = launchAtLogin.statusText
    }

    private func addEvent(_ message: String) {
        let event = ControlEvent(message: message)
        events.insert(event, at: 0)
        if events.count > 100 { events.removeLast(events.count - 100) }
        diagnosticLog.record(message, at: event.date)
    }

    private static func exportTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}

struct ControlEvent: Identifiable {
    let id = UUID()
    let message: String
    let date = Date()
}
