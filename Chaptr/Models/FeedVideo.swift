import Foundation

struct VideoCatalog: Decodable {
    let videos: [FeedVideo]
}

struct FeedVideo: Decodable, Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
    let description: String?
    let duration: Int
    let width: Int
    let height: Int
    let url: String
    let thumbnail: String

    init(
        id: Int,
        title: String,
        description: String? = nil,
        duration: Int,
        width: Int,
        height: Int,
        url: String,
        thumbnail: String
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.duration = duration
        self.width = width
        self.height = height
        self.url = url
        self.thumbnail = thumbnail
    }

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
