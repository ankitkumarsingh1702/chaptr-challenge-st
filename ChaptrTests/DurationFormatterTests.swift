import XCTest
@testable import Chaptr

final class DurationFormatterTests: XCTestCase {
    func testZeroSeconds() {
        XCTAssertEqual(DurationFormatter.shortLabel(seconds: 0), "0:00")
    }

    func testUnderOneMinute() {
        XCTAssertEqual(DurationFormatter.shortLabel(seconds: 59), "0:59")
    }

    func testExactlyOneMinute() {
        XCTAssertEqual(DurationFormatter.shortLabel(seconds: 60), "1:00")
    }

    func testTypicalDuration() {
        XCTAssertEqual(DurationFormatter.shortLabel(seconds: 236), "3:56")
    }

    func testNegativeInputClampedToZero() {
        XCTAssertEqual(DurationFormatter.shortLabel(seconds: -10), "0:00")
    }
}
