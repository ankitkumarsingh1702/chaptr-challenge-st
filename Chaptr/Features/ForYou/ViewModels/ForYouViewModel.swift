import Combine
import Foundation

@MainActor
final class ForYouViewModel: ObservableObject {
    @Published private(set) var videos: [FeedVideo] = []
    @Published private(set) var loadState: CatalogLoadState = .idle
    @Published private(set) var descriptionsByID: [Int: String] = [:]
    @Published var activeIndex = 0
    @Published var isMuted = false

    let playbackCoordinator: PlaybackCoordinator
    private let repository: CatalogRepository
    private let descriptionService: VideoDescriptionService
    private var pendingWindowUpdate: DispatchWorkItem?
    private var descriptionTask: Task<Void, Never>?

    init(
        repository: CatalogRepository,
        playbackCoordinator: PlaybackCoordinator,
        descriptionService: VideoDescriptionService = .live()
    ) {
        self.repository = repository
        self.playbackCoordinator = playbackCoordinator
        self.descriptionService = descriptionService
    }

    deinit {
        pendingWindowUpdate?.cancel()
        descriptionTask?.cancel()
    }

    func load() async {
        guard loadState == .idle || loadState.isRetryable else {
            return
        }

        loadState = .loading
        do {
            let catalog = try await repository.loadCatalog()
            videos = catalog.videos
            loadState = videos.isEmpty ? .empty : .loaded
            updateActiveIndex(0)
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    func updateActiveIndex(_ index: Int) {
        guard videos.indices.contains(index) else {
            return
        }

        activeIndex = index
        playbackCoordinator.pauseAll(except: videos[index].id)

        pendingWindowUpdate?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.playbackCoordinator.prepareWindow(activeIndex: index, videos: self.videos)
        }
        pendingWindowUpdate = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
        refreshDescriptions(around: index)
    }

    func toggleMuted() {
        isMuted.toggle()
        playbackCoordinator.setMuted(isMuted)
    }

    func togglePlayPause() {
        playbackCoordinator.togglePlayPause()
    }

    func retry(video: FeedVideo) {
        playbackCoordinator.retry(video: video, isActive: video.id == activeVideo?.id)
    }

    func handleScenePhase(isActive: Bool) {
        if isActive {
            playbackCoordinator.resumeForForeground()
        } else {
            playbackCoordinator.pauseForBackground()
        }
    }

    func handleMemoryWarning() {
        playbackCoordinator.trimToActiveVideo()
    }

    func handleConnectivityRestored() {
        guard loadState == .loaded, videos.indices.contains(activeIndex) else { return }
        updateActiveIndex(activeIndex)
    }

    func description(for video: FeedVideo) -> String {
        if let catalogDescription = normalizedDescription(video.description) {
            return catalogDescription
        }
        return descriptionsByID[video.id] ?? DescriptionBuilder.description(for: video)
    }

    func tags(for video: FeedVideo) -> [String] {
        TagBuilder.tags(for: video)
    }

    var activeVideo: FeedVideo? {
        videos.indices.contains(activeIndex) ? videos[activeIndex] : nil
    }

    private func refreshDescriptions(around index: Int) {
        descriptionTask?.cancel()
        let candidates = descriptionCandidates(around: index)
        let service = descriptionService

        descriptionTask = Task { [weak self] in
            await withTaskGroup(of: (Int, String).self) { group in
                for video in candidates {
                    group.addTask {
                        let description = await service.description(for: video)
                        return (video.id, description)
                    }
                }

                for await (videoID, description) in group {
                    guard !Task.isCancelled else { return }

                    await MainActor.run {
                        guard let self, self.videos.contains(where: { $0.id == videoID }) else {
                            return
                        }
                        self.descriptionsByID[videoID] = description
                    }
                }
            }
        }
    }

    private func descriptionCandidates(around index: Int) -> [FeedVideo] {
        guard videos.indices.contains(index) else {
            return []
        }

        let endIndex = min(index + 2, videos.count - 1)
        return Array(videos[index...endIndex])
    }

    private func normalizedDescription(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }
}
