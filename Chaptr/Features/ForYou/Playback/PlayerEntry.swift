import AVFoundation

final class PlayerEntry {
    let id: Int
    let player: AVPlayer
    let item: AVPlayerItem
    var observer: PlayerObserver?
    private var timeObserverToken: Any?
    private var loadingTimer: DispatchWorkItem?

    init(id: Int, player: AVPlayer, item: AVPlayerItem) {
        self.id = id
        self.player = player
        self.item = item
    }

    func stop() {
        player.pause()
        cancelLoadingTimeout()
        if let timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
        }
        timeObserverToken = nil
        observer?.invalidate()
        observer = nil
        player.replaceCurrentItem(with: nil)
    }

    func startLoadingTimeout(timeout: TimeInterval = 15, onTimeout: @escaping () -> Void) {
        // s51 Slow loads fail after 15 seconds instead of buffering forever.
        cancelLoadingTimeout()
        let work = DispatchWorkItem { onTimeout() }
        loadingTimer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: work)
    }

    func cancelLoadingTimeout() {
        loadingTimer?.cancel()
        loadingTimer = nil
    }

    func observeProgress(_ handler: @escaping (Double) -> Void) {
        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak item] time in
            guard let duration = item?.duration.seconds, duration.isFinite, duration > 0 else {
                handler(0)
                return
            }
            let progress = min(max(time.seconds / duration, 0), 1)
            handler((progress * 100).rounded() / 100)
        }
    }
}
