import XCTest
@testable import GrubIOS

final class DigSolverTests: XCTestCase {
    func test_the_solver_always_finds_an_easy_spot() {
        for seed in UInt64(1)...100 {
            var rng = BurrowRNG(seed: seed)
            let g = DigGen.make(layer: .loose, condition: nil, rng: &rng)
            XCTAssertTrue(DigSolver.solves(tiles: g.tiles, findTile: g.findTile,
                                           wet: false, strikes: 6),
                          "seed \(seed): loose soil with 6 strikes should always work out")
        }
    }

    func test_the_solver_is_deterministic() {
        var rng = BurrowRNG(seed: 5)
        let g = DigGen.make(layer: .deep, condition: .rooty, rng: &rng)
        let a = DigSolver.solves(tiles: g.tiles, findTile: g.findTile, wet: false, strikes: 3)
        let b = DigSolver.solves(tiles: g.tiles, findTile: g.findTile, wet: false, strikes: 3)
        XCTAssertEqual(a, b)
    }

    func test_one_strike_only_wins_if_it_lands_on_the_find() {
        var tiles = [DigTile](repeating: .soil, count: 25)
        tiles[0] = .root
        XCTAssertFalse(DigSolver.solves(tiles: tiles, findTile: 24, wet: false, strikes: 1))
    }
}
