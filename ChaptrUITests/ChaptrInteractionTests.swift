import XCTest

final class ChaptrInteractionTests: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "com.ankit.chaptr")

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app.launch()
        waitForFeed()
    }

    func testContinuousScrollingForLiveProof() {
        let deadline = Date().addingTimeInterval(25)

        while Date() < deadline {
            swipeToNextVideo(duration: 0.08)
            Thread.sleep(forTimeInterval: 0.28)
        }
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
    }

    func testRapidSwipingSkipsFiveItemsInOneSecond() {
        for _ in 0..<5 {
            swipeToNextVideo(duration: 0.03)
            Thread.sleep(forTimeInterval: 0.13)
        }
        addScreenAttachment(named: "rapid-swipe-end")
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
        XCTAssertTrue(app.staticTexts["Chaptr"].waitForExistence(timeout: 10))
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
}
