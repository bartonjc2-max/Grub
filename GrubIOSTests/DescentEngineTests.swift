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
}
