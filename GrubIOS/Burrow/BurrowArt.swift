import SwiftUI

// MARK: - Layout

struct CellRect: Equatable {
    var x: Int, y: Int, w: Int, h: Int
    var maxX: Int { x + w }
    var maxY: Int { y + h }
    var midX: Int { x + w / 2 }

    /// Design-space hit test.
    func contains(x: Int, y: Int) -> Bool {
        (self.x..<maxX).contains(x) && (self.y..<maxY).contains(y)
    }
}

/// Screen geometry. The burrow is designed on a 64-column grid; each cell is a whole
/// number of device pixels so pixels stay square and seam-free on every iPhone.
struct BurrowLayout: Equatable {
    static let designCols = 64

    let cell: CGFloat     // points per cell
    let cols: Int         // bitmap columns (covers the full screen width)
    let rows: Int
    let x0: Int           // bitmap column where design column 0 sits
    let originX: CGFloat  // screen x of bitmap column 0 (≤ 0, centres the bitmap)
    let surface: Int
    let chamber: CellRect
    let sideL: CellRect
    let sideR: CellRect

    init(size: CGSize, displayScale: CGFloat) {
        let devicePx = max(1, floor(size.width * displayScale / CGFloat(Self.designCols)))
        cell = devicePx / displayScale
        cols = Int(ceil(size.width / cell))
        rows = max(80, Int(ceil(size.height / cell)))
        x0 = (cols - Self.designCols) / 2
        originX = (size.width - CGFloat(cols) * cell) / 2

        surface = Int(Double(rows) * 0.29)
        let hudRows = Int(ceil(176 / cell))                 // bottom panel + home indicator
        let usable = max(48, rows - hudRows - surface)
        let top = surface + Int(Double(usable) * 0.24)
        chamber = CellRect(x: 14, y: top, w: 36, h: 31)
        let gap = max(5, Int(Double(usable) * 0.08))
        sideR = CellRect(x: 46, y: chamber.maxY + gap, w: 14, h: 11)
        sideL = CellRect(x: 3, y: chamber.maxY + gap + 4, w: 12, h: 11)
    }

    /// Screen point (top-left of a cell) for a design-space cell.
    func point(_ dx: Double, _ dy: Double) -> CGPoint {
        CGPoint(x: originX + (CGFloat(x0) + dx) * cell, y: dy * cell)
    }
}

extension BurrowLayout {
    /// Row boundaries of the four soil bands drawn by `BurrowArt.backdrop`.
    /// soil1 = (surface+1 ..< b1), soil2 = (b1 ..< b2), soil3 = (b2 ..< b3), soil4 = (b3 ..< rows).
    var soilBands: (b1: Int, b2: Int, b3: Int) {
        let soil = rows - surface - 1
        let b1 = surface + 1 + Int(Double(soil) * 0.24)
        let b2 = b1 + Int(Double(soil) * 0.27)
        let b3 = b2 + Int(Double(soil) * 0.24)
        return (b1, b2, b3)
    }

    /// First row covered by the bottom panel. The soil bands run to the bottom of the screen,
    /// so the deep band's lower rows sit *behind* the HUD — a spot there can't be seen or
    /// tapped. Same 176pt the initialiser reserves for the panel.
    var hudTopRow: Int { rows - Int(ceil(176 / cell)) }

    /// Spec §1: loose = soil1, clay = soil2, deep = soil3. soil4 holds no spots.
    func rows(for layer: SoilLayer) -> Range<Int> {
        let b = soilBands
        switch layer {
        case .loose: return (surface + 1)..<b.b1
        case .clay:  return b.b1..<b.b2
        case .deep:  return b.b2..<b.b3
        }
    }

    /// The display room on the COLLECTION page — its own space, not the burrow's side rooms.
    /// Those were 12 and 14 cells wide and could show three busts between them; this is 58
    /// wide and shows eight, which is the difference between a shelf and a gallery.
    var gallery: CellRect {
        // A fixed height, centred in what the HUD leaves. Stretching it to fill the screen
        // put the alcoves at the top and the ledge at the bottom with nothing between them.
        let h = min(44, max(28, hudTopRow - 10))
        return CellRect(x: 3, y: max(5, (hudTopRow - h) / 2), w: 58, h: h)
    }

    /// Top-centre cell of decor niche `i`: the 6×2 plinth spans x-3…x+2, rows y…y+1, and the
    /// decor sprite stands on it (its bottom row at y-1). Four alcoves evenly across the
    /// gallery's back wall — they used to be scattered round the chamber floor, competing
    /// with the grub for the same frame.
    func decorSlot(_ i: Int) -> (x: Int, y: Int)? {
        guard (0..<4).contains(i) else { return nil }
        let g = gallery, step = g.w / 4
        return (g.x + step / 2 + i * step, g.y + 14)
    }

    /// Every niche hangs on the gallery wall now, so they all get the bracket plinth.
    func decorIsShelf(_ i: Int) -> Bool { true }

    /// The specimen ledge running across the gallery, and how many busts stand on it. Each is
    /// 5 cells wide with a cell of air; the rest of the collection is a tap away.
    var shelf: (y: Int, x0: Int, width: Int) {
        let g = gallery
        return (y: g.maxY - 8, x0: g.x + 2, width: g.w - 4)
    }
    var shelfSlots: Int { max(1, (shelf.width - 2) / 6) }
}

