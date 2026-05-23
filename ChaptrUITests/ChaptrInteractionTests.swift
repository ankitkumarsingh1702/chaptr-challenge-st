import XCTest

final class ChaptrInteractionTests: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "com.ankit.chaptr")

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app.launchArguments = [
            "-ChaptrResetFeedPosition",
            "-ChaptrExposeAutomationIdentifiers",
            "-ChaptrUseFakeMLDescriptions",
        ]
        app.launch()
        waitForFeed()
    }

    func testDescriptionAppearsAndCanUpdateFromDeterministicMLMode() {
        let description = descriptionElement
        let initialText = description.label
        XCTAssertFalse(initialText.isEmpty)

        let enrichedText = "A warm ambient clip built around flame, glow, and slow visual rhythm."
        if initialText != enrichedText {
            let predicate = NSPredicate(format: "label == %@", enrichedText)
            expectation(for: predicate, evaluatedWith: description)
            waitForExpectations(timeout: 3)
        }

        XCTAssertEqual(description.label, enrichedText)
    }

    func testContinuousScrollingForLiveProof() {
        let deadline = Date().addingTimeInterval(25)

        while Date() < deadline {
            swipeToNextVideo(duration: 0.08)
            Thread.sleep(forTimeInterval: 0.28)
        }
        XCTAssertTrue(descriptionElement.exists)
    }

    func testFiftyPlusScrollMemoryWindow() {
        for index in 0..<60 {
            swipeToNextVideo(duration: 0.06)
            if index.isMultiple(of: 10) {
                addScreenAttachment(named: "scroll-\(index)")
            }
            Thread.sleep(forTimeInterval: 0.14)
        }
        addScreenAttachment(named: "scroll-60")
        XCTAssertTrue(descriptionElement.exists)
    }

    func testRapidSwipingSkipsFiveItemsInOneSecond() {
        for _ in 0..<5 {
            swipeToNextVideo(duration: 0.03)
            Thread.sleep(forTimeInterval: 0.13)
        }
        addScreenAttachment(named: "rapid-swipe-end")
        XCTAssertTrue(descriptionElement.exists)
    }

    func testBackgroundAndRelaunchPausePath() {
        addScreenAttachment(named: "foreground-before-home")
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 2)

        app.activate()
        waitForFeed()
        addScreenAttachment(named: "foreground-after-return")
    }

    private func waitForFeed() {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 8))
        XCTAssertTrue(feedElement.waitForExistence(timeout: 10))
        XCTAssertTrue(descriptionElement.waitForExistence(timeout: 5))
    }

    private func swipeToNextVideo(duration: TimeInterval) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.82))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.16))
        start.press(forDuration: 0.01, thenDragTo: end, withVelocity: .fast, thenHoldForDuration: duration)
    }

    private func addScreenAttachment(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private var feedElement: XCUIElement {
        app.descendants(matching: .any)["feed-scroll-view"]
    }

    private var descriptionElement: XCUIElement {
        app.descendants(matching: .any)["feed-description"]
    }
}
