import AppKit
import ApplicationServices
import Foundation

enum AppSwitcherShortcutResult {
    case none
    case confirmed
    case cancelled
}

@MainActor
final class KeyboardOutputService: ObservableObject {
    @Published private(set) var activeOutputCount = 0
    private var planner = KeyboardEventPlanner()
    private var repeatTasks: [String: Task<Void, Never>] = [:]
    private let appSwitchCommandID = "system.app-switch.command"
    private let appSwitchShiftID = "system.app-switch.shift"

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
        tapGlobal(shortcut)
    }

    func tapGlobal(_ shortcut: KeyboardShortcut) {
        guard isAccessibilityTrusted else { return }
        let events = planner.tap(shortcut)
        guard events.count == 2 else { return }
        post(events[0])
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(60))
            self?.post(events[1])
        }
    }

    func showApplicationSwitcher(_ direction: AppSwitchDirection) {
        guard isAccessibilityTrusted else { return }
        let leftCommand = KeyboardShortcut(
            keyCode: 55,
            modifierFlags: NSEvent.ModifierFlags.command.rawValue,
            modifierOnly: true
        )
        let leftShift = KeyboardShortcut(
            keyCode: 56,
            modifierFlags: NSEvent.ModifierFlags.shift.rawValue,
            modifierOnly: true
        )

        press(leftCommand, id: appSwitchCommandID)
        if direction == .previous {
            press(leftShift, id: appSwitchShiftID)
        }
        tapGlobal(KeyboardShortcut(keyCode: 48, modifierFlags: 0, modifierOnly: false))

        if direction == .previous {
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(70))
                guard let self else { return }
                self.release(id: self.appSwitchShiftID)
            }
        }
    }

    func handleApplicationSwitcherShortcut(_ shortcut: KeyboardShortcut) -> AppSwitcherShortcutResult {
        guard planner.contains(appSwitchCommandID) else { return .none }
        let isReturn = shortcut.keyCode == 36 || shortcut.keyCode == 76
        if isReturn {
            release(id: appSwitchShiftID)
            release(id: appSwitchCommandID)
            return .confirmed
        }
        if shortcut.keyCode == 53 {
            tapGlobal(KeyboardShortcut(keyCode: 53, modifierFlags: 0, modifierOnly: false))
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(80))
                guard let self else { return }
                self.release(id: self.appSwitchShiftID)
                self.release(id: self.appSwitchCommandID)
            }
            return .cancelled
        }
        return .none
    }

    func resolvedDisplayName(for shortcut: KeyboardShortcut) -> String {
        guard !shortcut.modifierOnly else { return shortcut.displayName }
        return planner.resolvedDisplayName(for: shortcut)
    }

    func press(_ shortcut: KeyboardShortcut, id: String, repeats: Bool = true) {
        guard !planner.contains(id), isAccessibilityTrusted else { return }
        guard let event = planner.press(shortcut, id: id) else { return }
        post(event)
        if repeats && !shortcut.modifierOnly {
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
        // System-level posting matches a physical keyboard event. Targeting a
        // single PID skips global listeners and transient UI such as menu-bar
        // popovers, which made Escape and other mappings depend on app focus.
        event.post(tap: .cghidEventTap)
    }

}
