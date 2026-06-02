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
}
