import Combine
import Foundation

struct MappingBackup: Codable {
    let formatVersion: Int
    let exportedAt: Date
    let mappings: [ButtonMapping]?
    let devices: [DeviceMappingConfiguration]?

    init(formatVersion: Int, exportedAt: Date, mappings: [ButtonMapping]) {
        self.formatVersion = formatVersion
        self.exportedAt = exportedAt
        self.mappings = mappings
        self.devices = nil
    }

    init(formatVersion: Int, exportedAt: Date, devices: [DeviceMappingConfiguration]) {
        self.formatVersion = formatVersion
        self.exportedAt = exportedAt
        self.mappings = nil
        self.devices = devices
    }
}

enum MappingBackupError: LocalizedError {
    case unsupportedVersion(Int)
    case duplicateControl(String)
    case duplicateDevice(String)
    case emptyBackup

    var errorDescription: String? {
        switch self {
        case let .unsupportedVersion(version): "不支持的配置版本：\(version)"
        case let .duplicateControl(control): "配置中存在重复按键：\(control)"
        case let .duplicateDevice(device): "配置中存在重复设备：\(device)"
        case .emptyBackup: "配置文件中没有可导入的设备"
        }
    }
}

@MainActor
final class MappingStore: ObservableObject {
    @Published private(set) var configurations: [String: DeviceMappingConfiguration] = [:]
    @Published private(set) var selectedDeviceID: String?

    private let legacyDefaultsKey = "controllerMappings.v1"
    private let configurationsKey = "deviceConfigurations.v2"
    private let selectedDeviceKey = "selectedInputDevice.v2"
    private let mouseControlsMigrationKey = "mouseControlsMigration.v1"
    private let defaults: UserDefaults
    private var pendingLegacyMappings: [ButtonMapping]?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    var mappings: [ControllerControl: ButtonMapping] {
        guard let selectedDeviceID else { return [:] }
        return mappingDictionary(deviceID: selectedDeviceID)
    }

    var selectedConfiguration: DeviceMappingConfiguration? {
        guard let selectedDeviceID else { return nil }
        return configurations[selectedDeviceID]
    }

    var profiles: [MappingProfile] { selectedConfiguration?.profiles ?? [] }
    var activeProfileID: UUID? { selectedConfiguration?.activeProfileID }
    var activeProfileName: String { activeProfile?.name ?? "默认方案" }

    func registerDevice(_ device: InputDeviceDescriptor) {
        if var existing = configurations[device.id] {
            existing.deviceName = device.name
            existing.deviceKind = device.kind
            configurations[device.id] = addingControls(
                device.controls,
                to: migratedMouseDefaultsIfNeeded(normalized(existing))
            )
        } else {
            var mappings = pendingLegacyMappings ?? Self.defaultMappings(for: device.kind).values.map { $0 }
            pendingLegacyMappings = nil
            let existingControls = Set(mappings.map(\.control))
            mappings.append(contentsOf: device.controls.filter { !existingControls.contains($0) }.map(ButtonMapping.empty))
            let profile = MappingProfile(
                id: UUID(),
                name: "默认方案",
                mappings: normalizedMappings(mappings, kind: device.kind)
            )
            configurations[device.id] = DeviceMappingConfiguration(
                deviceID: device.id,
                deviceName: device.name,
                deviceKind: device.kind,
                activeProfileID: profile.id,
                profiles: [profile]
            )
        }
        if selectedDeviceID == nil || configurations[selectedDeviceID ?? ""] == nil {
            selectedDeviceID = device.id
        }
        save()
    }

    func selectDevice(_ deviceID: String) {
        guard configurations[deviceID] != nil else { return }
        selectedDeviceID = deviceID
        defaults.set(deviceID, forKey: selectedDeviceKey)
    }

    func mapping(for control: ControllerControl) -> ButtonMapping {
        guard let selectedDeviceID else { return .empty(for: control) }
        return mapping(for: control, deviceID: selectedDeviceID)
    }

    func mapping(for control: ControllerControl, deviceID: String) -> ButtonMapping {
        mappingDictionary(deviceID: deviceID)[control] ?? .empty(for: control)
    }

