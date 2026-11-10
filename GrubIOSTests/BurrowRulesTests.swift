import XCTest
@testable import GrubIOS

/// Deterministic RNG for tests (SplitMix64).
struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(_ seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

final class BurrowRulesTests: XCTestCase {
    let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let h: TimeInterval = 3600
    var rng = SeededRNG(42)

    /// A fresh larva at t0, customised by `edit`.
    func save(_ edit: (inout BurrowSave) -> Void = { _ in }) -> BurrowSave {
        var s = BurrowSave.fresh(now: t0)
        edit(&s)
        return s
    }

    func advance(_ s: BurrowSave, hours: Double) -> BurrowResult {
        BurrowRules.advance(s, to: t0.addingTimeInterval(hours * h), rng: &rng)
    }

    // MARK: digs

    func test_digs_regrow_one_per_3h_and_cap_at_3() {
        let s = save { $0.digs = 0 }
        XCTAssertEqual(advance(s, hours: 2.9).save.digs, 0)
        XCTAssertEqual(advance(s, hours: 3).save.digs, 1)
        XCTAssertEqual(advance(s, hours: 9).save.digs, 3)
        XCTAssertEqual(advance(s, hours: 30).save.digs, 3)
    }

    func test_dig_timer_carries_partial_time_below_cap() {
        let a = advance(save { $0.digs = 0 }, hours: 2).save          // 2 h banked
        let b = BurrowRules.advance(a, to: t0.addingTimeInterval(3 * h), rng: &rng).save
        XCTAssertEqual(b.digs, 1)
    }

    func test_dig_timer_does_not_bank_at_cap() {
        let a = advance(save { $0.digs = 3 }, hours: 2.9).save
        XCTAssertEqual(a.digTimer, 0)
    }

    // MARK: burying

    func test_buries_every_2h_up_to_4_in_distinct_spots() {
        let s = save { $0.buried = []; $0.holes = [0, 1, 2, 3, 4, 5, 6, 7] }
        XCTAssertEqual(advance(s, hours: 1.9).save.buried.count, 0)
        let one = advance(s, hours: 2)
        XCTAssertEqual(one.save.buried.count, 1)
        XCTAssertEqual(one.events.count, 1)
        guard case .buried(let spot, _) = one.events[0] else { return XCTFail("\(one.events)") }
        XCTAssertFalse(one.save.holes.contains(spot), "reburying a spot clears its hole")
        let full = advance(s, hours: 30).save
        XCTAssertEqual(full.buried.count, 4)
        XCTAssertEqual(Set(full.buried.map(\.spot)).count, 4)
        XCTAssertEqual(full.buryTimer, 0)
    }

    func test_bury_weights() {
        var counts: [FindKind: Int] = [:]
        for _ in 0..<10_000 { counts[BurrowRules.weightedKind(rng: &rng), default: 0] += 1 }
        let total = FindKind.allCases.reduce(0) { $0 + $1.buryWeight }
        for k in FindKind.allCases {
            let expected = Double(k.buryWeight) / Double(total)
            XCTAssertEqual(Double(counts[k] ?? 0) / 10_000, expected, accuracy: 0.02, "\(k)")
        }
    }

    // MARK: belly + joy

    func test_belly_drops_one_per_2h_to_zero() {
        let s = save { $0.belly = 3 }
        XCTAssertEqual(advance(s, hours: 4).save.belly, 1)
        XCTAssertEqual(advance(s, hours: 40).save.belly, 0)
    }

    func test_joy_drops_one_per_4h_plus_1h_per_decor() {
        XCTAssertEqual(advance(save { $0.belly = 10; $0.joy = 10 }, hours: 8).save.joy, 8)
        let decor = save { $0.belly = 10; $0.joy = 10; $0.placed = [0: .amber, 1: .bone] }   // 6 h period
        XCTAssertEqual(advance(decor, hours: 12).save.joy, 8)
    }

    func test_joy_drains_hourly_once_belly_hits_zero_mid_gap() {
        // Belly 1 → 0 at 2 h. Joy timer has 2 h banked, which pays at once on the 1 h period
        // (joy 9), then hourly at 3 h, 4 h, 5 h → 6. Without the switch it would be 9.
        let s = save { $0.belly = 1; $0.joy = 10 }
        XCTAssertEqual(advance(s, hours: 5).save.joy, 6)
    }

    func test_only_larva_runs_belly_and_joy() {
        let s = save { $0.stage = .egg; $0.digs = 0 }
        let r = advance(s, hours: 10).save
        XCTAssertEqual([r.belly, r.joy], [6, 6])
        XCTAssertEqual(r.digs, 3, "digs still regrow in every stage")
    }

    // MARK: clock edge cases

    func test_catch_up_is_capped_at_72h() {
        let long = save { $0.digs = 0; $0.lastTick = self.t0.addingTimeInterval(-30 * 86_400) }
        let capped = save { $0.digs = 0; $0.lastTick = self.t0.addingTimeInterval(-72 * self.h) }
        var r1 = SeededRNG(7), r2 = SeededRNG(7)
        XCTAssertEqual(BurrowRules.advance(long, to: t0, rng: &r1).save,
                       BurrowRules.advance(capped, to: t0, rng: &r2).save)
    }

    func test_clock_moving_backwards_only_resets_lastTick() {
        let s = save { $0.lastTick = self.t0.addingTimeInterval(self.h) }
        let r = BurrowRules.advance(s, to: t0, rng: &rng)
        var expected = s
        expected.lastTick = t0
        XCTAssertEqual(r.save, expected)
        XCTAssertTrue(r.events.isEmpty)
    }
}
