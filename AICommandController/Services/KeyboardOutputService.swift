import AppKit
import ApplicationServices
import Foundation

@MainActor
final class KeyboardOutputService: ObservableObject {
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
              let event = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: keyDown)
        else { return }
        event.flags = keyDown ? .maskCommand : []
        event.post(tap: .cghidEventTap)
    }
}
