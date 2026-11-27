import XCTest

/// Drives the real app in the simulator.
///
/// These tests need geotagged photos and at least one video in the simulator's
/// camera roll (see docs/testing.md). With an empty camera roll they are skipped, not failed.
final class MemoryViewerUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        dismissSystemAlerts()
        try openAllMemoriesOfLatestCity()
    }

    /// Bug: tapping a memory in "View all" only showed that one memory.
    func testViewAllLetsYouSwipeThroughEveryMemory() throws {
        app.buttons.matching(identifier: "memoryCell").firstMatch.tap()
        let total = try viewerTotal()
        try XCTSkipIf(total < 2, "Needs at least two memories in one city")
        XCTAssertTrue(caption(containing: "1 of \(total)").exists, "Viewer should open on the first memory")
        snapshot("viewer-1")

        for position in 2...total {
            XCTAssertTrue(swipe(to: position, of: total, using: { $0.swipeLeft() }),
                          "Swiping should reach memory \(position) of \(total)")
            snapshot("viewer-\(position)")
        }
    }

    /// Opening from further down the grid should start there, with the rest still swipeable.
    func testViewAllOpensOnTheTappedMemory() throws {
        let cells = app.buttons.matching(identifier: "memoryCell")
        try XCTSkipIf(cells.count < 2, "Needs at least two memories in one city")
        cells.element(boundBy: 1).tap()
        let total = try viewerTotal()
        XCTAssertTrue(caption(containing: "2 of \(total)").exists, "Viewer should open on the tapped memory")
        snapshot("opened-on-2")
        XCTAssertTrue(swipe(to: 1, of: total, using: { $0.swipeRight() }))
        XCTAssertTrue(swipe(to: 2, of: total, using: { $0.swipeLeft() }))
        XCTAssertTrue(swipe(to: 3, of: total, using: { $0.swipeLeft() }))
    }

    /// Playing a day from the city page always starts on its first memory: swiping must work there too,
    /// otherwise the videos later in the day can never be reached.
    func testPlayDayLetsYouSwipeToTheNextMemory() throws {
        app.navigationBars.buttons.firstMatch.tap() // back to the city page
        // Tap the day card's caption ("Sat 14 · 11 moments"): always visible above the tab bar.
        let multiMomentDay = app.buttons.staticTexts.matching(
            NSPredicate(format: "label MATCHES %@", ".* · ([2-9]|[1-9][0-9]+) moments$")
        ).firstMatch
        try XCTSkipUnless(multiMomentDay.waitForExistence(timeout: 5), "Needs a day with at least two memories")
        multiMomentDay.tap()
        let total = try viewerTotal()
        XCTAssertTrue(caption(containing: "1 of \(total)").exists)
        XCTAssertTrue(swipe(to: 2, of: total, using: { $0.swipeLeft() }),
                      "Swiping should move on from the first memory of the day")
    }

    /// Bug: videos never appeared, only photos.
    func testVideoShowsAndPlays() throws {
        app.buttons["Type"].tap()
        let video = app.buttons.matching(NSPredicate(format: "identifier == 'memoryCell' AND label BEGINSWITH 'Video'")).firstMatch
        scrollUntilHittable(video) { $0.swipeUp() }
        try XCTSkipUnless(video.exists, "Needs a video in the camera roll")

        video.tap()
        XCTAssertTrue(caption(containing: "Video ·").waitForExistence(timeout: 5))
        snapshot("video-opened")
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 10), "The video should start playing")
        XCTAssertTrue(app.otherElements["videoPlayer"].waitForExistence(timeout: 10),
                      "The video itself should be on screen, not just a still frame")
    }

    // MARK: - Helpers

    /// Reads "Photo · 2 of 5" in the viewer and returns 5.
    private func viewerTotal() throws -> Int {
        let label = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^(Photo|Video) · [0-9]+ of [0-9]+$")).firstMatch
        XCTAssertTrue(label.waitForExistence(timeout: 5), "Viewer caption missing")
        return try XCTUnwrap(Int(label.label.split(separator: " ").last ?? ""))
    }

    /// Swipes until the caption reads "<position> of <total>". The simulator occasionally drops a
    /// synthetic swipe, so one retry is allowed; a viewer that is really stuck still fails.
    private func swipe(to position: Int, of total: Int, using gesture: (XCUIApplication) -> Void) -> Bool {
        let target = caption(containing: " \(position) of \(total)")
        for _ in 0..<2 {
            gesture(app)
            if target.waitForExistence(timeout: 3) { return true }
        }
        return false
    }

    /// Grids and rows only load what's on screen, so scroll until the element shows up.
    private func scrollUntilHittable(_ element: XCUIElement, maxSwipes: Int = 15, swipe: (XCUIApplication) -> Void) {
        for _ in 0..<maxSwipes where !(element.exists && element.isHittable) {
            swipe(app)
        }
    }

    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func caption(containing text: String) -> XCUIElement {
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func openAllMemoriesOfLatestCity() throws {
        let latest = app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'Latest:'")).firstMatch
        try XCTSkipUnless(latest.waitForExistence(timeout: 30), "No geotagged memories in this simulator")
        latest.tap()
        let viewAll = app.buttons["View all"]
        XCTAssertTrue(viewAll.waitForExistence(timeout: 5))
        viewAll.tap()
        XCTAssertTrue(app.buttons.matching(identifier: "memoryCell").firstMatch.waitForExistence(timeout: 5))
    }

    /// Notification / location prompts belong to SpringBoard, not the app.
    private func dismissSystemAlerts() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Allow", "Allow While Using App", "Don’t Allow"] {
            let button = springboard.buttons[label]
            if button.waitForExistence(timeout: 2) { button.tap() }
        }
    }
}
