import Combine
import Foundation

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

    private func load() {
        guard let data = defaults.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([ButtonMapping].self, from: data)
        else {
            mappings = Self.defaultMappings()
            return
        }
        mappings = Dictionary(uniqueKeysWithValues: decoded.map { ($0.control, $0) })
        for control in ControllerControl.allCases where mappings[control] == nil {
            mappings[control] = .empty(for: control)
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
        return result
    }
}
