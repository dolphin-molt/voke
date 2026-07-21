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
}
