import XCTest
@testable import GrubIOS

/// A wet-aware greedy player. `DigSolver` deliberately ignores wetness when scoring its next
/// move (simplification 1 in its doc comment), which makes it play wet spots far worse than a
/// person who has noticed that warm tiles read cold there. The shipped solver is pinned by the
/// spec because the pacing figures depend on it, so the wet-aware variant lives here, in the
/// test target, purely to measure wet spots fairly.
enum WetAwareSolver {
    static func solves(tiles: [DigTile], findTile: Int, wet: Bool, strikes: Int) -> Bool {
        var tiles = tiles
        var left = strikes
        var candidates = Set(tiles.indices.filter { tiles[$0] != .root })
        while left > 0 {
            var best: (Double, Int)?
            for t in tiles.indices where tiles[t].isDiggable {
                let s = elimination(tile: t, candidates: candidates, wet: wet) / Double(tiles[t].cost)
                if best == nil || s > best!.0 + 1e-9 { best = (s, t) }
            }
            guard let pick = best?.1 else { return false }
            let cost = tiles[pick].cost
            if cost > left { return false }
            left -= cost
            tiles[pick] = .broken
            if pick == findTile { return true }
            candidates.remove(pick)
            let h = DigGrid.heat(distance: DigGrid.distance(pick, findTile), wet: wet)
            candidates = candidates.filter { DigGrid.heat(distance: DigGrid.distance(pick, $0), wet: wet) == h }
        }
        return false
    }

    private static func elimination(tile: Int, candidates: Set<Int>, wet: Bool) -> Double {
        guard !candidates.isEmpty else { return 0 }
        var buckets: [Heat: Int] = [:]
        for c in candidates where c != tile {
            buckets[DigGrid.heat(distance: DigGrid.distance(tile, c), wet: wet), default: 0] += 1
        }
        let n = Double(candidates.count)
        return n - buckets.values.reduce(0.0) { $0 + Double($1) * Double($1) } / n
    }
}

/// How often a greedy player finds the item, for every layer × condition.
/// Both solvers are pessimistic — they never read the glinting freebie, and they'll spend a
/// last strike on a 2-hit rock — so these are a floor, not an average player.
final class DigBalanceTests: XCTestCase {
    /// A spot in each layer, so `tripStrikes` reads the right strike count.
    func spotFor(_ layer: SoilLayer) -> Int {
        switch layer {
        case .loose: return 1
        case .clay:  return 0
        case .deep:  return 3
        }
    }

    func rate(_ layer: SoilLayer, _ condition: DigCondition?, wetAware: Bool) -> Double {
        var wins = 0
        let trials = 400
        for seed in UInt64(1)...UInt64(trials) {
            var rng = BurrowRNG(seed: seed)
            let g = DigGen.make(layer: layer, condition: condition, rng: &rng)
            var s = BurrowSave.fresh(now: Date())
            s.stage = .larva
            s.buried = [BuriedFind(spot: spotFor(layer), kind: .berry, condition: condition,
                                   findTile: g.findTile, tiles: g.tiles)]
            let strikes = BurrowRules.tripStrikes(s, spot: spotFor(layer))
            let won = wetAware
                ? WetAwareSolver.solves(tiles: g.tiles, findTile: g.findTile,
                                        wet: condition == .wet, strikes: strikes)
                : DigSolver.solves(tiles: g.tiles, findTile: g.findTile,
                                   wet: condition == .wet, strikes: strikes)
            if won { wins += 1 }
        }
        return Double(wins) / Double(trials)
    }

    func test_no_dry_combination_is_hopeless() {
        var worst: (String, Double) = ("", 1)
        for layer in SoilLayer.allCases {
            for condition in [nil] + DigCondition.allCases.map(Optional.init) where condition != .wet {
                let r = rate(layer, condition, wetAware: false)
                print("BALANCE \(layer) \(condition.map(\.rawValue) ?? "plain"): \(Int(r * 100))%")
                if r < worst.1 { worst = ("\(layer)/\(condition?.rawValue ?? "plain")", r) }
            }
        }
        XCTAssertGreaterThan(worst.1, 0.70, "worst combination is \(worst.0)")
    }

    /// Measured with the wet-aware player, because the shipped solver can't read a wet grid.
    /// With it, the three wet combinations score 86–100 %; the blind solver scores 68–74 %,
    /// which says more about the solver than the spot.
    func test_wet_spots_are_fair_to_a_player_who_reads_them() {
        var worst: (String, Double) = ("", 1)
        for layer in SoilLayer.allCases {
            let r = rate(layer, .wet, wetAware: true)
            let blind = rate(layer, .wet, wetAware: false)
            print("BALANCE \(layer) wet: \(Int(r * 100))% (blind solver: \(Int(blind * 100))%)")
            if r < worst.1 { worst = ("\(layer)/wet", r) }
        }
        XCTAssertGreaterThan(worst.1, 0.80, "worst wet layer is \(worst.0)")
    }
}
