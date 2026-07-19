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

    func tapGlobal(_ shortcut: KeyboardShortcut) {
        guard isAccessibilityTrusted else { return }
        post(shortcut, keyDown: true, targetPID: nil)
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(60))
            self?.post(shortcut, keyDown: false, targetPID: nil)
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
        activeOutputCount = activeShortcuts.count
    }

    func release(id: String) {
        guard let output = activeShortcuts.removeValue(forKey: id) else { return }
        post(output.shortcut, keyDown: false, targetPID: output.targetPID)
        activeOutputCount = activeShortcuts.count
    }

    func releaseAll() {
        let active = activeShortcuts
        activeShortcuts.removeAll()
        active.forEach { post($0.value.shortcut, keyDown: false, targetPID: $0.value.targetPID) }
        activeOutputCount = 0
    }

    private func deliveryTarget(for shortcut: KeyboardShortcut) -> pid_t? {
        guard !shortcut.modifierOnly,
              let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else { return nil }
        return app.processIdentifier
    }

    private func post(_ shortcut: KeyboardShortcut, keyDown: Bool, targetPID: pid_t?) {
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
                ? activeModifierEventFlags | modifierEventFlags(for: shortcut)
                : activeModifierEventFlags
        } else {
            // Events posted directly to a target PID do not automatically inherit
            // modifiers posted through the HID tap. Carry all controller-held
            // modifiers explicitly so ZR(Command) + A becomes a real Command-A.
            flags = activeModifierEventFlags | shortcut.modifierFlags
        }
        event.flags = CGEventFlags(rawValue: UInt64(flags))
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

    private var activeModifierEventFlags: UInt {
        activeShortcuts.values.reduce(into: UInt(0)) { flags, output in
            guard output.shortcut.modifierOnly else { return }
            flags |= modifierEventFlags(for: output.shortcut)
        }
    }

    private func modifierEventFlags(for shortcut: KeyboardShortcut) -> UInt {
        // Device-dependent bits preserve the physical side of a modifier.
        // Some global hotkey tools distinguish right Command from left Command
        // using these flags rather than the device-independent mask alone.
        let sideMask: UInt
        switch shortcut.keyCode {
        case 54: sideMask = 0x00000010 // right Command
        case 55: sideMask = 0x00000008 // left Command
        case 56: sideMask = 0x00000002 // left Shift
        case 60: sideMask = 0x00000004 // right Shift
        case 58: sideMask = 0x00000020 // left Option
        case 61: sideMask = 0x00000040 // right Option
        case 59: sideMask = 0x00000001 // left Control
        case 62: sideMask = 0x00002000 // right Control
        default: sideMask = 0
        }
        return shortcut.modifierFlags | sideMask
    }
}
