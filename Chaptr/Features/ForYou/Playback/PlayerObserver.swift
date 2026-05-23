import AVFoundation

final class PlayerObserver {
    private var observations: [NSKeyValueObservation] = []
    private var endObserver: NSObjectProtocol?
    private var failedToEndObserver: NSObjectProtocol?
    private weak var item: AVPlayerItem?

    init(
        item: AVPlayerItem,
        onStateChange: @escaping (VideoPlaybackState) -> Void,
        onEnd: @escaping () -> Void
    ) {
        self.item = item
        observations = [
            item.observe(\.status, options: [.initial, .new]) { item, _ in
                switch item.status {
                case .readyToPlay:
                    onStateChange(.ready)
                case .failed:
                    onStateChange(.failed(item.error?.localizedDescription ?? "Video failed to load."))
                case .unknown:
                    onStateChange(.loading)
                @unknown default:
                    onStateChange(.failed("Unsupported video state."))
                }
            },
            item.observe(\.isPlaybackLikelyToKeepUp, options: [.new]) { item, _ in
                guard item.status == .readyToPlay else {
                    return
                }

                if item.isPlaybackLikelyToKeepUp {
                    onStateChange(.ready)
                } else {
                    onStateChange(.stalled)
                }
            },
            item.observe(\.isPlaybackBufferEmpty, options: [.new]) { item, _ in
                guard item.status == .readyToPlay else {
                    return
                }

                if item.isPlaybackBufferEmpty {
                    onStateChange(.stalled)
                } else {
                    onStateChange(.ready)
                }
            }
        ]

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            onEnd()
        }

        failedToEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { notification in
            let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            onStateChange(.failed(error?.localizedDescription ?? "Playback failed unexpectedly."))
        }
    }

    func invalidate() {
        observations.removeAll()
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
        if let failedToEndObserver {
            NotificationCenter.default.removeObserver(failedToEndObserver)
        }
        failedToEndObserver = nil
        item = nil
    }

    deinit {
        invalidate()
    }
}
