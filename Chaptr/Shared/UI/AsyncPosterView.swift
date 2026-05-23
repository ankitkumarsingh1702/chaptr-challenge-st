import SwiftUI

struct AsyncPosterView: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                posterFallback
            case .empty:
                posterFallback
                    .overlay(ProgressView().tint(.white))
            @unknown default:
                posterFallback
            }
        }
        .ignoresSafeArea()
    }

    private var posterFallback: some View {
        LinearGradient(
            colors: [Color(red: 0.05, green: 0.05, blue: 0.06), Color(red: 0.16, green: 0.18, blue: 0.2)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

