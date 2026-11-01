import XCTest

/// The open source licences page: the notices of the packages the app links.
///
/// The notices are a long document, so the page is also the place where a
/// layout that cannot hold a long text shows up as a blank screen.
final class OpenSourceLicencesUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTheNoticesAreOnThePage() {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_SESSION_TREE_FIXTURE", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        let settings = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 8))
        settings.tap()

        let row = app.descendants(matching: .any)["settings-open-source-licences"]
        for _ in 0..<8 where !row.isHittable { app.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout: 5), "the licences row must be reachable")
        row.tap()

        let notices = app.descendants(matching: .any)["settings-open-source-licences-text"]
        XCTAssertTrue(
            notices.waitForExistence(timeout: 10),
            "the licence notices must render — a blank page means the text never laid out"
        )
        XCTAssertTrue(
            app.staticTexts["Third-party licences"].exists,
            "the page must show the notices, not an empty document"
        )
    }
}
