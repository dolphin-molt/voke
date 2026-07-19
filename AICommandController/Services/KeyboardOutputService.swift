import AppKit
import ApplicationServices
import Foundation

@MainActor
final class KeyboardOutputService: ObservableObject {
    private let rightCommandKeyCode: CGKeyCode = 0x36
    @Published private(set) var commandIsPressed = false

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

    func pressCommand() {
        guard !commandIsPressed, isAccessibilityTrusted else { return }
        postCommand(keyDown: true)
        commandIsPressed = true
    }

    func releaseCommand() {
        guard commandIsPressed else { return }
        postCommand(keyDown: false)
        commandIsPressed = false
    }

    private func postCommand(keyDown: Bool) {
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let event = CGEvent(
                keyboardEventSource: source,
                virtualKey: rightCommandKeyCode,
                keyDown: keyDown
              )
        else { return }
        // A standalone modifier is delivered by macOS as flagsChanged, not a
        // regular keyDown/keyUp event. Modifier-only global shortcuts rely on it.
        event.type = .flagsChanged
        event.flags = keyDown ? .maskCommand : []
        event.post(tap: .cghidEventTap)
    }
}
