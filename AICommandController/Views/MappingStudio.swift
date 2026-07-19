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
                if event.keyCode == 53, flags.isEmpty {
                    self.stop()
                    return nil
                }
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
    @Binding var selectedControl: ControllerControl
    let accessibilityTrusted: Bool
    let openAccessibilitySettings: () -> Void

    @StateObject private var recorder = ShortcutRecorder()

    private let field = Color.white.opacity(0.045)
    private let border = Color.white.opacity(0.085)
    private let accent = Color(red: 0.58, green: 0.94, blue: 0.56)
    private let warning = Color(red: 1.0, green: 0.70, blue: 0.28)
    private let modifierPresets = [
        ModifierPreset(id: "command", label: "⌘ Command", shortcut: .rightCommand),
        ModifierPreset(id: "option", label: "⌥ Option", shortcut: .rightOption),
        ModifierPreset(id: "shift", label: "⇧ Shift", shortcut: .rightShift),
        ModifierPreset(id: "control", label: "⌃ Control", shortcut: .rightControl)
    ]

    private var mapping: ButtonMapping { store.mapping(for: selectedControl) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("按键映射")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Text("选择一个手柄按键，然后设置它的动作")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(selectedControl.rawValue)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.black.opacity(0.78))
                    .frame(minWidth: 42, minHeight: 34)
                    .padding(.horizontal, 3)
                    .background(accent)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }

            controlGrid

            VStack(alignment: .leading, spacing: 10) {
                label("执行什么")
                Picker("执行什么", selection: actionKindBinding) {
                    ForEach(MappingActionKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            Group {
                switch mapping.actionKind {
                case .none:
                    emptyState
                case .shortcut:
                    shortcutEditor
                case .shell:
                    shellEditor
                }
            }

            currentResult
        }
        .onChange(of: selectedControl) { recorder.stop() }
        .onDisappear { recorder.stop() }
    }

    private var controlGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 7)], spacing: 7) {
            ForEach(ControllerControl.allCases) { control in
                let selected = control == selectedControl
                let configured = store.mapping(for: control).actionKind != .none

                Button {
                    selectedControl = control
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Text(control.compactLabel)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity, minHeight: 36)
                        if configured {
                            Circle()
                                .fill(selected ? Color.black.opacity(0.55) : accent)
                                .frame(width: 6, height: 6)
                                .padding(5)
                        }
                    }
                    .foregroundStyle(selected ? Color.black.opacity(0.8) : .primary)
                    .background(selected ? accent : field)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(selected ? accent : border))
                }
                .buttonStyle(.plain)
            }
        }
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
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                label("快捷键")
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
                        Image(systemName: recorder.isRecording ? "record.circle.fill" : "keyboard")
                            .foregroundStyle(recorder.isRecording ? warning : accent)
                        Text(recorder.isRecording ? "现在按下快捷键…" : (mapping.shortcut?.displayName ?? "点击录制快捷键"))
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        Spacer()
                        Text(recorder.isRecording ? "ESC 取消" : "录制")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 13)
                    .frame(height: 44)
                    .background(field)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(recorder.isRecording ? warning : border))
                }
                .buttonStyle(.plain)

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
                                .font(.system(size: 10, weight: .semibold))
                                .frame(maxWidth: .infinity, minHeight: 30)
                                .background(mapping.shortcut == preset.shortcut ? accent.opacity(0.18) : field)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(mapping.shortcut == preset.shortcut ? accent.opacity(0.65) : border)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                label("触发方式")
                Picker("触发方式", selection: behaviorBinding) {
                    ForEach(TriggerBehavior.allCases) { behavior in
                        Text(behavior.title).tag(behavior)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            if !accessibilityTrusted {
                Button("授权后才能发送快捷键") { openAccessibilitySettings() }
                    .buttonStyle(.link)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(warning)
            }
        }
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

    private var currentResult: some View {
        HStack(spacing: 10) {
            Image(systemName: mapping.actionKind == .none ? "minus" : "arrow.right")
                .foregroundStyle(mapping.actionKind == .none ? .secondary : accent)
            Text("按下 \(selectedControl.rawValue)")
                .foregroundStyle(.secondary)
            Spacer()
            Text(mapping.summary)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .lineLimit(1)
        }
        .font(.system(size: 10, weight: .medium))
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(Color.black.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var actionKindBinding: Binding<MappingActionKind> {
        Binding(
            get: { mapping.actionKind },
            set: { value in
                recorder.stop()
                store.update(selectedControl) { $0.actionKind = value }
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

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
    }
}

private struct ModifierPreset: Identifiable {
    let id: String
    let label: String
    let shortcut: KeyboardShortcut
}
