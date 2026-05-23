import Foundation

struct PlaybackWindow: Equatable {
    let activeIndex: Int
    let totalCount: Int
    let previousWarmCount: Int
    let nextPreloadCount: Int

    var indexRange: ClosedRange<Int>? {
        guard totalCount > 0 else {
            return nil
        }

        // s32 Keep previous 1, active, and next 2 videos in memory.
        let clampedActive = min(max(activeIndex, 0), totalCount - 1)
        let lowerBound = max(0, clampedActive - previousWarmCount)
        let upperBound = min(totalCount - 1, clampedActive + nextPreloadCount)
        return lowerBound...upperBound
    }

    func retainedIDs(from videos: [FeedVideo]) -> Set<Int> {
        guard let indexRange else {
            return []
        }
        return Set(indexRange.map { videos[$0].id })
    }
}
