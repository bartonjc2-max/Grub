import XCTest
@testable import GrubIOS

final class DescentEngineTests: XCTestCase {

    // A tiny 5x4 test room: border walls, entry top-left interior,
    // stairs bottom-right interior, slime in the middle.
    //   row0: #####
    //   row1: #E..#
    //   row2: #.S>#
    //   row3: #####
    static let room: [String] = [
        "#####",
        "#E..#",
        "#.S>#",
        "#####",
    ]

    func makeEngine() -> DescentEngine {
        DescentEngine(layout: Self.room, tuning: DescentTuning())
    }

    func test_parsing_places_grub_at_entry_and_slime_at_spawn() {
        let e = makeEngine()
        XCTAssertEqual(e.grub, GridPoint(x: 1, y: 1))           // 'E'
        XCTAssertEqual(e.hearts, 3)
        XCTAssertEqual(e.status, .playing)
        XCTAssertEqual(e.enemies.count, 1)
        XCTAssertEqual(e.enemies.first?.tile, GridPoint(x: 2, y: 2)) // 'S'
        XCTAssertEqual(e.enemies.first?.hp, 2)
    }

    func test_passability() {
        let e = makeEngine()
        XCTAssertFalse(e.isPassable(GridPoint(x: 0, y: 0)))     // wall
        XCTAssertTrue(e.isPassable(GridPoint(x: 1, y: 1)))      // entry/floor
        XCTAssertTrue(e.isPassable(GridPoint(x: 3, y: 2)))      // stairs
        XCTAssertFalse(e.isPassable(GridPoint(x: -1, y: 1)))    // out of bounds
        XCTAssertFalse(e.isPassable(GridPoint(x: 99, y: 1)))    // out of bounds
    }

    func test_held_move_steps_one_tile_per_step_duration() {
        var e = makeEngine()
        e.setMove(.e)
        e.update(e.tuning.grubStepDuration)
        XCTAssertEqual(e.grub, GridPoint(x: 2, y: 1))   // moved east one tile
        XCTAssertEqual(e.facing, .e)
    }

    func test_move_into_wall_is_blocked() {
        var e = makeEngine()
        e.setMove(.n)                                    // wall directly above entry (row 0)
        e.update(e.tuning.grubStepDuration)
        XCTAssertEqual(e.grub, GridPoint(x: 1, y: 1))   // unchanged
        XCTAssertEqual(e.facing, .n)                    // facing still updates
    }

    func test_release_move_stops_stepping() {
        var e = makeEngine()
        e.setMove(.e)
        e.update(e.tuning.grubStepDuration)             // -> (2,1)
        e.setMove(nil)
        e.update(e.tuning.grubStepDuration * 5)
        XCTAssertEqual(e.grub, GridPoint(x: 2, y: 1))   // no further movement
    }

    func test_direction8_quantization() {
        XCTAssertEqual(Direction8.from(dx: 1.0, dy: 0.0), .e)
        XCTAssertEqual(Direction8.from(dx: 0.0, dy: 1.0), .s)    // y down
        XCTAssertEqual(Direction8.from(dx: 0.0, dy: -1.0), .n)
        XCTAssertEqual(Direction8.from(dx: 0.8, dy: 0.8), .se)
        XCTAssertEqual(Direction8.from(dx: -0.9, dy: -0.1), .w)
        XCTAssertNil(Direction8.from(dx: 0.0, dy: 0.0))         // dead zone
    }

    func test_static_path_exists_from_entry_to_stairs_avoiding_slime_spawn() {
        let e = makeEngine()
        XCTAssertTrue(e.hasStaticPathToStairs())
    }

    // Frozen-enemy engine: the slime never moves, so attack behavior is tested
    // in isolation. Default room has grub (1,1), slime (2,2).
    func makeFrozenEnemyEngine() -> DescentEngine {
        var t = DescentTuning()
        t.enemyStepDuration = 9999    // slime effectively never steps during a test
        return DescentEngine(layout: Self.room, tuning: t)
    }

    func test_attack_auto_targets_adjacent_enemy_without_facing() {
        // v2: HIT auto-targets the nearest in-range enemy — no precise facing.
        var e = makeFrozenEnemyEngine()                    // grub (1,1), slime (2,2) diag-adjacent
        // Default facing is .s (toward (1,2) floor), NOT the slime — auto-target still hits.
        e.attack()
        XCTAssertEqual(e.enemies.first?.hp, 1)            // 2 -> 1
    }

    func test_attack_faces_the_targeted_enemy() {
        var e = makeFrozenEnemyEngine()                    // grub (1,1), slime (2,2) -> SE
        e.attack()
        XCTAssertEqual(e.facing, .se)                     // turned to face the auto-target
    }

    func test_two_attacks_kill_two_hp_slime() {
        var e = makeFrozenEnemyEngine()                    // grub (1,1), slime (2,2) in range
        e.attack()                                         // hp 2 -> 1
        e.update(e.tuning.attackCooldown)                  // clear cooldown (grub idle, slime frozen)
        e.attack()                                         // hp 1 -> 0 -> removed
        XCTAssertTrue(e.enemies.isEmpty)
    }

    func test_attack_with_no_enemy_in_range_does_nothing() {
        // wideRoom puts the slime at (5,3), far outside attackRange of grub (1,1).
        var e = DescentEngine(layout: Self.wideRoom)
        e.attack()
        XCTAssertEqual(e.enemies.first?.hp, 2)            // nothing in range -> no damage
    }

    func test_attack_respects_cooldown() {
        var e = makeFrozenEnemyEngine()                    // slime in range
        e.attack()                                         // hp -> 1
        e.attack()                                         // still cooling down, no effect
        XCTAssertEqual(e.enemies.first?.hp, 1)
    }

