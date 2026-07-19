import AppKit
import ApplicationServices
import Foundation

@MainActor
final class KeyboardOutputService: ObservableObject {
    @Published private(set) var activeOutputCount = 0
    private var planner = KeyboardEventPlanner()
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
        tap(shortcut, targetPID: deliveryTarget(for: shortcut))
    }

    func tapGlobal(_ shortcut: KeyboardShortcut) {
        tap(shortcut, targetPID: nil)
    }

    private func tap(_ shortcut: KeyboardShortcut, targetPID: pid_t?) {
        guard isAccessibilityTrusted else { return }
        let events = planner.tap(shortcut, targetPID: targetPID)
        guard events.count == 2 else { return }
        post(events[0])
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(60))
            self?.post(events[1])
        }
    }

    func resolvedDisplayName(for shortcut: KeyboardShortcut) -> String {
        guard !shortcut.modifierOnly else { return shortcut.displayName }
        return planner.resolvedDisplayName(for: shortcut)
    }

    func press(_ shortcut: KeyboardShortcut, id: String) {
        guard !planner.contains(id), isAccessibilityTrusted else { return }
        let targetPID = deliveryTarget(for: shortcut)
        guard let event = planner.press(shortcut, id: id, targetPID: targetPID) else { return }
        post(event)
        if !shortcut.modifierOnly {
            startRepeating(id: id)
        }
        activeOutputCount = planner.activeCount
    }

    func release(id: String) {
        repeatTasks.removeValue(forKey: id)?.cancel()
        guard let event = planner.release(id: id) else { return }
        post(event)
        activeOutputCount = planner.activeCount
    }

    func releaseAll() {
        repeatTasks.values.forEach { $0.cancel() }
        repeatTasks.removeAll()
        planner.releaseAll().forEach(post)
        activeOutputCount = 0
    }

    private func startRepeating(id: String) {
        repeatTasks[id]?.cancel()
        repeatTasks[id] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(NSEvent.keyRepeatDelay))
            while !Task.isCancelled {
                guard let self, self.planner.contains(id) else { return }
                // Some apps ignore consecutive synthetic keyDown events even when
                // keyboardEventAutorepeat is set. Close the previous pulse first,
                // then send a fresh repeat keyDown so text fields and editors see
                // the same discrete input cadence as a physical keyboard.
                self.planner.repeatPulse(id: id).forEach(self.post)
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

    private func post(_ planned: PlannedKeyboardEvent) {
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let event = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(planned.shortcut.keyCode),
                keyDown: planned.keyDown
              )
        else { return }
        if planned.shortcut.modifierOnly {
            event.type = .flagsChanged
        }
        event.flags = CGEventFlags(rawValue: UInt64(planned.flags))
        if let targetPID = planned.targetPID {
            event.postToPid(targetPID)
        } else {
            event.post(tap: .cghidEventTap)
        }
    }

}
