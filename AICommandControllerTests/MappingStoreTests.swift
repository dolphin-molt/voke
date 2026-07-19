import XCTest
@testable import AICommandController

@MainActor
final class MappingStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "MappingStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testNewStoreDefaultsSticksToScrollAndAppSwitch() {
        let store = MappingStore(defaults: defaults)
        store.registerDevice(gamepad(id: "gamepad.one"))

        XCTAssertEqual(store.mapping(for: .leftStickUp).actionKind, .scroll)
        XCTAssertEqual(store.mapping(for: .leftStickUp).scrollDirection, .up)
        XCTAssertEqual(store.mapping(for: .leftStickDown).scrollDirection, .down)
        XCTAssertEqual(store.mapping(for: .leftStickLeft).scrollDirection, .left)
        XCTAssertEqual(store.mapping(for: .leftStickRight).scrollDirection, .right)
        XCTAssertEqual(store.mapping(for: .rightStickLeft).appSwitchDirection, .previous)
        XCTAssertEqual(store.mapping(for: .rightStickRight).appSwitchDirection, .next)
        XCTAssertEqual(store.mapping(for: .rightStickUp).actionKind, .none)
        XCTAssertEqual(store.mapping(for: .capture).actionKind, .screenshot)
    }

    func testExportImportRoundTripPreservesMappings() throws {
        let source = MappingStore(defaults: defaults)
        source.registerDevice(gamepad(id: "gamepad.one"))
        source.update(.rightTrigger) { mapping in
            mapping.actionKind = .shortcut
            mapping.shortcut = .rightControl
            mapping.triggerBehavior = .hold
        }
        let data = try source.exportData(exportedAt: Date(timeIntervalSince1970: 0))

        let secondSuite = "MappingStoreTests.\(UUID().uuidString)"
        let secondDefaults = try XCTUnwrap(UserDefaults(suiteName: secondSuite))
        defer { secondDefaults.removePersistentDomain(forName: secondSuite) }
        let destination = MappingStore(defaults: secondDefaults)
        try destination.importData(data)

        XCTAssertEqual(destination.mapping(for: .rightTrigger), source.mapping(for: .rightTrigger))
        XCTAssertEqual(destination.mappings.count, ControllerControl.allCases.count)
    }

    func testImportRejectsUnsupportedVersionWithoutChangingMappings() throws {
        let store = MappingStore(defaults: defaults)
        store.registerDevice(gamepad(id: "gamepad.one"))
        let original = store.mappings
        let backup = MappingBackup(formatVersion: 99, exportedAt: Date(), mappings: [])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        XCTAssertThrowsError(try store.importData(encoder.encode(backup)))
        XCTAssertEqual(store.mappings, original)
    }

    func testDevicesKeepIndependentMappings() {
        let store = MappingStore(defaults: defaults)
        store.registerDevice(gamepad(id: "gamepad.one"))
        store.registerDevice(gamepad(id: "gamepad.two"))

        store.selectDevice("gamepad.one")
        store.update(.a) { mapping in
            mapping.actionKind = .shortcut
            mapping.shortcut = KeyboardShortcut(keyCode: 0, modifierFlags: 0, modifierOnly: false)
        }

        XCTAssertEqual(store.mapping(for: .a, deviceID: "gamepad.one").shortcut?.keyCode, 0)
        XCTAssertEqual(store.mapping(for: .a, deviceID: "gamepad.two").actionKind, .none)
    }

    func testProfileCopiesCurrentMappingsAndCanSwitchBack() {
        let store = MappingStore(defaults: defaults)
        store.registerDevice(gamepad(id: "gamepad.one"))
        let originalProfile = try! XCTUnwrap(store.activeProfileID)
        store.update(.a) { $0.actionKind = .screenshot }

        store.addProfile()
        XCTAssertEqual(store.mapping(for: .a).actionKind, .screenshot)
        store.update(.a) { $0.actionKind = .none }
        store.setActiveProfile(originalProfile)

        XCTAssertEqual(store.mapping(for: .a).actionKind, .screenshot)
    }

    func testImportRejectsDuplicateDevices() throws {
        let profile = MappingProfile(id: UUID(), name: "默认方案", mappings: [])
        let device = DeviceMappingConfiguration(
            deviceID: "duplicate",
            deviceName: "Duplicate",
            deviceKind: .gameController,
            activeProfileID: profile.id,
            profiles: [profile]
        )
        let backup = MappingBackup(formatVersion: 2, exportedAt: Date(), devices: [device, device])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let store = MappingStore(defaults: defaults)
        XCTAssertThrowsError(try store.importData(encoder.encode(backup))) { error in
            guard case MappingBackupError.duplicateDevice("duplicate") = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    private func gamepad(id: String) -> InputDeviceDescriptor {
        InputDeviceDescriptor(
            id: id,
            name: "Test Controller",
            kind: .gameController,
            connected: true,
            controls: ControllerControl.gamepadControls
        )
    }
}