// MARK: - Backdrop (sky, surface, soil, tunnels, decor)

enum BurrowArt {
    /// Each page has its own backdrop.
    ///
    /// One drawing behind all three made the split cosmetic: the busiest picture in the game
    /// was still there on every page and only the foreground moved. These share helpers —
    /// sky, grit, carving — but never a composition. BURROW is a room at night, DIG is a
    /// soil face with no sky at all, COLLECTION is an interior you are standing in.
    static func backdrop(_ page: BurrowPage, _ L: BurrowLayout, holes: [Int],
                         spurs: [Int] = [], spots: [SpotPlacement] = []) -> PixelBuffer {
        switch page {
        case .burrow:     return home(L)
        case .dig:        return strata(L, holes: holes, spurs: spurs,
                                        spots: spots.isEmpty ? BurrowSpots.fallback : spots)
        case .collection: return gallery(L)
        }
    }

    // MARK: Shared pieces

    /// A bitmap addressed in **design** columns, so no caller has to remember `x0`.
    private struct Canvas {
        var b: PixelBuffer
        let L: BurrowLayout
        init(_ L: BurrowLayout) { self.L = L; b = PixelBuffer(width: L.cols, height: L.rows) }
        mutating func r(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ c: UInt32) {
            b.fill(L.x0 + x, y, w, h, c)
        }
        /// Full bitmap width, so a band reaches the bezels on every screen.
        mutating func band(_ y0: Int, _ y1: Int, _ c: UInt32) {
            b.fill(0, y0, L.cols, max(0, y1 - y0), c)
        }
        /// Stroke every boundary between hollow and solid, in one pass over the bitmap.
        ///
        /// Found rather than predicted: a hand-drawn outline has a gap wherever two passages
        /// meet in a way nobody thought of, and that is exactly how the last den failed. One
        /// edge-detect over everything that has been carved gives one continuous rim.
        ///
        /// Hollow above a cell means the cell is a floor catching light; hollow below means
        /// it is a ceiling in its own shadow. That is the whole lighting model, and it is
        /// enough to make a flat cavity read as a room.
        mutating func stroke() {
            typealias I = BurrowInk
            var edges: [(Int, Int, UInt32)] = []
            for y in 1..<(L.rows - 1) {
                for x in 1..<(L.cols - 1) where b.color(x, y) != I.hollow {
                    let up = b.color(x, y - 1) == I.hollow
                    let down = b.color(x, y + 1) == I.hollow
                    guard up || down || b.color(x - 1, y) == I.hollow
                            || b.color(x + 1, y) == I.hollow else { continue }
                    edges.append((x, y, up ? I.root : (down ? I.shade : I.soil3)))
                }
            }
            // Collected first: written as it goes, the pass would read its own output and
            // thicken every edge into a smear.
            for (x, y, c) in edges { b.fill(x, y, 1, 1, c) }
        }

        /// A space with a bevelled edge, so a room reads as dug rather than stamped out.
        mutating func carve(_ c: CellRect, bevel v: Int, _ ink: UInt32 = BurrowInk.hollow) {
            r(c.x, c.y, c.w, c.h, ink)
            r(c.x + v, c.y - v, c.w - 2 * v, v, ink)
            r(c.x + v, c.maxY, c.w - 2 * v, v, ink)
            r(c.x - v, c.y + 2 * v, v, c.h - 4 * v, ink)
            r(c.maxX, c.y + 2 * v, v, c.h - 4 * v, ink)
        }
    }

    /// Deterministic noise — the burrow must never shimmer between launches.
    private struct Noise {
        var seed: UInt32 = 0x9e37_79b9
        mutating func next(_ n: Int) -> Int {
            seed = seed &* 1_664_525 &+ 1_013_904_223
            return Int(seed >> 8) % max(1, n)
        }
    }

    private static func sky(_ c: inout Canvas, height S: Int) {
        c.band(0, S, BurrowInk.sky)
        let hero = [(6, 5), (19, 22), (33, 4), (52, 24), (68, 5), (79, 21),
                    (97, 12), (103, 24), (11, 14), (88, 27), (42, 13)]
        for (hx, hy) in hero {
            c.r(Int(Double(hx) / 108 * 64),
                3 + Int(Double(hy) / 30 * Double(max(10, S - 10))), 1, 1, BurrowInk.teal)
        }
    }

    private static func moon(_ c: inout Canvas, at my: Int) {
        typealias I = BurrowInk
        let mx = 52
        c.r(mx + 1, my, 6, 1, I.cream); c.r(mx, my + 1, 8, 6, I.cream)
        c.r(mx + 1, my + 7, 6, 1, I.cream)
        c.r(mx + 2, my + 2, 2, 2, I.creamDim); c.r(mx + 5, my + 5, 1, 1, I.creamDim)
    }

