import Combine
import Foundation

struct MappingBackup: Codable {
    let formatVersion: Int
    let exportedAt: Date
    let mappings: [ButtonMapping]
}

enum MappingBackupError: LocalizedError {
    case unsupportedVersion(Int)
    case duplicateControl(String)

    var errorDescription: String? {
        switch self {
        case let .unsupportedVersion(version): "不支持的配置版本：\(version)"
        case let .duplicateControl(control): "配置中存在重复按键：\(control)"
        }
    }
}

@MainActor
final class MappingStore: ObservableObject {
    @Published private(set) var mappings: [ControllerControl: ButtonMapping] = [:]

    private let defaultsKey = "controllerMappings.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func mapping(for control: ControllerControl) -> ButtonMapping {
        mappings[control] ?? .empty(for: control)
    }

    func update(_ mapping: ButtonMapping) {
        mappings[mapping.control] = mapping
        save()
    }

    func update(_ control: ControllerControl, mutate: (inout ButtonMapping) -> Void) {
        var mapping = mapping(for: control)
        mutate(&mapping)
        update(mapping)
    }

    func resetToDefaults() {
        mappings = Self.defaultMappings()
        save()
    }

    func exportData(exportedAt: Date = Date()) throws -> Data {
        let backup = MappingBackup(
            formatVersion: 1,
            exportedAt: exportedAt,
            mappings: ControllerControl.allCases.map { mapping(for: $0) }
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(backup)
    }

    func importData(_ data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(MappingBackup.self, from: data)
        guard backup.formatVersion == 1 else {
            throw MappingBackupError.unsupportedVersion(backup.formatVersion)
        }

        var imported: [ControllerControl: ButtonMapping] = [:]
        for mapping in backup.mappings {
            guard imported[mapping.control] == nil else {
                throw MappingBackupError.duplicateControl(mapping.control.rawValue)
            }
            imported[mapping.control] = mapping
        }
        let defaults = Self.defaultMappings()
        for control in ControllerControl.allCases where imported[control] == nil {
            imported[control] = defaults[control] ?? .empty(for: control)
        }
        mappings = imported
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([ButtonMapping].self, from: data)
        else {
            mappings = Self.defaultMappings()
            return
        }
        mappings = Dictionary(uniqueKeysWithValues: decoded.map { ($0.control, $0) })
        let defaults = Self.defaultMappings()
        for control in ControllerControl.allCases where mappings[control] == nil {
            mappings[control] = defaults[control] ?? .empty(for: control)
        }
    }

    private func save() {
        let ordered = ControllerControl.allCases.map { mapping(for: $0) }
        guard let data = try? JSONEncoder().encode(ordered) else { return }
        defaults.set(data, forKey: defaultsKey)
    }

    private static func defaultMappings() -> [ControllerControl: ButtonMapping] {
        var result = Dictionary(uniqueKeysWithValues: ControllerControl.allCases.map { ($0, ButtonMapping.empty(for: $0)) })
        result[.rightTrigger] = ButtonMapping(
            control: .rightTrigger,
            actionKind: .shortcut,
            shortcut: .rightCommand,
            triggerBehavior: .hold,
            shellCommand: ""
        )
        for control in [ControllerControl.leftStickUp, .leftStickDown, .leftStickLeft, .leftStickRight] {
            result[control] = ButtonMapping(
                control: control,
                actionKind: .scroll,
                shortcut: nil,
                triggerBehavior: .hold,
                shellCommand: "",
                scrollDirection: control.defaultScrollDirection
            )
        }
        result[.rightStickLeft] = ButtonMapping(
            control: .rightStickLeft,
            actionKind: .appSwitch,
            shortcut: nil,
            triggerBehavior: .tap,
            shellCommand: "",
            appSwitchDirection: .previous
        )
        result[.rightStickRight] = ButtonMapping(
            control: .rightStickRight,
            actionKind: .appSwitch,
            shortcut: nil,
            triggerBehavior: .tap,
            shellCommand: "",
            appSwitchDirection: .next
        )
        return result
    }
}
