import XCTest

final class MainViewUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Each test launches for itself: the first-run dashboard needs an empty store, and
    /// launch arguments cannot be varied once `setUp` has launched the app.
    private func launch(extraArguments: [String] = []) {
        app.launchArguments = ["-uiTestCompletedOnboarding"] + extraArguments
        app.launch()
    }

    func testMainTabNavigation() throws {
        launch()

        XCTAssertTrue(app.tabBars.buttons["Sleep"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Sleep"].tap()

        XCTAssertTrue(app.tabBars.buttons["Alarm"].exists)
        app.tabBars.buttons["Alarm"].tap()

        XCTAssertTrue(app.tabBars.buttons["Learn"].exists)
        app.tabBars.buttons["Learn"].tap()
    }

    /// Covers B11: with no completed sessions the dashboard replaces its metric cards with
    /// a single call to action that routes to the importer. This test previously waited for
    /// the "Sleep Metrics" header, which B11 stopped rendering on an empty store.
    func testFirstRunDashboardShowsEmptyStateAndOpensImporter() throws {
        launch(extraArguments: ["-uiTestResetStore"])

        XCTAssertTrue(app.tabBars.buttons["Sleep"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Sleep"].tap()

        let emptyState = app.otherElements["dashboardEmptyState"]
        XCTAssertTrue(
            emptyState.waitForExistence(timeout: 5),
            "An empty store must show DashboardEmptyStateCard, not empty metric cards"
        )

        let importButton = app.buttons["dashboardImportButton"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 2))
        importButton.tap()

        // ModalCoordinator presents SimpleDataImportView, whose heading is distinct from the
        // card's button title (both read "Import from Apple Health").
        XCTAssertTrue(
            app.staticTexts["Import Your Sleep Data"].waitForExistence(timeout: 5),
            "The empty-state button must route to the importer"
        )
    }
}
