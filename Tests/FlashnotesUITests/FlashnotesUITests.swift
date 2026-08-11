import XCTest

final class FlashnotesUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCreateFolderHappyPath() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing")
        app.launch()

        let emptyStateButton = app.buttons["Create Folder"]
        XCTAssertTrue(emptyStateButton.waitForExistence(timeout: 5))
        emptyStateButton.click()

        let nameField = app.textFields["Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.click()
        nameField.typeKey("a", modifierFlags: .command)
        nameField.typeText("Study")
        app.buttons["Save"].click()

        XCTAssertTrue(app.staticTexts["Study"].waitForExistence(timeout: 3))
    }
}
