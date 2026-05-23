import XCTest
@testable import Chaptr

@MainActor
final class ForYouViewModelTests: XCTestCase {
    func testEmptyCatalogMapsToEmptyState() async {
        let viewModel = ForYouViewModel(
            repository: MockCatalogRepository(result: .success(VideoCatalog(videos: []))),
            playbackCoordinator: PlaybackCoordinator()
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.loadState, .empty)
    }

    func testRepositoryFailureMapsToFailedState() async {
        let viewModel = ForYouViewModel(
            repository: MockCatalogRepository(result: .failure(CatalogRepositoryError.decodeFailed)),
            playbackCoordinator: PlaybackCoordinator()
        )

        await viewModel.load()

        if case .failed = viewModel.loadState {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected failed state")
        }
    }

    func testDescriptionReturnsFallbackImmediatelyThenUpdatesAsync() async {
        let video = makeVideo(id: 1, title: "Intense Indoor Fitness Workout Session")
        let viewModel = ForYouViewModel(
            repository: MockCatalogRepository(result: .success(VideoCatalog(videos: [video]))),
            playbackCoordinator: PlaybackCoordinator(),
            descriptionService: VideoDescriptionService(
                imageLoader: CountingPosterImageLoader(delayNanoseconds: 150_000_000),
                classifier: CountingImageClassifier(labels: [
                    VisualLabel(identifier: "athlete", confidence: 0.9),
                    VisualLabel(identifier: "bodybuilding", confidence: 0.86),
                    VisualLabel(identifier: "exercise", confidence: 0.8),
                ]),
                cache: InMemoryDescriptionCache()
            )
        )

        await viewModel.load()
        XCTAssertEqual(viewModel.description(for: video), DescriptionBuilder.description(for: video))

        let didUpdate = await waitUntil {
            viewModel.description(for: video) != DescriptionBuilder.description(for: video)
        }

        XCTAssertTrue(didUpdate)
        XCTAssertEqual(
            viewModel.description(for: video),
            "An energetic indoor training session focused on strength work, repetition, and high-intensity movement."
        )
    }

    func testDescriptionEnrichmentStartsWithActiveAndNextTwoVideosOnly() async {
        let videos = (0..<5).map { makeVideo(id: $0, title: "Video \($0)") }
        let classifier = CountingImageClassifier(labels: [
            VisualLabel(identifier: "cinematic motion", confidence: 0.8),
        ])
        let viewModel = ForYouViewModel(
            repository: MockCatalogRepository(result: .success(VideoCatalog(videos: videos))),
            playbackCoordinator: PlaybackCoordinator(),
            descriptionService: VideoDescriptionService(
                imageLoader: CountingPosterImageLoader(),
                classifier: classifier,
                cache: InMemoryDescriptionCache()
            )
        )

        await viewModel.load()
        let didEnrichWindow = await waitUntil {
            viewModel.descriptionsByID.count == 3
        }

        XCTAssertTrue(didEnrichWindow)
        XCTAssertEqual(Set(viewModel.descriptionsByID.keys), [0, 1, 2])
        let classifierCount = await classifier.callCount()
        XCTAssertEqual(classifierCount, 3)
    }

    func testDescriptionEnrichmentRunsPreloadWindowInParallel() async {
        let videos = (0..<3).map { makeVideo(id: $0, title: "Untitled Clip \($0)") }
        let classifier = ConcurrentTrackingImageClassifier(
            labels: [
                VisualLabel(identifier: "fireplace", confidence: 0.92),
                VisualLabel(identifier: "flame", confidence: 0.84),
            ],
            delayNanoseconds: 250_000_000
        )
        let viewModel = ForYouViewModel(
            repository: MockCatalogRepository(result: .success(VideoCatalog(videos: videos))),
            playbackCoordinator: PlaybackCoordinator(),
            descriptionService: VideoDescriptionService(
                imageLoader: CountingPosterImageLoader(),
                classifier: classifier,
                cache: InMemoryDescriptionCache()
            )
        )

        await viewModel.load()
        let didEnrichWindow = await waitUntil {
            viewModel.descriptionsByID.count == 3
        }
        let maxConcurrentCalls = await classifier.maxConcurrentCallCount()

        XCTAssertTrue(didEnrichWindow)
        XCTAssertGreaterThanOrEqual(maxConcurrentCalls, 2)
    }

    func testRapidIndexChangeDoesNotPublishStaleDescriptions() async {
        let videos = (0..<5).map { makeVideo(id: $0, title: "Video \($0)") }
        let viewModel = ForYouViewModel(
            repository: MockCatalogRepository(result: .success(VideoCatalog(videos: videos))),
            playbackCoordinator: PlaybackCoordinator(),
            descriptionService: VideoDescriptionService(
                imageLoader: CountingPosterImageLoader(delayNanoseconds: 250_000_000),
                classifier: CountingImageClassifier(labels: [
                    VisualLabel(identifier: "cinematic motion", confidence: 0.8),
                ]),
                cache: InMemoryDescriptionCache()
            )
        )

        await viewModel.load()
        viewModel.updateActiveIndex(4)

        let didEnrichLatestVideo = await waitUntil {
            viewModel.descriptionsByID[4] != nil
        }

        XCTAssertTrue(didEnrichLatestVideo)
        XCTAssertNil(viewModel.descriptionsByID[0])
    }
}

private struct MockCatalogRepository: CatalogRepository {
    let result: Result<VideoCatalog, Error>

    func loadCatalog() async throws -> VideoCatalog {
        try result.get()
    }
}

private func makeVideo(id: Int, title: String) -> FeedVideo {
    FeedVideo(
        id: id,
        title: title,
        duration: 118,
        width: 720,
        height: 1280,
        url: "https://example.com/\(id).mp4",
        thumbnail: "https://example.com/\(id).jpg"
    )
}

private actor ConcurrentTrackingImageClassifier: ImageClassifying {
    private var activeCalls = 0
    private var maxConcurrentCalls = 0
    private let labels: [VisualLabel]
    private let delayNanoseconds: UInt64

    init(labels: [VisualLabel], delayNanoseconds: UInt64) {
        self.labels = labels
        self.delayNanoseconds = delayNanoseconds
    }

    func labels(for imageData: Data) async throws -> [VisualLabel] {
        activeCalls += 1
        maxConcurrentCalls = max(maxConcurrentCalls, activeCalls)
        try await Task.sleep(nanoseconds: delayNanoseconds)
        activeCalls -= 1
        return labels
    }

    func maxConcurrentCallCount() -> Int {
        maxConcurrentCalls
    }
}

@MainActor
private func waitUntil(timeout: TimeInterval = 2, condition: () -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() {
            return true
        }
        try? await Task.sleep(nanoseconds: 50_000_000)
    }
    return false
}
