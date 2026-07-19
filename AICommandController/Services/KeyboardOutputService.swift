import AppKit
import ApplicationServices
import Foundation

@MainActor
final class KeyboardOutputService: ObservableObject {
    @Published private(set) var activeOutputCount = 0
    private struct ActiveOutput {
        let shortcut: KeyboardShortcut
        let targetPID: pid_t?
    }

    private var activeShortcuts: [String: ActiveOutput] = [:]
    private var repeatTasks: [String: Task<Void, Never>] = [:]

    var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    func tap(_ shortcut: KeyboardShortcut) {
        guard isAccessibilityTrusted else { return }
        let targetPID = deliveryTarget(for: shortcut)
        post(shortcut, keyDown: true, targetPID: targetPID)
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(60))
            self?.post(shortcut, keyDown: false, targetPID: targetPID)
        }
    }

    func resolvedDisplayName(for shortcut: KeyboardShortcut) -> String {
        guard !shortcut.modifierOnly else { return shortcut.displayName }
        var resolved = shortcut
        resolved.modifierFlags |= activeModifierFlags
        return resolved.displayName
    }

    func press(_ shortcut: KeyboardShortcut, id: String) {
        guard activeShortcuts[id] == nil, isAccessibilityTrusted else { return }
        let targetPID = deliveryTarget(for: shortcut)
        post(shortcut, keyDown: true, targetPID: targetPID)
        activeShortcuts[id] = ActiveOutput(shortcut: shortcut, targetPID: targetPID)
        if !shortcut.modifierOnly {
            startRepeating(id: id)
        }
        activeOutputCount = activeShortcuts.count
    }

    func release(id: String) {
        repeatTasks.removeValue(forKey: id)?.cancel()
        guard let output = activeShortcuts.removeValue(forKey: id) else { return }
        post(output.shortcut, keyDown: false, targetPID: output.targetPID)
        activeOutputCount = activeShortcuts.count
    }

    func releaseAll() {
        let active = activeShortcuts
        repeatTasks.values.forEach { $0.cancel() }
        repeatTasks.removeAll()
        activeShortcuts.removeAll()
        active.forEach { post($0.value.shortcut, keyDown: false, targetPID: $0.value.targetPID) }
        activeOutputCount = 0
    }

    private func startRepeating(id: String) {
        repeatTasks[id]?.cancel()
        repeatTasks[id] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(NSEvent.keyRepeatDelay))
            while !Task.isCancelled {
                guard let self, let output = self.activeShortcuts[id] else { return }
                // Some apps ignore consecutive synthetic keyDown events even when
                // keyboardEventAutorepeat is set. Close the previous pulse first,
                // then send a fresh repeat keyDown so text fields and editors see
                // the same discrete input cadence as a physical keyboard.
                self.post(output.shortcut, keyDown: false, targetPID: output.targetPID)
                self.post(output.shortcut, keyDown: true, targetPID: output.targetPID, isRepeat: true)
                try? await Task.sleep(for: .seconds(NSEvent.keyRepeatInterval))
            }
        }
    }

    private func deliveryTarget(for shortcut: KeyboardShortcut) -> pid_t? {
        guard !shortcut.modifierOnly,
              let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else { return nil }
        return app.processIdentifier
    }

    private func post(_ shortcut: KeyboardShortcut, keyDown: Bool, targetPID: pid_t?, isRepeat: Bool = false) {
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let event = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(shortcut.keyCode),
                keyDown: keyDown
              )
        else { return }
        if shortcut.modifierOnly {
            event.type = .flagsChanged
        }
        let flags: UInt
        if shortcut.modifierOnly {
            // A modifier press is added before it enters activeShortcuts, while a
            // release is removed first. This makes flagsChanged describe the
            // modifier state that should exist after the event.
            flags = keyDown
                ? activeModifierFlags | shortcut.modifierFlags | modifierSideFlag(for: shortcut.keyCode)
                : activeModifierFlags
        } else {
            // Events posted directly to a target PID do not automatically inherit
            // modifiers posted through the HID tap. Carry all controller-held
            // modifiers explicitly so ZR(Command) + A becomes a real Command-A.
            flags = activeModifierFlags | shortcut.modifierFlags
        }
        event.flags = CGEventFlags(rawValue: UInt64(flags))
        if isRepeat {
            event.setIntegerValueField(.keyboardEventAutorepeat, value: 1)
        }
        if let targetPID {
            event.postToPid(targetPID)
        } else {
            event.post(tap: .cghidEventTap)
        }
    }

    private var activeModifierFlags: UInt {
        activeShortcuts.values.reduce(into: UInt(0)) { flags, output in
            guard output.shortcut.modifierOnly else { return }
            flags |= output.shortcut.modifierFlags
        }
    }

    private func modifierSideFlag(for keyCode: UInt16) -> UInt {
        // macOS carries a device-dependent bit in modifier events to distinguish
        // the left and right physical keys. Keep this on flagsChanged only; normal
        // A/C/V events continue to receive the portable modifier mask above.
        switch keyCode {
        case 54: 0x00000010 // right Command
        case 55: 0x00000008 // left Command
        case 56: 0x00000002 // left Shift
        case 60: 0x00000004 // right Shift
        case 58: 0x00000020 // left Option
        case 61: 0x00000040 // right Option
        case 59: 0x00000001 // left Control
        case 62: 0x00002000 // right Control
        default: 0
        }
    }
}
