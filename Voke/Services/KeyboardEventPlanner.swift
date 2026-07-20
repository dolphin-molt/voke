import Foundation

struct PlannedKeyboardEvent: Equatable {
    let shortcut: KeyboardShortcut
    let keyDown: Bool
    let targetPID: pid_t?
    let flags: UInt
}

struct KeyboardEventPlanner {
    private struct ActiveOutput {
        let shortcut: KeyboardShortcut
        let targetPID: pid_t?
    }

    private var activeOutputs: [String: ActiveOutput] = [:]

    var activeCount: Int { activeOutputs.count }

    func contains(_ id: String) -> Bool {
        activeOutputs[id] != nil
    }

    func tap(_ shortcut: KeyboardShortcut, targetPID: pid_t?) -> [PlannedKeyboardEvent] {
        [
            makeEvent(shortcut, keyDown: true, targetPID: targetPID),
            makeEvent(shortcut, keyDown: false, targetPID: targetPID)
        ]
    }

    mutating func press(_ shortcut: KeyboardShortcut, id: String, targetPID: pid_t?) -> PlannedKeyboardEvent? {
        guard activeOutputs[id] == nil else { return nil }
        let event = makeEvent(shortcut, keyDown: true, targetPID: targetPID)
        activeOutputs[id] = ActiveOutput(shortcut: shortcut, targetPID: targetPID)
        return event
    }

    mutating func release(id: String) -> PlannedKeyboardEvent? {
        guard let output = activeOutputs.removeValue(forKey: id) else { return nil }
        return makeEvent(output.shortcut, keyDown: false, targetPID: output.targetPID)
    }

    func repeatPulse(id: String) -> [PlannedKeyboardEvent] {
        guard let output = activeOutputs[id] else { return [] }
        return [
            makeEvent(output.shortcut, keyDown: false, targetPID: output.targetPID),
            makeEvent(output.shortcut, keyDown: true, targetPID: output.targetPID)
        ]
    }

    mutating func releaseAll() -> [PlannedKeyboardEvent] {
        let outputs = activeOutputs.values
        activeOutputs.removeAll()
        return outputs.map { makeEvent($0.shortcut, keyDown: false, targetPID: $0.targetPID) }
    }

    func resolvedDisplayName(for shortcut: KeyboardShortcut) -> String {
        guard !shortcut.modifierOnly else { return shortcut.displayName }
        var resolved = shortcut
        resolved.modifierFlags |= activeModifierFlags
        return resolved.displayName
    }

    private func makeEvent(_ shortcut: KeyboardShortcut, keyDown: Bool, targetPID: pid_t?) -> PlannedKeyboardEvent {
        let flags: UInt
        if shortcut.modifierOnly {
            flags = keyDown
                ? activeModifierFlags | shortcut.modifierFlags | Self.modifierSideFlag(for: shortcut.keyCode)
                : activeModifierFlags
        } else {
            flags = activeModifierFlags | shortcut.modifierFlags
        }
        return PlannedKeyboardEvent(shortcut: shortcut, keyDown: keyDown, targetPID: targetPID, flags: flags)
    }

    private var activeModifierFlags: UInt {
        activeOutputs.values.reduce(into: UInt(0)) { flags, output in
            guard output.shortcut.modifierOnly else { return }
            flags |= output.shortcut.modifierFlags
        }
    }

    static func modifierSideFlag(for keyCode: UInt16) -> UInt {
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

enum StickDirectionResolver {
    static let pressThreshold: Float = 0.58
    static let releaseThreshold: Float = 0.38

    static func isPressed(value: Float, currentlyPressed: Bool) -> Bool {
        currentlyPressed ? value > releaseThreshold : value > pressThreshold
    }
}
