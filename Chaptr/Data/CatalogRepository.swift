import Foundation

protocol CatalogRepository {
    func loadCatalog() async throws -> VideoCatalog
}

enum CatalogRepositoryError: LocalizedError, Equatable {
    case missingResource
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .missingResource:
            return "The local video catalog could not be found."
        case .decodeFailed:
            return "The video catalog could not be read."
        }
    }
}

struct BundleCatalogRepository: CatalogRepository {
    private let resourceName: String
    private let bundle: Bundle

    init(resourceName: String = "for-you", bundle: Bundle = .main) {
        self.resourceName = resourceName
        self.bundle = bundle
    }

    func loadCatalog() async throws -> VideoCatalog {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw CatalogRepositoryError.missingResource
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(VideoCatalog.self, from: data)
        } catch let error as CatalogRepositoryError {
            throw error
        } catch {
            throw CatalogRepositoryError.decodeFailed
        }
    }
}
