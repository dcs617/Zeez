import XCTest

final class MainViewUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["-uiTestCompletedOnboarding"]
        app.launch()
    }

    func testMainTabNavigation() throws {
        XCTAssertTrue(app.tabBars.buttons["Sleep"].exists)
        app.tabBars.buttons["Sleep"].tap()

        XCTAssertTrue(app.tabBars.buttons["Alarm"].exists)
        app.tabBars.buttons["Alarm"].tap()

        XCTAssertTrue(app.tabBars.buttons["Learn"].exists)
        app.tabBars.buttons["Learn"].tap()
    }

    func testSleepTabLoads() throws {
        app.tabBars.buttons["Sleep"].tap()
        XCTAssertTrue(app.staticTexts["Sleep Duration"].exists || app.otherElements["Sleep Dashboard"].exists)
    }
}
