import Foundation

/// A deterministic greedy player, used by the pacing test and the balance sim — never by the
/// game. Spec §6 pins its behaviour, because the pacing figures depend on it.
///
/// **Three deliberate simplifications**, all pessimistic — don't "fix" them without
/// re-measuring the pacing numbers that depend on them:
///
/// 1. `expectedElimination` ignores wetness when bucketing, so on a wet spot the solver
///    over-estimates how much a d = 2 strike tells it.
/// 2. The candidate set starts as every non-root tile, including glinting's already-broken
///    one, and the solver never reads that free clue.
/// 3. `choose` can pick a 2-cost rock with 1 strike left and forfeit the trip.
enum DigSolver {
    /// Would a player who always makes the locally best move find the item in `strikes`?
    static func solves(tiles: [DigTile], findTile: Int, wet: Bool, strikes: Int) -> Bool {
        play(tiles: tiles, findTile: findTile, wet: wet, strikes: strikes).found
    }

    /// The tiles it strikes, in order, and whether the last one was the find.
    ///
    /// **A losing trip still returns its strikes.** Broken tiles stay broken between trips
    /// (spec §1 "Ending a trip"), so a caller that applies the moves only on a win leaves the
    /// grid untouched after a failure — and then replays the identical losing trip forever,
    /// because this solver is deterministic. The pacing sim hit exactly that.
    static func play(tiles: [DigTile], findTile: Int, wet: Bool,
                     strikes: Int) -> (moves: [Int], found: Bool) {
        var tiles = tiles
        var left = strikes
        var struck: [Int] = []
        // Every tile that could still hold the find, given what has been revealed.
        var candidates = Set(tiles.indices.filter { tiles[$0] != .root })

        while left > 0 {
            guard let pick = choose(tiles: tiles, candidates: candidates) else { return (struck, false) }
            let cost = tiles[pick].cost
            if cost > left { return (struck, false) }
            left -= cost
            // One entry per strike, so a 2-hp rock appears twice.
            struck.append(contentsOf: Array(repeating: pick, count: cost))
            tiles[pick] = .broken
            if pick == findTile { return (struck, true) }
            candidates.remove(pick)
            // Keep only the candidates consistent with the heat just revealed.
            let heat = DigGrid.heat(distance: DigGrid.distance(pick, findTile), wet: wet)
            candidates = candidates.filter {
                DigGrid.heat(distance: DigGrid.distance(pick, $0), wet: wet) == heat
            }
        }
        return (struck, false)
    }

    /// Highest (expected candidates eliminated ÷ strike cost); ties go to the lowest index.
    private static func choose(tiles: [DigTile], candidates: Set<Int>) -> Int? {
        var best: (score: Double, tile: Int)?
        for tile in tiles.indices where tiles[tile].isDiggable {
            let score = expectedElimination(tile: tile, candidates: candidates)
                      / Double(tiles[tile].cost)
            if best == nil || score > best!.score + 1e-9 {
                best = (score, tile)
            }
        }
        return best?.tile
    }

    /// Averaged over the candidates, each equally likely to hold the find.
    ///
    /// `tile` itself is excluded from the buckets: with probability 1/n it *is* the find, and
    /// then the dig ends with nothing left to search. Without that term a tile can never score
    /// for being the find, so once one candidate remains every move scores zero and the solver
    /// spends the rest of the trip striking tile 0 instead of digging the thing up.
    private static func expectedElimination(tile: Int, candidates: Set<Int>) -> Double {
        guard !candidates.isEmpty else { return 0 }
        var buckets: [Heat: Int] = [:]
        for c in candidates where c != tile {
            buckets[DigGrid.heat(distance: DigGrid.distance(tile, c), wet: false), default: 0] += 1
        }
        let n = Double(candidates.count)
        // Expected size of the surviving bucket, weighted by the chance of landing in it.
        let expectedRemaining = buckets.values.reduce(0.0) { $0 + Double($1) * Double($1) } / n
        return n - expectedRemaining
    }
}
