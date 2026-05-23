import XCTest
@testable import Chaptr

final class DescriptionBuilderTests: XCTestCase {
    func testBundledVideosReceiveShortDescriptions() async throws {
        let catalog = try await BundleCatalogRepository().loadCatalog()
        let descriptions = catalog.videos.map { DescriptionBuilder.description(for: $0) }

        XCTAssertEqual(descriptions.count, catalog.videos.count)
        XCTAssertTrue(descriptions.allSatisfy { $0.isEmpty == false })
        XCTAssertTrue(descriptions.allSatisfy { $0.count <= 130 })
    }

    func testDescriptionIsDeterministicForSameVideo() {
        let video = makeVideo(
            id: 11187395,
            title: "Slow Motion Of Fire In Fireplace",
            thumbnail: "https://images.pexels.com/videos/11187395/fireplace-11187395.jpeg"
        )

        XCTAssertEqual(
            DescriptionBuilder.description(for: video),
            DescriptionBuilder.description(for: video)
        )
    }

    func testKnownSamplesMapToExpectedCategories() {
        XCTAssertEqual(DescriptionBuilder.inferredCategory(for: makeVideo(title: "Slow Motion Of Fire In Fireplace")), "fireAmbient")
        XCTAssertEqual(DescriptionBuilder.inferredCategory(for: makeVideo(title: "A Man Doing Exercise Sets In A Gym")), "fitnessSport")
        XCTAssertEqual(DescriptionBuilder.inferredCategory(for: makeVideo(title: "A Colorful Abstract Painting")), "abstractArt")
        XCTAssertEqual(DescriptionBuilder.inferredCategory(for: makeVideo(title: "Close Up Shot Of Kangaroos Eating In The Front Yard")), "animals")
    }

    func testThumbnailSlugImprovesVagueTitleCategory() {
        let video = makeVideo(
            title: "Beautiful Clip",
            thumbnail: "https://images.pexels.com/videos/5975953/beautiful-landscape-beautiful-nature-change-changing-colors-5975953.jpeg"
        )

        XCTAssertEqual(DescriptionBuilder.inferredCategory(for: video), "natureLandscape")
    }

    func testEmptyTitleUsesFallbackSubject() {
        let video = makeVideo(id: 0, title: "")
        let desc = DescriptionBuilder.description(for: video)
        XCTAssertFalse(desc.contains(", ,"))
        XCTAssertTrue(desc.contains("a short clip"))
    }

    func testUnknownTitleUsesFallbackCategory() {
        let video = makeVideo(
            title: "Untitled Moment",
            thumbnail: "https://example.com/clip-12345.jpeg"
        )

        XCTAssertEqual(DescriptionBuilder.inferredCategory(for: video), "general")
        XCTAssertFalse(DescriptionBuilder.description(for: video).isEmpty)
    }

    private func makeVideo(
        id: Int = 1,
        title: String,
        duration: Int = 118,
        width: Int = 720,
        height: Int = 1280,
        thumbnail: String = "https://example.com/poster.jpg"
    ) -> FeedVideo {
        FeedVideo(
            id: id,
            title: title,
            duration: duration,
            width: width,
            height: height,
            url: "https://example.com/video.mp4",
            thumbnail: thumbnail
        )
    }
}
