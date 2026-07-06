import XCTest

final class OnboardingUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["-uiTestResetOnboarding"]
        app.launch()
    }

    func testWelcomeScreenAppears() throws {
        XCTAssertTrue(app.staticTexts["Welcome to Zeez"].exists)
    }

    func testContinueFromWelcomeNavigatesToHealthIntegration() throws {
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 3))
        continueButton.tap()
        XCTAssertTrue(app.staticTexts["Health Integration"].waitForExistence(timeout: 3))
    }

    func testBackButtonHiddenOnWelcomeStep() throws {
        XCTAssertFalse(app.buttons["Back"].exists)
    }

    func testBackButtonAppearsAfterAdvancing() throws {
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.buttons["Back"].waitForExistence(timeout: 3))
    }
}
