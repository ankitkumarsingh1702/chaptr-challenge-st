import SwiftUI

struct VideoPageView: View {
    let video: FeedVideo
    let description: String
    let tags: [String]
    let isActive: Bool
    let isMuted: Bool
    @ObservedObject var coordinator: PlaybackCoordinator
    let onMuteToggle: () -> Void
    let onRetry: () -> Void
    let onPlayPauseToggle: () -> Void

    var body: some View {
        ZStack {
            Color.black
            mediaLayer
            VideoOverlayView(
                video: video,
                description: description,
                tags: tags,
                state: coordinator.state(for: video.id),
                progress: coordinator.progress(for: video.id),
                isMuted: isMuted,
                isUserPaused: coordinator.isUserPaused && isActive,
                onMuteToggle: onMuteToggle,
                onRetry: onRetry
            )
        }
        .clipped()
        .onTapGesture {
            // s41 Tapping the active video toggles play and pause.
            if isActive { onPlayPauseToggle() }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(video.title), \(DurationFormatter.shortLabel(seconds: video.duration))")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Toggle playback") {
            // s57 VoiceOver users can trigger the same play/pause action.
            if isActive { onPlayPauseToggle() }
        }
    }

    @ViewBuilder
    private var mediaLayer: some View {
        let playerReady = coordinator.state(for: video.id) == .ready

        ZStack {
            if !playerReady {
                AsyncPosterView(url: video.thumbnailURL)
            }

            if playerReady, let player = coordinator.player(for: video.id) {
                VideoPlayerLayerView(player: player)
            }
        }
    }
}
