import AppKit
import SwiftUI

@MainActor
final class ShortcutRecorder: ObservableObject {
    @Published private(set) var isRecording = false

    private var monitor: Any?
    private var pendingModifier: KeyboardShortcut?
    private var capture: ((KeyboardShortcut) -> Void)?

    func start(capture: @escaping (KeyboardShortcut) -> Void) {
        stop()
        self.capture = capture
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self, self.isRecording else { return event }
            let flags = event.modifierFlags.intersection([.command, .shift, .option, .control, .function])

            if event.type == .keyDown {
                self.finish(KeyboardShortcut(keyCode: event.keyCode, modifierFlags: flags.rawValue, modifierOnly: false))
                return nil
            }

            if KeyboardShortcut.isModifierKey(event.keyCode) {
                if !flags.isEmpty {
                    self.pendingModifier = KeyboardShortcut(keyCode: event.keyCode, modifierFlags: flags.rawValue, modifierOnly: true)
                } else if let pendingModifier = self.pendingModifier {
                    self.finish(pendingModifier)
                }
                return nil
            }
            return event
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        pendingModifier = nil
        capture = nil
        isRecording = false
    }

    private func finish(_ shortcut: KeyboardShortcut) {
        let handler = capture
        stop()
        handler?(shortcut)
    }

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
    }
}

struct MappingStudio: View {
    @ObservedObject var store: MappingStore
    @ObservedObject var applicationShortcuts: ApplicationShortcutSyncService
    @Binding var selectedControl: ControllerControl
    let accessibilityTrusted: Bool
    let openAccessibilitySettings: () -> Void
    let controls: [ControllerControl]
    let controlLabel: (ControllerControl) -> String

    @StateObject private var recorder = ShortcutRecorder()
    @State private var demoPressed = false
    @AppStorage("appearanceTheme") private var themeRawValue = AppTheme.daylight.rawValue

    private var theme: AppTheme { AppTheme(rawValue: themeRawValue) ?? .daylight }
    private var field: Color { theme.palette.elevated }
    private var border: Color { theme.palette.border }
    private var accent: Color { theme.palette.accent }
    private var warning: Color { theme.palette.warning }
    private var ink: Color { theme.palette.ink }
    private let modifierPresets = [
        ModifierPreset(id: "command", label: "⌘ Command", shortcut: .rightCommand),
        ModifierPreset(id: "option", label: "⌥ Option", shortcut: .rightOption),
        ModifierPreset(id: "shift", label: "⇧ Shift", shortcut: .rightShift),
        ModifierPreset(id: "control", label: "⌃ Control", shortcut: .rightControl),
        ModifierPreset(id: "escape", label: "Esc 退出", shortcut: .escape)
    ]