    private static func mushrooms(_ c: inout Canvas, on S: Int) {
        typealias I = BurrowInk
        func big(_ x: Int) {
            c.r(x + 3, S - 3, 2, 3, I.cream)
            c.r(x, S - 5, 8, 2, I.mushroom)
            c.r(x + 2, S - 6, 4, 1, I.mushroomHi)
        }
        // Clear of the entrance shaft at columns 6–9: a cap sitting over the mouth of the
        // burrow read as the hole being blocked.
        big(14); big(51)
        c.r(29, S - 2, 1, 2, I.cream); c.r(27, S - 3, 5, 1, I.mushroom)
    }

    // MARK: BURROW — the pet's room at night

    /// Sky, a quiet two-tone earth, and one big chamber with tunnels leaving it. No strata,
    /// no dig spots, no gallery: this page is the animal, and anything else on it competes.
    private static func home(_ L: BurrowLayout) -> PixelBuffer {
        typealias I = BurrowInk
        var c = Canvas(L)
        let S = L.surface, C = L.chamber, split = L.soilBands.b2
        sky(&c, height: S)
        moon(&c, at: max(10, S - 30))
        mushrooms(&c, on: S)
        c.band(S, S + 1, I.surface)
        // Two tones rather than four bands. Depth is the DIG page's job; banding here only
        // drew hard lines across the room the player is meant to be looking at.
        c.band(S + 1, split, I.soil1)
        c.band(split, L.rows, I.soil2)
        var n = Noise()
        for _ in 0..<(L.cols * max(1, L.rows - S) / 95) {
            let y = S + 2 + n.next(max(1, L.rows - S - 2))
            c.b.fill(n.next(L.cols), y, n.next(2) + 1, 1, y < split ? I.speck1 : I.speck2)
        }
        c.r(44, S + 1, 1, 7, I.root); c.r(45, S + 8, 1, 3, I.root); c.r(2, S + 1, 1, 4, I.root)

        // The way in, from the surface. The den's own exits are drawn with it.
        // The shaft stops level with the crawl's floor. One row deeper, it hung below the
        // crawl at the left end and the stroke lit that step, putting an extra lip under the
        // horizontal run that matched nothing else in the tunnel.
        c.r(6, S, 4, 13, I.hollow)                                   // entrance, breaks the surface
        c.r(6, S + 9, 28, 4, I.hollow)                               // crawl
        c.r(30, S + 9, 4, max(0, C.y - (S + 9)), I.hollow)           // drop into the ceiling
        den(&c, C)
        // Last, and over everything that was carved: one pass, one continuous edge.
        c.stroke()
        return c.b
    }

    /// The den: an authored arch, carved and then stroked.
    ///
    /// Rewritten rather than corrected. The previous one computed its walls row by row with
    /// a random wobble, and no amount of tuning the wobble fixed the real problem: the
    /// cavity was pure black against brown with no edge treatment at all, so wherever the
    /// wall stepped the boundary went soft and the steps read as gaps. The shape here is
    /// hand-stepped and symmetric — something you could draw on graph paper — and the edge
    /// is a real stroke found by `Canvas.stroke`, so it cannot have a hole in it.
    private static func den(_ c: inout Canvas, _ C: CellRect) {
        typealias I = BurrowInk
        // Inset from each wall, as a run of rows at each step. Chunky and deliberate: a
        // single-cell jitter is noise at this scale, and two cells is a step you can see.
        let shoulders: [(rows: Int, inset: Int)] =
            [(1, 12), (1, 9), (1, 7), (2, 5), (2, 3), (2, 2), (2, 1)]
        let hem: [(rows: Int, inset: Int)] = [(2, 1), (2, 2), (1, 4)]
        let fixed = (shoulders + hem).reduce(0) { $0 + $1.rows }
        let plan = shoulders + [(max(2, C.h - fixed), 0)] + hem

        var row = C.y
        for step in plan {
            for _ in 0..<step.rows where row < C.maxY {
                c.r(C.x + step.inset, row, C.w - 2 * step.inset, 1, I.hollow)
                row += 1
            }
        }

        // One way in through the ceiling, one way out at floor level. The way out turns down
        // after a few cells and leaves the frame, so it is a passage rather than a stub.
        let mouthY = C.maxY - 5, rows = c.L.rows, shaft = 3
        c.r(shaft, mouthY, C.x + 6 - shaft, 4, I.hollow)
        c.r(shaft, mouthY, 4, rows - mouthY, I.hollow)

        // The floor, laid inside the cavity so the stroke finds its top edge and lights it
        // for free. Its top row is `C.maxY - 1`, which is where `grub()` stands the animal.
        c.r(C.x + 1, C.maxY - 1, C.w - 2, 1, I.soil1)
        c.r(C.x, C.maxY, C.w, 3, I.soil2)
        // Out through the mouth, stopping at the shaft. Carried across it, the floor filled
        // in the very hole the shaft was supposed to be, which is why the corner of the
        // passage looked disconnected: the two legs were there, the turn was plugged.
        c.r(shaft + 4, C.maxY - 1, C.x - 3 - shaft, 1, I.soil1)
        c.r(shaft + 4, C.maxY, C.x - 3 - shaft, 2, I.soil2)
    }

    // MARK: DIG — the soil face

