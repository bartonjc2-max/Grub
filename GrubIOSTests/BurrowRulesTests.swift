import XCTest
@testable import GrubIOS

final class BurrowRulesTests: XCTestCase {
    let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let h: TimeInterval = 3600
    var rng = BurrowRNG(seed: 42)

    /// A fresh *hatched* larva named GRUB at t0, customised by `edit`.
    func save(_ edit: (inout BurrowSave) -> Void = { _ in }) -> BurrowSave {
        var s = BurrowSave.fresh(now: t0)
        s.stage = .larva
        s.name = "GRUB"
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

    func test_each_layer_buries_its_own_mix() {
        var counts: [SoilLayer: [FindKind: Int]] = [:]
        for layer in SoilLayer.allCases {
            var rng = BurrowRNG(seed: 7)
            var c: [FindKind: Int] = [:]
            for _ in 0..<4000 { c[DigGen.rollKind(layer: layer, rng: &rng), default: 0] += 1 }
            counts[layer] = c
        }
        XCTAssertEqual(counts[.loose]?[.crystal] ?? 0, 0, "loose soil holds no crystals")
        XCTAssertGreaterThan(counts[.deep]?[.crystal] ?? 0, 500, "deep soil is where crystals live")
        XCTAssertEqual(counts[.loose]?[.amber] ?? 0, 0)
    }

    func test_food_share_per_layer() {
        func foodShare(_ layer: SoilLayer) -> Double {
            var rng = BurrowRNG(seed: 11)
            let n = 4000
            let food = (0..<n).filter { _ in DigGen.rollKind(layer: layer, rng: &rng).isFood }.count
            return Double(food) / Double(n)
        }
        XCTAssertEqual(foodShare(.loose), 0.80, accuracy: 0.03)
        XCTAssertEqual(foodShare(.clay),  0.70, accuracy: 0.03)
        XCTAssertEqual(foodShare(.deep),  0.45, accuracy: 0.03)
    }

    func test_every_layer_table_sums_to_100() {
        for layer in SoilLayer.allCases {
            XCTAssertEqual(DigGen.kindWeights(layer).reduce(0) { $0 + $1.1 }, 100, "\(layer)")
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
        var r1 = BurrowRNG(seed: 7), r2 = BurrowRNG(seed: 7)
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
        XCTAssertEqual(r.events, [.dugUp(spot: 1, kind: .root)])
        XCTAssertEqual(r.save.digs, 2)
        XCTAssertEqual(r.save.bag, [.berry: 1, .root: 1])
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

    func test_spot_table_matches_rules() {
        XCTAssertEqual(BurrowSpots.spots.count, BurrowRules.spotCount)
    }

    // MARK: finds (phase 2)

    func test_find_table_matches_spec() {
        XCTAssertEqual(FindKind.allCases.count, 8)
        XCTAssertEqual(FindKind.feedOrder, [.berry, .root, .mushroom, .honeydew])
        XCTAssertEqual(Set(FindKind.allCases.filter(\.isDecor)), [.crystal, .shell, .amber, .bone])
        // Burial odds are per soil layer now (DigGen.kindWeights), not one global table.
        // Food share is 80 / 70 / 45 by layer; over the 8 spots (3 loose, 3 clay, 2 deep)
        // that averages 67.5 %, close to the 70 % the stat pacing was tuned against.
        let perSpot = (0..<BurrowRules.spotCount).map { spot -> Double in
            let table = DigGen.kindWeights(BurrowSpots.layer(spot))
            return Double(table.filter { $0.0.isFood }.reduce(0) { $0 + $1.1 }) / 100
        }
        XCTAssertEqual(perSpot.reduce(0, +) / Double(perSpot.count), 0.675, accuracy: 0.001)
        XCTAssertEqual(FindKind.root.leansTo, .claws)
        XCTAssertEqual(FindKind.mushroom.leansTo, .stalk)
        XCTAssertEqual(FindKind.honeydew.leansTo, .fuzz)
        XCTAssertEqual(FindKind.shell.leansTo, .shell)
    }

    func test_auto_feed_prefers_a_different_food() {
        let s = save { $0.bag = [.berry: 1, .root: 1]; $0.lastMeal = .berry }
        let r = BurrowRules.feed(s, kind: nil, now: t0)
        XCTAssertEqual(r.events, [.ate(.root, joyGained: true)])
        XCTAssertEqual(r.save.joy, 7)
    }

    func test_auto_feed_falls_back_to_a_repeat() {
        let s = save { $0.bag = [.root: 1]; $0.lastMeal = .root }
        XCTAssertEqual(BurrowRules.feed(s, kind: nil, now: t0).events, [.ate(.root, joyGained: false)])
    }

    func test_feed_specific_food() {
        let s = save { $0.bag = [.berry: 1, .honeydew: 1] }
        let r = BurrowRules.feed(s, kind: .honeydew, now: t0)
        XCTAssertEqual(r.events, [.ate(.honeydew, joyGained: true)])
        XCTAssertEqual(r.save.bag, [.berry: 1])
        XCTAssertEqual(r.save.eaten, [.honeydew: 1])
    }

    // MARK: furnish

    func test_place_moves_decor_from_bag_to_slot() {
        let r = BurrowRules.place(save { $0.bag = [.crystal: 2] }, kind: .crystal, slot: 2, now: t0)
        XCTAssertEqual(r.events, [.placed(slot: 2, kind: .crystal)])
        XCTAssertEqual(r.save.placed, [2: .crystal])
        XCTAssertEqual(r.save.bag, [.crystal: 1])
    }

    func test_place_refusals() {
        let s = save { $0.bag = [.crystal: 1, .berry: 1]; $0.placed = [0: .bone] }
        XCTAssertEqual(BurrowRules.place(s, kind: .berry, slot: 1, now: t0).events, [.refused(.notDecor)])
        XCTAssertEqual(BurrowRules.place(s, kind: .shell, slot: 1, now: t0).events, [.refused(.notInBag)])
        XCTAssertEqual(BurrowRules.place(s, kind: .crystal, slot: 0, now: t0).events, [.refused(.slotTaken)])
        XCTAssertEqual(BurrowRules.place(s, kind: .crystal, slot: 4, now: t0).events, [.refused(.slotTaken)],
                       "out-of-range slots are refused, never crash")
        var egg = s
        egg.stage = .egg
        XCTAssertEqual(BurrowRules.place(egg, kind: .crystal, slot: 1, now: t0).events, [.refused(.wrongStage)])
    }

    func test_remove_returns_decor_to_bag() {
        let r = BurrowRules.remove(save { $0.bag = [:]; $0.placed = [3: .shell] }, slot: 3, now: t0)
        XCTAssertEqual(r.events, [.removed(slot: 3, kind: .shell)])
        XCTAssertTrue(r.save.placed.isEmpty)
        XCTAssertEqual(r.save.bag, [.shell: 1])
        XCTAssertEqual(BurrowRules.remove(save(), slot: 3, now: t0).events, [.refused(.emptySlot)])
    }

    func test_placed_decor_slows_the_joy_drain() {
        // 4 h base + 1 h per placed decor: with 4 placed, Joy drops once per 8 h.
        let s = save { $0.belly = 10; $0.joy = 10; $0.placed = [0: .amber, 1: .bone, 2: .crystal, 3: .shell] }
        XCTAssertEqual(advance(s, hours: 16).save.joy, 8)
    }

    // MARK: molt (phase 3)

    func test_base_odds_favour_grub() {
        let o = BurrowRules.odds(save())
        XCTAssertEqual(o[.grub]!, 2.0 / 7, accuracy: 1e-9)
        for sp in Species.allCases where sp != .grub { XCTAssertEqual(o[sp]!, 1.0 / 7, accuracy: 1e-9) }
        XCTAssertEqual(o.values.reduce(0, +), 1, accuracy: 1e-9)
    }

    func test_diet_shifts_odds() {
        let o = BurrowRules.odds(save { $0.eaten = [.root: 3] })       // claws 1+3 of 10
        XCTAssertEqual(o[.claws]!, 0.4, accuracy: 1e-9)
    }

    func test_placed_decor_counts_double_only_while_placed() {
        let placed = save { $0.placed = [0: .crystal] }                // horn 1+2 of 9
        XCTAssertEqual(BurrowRules.odds(placed)[.horn]!, 3.0 / 9, accuracy: 1e-9)
        let r = BurrowRules.remove(placed, slot: 0, now: t0).save
        XCTAssertEqual(BurrowRules.odds(r)[.horn]!, 1.0 / 7, accuracy: 1e-9)
    }

    func test_lineage_adds_two() {
        XCTAssertEqual(BurrowRules.odds(save { $0.lineage = .stalk })[.stalk]!, 3.0 / 9, accuracy: 1e-9)
    }

    func test_roll_matches_odds() {
        let o = BurrowRules.odds(save { $0.eaten = [.root: 3] })
        var counts: [Species: Int] = [:]
        for _ in 0..<20_000 { counts[BurrowRules.roll(o, rng: &rng), default: 0] += 1 }
        for sp in Species.allCases {
            XCTAssertEqual(Double(counts[sp] ?? 0) / 20_000, o[sp]!, accuracy: 0.015, "\(sp)")
        }
    }

    func test_start_molt_needs_a_full_molt_bar() {
        XCTAssertFalse(BurrowRules.isMoltReady(save { $0.molt = 9 }))
        XCTAssertEqual(BurrowRules.startMolt(save { $0.molt = 9 }, now: t0, rng: &rng).events, [.refused(.notMoltReady)])
        XCTAssertEqual(BurrowRules.startMolt(save { $0.molt = 10; $0.stage = .egg }, now: t0, rng: &rng).events,
                       [.refused(.wrongStage)])
    }

    func test_start_molt_rolls_and_becomes_adult_in_one_step() {
        let s = save { $0.molt = 10 }
        XCTAssertTrue(BurrowRules.isMoltReady(s))
        let r = BurrowRules.startMolt(s, now: t0, rng: &rng)
        guard case .molted(let sp) = r.events.first else { return XCTFail("\(r.events)") }
        XCTAssertEqual(r.events.count, 1)
        XCTAssertEqual(r.save.stage, .adult)
        XCTAssertEqual(r.save.adult, sp)
        XCTAssertFalse(BurrowRules.isMoltReady(r.save))
    }

    func test_adult_stage_freezes_care() {
        let adult = BurrowRules.startMolt(save { $0.molt = 10; $0.belly = 5 }, now: t0, rng: &rng).save
        XCTAssertEqual(BurrowRules.feed(adult, kind: nil, now: t0).events, [.refused(.wrongStage)])
        XCTAssertEqual(BurrowRules.pet(adult, now: t0).events, [.refused(.wrongStage)])
        XCTAssertEqual(advance(adult, hours: 10).save.belly, 5, "belly/joy only drain for a larva")
    }

    // MARK: collect + hatch (phase 4)

    func egg(_ edit: (inout BurrowSave) -> Void = { _ in }) -> BurrowSave {
        var s = BurrowSave.fresh(now: t0)
        edit(&s)
        return s
    }

    func test_valid_names() {
        XCTAssertEqual(BurrowRules.validName("pip"), "PIP")
        XCTAssertEqual(BurrowRules.validName("  MR BEAN "), "MR BEAN")
        XCTAssertEqual(BurrowRules.validName("ABCDEFGHIJ"), "ABCDEFGHIJ")
        for bad in ["", "   ", "ABCDEFGHIJK", "R2D2", "ÉCLAIR", "HI!"] {
            XCTAssertNil(BurrowRules.validName(bad), bad)
        }
        XCTAssertTrue(BurrowRules.eggNames.allSatisfy { BurrowRules.validName($0) == $0 })
    }

    func test_name_the_egg() {
        let r = BurrowRules.name(egg(), "bean", now: t0)
        XCTAssertEqual(r.events, [.named("BEAN")])
        XCTAssertEqual(r.save.name, "BEAN")
        XCTAssertEqual(BurrowRules.name(egg(), "R2", now: t0).events, [.refused(.badName)])
        XCTAssertEqual(BurrowRules.name(save(), "BEAN", now: t0).events, [.refused(.wrongStage)])
    }

    func test_three_cracks_hatch_a_named_egg() {
        XCTAssertEqual(BurrowRules.crackEgg(egg(), now: t0).events, [.refused(.badName)], "name it first")
        var s = egg { $0.name = "PIP" }
        var r = BurrowRules.crackEgg(s, now: t0)
        XCTAssertEqual(r.events, [.eggCracked(stage: 1)]); s = r.save
        r = BurrowRules.crackEgg(s, now: t0)
        XCTAssertEqual(r.events, [.eggCracked(stage: 2)]); s = r.save
        r = BurrowRules.crackEgg(s, now: t0)
        XCTAssertEqual(r.events, [.eggCracked(stage: 3), .hatched])
        XCTAssertEqual(r.save.stage, .larva)
        XCTAssertEqual(r.save.eggCracks, 0)
        XCTAssertEqual(BurrowRules.crackEgg(r.save, now: t0).events, [.refused(.wrongStage)])
    }

    func test_pin_files_the_adult_and_starts_an_inheriting_egg() {
        let adult = save {
            $0.stage = .adult; $0.adult = .horn; $0.name = "PIP"
            $0.belly = 2; $0.joy = 9; $0.molt = 10; $0.eaten = [.root: 4]; $0.lastMeal = .root
            $0.bag = [.amber: 2]; $0.placed = [1: .shell]; $0.digs = 1; $0.holes = [3]
            $0.bellyTimer = 99; $0.joyTimer = 99
        }
        let r = BurrowRules.pin(adult, now: t0)
        XCTAssertEqual(r.events, [.pinned(Specimen(name: "PIP", species: .horn, pinnedAt: t0))])
        let s = r.save
        XCTAssertEqual(s.specimens, [Specimen(name: "PIP", species: .horn, pinnedAt: t0)])
        XCTAssertEqual(s.stage, .egg)
        XCTAssertEqual(s.lineage, .horn)
        XCTAssertEqual(s.tint, .horn)
        XCTAssertNil(s.adult)
        XCTAssertEqual(s.name, "")
        XCTAssertEqual([s.belly, s.joy, s.molt, s.eggCracks], [6, 6, 0, 0])
        XCTAssertTrue(s.eaten.isEmpty)
        XCTAssertNil(s.lastMeal)
        XCTAssertEqual([s.bellyTimer, s.joyTimer], [0, 0])
        // The burrow is the player's: bag, decor, digs and holes carry over.
        XCTAssertEqual(s.bag, [.amber: 2]); XCTAssertEqual(s.placed, [1: .shell])
        XCTAssertEqual(s.digs, 1); XCTAssertEqual(s.holes, [3])
        XCTAssertEqual(BurrowRules.pin(save(), now: t0).events, [.refused(.wrongStage)])
    }

    func test_pinned_name_falls_back_to_grub() {
        let r = BurrowRules.pin(save { $0.stage = .adult; $0.adult = .fuzz; $0.name = "" }, now: t0)
        XCTAssertEqual(r.save.specimens.first?.name, "GRUB")
    }

    func test_lineage_carries_into_the_next_molt_odds() {
        let next = BurrowRules.pin(save { $0.stage = .adult; $0.adult = .stalk }, now: t0).save
        XCTAssertEqual(BurrowRules.odds(next)[.stalk]!, 3.0 / 9, accuracy: 1e-9)
    }

    /// The whole loop on the rules: hatch → feed to molt → molt → pin → next egg.
    func test_full_loop() {
        var s = egg()
        s = BurrowRules.name(s, "PIP", now: t0).save
        for _ in 0..<3 { s = BurrowRules.crackEgg(s, now: t0).save }
        XCTAssertEqual(s.stage, .larva)
        s.bag = [.berry: 20]
        var clock = t0
        while !BurrowRules.isMoltReady(s) {
            clock = clock.addingTimeInterval(6 * 3600)            // let belly drop
            s = BurrowRules.advance(s, to: clock, rng: &rng).save
            s = BurrowRules.feed(s, kind: nil, now: clock).save
        }
        let molted = BurrowRules.startMolt(s, now: clock, rng: &rng)
        guard case .molted(let sp) = molted.events.first else { return XCTFail() }
        let pinned = BurrowRules.pin(molted.save, now: clock).save
        XCTAssertEqual(pinned.stage, .egg)
        XCTAssertEqual(pinned.specimens.map(\.species), [sp])
        XCTAssertEqual(pinned.specimens.map(\.name), ["PIP"])
        XCTAssertEqual(pinned.lineage, sp)
    }
}
