import XCTest

final class WalkWorthyUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchesToOnboardingOrToday() {
        let app = XCUIApplication()
        app.launch()

        let onboardingExists = app.staticTexts["Welcome to Tend"].waitForExistence(timeout: 5)
        let homeExists = app.navigationBars["Home"].waitForExistence(timeout: 5)

        XCTAssertTrue(onboardingExists || homeExists)
    }
}