    /// No sky, no chamber, no rooms: soil from the top of the screen to the bottom. The four
    /// layers the entire difficulty model rests on get a lit rim at each boundary, and grit
    /// that thickens with depth, so "deeper is different" reads before a single mound does.
    ///
    /// The band rows are `L.soilBands` untouched, because `BurrowSpots.resolve` places every
    /// mound against them — a prettier spacing here would put the markers in the wrong layer.
    private static func strata(_ L: BurrowLayout, holes: [Int], spurs: [Int],
                               spots: [SpotPlacement]) -> PixelBuffer {
        typealias I = BurrowInk
        var c = Canvas(L)
        let (b1, b2, b3) = L.soilBands
        c.band(0, b1, I.soil1); c.band(b1, b2, I.soil2)
        c.band(b2, b3, I.soil3); c.band(b3, L.rows, I.soil4)
        // A lit rim on top of each layer. One pixel, and it turns four similar browns into
        // four named places.
        for (y, ink) in [(b1, I.speck2), (b2, I.speck3), (b3, I.speck4)] {
            c.band(y, y + 1, ink)
        }
        var n = Noise()
        func fleck(_ y: Int) -> UInt32 {
            if y < b1 { return I.speck1 }
            if y < b2 { return I.speck2 }
            if y < b3 { return I.speck3 }
            return I.speck4
        }
        for _ in 0..<(L.cols * L.rows / 40) {
            let y = n.next(L.rows)
            c.b.fill(n.next(L.cols), y, n.next(2) + 1, 1, fleck(y))
        }
        // Pebbles in the lower two layers — mineral, and a reason the deep soil looks harder.
        for _ in 0..<(L.cols * max(0, L.rows - b2) / 90) {
            let y = b2 + n.next(max(1, L.rows - b2))
            c.b.fill(n.next(L.cols), y, 2, 2, fleck(y))
        }
        // Roots trailing down from a surface that is just off the top of this page.
        for (x, len) in [(8, 9), (23, 5), (44, 12), (52, 6), (61, 8)] {
            c.r(x, 0, 1, len, I.root)
            c.r(x + 1, len, 1, max(1, len / 3), I.root)
        }
        // The fossil, embedded in the clay with its socket shadow.
        let fy = b1 + 4
        c.r(48, fy + 1, 5, 1, I.shade); c.r(47, fy, 1, 3, I.shade); c.r(53, fy, 1, 3, I.shade)
        c.r(48, fy, 5, 1, I.creamDim); c.r(47, fy - 1, 1, 3, I.creamDim)
        c.r(53, fy - 1, 1, 3, I.creamDim)

        // The channel the grub dug on its way to a spot it has visited, capped at 8 cells.
        for spot in Set(spurs) where spots.indices.contains(spot) {
            let p = BurrowSpots.resolve(spots[spot], L)
            for step in 0...8 {
                c.r(p.x - 1, max(0, p.y - 4 - step), 2, 2, I.hollow)
            }
        }
        // Pockets left by digging.
        for spot in holes where spots.indices.contains(spot) {
            let p = BurrowSpots.resolve(spots[spot], L)
            c.r(p.x - 2, p.y - 1, 5, 3, I.hollow)
            c.r(p.x - 1, p.y - 2, 3, 1, I.hollow)
            c.r(p.x - 1, p.y + 2, 3, 1, I.hollow)
        }
        return c.b
    }

    // MARK: COLLECTION — a room you are standing in

    /// An interior, not a cross-section: no sky, packed-earth walls, four alcoves cut into
    /// the back wall for the decor, and a long ledge for the busts. The side rooms this
    /// replaced were 12 and 14 cells wide and held three specimens between them.
    private static func gallery(_ L: BurrowLayout) -> PixelBuffer {
        typealias I = BurrowInk
        var c = Canvas(L)
        let g = L.gallery
        // Solid earth, so the room reads as carved out of the ground rather than floating.
        c.band(0, L.rows, I.soil4)
        var n = Noise()
        for _ in 0..<(L.cols * L.rows / 120) {
            c.b.fill(n.next(L.cols), n.next(L.rows), n.next(2) + 1, 1, I.speck4)
        }
        c.carve(g, bevel: 2, I.soil2)
        c.r(g.x, g.y, g.w, 1, I.root)                    // ceiling rail
        c.r(g.x, g.maxY - 5, g.w, 5, I.soil3)            // floor
        c.r(g.x, g.maxY - 5, g.w, 1, I.root)
        // Alcoves. There is no lighting system — one flat bitmap of hard colours — so the
        // warmth round each mouth is a hand-drawn dither rather than a glow.
        for i in 0..<BurrowRules.decorSlots {
            guard let p = L.decorSlot(i) else { continue }
            c.r(p.x - 5, p.y - 10, 11, 12, I.soil3)
            c.r(p.x - 5, p.y - 10, 11, 1, I.root)
            c.r(p.x - 5, p.y - 9, 1, 11, I.soil2); c.r(p.x + 5, p.y - 9, 1, 11, I.soil2)
            for k in stride(from: -4, through: 4, by: 2) {
                c.r(p.x + k, p.y - 11, 1, 1, I.amberLo)
            }
        }
        // The ledge's shadow; the ledge itself is drawn live, over the specimens.
        let sh = L.shelf
        c.r(sh.x0 - 1, sh.y + 1, sh.width + 2, 1, I.shade)
        return c.b
    }
}

