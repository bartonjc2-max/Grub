import Foundation

/// One step of a crawl, in **design** space — the same space as `BurrowSpots.resolve` and
/// `CellRect`. Nothing here adds `L.x0`; the view does that when it draws.
struct Waypoint: Equatable {
    let x: Int
    let y: Int
}

/// The route the grub crawls from its chamber to a dig spot.
///
/// A hand-written set of tunnel routes rather than a pathfinder: there are eight spots and
/// four tunnels, and a graph search would be more code to read and no more correct. The nodes
/// follow the tunnels `BurrowArt.backdrop` actually carves, so the grub stays in open ground
/// until the final leg — which is a deliberate burrow through soil to reach the find.
enum BurrowWaypoints {
    /// Longest leg the crawl will take in one step, in design cells. Legs are subdivided to
    /// this, so the animation can walk the list at a steady pace without lurching.
    static let maxStep = 10

    static func path(to spot: Int, _ L: BurrowLayout) -> [Waypoint] {
        let p = BurrowSpots.resolve(spot, L)
        let target = Waypoint(x: p.x, y: p.y)

        // Walk every route and keep the prefix whose last node is nearest the spot. A spot
        // beside the chamber keeps just the chamber itself, and burrows straight out.
        var best: [Waypoint] = [home(L)]
        var bestDistance = Int.max
        for route in routes(L) {
            for i in route.indices {
                let d = distance(route[i], target)
                if d < bestDistance {
                    bestDistance = d
                    best = Array(route[0...i])
                }
            }
        }
        return subdivide(best + [target])
    }

    /// Where the grub stands in its chamber.
    static func home(_ L: BurrowLayout) -> Waypoint {
        Waypoint(x: L.chamber.midX, y: L.chamber.maxY - 3)
    }

    /// The tunnels, as the backdrop carves them. Every route starts in the chamber.
    private static func routes(_ L: BurrowLayout) -> [[Waypoint]] {
        let C = L.chamber, S = L.surface
        let start = home(L)

        // Up the drop shaft (design columns 30…34) into the crawl tunnel (rows S+9…S+13).
        let chamberTop = Waypoint(x: 32, y: C.y + 1)
        let crawlRight = Waypoint(x: 32, y: S + 11)
        let crawlLeft  = Waypoint(x: 8,  y: S + 11)
        let shaftTop   = Waypoint(x: 8,  y: S + 2)

        // Out of the chamber's right wall, then down to the right side-room.
        let rightMouth = Waypoint(x: C.maxX + 1, y: C.y + 14)
        let rightBend  = Waypoint(x: 58, y: C.y + 14)
        let rightRoom  = Waypoint(x: L.sideR.midX, y: L.sideR.y + 5)

        // Down from the chamber floor, then left into the left side-room.
        let leftMouth  = Waypoint(x: 24, y: C.maxY + 1)
        let leftBend   = Waypoint(x: 24, y: L.sideL.y + 5)
        let leftRoom   = Waypoint(x: L.sideL.midX, y: L.sideL.y + 5)

        return [
            [start, chamberTop, crawlRight, crawlLeft, shaftTop],
            [start, rightMouth, rightBend, rightRoom],
            [start, leftMouth, leftBend, leftRoom],
        ]
    }

    private static func distance(_ a: Waypoint, _ b: Waypoint) -> Int {
        abs(a.x - b.x) + abs(a.y - b.y)
    }

    /// Break any leg longer than `maxStep` into equal pieces, so the crawl animates evenly.
    private static func subdivide(_ points: [Waypoint]) -> [Waypoint] {
        guard points.count > 1 else { return points }
        var out = [points[0]]
        for i in 1..<points.count {
            let a = points[i - 1], b = points[i]
            let steps = max(1, (distance(a, b) + maxStep - 1) / maxStep)
            for k in 1...steps {
                let t = Double(k) / Double(steps)
                out.append(Waypoint(x: a.x + Int((Double(b.x - a.x) * t).rounded()),
                                    y: a.y + Int((Double(b.y - a.y) * t).rounded())))
            }
        }
        return out
    }
}
