import ApplicationServices
import XCTest
@testable import Voke

final class MouseMotionPlannerTests: XCTestCase {
    func testDeadZoneStopsCursorDrift() {
        XCTAssertEqual(MouseMotionPlanner.delta(x: 0.08, y: -0.08), .zero)
    }

    func testFullStickIsFasterThanPartialStick() {
        let partial = MouseMotionPlanner.delta(x: 0.4, y: 0)
        let full = MouseMotionPlanner.delta(x: 1, y: 0)
        XCTAssertGreaterThan(full.x, partial.x)
        XCTAssertEqual(partial.y, 0)
    }

    func testStickUpMovesCursorTowardScreenTop() {
        XCTAssertLessThan(MouseMotionPlanner.delta(x: 0, y: 1).y, 0)
    }

    func testLeftClickUsesPrimaryButtonWithoutControlModifier() throws {
        let events = try XCTUnwrap(MouseClickEventFactory.leftClick(at: CGPoint(x: 120, y: 80)))

        XCTAssertEqual(events.down.type, .leftMouseDown)
        XCTAssertEqual(events.up.type, .leftMouseUp)
        XCTAssertEqual(events.down.getIntegerValueField(.mouseEventButtonNumber), 0)
        XCTAssertEqual(events.up.getIntegerValueField(.mouseEventButtonNumber), 0)
        XCTAssertEqual(events.down.getIntegerValueField(.mouseEventClickState), 1)
        XCTAssertEqual(events.up.getIntegerValueField(.mouseEventClickState), 1)
        XCTAssertFalse(events.down.flags.contains(.maskControl))
        XCTAssertFalse(events.up.flags.contains(.maskControl))
    }
}
