import Foundation

/// Builds dig grids. The only place a grid is created — `bury`, `BurrowSave.fresh` and the
/// v1→v2 migration all come through here, so a grid is generated exactly once and then saved.
enum DigGen {
    struct Result: Equatable {
        var tiles: [DigTile]
        var findTile: Int
        /// True when the clue constraint forced obstacles to be dropped (see `make`).
        var usedFallback: Bool
    }

    static let maxAttempts = 40

    /// Spec §1 "Grid generation". RNG draw order is part of the contract.
    static func make(layer: SoilLayer, condition: DigCondition?,
                     rng: inout some RandomNumberGenerator) -> Result {
        let findTile = Int.random(in: 0..<DigGrid.tileCount, using: &rng)
        let rocks = layer.rocks + (condition == .rocky ? 3 : 0)
        let roots = layer.roots + (condition == .rooty ? 3 : 0)

        for _ in 0..<maxAttempts {
            var tiles = place(rocks: rocks, roots: roots, findTile: findTile, rng: &rng)
            applyGlint(&tiles, findTile: findTile, condition: condition, rng: &rng)
            if hasEnoughClues(tiles, findTile: findTile, wet: condition == .wet) {
                return Result(tiles: tiles, findTile: findTile, usedFallback: false)
            }
        }

        // Deterministic fallback: drop obstacles one at a time until the grid is readable.
        // It always terminates — with no obstacles, even a corner find has 5 tiles at d ≤ 2
        // and 2 at d == 1.
        var r = rocks, t = roots
        while true {
            if t > 0 { t -= 1 } else if r > 0 { r -= 1 }
            var tiles = place(rocks: r, roots: t, findTile: findTile, rng: &rng)
            applyGlint(&tiles, findTile: findTile, condition: condition, rng: &rng)
            if hasEnoughClues(tiles, findTile: findTile, wet: condition == .wet) || (r == 0 && t == 0) {
                return Result(tiles: tiles, findTile: findTile, usedFallback: true)
            }
        }
    }

    /// Spec §1 "Conditions": none 40 %, then wet / rocky / rooty / glinting at 15 % each.
    static func rollCondition(rng: inout some RandomNumberGenerator) -> DigCondition? {
        let r = Int.random(in: 0..<100, using: &rng)
        switch r {
        case ..<40: return nil
        case ..<55: return .wet
        case ..<70: return .rocky
        case ..<85: return .rooty
        default:    return .glinting
        }
    }

    /// Roots never cover the find; rocks may (that is rocky's cost).
    private static func place(rocks: Int, roots: Int, findTile: Int,
                              rng: inout some RandomNumberGenerator) -> [DigTile] {
        var tiles = [DigTile](repeating: .soil, count: DigGrid.tileCount)
        var free = Array(0..<DigGrid.tileCount).filter { $0 != findTile }
        free.shuffle(using: &rng)

        for _ in 0..<roots where !free.isEmpty {
            tiles[free.removeLast()] = .root
        }
        // Rocks may land on the find, so put it back in the pool first.
        var rockPool = free + [findTile]
        rockPool.shuffle(using: &rng)
        for _ in 0..<rocks where !rockPool.isEmpty {
            tiles[rockPool.removeLast()] = .rock(hp: 2)
        }
        return tiles
    }

    private static func applyGlint(_ tiles: inout [DigTile], findTile: Int,
                                   condition: DigCondition?,
                                   rng: inout some RandomNumberGenerator) {
        guard condition == .glinting else { return }
        func eligible(_ d: Int) -> [Int] {
            tiles.indices.filter {
                $0 != findTile && tiles[$0].isDiggable && DigGrid.distance($0, findTile) == d
            }
        }
        let pool = eligible(2).isEmpty ? eligible(1) : eligible(2)
        guard let pick = pool.randomElement(using: &rng) else { return }
        tiles[pick] = .broken        // a rock here breaks fully, per the spec
    }

    /// At least 4 diggable tiles within d ≤ 2 of the find, and on a wet spot at least 2 of
    /// them at d == 1 (because d == 2 reads as cold there).
    private static func hasEnoughClues(_ tiles: [DigTile], findTile: Int, wet: Bool) -> Bool {
        let near = tiles.indices.filter {
            $0 != findTile && tiles[$0].isDiggable && DigGrid.distance($0, findTile) <= 2
        }
        guard near.count >= 4 else { return false }
        guard wet else { return true }
        return near.filter { DigGrid.distance($0, findTile) == 1 }.count >= 2
    }
}
