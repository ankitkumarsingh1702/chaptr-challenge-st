import Foundation

struct VideoCatalog: Decodable {
    let videos: [FeedVideo]
}

struct FeedVideo: Decodable, Identifiable, Equatable {
    let id: Int
    let title: String
    let duration: Int
    let width: Int
    let height: Int
    let url: String
    let thumbnail: String

    var videoURL: URL? {
        Self.webURL(from: url)
    }

    var thumbnailURL: URL? {
        Self.webURL(from: thumbnail)
    }

    private static func webURL(from value: String) -> URL? {
        guard let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host,
              !host.isEmpty else {
            return nil
        }

        return url
    }
}
