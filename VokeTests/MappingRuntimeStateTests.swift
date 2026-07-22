import XCTest
@testable import Voke

final class MappingRuntimeStateTests: XCTestCase {
    func testPausedTakesPriorityOverMissingDeviceAndPermissions() {
        XCTAssertEqual(
            MappingRuntimeState.resolve(
                mappingEnabled: false,
                selectedDevice: nil,
                inputMonitoringGranted: false,
                accessibilityTrusted: false
            ),
            .paused
        )
    }

    func testEnabledMappingWaitsForAConnectedDevice() {
        XCTAssertEqual(
            MappingRuntimeState.resolve(
                mappingEnabled: true,
                selectedDevice: device(kind: .gameController, connected: false),
                inputMonitoringGranted: true,
                accessibilityTrusted: true
            ),
            .waitingForDevice
        )
    }

    func testHIDDeviceRequiresInputMonitoringBeforeAccessibility() {
        XCTAssertEqual(
            MappingRuntimeState.resolve(
                mappingEnabled: true,
                selectedDevice: device(kind: .hidKeyboard),
                inputMonitoringGranted: false,
                accessibilityTrusted: false
            ),
            .needsInputMonitoring
        )
    }

    func testConnectedDeviceRequiresAccessibilityForSystemOutput() {
        XCTAssertEqual(
            MappingRuntimeState.resolve(
                mappingEnabled: true,
                selectedDevice: device(kind: .gameController),
                inputMonitoringGranted: true,
                accessibilityTrusted: false
            ),
            .needsAccessibility
        )
    }

    func testReadyRequiresEnabledMappingConnectedDeviceAndPermissions() {
        XCTAssertEqual(
            MappingRuntimeState.resolve(
                mappingEnabled: true,
                selectedDevice: device(kind: .hidMouse),
                inputMonitoringGranted: true,
                accessibilityTrusted: true
            ),
            .ready
        )
    }

    private func device(kind: InputDeviceKind, connected: Bool = true) -> InputDeviceDescriptor {
        InputDeviceDescriptor(
            id: "test-device",
            name: "Test Device",
            kind: kind,
            connected: connected,
            controls: []
        )
    }
}
