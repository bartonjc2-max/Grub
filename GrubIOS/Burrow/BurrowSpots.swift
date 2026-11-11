import Foundation

/// The fixed places where finds get buried (spec §1: 8 spots in open soil).
/// Index = `BuriedFind.spot` = `BurrowSave.holes` entry. **Order is part of the save
/// format: append new spots, never reorder.**
///
/// A spot is defined by its design column, its soil layer, and how far down that layer's
/// band it sits (`t`, 0 = top of the band, 1 = bottom). Resolving against the layout rather
/// than a fixed row offset is what keeps a spot inside its layer on every screen — fixed
/// offsets overflowed the much shorter iPad burrow.
///
/// **Why the two deep spots hug the edges.** On iPad the burrow is only ~92 rows, so the
/// chamber (design columns 14..<50) swallows the top two thirds of the deep band; on the SE
/// the bottom panel covers the deep band below about `t = 0.5`. Between them a deep spot has
/// to sit at a shallow `t` *and* clear of every room's columns — and the side rooms take
/// 3..<15 and 46..<60, which leaves the two outer edges.
enum BurrowSpots {
    struct Spot {
        let x: Int           // design column, 0..<64
        let layer: SoilLayer
        let t: Double        // 0...1 down the layer's band
    }

    static let spots: [Spot] = [
        Spot(x: 6,  layer: .clay,  t: 0.30),   // 0  left of the chamber
        Spot(x: 39, layer: .loose, t: 0.55),   // 1  upper soil, middle
        Spot(x: 59, layer: .loose, t: 0.80),   // 2  upper soil, right edge
        Spot(x: 10, layer: .deep,  t: 0.15),   // 3  deep soil, under the chamber's left wall
        Spot(x: 20, layer: .loose, t: 0.25),   // 4  upper soil, above the crawl tunnel
        Spot(x: 5,  layer: .clay,  t: 0.75),   // 5  far left, above the left side-room
        Spot(x: 62, layer: .clay,  t: 0.50),   // 6  far right, beside the right connector
        Spot(x: 61, layer: .deep,  t: 0.45),   // 7  deep soil, right of the right side-room
    ]

    static func layer(_ spot: Int) -> SoilLayer { spots[spot].layer }

    /// The spot's cell in **design** space — the same space `BurrowLayout.resolve(_:)`
    /// returned, and the space `CellRect` (chamber, side rooms) uses.
    ///
    /// Do **not** add `L.x0` here. Both consumers add it themselves: `L.point(dx, dy)`
    /// computes `originX + (x0 + dx) * cell`, and `backdrop`'s `r()` helper fills at
    /// `L.x0 + x`. Returning bitmap coordinates would shift every marker and hole right by
    /// `x0` — which is 0 on most sizes and 2 on the SE, so it would survive a casual look.
    static func resolve(_ spot: Int, _ L: BurrowLayout) -> (x: Int, y: Int) {
        let s = spots[spot]
        let band = L.rows(for: s.layer)
        let span = max(1, band.count - 1)
        let y = band.lowerBound + Int((Double(span) * s.t).rounded())
        return (s.x, min(y, band.upperBound - 1))
    }
}