    func update(_ mapping: ButtonMapping) {
        guard let selectedDeviceID else { return }
        update(mapping, deviceID: selectedDeviceID)
    }

    func update(_ mapping: ButtonMapping, deviceID: String) {
        guard var configuration = configurations[deviceID],
              let index = configuration.profiles.firstIndex(where: { $0.id == configuration.activeProfileID })
        else { return }
        var dictionary = Dictionary(uniqueKeysWithValues: configuration.profiles[index].mappings.map { ($0.control, $0) })
        dictionary[mapping.control] = mapping
        configuration.profiles[index].mappings = orderedMappings(dictionary)
        configurations[deviceID] = configuration
        save()
    }

    func update(_ control: ControllerControl, mutate: (inout ButtonMapping) -> Void) {
        var mapping = mapping(for: control)
        mutate(&mapping)
        update(mapping)
    }

    func resetToDefaults() {
        guard let selectedDeviceID,
              var configuration = configurations[selectedDeviceID],
              let index = configuration.profiles.firstIndex(where: { $0.id == configuration.activeProfileID })
        else { return }
        if configuration.deviceKind == .gameController {
            configuration.profiles[index].mappings = ControllerControl.allCases.compactMap {
                Self.defaultMappings(for: configuration.deviceKind)[$0]
            }
        } else {
            configuration.profiles[index].mappings = configuration.profiles[index].mappings.map {
                .empty(for: $0.control)
            }
        }
        configurations[selectedDeviceID] = configuration
        save()
    }

    func addProfile() {
        guard let selectedDeviceID,
              var configuration = configurations[selectedDeviceID],
              let current = activeProfile(in: configuration)
        else { return }
        let profile = MappingProfile(
            id: UUID(),
            name: "方案 \(configuration.profiles.count + 1)",
            mappings: current.mappings
        )
        configuration.profiles.append(profile)
        configuration.activeProfileID = profile.id
        configurations[selectedDeviceID] = configuration
        save()
    }

    func deleteActiveProfile() {
        guard let selectedDeviceID,
              var configuration = configurations[selectedDeviceID],
              configuration.profiles.count > 1
        else { return }
        configuration.profiles.removeAll { $0.id == configuration.activeProfileID }
        configuration.activeProfileID = configuration.profiles[0].id
        configurations[selectedDeviceID] = configuration
        save()
    }

    func setActiveProfile(_ profileID: UUID) {
        guard let selectedDeviceID,
              var configuration = configurations[selectedDeviceID],
              configuration.profiles.contains(where: { $0.id == profileID })
        else { return }
        configuration.activeProfileID = profileID
        configurations[selectedDeviceID] = configuration
        save()
    }

    func renameActiveProfile(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let selectedDeviceID,
              var configuration = configurations[selectedDeviceID],
              let index = configuration.profiles.firstIndex(where: { $0.id == configuration.activeProfileID })
        else { return }
        configuration.profiles[index].name = trimmed
        configurations[selectedDeviceID] = configuration
        save()
    }

