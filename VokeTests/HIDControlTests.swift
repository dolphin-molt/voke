import XCTest
@testable import Voke

@MainActor
final class HIDControlTests: XCTestCase {
    func testDynamicHIDControlRoundTripsThroughCodable() throws {
        let control = ControllerControl.hid(usagePage: 9, usage: 4)
        let data = try JSONEncoder().encode(control)
        XCTAssertEqual(try JSONDecoder().decode(ControllerControl.self, from: data), control)
        XCTAssertEqual(control.rawValue, "HID:9:4")
    }

    func testMouseControlsUseReadableLabelsInsteadOfRawHIDIdentifiers() {
        XCTAssertEqual(ControllerControl.hid(usagePage: 9, usage: 1).compactLabel, "鼠标左键")
        XCTAssertEqual(ControllerControl.hid(usagePage: 9, usage: 2).compactLabel, "鼠标右键")
        XCTAssertEqual(ControllerControl.hid(usagePage: 9, usage: 3).compactLabel, "鼠标中键")
        XCTAssertEqual(ControllerControl.hid(usagePage: 9, usage: 4).compactLabel, "鼠标侧键 1")
    }

    func testDynamicControlsPersistInDeviceMappings() throws {
        let suite = "HIDControlTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let control = ControllerControl.hid(usagePage: 7, usage: 41)
        let device = InputDeviceDescriptor(
            id: "hid.test",
            name: "Test Keyboard",
            kind: .hidKeyboard,
            connected: true,
            controls: [control],
            controlLabels: [control: "Esc"]
        )

        let store = MappingStore(defaults: defaults)
        store.registerDevice(device)
        store.update(control) { mapping in
            mapping.actionKind = .screenshot
        }

        let reloaded = MappingStore(defaults: defaults)
        XCTAssertEqual(reloaded.mapping(for: control).actionKind, .screenshot)
        XCTAssertTrue(reloaded.mappings.keys.contains(control))
    }

    func testKeyboardProductWinsOverMisleadingMouseCollection() {
        let kind = HIDDeviceClassifier.kind(
            product: "USB KEYBOARD",
            capabilities: [.keyboard, .mouse, .consumerControls],
            declaredMouseButtonCount: 3
        )

        XCTAssertEqual(kind, .hidKeyboard)
    }

    func testGamingDeviceWithMouseButtonsIsClassifiedAsMouse() {
        let kind = HIDDeviceClassifier.kind(
            product: "Rapoo Gaming Device",
            capabilities: [.keyboard, .mouse],
            declaredMouseButtonCount: 0,
            hasRelativePointerAxes: false
        )

        XCTAssertEqual(kind, .hidMouse)
    }

    func testAmbiguousCompositeDeviceRemainsComposite() {
        let kind = HIDDeviceClassifier.kind(
            product: "HID Device",
            capabilities: [.keyboard, .mouse],
            declaredMouseButtonCount: 0
        )

        XCTAssertEqual(kind, .hidComposite)
    }
}
