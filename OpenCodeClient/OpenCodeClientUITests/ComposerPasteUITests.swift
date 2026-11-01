import XCTest

/// The composer accepts what the clipboard holds: text goes into the draft,
/// an image becomes an attachment.
final class ComposerPasteUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testPastingAnImageFromTheClipboardAttachesIt() {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_SESSION_TREE_FIXTURE", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["UITEST_PASTE_IMAGE"] = "1"
        app.launch()

        let input = app.textViews["chat-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["chat-attachment-strip"].exists)

        let paste = app.descendants(matching: .any)["chat-paste"]
        XCTAssertTrue(paste.waitForExistence(timeout: 6), "the paste control must be there")
        XCTAssertTrue(paste.isEnabled, "an image on the clipboard must enable the paste control")
        paste.tap()

        let strip = app.descendants(matching: .any)["chat-attachment-strip"]
        XCTAssertTrue(
            strip.waitForExistence(timeout: 8),
            "a pasted image must become an attachment in the composer"
        )
    }
}
