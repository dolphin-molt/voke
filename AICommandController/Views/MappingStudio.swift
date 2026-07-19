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
                let shortcut = KeyboardShortcut(
                    keyCode: event.keyCode,
                    modifierFlags: flags.rawValue,
                    modifierOnly: false
                )
                self.finish(shortcut)
                return nil
            }

            if KeyboardShortcut.isModifierKey(event.keyCode) {
                if !flags.isEmpty {
                    self.pendingModifier = KeyboardShortcut(
                        keyCode: event.keyCode,
                        modifierFlags: flags.rawValue,
                        modifierOnly: true
                    )
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

    private let panel = Color(red: 0.075, green: 0.082, blue: 0.09)
    private let line = Color.white.opacity(0.10)
    private let cyan = Color(red: 0.25, green: 0.91, blue: 0.82)
    private let amber = Color(red: 1.0, green: 0.67, blue: 0.22)

    private var mapping: ButtonMapping {
        store.mapping(for: selectedControl)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MAPPING STUDIO")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .tracking(0.8)
                    Text("选择按键，然后定义它要执行的动作")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(selectedControl.rawValue)
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundStyle(.black)
                    .frame(minWidth: 42, minHeight: 34)
                    .padding(.horizontal, 4)
                    .background(amber)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }

            controlGrid

            VStack(alignment: .leading, spacing: 11) {
                fieldLabel("ACTION TYPE")
                Picker("", selection: actionKindBinding) {
                    ForEach(MappingActionKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)

                switch mapping.actionKind {
                case .none:
                    emptyState
                case .shortcut:
                    shortcutEditor
                case .shell:
                    shellEditor
                }
            }
            .padding(14)
            .background(panel)
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(line))
        }
        .onChange(of: selectedControl) { recorder.stop() }
        .onDisappear { recorder.stop() }
    }

    private var controlGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
            ForEach(ControllerControl.allCases) { control in
                let configured = store.mapping(for: control).actionKind != .none
                Button {
                    selectedControl = control
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Text(control.compactLabel)
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .frame(maxWidth: .infinity, minHeight: 29)
                        if configured {
                            Circle()
                                .fill(control == selectedControl ? Color.black.opacity(0.55) : cyan)
                                .frame(width: 5, height: 5)
                                .padding(4)
                        }
                    }
                    .foregroundStyle(control == selectedControl ? .black : .white.opacity(0.68))
                    .background(control == selectedControl ? amber : panel)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(control == selectedControl ? amber : line))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        HStack(spacing: 9) {
            Image(systemName: "minus.circle")
            Text("这个按键目前不会执行任何动作")
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
    }

    private var shortcutEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            fieldLabel("KEY COMBINATION")
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
                HStack {
                    Image(systemName: recorder.isRecording ? "record.circle.fill" : "keyboard")
                        .foregroundStyle(recorder.isRecording ? amber : cyan)
                    Text(recorder.isRecording ? "请按下组合键…  ESC 取消" : (mapping.shortcut?.displayName ?? "点击录制快捷键"))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                    Spacer()
                    Text(recorder.isRecording ? "REC" : "RECORD")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(recorder.isRecording ? amber : .secondary)
                }
                .padding(.horizontal, 11)
                .frame(height: 40)
                .background(Color.black.opacity(0.24))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(recorder.isRecording ? amber : line))
            }
            .buttonStyle(.plain)

            fieldLabel("TRIGGER MODE")
            Picker("", selection: behaviorBinding) {
                ForEach(TriggerBehavior.allCases) { behavior in
                    Text(behavior.title).tag(behavior)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            if !accessibilityTrusted {
                Button("快捷键输出需要辅助功能权限") {
                    openAccessibilitySettings()
                }
                .buttonStyle(.link)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(amber)
            }
        }
    }

    private var shellEditor: some View {
        VStack(alignment: .leading, spacing: 9) {
            fieldLabel("ZSH COMMAND")
            TextEditor(text: shellCommandBinding)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 76)
                .background(Color.black.opacity(0.28))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(line))
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "exclamationmark.shield")
                    .foregroundStyle(amber)
                Text("按键按下时通过 /bin/zsh -lc 执行一次。命令拥有当前用户权限，请只填写你信任的命令。")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .black, design: .monospaced))
            .foregroundStyle(.secondary)
            .tracking(1.1)
    }
}

