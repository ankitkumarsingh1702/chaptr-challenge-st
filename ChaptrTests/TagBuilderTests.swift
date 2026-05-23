import XCTest
@testable import Chaptr

final class TagBuilderTests: XCTestCase {
    func testTagsAreNonEmpty() {
        let video = FeedVideo(
            id: 10,
            title: "Slow Motion Of Fire In Fireplace",
            duration: 236,
            width: 720,
            height: 1280,
            url: "https://example.com/video.mp4",
            thumbnail: "https://example.com/poster.jpg"
        )

        let tags = TagBuilder.tags(for: video)

        XCTAssertFalse(tags.isEmpty)
    }

    func testTagsDoNotIncludeStopWords() {
        let video = FeedVideo(
            id: 10,
            title: "A Fire In The Fireplace",
            duration: 120,
            width: 720,
            height: 1280,
            url: "https://example.com/video.mp4",
            thumbnail: "https://example.com/poster.jpg"
        )

        let tags = TagBuilder.tags(for: video)
        let stopWords = ["#a", "#in", "#the", "#of", "#on"]

        for tag in tags {
            XCTAssertFalse(stopWords.contains(tag), "Tag '\(tag)' is a stop word")
        }
    }

    func testTagsCappedAtFour() {
        let video = FeedVideo(
            id: 10,
            title: "Very Long Title With Many Words Here Today",
            duration: 200,
            width: 1080,
            height: 1920,
            url: "https://example.com/video.mp4",
            thumbnail: "https://example.com/poster.jpg"
        )

        let tags = TagBuilder.tags(for: video)

        XCTAssertLessThanOrEqual(tags.count, 4)
    }

    func testIncludesDurationCategoryTag() {
        let longVideo = FeedVideo(
            id: 10, title: "Test", duration: 200,
            width: 720, height: 1280,
            url: "https://example.com/v.mp4",
            thumbnail: "https://example.com/p.jpg"
        )

        let tags = TagBuilder.tags(for: longVideo)

        XCTAssertTrue(tags.contains("#longform") || tags.contains("#shortform") || tags.contains("#clip"))
    }

    func testIncludesResolutionTag() {
        let hdVideo = FeedVideo(
            id: 10, title: "Test", duration: 100,
            width: 1080, height: 1920,
            url: "https://example.com/v.mp4",
            thumbnail: "https://example.com/p.jpg"
        )

        let tags = TagBuilder.tags(for: hdVideo)

        XCTAssertTrue(tags.contains("#fullhd") || tags.contains("#hd") || tags.contains("#sd"))
    }
}
