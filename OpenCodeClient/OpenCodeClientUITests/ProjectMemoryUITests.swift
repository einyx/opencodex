import XCTest

/// The Project Memory surface: the Files tab's entry into the `AGENTS.md` the server injects
/// into every agent turn.
final class ProjectMemoryUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTheSectionStatesTheProjectHasMemory() {
        let app = launch(mode: "present")
        let section = app.descendants(matching: .any)["files-project-memory-section"]
        XCTAssertTrue(section.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["AGENTS.md · 10 lines"].waitForExistence(timeout: 8))
    }

    func testThePanelShowsTheFileAndWhereItCameFrom() {
        let app = launch(mode: "present")
        let section = app.descendants(matching: .any)["files-project-memory-section"]
        XCTAssertTrue(section.waitForExistence(timeout: 8))
        section.tap()

        XCTAssertTrue(app.navigationBars["Project Memory"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["project-memory-path"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Project Memory Fixture"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["project-memory-improve"].waitForExistence(timeout: 4))
        capture(app, name: "present")
    }

    func testThePanelStatesWhenThereIsNoProjectMemory() {
        let app = launch(mode: "absent")
        let section = app.descendants(matching: .any)["files-project-memory-section"]
        XCTAssertTrue(section.waitForExistence(timeout: 8))
        section.tap()

        XCTAssertTrue(app.descendants(matching: .any)["project-memory-absent"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["project-memory-empty"].waitForExistence(timeout: 8))
    }

    func testTheAgentRewriteIsOfferedForReview() {
        let app = launch(mode: "changed")
        let section = app.descendants(matching: .any)["files-project-memory-section"]
        XCTAssertTrue(section.waitForExistence(timeout: 8))
        section.tap()

        let changed = app.descendants(matching: .any)["project-memory-changed"]
        XCTAssertTrue(changed.waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["project-memory-review"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.descendants(matching: .any)["project-memory-keep"].waitForExistence(timeout: 4))
        capture(app, name: "changed")

        app.descendants(matching: .any)["project-memory-review"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["project-memory-review-diff"].waitForExistence(timeout: 4))
        capture(app, name: "review")
    }

    /// Write a screenshot where the host can find it.
    private func capture(_ app: XCUIApplication, name: String) {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("ProjectMemoryUITests", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let shot = XCUIScreen.main.screenshot()
        try? shot.pngRepresentation.write(to: folder.appendingPathComponent("project-memory-\(name).png"))
    }

    private func launch(mode: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_PROJECT_MEMORY_FIXTURE"]
        app.launchEnvironment["PROJECT_MEMORY_FIXTURE_MODE"] = mode
        app.launch()
        return app
    }
}
