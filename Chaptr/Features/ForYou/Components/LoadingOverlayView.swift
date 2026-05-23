import SwiftUI

struct LoadingOverlayView: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(.white)
            Text(message)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.82))
        }
        .padding(16)
        .background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 8))
    }
}

