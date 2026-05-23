import XCTest
@testable import Chaptr

@MainActor
final class ForYouViewModelTests: XCTestCase {
    func testEmptyCatalogMapsToEmptyState() async {
        let viewModel = ForYouViewModel(
            repository: MockCatalogRepository(result: .success(VideoCatalog(videos: []))),
            playbackCoordinator: PlaybackCoordinator()
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.loadState, .empty)
    }

    func testRepositoryFailureMapsToFailedState() async {
        let viewModel = ForYouViewModel(
            repository: MockCatalogRepository(result: .failure(CatalogRepositoryError.decodeFailed)),
            playbackCoordinator: PlaybackCoordinator()
        )

        await viewModel.load()

        if case .failed = viewModel.loadState {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected failed state")
        }
    }
}

private struct MockCatalogRepository: CatalogRepository {
    let result: Result<VideoCatalog, Error>

    func loadCatalog() async throws -> VideoCatalog {
        try result.get()
    }
}

