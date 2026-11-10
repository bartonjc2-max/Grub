import XCTest
@testable import GrubIOS

/// Port of docs/burrow/stat-sim.py. Each visit: dig everything, place any decor into free
/// slots, feed while Belly ≤ 7 (auto-feed prefers variety), pet once. Asserts the
/// days-to-molt column of the spec's "Stat roles" table.
final class BurrowPacingTests: XCTestCase {
    let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func daysToMolt(visitMinutes: [Int], seed: UInt64, maxDays: Int = 12) -> Double? {
        var rng = SeededRNG(seed)
        var s = BurrowSave.fresh(now: t0)
        for day in 0..<maxDays {
            for m in visitMinutes {
                let now = t0.addingTimeInterval(TimeInterval(day * 86_400 + m * 60))
                s = BurrowRules.advance(s, to: now, rng: &rng).save
                while s.digs > 0, let f = s.buried.first {
                    s = BurrowRules.dig(s, spot: f.spot, now: now, rng: &rng).save
                }
                for k in FindKind.allCases where k.isDecor {
                    while s.bag[k, default: 0] > 0,
                          let slot = (0..<BurrowRules.decorSlots).first(where: { s.placed[$0] == nil }) {
                        s = BurrowRules.place(s, kind: k, slot: slot, now: now).save
                    }
                }
                while s.belly <= 7 {
                    let r = BurrowRules.feed(s, kind: nil, now: now)
                    if case .refused = r.events.first { break }
                    s = r.save
                }
                s = BurrowRules.pet(s, now: now).save
                if s.molt >= BurrowRules.moltGoal { return now.timeIntervalSince(t0) / 86_400 }
            }
        }
        return nil
    }

    func averageDays(_ visits: [Int]) -> Double {
        let runs = (1...30).map { daysToMolt(visitMinutes: visits, seed: UInt64($0)) ?? 99 }
        return runs.reduce(0, +) / Double(runs.count)
    }

    func test_four_visits_a_day_molts_in_about_2_3_days() {
        XCTAssertEqual(averageDays([8 * 60, 12 * 60, 17 * 60, 22 * 60]), 2.3, accuracy: 0.5)
    }

    func test_two_visits_a_day_molts_in_about_2_4_days() {
        XCTAssertEqual(averageDays([8 * 60, 20 * 60]), 2.4, accuracy: 0.5)
    }

    func test_one_visit_a_day_molts_in_about_4_5_days() {
        XCTAssertEqual(averageDays([19 * 60]), 4.5, accuracy: 0.5)
    }
}
