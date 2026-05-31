import XCTest
@testable import GrubIOS

final class NotificationSchedulerTests: XCTestCase {
    func test_schedules_hungry_when_hunger_above_threshold() {
        let notices = NotificationScheduler.plan(
            hunger: 100, happiness: 100,
            hungerPerHour: 6.0, happinessPerHour: 4.0,
            expeditionEnd: nil,
            from: Date(timeIntervalSince1970: 0))
        XCTAssertTrue(notices.contains { $0.id == "grub_hungry" })
        XCTAssertTrue(notices.contains { $0.id == "grub_lonely" })
    }

    func test_does_not_schedule_hungry_when_already_low() {
        let notices = NotificationScheduler.plan(
            hunger: 10, happiness: 10,
            hungerPerHour: 6.0, happinessPerHour: 4.0,
            expeditionEnd: nil,
            from: Date(timeIntervalSince1970: 0))
        XCTAssertFalse(notices.contains { $0.id == "grub_hungry" })
        XCTAssertFalse(notices.contains { $0.id == "grub_lonely" })
    }

    func test_schedules_expedition_ready_when_end_is_future() {
        let from = Date(timeIntervalSince1970: 0)
        let end = from.addingTimeInterval(3600)
        let notices = NotificationScheduler.plan(
            hunger: 100, happiness: 100,
            hungerPerHour: 6, happinessPerHour: 4,
            expeditionEnd: end, from: from)
        let exp = notices.first { $0.id == "expedition_ready" }
        XCTAssertEqual(exp?.fireDate, end)
    }

    func test_skips_expedition_when_end_is_past() {
        let from = Date(timeIntervalSince1970: 3600)
        let end = Date(timeIntervalSince1970: 0)
        let notices = NotificationScheduler.plan(
            hunger: 100, happiness: 100,
            hungerPerHour: 6, happinessPerHour: 4,
            expeditionEnd: end, from: from)
        XCTAssertFalse(notices.contains { $0.id == "expedition_ready" })
    }

    func test_hungry_fire_date_uses_decay_rate() {
        let from = Date(timeIntervalSince1970: 0)
        // hunger 85, threshold 25, rate 6/hr -> 60/6 = 10 hours
        let notices = NotificationScheduler.plan(
            hunger: 85, happiness: 100,
            hungerPerHour: 6.0, happinessPerHour: 4.0,
            expeditionEnd: nil, from: from)
        let hungry = notices.first { $0.id == "grub_hungry" }!
        XCTAssertEqual(hungry.fireDate.timeIntervalSince(from), 10 * 3600, accuracy: 1)
    }
}
