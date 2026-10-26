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

    /// D1a gave each tab its own `NavigationStack`. A tab that loses it loses its navigation
    /// bar (Alarm, Learn) or stops pushing (Sleep); `testMainTabNavigation` notices neither.
    func testEveryTabHasItsOwnNavigationStack() throws {
        // Learn otherwise opens its first-visit onboarding cover over the tab.
        launch(extraArguments: ["-hasShownLearnOnboarding", "YES"])

        // The dashboard hides its bar behind a custom header, so prove its stack by pushing.
        XCTAssertTrue(app.tabBars.buttons["Sleep"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Sleep"].tap()
        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5),
                      "The Sleep tab must push Settings onto its own stack")
        XCTAssertTrue(app.tabBars.buttons["Alarm"].isHittable,
                      "A push inside a tab keeps the tab bar on screen")

        app.tabBars.buttons["Alarm"].tap()
        XCTAssertTrue(app.navigationBars["Rise"].waitForExistence(timeout: 5),
                      "The Alarm tab must show its navigation title")

        app.tabBars.buttons["Learn"].tap()
        XCTAssertTrue(app.navigationBars["Learn"].waitForExistence(timeout: 5),
                      "The Learn tab must show its navigation title")
    }

    /// Trends had no entry point from 2025-08-19 until the Dashboard link of 2026-10-26.
    func testDashboardLinkOpensTrends() throws {
        launch(extraArguments: ["-uiTestResetStore", "-uiTestSeedMockData"])

        XCTAssertTrue(app.tabBars.buttons["Sleep"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Sleep"].tap()

        let trendsLink = app.buttons["sleepTrendsLink"]
        XCTAssertTrue(trendsLink.waitForExistence(timeout: 10), "With recorded nights the dashboard links to Trends")
        trendsLink.tap()

        XCTAssertTrue(app.navigationBars["Sleep Trends"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["nightCoverageCard"].waitForExistence(timeout: 5),
                      "Trends opens on its coverage card")
        XCTAssertTrue(app.tabBars.buttons["Sleep"].isHittable, "Trends is pushed inside the Sleep tab")
    }

    func testEmptyDashboardHasNoTrendsLink() throws {
        launch(extraArguments: ["-uiTestResetStore"])

        XCTAssertTrue(app.otherElements["dashboardEmptyState"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["sleepTrendsLink"].exists, "Trends is linked only once there are recorded nights")
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
