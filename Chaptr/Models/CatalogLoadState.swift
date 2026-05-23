import Foundation

enum CatalogLoadState: Equatable {
    case idle
    case loading
    case loaded
    case empty
    case failed(String)

    var isRetryable: Bool {
        if case .failed = self { return true }
        return false
    }
}

