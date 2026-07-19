import AppKit
import ApplicationServices
import Foundation

@MainActor
final class KeyboardOutputService: ObservableObject {
    @Published private(set) var activeOutputCount = 0
    private var activeShortcuts: [String: KeyboardShortcut] = [:]

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
        post(shortcut, keyDown: true)
        post(shortcut, keyDown: false)
    }

    func press(_ shortcut: KeyboardShortcut, id: String) {
        guard activeShortcuts[id] == nil, isAccessibilityTrusted else { return }
        post(shortcut, keyDown: true)
        activeShortcuts[id] = shortcut
        activeOutputCount = activeShortcuts.count
    }

    func release(id: String) {
        guard let shortcut = activeShortcuts.removeValue(forKey: id) else { return }
        post(shortcut, keyDown: false)
        activeOutputCount = activeShortcuts.count
    }

    func releaseAll() {
        let active = activeShortcuts
        activeShortcuts.removeAll()
        active.forEach { post($0.value, keyDown: false) }
        activeOutputCount = 0
    }

    private func post(_ shortcut: KeyboardShortcut, keyDown: Bool) {
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
        event.post(tap: .cghidEventTap)
    }
}
