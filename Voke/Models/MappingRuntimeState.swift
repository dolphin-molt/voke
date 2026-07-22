import Foundation

enum MappingRuntimeState: Equatable {
    case paused
    case waitingForDevice
    case needsInputMonitoring
    case needsAccessibility
    case ready

    var label: String {
        switch self {
        case .paused: "映射已暂停"
        case .waitingForDevice: "等待设备连接"
        case .needsInputMonitoring: "需要输入监控"
        case .needsAccessibility: "需要辅助功能"
        case .ready: "映射运行中"
        }
    }

    var isReady: Bool { self == .ready }
    var isPaused: Bool { self == .paused }

    static func resolve(
        mappingEnabled: Bool,
        selectedDevice: InputDeviceDescriptor?,
        inputMonitoringGranted: Bool,
        accessibilityTrusted: Bool
    ) -> MappingRuntimeState {
        guard mappingEnabled else { return .paused }
        guard let selectedDevice, selectedDevice.connected else { return .waitingForDevice }
        if selectedDevice.kind.isHID && !inputMonitoringGranted {
            return .needsInputMonitoring
        }
        guard accessibilityTrusted else { return .needsAccessibility }
        return .ready
    }
}