// MARK: - The grub (the round "GRUB" from the 6-species contact sheet)

/// The contact sheet draws GRUB as a 14×18 sprite. This is that design redrawn at 1.5×
/// on the world grid: same round body, short stalk antennae, wide-set square eyes with a
/// top-left glint, tiny mouth, cream highlight and a solid side shade.
enum GrubArt {
    static let width = 21
    static let height = 26

    static func frame(blink: Bool = false, chomp: Bool = false, sulk: Bool = false,
                      body: UInt32 = BurrowInk.teal, shade: UInt32 = 0x37a886) -> PixelBuffer {
        var b = PixelBuffer(width: width, height: height)
        func r(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ c: UInt32) { b.fill(x, y, w, h, c) }
        typealias I = BurrowInk
        let o = 6 // first body row; the antennae sit above it
        // round body: a 20-row pixel oval. The straight edge is only the 6 middle rows, so
        // the sides curve instead of reading as clipped.
        for (y, span) in bodySpans.enumerated() {
            r(span.0, o + y, span.1 - span.0 + 1, 1, body)
        }
        // antennae: stalk, one step outward, white tip
        r(7, o - 3, 1, 3, body); r(6, o - 4, 1, 1, body); r(6, o - 6, 1, 2, I.white)
        r(13, o - 3, 1, 3, body); r(14, o - 4, 1, 1, body); r(14, o - 6, 1, 2, I.white)
        // cream highlight + a crescent side shade that follows the curve (thick at the
        // middle, thin toward top and bottom)
        r(4, o + 2, 3, 1, I.cream)
        for (y, span) in bodySpans.enumerated() {
            let k = shadeDepth[y]
            if k > 0 { r(span.1 - k + 1, o + y, k, 1, shade) }
        }
        // eyes
        if blink {
            r(3, o + 9, 4, 1, I.hollow); r(14, o + 9, 4, 1, I.hollow)
        } else if sulk {
            r(3, o + 8, 4, 2, I.hollow); r(14, o + 8, 4, 2, I.hollow)      // heavy-lidded, no glint
        } else {
            r(3, o + 6, 4, 4, I.hollow); r(14, o + 6, 4, 4, I.hollow)
            r(3, o + 6, 2, 2, I.white); r(14, o + 6, 2, 2, I.white)
        }
        // mouth
        if chomp {
            r(8, o + 12, 5, 3, I.hollow); r(9, o + 14, 3, 1, I.berry)
        } else if sulk {
            r(9, o + 13, 3, 1, I.hollow); r(8, o + 14, 1, 1, I.hollow); r(12, o + 14, 1, 1, I.hollow)  // frown
        } else {
            r(9, o + 13, 3, 1, I.hollow)
        }
        return b
    }

    /// First and last body column for each of the 20 body rows.
    static let bodySpans: [(Int, Int)] = [
        (7, 13), (5, 15), (3, 17), (2, 18), (2, 18), (1, 19), (1, 19),
        (0, 20), (0, 20), (0, 20), (0, 20), (0, 20), (0, 20),
        (1, 19), (1, 19), (2, 18), (2, 18), (3, 17), (5, 15), (7, 13)]
    /// Shade width per body row (right edge).
    static let shadeDepth = [0, 1, 1, 2, 2, 3, 3, 4, 4, 4, 4, 4, 4, 3, 3, 3, 2, 2, 2, 1]

    static let sulk = frame(sulk: true)
    static let idle = frame()
    static let blink = frame(blink: true)
    static let chomp = frame(chomp: true)
}

extension GrubArt {
    struct Frames { let idle, blink, chomp, sulk: PixelBuffer }

    /// Per-channel blend of two 0xRRGGBB colours (`f` = share of `b`), rounded.
    static func mix(_ a: UInt32, _ b: UInt32, _ f: Double) -> UInt32 {
        func ch(_ c: UInt32, _ s: UInt32) -> Double { Double((c >> s) & 0xFF) }
        func out(_ s: UInt32) -> UInt32 { UInt32((ch(a, s) + (ch(b, s) - ch(a, s)) * f).rounded()) << s }
        return out(16) | out(8) | out(0)
    }

    /// Per-channel multiply, rounded.
    static func scale(_ c: UInt32, _ k: Double) -> UInt32 { mix(0x000000, c, k) }

    /// Spec §5: larva body = teal mixed 25 % toward the parent species' colour.
    static func bodyColor(tint: Species?) -> UInt32 {
        guard let t = tint, t != .grub else { return BurrowInk.teal }
        return mix(BurrowInk.teal, t.color, 0.25)
    }

    /// Larva frames for a tint. Untinted (or GRUB) is the original art; otherwise the body
    /// is `bodyColor` and the side shade is the body × 0.82.
    static func frames(tint: Species?) -> Frames { frameCache[tint?.rawValue ?? ""]! }

    private static let frameCache: [String: Frames] = {
        var out: [String: Frames] = ["": Frames(idle: idle, blink: blink, chomp: chomp, sulk: sulk)]
        for sp in Species.allCases {
            if sp == .grub { out[sp.rawValue] = out[""]; continue }
            let body = bodyColor(tint: sp), shade = scale(body, 0.82)
            out[sp.rawValue] = Frames(idle: frame(body: body, shade: shade),
                                      blink: frame(blink: true, body: body, shade: shade),
                                      chomp: frame(chomp: true, body: body, shade: shade),
                                      sulk: frame(sulk: true, body: body, shade: shade))
        }
        return out
    }()
}

