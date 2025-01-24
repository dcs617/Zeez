import XCTest

final class MainViewUITests: XCTestCase {
    let app = XCUIApplication()
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["UI-Testing"]
        app.launch()
    }
    
    func testMainTabNavigation() throws {
        // Test Sleep tab
        XCTAssertTrue(app.tabBars.buttons["Sleep"].exists)
        app.tabBars.buttons["Sleep"].tap()
        
        // Verify sleep data elements exist
        XCTAssertTrue(app.staticTexts["Sleep Duration"].exists)
        XCTAssertTrue(app.staticTexts["Quality Sleep Score"].exists)
        
        // Test Stats tab
        app.tabBars.buttons["Stats"].tap()
        XCTAssertTrue(app.staticTexts["Sleep Stats"].exists)
        XCTAssertTrue(app.staticTexts["Sleep Debt Overview"].exists)
        
        // Test Trends tab
        app.tabBars.buttons["Trends"].tap()
        XCTAssertTrue(app.staticTexts["Sleep Trends"].exists)
        XCTAssertTrue(app.buttons["Week"].exists)
        XCTAssertTrue(app.buttons["Month"].exists)
    }
    
    func testSleepDataDisplay() throws {
        // Navigate to Sleep tab
        app.tabBars.buttons["Sleep"].tap()
        
        // Test navigation to detailed views
        app.buttons["Sleep Quality"].tap()
        XCTAssertTrue(app.navigationBars.staticTexts["Sleep Quality"].exists)
        app.navigationBars.buttons.firstMatch.tap()
        
        app.buttons["Heart Rate"].tap()
        XCTAssertTrue(app.navigationBars.staticTexts["Heart Rate"].exists)
        app.navigationBars.buttons.firstMatch.tap()
        
        app.buttons["Sleep Information"].tap()
        XCTAssertTrue(app.navigationBars.staticTexts["Sleep Information"].exists)
        app.navigationBars.buttons.firstMatch.tap()
    }
}
