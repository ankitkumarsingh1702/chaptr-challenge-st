import AVFoundation
import Combine
import Foundation

@MainActor
final class PlaybackCoordinator: ObservableObject {
    @Published private(set) var states: [Int: VideoPlaybackState] = [:]
    @Published private(set) var progress: [Int: Double] = [:]
    @Published private(set) var isUserPaused = false

    private var entries: [Int: PlayerEntry] = [:]
    private var activeVideoID: Int?
    private var isMuted = false
    private var isInForeground = true
    private var isNetworkExpensive = false
    private var wasPlayingBeforeInterruption = false
    private var audioInterruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    private let previousWarmCount = 1
    private let nextPreloadCount = 2

    init() {
        configureAudioSession()
        observeAudioSessionEvents()
    }

    deinit {
        if let audioInterruptionObserver {
            NotificationCenter.default.removeObserver(audioInterruptionObserver)
        }
        if let routeChangeObserver {
            NotificationCenter.default.removeObserver(routeChangeObserver)
        }
    }

    func player(for videoID: Int) -> AVPlayer? {
        entries[videoID]?.player
    }

    func state(for videoID: Int) -> VideoPlaybackState {
        states[videoID] ?? .idle
    }

    func progress(for videoID: Int) -> Double {
        progress[videoID] ?? 0
    }

    func prepareWindow(activeIndex: Int, videos: [FeedVideo]) {
        guard videos.indices.contains(activeIndex) else {
            pauseAll(except: nil)
            releaseAll()
            activeVideoID = nil
            return
        }

        let window = PlaybackWindow(
            activeIndex: activeIndex,
            totalCount: videos.count,
            previousWarmCount: previousWarmCount,
            nextPreloadCount: nextPreloadCount
        )

        let retainedIDs = window.retainedIDs(from: videos)
        releasePlayersOutsideWindow(retainedIDs: retainedIDs)
        retainedIDs.compactMap { id in videos.first { $0.id == id } }.forEach(prepare)

        let newActiveID = videos[activeIndex].id
        if activeVideoID != newActiveID {
            isUserPaused = false
        }
        activeVideoID = newActiveID
        pauseAll(except: activeVideoID)
        playActiveIfNeeded()
    }

    func togglePlayPause() {
        guard let activeVideoID, let entry = entries[activeVideoID] else { return }
        if isUserPaused {
            isUserPaused = false
            entry.player.play()
        } else {
            isUserPaused = true
            entry.player.pause()
        }
    }

    func setMuted(_ muted: Bool) {
        isMuted = muted
        entries.values.forEach { $0.player.isMuted = muted }
    }

    func pauseForBackground() {
        isInForeground = false
        pauseAll(except: nil)
    }

    func resumeForForeground() {
        isInForeground = true
        playActiveIfNeeded()
    }

    func retry(video: FeedVideo, isActive: Bool) {
        release(videoID: video.id)
        prepare(video: video)
        if isActive {
            activeVideoID = video.id
            playActiveIfNeeded()
        }
    }

    func releaseAll() {
        entries.values.forEach { $0.stop() }
        entries.removeAll()
        states.removeAll()
        progress.removeAll()
    }

    func trimToActiveVideo() {
        guard let activeVideoID else {
            releaseAll()
            return
        }

        releasePlayersOutsideWindow(retainedIDs: [activeVideoID])
        playActiveIfNeeded()
    }

    private func prepare(video: FeedVideo) {
        guard entries[video.id] == nil else {
            return
        }

        guard let url = video.videoURL else {
            states[video.id] = .failed("This video URL is invalid.")
            return
        }

        states[video.id] = .loading
        let item = AVPlayerItem(asset: AVURLAsset(url: url))
        item.preferredForwardBufferDuration = isNetworkExpensive ? 5 : 10

        let player = AVPlayer(playerItem: item)
        player.automaticallyWaitsToMinimizeStalling = true
        player.isMuted = isMuted

        let entry = PlayerEntry(id: video.id, player: player, item: item)
        entry.observeProgress { [weak self] progress in
            guard self?.progress[video.id] != progress else { return }
            self?.progress[video.id] = progress
        }
        entry.observer = PlayerObserver(
            item: item,
            onStateChange: { [weak self] state in
                DispatchQueue.main.async {
                    if state != .loading {
                        self?.entries[video.id]?.cancelLoadingTimeout()
                    }
                    self?.states[video.id] = state
                    self?.playActiveIfNeeded()
                }
            },
            onEnd: { [weak self, weak player] in
                player?.seek(to: .zero) { finished in
                    guard finished else { return }
                    DispatchQueue.main.async {
                        guard self?.activeVideoID == video.id else { return }
                        self?.playActiveIfNeeded()
                    }
                }
            }
        )

        entries[video.id] = entry

        entry.startLoadingTimeout { [weak self] in
            guard self?.states[video.id] == .loading else { return }
            self?.states[video.id] = .failed("Video took too long to load.")
        }
    }

    func setNetworkExpensive(_ expensive: Bool) {
        isNetworkExpensive = expensive
        let bufferDuration: TimeInterval = expensive ? 5 : 10
        entries.values.forEach { $0.item.preferredForwardBufferDuration = bufferDuration }
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            return
        }
    }

    private func observeAudioSessionEvents() {
        audioInterruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleAudioInterruption(notification)
            }
        }

        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleRouteChange(notification)
            }
        }
    }

    private func handleAudioInterruption(_ notification: Notification) {
        guard let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            wasPlayingBeforeInterruption = !isUserPaused && activeVideoID != nil
            if let activeVideoID, let entry = entries[activeVideoID] {
                entry.player.pause()
            }
        case .ended:
            guard let optionsValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume), wasPlayingBeforeInterruption {
                playActiveIfNeeded()
            }
            wasPlayingBeforeInterruption = false
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue),
              reason == .oldDeviceUnavailable else { return }

        if let activeVideoID, let entry = entries[activeVideoID] {
            entry.player.pause()
            isUserPaused = true
        }
    }

    private func playActiveIfNeeded() {
        guard isInForeground, !isUserPaused,
              let activeVideoID, let activeEntry = entries[activeVideoID] else {
            return
        }

        activeEntry.player.isMuted = isMuted
        activeEntry.player.play()
    }

    func pauseAll(except videoID: Int?) {
        entries.forEach { id, entry in
            if id != videoID {
                entry.player.pause()
            }
        }
    }

    private func releasePlayersOutsideWindow(retainedIDs: Set<Int>) {
        entries.keys.filter { retainedIDs.contains($0) == false }.forEach(release)
        states.keys.filter { retainedIDs.contains($0) == false }.forEach { states.removeValue(forKey: $0) }
        progress.keys.filter { retainedIDs.contains($0) == false }.forEach { progress.removeValue(forKey: $0) }
    }

    private func release(videoID: Int) {
        entries[videoID]?.stop()
        entries.removeValue(forKey: videoID)
        states.removeValue(forKey: videoID)
        progress.removeValue(forKey: videoID)
    }
}
