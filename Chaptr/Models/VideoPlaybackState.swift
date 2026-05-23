import Foundation

enum VideoPlaybackState: Equatable {
    case idle
    case loading
    case ready
    case stalled
    case failed(String)

    var isRecoverable: Bool {
        if case .failed = self {
            return true
        }
        return false
    }
}

