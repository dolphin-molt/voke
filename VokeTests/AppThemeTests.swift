import XCTest
@testable import Voke

final class AppThemeTests: XCTestCase {
    func testFormerOceanPreferenceMigratesToSketchCapsule() {
        XCTAssertEqual(AppTheme(rawValue: "ocean"), .sketchCapsule)
        XCTAssertEqual(AppTheme.sketchCapsule.title, "素描胶囊")
    }

    func testThemePickerStillContainsThreeThemes() {
        XCTAssertEqual(AppTheme.allCases.count, 3)
        XCTAssertEqual(AppTheme.allCases.map(\.title), ["明亮", "石墨", "素描胶囊"])
    }
}
