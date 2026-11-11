import XCTest
@testable import GrubIOS

final class DigTypesTests: XCTestCase {
    func test_manhattan_distance_on_the_5x5_grid() {
        XCTAssertEqual(DigGrid.distance(0, 0), 0)
        XCTAssertEqual(DigGrid.distance(0, 1), 1)       // same row, next column
        XCTAssertEqual(DigGrid.distance(0, 5), 1)       // next row, same column
        XCTAssertEqual(DigGrid.distance(0, 6), 2)       // diagonal
        XCTAssertEqual(DigGrid.distance(0, 24), 8)      // opposite corners
    }

    func test_the_find_tile_itself_reads_hot() {
        // `strike` emits `.tileBroken` for the winning tile too, so d == 0 needs an answer.
        XCTAssertEqual(DigGrid.heat(distance: 0, wet: false), .hot)
        XCTAssertEqual(DigGrid.heat(distance: 0, wet: true), .hot)
    }

    func test_heat_from_distance() {
        XCTAssertEqual(DigGrid.heat(distance: 1, wet: false), .hot)
        XCTAssertEqual(DigGrid.heat(distance: 2, wet: false), .warm)
        XCTAssertEqual(DigGrid.heat(distance: 3, wet: false), .cold)
        XCTAssertEqual(DigGrid.heat(distance: 8, wet: false), .cold)
    }

    func test_wet_hides_warm_but_not_hot() {
        XCTAssertEqual(DigGrid.heat(distance: 1, wet: true), .hot)
        XCTAssertEqual(DigGrid.heat(distance: 2, wet: true), .cold, "wet reads warm as cold")
    }

    func test_a_dig_tile_round_trips_through_json() throws {
        let tiles: [DigTile] = [.soil, .root, .broken, .rock(hp: 2), .rock(hp: 1)]
        let data = try JSONEncoder().encode(tiles)
        XCTAssertEqual(try JSONDecoder().decode([DigTile].self, from: data), tiles)
    }
}
