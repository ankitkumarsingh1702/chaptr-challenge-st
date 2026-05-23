import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct RootView: View {
    // s12 Root setup connects catalog loading, playback, and network state.
    @StateObject private var viewModel = ForYouViewModel(
        repository: BundleCatalogRepository(),
        playbackCoordinator: PlaybackCoordinator()
    )
    @StateObject private var networkMonitor = NetworkMonitor()

    var body: some View {
        ForYouFeedView(viewModel: viewModel)
            .environmentObject(networkMonitor)
            .task {
                // s13 Catalog loads once when the root view appears.
                await viewModel.load()
            }
            .onReceive(memoryWarningPublisher) { _ in
                viewModel.handleMemoryWarning()
            }
            .onReceive(networkMonitor.$isConnected) { connected in
                if connected {
                    // s52 Network recovery refreshes the active playback window.
                    viewModel.handleConnectivityRestored()
                }
            }
            .onReceive(networkMonitor.$isExpensive) { expensive in
                viewModel.playbackCoordinator.setNetworkExpensive(expensive)
            }
    }

    private var memoryWarningPublisher: NotificationCenter.Publisher {
#if canImport(UIKit)
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
#else
        NotificationCenter.default.publisher(for: Notification.Name("MemoryWarning"))
#endif
    }
}
