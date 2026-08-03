import XCTest

/// Placeholder UI test target — Swift Testing does not yet drive
/// XCUIApplication automation, so UI tests stay on XCTest/XCUITest (see
/// `.claude/guidelines.md`'s testing section).
final class EasyPathUITests: XCTestCase {
    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }
}
