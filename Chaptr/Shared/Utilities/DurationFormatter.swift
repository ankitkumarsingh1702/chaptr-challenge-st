import Foundation

enum DurationFormatter {
    static func shortLabel(seconds: Int) -> String {
        let minutes = max(seconds, 0) / 60
        let remainingSeconds = max(seconds, 0) % 60
        return "\(minutes):\(String(format: "%02d", remainingSeconds))"
    }
}

