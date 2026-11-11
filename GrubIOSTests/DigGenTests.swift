import XCTest
@testable import GrubIOS

final class DigGenTests: XCTestCase {
    func grid(_ layer: SoilLayer, _ condition: DigCondition?, seed: UInt64 = 1) -> DigGen.Result {
        var rng = BurrowRNG(seed: seed)
        return DigGen.make(layer: layer, condition: condition, rng: &rng)
    }

    func test_a_grid_has_25_tiles_and_a_find_that_is_not_under_a_root() {
        for seed in UInt64(1)...60 {
            for layer in SoilLayer.allCases {
                let g = grid(layer, nil, seed: seed)
                XCTAssertEqual(g.tiles.count, DigGrid.tileCount)
                XCTAssertTrue((0..<DigGrid.tileCount).contains(g.findTile))
                XCTAssertNotEqual(g.tiles[g.findTile], .root, "seed \(seed) \(layer)")
            }
        }
    }

    func test_layers_place_their_obstacles() {
        for seed in UInt64(1)...60 {
            let loose = grid(.loose, nil, seed: seed)
            XCTAssertEqual(loose.tiles.filter(\.isObstacle).count, 0, "loose soil is clear")

            let clay = grid(.clay, nil, seed: seed)
            if !clay.usedFallback {
                XCTAssertEqual(clay.tiles.filter { $0.isRock }.count, 3, "seed \(seed)")
            } else {
                XCTAssertLessThanOrEqual(clay.tiles.filter { $0.isRock }.count, 3)
            }

            let deep = grid(.deep, nil, seed: seed)
            if !deep.usedFallback {
                XCTAssertEqual(deep.tiles.filter { $0 == .root }.count, 3, "seed \(seed)")
            }
        }
    }

    func test_conditions_add_their_obstacles() {
        for seed in UInt64(1)...60 {
            let rocky = grid(.clay, .rocky, seed: seed)
            if !rocky.usedFallback {
                XCTAssertEqual(rocky.tiles.filter { $0.isRock }.count, 6, "3 from clay + 3 from rocky")
            }
            let rooty = grid(.deep, .rooty, seed: seed)
            if !rooty.usedFallback {
                XCTAssertEqual(rooty.tiles.filter { $0 == .root }.count, 6)
            }
        }
    }

    func test_glinting_reveals_one_tile_that_is_not_the_find() {
        for seed in UInt64(1)...60 {
            let g = grid(.clay, .glinting, seed: seed)
            let broken = g.tiles.indices.filter { g.tiles[$0] == .broken }
            XCTAssertEqual(broken.count, 1, "seed \(seed)")
            XCTAssertNotEqual(broken[0], g.findTile)
            XCTAssertLessThanOrEqual(DigGrid.distance(broken[0], g.findTile), 2)
        }
    }

    func test_every_grid_leaves_enough_clues_to_read() {
        for seed in UInt64(1)...200 {
            for layer in SoilLayer.allCases {
                for condition in [nil] + DigCondition.allCases.map(Optional.init) {
                    let g = grid(layer, condition, seed: seed)
                    let near = g.tiles.indices.filter {
                        $0 != g.findTile && g.tiles[$0].isDiggable && DigGrid.distance($0, g.findTile) <= 2
                    }
                    XCTAssertGreaterThanOrEqual(near.count, 4,
                        "seed \(seed) \(layer) \(String(describing: condition)): only \(near.count) clues")
                    if condition == .wet {
                        let hot = near.filter { DigGrid.distance($0, g.findTile) == 1 }
                        XCTAssertGreaterThanOrEqual(hot.count, 2, "wet needs hot tiles; seed \(seed)")
                    }
                }
            }
        }
    }

    func test_conditions_roll_at_the_spec_odds() {
        var rng = BurrowRNG(seed: 3)
        var counts: [DigCondition?: Int] = [:]
        let n = 2000
        for _ in 0..<n { counts[DigGen.rollCondition(rng: &rng), default: 0] += 1 }
        XCTAssertEqual(Double(counts[nil] ?? 0) / Double(n), 0.40, accuracy: 0.04)
        for c in DigCondition.allCases {
            XCTAssertEqual(Double(counts[c] ?? 0) / Double(n), 0.15, accuracy: 0.04, "\(c)")
        }
    }

    func test_generation_is_reproducible() {
        var a = BurrowRNG(seed: 99), b = BurrowRNG(seed: 99)
        let x = DigGen.make(layer: .clay, condition: .rocky, rng: &a)
        let y = DigGen.make(layer: .clay, condition: .rocky, rng: &b)
        XCTAssertEqual(x.tiles, y.tiles)
        XCTAssertEqual(x.findTile, y.findTile)
    }
}

private extension DigTile {
    var isObstacle: Bool { isRock || self == .root }
}
