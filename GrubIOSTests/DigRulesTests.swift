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
        XCTAssertEqual(strikes(save(spot: 0), spot: 0), 6, "clay")
        XCTAssertEqual(strikes(save(spot: 3), spot: 3), 5, "deep")
    }

    func test_only_wet_changes_the_strike_count() {
        XCTAssertEqual(strikes(save(spot: 0, condition: .wet)), 8)
        XCTAssertEqual(strikes(save(spot: 0, condition: .rooty)), 6, "rooty costs tiles, not strikes")
        XCTAssertEqual(strikes(save(spot: 0, condition: .rocky)), 6, "rocky costs tiles, not strikes")
    }

    func test_a_happy_grub_digs_longer_and_a_sulking_one_shorter() {
        XCTAssertEqual(strikes(save(joy: 7)), 8, "happy")
        XCTAssertEqual(strikes(save(belly: 0)), 5, "sulking")
    }

    func test_sulking_beats_happy_when_both_hold() {
        XCTAssertEqual(strikes(save(belly: 0, joy: 10)), 5,
                       "starving outweighs cheerful")
    }

    func test_an_egg_gets_no_mood_bonus() {
        var s = save(joy: 10, stage: .egg)
        s.name = ""
        XCTAssertEqual(strikes(s), 6, "stats are larva-only")
    }

    func test_the_worst_case_is_four_strikes() {
        XCTAssertEqual(strikes(save(spot: 3, belly: 0, condition: .rooty), spot: 3), 4,
                       "deep 5, sulking -1; rooty no longer costs a strike")
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

    // MARK: strike

    /// A save whose spot-0 grid is fully known.
    ///
    ///     col:  0  1  2  3  4
    ///  row 0:   R  .  .  .  .     R = root (tile 0)
    ///  row 1:   .  .  .  .  .
    ///  row 2:   K  .  F  .  .     K = rock, 2 hp (tile 10) — d == 2 from the find
    ///  row 3:   .  .  .  .  .     F = the find (tile 12, the centre)
    ///  row 4:   .  .  .  .  .
    ///
    /// Tile 11 is plain soil at d == 1 (hot); tile 24 is soil at d == 4 (cold).
    func rigged() -> BurrowSave {
        var s = save()
        var tiles = [DigTile](repeating: .soil, count: 25)
        tiles[0] = .root
        tiles[10] = .rock(hp: 2)
        s.buried = [BuriedFind(spot: 0, kind: .berry, condition: nil,
                               findTile: 12, tiles: tiles)]
        return s
    }

    func test_breaking_a_soil_tile_reports_its_heat() {
        let r = BurrowRules.strike(rigged(), spot: 0, tile: 11, strikesLeft: 3)   // d == 1
        XCTAssertEqual(r.events, [.tileBroken(tile: 11, heat: .hot)])
        XCTAssertEqual(r.save.buried[0].tiles[11], .broken)
    }

    func test_distant_tiles_read_cold() {
        let r = BurrowRules.strike(rigged(), spot: 0, tile: 24, strikesLeft: 3)   // d == 4
        XCTAssertEqual(r.events, [.tileBroken(tile: 24, heat: .cold)])
    }

    func test_a_rock_takes_two_strikes() {
        let first = BurrowRules.strike(rigged(), spot: 0, tile: 10, strikesLeft: 3)
        XCTAssertEqual(first.events, [.rockChipped(tile: 10)])
        XCTAssertEqual(first.save.buried[0].tiles[10], .rock(hp: 1))

        let second = BurrowRules.strike(first.save, spot: 0, tile: 10, strikesLeft: 2)
        XCTAssertEqual(second.events, [.tileBroken(tile: 10, heat: .warm)])   // d == 2
        XCTAssertEqual(second.save.buried[0].tiles[10], .broken)
    }

    func test_finding_the_item_fills_the_bag_and_clears_the_spot() {
        // Striking the find tile is d == 0, which reads hot (see DigGrid.heat).
        let r = BurrowRules.strike(rigged(), spot: 0, tile: 12, strikesLeft: 1)
        XCTAssertEqual(r.events, [.tileBroken(tile: 12, heat: .hot), .dugUp(spot: 0, kind: .berry)])
        XCTAssertEqual(r.save.bag[.berry], 2, "fresh starts with one berry")
        XCTAssertTrue(r.save.buried.isEmpty)
        XCTAssertEqual(r.save.holes, [0])
    }

    func test_a_rock_can_hide_the_find() {
        var s = rigged()
        s.buried[0].findTile = 10                   // the rock tile
        let first = BurrowRules.strike(s, spot: 0, tile: 10, strikesLeft: 2)
        XCTAssertEqual(first.events, [.rockChipped(tile: 10)], "still buried after one hit")
        let second = BurrowRules.strike(first.save, spot: 0, tile: 10, strikesLeft: 1)
        XCTAssertEqual(second.events, [.tileBroken(tile: 10, heat: .hot), .dugUp(spot: 0, kind: .berry)])
    }

    func test_strike_refusals_cost_nothing() {
        XCTAssertEqual(BurrowRules.strike(rigged(), spot: 0, tile: 0, strikesLeft: 3).events,
                       [.refused(.rootTile)])
        XCTAssertEqual(BurrowRules.strike(rigged(), spot: 0, tile: 11, strikesLeft: 0).events,
                       [.refused(.noStrikes)])
        XCTAssertEqual(BurrowRules.strike(rigged(), spot: 0, tile: 99, strikesLeft: 3).events,
                       [.refused(.badTile)])
        XCTAssertEqual(BurrowRules.strike(rigged(), spot: 5, tile: 1, strikesLeft: 3).events,
                       [.refused(.nothingBuriedThere)])

        let broken = BurrowRules.strike(rigged(), spot: 0, tile: 11, strikesLeft: 3).save
        XCTAssertEqual(BurrowRules.strike(broken, spot: 0, tile: 11, strikesLeft: 2).events,
                       [.refused(.alreadyBroken)])
    }

    // MARK: the clean dig

    func test_finding_it_with_three_to_spare_pays_a_bonus() {
        // 4 in hand, so 3 remain after the winning strike.
        let r = BurrowRules.strike(rigged(), spot: 0, tile: 12, strikesLeft: 4)
        guard case .cleanDig(0, let extra)? = r.events.last else {
            return XCTFail("no bonus: \(r.events)")
        }
        XCTAssertEqual(r.events.count, 3, "tile broken, dug up, then the bonus")
        XCTAssertEqual(r.save.bag[extra], (extra == .berry ? 1 : 0) + 1 + (extra == .berry ? 1 : 0),
                       "the bonus landed in the bag alongside the find")
    }

    func test_one_strike_short_of_clean_pays_nothing() {
        let r = BurrowRules.strike(rigged(), spot: 0, tile: 12, strikesLeft: 3)
        XCTAssertEqual(r.events, [.tileBroken(tile: 12, heat: .hot), .dugUp(spot: 0, kind: .berry)])
    }

    func test_a_scraped_win_pays_nothing() {
        let r = BurrowRules.strike(rigged(), spot: 0, tile: 12, strikesLeft: 1)
        XCTAssertFalse(r.events.contains { if case .cleanDig = $0 { return true }; return false })
    }

    func test_the_bonus_is_stable_for_a_burial_but_not_across_them() {
        let find = BuriedFind(spot: 0, kind: .berry, condition: nil, findTile: 12, tiles: [])
        XCTAssertEqual(BurrowRules.bonusKind(for: find), BurrowRules.bonusKind(for: find),
                       "the same pocket holds the same thing")
        var moved = find
        moved.findTile = 7
        let kinds = (0..<25).map { tile -> FindKind in
            var f = find; f.findTile = tile
            return BurrowRules.bonusKind(for: f)
        }
        XCTAssertGreaterThan(Set(kinds).count, 1, "a re-buried spot does not always pay the same")
    }

    func test_the_bonus_comes_from_the_spots_own_soil() {
        // Spot 1 is loose, whose table holds no crystals or amber at any weight.
        for tile in 0..<DigGrid.tileCount {
            let f = BuriedFind(spot: 1, kind: .berry, condition: nil, findTile: tile, tiles: [])
            let bonus = BurrowRules.bonusKind(for: f)
            XCTAssertFalse([.crystal, .amber].contains(bonus),
                           "loose soil paid out \(bonus) at tile \(tile)")
        }
    }

    func test_progress_is_kept_between_trips() {
        let r = BurrowRules.strike(rigged(), spot: 0, tile: 11, strikesLeft: 1)
        // The trip ends here (the model drops to 0 strikes), but the save keeps the hole.
        XCTAssertEqual(r.save.buried[0].tiles[11], .broken)
        XCTAssertEqual(r.save.buried[0].findTile, 12, "the find has not moved")
    }
}
