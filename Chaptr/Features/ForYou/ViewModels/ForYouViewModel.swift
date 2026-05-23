import Combine
import Foundation

@MainActor
final class ForYouViewModel: ObservableObject {
    @Published private(set) var videos: [FeedVideo] = []
    @Published private(set) var loadState: CatalogLoadState = .idle
    @Published var activeIndex = 0
    @Published var isMuted = false

    let playbackCoordinator: PlaybackCoordinator
    private let repository: CatalogRepository
    private var pendingWindowUpdate: DispatchWorkItem?

    init(repository: CatalogRepository, playbackCoordinator: PlaybackCoordinator) {
        self.repository = repository
        self.playbackCoordinator = playbackCoordinator
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
            // s14 First loaded video becomes active so autoplay can start.
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
        // s23 Old/off-screen videos pause before the new active item plays.
        playbackCoordinator.pauseAll(except: videos[index].id)

        pendingWindowUpdate?.cancel()
        // s31 Fast swipes are debounced before rebuilding the player window.
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.playbackCoordinator.prepareWindow(activeIndex: index, videos: self.videos)
        }
        pendingWindowUpdate = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    func toggleMuted() {
        isMuted.toggle()
        playbackCoordinator.setMuted(isMuted)
    }

    func togglePlayPause() {
        playbackCoordinator.togglePlayPause()
    }

    func retry(video: FeedVideo) {
        // s43 Retry bridges the UI action into fresh playback preparation.
        playbackCoordinator.retry(video: video, isActive: video.id == activeVideo?.id)
    }

    func handleScenePhase(isActive: Bool) {
        // s53 App lifecycle pauses in background and resumes on foreground.
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
        DescriptionBuilder.description(for: video)
    }

    func tags(for video: FeedVideo) -> [String] {
        TagBuilder.tags(for: video)
    }

    var activeVideo: FeedVideo? {
        videos.indices.contains(activeIndex) ? videos[activeIndex] : nil
    }
}
