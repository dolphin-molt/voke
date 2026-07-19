import AppKit
import XCTest
@testable import AICommandController

final class KeyboardEventPlannerTests: XCTestCase {
    func testRightControlDownCarriesSideFlagButComboUsesPortableControlFlag() throws {
        var planner = KeyboardEventPlanner()
        let control = KeyboardShortcut.rightControl
        let a = KeyboardShortcut(keyCode: 0, modifierFlags: 0, modifierOnly: false)

        let controlDown = try XCTUnwrap(planner.press(control, id: "zr", targetPID: nil))
        XCTAssertEqual(
            controlDown.flags,
            NSEvent.ModifierFlags.control.rawValue | KeyboardEventPlanner.modifierSideFlag(for: 62)
        )

        let aDown = try XCTUnwrap(planner.press(a, id: "a", targetPID: 42))
        XCTAssertEqual(aDown.flags, NSEvent.ModifierFlags.control.rawValue)
        XCTAssertEqual(aDown.targetPID, 42)

        let aUp = try XCTUnwrap(planner.release(id: "a"))
        XCTAssertEqual(aUp.flags, NSEvent.ModifierFlags.control.rawValue)
        let controlUp = try XCTUnwrap(planner.release(id: "zr"))
        XCTAssertEqual(controlUp.flags, 0)
    }

    func testLeftCommandCombinesWithA() throws {
        var planner = KeyboardEventPlanner()
        let command = KeyboardShortcut(keyCode: 55, modifierFlags: NSEvent.ModifierFlags.command.rawValue, modifierOnly: true)
        let a = KeyboardShortcut(keyCode: 0, modifierFlags: 0, modifierOnly: false)

        _ = planner.press(command, id: "zl", targetPID: nil)
        let aDown = try XCTUnwrap(planner.press(a, id: "a", targetPID: 88))

        XCTAssertEqual(aDown.flags, NSEvent.ModifierFlags.command.rawValue)
        XCTAssertFalse(aDown.flags & KeyboardEventPlanner.modifierSideFlag(for: 55) != 0)
    }

    func testTapAndRepeatPulseInheritHeldModifier() throws {
        var planner = KeyboardEventPlanner()
        _ = planner.press(.rightControl, id: "zr", targetPID: nil)
        let delete = KeyboardShortcut(keyCode: 51, modifierFlags: 0, modifierOnly: false)

        let tap = planner.tap(delete, targetPID: 10)
        XCTAssertEqual(tap.map(\.keyDown), [true, false])
        XCTAssertEqual(tap.map(\.flags), [NSEvent.ModifierFlags.control.rawValue, NSEvent.ModifierFlags.control.rawValue])

        _ = planner.press(delete, id: "minus", targetPID: 10)
        let repeatEvents = planner.repeatPulse(id: "minus")
        XCTAssertEqual(repeatEvents.map(\.keyDown), [false, true])
        XCTAssertEqual(repeatEvents.map(\.flags), [NSEvent.ModifierFlags.control.rawValue, NSEvent.ModifierFlags.control.rawValue])
    }

    func testDuplicatePressIsIgnoredAndReleaseAllClearsState() {
        var planner = KeyboardEventPlanner()
        XCTAssertNotNil(planner.press(.rightCommand, id: "zr", targetPID: nil))
        XCTAssertNil(planner.press(.rightCommand, id: "zr", targetPID: nil))
        XCTAssertEqual(planner.activeCount, 1)
        XCTAssertEqual(planner.releaseAll().count, 1)
        XCTAssertEqual(planner.activeCount, 0)
        XCTAssertTrue(planner.repeatPulse(id: "zr").isEmpty)
    }

    func testAppSwitcherKeepsCommandHeldUntilConfirmation() throws {
        var planner = KeyboardEventPlanner()
        let command = KeyboardShortcut(
            keyCode: 55,
            modifierFlags: NSEvent.ModifierFlags.command.rawValue,
            modifierOnly: true
        )
        let tab = KeyboardShortcut(keyCode: 48, modifierFlags: 0, modifierOnly: false)

        _ = planner.press(command, id: "command", targetPID: nil)
        let tabEvents = planner.tap(tab, targetPID: nil)
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