    private var mapping: ButtonMapping { store.mapping(for: selectedControl) }

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 17) {
                selectedHero
                actionSelector

                Group {
                    switch mapping.actionKind {
                    case .none:
                        emptyState
                    case .shortcut:
                        shortcutEditor
                    case .inputSource:
                        inputSourceEditor
                    case .scroll:
                        scrollEditor
                    case .mouseMove:
                        mouseMoveEditor
                    case .mouseClick:
                        mouseClickEditor
                    case .appSwitch:
                        appSwitchEditor
                    case .screenshot:
                        screenshotEditor
                    case .shell:
                        shellEditor
                    case .applicationAction:
                        applicationActionEditor
                    }
                }

                if geometry.size.height >= 620 {
                    demoPressButton
                }
                Spacer(minLength: 4)
                currentResult
            }
        }
        .onChange(of: selectedControl) { recorder.stop() }
        .onDisappear { recorder.stop() }
    }

    private var selectedHero: some View {
        HStack(spacing: 0) {
            Text(compactControlLabel(selectedControl))
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(ink)
                .frame(minWidth: 58, minHeight: 42)
                .padding(.horizontal, 4)
                .background(warning)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 20,
                        bottomLeadingRadius: 17,
                        bottomTrailingRadius: 22,
                        topTrailingRadius: 18,
                        style: .continuous
                    )
                )
                .overlay(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 20,
                        bottomLeadingRadius: 17,
                        bottomTrailingRadius: 22,
                        topTrailingRadius: 18,
                        style: .continuous
                    )
                    .stroke(ink, lineWidth: 1.7)
                )
                .rotationEffect(.degrees(-2))
                .shadow(color: ink.opacity(0.14), radius: 0, x: 3, y: 4)

            Spacer(minLength: 0)
        }
    }

    private var actionSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("执行什么")
            HStack(spacing: 4) {
                actionCategoryButton("快捷键", active: mapping.actionKind == .shortcut) {
                    actionKindBinding.wrappedValue = .shortcut
                }
                .frame(maxWidth: .infinity)

                if !store.availableApplicationActions.isEmpty {
                    Menu {
                        ForEach(ApplicationActionGroup.allCases) { group in
                            let actions = store.availableApplicationActions.filter { $0.group == group }
                            if !actions.isEmpty {
                                Section(group.title) {
                                    ForEach(actions) { action in
                                        let resolution = applicationShortcuts.resolution(for: action)
                                        Button(actionMenuTitle(action, resolution: resolution)) {
                                            selectApplicationAction(action)
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        categoryLabel("当前 App", active: mapping.actionKind == .applicationAction)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .frame(maxWidth: .infinity)
                }

                Menu {
                    Button("切换中英文") { actionKindBinding.wrappedValue = .inputSource }
                    Button("页面滚动") { actionKindBinding.wrappedValue = .scroll }
                    if isRightStickDirection(selectedControl) {
                        Button("移动鼠标") { actionKindBinding.wrappedValue = .mouseMove }
                    }
                    Button("鼠标左键") { actionKindBinding.wrappedValue = .mouseClick }
                    Button("切换 App") { actionKindBinding.wrappedValue = .appSwitch }
                    Button("截取屏幕") { actionKindBinding.wrappedValue = .screenshot }
                } label: {
                    categoryLabel("系统", active: isSystemAction)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(maxWidth: .infinity)

                Menu {
                    Button("无动作") { actionKindBinding.wrappedValue = .none }
                    Button("终端命令") { actionKindBinding.wrappedValue = .shell }
                } label: {
                    categoryLabel("更多", active: isMoreAction)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(maxWidth: .infinity)
            }
            .padding(4)
            .background(ink.opacity(0.06))
            .clipShape(Capsule())
        }
    }

    private var isSystemAction: Bool {
        [.inputSource, .scroll, .mouseMove, .mouseClick, .appSwitch, .screenshot].contains(mapping.actionKind)
    }

    private var isMoreAction: Bool { [.none, .shell].contains(mapping.actionKind) }

    private func actionMenuTitle(
        _ action: ApplicationActionPreset,
        resolution: ApplicationShortcutResolution
    ) -> String {
        if let shortcut = resolution.shortcut {
            return "\(action.title) · \(shortcut.displayName)"
        }
        return "\(action.title) · 需先在 Codex 设置"
    }

    private func selectApplicationAction(_ action: ApplicationActionPreset) {
        store.update(selectedControl) { mapping in
            mapping.actionKind = .applicationAction
            mapping.applicationActionID = action.id
            mapping.applicationActionShortcut = nil
            mapping.triggerBehavior = action.interaction == .pressAndHold ? .hold : .tap
        }
    }

    private var applicationActionEditor: some View {
        let preset = ApplicationActionRegistry.preset(id: mapping.applicationActionID)
        let resolution = preset.map(applicationShortcuts.resolution)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "app.badge.checkmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(preset?.title ?? "选择当前 App 的动作")
                        .font(.system(size: 12, weight: .bold))
                    Text(preset?.detail ?? "从上方“当前 App”菜单选择")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let preset {
                    Text(preset.group == .codexGeneral ? "CODEX" : "MICRO")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(accent.opacity(0.18))
                        .clipShape(Capsule())
                }
            }
            .padding(14)
            .background(field)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            if let preset {
                label("Codex 快捷键同步")
                HStack {
                    Image(systemName: resolution?.shortcut == nil ? "exclamationmark.triangle" : "arrow.triangle.2.circlepath")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(resolution?.shortcut?.displayName ?? "Codex 中未设置")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                        Text(applicationShortcuts.statusText)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("刷新") { applicationShortcuts.refresh() }
                        .buttonStyle(.borderless)
                        .font(.system(size: 9, weight: .bold))
                }
                .padding(.horizontal, 13)
                .frame(minHeight: 50)
                .background(theme.palette.surface.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(border))

                if resolution?.shortcut == nil {
                    HStack {
                        Image(systemName: "keyboard")
                        Text("请在 Codex → Settings → Keyboard shortcuts 为“\(preset.title)”设置快捷键。Voke 会自动读取，不需要再次录入。")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func actionCategoryButton(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { categoryLabel(title, active: active) }
            .buttonStyle(.plain)
    }

    private func categoryLabel(_ title: String, active: Bool) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(active ? ink : .secondary)
            .frame(maxWidth: .infinity, minHeight: 31)
            .background(active ? theme.palette.surface.opacity(0.88) : .clear)
            .clipShape(Capsule())
            .shadow(color: active ? ink.opacity(0.10) : .clear, radius: 0, x: 2, y: 3)
    }

    private var emptyState: some View {
        HStack(spacing: 12) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("这个按键不会执行动作")
                    .font(.system(size: 12, weight: .semibold))
                Text("需要时再为它添加快捷键或终端命令。")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(field)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private var shortcutEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                label("当前快捷键")
                Button {
                    if recorder.isRecording {
                        recorder.stop()
                    } else {
                        recorder.start { shortcut in
                            store.update(selectedControl) { mapping in
                                mapping.shortcut = shortcut
                                if shortcut.modifierOnly { mapping.triggerBehavior = .hold }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: recorder.isRecording ? "record.circle.fill" : "keyboard.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(recorder.isRecording ? warning : Color(red: 0.192, green: 0.373, blue: 0.255))
                            .frame(width: 33, height: 33)
                            .background(accent.opacity(0.27))
                            .clipShape(Circle())
                        Text(recorder.isRecording ? "现在按下快捷键…" : (mapping.shortcut?.displayName ?? "点击录制快捷键"))
                            .font(.system(size: 15, weight: .black, design: .monospaced))
                            .lineLimit(1)
                        Spacer()
                        Text(recorder.isRecording ? "取消" : "重新录制")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .frame(height: 30)
                            .background(theme.palette.surface.opacity(0.72))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(border))
                    }
                    .padding(14)
                    .frame(minHeight: 63)
                    .background(theme.palette.surface.opacity(0.52))
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 23,
                            bottomLeadingRadius: 19,
                            bottomTrailingRadius: 25,
                            topTrailingRadius: 20,
                            style: .continuous
                        )
                    )
                    .overlay(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 23,
                            bottomLeadingRadius: 19,
                            bottomTrailingRadius: 25,
                            topTrailingRadius: 20,
                            style: .continuous
                        )
                        .stroke(recorder.isRecording ? warning : ink.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    )
                }
                .buttonStyle(.plain)

                if recorder.isRecording {
                    Button("取消录制") { recorder.stop() }
                        .buttonStyle(.link)
                        .font(.system(size: 10, weight: .semibold))
                }

                label("常用修饰键")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 7) {
                    ForEach(modifierPresets) { preset in
                        Button {
                            store.update(selectedControl) { mapping in
                                mapping.shortcut = preset.shortcut
                                mapping.triggerBehavior = .hold
                            }
                        } label: {
                            Text(preset.label)
                                .font(.system(size: 9, weight: .bold))
                                .frame(maxWidth: .infinity, minHeight: 35)
                                .background(mapping.shortcut == preset.shortcut ? accent.opacity(0.18) : field)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(mapping.shortcut == preset.shortcut ? accent.opacity(0.65) : border)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                label("触发方式")
                HStack(spacing: 4) {
                    ForEach(TriggerBehavior.allCases) { behavior in
                        Button {
                            behaviorBinding.wrappedValue = behavior
                        } label: {
                            Text(behavior.title)
                                .font(.system(size: 9, weight: .bold))
                                .frame(maxWidth: .infinity, minHeight: 31)
                                .background(mapping.triggerBehavior == behavior ? theme.palette.surface.opacity(0.88) : .clear)
                                .clipShape(Capsule())
                                .shadow(color: mapping.triggerBehavior == behavior ? ink.opacity(0.10) : .clear, radius: 0, x: 2, y: 3)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(ink.opacity(0.06))
                .clipShape(Capsule())
            }
        }
    }

    private var inputSourceEditor: some View {
        HStack(spacing: 12) {
            Image(systemName: "character.bubble.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 3) {
                Text("中文 ↔ English")
                    .font(.system(size: 12, weight: .semibold))
                Text("直接在 macOS 已启用的中文和英文输入源之间切换。")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(field)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private var shellEditor: some View {
        VStack(alignment: .leading, spacing: 9) {
            label("终端命令 · ZSH")
            TextEditor(text: shellCommandBinding)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(9)
                .frame(minHeight: 86)
                .background(field)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(border))
            Label("命令会以当前用户权限执行，请只使用你信任的内容。", systemImage: "exclamationmark.shield")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var scrollEditor: some View {
        VStack(alignment: .leading, spacing: 9) {
            label("滚动方向")
            Picker("滚动方向", selection: scrollDirectionBinding) {
                ForEach(ScrollDirection.allCases) { direction in
                    Text(direction.title).tag(direction)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            Label("按住摇杆方向会连续滚动，松手立即停止。", systemImage: "scroll")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var mouseMoveEditor: some View {
        HStack(spacing: 12) {
            Image(systemName: "cursorarrow.motionlines")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 3) {
                Text("摇杆控制光标")
                    .font(.system(size: 12, weight: .semibold))
                Text("轻推慢移，推到底加速；松开立即停止。")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(field)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private var mouseClickEditor: some View {
        HStack(spacing: 12) {
            Image(systemName: "cursorarrow.click.2")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 3) {
                Text("鼠标左键单击")
                    .font(.system(size: 12, weight: .semibold))
                Text("按下手柄按钮时，在当前光标位置点击一次。")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(field)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private var appSwitchEditor: some View {
        VStack(alignment: .leading, spacing: 9) {
            label("切换方向")
            Picker("切换方向", selection: appSwitchDirectionBinding) {
                ForEach(AppSwitchDirection.allCases) { direction in
                    Text(direction.title).tag(direction)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            Label("打开系统切换条；继续拨动选择，按映射为回车的按钮确认。", systemImage: "macwindow.on.rectangle")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var screenshotEditor: some View {
        HStack(spacing: 12) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 3) {
                Text("截取当前屏幕")
                    .font(.system(size: 12, weight: .semibold))
                Text("调用 macOS 系统截图并保存到系统默认位置。")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(field)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private var currentResult: some View {
        HStack(spacing: 10) {
            Image(systemName: mapping.actionKind == .none ? "minus" : "arrow.right")
                .foregroundStyle(mapping.actionKind == .none ? .secondary : accent)
            Text("按下 \(controlLabel(selectedControl))")
                .foregroundStyle(.secondary)
            Spacer()
            Text(mapping.summary)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .lineLimit(1)
        }
        .font(.system(size: 10, weight: .bold))
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(ink.opacity(0.07))
        .clipShape(Capsule())
    }

    private var demoPressButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.12)) { demoPressed = true }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(180))
                withAnimation(.easeOut(duration: 0.16)) { demoPressed = false }
            }
        } label: {
            Text(demoPressed ? "正在按下 \(compactControlLabel(selectedControl))" : "演示按下当前按钮")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color(red: 0.208, green: 0.416, blue: 0.275))
                .frame(maxWidth: .infinity, minHeight: 37)
                .background(accent.opacity(demoPressed ? 0.32 : 0.16))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color(red: 0.263, green: 0.557, blue: 0.365), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        }
        .buttonStyle(.plain)
    }

    private var actionKindBinding: Binding<MappingActionKind> {
        Binding(
            get: { mapping.actionKind },
            set: { value in
                recorder.stop()
                if value == .mouseMove, isRightStickDirection(selectedControl) {
                    let controls = [ControllerControl.rightStickUp, .rightStickDown, .rightStickLeft, .rightStickRight]
                    for control in controls {
                        store.update(control) { mapping in
                            mapping.actionKind = .mouseMove
                            mapping.triggerBehavior = .hold
                        }
                    }
                    return
                }
                store.update(selectedControl) { mapping in
                    mapping.actionKind = value
                    if value == .scroll, mapping.scrollDirection == nil {
                        mapping.scrollDirection = selectedControl.defaultScrollDirection ?? .down
                    }
                    if value == .appSwitch, mapping.appSwitchDirection == nil {
                        mapping.appSwitchDirection = .next
                    }
                }
            }
        )
    }

    private var behaviorBinding: Binding<TriggerBehavior> {
        Binding(
            get: { mapping.triggerBehavior },
            set: { value in store.update(selectedControl) { $0.triggerBehavior = value } }
        )
    }

    private var shellCommandBinding: Binding<String> {
        Binding(
            get: { mapping.shellCommand },
            set: { value in store.update(selectedControl) { $0.shellCommand = value } }
        )
    }

    private var scrollDirectionBinding: Binding<ScrollDirection> {
        Binding(
            get: { mapping.scrollDirection ?? selectedControl.defaultScrollDirection ?? .down },
            set: { value in store.update(selectedControl) { $0.scrollDirection = value } }
        )
    }

    private var appSwitchDirectionBinding: Binding<AppSwitchDirection> {
        Binding(
            get: { mapping.appSwitchDirection ?? .next },
            set: { value in store.update(selectedControl) { $0.appSwitchDirection = value } }
        )
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private func compactControlLabel(_ control: ControllerControl) -> String {
        switch control {
        case .leftStickUp: "L↑"
        case .leftStickDown: "L↓"
        case .leftStickLeft: "L←"
        case .leftStickRight: "L→"
        case .rightStickUp: "R↑"
        case .rightStickDown: "R↓"
        case .rightStickLeft: "R←"
        case .rightStickRight: "R→"
        default: controlLabel(control)
        }
    }

    private func isRightStickDirection(_ control: ControllerControl) -> Bool {
        [.rightStickUp, .rightStickDown, .rightStickLeft, .rightStickRight].contains(control)
    }
}

private struct ModifierPreset: Identifiable {
    let id: String
    let label: String
    let shortcut: KeyboardShortcut
}
