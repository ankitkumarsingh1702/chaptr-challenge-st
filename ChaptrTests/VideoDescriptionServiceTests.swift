import XCTest
@testable import Chaptr

final class VideoDescriptionServiceTests: XCTestCase {
    func testCatalogDescriptionWinsBeforeCacheOrML() async {
        let classifier = CountingImageClassifier(labels: fitnessLabels)
        let service = VideoDescriptionService(
            imageLoader: CountingPosterImageLoader(),
            classifier: classifier,
            cache: InMemoryDescriptionCache()
        )
        let video = makeVideo(description: "  Curated catalog description.  ")

        let description = await service.description(for: video)
        let classifierCount = await classifier.callCount()

        XCTAssertEqual(description, "Curated catalog description.")
        XCTAssertEqual(classifierCount, 0)
    }

    func testCacheWinsBeforeImageLoadingAndClassification() async {
        let cache = InMemoryDescriptionCache()
        let classifier = CountingImageClassifier(labels: fitnessLabels)
        let loader = CountingPosterImageLoader()
        let service = VideoDescriptionService(
            imageLoader: loader,
            classifier: classifier,
            cache: cache
        )
        let video = makeVideo()
        await cache.store("Cached enriched description.", for: VideoDescriptionService.cacheKey(for: video))

        let description = await service.description(for: video)
        let loaderCount = await loader.callCount()
        let classifierCount = await classifier.callCount()

        XCTAssertEqual(description, "Cached enriched description.")
        XCTAssertEqual(loaderCount, 0)
        XCTAssertEqual(classifierCount, 0)
    }

    func testMLLabelsProduceEnrichedDescription() async {
        let service = VideoDescriptionService(
            imageLoader: CountingPosterImageLoader(),
            classifier: CountingImageClassifier(labels: fitnessLabels),
            cache: InMemoryDescriptionCache()
        )

        let description = await service.description(for: makeVideo())

        XCTAssertEqual(
            description,
            "An energetic indoor training session focused on strength work, repetition, and high-intensity movement."
        )
    }

    func testRandomThumbnailNameAndGenericTitleStillUseImageLabels() async {
        let service = VideoDescriptionService(
            imageLoader: CountingPosterImageLoader(),
            classifier: CountingImageClassifier(labels: [
                VisualLabel(identifier: "fireplace", confidence: 0.92),
                VisualLabel(identifier: "flame", confidence: 0.86),
                VisualLabel(identifier: "smoke", confidence: 0.74),
            ]),
            cache: InMemoryDescriptionCache()
        )
        let video = makeVideo(
            title: "Untitled Clip",
            thumbnail: "https://images.pexels.com/videos/11187395/random-asset-name.jpeg"
        )

        let description = await service.description(for: video)

        XCTAssertEqual(description, "A warm ambient clip built around flame, glow, and slow visual rhythm.")
    }

    func testUnknownMLDoesNotLeakRawLabelsWhenMetadataHasClearSignal() async {
        let service = VideoDescriptionService(
            imageLoader: CountingPosterImageLoader(),
            classifier: CountingImageClassifier(labels: [
                VisualLabel(identifier: "maillot brassiere overskirt", confidence: 0.88),
            ]),
            cache: InMemoryDescriptionCache()
        )
        let video = makeVideo(
            title: "Slow Motion Of Fire In Fireplace",
            duration: 236,
            thumbnail: "https://images.pexels.com/videos/11187395/fireplace-11187395.jpeg"
        )

        let description = await service.description(for: video)

        XCTAssertEqual(description, "A warm ambient clip built around flame, glow, and slow visual rhythm.")
        XCTAssertFalse(description.contains("maillot"))
        XCTAssertFalse(description.contains("brassiere"))
    }

    func testConcurrentRequestsShareTheSameClassificationWork() async {
        let classifier = CountingImageClassifier(labels: fitnessLabels, delayNanoseconds: 150_000_000)
        let loader = CountingPosterImageLoader(delayNanoseconds: 150_000_000)
        let service = VideoDescriptionService(
            imageLoader: loader,
            classifier: classifier,
            cache: InMemoryDescriptionCache()
        )
        let video = makeVideo()

        async let first = service.description(for: video)
        async let second = service.description(for: video)
        let descriptions = await [first, second]
        let loaderCount = await loader.callCount()
        let classifierCount = await classifier.callCount()

        XCTAssertEqual(descriptions[0], descriptions[1])
        XCTAssertEqual(loaderCount, 1)
        XCTAssertEqual(classifierCount, 1)
    }

    func testImageLoadingFailureFallsBackToMetadataBuilder() async {
        let service = VideoDescriptionService(
            imageLoader: FailingPosterImageLoader(),
            classifier: CountingImageClassifier(labels: fitnessLabels),
            cache: InMemoryDescriptionCache()
        )
        let video = makeVideo()

        let description = await service.description(for: video)

        XCTAssertEqual(description, DescriptionBuilder.description(for: video))
    }

    private var fitnessLabels: [VisualLabel] {
        [
            VisualLabel(identifier: "athlete", confidence: 0.9),
            VisualLabel(identifier: "bodybuilding", confidence: 0.86),
            VisualLabel(identifier: "exercise", confidence: 0.8),
        ]
    }

    private func makeVideo(
        title: String = "Intense Indoor Fitness Workout Session",
        description: String? = nil,
        duration: Int = 115,
        thumbnail: String = "https://images.pexels.com/videos/36014878/athlete-bodybuilding-cineamtic-cinema-36014878.jpeg"
    ) -> FeedVideo {
        FeedVideo(
            id: 36014878,
            title: title,
            description: description,
            duration: duration,
            width: 360,
            height: 640,
            url: "https://example.com/video.mp4",
            thumbnail: thumbnail
        )
    }
}

actor CountingPosterImageLoader: PosterImageLoading {
    private var count = 0
    private let delayNanoseconds: UInt64

    init(delayNanoseconds: UInt64 = 0) {
        self.delayNanoseconds = delayNanoseconds
    }

    func imageData(from url: URL) async throws -> Data {
        count += 1
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        return Data([1, 2, 3])
    }

    func callCount() -> Int {
        count
    }
}

actor CountingImageClassifier: ImageClassifying {
    private var count = 0
    private let labels: [VisualLabel]
    private let delayNanoseconds: UInt64

    init(labels: [VisualLabel], delayNanoseconds: UInt64 = 0) {
        self.labels = labels
        self.delayNanoseconds = delayNanoseconds
    }

    func labels(for imageData: Data) async throws -> [VisualLabel] {
        count += 1
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        return labels
    }

    func callCount() -> Int {
        count
    }
}

struct FailingPosterImageLoader: PosterImageLoading {
    func imageData(from url: URL) async throws -> Data {
        throw URLError(.cannotLoadFromNetwork)
    }
}
