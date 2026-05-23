import XCTest
@testable import Chaptr

final class CatalogRepositoryTests: XCTestCase {
    func testBundledCatalogDecodesAllVideos() async throws {
        let repository = BundleCatalogRepository()
        let catalog = try await repository.loadCatalog()

        XCTAssertEqual(catalog.videos.count, 25)
        XCTAssertTrue(catalog.videos.allSatisfy { $0.videoURL != nil })
        XCTAssertTrue(catalog.videos.allSatisfy { $0.thumbnailURL != nil })
    }

    func testInvalidVideoURLIsRepresentedWithoutCrashing() {
        let video = FeedVideo(
            id: 1,
            title: "Broken",
            duration: 120,
            width: 720,
            height: 1280,
            url: "not a url",
            thumbnail: "https://example.com/poster.jpg"
        )

        XCTAssertNil(video.videoURL)
        XCTAssertNotNil(video.thumbnailURL)
    }
}

