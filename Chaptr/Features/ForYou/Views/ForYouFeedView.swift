import SwiftUI

struct ForYouFeedView: View {
    @ObservedObject var viewModel: ForYouViewModel
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @Environment(\.scenePhase) private var scenePhase
    // s56 SceneStorage keeps the last active video index across relaunch.
    @SceneStorage("activeVideoIndex") private var savedIndex: Int = 0
    @State private var scrollPositionID: Int?
    @State private var didRestoreScrollPosition = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
            connectionBanner
        }
        .preferredColorScheme(.dark)
        .persistentSystemOverlays(.hidden)
        .onChange(of: scenePhase) { _, newPhase in
            viewModel.handleScenePhase(isActive: newPhase == .active)
        }
        .onChange(of: networkMonitor.isConnected) { _, connected in
            if connected {
                UIAccessibility.post(notification: .announcement, argument: "Network connection restored")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .idle, .loading:
            LoadingOverlayView(message: "Preparing your feed")
        case .loaded:
            feed
        case .empty:
            FeedMessageView(title: "No videos yet", message: "The local catalog is empty.")
        case .failed(let message):
            FeedMessageView(title: "Could not load feed", message: message, onRetry: {
                Task { await viewModel.load() }
            })
        }
    }

    private var feed: some View {
        // s21 This is the full-screen vertical paging feed.
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.videos.enumerated()), id: \.element.id) { index, video in
                    VideoPageView(
                        video: video,
                        description: viewModel.description(for: video),
                        tags: viewModel.tags(for: video),
                        isActive: index == viewModel.activeIndex,
                        isMuted: viewModel.isMuted,
                        coordinator: viewModel.playbackCoordinator,
                        onMuteToggle: viewModel.toggleMuted,
                        onRetry: { viewModel.retry(video: video) },
                        onPlayPauseToggle: viewModel.togglePlayPause
                    )
                    .containerRelativeFrame([.horizontal, .vertical])
                    .id(video.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrollPositionID)
        .ignoresSafeArea()
        .onAppear(perform: restoreScrollPositionIfNeeded)
        .onChange(of: scrollPositionID) { _, newID in
            // s22 Scroll position changes decide which video is active.
            updateActivePage(for: newID)
        }
        .onChange(of: viewModel.activeIndex) { _, newIndex in
            savedIndex = newIndex
        }
    }

    @ViewBuilder
    private var connectionBanner: some View {
        if !networkMonitor.isConnected {
            GeometryReader { proxy in
                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: "wifi.slash")
                            .font(.caption)
                        Text("No connection")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.red.opacity(0.85), in: Capsule())
                    .padding(.top, proxy.safeAreaInsets.top + 4)
                    Spacer()
                }
                .ignoresSafeArea()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.3), value: networkMonitor.isConnected)
            .onAppear {
                UIAccessibility.post(notification: .announcement, argument: "Network connection lost")
            }
        }
    }

    private func restoreScrollPositionIfNeeded() {
        guard !didRestoreScrollPosition, viewModel.videos.isEmpty == false else { return }
        didRestoreScrollPosition = true

        let restoredIndex = viewModel.videos.indices.contains(savedIndex) ? savedIndex : 0
        scrollPositionID = viewModel.videos[restoredIndex].id
        if restoredIndex != viewModel.activeIndex {
            viewModel.updateActiveIndex(restoredIndex)
        }
    }

    private func updateActivePage(for videoID: Int?) {
        guard let videoID,
              let index = viewModel.videos.firstIndex(where: { $0.id == videoID }),
              index != viewModel.activeIndex else {
            return
        }

        viewModel.updateActiveIndex(index)
    }
}

private struct FeedMessageView: View {
    let title: String
    let message: String
    var onRetry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title2.weight(.semibold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let onRetry {
                Button("Try Again", action: onRetry)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
