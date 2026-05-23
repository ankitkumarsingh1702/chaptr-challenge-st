import Foundation

enum DescriptionBuilder {
    static func description(for video: FeedVideo) -> String {
        let category = categoryValue(for: video)
        let subject = subject(from: video.title)
        let tempo = tempoLabel(seconds: video.duration)
        let templates = templates(for: category)
        let index = abs(video.id) % templates.count

        return templates[index](subject, tempo)
    }

    static func inferredCategory(for video: FeedVideo) -> String {
        categoryValue(for: video).rawValue
    }

    private static func categoryValue(for video: FeedVideo) -> DescriptionCategory {
        let tokenSet = Set(tokens(for: video))
        for rule in categoryRules where rule.keywords.isDisjoint(with: tokenSet) == false {
            return rule.category
        }
        return .general
    }

    private static func tokens(for video: FeedVideo) -> [String] {
        uniqueTokens(from: "\(video.title) \(thumbnailSlug(from: video.thumbnail))")
    }

    private static func thumbnailSlug(from thumbnail: String) -> String {
        guard let url = URL(string: thumbnail) else {
            return thumbnail
        }

        return url.deletingPathExtension().lastPathComponent
    }

    private static func uniqueTokens(from value: String) -> [String] {
        let rawTokens = value
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { token in
                token.count > 2 && token.allSatisfy(\.isNumber) == false && stopWords.contains(token) == false
            }

        return rawTokens.reduce(into: []) { result, token in
            if result.contains(token) == false {
                result.append(token)
            }
        }
    }

    private static func subject(from title: String) -> String {
        var subject = title.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["A ", "An ", "The "] where subject.hasPrefix(prefix) {
            subject = String(subject.dropFirst(prefix.count))
            break
        }
        let result = subject.prefix(1).lowercased() + subject.dropFirst()
        return result.isEmpty ? "a short clip" : result
    }

    private static func tempoLabel(seconds: Int) -> String {
        if seconds >= 180 { return "slow-burn" }
        if seconds <= 75 { return "quick-hit" }
        return "steady"
    }

    private static func templates(for category: DescriptionCategory) -> [(String, String) -> String] {
        switch category {
        case .fireAmbient:
            return [
                { subject, _ in "A warm ambient clip built around \(subject), soft motion, and full-screen atmosphere." },
                { _, tempo in "A \(tempo) fireplace moment with glowing texture and a calm visual rhythm." },
            ]
        case .natureLandscape:
            return [
                { subject, _ in "A scenic \(subject) clip with calm texture and room to settle into the moment." },
                { _, tempo in "A \(tempo) outdoor view shaped for immersive vertical browsing." },
            ]
        case .fitnessSport:
            return [
                { subject, _ in "A focused \(subject) moment built around movement, repetition, and vertical pacing." },
                { _, tempo in "A \(tempo) training clip with clear motion and workout energy." },
            ]
        case .abstractArt:
            return [
                { subject, _ in "A visual art clip centered on \(subject), color, and motion." },
                { _, tempo in "A \(tempo) abstract visual designed for immersive full-screen viewing." },
            ]
        case .cityLifestyle:
            return [
                { subject, _ in "A lifestyle clip following \(subject) with a clean short-form feel." },
                { _, tempo in "A \(tempo) city moment with movement, place, and vertical framing." },
            ]
        case .foodDrink:
            return [
                { subject, _ in "A close-up food moment built around \(subject), texture, and detail." },
                { _, tempo in "A \(tempo) food clip with a simple, sensory full-screen feel." },
            ]
        case .animals:
            return [
                { subject, _ in "An animal-focused clip capturing \(subject) in a natural, watchable moment." },
                { _, tempo in "A \(tempo) wildlife moment with gentle motion and clear subject focus." },
            ]
        case .peopleActivity:
            return [
                { subject, _ in "A people-centered clip capturing \(subject) with natural motion and presence." },
                { _, tempo in "A \(tempo) human moment shaped for quick, full-screen browsing." },
            ]
        case .general:
            return [
                { subject, _ in "A vertical clip featuring \(subject), tuned for clean full-screen viewing." },
                { _, tempo in "A \(tempo) short-form moment with simple pacing and a clear visual focus." },
            ]
        }
    }
}

private enum DescriptionCategory: String {
    case fireAmbient
    case natureLandscape
    case fitnessSport
    case abstractArt
    case cityLifestyle
    case foodDrink
    case animals
    case peopleActivity
    case general
}

private let categoryRules: [(category: DescriptionCategory, keywords: Set<String>)] = [
    (.fireAmbient, ["fire", "fireplace", "flame", "flames", "burning", "smoke", "incense", "ambient"]),
    (.natureLandscape, ["nature", "landscape", "sunset", "ocean", "sea", "beach", "forest", "mountain", "sky", "water", "scenic"]),
    (.fitnessSport, ["gym", "fitness", "exercise", "workout", "training", "sport", "crossfit", "body", "running", "yoga"]),
    (.abstractArt, ["abstract", "painting", "colorful", "art", "mural", "graffiti", "symbols", "signs", "background"]),
    (.cityLifestyle, ["city", "street", "new", "york", "fashion", "travel", "building", "urban", "lifestyle"]),
    (.foodDrink, ["food", "drink", "coffee", "tea", "kitchen", "cooking", "meal", "fruit", "restaurant"]),
    (.animals, ["animal", "animals", "kangaroo", "kangaroos", "dog", "cat", "bird", "wildlife", "yard"]),
    (.peopleActivity, ["people", "person", "man", "woman", "girl", "boy", "hands", "oculus", "artist", "doing"]),
]

private let stopWords: Set<String> = [
    "and", "the", "with", "from", "into", "over", "under", "this", "that", "than",
    "auto", "compress", "tinysrgb", "crop", "jpeg", "jpg", "photo", "pexels",
    "video", "videos", "files", "background", "white", "black", "front",
]
