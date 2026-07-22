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
    case duplicateApplicationBinding(String)
    case emptyBackup

    var errorDescription: String? {
        switch self {
        case let .unsupportedVersion(version): "不支持的配置版本：\(version)"
        case let .duplicateControl(control): "配置中存在重复按键：\(control)"
        case let .duplicateDevice(device): "配置中存在重复设备：\(device)"
        case let .duplicateApplicationBinding(bundleIdentifier): "同一设备中有多个方案绑定了 App：\(bundleIdentifier)"
        case .emptyBackup: "配置文件中没有可导入的设备"
        }
    }
}

@MainActor
final class MappingStore: ObservableObject {
    @Published private(set) var configurations: [String: DeviceMappingConfiguration] = [:]
    @Published private(set) var selectedDeviceID: String?
    @Published private(set) var applicationContext: ApplicationContext = .desktop
    @Published var contextualProfilesEnabled: Bool {
        didSet {
            defaults.set(contextualProfilesEnabled, forKey: contextualProfilesEnabledKey)
        }
    }

    private let legacyDefaultsKey = "controllerMappings.v1"
    private let configurationsKey = "deviceConfigurations.v2"
    private let selectedDeviceKey = "selectedInputDevice.v2"
    private let mouseControlsMigrationKey = "mouseControlsMigration.v1"
    private let contextualProfilesEnabledKey = "contextualProfilesEnabled.v1"
    private let defaults: UserDefaults
    private var pendingLegacyMappings: [ButtonMapping]?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        contextualProfilesEnabled = defaults.object(forKey: contextualProfilesEnabledKey) as? Bool ?? true
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
    var activeProfileID: UUID? {
        guard let configuration = selectedConfiguration else { return nil }
        return resolvedProfile(in: configuration)?.id
    }
    var activeProfileName: String { activeProfile?.name ?? "默认方案" }
    var currentApplicationUsesDedicatedProfile: Bool {
        guard contextualProfilesEnabled,
              let bundleIdentifier = applicationContext.bundleIdentifier,
              let configuration = selectedConfiguration
        else { return false }
        return configuration.profiles.contains { $0.isBound(to: bundleIdentifier) }
    }

    var fallbackProfileID: UUID? { selectedConfiguration?.activeProfileID }
    var fallbackProfileName: String {
        guard let configuration = selectedConfiguration else { return "默认方案" }
        return activeProfile(in: configuration)?.name ?? "默认方案"
    }

    var availableApplicationActions: [ApplicationActionPreset] {
        guard currentApplicationUsesDedicatedProfile else { return [] }
        return ApplicationActionRegistry.actions(for: applicationContext.bundleIdentifier)
    }

    func updateApplicationContext(bundleIdentifier: String?, displayName: String) {
        let context = ApplicationContext(bundleIdentifier: bundleIdentifier, displayName: displayName)
        guard context != applicationContext else { return }
        applicationContext = context
    }

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
              let index = resolvedProfileIndex(in: configuration)
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
              let index = resolvedProfileIndex(in: configuration)
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

    func addProfile(forCurrentApplication: Bool = true) {
        guard let selectedDeviceID,
              var configuration = configurations[selectedDeviceID],
              let current = resolvedProfile(in: configuration)
        else { return }
        let shouldBindApplication = forCurrentApplication && contextualProfilesEnabled && applicationContext.isBindable
        let baseName = shouldBindApplication ? applicationContext.displayName : "方案"
        let existingNames = Set(configuration.profiles.map(\.name))
        var candidate = "\(baseName) 方案"
        var suffix = 2
        while existingNames.contains(candidate) {
            candidate = "\(baseName) 方案 \(suffix)"
            suffix += 1
        }
        let profile = MappingProfile(
            id: UUID(),
            name: candidate,
            mappings: current.mappings,
            applicationBundleIdentifiers: shouldBindApplication ? applicationContext.bundleIdentifier.map { [$0] } : nil
        )
        if let bundleIdentifier = applicationContext.bundleIdentifier, shouldBindApplication {
            removeBinding(bundleIdentifier, from: &configuration)
        }
        configuration.profiles.append(profile)
        if !shouldBindApplication {
            configuration.activeProfileID = profile.id
        }
        configurations[selectedDeviceID] = configuration
        save()
    }

    func deleteActiveProfile() {
        guard let configuration = selectedConfiguration,
              let profileID = resolvedProfile(in: configuration)?.id
        else { return }
        deleteProfile(profileID)
    }

    func setActiveProfile(_ profileID: UUID) {
        guard let selectedDeviceID,
              var configuration = configurations[selectedDeviceID],
              let profile = configuration.profiles.first(where: { $0.id == profileID }),
              profile.applicationBundleIdentifiers?.isEmpty != false
        else { return }
        configuration.activeProfileID = profileID
        configurations[selectedDeviceID] = configuration
        save()
    }

    func useProfileForCurrentApplication(_ profileID: UUID) {
        guard contextualProfilesEnabled,
              let bundleIdentifier = applicationContext.bundleIdentifier,
              let selectedDeviceID,
              var configuration = configurations[selectedDeviceID],
              profileID != configuration.activeProfileID,
              let index = configuration.profiles.firstIndex(where: { $0.id == profileID }),
              configuration.profiles[index].applicationBundleIdentifiers?.first == nil
                || configuration.profiles[index].isBound(to: bundleIdentifier)
        else {
            setActiveProfile(profileID)
            return
        }
        removeBinding(bundleIdentifier, from: &configuration)
        configuration.profiles[index].applicationBundleIdentifiers = [bundleIdentifier]
        configurations[selectedDeviceID] = configuration
        save()
    }

