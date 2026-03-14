import XCTest

final class WalkWorthyUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchesToOnboardingOrToday() {
        let app = XCUIApplication()
        app.launch()

        let onboardingExists = app.staticTexts["Welcome to Tend"].waitForExistence(timeout: 2)
        let todayExists = app.navigationBars["Today"].waitForExistence(timeout: 2)

        XCTAssertTrue(onboardingExists || todayExists)
    }
}
