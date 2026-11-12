import Foundation

/// Where one dig site currently is: its design column, its soil layer, and how far down that
/// layer's band it sits (`t`, 0 = top of the band, 1 = bottom).
///
/// Resolving against the layout rather than a fixed row offset is what keeps a spot inside
/// its layer on every screen; fixed offsets overflowed the much shorter iPad burrow.
struct SpotPlacement: Codable, Equatable {
    var x: Int
    var layer: SoilLayer
    var t: Double
}

/// The eight dig sites.
///
/// They used to be a frozen table, which meant the DIG page looked identical every session.
/// A placement now lives in the save and is **re-rolled whenever that spot is used again**,
/// so the soil face changes as the burrow is worked. The index is still the identity —
/// `BuriedFind.spot` and `BurrowSave.holes` are indices, and that has not changed — but
/// where the index points to has stopped being a constant.
///
/// This became possible when DIG got its own page. The old table had both deep spots jammed
/// against the outer edges because the chamber took design columns 14..<50 and the side rooms
/// 3..<15 and 46..<60; on the dig page there is nothing but soil, so a spot may go anywhere
/// the HUD does not cover.
enum BurrowSpots {
    /// Leftmost and rightmost column a site may sit on. A site is `MarkerArt.siteWidth` wide
    /// and centred on its column, so this keeps the whole mound on the design grid.
    static let xRange = 6...57
    /// Minimum gap between two sites **in the same layer**. Different layers are bands apart
    /// vertically, so only same-band neighbours can collide.
    static let minGap = 13
    /// How many sites each layer carries. Deep gets fewer: its band is the shortest once the
    /// HUD has taken the bottom of the screen.
    static let perLayer: [(SoilLayer, Int)] = [(.loose, 3), (.clay, 3), (.deep, 2)]

    /// A fresh map. Each layer's sites are spaced along the band so no two mounds touch, and
    /// `t` is jittered so the row is never the same twice either.
    static func generate(rng: inout some RandomNumberGenerator) -> [SpotPlacement] {
        var out: [SpotPlacement] = []
        for (layer, count) in perLayer {
            var xs: [Int] = []
            // Walk the band left to right handing out a slot at a time, so spacing is a
            // property of the construction rather than something to reject-sample for.
            let span = xRange.upperBound - xRange.lowerBound
            let slack = max(0, span - (count - 1) * minGap)
            var cursor = xRange.lowerBound + Int.random(in: 0...max(0, slack / count), using: &rng)
            for _ in 0..<count {
                xs.append(min(xRange.upperBound, cursor))
                cursor += minGap + Int.random(in: 0...max(0, slack / count), using: &rng)
            }
            for x in xs {
                out.append(SpotPlacement(x: x, layer: layer,
                                         t: Double(Int.random(in: 15...85, using: &rng)) / 100))
            }
        }
        return out
    }

    /// Re-roll one site: new column, new depth in its band, and sometimes a different band.
    ///
    /// A band is taken by **trading** with another site rather than picked freely. Picking
    /// freely let the 3 / 3 / 2 mix random-walk — a few moves in it was 4 clay and 1 deep —
    /// and that mix is not decoration: it is the food/decor balance and the difficulty curve,
    /// measured at 67.5 % food overall and tuned against the stat pacing. A trade keeps the
    /// counts exact while still letting the map change depth over a game.
    static func reroll(_ spot: Int, in all: inout [SpotPlacement],
                       rng: inout some RandomNumberGenerator) {
        guard all.indices.contains(spot) else { return }
        if Int.random(in: 0..<2, using: &rng) == 0 {
            let others = all.indices.filter { $0 != spot && all[$0].layer != all[spot].layer }
            if let o = others.randomElement(using: &rng) {
                // Via locals: `swap(&all[i], &all[j])` is two overlapping exclusive accesses
                // to the same array and Swift will not have it.
                let mine = all[spot].layer
                all[spot].layer = all[o].layer
                all[o].layer = mine
                // The traded site is now in a band it was not spaced for, so it moves too.
                place(o, in: &all, rng: &rng)
            }
        }
        place(spot, in: &all, rng: &rng)
    }

    /// Give one site a column and a depth, as clear of its band-mates as a dozen tries can
    /// manage. Best-effort rather than exhaustive: a band holding three sites can be genuinely
    /// tight, and a site that refuses to move is worse than one that lands a little close.
    private static func place(_ spot: Int, in all: inout [SpotPlacement],
                              rng: inout some RandomNumberGenerator) {
        let layer = all[spot].layer
        let taken = all.indices.filter { $0 != spot && all[$0].layer == layer }.map { all[$0].x }
        var bestX = all[spot].x, bestGap = -1
        for _ in 0..<12 {
            let x = Int.random(in: xRange, using: &rng)
            let gap = taken.map { abs($0 - x) }.min() ?? Int.max
            if gap > bestGap { bestGap = gap; bestX = x }
            if bestGap >= minGap { break }
        }
        all[spot] = SpotPlacement(x: bestX, layer: layer,
                                  t: Double(Int.random(in: 15...85, using: &rng)) / 100)
    }

    /// The map a save written before placements existed is treated as having. Keeping the old
    /// table here means an existing burrow looks exactly as it did on the update that ships
    /// this, and only starts moving as its spots are used.
    static let fallback: [SpotPlacement] = [
        SpotPlacement(x: 6,  layer: .clay,  t: 0.30),
        SpotPlacement(x: 39, layer: .loose, t: 0.55),
        SpotPlacement(x: 59, layer: .loose, t: 0.80),
        SpotPlacement(x: 10, layer: .deep,  t: 0.15),
        SpotPlacement(x: 20, layer: .loose, t: 0.25),
        SpotPlacement(x: 5,  layer: .clay,  t: 0.75),
        SpotPlacement(x: 62, layer: .clay,  t: 0.50),
        SpotPlacement(x: 61, layer: .deep,  t: 0.45),
    ]

    /// The site's cell in **design** space.
    ///
    /// Do **not** add `L.x0` here. Both consumers add it themselves: `L.point(dx, dy)`
    /// computes `originX + (x0 + dx) * cell`, and the backdrop's `r()` helper fills at
    /// `L.x0 + x`. Returning bitmap coordinates would shift every marker and hole right by
    /// `x0` — which is 0 on most sizes and 2 on the SE, so it would survive a casual look.
    static func resolve(_ p: SpotPlacement, _ L: BurrowLayout) -> (x: Int, y: Int) {
        let band = L.rows(for: p.layer)
        let span = max(1, band.count - 1)
        let y = band.lowerBound + Int((Double(span) * p.t).rounded())
        // The bottom panel covers the lower rows, and a site under it can be neither seen nor
        // tapped. Clamping here rather than in the generator keeps the map screen-independent.
        return (p.x, max(band.lowerBound, min(y, min(band.upperBound - 1, L.hudTopRow - 3))))
    }

    /// Centre column of the mound drawn at a site. A mound sliced by the bezel stops reading
    /// as a mound at all — the dome and its cast shadow are the whole affordance — so the art
    /// clamps even though the site itself does not move.
    static func markerCentre(_ p: SpotPlacement, _ L: BurrowLayout, width: Int) -> Double {
        let half = Double(width) / 2
        return min(Double(BurrowLayout.designCols) - half, max(half, Double(p.x) + 0.5))
    }
}
