import XCTest
@testable import Chaptr

final class PlaybackWindowTests: XCTestCase {
    private let videos = (0..<25).map {
        FeedVideo(
            id: $0,
            title: "Video \($0)",
            duration: 120,
            width: 720,
            height: 1280,
            url: "https://example.com/\($0).mp4",
            thumbnail: "https://example.com/\($0).jpg"
        )
    }

    func testStartWindowKeepsActiveAndNextTwo() {
        let window = PlaybackWindow(activeIndex: 0, totalCount: videos.count, previousWarmCount: 1, nextPreloadCount: 2)

        XCTAssertEqual(window.retainedIDs(from: videos), [0, 1, 2])
    }

    func testMiddleWindowKeepsPreviousActiveAndNextTwo() {
        let window = PlaybackWindow(activeIndex: 10, totalCount: videos.count, previousWarmCount: 1, nextPreloadCount: 2)

        XCTAssertEqual(window.retainedIDs(from: videos), [9, 10, 11, 12])
    }

    func testEndWindowDoesNotExceedCatalog() {
        let window = PlaybackWindow(activeIndex: 24, totalCount: videos.count, previousWarmCount: 1, nextPreloadCount: 2)

        XCTAssertEqual(window.retainedIDs(from: videos), [23, 24])
    }

    func testRapidIndexChangesStayBounded() {
        for index in 0..<50 {
            let activeIndex = index % videos.count
            let window = PlaybackWindow(activeIndex: activeIndex, totalCount: videos.count, previousWarmCount: 1, nextPreloadCount: 2)

            XCTAssertLessThanOrEqual(window.retainedIDs(from: videos).count, 4)
        }
    }
}

