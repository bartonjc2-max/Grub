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

    // MARK: dig

    func test_dig_moves_find_to_bag_and_leaves_hole() {
        let r = BurrowRules.dig(save { $0.joy = 0 }, spot: 1, now: t0, rng: &rng)
        XCTAssertEqual(r.events, [.dugUp(spot: 1, kind: .amber)])
        XCTAssertEqual(r.save.digs, 2)
        XCTAssertEqual(r.save.bag, [.berry: 1, .amber: 1])
        XCTAssertEqual(r.save.holes, [1])
        XCTAssertFalse(r.save.buried.contains { $0.spot == 1 })
    }

    func test_dig_refusals() {
        XCTAssertEqual(BurrowRules.dig(save(), spot: 7, now: t0, rng: &rng).events, [.refused(.nothingBuriedThere)])
        let none = save { $0.digs = 0 }
        let r = BurrowRules.dig(none, spot: 0, now: t0, rng: &rng)
        XCTAssertEqual(r.events, [.refused(.noDigs)])
        XCTAssertEqual(r.save, none)
    }

    func test_bonus_find_only_when_happy_at_about_35_percent() {
        func bonusRate(joy: Int) -> Double {
            var hits = 0
            for _ in 0..<4000 {
                let s = save { $0.joy = joy; $0.buried = [BuriedFind(spot: 0, kind: .berry)] }
                let r = BurrowRules.dig(s, spot: 0, now: t0, rng: &rng)
                if r.events.contains(where: { if case .bonusFind = $0 { return true } else { return false } }) { hits += 1 }
            }
            return Double(hits) / 4000
        }
        XCTAssertEqual(bonusRate(joy: 7), 0.35, accuracy: 0.03)
        XCTAssertEqual(bonusRate(joy: 6), 0)
    }

    func test_bonus_find_lands_in_bag() {
        var r: BurrowResult
        repeat {
            r = BurrowRules.dig(save { $0.joy = 10; $0.bag = [:] }, spot: 0, now: t0, rng: &rng)
        } while r.events.count < 2
        guard case .bonusFind(0, let extra) = r.events[1] else { return XCTFail("\(r.events)") }
        XCTAssertEqual(r.save.bag.values.reduce(0, +), 2)
        XCTAssertGreaterThanOrEqual(r.save.bag[extra] ?? 0, 1)
    }

    // MARK: feed

    func test_feed_auto_eats_berry() {
        let r = BurrowRules.feed(save(), kind: nil, now: t0)
        XCTAssertEqual(r.events, [.ate(.berry, joyGained: true)])
        XCTAssertEqual([r.save.belly, r.save.joy, r.save.molt], [9, 7, 1])
        XCTAssertNil(r.save.bag[.berry], "empty bag entries are removed")
        XCTAssertEqual(r.save.eaten, [.berry: 1])
        XCTAssertEqual(r.save.lastMeal, .berry)
    }

    func test_repeat_meal_gives_no_joy() {
        let s = save { $0.bag = [.berry: 2]; $0.lastMeal = .berry; $0.belly = 2 }
        let r = BurrowRules.feed(s, kind: nil, now: t0)
        XCTAssertEqual(r.events, [.ate(.berry, joyGained: false)])
        XCTAssertEqual(r.save.joy, 6)
    }

    func test_feed_works_while_sulking() {
        let r = BurrowRules.feed(save { $0.belly = 0 }, kind: .berry, now: t0)
        XCTAssertEqual(r.save.molt, 1)
        XCTAssertFalse(BurrowRules.isSulking(r.save))
    }

    func test_feed_refusals() {
        XCTAssertEqual(BurrowRules.feed(save { $0.bag = [:] }, kind: nil, now: t0).events, [.refused(.noFood)])
        XCTAssertEqual(BurrowRules.feed(save { $0.bag = [.crystal: 1] }, kind: .crystal, now: t0).events, [.refused(.notFood)])
        XCTAssertEqual(BurrowRules.feed(save { $0.bag = [:] }, kind: .berry, now: t0).events, [.refused(.notInBag)])
        let full = save { $0.belly = 10 }
        let r = BurrowRules.feed(full, kind: nil, now: t0)
        XCTAssertEqual(r.events, [.refused(.tooFull)])
        XCTAssertEqual(r.save, full, "nothing is used when too full")
        XCTAssertEqual(BurrowRules.feed(save { $0.stage = .egg }, kind: nil, now: t0).events, [.refused(.wrongStage)])
    }

    func test_molt_ready_fires_only_on_the_crossing() {
        let r = BurrowRules.feed(save { $0.molt = 9; $0.bag = [.berry: 2] }, kind: nil, now: t0)
        XCTAssertEqual(r.events.last, .moltReady)
        XCTAssertEqual(r.save.molt, 10)
        var again = r.save
        again.belly = 0
        XCTAssertFalse(BurrowRules.feed(again, kind: nil, now: t0).events.contains(.moltReady))
    }

    // MARK: pet

    func test_pet_gives_joy_at_most_once_per_15_min() {
        let a = BurrowRules.pet(save(), now: t0)
        XCTAssertEqual(a.events, [.petted(joyGained: true)])
        XCTAssertEqual(a.save.joy, 7)
        let b = BurrowRules.pet(a.save, now: t0.addingTimeInterval(14 * 60))
        XCTAssertEqual(b.events, [.petted(joyGained: false)])
        XCTAssertEqual(b.save.joy, 7)
        XCTAssertEqual(BurrowRules.pet(b.save, now: t0.addingTimeInterval(15 * 60)).save.joy, 8)
    }
}