// MARK: - Finds + UI icons

extension FindKind {
    /// The same find, in the condition it came out of the ground in. A tier is a treatment
    /// over the one sprite rather than three drawings of it: chipped takes a bite out of the
    /// corner, fine is the thing as drawn, and pristine adds a glint. Twelve recognisable
    /// objects, four sprites.
    func sprite(tier: Int) -> PixelBuffer {
        guard isDecor else { return sprite }
        var b = sprite
        switch max(1, min(FindKind.maxTier, tier)) {
        case 1:
            b.clear(b.width - 1, b.height - 2, 1, 2)
            b.clear(0, b.height - 1, 1, 1)
        case 2:
            break
        default:
            b.fill(1, 0, 1, 1, BurrowInk.white)
            b.fill(b.width - 2, 1, 1, 1, BurrowInk.white)
        }
        return b
    }

    var sprite: PixelBuffer {
        typealias I = BurrowInk
        switch self {
        case .berry:
            return PixelBuffer(art: ["...L.",
                                     ".RRL.",
                                     "RRRRR",
                                     "RHRRR",
                                     ".RRR."],
                               palette: ["R": I.berry, "H": I.berryHi, "L": I.leaf])
        case .amber:
            return PixelBuffer(art: ["..AA..",
                                     ".AAAA.",
                                     "AHAAAA",
                                     ".AAAA.",
                                     "..AA.."],
                               palette: ["A": I.amber, "H": I.amberHi])
        case .bone:
            return PixelBuffer(art: ["C...C",
                                     "CCCCC",
                                     "C...C"],
                               palette: ["C": I.cream])
        case .crystal:
            return PixelBuffer(art: [".P.P.",
                                     ".PHP.",
                                     "PPHPP",
                                     "PPPPP"],
                               palette: ["P": I.violet, "H": I.violetHi])
        case .root:
            return PixelBuffer(art: [".L.L.",
                                     "..L..",
                                     ".CCD.",
                                     ".CCD.",
                                     "..CD.",
                                     "..C.."],
                               palette: ["C": I.copper, "D": I.amberLo, "L": I.leaf])
        case .mushroom:
            return PixelBuffer(art: [".PPP.",
                                     "PWPPP",
                                     "PPPWP",
                                     "..C..",
                                     "..C.."],
                               palette: ["P": I.pink, "W": I.white, "C": I.cream])
        case .honeydew:
            return PixelBuffer(art: ["..A..",
                                     ".AYA.",
                                     "AYWYA",
                                     "AYYYA",
                                     ".AAA."],
                               palette: ["A": I.amber, "Y": I.amberHi, "W": I.white])
        case .shell:
            return PixelBuffer(art: [".SSSS.",
                                     "SHHHSS",
                                     "SHSSHS",
                                     "SSHHSS",
                                     ".SSSS."],
                               palette: ["S": I.steel, "H": I.steelHi])
        }
    }
}

/// Tiles for the 5 × 5 dig grid (spec §1). Each is 9 × 9 pixels, drawn at `layout.cell * 2`
/// points per pixel — so the grid spans 5 × 9 × 2 = 90 design cells against the burrow's 64,
/// which is what makes arriving at a spot read as a zoom in rather than a screen change.
///
/// Heat is never colour alone (spec §6): hot carries a ▲, warm a single dot, cold nothing.
/// What a buried find shows above it in the burrow (spec §3). The old marker was one amber
/// "!" for every spot; these say what is down there, how deep, what the soil is like, and
/// whether the grub has started on it.
enum MarkerArt {
    /// Every dig site is this wide, so the clamp that keeps one off the bezel does not have
    /// to build a sprite to measure it.
    static let siteWidth = 11

    /// A dig site: the mound, and what the mound itself says is buried under it.
    ///
    /// 11 wide, 9 tall. The last row is the shadow it casts, which is what anchors the whole
    /// thing to the soil. Mound and tell are ONE sprite — they used to be two, with the tell
    /// bobbing above the crown and a gap underneath, which is exactly why it read as falling.
    ///
    /// The language is the mound's own outline: weeds growing out of it mean food, a shard
    /// breaking its surface means decor. Before this, four of the six marks a site could show
    /// were the same 3×3 plus in different colours — two orthogonal axes (what is buried,
    /// what the soil is like) fused into one glyph and separated only by hue, which at three
    /// pixels square is not a language.
    static func site(food: Bool, opened: Bool) -> PixelBuffer {
        let body = opened ? ["...D.K.D...",
                             "..DDKKKDD..",
                             ".DDKKKKKDD.",
                             "DDDKKKKKDDD",
                             "DDDDKKKDDDD",
                             "SSSSSSSSSSS"]
                          : ["....HHD....",
                             "..HHDDDDD..",
                             ".HDDDDDDDD.",
                             "HDDDDDDDDDD",
                             "DDDDDDDDDDD",
                             "SSSSSSSSSSS"]
        let top = food ? ["..G..G.G...",     // weeds, growing out of the mound
                          "..G.GG.G...",
                          "...GGGG...."]
                       : ["......A....",     // a shard, breaking its surface
                          ".....AA....",
                          "....AWA...."]
        return PixelBuffer(art: top + body,
                           palette: ["W": BurrowInk.tellGold, "A": BurrowInk.tellGoldLo,
                                     "G": BurrowInk.sprig,
                                     "H": BurrowInk.dirtHi, "D": BurrowInk.dirt,
                                     "K": BurrowInk.hollow, "S": BurrowInk.shade])
    }

