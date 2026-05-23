import XCTest
@testable import Chaptr

final class VisualDescriptionComposerTests: XCTestCase {
    private let composer = VisualDescriptionComposer()

    func testFitnessLabelsProduceWorkoutCopy() {
        let description = composer.description(
            for: makeVideo(
                title: "Intense Indoor Fitness Workout Session",
                thumbnail: "https://images.pexels.com/videos/36014878/athlete-bodybuilding-cineamtic-cinema-36014878.jpeg"
            ),
            labels: labels("athlete", "bodybuilding", "exercise")
        )

        XCTAssertEqual(
            description,
            "An energetic indoor training session focused on strength work, repetition, and high-intensity movement."
        )
    }

    func testKnownCategoriesProduceDistinctCopy() {
        let samples: [(FeedVideo, [VisualLabel], String)] = [
            (
                makeVideo(title: "Landscape With Cascade Waterfalls In Forest"),
                labels("waterfall", "forest", "landscape"),
                "nature scene"
            ),
            (
                makeVideo(title: "Aerial View Of Cablebus Over Mexico City"),
                labels("city", "street", "building"),
                "city-life clip"
            ),
            (
                makeVideo(title: "A Deer Standing On A Road With Grass And Trees"),
                labels("deer", "wildlife", "animal"),
                "animal moment"
            ),
            (
                makeVideo(title: "A Colorful Abstract Painting"),
                labels("abstract art", "colorful pattern"),
                "color-led visual piece"
            ),
            (
                makeVideo(title: "Smoke In Slow Motion"),
                labels("fireplace", "flame", "smoke"),
                "warm ambient clip"
            ),
            (
                makeVideo(title: "Traditional Tribal Dance In Outdoor Village Setting"),
                labels("people", "dance", "group"),
                "dance moment"
            ),
        ]

        for (video, labels, expectedText) in samples {
            let description = composer.description(for: video, labels: labels)
            XCTAssertTrue(description?.contains(expectedText) == true, "Expected \(expectedText) in \(description ?? "nil")")
        }
    }

    func testLowConfidenceUnknownLabelsReturnNilForFallback() {
        let description = composer.description(
            for: makeVideo(title: "Untitled Moment", thumbnail: "https://example.com/poster.jpg"),
            labels: [VisualLabel(identifier: "unclear object", confidence: 0.12)]
        )

        XCTAssertNil(description)
    }

    func testHighConfidenceUnknownLabelsUseSafeGeneralCopy() {
        let description = composer.description(
            for: makeVideo(title: "Untitled Moment", thumbnail: "https://example.com/poster.jpg"),
            labels: [VisualLabel(identifier: "maillot brassiere overskirt", confidence: 0.82)]
        )

        XCTAssertEqual(description, "A visually focused short-form clip with clear motion and full-screen composition.")
        XCTAssertFalse(description?.contains("maillot") == true)
        XCTAssertFalse(description?.contains("brassiere") == true)
    }

    func testGeneratedDescriptionsStayShortAndDeterministic() {
        let video = makeVideo(title: "People Walking Down A Street At Dusk")
        let labels = labels("people", "street", "city")

        let first = composer.description(for: video, labels: labels)
        let second = composer.description(for: video, labels: labels)

        XCTAssertEqual(first, second)
        XCTAssertNotNil(first)
        XCTAssertLessThanOrEqual(first?.count ?? 0, 130)
    }

    private func labels(_ identifiers: String...) -> [VisualLabel] {
        identifiers.map { VisualLabel(identifier: $0, confidence: 0.86) }
    }

    private func makeVideo(
        id: Int = 1,
        title: String,
        thumbnail: String = "https://example.com/poster.jpg"
    ) -> FeedVideo {
        FeedVideo(
            id: id,
            title: title,
            duration: 118,
            width: 720,
            height: 1280,
            url: "https://example.com/video.mp4",
            thumbnail: thumbnail
        )
    }
}
