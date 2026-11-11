import XCTest
@testable import GrubIOS

final class DigRulesTests: XCTestCase {
    let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// A larva with a find buried at `spot`, and the stats given.
    func save(spot: Int = 0, belly: Int = 6, joy: Int = 6, digs: Int = 3,
              stage: GrubStage = .larva, condition: DigCondition? = nil) -> BurrowSave {
        var s = BurrowSave.fresh(now: t0)
        s.stage = stage; s.name = "GRUB"
        s.belly = belly; s.joy = joy; s.digs = digs
        s.buried = [BuriedFind(spot: spot, kind: .berry, condition: condition)]
        return s
    }

    func strikes(_ s: BurrowSave, spot: Int = 0) -> Int {
        let r = BurrowRules.startTrip(s, spot: spot)
        for case .tripStarted(_, let n) in r.events { return n }
        XCTFail("no trip started: \(r.events)"); return -1
    }

    func test_strikes_come_from_the_layer() {
        XCTAssertEqual(strikes(save(spot: 1), spot: 1), 6, "loose")
        XCTAssertEqual(strikes(save(spot: 0), spot: 0), 5, "clay")
        XCTAssertEqual(strikes(save(spot: 3), spot: 3), 4, "deep")
    }

    func test_wet_adds_two_and_rooty_takes_one() {
        XCTAssertEqual(strikes(save(spot: 0, condition: .wet)), 7)
        XCTAssertEqual(strikes(save(spot: 0, condition: .rooty)), 4)
        XCTAssertEqual(strikes(save(spot: 0, condition: .rocky)), 5, "rocky costs tiles, not strikes")
    }

    func test_a_happy_grub_digs_longer_and_a_sulking_one_shorter() {
        XCTAssertEqual(strikes(save(joy: 7)), 7, "happy")
        XCTAssertEqual(strikes(save(belly: 0)), 4, "sulking")
    }

    func test_sulking_beats_happy_when_both_hold() {
        XCTAssertEqual(strikes(save(belly: 0, joy: 10)), 4,
                       "starving outweighs cheerful")
    }

    func test_an_egg_gets_no_mood_bonus() {
        var s = save(joy: 10, stage: .egg)
        s.name = ""
        XCTAssertEqual(strikes(s), 5, "stats are larva-only")
    }

    func test_the_worst_case_is_two_strikes() {
        XCTAssertEqual(strikes(save(spot: 3, belly: 0, condition: .rooty), spot: 3), 2,
                       "deep 4, rooty -1, sulking -1")
    }

    func test_a_trip_spends_a_charge_and_marks_the_spot_visited() {
        let r = BurrowRules.startTrip(save(digs: 2), spot: 0)
        XCTAssertEqual(r.save.digs, 1)
        XCTAssertTrue(r.save.buried[0].visited)
    }

    func test_trip_refusals() {
        XCTAssertEqual(BurrowRules.startTrip(save(digs: 0), spot: 0).events, [.refused(.noDigs)])
        XCTAssertEqual(BurrowRules.startTrip(save(), spot: 5).events, [.refused(.nothingBuriedThere)])
        XCTAssertEqual(BurrowRules.startTrip(save(stage: .adult), spot: 0).events,
                       [.refused(.wrongStage)])
    }
}
