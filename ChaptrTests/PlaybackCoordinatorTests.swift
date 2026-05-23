import XCTest
@testable import Chaptr

@MainActor
final class PlaybackCoordinatorTests: XCTestCase {
    private let videos = (0..<10).map {
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

    func testPrepareWindowCreatesPlayers() {
        let coordinator = PlaybackCoordinator()
        coordinator.prepareWindow(activeIndex: 0, videos: videos)

        XCTAssertNotNil(coordinator.player(for: 0))
        XCTAssertNotNil(coordinator.player(for: 1))
        XCTAssertNotNil(coordinator.player(for: 2))
    }

    func testPrepareWindowReleasesPlayersOutsideWindow() {
        let coordinator = PlaybackCoordinator()
        coordinator.prepareWindow(activeIndex: 0, videos: videos)
        coordinator.prepareWindow(activeIndex: 5, videos: videos)

        XCTAssertNil(coordinator.player(for: 0))
        XCTAssertNil(coordinator.player(for: 1))
        XCTAssertNil(coordinator.player(for: 2))
        XCTAssertNotNil(coordinator.player(for: 4))
        XCTAssertNotNil(coordinator.player(for: 5))
        XCTAssertNotNil(coordinator.player(for: 6))
        XCTAssertNotNil(coordinator.player(for: 7))
    }

    func testPrepareWindowWithEmptyVideosDoesNotCrash() {
        let coordinator = PlaybackCoordinator()
        coordinator.prepareWindow(activeIndex: 0, videos: [])
    }

    func testReleaseAllClearsState() {
        let coordinator = PlaybackCoordinator()
        coordinator.prepareWindow(activeIndex: 0, videos: videos)
        coordinator.releaseAll()

        XCTAssertNil(coordinator.player(for: 0))
        XCTAssertEqual(coordinator.state(for: 0), .idle)
    }

    func testTrimToActiveVideoKeepsOnlyActive() {
        let coordinator = PlaybackCoordinator()
        coordinator.prepareWindow(activeIndex: 3, videos: videos)
        coordinator.trimToActiveVideo()

        XCTAssertNil(coordinator.player(for: 2))
        XCTAssertNotNil(coordinator.player(for: 3))
        XCTAssertNil(coordinator.player(for: 4))
        XCTAssertNil(coordinator.player(for: 5))
    }

    func testStateForUnknownVideoIsIdle() {
        let coordinator = PlaybackCoordinator()

        XCTAssertEqual(coordinator.state(for: 999), .idle)
    }

    func testTogglePlayPauseFlipsState() {
        let coordinator = PlaybackCoordinator()
        coordinator.prepareWindow(activeIndex: 0, videos: videos)

        XCTAssertFalse(coordinator.isUserPaused)
        coordinator.togglePlayPause()
        XCTAssertTrue(coordinator.isUserPaused)
        coordinator.togglePlayPause()
        XCTAssertFalse(coordinator.isUserPaused)
    }

    func testPrepareWindowResetsUserPaused() {
        let coordinator = PlaybackCoordinator()
        coordinator.prepareWindow(activeIndex: 0, videos: videos)
        coordinator.togglePlayPause()
        XCTAssertTrue(coordinator.isUserPaused)

        coordinator.prepareWindow(activeIndex: 3, videos: videos)
        XCTAssertFalse(coordinator.isUserPaused)
    }

    func testInvalidURLSetsFailedState() {
        let coordinator = PlaybackCoordinator()
        let badVideo = FeedVideo(
            id: 100,
            title: "Bad",
            duration: 60,
            width: 720,
            height: 1280,
            url: "not a url",
            thumbnail: "https://example.com/p.jpg"
        )

        coordinator.prepareWindow(activeIndex: 0, videos: [badVideo])

        XCTAssertEqual(coordinator.state(for: 100), .failed("This video URL is invalid."))
    }
}
