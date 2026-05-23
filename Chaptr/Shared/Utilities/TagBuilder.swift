import Foundation

enum TagBuilder {
    private static let stopWords: Set<String> = [
        "a", "an", "the", "in", "of", "on", "with", "and", "at", "is", "for", "to", "by"
    ]

    static func tags(for video: FeedVideo) -> [String] {
        var result: [String] = []

        let words = video.title
            .components(separatedBy: .whitespaces)
            .map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty && !stopWords.contains($0) }

        let contentTags = words.prefix(2).map { "#\($0)" }
        result.append(contentsOf: contentTags)

        if video.duration >= 180 {
            result.append("#longform")
        } else if video.duration >= 120 {
            result.append("#shortform")
        } else {
            result.append("#clip")
        }

        let maxDim = max(video.width, video.height)
        if maxDim >= 1920 {
            result.append("#fullhd")
        } else if maxDim >= 1280 {
            result.append("#hd")
        } else {
            result.append("#sd")
        }

        return Array(result.prefix(4))
    }
}
