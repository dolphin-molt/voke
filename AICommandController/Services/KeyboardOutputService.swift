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
        event.flags = keyDown ? CGEventFlags(rawValue: UInt64(shortcut.modifierFlags)) : []
        if let targetPID {
            event.postToPid(targetPID)
        } else {
            event.post(tap: .cghidEventTap)
        }
    }
}