    // Room with grub far from slime so we can observe approach without contact.
    //   row0: #######
    //   row1: #E....#
    //   row2: #.....#
    //   row3: #....S#
    //   row4: #....>#
    //   row5: #######
    static let wideRoom: [String] = [
        "#######",
        "#E....#",
        "#.....#",
        "#....S#",
        "#....>#",
        "#######",
    ]

    func test_enemy_chases_toward_grub() {
        var e = DescentEngine(layout: Self.wideRoom)
        let before = e.enemies.first!.tile               // (5,3)
        e.update(e.tuning.enemyStepDuration)             // one enemy step
        let after = e.enemies.first!.tile
        let distBefore = abs(before.x - e.grub.x) + abs(before.y - e.grub.y)
        let distAfter  = abs(after.x  - e.grub.x) + abs(after.y  - e.grub.y)
        XCTAssertLessThan(distAfter, distBefore)         // got closer
    }

    func test_enemy_does_not_step_into_wall() {
        // Slime boxed against the right wall; chasing left toward grub must stay in bounds.
        var e = DescentEngine(layout: Self.wideRoom)
        for _ in 0..<20 { e.update(e.tuning.enemyStepDuration) }
        let t = e.enemies.first?.tile
        if let t = t { XCTAssertTrue(e.isPassable(t)) }  // never on a wall / OOB
    }

    func test_static_path_false_when_only_route_is_through_slime_spawn() {
        // A 1-wide corridor where the slime spawn blocks the sole path.
        //   ###
        //   #E#
        //   #S#
        //   #>#
        //   ###
        let blocked = DescentEngine(layout: [
            "###",
            "#E#",
            "#S#",
            "#>#",
            "###",
        ])
        XCTAssertFalse(blocked.hasStaticPathToStairs())
    }

    func test_contact_removes_a_heart_and_starts_iframes() {
        var e = makeEngine()                              // grub (1,1), slime (2,2)
        // Let the slime reach grub. Don't move grub.
        var guardCount = 0
        while e.hearts == e.tuning.startHearts && guardCount < 50 {
            e.update(e.tuning.enemyStepDuration)
            guardCount += 1
        }
        XCTAssertEqual(e.hearts, e.tuning.startHearts - 1)
        XCTAssertTrue(e.isInIFrames)
    }

    func test_no_second_hit_during_iframes() {
        var e = makeEngine()
        var guardCount = 0
        while e.hearts == e.tuning.startHearts && guardCount < 50 {
            e.update(e.tuning.enemyStepDuration); guardCount += 1
        }
        let afterFirst = e.hearts
        // Advance a small amount, still within the 0.8s i-frame window.
        e.update(0.1)
        XCTAssertEqual(e.hearts, afterFirst)             // no extra damage
    }

    func test_contact_removes_again_after_iframes_expire() {
        // Spec §10: after i-frames expire, a subsequent contact removes another heart.
        var t = DescentTuning(); t.startHearts = 3
        var e = DescentEngine(layout: Self.room, tuning: t)   // grub (1,1), slime (2,2)
        var guardCount = 0
        while e.hearts == t.startHearts && guardCount < 50 {  // take the first hit
            e.update(e.tuning.enemyStepDuration); guardCount += 1
        }
        XCTAssertEqual(e.hearts, 2)
        XCTAssertTrue(e.isInIFrames)
        // One update past the i-frame window (0.8s): the slime is still on grub's
        // tile (chase from grub's own tile is a no-op), so in this same tick the
        // i-frames lapse and resolveContact lands a fresh hit (which re-arms them).
        e.update(e.tuning.enemyContactIFrames + 0.05)
        XCTAssertEqual(e.hearts, 1)                           // re-hit landed once i-frames lapsed
    }

    func test_interact_on_stairs_wins() {
        // Use a slime-free room so we can reach the stairs safely.
        //   #####
        //   #E.>#
        //   #####
        var e = DescentEngine(layout: ["#####", "#E.>#", "#####"])
        e.setMove(.e); e.update(e.tuning.grubStepDuration)   // (2,1)
        e.setMove(.e); e.update(e.tuning.grubStepDuration)   // (3,1) stairs
        XCTAssertEqual(e.tile(at: e.grub), .stairs)
        e.interact()
        XCTAssertEqual(e.status, .won)
    }

    func test_interact_off_stairs_does_nothing() {
        var e = DescentEngine(layout: ["#####", "#E.>#", "#####"])
        e.interact()
        XCTAssertEqual(e.status, .playing)
    }

    func test_death_when_hearts_reach_zero() {
        // 1-heart tuning + slime adjacent: dies on first contact.
        var t = DescentTuning(); t.startHearts = 1
        var e = DescentEngine(layout: ["#####", "#ES.#", "#####"], tuning: t)
        var guardCount = 0
        while e.status == .playing && guardCount < 50 {
            e.update(e.tuning.enemyStepDuration); guardCount += 1
        }
        XCTAssertEqual(e.status, .dead)
        XCTAssertEqual(e.hearts, 0)
    }

    func test_inputs_are_noops_once_terminal() {
        var e = DescentEngine(layout: ["#####", "#E.>#", "#####"])
        e.setMove(.e); e.update(e.tuning.grubStepDuration)
        e.setMove(.e); e.update(e.tuning.grubStepDuration)   // on stairs
        e.interact()                                          // -> .won
        let frozen = e.grub
        e.setMove(.w); e.update(e.tuning.grubStepDuration)    // ignored
        e.attack()                                            // ignored
        XCTAssertEqual(e.grub, frozen)
        XCTAssertEqual(e.status, .won)
    }
}