    /// The condition badge, shown only once the spot has been visited — before that, what the
    /// soil is like is exactly what the trip is for finding out.
    static func badge(_ c: DigCondition) -> PixelBuffer {
        switch c {
        case .wet:      return PixelBuffer(art: [".W.", "WWW", ".W."],
                                           palette: ["W": BurrowInk.steelHi])
        case .rocky:    return PixelBuffer(art: [".RR", "RRR", "RR."],
                                           palette: ["R": BurrowInk.steel])
        case .rooty:    return PixelBuffer(art: ["R..", ".R.", "RR."],
                                           palette: ["R": BurrowInk.root])
        case .glinting: return PixelBuffer(art: [".H.", "HAH", ".H."],
                                           palette: ["H": BurrowInk.amberHi, "A": BurrowInk.cream])
        }
    }

}

enum DigArt {
    static let side = 9

    /// Untouched soil: a raised block with a lit top edge, so it reads as "not dug yet".
    static let soil = PixelBuffer(art: ["LLLLLLLLL",
                                        "LSSSSSSSd",
                                        "LSSsSSSSd",
                                        "LSSSSSsSd",
                                        "LsSSSSSSd",
                                        "LSSSSsSSd",
                                        "LSSsSSSSd",
                                        "LSSSSSSSd",
                                        "ddddddddd"],
                                  palette: ["L": BurrowInk.soil1, "S": BurrowInk.soil2,
                                            "s": BurrowInk.speck, "d": BurrowInk.soil4])

    /// A rock, still whole. `cracked` is the same stone after one hit.
    static func rock(cracked: Bool) -> PixelBuffer {
        PixelBuffer(art: ["LLLLLLLLL",
                          "LSSSSSSSd",
                          "LSRRRRRSd",
                          "LRRhhRRRd",
                          cracked ? "LRkkkkkRd" : "LRRhRRRRd",
                          cracked ? "LRRkRkRRd" : "LRRRRhRRd",
                          "LSRRRRRSd",
                          "LSSSSSSSd",
                          "ddddddddd"],
                    palette: ["L": BurrowInk.soil1, "S": BurrowInk.soil2, "d": BurrowInk.soil4,
                              "R": BurrowInk.steel, "h": BurrowInk.steelHi,
                              "k": BurrowInk.hollow])
    }
    static let rockWhole = rock(cracked: false)
    static let rockCracked = rock(cracked: true)

    /// A root: can't be dug, and never hides the find.
    static let root = PixelBuffer(art: ["LLLLLLLLL",
                                        "LSSrSSSSd",
                                        "LSSrrSSSd",
                                        "LSrrRrSSd",
                                        "LrrRRRrrd",
                                        "LSSrRRrSd",
                                        "LSSSrrSSd",
                                        "LSSSSrSSd",
                                        "ddddddddd"],
                                  palette: ["L": BurrowInk.soil1, "S": BurrowInk.soil2,
                                            "d": BurrowInk.soil4,
                                            "R": BurrowInk.root, "r": BurrowInk.surface])

    /// A tile already dug, showing how close the find was.
    static func broken(_ heat: Heat) -> PixelBuffer {
        switch heat {
        // Hot is the brightest field in the game and carries a ▲; warm is a dim field with a
        // single dot. The two must differ in brightness as well as glyph — colour alone fails
        // for a colour-blind player, and glyph alone is too small to read at a glance.
        case .hot:  return PixelBuffer(art: ["kkkkkkkkk",
                                             "kHHHHHHHk",
                                             "kHHHAHHHk",
                                             "kHHAAAHHk",
                                             "kHAAAAAHk",
                                             "kHHHHHHHk",
                                             "kHHHHHHHk",
                                             "kHHHHHHHk",
                                             "kkkkkkkkk"],
                                       palette: ["k": BurrowInk.hollow, "H": BurrowInk.amber,
                                                 "A": BurrowInk.amberHi])
        case .warm: return PixelBuffer(art: ["kkkkkkkkk",
                                             "kWWWWWWWk",
                                             "kWWWWWWWk",
                                             "kWWWWWWWk",
                                             "kWWWAWWWk",
                                             "kWWWWWWWk",
                                             "kWWWWWWWk",
                                             "kWWWWWWWk",
                                             "kkkkkkkkk"],
                                       palette: ["k": BurrowInk.hollow, "W": BurrowInk.amberLo,
                                                 "A": BurrowInk.amber])
        // An empty pit. The field is the darkest ink in the palette with a lip around it:
        // filled with `soil4` it was within a shade of untouched soil, and a dug tile that
        // reads as undug is the one thing this grid cannot afford.
        case .cold: return PixelBuffer(art: ["RRRRRRRRR",
                                             "RkkkkkkkR",
                                             "RkkkkkkkR",
                                             "RkkkkkkkR",
                                             "RkkkkkkkR",
                                             "RkkkkkkkR",
                                             "RkkkkkkkR",
                                             "RkkkkkkkR",
                                             "RRRRRRRRR"],
                                       palette: ["k": BurrowInk.hollow, "R": BurrowInk.soil4])
        }
    }
    static let brokenHot = broken(.hot)
    static let brokenWarm = broken(.warm)
    static let brokenCold = broken(.cold)
}

