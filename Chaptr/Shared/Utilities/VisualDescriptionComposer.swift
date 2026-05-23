import Foundation

struct VisualLabel: Equatable, Sendable {
    let identifier: String
    let confidence: Float
}

struct VisualDescriptionResult: Equatable, Sendable {
    let text: String
    let quality: Double
}

struct VisualDescriptionComposer: Sendable {
    func description(for video: FeedVideo, labels: [VisualLabel]) -> String? {
        result(for: video, labels: labels)?.text
    }

    func result(for video: FeedVideo, labels: [VisualLabel]) -> VisualDescriptionResult? {
        let evidence = VisualEvidence(video: video, labels: labels)
        guard evidence.hasUsefulSignal else {
            return nil
        }

        return VisualDescriptionResult(
            text: copy(for: evidence.category, evidence: evidence),
            quality: evidence.quality
        )
    }

    private func copy(for category: VisualCategory, evidence: VisualEvidence) -> String {
        switch category {
        case .fitness:
            if evidence.containsAny(["indoor", "gym", "bodybuilding", "workout"]) {
                return "An energetic indoor training session focused on strength work, repetition, and high-intensity movement."
            }
            return "A focused training clip built around athletic movement, repetition, and strong vertical pacing."
        case .nature:
            if evidence.containsAny(["waterfall", "rain", "snow", "forest"]) {
                return "A calm nature scene shaped by texture, atmospheric motion, and a scenic vertical frame."
            }
            return "A scenic outdoor clip with natural movement, open atmosphere, and room to settle into the moment."
        case .city:
            return "A city-life clip with street movement, place detail, and a clean vertical browsing rhythm."
        case .animals:
            return "A watchable animal moment with natural movement, clear subject focus, and a close short-form feel."
        case .abstract:
            return "A color-led visual piece shaped around texture, motion, and full-screen atmosphere."
        case .fireAmbient:
            return "A warm ambient clip built around flame, glow, and slow visual rhythm."
        case .peopleActivity:
            if evidence.containsAny(["dance", "tribal"]) {
                return "A human-centered dance moment with group movement, rhythm, and outdoor presence."
            }
            return "A human-centered moment with natural movement, presence, and short-form pacing."
        case .foodDrink:
            return "A close-up food moment built around texture, detail, and sensory motion."
        case .general:
            return "A visually focused short-form clip with clear motion and full-screen composition."
        }
    }
}

private struct VisualEvidence {
    let video: FeedVideo
    let labels: [VisualLabel]
    let metadataTokens: Set<String>
    let labelTokens: Set<String>
    let category: VisualCategory
    let categoryScore: Double

    init(video: FeedVideo, labels: [VisualLabel]) {
        self.video = video
        self.labels = labels
        self.metadataTokens = Set(Self.tokens(from: "\(video.title) \(Self.thumbnailSlug(from: video.thumbnail))"))
        self.labelTokens = Set(
            labels
                .filter { $0.confidence >= 0.22 }
                .flatMap { Self.tokens(from: $0.identifier) }
        )
        let match = VisualCategory.bestMatch(
            metadataTokens: metadataTokens,
            labelTokens: labelTokens,
            labels: labels
        )
        self.category = match.category
        self.categoryScore = match.score
    }

    var hasUsefulSignal: Bool {
        category != .general || labels.contains { $0.confidence >= 0.35 }
    }

    var quality: Double {
        if category == .general {
            return Double(labels.map(\.confidence).max() ?? 0) * 0.6
        }

        return categoryScore
    }

    func containsAny(_ values: Set<String>) -> Bool {
        metadataTokens.isDisjoint(with: values) == false || labelTokens.isDisjoint(with: values) == false
    }

    private static func tokens(from value: String) -> [String] {
        value
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { token in
                token.count > 2 && token.allSatisfy(\.isNumber) == false && ignoredTokens.contains(token) == false
            }
    }

    private static func thumbnailSlug(from thumbnail: String) -> String {
        guard let url = URL(string: thumbnail) else {
            return thumbnail
        }

        return url.deletingPathExtension().lastPathComponent
    }
}

private enum VisualCategory: CaseIterable {
    case fitness
    case nature
    case city
    case animals
    case abstract
    case fireAmbient
    case peopleActivity
    case foodDrink
    case general

    static func bestMatch(metadataTokens: Set<String>, labelTokens: Set<String>, labels: [VisualLabel]) -> (category: VisualCategory, score: Double) {
        let scored = allCases
            .filter { $0 != .general }
            .map { category in
                (
                    category,
                    category.score(metadataTokens: metadataTokens, labelTokens: labelTokens, labels: labels)
                )
            }
            .sorted { $0.1 > $1.1 }

        guard let best = scored.first, best.1 >= 1.4 else {
            return (.general, 0)
        }

        return best
    }

    private func score(metadataTokens: Set<String>, labelTokens: Set<String>, labels: [VisualLabel]) -> Double {
        let matchedMetadata = metadataTokens.intersection(keywords).count
        let matchedLabels = labelTokens.intersection(keywords).count
        let confidenceBoost = labels.reduce(0.0) { total, label in
            let tokens = Set(VisualEvidence.tokensForScoring(from: label.identifier))
            guard tokens.isDisjoint(with: keywords) == false else {
                return total
            }
            return total + Double(label.confidence)
        }

        return Double(matchedMetadata) * 1.0 + Double(matchedLabels) * 1.8 + confidenceBoost
    }

    private var keywords: Set<String> {
        switch self {
        case .fitness:
            return ["athlete", "bodybuilding", "body", "exercise", "fitness", "gym", "training", "workout", "sport", "strength", "running", "yoga"]
        case .nature:
            return ["adventure", "aerial", "alps", "beach", "bluelake", "forest", "landscape", "mountain", "nature", "outdoor", "rain", "scenic", "snow", "sunset", "water", "waterfall", "winter"]
        case .city:
            return ["building", "cablebus", "cdmx", "city", "downtown", "mexico", "metro", "street", "urban", "skyline", "york"]
        case .animals:
            return ["animal", "animals", "bee", "bees", "deer", "kangaroo", "kangaroos", "squirrel", "wildlife"]
        case .abstract:
            return ["abstract", "art", "color", "colorful", "graffiti", "mural", "painting", "signs", "symbols"]
        case .fireAmbient:
            return ["ambient", "fire", "fireplace", "flame", "glow", "incense", "smoke"]
        case .peopleActivity:
            return ["artist", "dance", "group", "hands", "human", "luggage", "man", "oculus", "people", "person", "tribal", "walking", "woman"]
        case .foodDrink:
            return ["coffee", "cooking", "drink", "food", "kitchen", "meal", "restaurant", "tea"]
        case .general:
            return []
        }
    }
}

private let ignoredTokens: Set<String> = [
    "and", "the", "with", "from", "into", "over", "under", "this", "that", "than",
    "auto", "compress", "tinysrgb", "crop", "jpeg", "jpg", "photo", "pexels",
    "video", "videos", "files", "background", "white", "black", "front",
]

private extension VisualEvidence {
    static func tokensForScoring(from value: String) -> [String] {
        tokens(from: value)
    }
}
