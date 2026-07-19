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

        XCTAssertEqual(store.mapping(for: .leftStickUp).actionKind, .scroll)
        XCTAssertEqual(store.mapping(for: .leftStickUp).scrollDirection, .up)
        XCTAssertEqual(store.mapping(for: .leftStickDown).scrollDirection, .down)
        XCTAssertEqual(store.mapping(for: .leftStickLeft).scrollDirection, .left)
        XCTAssertEqual(store.mapping(for: .leftStickRight).scrollDirection, .right)
        XCTAssertEqual(store.mapping(for: .rightStickLeft).appSwitchDirection, .previous)
        XCTAssertEqual(store.mapping(for: .rightStickRight).appSwitchDirection, .next)
        XCTAssertEqual(store.mapping(for: .rightStickUp).actionKind, .none)
    }

    func testExportImportRoundTripPreservesMappings() throws {
        let source = MappingStore(defaults: defaults)
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
        let original = store.mappings
        let backup = MappingBackup(formatVersion: 99, exportedAt: Date(), mappings: [])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        XCTAssertThrowsError(try store.importData(encoder.encode(backup)))
        XCTAssertEqual(store.mappings, original)
    }
}
