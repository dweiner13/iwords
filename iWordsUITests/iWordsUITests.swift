import XCTest
import XCUIAutomation

@MainActor
final class iWordsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "org.iwords.iwords.uitesting")
        app.launchArguments = ["-ApplePersistenceIgnoreState", "NO", "-prettyFormatOutput", "YES",
                               "-copySearchToNewWindows", "NO", "-NSQuitAlwaysKeepsWindows", "YES"]
        app.launch()
        return app
    }

    private func search(_ word: String, app: XCUIApplication) {
        app.typeKey("l", modifierFlags: .command)
        let field = app.textFields["lookupSearchField"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), app.debugDescription)
        field.click()
        field.typeKey("a", modifierFlags: .command)
        field.typeText(word)
        app.buttons["lookupSearchButton"].firstMatch.click()
    }

    private func expectResult(_ text: String, app: XCUIApplication) {
        let result = app.textViews["lookupResults"].firstMatch
        let predicate = NSPredicate(format: "value CONTAINS[c] %@", text)
        expectation(for: predicate, evaluatedWith: result)
        waitForExpectations(timeout: 10)
    }

    func testSearchHistoryAndNativeSelection() {
        let app = launch()
        defer { app.terminate() }
        search("amo", app: app)
        expectResult("love", app: app)
        search("sum", app: app)
        expectResult("be", app: app)
        app.typeKey("[", modifierFlags: .command)
        expectResult("love", app: app)
        app.typeKey("]", modifierFlags: .command)
        expectResult("be", app: app)
        let result = app.textViews["lookupResults"].firstMatch
        result.click()
        result.typeKey("a", modifierFlags: .command)
        result.typeKey("c", modifierFlags: .command)
        app.typeKey("f", modifierFlags: .command)
        XCTAssertTrue(app.textFields.count > 1 || app.searchFields.count > 0)
    }

    func testMultipleWindowsHaveIndependentResults() {
        let app = launch()
        defer { app.terminate() }
        search("amo", app: app)
        expectResult("love", app: app)
        let originalCount = app.windows.count
        app.typeKey("n", modifierFlags: .command)
        expectation(for: NSPredicate(format: "count == %d", originalCount + 1), evaluatedWith: app.windows)
        waitForExpectations(timeout: 5)
        search("sum", app: app)
        expectResult("be", app: app)
        app.typeKey("w", modifierFlags: .command)
        expectResult("love", app: app)
    }

    func testResultsAndHistoryRestoreAfterQuit() {
        let app = launch()
        search("amo", app: app)
        expectResult("love", app: app)
        search("sum", app: app)
        expectResult("be", app: app)
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 10))
        app.launchArguments = ["-NSQuitAlwaysKeepsWindows", "YES", "-prettyFormatOutput", "YES"]
        app.launch()
        defer { app.terminate() }
        expectResult("be", app: app)
        app.typeKey("[", modifierFlags: .command)
        expectResult("love", app: app)
    }
}
