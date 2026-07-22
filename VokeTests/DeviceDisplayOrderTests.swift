import XCTest
@testable import Voke

final class DeviceDisplayOrderTests: XCTestCase {
    func testMovingForwardPlacesSourceAfterTarget() {
        XCTAssertEqual(
            DeviceDisplayOrder.moving(["a", "b", "c"], sourceID: "a", targetID: "c"),
            ["b", "c", "a"]
        )
    }

    func testMovingBackwardPlacesSourceBeforeTarget() {
        XCTAssertEqual(
            DeviceDisplayOrder.moving(["a", "b", "c"], sourceID: "c", targetID: "a"),
            ["c", "a", "b"]
        )
    }

    func testMovingUnknownDeviceLeavesOrderUnchanged() {
        XCTAssertEqual(
            DeviceDisplayOrder.moving(["a", "b"], sourceID: "missing", targetID: "a"),
            ["a", "b"]
        )
    }
}
