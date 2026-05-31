import XCTest
@testable import GrubIOS

final class RetentionTrackerTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "ret_\(UUID().uuidString)")!
    }

    func test_first_open_is_detected_once() {
        let d = makeDefaults()
        let day0 = Date(timeIntervalSince1970: 1_700_000_000)
        var now = day0
        let t = RetentionTracker(defaults: d, now: { now })

        XCTAssertTrue(t.registerOpen().isFirstOpen)
        now = day0.addingTimeInterval(3600)
        XCTAssertFalse(t.registerOpen().isFirstOpen)
    }

    func test_days_since_first_open() {
        let d = makeDefaults()
        let day0 = Date(timeIntervalSince1970: 1_700_000_000)
        var now = day0
        let t = RetentionTracker(defaults: d, now: { now })
        _ = t.registerOpen()
        now = day0.addingTimeInterval(86_400 * 7)
        XCTAssertEqual(t.registerOpen().daysSinceFirstOpen, 7)
    }
}
