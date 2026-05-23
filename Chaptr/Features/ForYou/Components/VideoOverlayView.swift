import SwiftUI

struct VideoOverlayView: View {
    let video: FeedVideo
    let description: String
    let tags: [String]
    let state: VideoPlaybackState
    let progress: Double
    let isMuted: Bool
    let isUserPaused: Bool
    let onMuteToggle: () -> Void
    let onRetry: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let metrics = FeedOverlayMetrics(size: proxy.size, safeAreaInsets: proxy.safeAreaInsets)

            ZStack {
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [.black.opacity(0.6), .black.opacity(0.2), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: proxy.safeAreaInsets.top + 80)
                    Spacer()
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.25), .black.opacity(0.78)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: proxy.size.height * 0.45)
                }
                .ignoresSafeArea()

                VStack {
                    header(metrics: metrics)
                        .padding(.leading, metrics.leadingPadding)
                        .padding(.trailing, metrics.trailingPadding)
                    Spacer()
                    bottomContent(metrics: metrics)
                        .padding(.leading, metrics.bottomContentLeadingPadding)
                        .padding(.trailing, metrics.bottomContentTrailingPadding)
                }
                .padding(.top, metrics.topPadding)
                .padding(.bottom, metrics.bottomPadding)

                HStack {
                    Spacer()
                    actionRail(metrics: metrics)
                }
                .padding(.trailing, metrics.actionTrailingPadding)
                .padding(.bottom, metrics.actionBottomPadding)

                stateOverlay

                if isUserPaused {
                    Image(systemName: "play.fill")
                        .font(.system(size: min(metrics.width * 0.14, 64)))
                        .foregroundStyle(.white.opacity(0.8))
                        .shadow(radius: 12)
                        .accessibilityLabel("Paused")
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
    }

    private func header(metrics: FeedOverlayMetrics) -> some View {
        HStack(spacing: 8) {
            Text("Chaptr")
                .font(metrics.headerFont.weight(.bold))
            Text("For You")
                .font(metrics.headerFont.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
            Spacer()
        }
        .shadow(radius: 10)
    }

    private func bottomContent(metrics: FeedOverlayMetrics) -> some View {
        HStack(alignment: .bottom, spacing: 18) {
            VStack(alignment: .leading, spacing: metrics.textSpacing) {
                Text(video.title)
                    .font(metrics.titleFont.weight(.bold))
                    .lineLimit(2)
                    .minimumScaleFactor(metrics.minimumScaleFactor)
                Text(description)
                    .font(metrics.descriptionFont)
                    .foregroundStyle(.white.opacity(0.86))
                    .lineLimit(metrics.descriptionLineLimit)
                    .minimumScaleFactor(metrics.minimumScaleFactor)
                if metrics.showsTags, !tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                    .lineLimit(1)
                }
                ProgressView(value: progress)
                    .tint(.white)
                    .opacity(0.72)
                    .accessibilityLabel("Playback progress")
                    .accessibilityValue("\(Int(progress * 100)) percent")
                Text(DurationFormatter.shortLabel(seconds: video.duration))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer(minLength: metrics.textTrailingReserve)
        }
        .padding(.bottom, metrics.bottomContentLift)
        .shadow(radius: 12)
    }

    private func actionRail(metrics: FeedOverlayMetrics) -> some View {
        VStack(spacing: 18) {
            FeedActionButton(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill", label: isMuted ? "Unmute" : "Mute", size: metrics.actionButtonSize, action: onMuteToggle)
            FeedActionButton(systemName: "arrow.clockwise", label: "Retry", size: metrics.actionButtonSize, action: onRetry)
        }
        .padding(.bottom, metrics.height * metrics.actionRailLiftRatio)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    @ViewBuilder
    private var stateOverlay: some View {
        switch state {
        case .idle, .ready:
            EmptyView()
        case .loading:
            LoadingOverlayView(message: "Loading")
        case .stalled:
            LoadingOverlayView(message: "Buffering")
                .onAppear {
                    UIAccessibility.post(notification: .announcement, argument: "Buffering")
                }
        case .failed(let message):
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                Button("Retry", action: onRetry)
                    .buttonStyle(.borderedProminent)
            }
            .padding(20)
            .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
            .padding(28)
        }
    }
}

private struct FeedOverlayMetrics {
    let size: CGSize
    let safeAreaInsets: EdgeInsets

    var width: CGFloat { size.width }
    var height: CGFloat { size.height }
    var isNarrow: Bool { width <= 390 }
    var isShort: Bool { height <= 700 }
    var leadingPadding: CGFloat { safeAreaInsets.leading + (isNarrow ? 36 : 48) }
    var trailingPadding: CGFloat { safeAreaInsets.trailing + (isNarrow ? 24 : 32) }
    var bottomContentLeadingPadding: CGFloat { safeAreaInsets.leading + (isNarrow ? 20 : 24) }
    var bottomContentTrailingPadding: CGFloat { safeAreaInsets.trailing + (isNarrow ? 16 : 20) }
    var actionTrailingPadding: CGFloat { safeAreaInsets.trailing + (isNarrow ? 20 : 24) }
    var topPadding: CGFloat { max(safeAreaInsets.top + (isShort ? 22 : 42), isShort ? 48 : 86) }
    var bottomPadding: CGFloat { max(safeAreaInsets.bottom + 10, isShort ? 18 : 28) }
    var actionBottomPadding: CGFloat { max(safeAreaInsets.bottom + 10, isShort ? 18 : 24) }
    var bottomContentLift: CGFloat { isShort ? 8 : 18 }
    var actionRailLiftRatio: CGFloat { isShort ? 0.09 : 0.12 }
    var actionButtonSize: CGFloat { isNarrow ? 42 : 48 }
    var textTrailingReserve: CGFloat { isNarrow ? 56 : 72 }
    var textSpacing: CGFloat { isShort ? 6 : 8 }
    var headerFont: Font { isShort ? .subheadline : .headline }
    var titleFont: Font { isNarrow || isShort ? .headline : .title3 }
    var descriptionFont: Font { isNarrow || isShort ? .caption : .subheadline }
    var descriptionLineLimit: Int { isShort ? 2 : 3 }
    var minimumScaleFactor: CGFloat { isNarrow ? 0.75 : 0.82 }
    var showsTags: Bool { !isShort }
}
