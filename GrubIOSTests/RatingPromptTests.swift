import XCTest
@testable import GrubIOS

final class RatingPromptTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "rate_\(UUID().uuidString)")!
    }

    func test_requests_on_positive_moment() {
        var requested = 0
        let p = RatingPrompt(defaults: makeDefaults(),
                             now: { Date(timeIntervalSince1970: 0) },
                             request: { requested += 1 })
        p.consider(moment: .positive)
        XCTAssertEqual(requested, 1)
    }

    func test_never_requests_on_negative_moment() {
        var requested = 0
        let p = RatingPrompt(defaults: makeDefaults(),
                             now: { Date(timeIntervalSince1970: 0) },
                             request: { requested += 1 })
        p.consider(moment: .negative)
        XCTAssertEqual(requested, 0)
    }

    func test_respects_cooldown() {
        let d = makeDefaults()
        var now = Date(timeIntervalSince1970: 0)
        var requested = 0
        let p = RatingPrompt(defaults: d, now: { now }, request: { requested += 1 })
        p.consider(moment: .positive)              // fires
        now = now.addingTimeInterval(60)
        p.consider(moment: .positive)              // within cooldown → suppressed
        XCTAssertEqual(requested, 1)
    }

    func test_fires_again_after_cooldown() {
        let d = makeDefaults()
        var now = Date(timeIntervalSince1970: 0)
        var requested = 0
        let p = RatingPrompt(defaults: d, now: { now }, request: { requested += 1 })
        p.consider(moment: .positive)
        now = now.addingTimeInterval(60 * 60 * 24 * 91)   // past 90-day cooldown
        p.consider(moment: .positive)
        XCTAssertEqual(requested, 2)
    }
}
