import AppKit
import Foundation

enum ControllerControl: String, Codable, CaseIterable, Identifiable {
    case a = "A"
    case b = "B"
    case x = "X"
    case y = "Y"
    case leftShoulder = "L"
    case rightShoulder = "R"
    case leftTrigger = "ZL"
    case rightTrigger = "ZR"
    case leftStick = "L3"
    case rightStick = "R3"
    case up = "↑"
    case down = "↓"
    case left = "←"
    case right = "→"
    case menu = "+"
    case options = "−"
    case home = "HOME"

    var id: String { rawValue }

    var compactLabel: String { rawValue }

    var group: String {
        switch self {
        case .a, .b, .x, .y: "FACE"
        case .leftShoulder, .rightShoulder, .leftTrigger, .rightTrigger: "SHOULDER"
        case .leftStick, .rightStick: "STICK"
        case .up, .down, .left, .right: "DPAD"
        case .menu, .options, .home: "SYSTEM"
        }
    }
}

enum MappingActionKind: String, Codable, CaseIterable, Identifiable {
    case none
    case shortcut
    case shell

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "无动作"
        case .shortcut: "快捷键"
        case .shell: "终端命令"
        }
    }
}

enum TriggerBehavior: String, Codable, CaseIterable, Identifiable {
    case tap
    case hold

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tap: "点按一次"
        case .hold: "按住 / 松开"
        }
    }
}

struct KeyboardShortcut: Codable, Equatable {
    var keyCode: UInt16
    var modifierFlags: UInt
    var modifierOnly: Bool

    static let rightCommand = KeyboardShortcut(
        keyCode: 0x36,
        modifierFlags: NSEvent.ModifierFlags.command.rawValue,
        modifierOnly: true
    )

    var displayName: String {
        if modifierOnly {
            return Self.modifierKeyName(keyCode) ?? Self.keyName(keyCode)
        }

        let flags = NSEvent.ModifierFlags(rawValue: modifierFlags)
        var parts: [String] = []
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }
        if flags.contains(.function) { parts.append("fn") }
        parts.append(Self.keyName(keyCode))
        return parts.joined()
    }

    static func isModifierKey(_ keyCode: UInt16) -> Bool {
        modifierKeyName(keyCode) != nil
    }

    static func modifierKeyName(_ keyCode: UInt16) -> String? {
        switch keyCode {
        case 54: "右⌘"
        case 55: "左⌘"
        case 56: "左⇧"
        case 60: "右⇧"
        case 58: "左⌥"
        case 61: "右⌥"
        case 59: "左⌃"
        case 62: "右⌃"
        case 57: "⇪"
        case 63: "fn"
        default: nil
        }
    }

    static func keyName(_ keyCode: UInt16) -> String {
        let names: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↩",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
            44: "/", 45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Space",
            50: "`", 51: "⌫", 53: "Esc", 71: "Clear", 76: "⌤",
            115: "Home", 116: "Page Up", 117: "⌦", 119: "End", 121: "Page Down",
            123: "←", 124: "→", 125: "↓", 126: "↑"
        ]
        return modifierKeyName(keyCode) ?? names[keyCode] ?? "KEY \(keyCode)"
    }
}

struct ButtonMapping: Codable, Identifiable, Equatable {
    var control: ControllerControl
    var actionKind: MappingActionKind
    var shortcut: KeyboardShortcut?
    var triggerBehavior: TriggerBehavior
    var shellCommand: String

    var id: ControllerControl { control }

    var summary: String {
        switch actionKind {
        case .none: "未配置"
        case .shortcut: shortcut?.displayName ?? "等待录制"
        case .shell: shellCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "等待命令" : "$ \(shellCommand)"
        }
    }

    static func empty(for control: ControllerControl) -> ButtonMapping {
        ButtonMapping(
            control: control,
            actionKind: .none,
            shortcut: nil,
            triggerBehavior: .tap,
            shellCommand: ""
        )
    }
}

