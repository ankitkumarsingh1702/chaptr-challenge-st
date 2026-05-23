import Foundation
import ImageIO
@preconcurrency import Vision

protocol PosterImageLoading: Sendable {
    func imageData(from url: URL) async throws -> Data
}

protocol ImageClassifying: Sendable {
    func labels(for imageData: Data) async throws -> [VisualLabel]
}

protocol DescriptionCache: Sendable {
    func description(for key: String) async -> String?
    func store(_ description: String, for key: String) async
}

actor VideoDescriptionService {
    private let imageLoader: any PosterImageLoading
    private let classifier: any ImageClassifying
    private let cache: any DescriptionCache
    private let composer: VisualDescriptionComposer
    private var inFlight: [String: Task<DescriptionSelection?, Never>] = [:]

    init(
        imageLoader: any PosterImageLoading = URLSessionPosterImageLoader(),
        classifier: any ImageClassifying = VisionImageClassifier(),
        cache: any DescriptionCache = InMemoryDescriptionCache(),
        composer: VisualDescriptionComposer = VisualDescriptionComposer()
    ) {
        self.imageLoader = imageLoader
        self.classifier = classifier
        self.cache = cache
        self.composer = composer
    }

    static func live() -> VideoDescriptionService {
        if shouldUseDeterministicService {
            return VideoDescriptionService(
                imageLoader: UITestPosterImageLoader(),
                classifier: StaticImageClassifier(labels: [
                    VisualLabel(identifier: "fireplace", confidence: 0.92),
                    VisualLabel(identifier: "flame", confidence: 0.84),
                    VisualLabel(identifier: "cinematic lighting", confidence: 0.68),
                ])
            )
        }

        return VideoDescriptionService()
    }

    private static var shouldUseDeterministicService: Bool {
        let processInfo = ProcessInfo.processInfo
        return processInfo.arguments.contains("-ChaptrUseFakeMLDescriptions")
            || processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    static func cacheKey(for video: FeedVideo) -> String {
        "\(video.id)|\(video.thumbnail)"
    }

    func description(for video: FeedVideo) async -> String {
        if let curated = Self.normalized(video.description) {
            return curated
        }

        let key = Self.cacheKey(for: video)
        if let cached = await cache.description(for: key) {
            return cached
        }

        if let task = inFlight[key], let selection = await task.value {
            return selection.text
        }

        let task: Task<DescriptionSelection?, Never> = Task { [imageLoader, classifier, composer] in
            guard let url = video.thumbnailURL else {
                return nil
            }

            do {
                let data = try await imageLoader.imageData(from: url)
                let labels = try await classifier.labels(for: data)
                return Self.bestDescription(for: video, labels: labels, composer: composer)
            } catch {
                return nil
            }
        }

        inFlight[key] = task
        let selection = await task.value
        inFlight[key] = nil

        guard let selection else {
            return DescriptionBuilder.description(for: video)
        }

        if selection.shouldCache {
            await cache.store(selection.text, for: key)
        }
        return selection.text
    }

    private static func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private static func bestDescription(
        for video: FeedVideo,
        labels: [VisualLabel],
        composer: VisualDescriptionComposer
    ) -> DescriptionSelection {
        let fallback = DescriptionBuilder.description(for: video)
        guard let visualResult = composer.result(for: video, labels: labels) else {
            return DescriptionSelection(text: fallback, shouldCache: true)
        }

        if visualResult.quality >= fallbackQuality(for: video) {
            return DescriptionSelection(text: visualResult.text, shouldCache: true)
        }

        return DescriptionSelection(text: fallback, shouldCache: true)
    }

    private static func fallbackQuality(for video: FeedVideo) -> Double {
        DescriptionBuilder.inferredCategory(for: video) == "general" ? 0.2 : 1.2
    }
}

private struct DescriptionSelection: Sendable {
    let text: String
    let shouldCache: Bool
}

struct URLSessionPosterImageLoader: PosterImageLoading {
    func imageData(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        if let response = response as? HTTPURLResponse, !(200..<300).contains(response.statusCode) {
            throw URLError(.badServerResponse)
        }
        return data
    }
}

struct VisionImageClassifier: ImageClassifying {
    func labels(for imageData: Data) async throws -> [VisualLabel] {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw URLError(.cannotDecodeContentData)
        }

        return try await withCheckedThrowingContinuation { continuation in
            let lock = NSLock()
            var didResume = false

            func resumeOnce(_ result: Result<[VisualLabel], Error>) {
                lock.lock()
                defer { lock.unlock() }
                guard !didResume else {
                    return
                }

                didResume = true
                switch result {
                case .success(let labels):
                    continuation.resume(returning: labels)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            let request = VNClassifyImageRequest { request, error in
                if let error {
                    resumeOnce(.failure(error))
                    return
                }

                let observations = (request.results as? [VNClassificationObservation]) ?? []
                let labels = observations
                    .prefix(8)
                    .map { VisualLabel(identifier: $0.identifier, confidence: $0.confidence) }
                resumeOnce(.success(labels))
            }

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                resumeOnce(.failure(error))
            }
        }
    }
}

actor InMemoryDescriptionCache: DescriptionCache {
    private var values: [String: String] = [:]

    func description(for key: String) -> String? {
        values[key]
    }

    func store(_ description: String, for key: String) {
        values[key] = description
    }
}

struct StaticImageClassifier: ImageClassifying {
    let labels: [VisualLabel]

    func labels(for imageData: Data) async throws -> [VisualLabel] {
        labels
    }
}

private struct UITestPosterImageLoader: PosterImageLoading {
    func imageData(from url: URL) async throws -> Data {
        try await Task.sleep(nanoseconds: 300_000_000)
        return Data([1])
    }
}