enum IconArt {
    static let shovel = PixelBuffer(art: ["....HH",
                                          "...HH.",
                                          "..HH..",
                                          "BBH...",
                                          "BBB...",
                                          "BB...."],
                                    palette: ["H": BurrowInk.copper, "B": BurrowInk.creamDim])
    static let pouch = PixelBuffer(art: ["..LL..",
                                         "..HH..",
                                         ".HHHH.",
                                         "HHHHHH",
                                         "HHHHHH",
                                         ".HHHH."],
                                   palette: ["H": BurrowInk.copper, "L": BurrowInk.cream])
    static let bang = PixelBuffer(art: ["A", "A", "A", ".", "A"], palette: ["A": BurrowInk.amber])
    /// The shovel, lit. Used for the strikes that are still inside the clean-dig window, so
    /// the grid shows at a glance whether the bonus is still in reach.
    static let shovelLit = PixelBuffer(art: ["....HH",
                                             "...HH.",
                                             "..HH..",
                                             "BBH...",
                                             "BBB...",
                                             "BB...."],
                                       palette: ["H": BurrowInk.amberHi, "B": BurrowInk.cream])
    static let heart = PixelBuffer(art: [".R.R.",
                                         "RRRRR",
                                         ".RRR.",
                                         "..R.."],
                                   palette: ["R": BurrowInk.berry])
    static let sparkle = PixelBuffer(art: ["A"], palette: ["A": BurrowInk.amberHi])

    /// Decor plinth (6×4). A 6×2 bar read as a smudge on the ground; a slab on a stem with a
    /// foot reads as furniture, which is what makes an empty slot look like somewhere to put
    /// something rather than like a gap in the art. `shelf` is the wall-mounted variant used
    /// by the two upper slots: it hangs on a bracket instead of standing on a foot.
    static func pedestal(lit: Bool, shelf: Bool = false) -> PixelBuffer {
        PixelBuffer(art: shelf ? ["TTTTTT", "BBBBBB"]
                               : ["TTTTTT", "BBBBBB", ".BBBB."],
                    palette: ["T": lit ? BurrowInk.amber : BurrowInk.root,
                              "B": lit ? BurrowInk.amberLo : BurrowInk.soil1])
    }
    static let pedestalDim = pedestal(lit: false)
    static let pedestalLit = pedestal(lit: true)
    static let shelfDim = pedestal(lit: false, shelf: true)
    static let shelfLit = pedestal(lit: true, shelf: true)

    /// Tier pips under a furnished slot: filled for the condition you hold, hollow for what
    /// is still out there. Three of them, so "there is a better one of these in the ground"
    /// is visible without a word of UI — and the next pip fills from the bottom as duplicates
    /// bank into it, which is what stops a surplus find feeling like nothing happened.
    static func pips(tier: Int, bank: Int) -> PixelBuffer {
        var b = PixelBuffer(width: FindKind.maxTier * 2 - 1, height: 2)
        for i in 0..<FindKind.maxTier {
            b.fill(i * 2, 0, 1, 2, i < tier ? BurrowInk.tellGold : BurrowInk.root)
        }
        if tier < FindKind.maxTier, bank > 0 {
            let h = bank * 2 >= BurrowRules.bankPerTier ? 2 : 1
            b.fill(tier * 2, 2 - h, 1, h, BurrowInk.tellGoldLo)
        }
        return b
    }

    /// A free slot's "put something here" mark, shown faintly on the plinth. It stays small
    /// and quiet on purpose: a full dashed box on every empty slot turned the chamber into
    /// wallpaper, which is the clutter this whole change is meant to remove.
    static let slotEmpty = PixelBuffer(art: [".P.",
                                             "PPP",
                                             ".P."],
                                       palette: ["P": BurrowInk.root])

    /// One pinned specimen on the shelf (5×6). The adult sprites are ~21 cells wide, which no
    /// 12-cell side room can show even one of, so the shelf carries a species-tinted bust with
    /// a pin through it — small enough that a room holds two, and the full list is a tap away.
    static func specimen(_ sp: Species) -> PixelBuffer {
        PixelBuffer(art: ["..P..",
                          ".CCC.",
                          "CCCCC",
                          "CECEC",
                          "CCCCC",
                          ".CCC."],
                    palette: ["C": sp.color, "E": BurrowInk.hollow, "P": BurrowInk.creamDim])
    }

    static let box = PixelBuffer(art: ["CCCCCCC",
                                       "C.....C",
                                       "C.TTT.C",
                                       "C..T..C",
                                       "C.....C",
                                       "CCCCCCC"],
                                 palette: ["C": BurrowInk.copper, "T": BurrowInk.teal])
}