    func stopUsingDedicatedProfileForCurrentApplication() {
        guard let bundleIdentifier = applicationContext.bundleIdentifier,
              let selectedDeviceID,
              var configuration = configurations[selectedDeviceID]
        else { return }
        removeBinding(bundleIdentifier, from: &configuration)
        configurations[selectedDeviceID] = configuration
        save()
    }

    func isProfileUsedByCurrentApplication(_ profileID: UUID) -> Bool {
        guard let bundleIdentifier = applicationContext.bundleIdentifier,
              let profile = profiles.first(where: { $0.id == profileID })
        else { return false }
        return profile.isBound(to: bundleIdentifier)
    }

    func renameActiveProfile(_ name: String) {
        guard let profileID = activeProfileID else { return }
        renameProfile(profileID, to: name)
    }

    func renameProfile(_ profileID: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let selectedDeviceID,
              var configuration = configurations[selectedDeviceID],
              let index = configuration.profiles.firstIndex(where: { $0.id == profileID })
        else { return }
        configuration.profiles[index].name = trimmed
        configurations[selectedDeviceID] = configuration
        save()
    }

    func deleteProfile(_ profileID: UUID) {
        guard let selectedDeviceID,
              var configuration = configurations[selectedDeviceID],
              configuration.profiles.count > 1,
              configuration.profiles.contains(where: { $0.id == profileID })
        else { return }
        configuration.profiles.removeAll { $0.id == profileID }
        configurations[selectedDeviceID] = normalized(configuration)
        save()
    }

    func clearApplicationBindings(for profileID: UUID) {
        guard let selectedDeviceID,
              var configuration = configurations[selectedDeviceID],
              let index = configuration.profiles.firstIndex(where: { $0.id == profileID })
        else { return }
        configuration.profiles[index].applicationBundleIdentifiers = nil
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
                var claimedApplications = Set<String>()
                for profile in device.profiles {
                    var controls = Set<ControllerControl>()
                    for mapping in profile.mappings where !controls.insert(mapping.control).inserted {
                        throw MappingBackupError.duplicateControl("\(device.deviceName) / \(mapping.control.rawValue)")
                    }
                    for bundleIdentifier in Set(profile.applicationBundleIdentifiers ?? [])
                    where !claimedApplications.insert(bundleIdentifier).inserted {
                        throw MappingBackupError.duplicateApplicationBinding(bundleIdentifier)
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
        return resolvedProfile(in: configuration)
    }

    private func activeProfile(in configuration: DeviceMappingConfiguration) -> MappingProfile? {
        configuration.profiles.first { $0.id == configuration.activeProfileID }
    }

    private func resolvedProfile(in configuration: DeviceMappingConfiguration) -> MappingProfile? {
        if contextualProfilesEnabled,
           let bundleIdentifier = applicationContext.bundleIdentifier,
           let contextual = configuration.profiles.first(where: { $0.isBound(to: bundleIdentifier) }) {
            return contextual
        }
        return activeProfile(in: configuration)
    }

    private func resolvedProfileIndex(in configuration: DeviceMappingConfiguration) -> Int? {
        guard let profileID = resolvedProfile(in: configuration)?.id else { return nil }
        return configuration.profiles.firstIndex { $0.id == profileID }
    }

    private func removeBinding(_ bundleIdentifier: String, from configuration: inout DeviceMappingConfiguration) {
        for index in configuration.profiles.indices {
            let filtered = configuration.profiles[index].applicationBundleIdentifiers?.filter { $0 != bundleIdentifier } ?? []
            configuration.profiles[index].applicationBundleIdentifiers = filtered.isEmpty ? nil : filtered
        }
    }

    private func mappingDictionary(deviceID: String) -> [ControllerControl: ButtonMapping] {
        guard let configuration = configurations[deviceID],
              let profile = resolvedProfile(in: configuration)
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
        var claimedApplications = Set<String>()
        for index in result.profiles.indices {
            result.profiles[index].mappings = normalizedMappings(result.profiles[index].mappings, kind: result.deviceKind)
            let identifiers = result.profiles[index].applicationBundleIdentifiers ?? []
            let normalizedIdentifiers = identifiers
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if normalizedIdentifiers.isEmpty {
                result.profiles[index].applicationBundleIdentifiers = nil
            } else {
                let preferred = preferredApplicationIdentifier(from: normalizedIdentifiers)
                result.profiles[index].applicationBundleIdentifiers = claimedApplications.insert(preferred).inserted
                    ? [preferred]
                    : nil
            }
        }
        if !result.profiles.contains(where: { $0.id == result.activeProfileID && $0.applicationBundleIdentifiers?.isEmpty != false }) {
            if let genericProfile = result.profiles.first(where: { $0.applicationBundleIdentifiers?.isEmpty != false }) {
                result.activeProfileID = genericProfile.id
            } else {
                let source = result.profiles.first!
                let genericProfile = MappingProfile(
                    id: UUID(),
                    name: "默认方案",
                    mappings: source.mappings,
                    applicationBundleIdentifiers: nil
                )
                result.profiles.insert(genericProfile, at: 0)
                result.activeProfileID = genericProfile.id
            }
        }
        return result
    }

    private func preferredApplicationIdentifier(from identifiers: [String]) -> String {
        let unique = Array(Set(identifiers)).sorted()
        if let chatGPT = unique.first(where: { ApplicationActionRegistry.chatGPTBundleIdentifiers.contains($0) }) {
            return chatGPT
        }
        return unique[0]
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
