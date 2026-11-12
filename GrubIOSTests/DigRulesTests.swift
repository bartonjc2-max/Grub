import XCTest
@testable import GrubIOS

final class DigRulesTests: XCTestCase {
    let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// A larva with a find buried at `spot`, and the stats given.
    func save(spot: Int = 0, belly: Int = 6, joy: Int = 6, digs: Int = 3,
              stage: GrubStage = .larva, condition: DigCondition? = nil) -> BurrowSave {
        var s = BurrowSave.fresh(now: t0)
        // Sites move now, so a fresh save's map is generated. Pin it: these tests are about
        // what a LAYER grants, not about which index happens to be deep on a given run.
        s.spots = BurrowSpots.fallback
        s.stage = stage; s.name = "GRUB"
        s.belly = belly; s.joy = joy; s.digs = digs
        s.buried = [BuriedFind(spot: spot, kind: .berry,
                               layer: BurrowSpots.fallback[spot].layer, condition: condition)]
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
        XCTAssertEqual(BurrowRules.bonusKind(for: find, layer: .clay), BurrowRules.bonusKind(for: find, layer: .clay),
                       "the same pocket holds the same thing")
        var moved = find
        moved.findTile = 7
        let kinds = (0..<25).map { tile -> FindKind in
            var f = find; f.findTile = tile
            return BurrowRules.bonusKind(for: f, layer: .clay)
        }
        XCTAssertGreaterThan(Set(kinds).count, 1, "a re-buried spot does not always pay the same")
    }

    func test_the_bonus_comes_from_the_spots_own_soil() {
        // Loose soil's table holds no crystals or amber at any weight.
        for tile in 0..<DigGrid.tileCount {
            let f = BuriedFind(spot: 1, kind: .berry, condition: nil, findTile: tile, tiles: [])
            let bonus = BurrowRules.bonusKind(for: f, layer: .loose)
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

    // MARK: decor tiers

    /// Loose soil with a plain condition can never score 2, so the shallow spots pay chipped
    /// things whatever you do. That is the rule that makes depth worth digging for.
    func test_shallow_plain_soil_only_ever_pays_chipped() {
        for tile in 0..<DigGrid.tileCount {
            let f = BuriedFind(spot: 1, kind: .shell, condition: nil, findTile: tile, tiles: [])
            XCTAssertEqual(BurrowRules.tier(for: f, layer: BurrowSpots.fallback[f.spot].layer, cleanDig: false), 1, "tile \(tile)")
        }
    }

    /// And the deep, glinting, cleanly-dug pocket is the only place pristine comes from.
    func test_only_a_deep_clean_dig_can_pay_pristine() {
        var deepClean = 0, shallowClean = 0
        for tile in 0..<DigGrid.tileCount {
            let deep = BuriedFind(spot: 3, kind: .crystal, condition: .glinting,
                                  findTile: tile, tiles: [])
            let loose = BuriedFind(spot: 1, kind: .shell, condition: .glinting,
                                   findTile: tile, tiles: [])
            if BurrowRules.tier(for: deep, layer: .deep, cleanDig: true) == FindKind.maxTier { deepClean += 1 }
            if BurrowRules.tier(for: loose, layer: .loose, cleanDig: true) == FindKind.maxTier { shallowClean += 1 }
        }
        XCTAssertGreaterThan(deepClean, 0, "a deep glinting clean dig can pay pristine")
        XCTAssertEqual(shallowClean, 0, "loose soil cannot, however cleanly it is dug")
    }

    func test_a_better_find_upgrades_the_kind_on_the_shelf() {
        var s = BurrowSave.fresh(now: Date())
        XCTAssertEqual(s.tier(.crystal), 1, "absent reads as chipped")
        let e = BurrowRules.collect(&s, kind: .crystal, tier: 3)
        XCTAssertEqual(e, .upgraded(kind: .crystal, tier: 3))
        XCTAssertEqual(s.tier(.crystal), 3)
        // And a worse one afterwards never downgrades what is already on display.
        _ = BurrowRules.collect(&s, kind: .crystal, tier: 1)
        XCTAssertEqual(s.tier(.crystal), 3)
    }

    /// The floor. Before tiers, a decor find with the slots full could not be eaten or placed
    /// and simply sat in the bag — about 30 % of everything dug from week one.
    func test_surplus_banks_until_it_buys_the_next_tier() {
        var s = BurrowSave.fresh(now: Date())
        for i in 1..<BurrowRules.bankPerTier {
            XCTAssertNil(BurrowRules.collect(&s, kind: .amber, tier: 1), "bank step \(i)")
            XCTAssertEqual(s.bank[.amber], i, "every duplicate moved it along")
        }
        XCTAssertEqual(BurrowRules.collect(&s, kind: .amber, tier: 1),
                       .upgraded(kind: .amber, tier: 2))
        XCTAssertEqual(s.tier(.amber), 2)
        XCTAssertEqual(s.bank[.amber], 0, "the bank resets for the next tier")
    }

    /// Once a kind is pristine its duplicates push whichever kind is furthest behind, so the
    /// loop keeps paying until the whole set is done rather than dead-ending per kind.
    func test_a_maxed_kinds_duplicates_feed_the_kind_furthest_behind() {
        var s = BurrowSave.fresh(now: Date())
        s.bestTier = [.amber: FindKind.maxTier, .bone: 2, .crystal: 2, .shell: 2]
        _ = BurrowRules.collect(&s, kind: .amber, tier: 1)
        XCTAssertEqual(s.bank[.amber] ?? 0, 0, "a pristine kind banks nothing for itself")
        XCTAssertEqual([.bone, .crystal, .shell].compactMap { s.bank[$0] }.reduce(0, +), 1,
                       "it went to one of the kinds still behind")
    }

    func test_nothing_banks_once_the_whole_set_is_pristine() {
        var s = BurrowSave.fresh(now: Date())
        for k in FindKind.allCases where k.isDecor { s.bestTier[k] = FindKind.maxTier }
        XCTAssertNil(BurrowRules.collect(&s, kind: .amber, tier: 1))
        XCTAssertTrue(s.bank.values.allSatisfy { $0 == 0 }, "there is nothing left to buy")
        XCTAssertEqual(s.bag[.amber], 1, "but it is still a find, and still goes in the bag")
    }

    func test_food_has_no_tier_and_never_banks() {
        var s = BurrowSave.fresh(now: Date())
        XCTAssertNil(BurrowRules.collect(&s, kind: .berry, tier: 3))
        XCTAssertTrue(s.bestTier.isEmpty && s.bank.isEmpty, "food is eaten, not displayed")
        XCTAssertEqual(s.bag[.berry], 2, "fresh starts with one")
    }
}
