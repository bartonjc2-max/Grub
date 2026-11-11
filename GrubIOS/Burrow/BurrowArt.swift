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

    /// Bottom-centre cell of decor slot `i`: the 6×2 pedestal spans x-3…x+2, rows y…y+1,
    /// and the decor sprite stands on it (its bottom row at y-1).
    func decorSlot(_ i: Int) -> (x: Int, y: Int)? {
        switch i {
        case 0: return (sideL.midX, sideL.maxY - 2)
        case 1: return (sideR.midX, sideR.maxY - 2)
        case 2: return (chamber.x + 5, chamber.maxY - 2)
        case 3: return (chamber.maxX - 4, chamber.maxY - 2)
        default: return nil
        }
    }
}

// MARK: - Backdrop (sky, surface, soil, tunnels, decor)

enum BurrowArt {
    static func backdrop(_ L: BurrowLayout, holes: [Int], spurs: [Int] = []) -> PixelBuffer {
        var b = PixelBuffer(width: L.cols, height: L.rows)
        let X = L.x0, S = L.surface
        func r(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ c: UInt32) { b.fill(X + x, y, w, h, c) }
        func band(_ y0: Int, _ y1: Int, _ c: UInt32) { b.fill(0, y0, L.cols, y1 - y0, c) }
        typealias I = BurrowInk
        func chamber(_ c: CellRect, bevel v: Int) {
            r(c.x, c.y, c.w, c.h, I.hollow)
            r(c.x + v, c.y - v, c.w - 2 * v, v, I.hollow)
            r(c.x + v, c.maxY, c.w - 2 * v, v, I.hollow)
            r(c.x - v, c.y + 2 * v, v, c.h - 4 * v, I.hollow)
            r(c.maxX, c.y + 2 * v, v, c.h - 4 * v, I.hollow)
        }

        // Sky + stars (positions from the hero, stretched to this sky).
        band(0, S, I.sky)
        let heroStars = [(6, 5), (19, 22), (33, 4), (52, 24), (68, 5), (79, 21), (97, 12), (103, 24), (11, 14), (88, 27), (42, 13)]
        for (hx, hy) in heroStars {
            let x = Int(Double(hx) / 108 * 64)
            let y = 3 + Int(Double(hy) / 30 * Double(max(10, S - 10)))
            r(x, y, 1, 1, I.teal)
        }

        // Moon.
        let mx = 52, my = max(10, S - 30)
        r(mx + 1, my, 6, 1, I.cream); r(mx, my + 1, 8, 6, I.cream); r(mx + 1, my + 7, 6, 1, I.cream)
        r(mx + 2, my + 2, 2, 2, I.creamDim); r(mx + 5, my + 5, 1, 1, I.creamDim)

        // Surface mushrooms.
        func bigShroom(_ x: Int) {
            r(x + 3, S - 3, 2, 3, I.cream); r(x, S - 5, 8, 2, I.mushroom); r(x + 2, S - 6, 4, 1, I.mushroomHi)
        }
        bigShroom(3); bigShroom(51)
        r(29, S - 2, 1, 2, I.cream); r(27, S - 3, 5, 1, I.mushroom)

        // Ground: surface line + four soil bands.
        let soil = L.rows - S - 1
        let bands = L.soilBands
        let (b1, b2, b3) = (bands.b1, bands.b2, bands.b3)
        band(S, S + 1, I.surface)
        band(S + 1, b1, I.soil1); band(b1, b2, I.soil2); band(b2, b3, I.soil3); band(b3, L.rows, I.soil4)

        // Speckles (deterministic LCG so the burrow never shimmers between launches).
        var seed: UInt32 = 0x9e37_79b9
        func rnd(_ n: Int) -> Int { seed = seed &* 1_664_525 &+ 1_013_904_223; return Int(seed >> 8) % max(1, n) }
        for _ in 0..<(L.cols * soil / 55) {
            b.fill(rnd(L.cols), S + 2 + rnd(max(1, soil - 2)), rnd(2) + 1, 1, I.speck)
        }

        // Roots hanging from the surface.
        r(44, S + 1, 1, 7, I.root); r(45, S + 8, 1, 3, I.root); r(61, S + 1, 1, 5, I.root); r(2, S + 1, 1, 4, I.root)

        // A buried bone (decor).
        r(48, S + 5, 5, 1, I.cream); r(47, S + 4, 1, 3, I.cream); r(53, S + 4, 1, 3, I.cream)

        // Tunnels.
        let C = L.chamber
        r(6, S, 4, 14, I.hollow)                       // entrance shaft (breaks the surface)
        r(6, S + 9, 28, 4, I.hollow)                   // crawl
        r(30, S + 9, 4, max(0, C.y - (S + 9)), I.hollow) // drop into the chamber
        chamber(C, bevel: 2)
        // → right side-chamber
        r(C.maxX, C.y + 12, 10, 4, I.hollow)
        r(56, C.y + 12, 4, max(0, L.sideR.y - (C.y + 12)), I.hollow)
        chamber(L.sideR, bevel: 1)
        // → left side-chamber
        r(22, C.maxY, 4, max(0, L.sideL.y + 7 - C.maxY), I.hollow)
        r(L.sideL.maxX - 1, L.sideL.y + 3, 26 - (L.sideL.maxX - 1), 4, I.hollow)
        chamber(L.sideL, bevel: 1)

        // Rooms start empty: decor is placed by the player (BurrowLayout.decorSlot).

        // The channel the grub dug on its way to a spot it has visited. Capped at 8 cells:
        // some spots sit 14 rows from their nearest tunnel, and an uncapped spur would run
        // all the way up into the title.
        for spot in Set(spurs) where BurrowSpots.spots.indices.contains(spot) {
            let route = BurrowWaypoints.path(to: spot, L)
            guard route.count >= 2 else { continue }
            let end = route[route.count - 1], from = route[route.count - 2]
            let dx = end.x - from.x, dy = end.y - from.y
            let length = min(8, abs(dx) + abs(dy))
            guard length > 0 else { continue }
            for step in 0...length {
                let t = Double(step) / Double(length)
                let x = end.x - Int((Double(dx) * (1 - t)).rounded())
                let y = end.y - Int((Double(dy) * (1 - t)).rounded())
                r(x - 1, y - 1, 2, 2, I.hollow)
            }
        }

        // Pockets left by digging.
        for spot in holes where BurrowSpots.spots.indices.contains(spot) {
            let p = BurrowSpots.resolve(spot, L)
            r(p.x - 2, p.y - 1, 5, 3, I.hollow); r(p.x - 1, p.y - 2, 3, 1, I.hollow); r(p.x - 1, p.y + 2, 3, 1, I.hollow)
        }
        return b
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
    /// A sprout for food, a glint for decor — so the player can choose what to go after.
    static let sprout = PixelBuffer(art: [".L.",
                                          "GLG",
                                          ".L.",
                                          ".L."],
                                    palette: ["L": BurrowInk.leaf, "G": BurrowInk.teal])
    static let glint = PixelBuffer(art: [".A.",
                                         "AHA",
                                         ".A."],
                                   palette: ["A": BurrowInk.amber, "H": BurrowInk.amberHi])

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

    /// Shown once the player has broken a tile here themselves, so a half-finished dig is
    /// visible from the burrow.
    static let crack = PixelBuffer(art: ["D.D", ".D.", "D.D"],
                                   palette: ["D": BurrowInk.dirt])
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
    static let heart = PixelBuffer(art: [".R.R.",
                                         "RRRRR",
                                         ".RRR.",
                                         "..R.."],
                                   palette: ["R": BurrowInk.berry])
    static let sparkle = PixelBuffer(art: ["A"], palette: ["A": BurrowInk.amberHi])

    /// Decor-slot pedestal (6×2). `lit` is the glowing version shown while placing.
    static func pedestal(lit: Bool) -> PixelBuffer {
        PixelBuffer(art: ["TTTTTT",
                          ".BBBB."],
                    palette: ["T": lit ? BurrowInk.amber : BurrowInk.root,
                              "B": lit ? BurrowInk.amberLo : BurrowInk.soil1])
    }
    static let pedestalDim = pedestal(lit: false)
    static let pedestalLit = pedestal(lit: true)

    static let box = PixelBuffer(art: ["CCCCCCC",
                                       "C.....C",
                                       "C.TTT.C",
                                       "C..T..C",
                                       "C.....C",
                                       "CCCCCCC"],
                                 palette: ["C": BurrowInk.copper, "T": BurrowInk.teal])
}