    func exportData(exportedAt: Date = Date()) throws -> Data {
        let backup = MappingBackup(
            formatVersion: 2,
            exportedAt: exportedAt,
            devices: configurations.values.sorted { $0.deviceName < $1.deviceName }
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
        switch backup.formatVersion {
        case 1:
            guard let mappings = backup.mappings else { throw MappingBackupError.emptyBackup }
            let deviceID = selectedDeviceID ?? "imported.game-controller"
            let profile = MappingProfile(id: UUID(), name: "导入方案", mappings: normalizedMappings(mappings, kind: .gameController))
            configurations[deviceID] = DeviceMappingConfiguration(
                deviceID: deviceID,
                deviceName: selectedConfiguration?.deviceName ?? "导入的手柄",
                deviceKind: .gameController,
                activeProfileID: profile.id,
                profiles: [profile]
            )
            selectedDeviceID = deviceID
        case 2:
            guard let devices = backup.devices, !devices.isEmpty else { throw MappingBackupError.emptyBackup }
            var imported: [String: DeviceMappingConfiguration] = [:]
            for device in devices {
                guard imported[device.deviceID] == nil else {
                    throw MappingBackupError.duplicateDevice(device.deviceID)
                }
                for profile in device.profiles {
                    var controls = Set<ControllerControl>()
                    for mapping in profile.mappings where !controls.insert(mapping.control).inserted {
                        throw MappingBackupError.duplicateControl("\(device.deviceName) / \(mapping.control.rawValue)")
                    }
                }
                imported[device.deviceID] = normalized(device)
            }
            configurations = imported
            selectedDeviceID = devices.first?.deviceID
        default:
            throw MappingBackupError.unsupportedVersion(backup.formatVersion)
        }
        save()
    }

    private var activeProfile: MappingProfile? {
        guard let configuration = selectedConfiguration else { return nil }
        return activeProfile(in: configuration)
    }

    private func activeProfile(in configuration: DeviceMappingConfiguration) -> MappingProfile? {
        configuration.profiles.first { $0.id == configuration.activeProfileID }
    }

    private func mappingDictionary(deviceID: String) -> [ControllerControl: ButtonMapping] {
        guard let configuration = configurations[deviceID],
              let profile = activeProfile(in: configuration)
        else { return [:] }
        return Dictionary(uniqueKeysWithValues: profile.mappings.map { ($0.control, $0) })
    }

    private func load() {
        if let data = defaults.data(forKey: configurationsKey),
           let decoded = try? JSONDecoder().decode([DeviceMappingConfiguration].self, from: data) {
            configurations = Dictionary(uniqueKeysWithValues: decoded.map {
                ($0.deviceID, migratedMouseDefaultsIfNeeded(normalized($0)))
            })
            if !defaults.bool(forKey: mouseControlsMigrationKey) {
                configurations = configurations.mapValues(applyingMouseControls)
                defaults.set(true, forKey: mouseControlsMigrationKey)
            }
            let savedSelection = defaults.string(forKey: selectedDeviceKey)
            selectedDeviceID = savedSelection.flatMap { configurations[$0] == nil ? nil : $0 }
                ?? decoded.first?.deviceID
            save()
            return
        }

        if let data = defaults.data(forKey: legacyDefaultsKey),
           let decoded = try? JSONDecoder().decode([ButtonMapping].self, from: data) {
            pendingLegacyMappings = decoded
        }
    }

    private func save() {
        let ordered = configurations.values.sorted { $0.deviceID < $1.deviceID }
        guard let data = try? JSONEncoder().encode(ordered) else { return }
        defaults.set(data, forKey: configurationsKey)
        defaults.set(selectedDeviceID, forKey: selectedDeviceKey)
    }

    private func normalized(_ configuration: DeviceMappingConfiguration) -> DeviceMappingConfiguration {
        var result = configuration
        if result.profiles.isEmpty {
            let profile = MappingProfile(
                id: UUID(),
                name: "默认方案",
                mappings: normalizedMappings([], kind: result.deviceKind)
            )
            result.profiles = [profile]
            result.activeProfileID = profile.id
        }
        for index in result.profiles.indices {
            result.profiles[index].mappings = normalizedMappings(result.profiles[index].mappings, kind: result.deviceKind)
        }
        if !result.profiles.contains(where: { $0.id == result.activeProfileID }) {
            result.activeProfileID = result.profiles[0].id
        }
        return result
    }

    private func normalizedMappings(_ mappings: [ButtonMapping], kind: InputDeviceKind) -> [ButtonMapping] {
        var result: [ControllerControl: ButtonMapping] = [:]
        for mapping in mappings {
            guard result[mapping.control] == nil else { continue }
            result[mapping.control] = mapping
        }
        let defaults = Self.defaultMappings(for: kind)
        for control in defaults.keys where result[control] == nil {
            result[control] = defaults[control] ?? .empty(for: control)
        }
        return orderedMappings(result)
    }

    private static func defaultMappings(for kind: InputDeviceKind) -> [ControllerControl: ButtonMapping] {
        guard kind == .gameController else { return [:] }
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
        for control in [ControllerControl.rightStickUp, .rightStickDown, .rightStickLeft, .rightStickRight] {
            result[control] = ButtonMapping(
                control: control,
                actionKind: .mouseMove,
                shortcut: nil,
                triggerBehavior: .hold,
                shellCommand: ""
            )
        }
        result[.rightStick] = ButtonMapping(
            control: .rightStick,
            actionKind: .mouseClick,
            shortcut: nil,
            triggerBehavior: .tap,
            shellCommand: ""
        )
        result[.capture] = ButtonMapping(
            control: .capture,
            actionKind: .screenshot,
            shortcut: nil,
            triggerBehavior: .tap,
            shellCommand: ""
        )
        return result
    }

    private func migratedMouseDefaultsIfNeeded(_ configuration: DeviceMappingConfiguration) -> DeviceMappingConfiguration {
        guard configuration.deviceKind == .gameController else { return configuration }
        var result = configuration
        for index in result.profiles.indices {
            var mappings = Dictionary(uniqueKeysWithValues: result.profiles[index].mappings.map { ($0.control, $0) })
            let usesOldDefaults = mappings[.rightStickUp]?.actionKind == MappingActionKind.none
                && mappings[.rightStickDown]?.actionKind == MappingActionKind.none
                && mappings[.rightStickLeft]?.actionKind == .appSwitch
                && mappings[.rightStickRight]?.actionKind == .appSwitch
                && mappings[.rightStick]?.actionKind == MappingActionKind.none
            guard usesOldDefaults else { continue }

            for control in [ControllerControl.rightStickUp, .rightStickDown, .rightStickLeft, .rightStickRight] {
                mappings[control] = ButtonMapping(
                    control: control,
                    actionKind: .mouseMove,
                    shortcut: nil,
                    triggerBehavior: .hold,
                    shellCommand: ""
                )
            }
            mappings[.rightStick] = ButtonMapping(
                control: .rightStick,
                actionKind: .mouseClick,
                shortcut: nil,
                triggerBehavior: .tap,
                shellCommand: ""
            )
            result.profiles[index].mappings = orderedMappings(mappings)
        }
        return result
    }

    private func applyingMouseControls(_ configuration: DeviceMappingConfiguration) -> DeviceMappingConfiguration {
        guard configuration.deviceKind == .gameController else { return configuration }
        var result = configuration
        for index in result.profiles.indices {
            var mappings = Dictionary(uniqueKeysWithValues: result.profiles[index].mappings.map { ($0.control, $0) })
            for control in [ControllerControl.rightStickUp, .rightStickDown, .rightStickLeft, .rightStickRight] {
                mappings[control] = ButtonMapping(
                    control: control,
                    actionKind: .mouseMove,
                    shortcut: nil,
                    triggerBehavior: .hold,
                    shellCommand: ""
                )
            }
            mappings[.rightStick] = ButtonMapping(
                control: .rightStick,
                actionKind: .mouseClick,
                shortcut: nil,
                triggerBehavior: .tap,
                shellCommand: ""
            )
            result.profiles[index].mappings = orderedMappings(mappings)
        }
        return result
    }

    private func orderedMappings(_ mappings: [ControllerControl: ButtonMapping]) -> [ButtonMapping] {
        let builtIn = ControllerControl.allCases.compactMap { mappings[$0] }
        let known = Set(ControllerControl.allCases)
        let dynamic = mappings
            .filter { !known.contains($0.key) }
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map(\.value)
        return builtIn + dynamic
    }

    private func addingControls(
        _ controls: [ControllerControl],
        to configuration: DeviceMappingConfiguration
    ) -> DeviceMappingConfiguration {
        var result = configuration
        for index in result.profiles.indices {
            var mappings = Dictionary(uniqueKeysWithValues: result.profiles[index].mappings.map { ($0.control, $0) })
            for control in controls where mappings[control] == nil {
                mappings[control] = .empty(for: control)
            }
            result.profiles[index].mappings = orderedMappings(mappings)
        }
        return result
    }
}
