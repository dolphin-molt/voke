import AppKit
import XCTest
@testable import Voke

final class KeyboardEventPlannerTests: XCTestCase {
    func testRightControlDownCarriesSideFlagButComboUsesPortableControlFlag() throws {
        var planner = KeyboardEventPlanner()
        let control = KeyboardShortcut.rightControl
        let a = KeyboardShortcut(keyCode: 0, modifierFlags: 0, modifierOnly: false)

        let controlDown = try XCTUnwrap(planner.press(control, id: "zr"))
        XCTAssertEqual(
            controlDown.flags,
            NSEvent.ModifierFlags.control.rawValue | KeyboardEventPlanner.modifierSideFlag(for: 62)
        )

        let aDown = try XCTUnwrap(planner.press(a, id: "a"))
        XCTAssertEqual(aDown.flags, NSEvent.ModifierFlags.control.rawValue)

        let aUp = try XCTUnwrap(planner.release(id: "a"))
        XCTAssertEqual(aUp.flags, NSEvent.ModifierFlags.control.rawValue)
        let controlUp = try XCTUnwrap(planner.release(id: "zr"))
        XCTAssertEqual(controlUp.flags, 0)
    }

    func testLeftCommandCombinesWithA() throws {
        var planner = KeyboardEventPlanner()
        let command = KeyboardShortcut(keyCode: 55, modifierFlags: NSEvent.ModifierFlags.command.rawValue, modifierOnly: true)
        let a = KeyboardShortcut(keyCode: 0, modifierFlags: 0, modifierOnly: false)

        _ = planner.press(command, id: "zl")
        let aDown = try XCTUnwrap(planner.press(a, id: "a"))

        XCTAssertEqual(aDown.flags, NSEvent.ModifierFlags.command.rawValue)
        XCTAssertFalse(aDown.flags & KeyboardEventPlanner.modifierSideFlag(for: 55) != 0)
    }

    func testTapAndRepeatPulseInheritHeldModifier() throws {
        var planner = KeyboardEventPlanner()
        _ = planner.press(.rightControl, id: "zr")
        let delete = KeyboardShortcut(keyCode: 51, modifierFlags: 0, modifierOnly: false)

        let tap = planner.tap(delete)
        XCTAssertEqual(tap.map(\.keyDown), [true, false])
        XCTAssertEqual(tap.map(\.flags), [NSEvent.ModifierFlags.control.rawValue, NSEvent.ModifierFlags.control.rawValue])

        _ = planner.press(delete, id: "minus")
        let repeatEvents = planner.repeatPulse(id: "minus")
        XCTAssertEqual(repeatEvents.map(\.keyDown), [false, true])
        XCTAssertEqual(repeatEvents.map(\.flags), [NSEvent.ModifierFlags.control.rawValue, NSEvent.ModifierFlags.control.rawValue])
    }

    func testDuplicatePressIsIgnoredAndReleaseAllClearsState() {
        var planner = KeyboardEventPlanner()
        XCTAssertNotNil(planner.press(.rightCommand, id: "zr"))
        XCTAssertNil(planner.press(.rightCommand, id: "zr"))
        XCTAssertEqual(planner.activeCount, 1)
        XCTAssertEqual(planner.releaseAll().count, 1)
        XCTAssertEqual(planner.activeCount, 0)
        XCTAssertTrue(planner.repeatPulse(id: "zr").isEmpty)
    }

    func testEscapeIsARecordableNormalKey() {
        XCTAssertEqual(KeyboardShortcut.escape.keyCode, 53)
        XCTAssertFalse(KeyboardShortcut.escape.modifierOnly)
        XCTAssertEqual(KeyboardShortcut.escape.displayName, "Esc")
    }

    func testAppSwitcherKeepsCommandHeldUntilConfirmation() throws {
        var planner = KeyboardEventPlanner()
        let command = KeyboardShortcut(
            keyCode: 55,
            modifierFlags: NSEvent.ModifierFlags.command.rawValue,
            modifierOnly: true
        )
        let tab = KeyboardShortcut(keyCode: 48, modifierFlags: 0, modifierOnly: false)

        _ = planner.press(command, id: "command")
        let tabEvents = planner.tap(tab)
        XCTAssertEqual(tabEvents.map(\.flags), [NSEvent.ModifierFlags.command.rawValue, NSEvent.ModifierFlags.command.rawValue])
        XCTAssertEqual(planner.activeCount, 1)

        // An R3 Return confirmation is implemented by releasing Command,
        // which is how the native macOS app switcher commits its selection.
        let commandUp = try XCTUnwrap(planner.release(id: "command"))
        XCTAssertFalse(commandUp.keyDown)
        XCTAssertEqual(commandUp.flags, 0)
        XCTAssertEqual(planner.activeCount, 0)
    }
}

final class StickDirectionResolverTests: XCTestCase {
    func testDeadZoneAndHysteresisPreventCenterJitter() {
        XCTAssertFalse(StickDirectionResolver.isPressed(value: 0.50, currentlyPressed: false))
        XCTAssertTrue(StickDirectionResolver.isPressed(value: 0.70, currentlyPressed: false))
        XCTAssertTrue(StickDirectionResolver.isPressed(value: 0.45, currentlyPressed: true))
        XCTAssertFalse(StickDirectionResolver.isPressed(value: 0.30, currentlyPressed: true))
    }
}
