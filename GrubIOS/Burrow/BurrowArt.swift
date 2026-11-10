import SwiftUI

// MARK: - Layout

struct CellRect: Equatable {
    var x: Int, y: Int, w: Int, h: Int
    var maxX: Int { x + w }
    var maxY: Int { y + h }
    var midX: Int { x + w / 2 }
}

/// A spot in the burrow expressed relative to a landmark, so it lands sensibly on any screen height.
struct CellAnchor: Equatable, Hashable {
    enum Ref: Hashable { case surface, chamberTop, chamberBottom }
    let ref: Ref
    let x: Int   // design column (0..<64)
    let dy: Int  // rows below the landmark
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

    func resolve(_ a: CellAnchor) -> (x: Int, y: Int) {
        switch a.ref {
        case .surface:       return (a.x, surface + a.dy)
        case .chamberTop:    return (a.x, chamber.y + a.dy)
        case .chamberBottom: return (a.x, chamber.maxY + a.dy)
        }
    }

    /// Screen point (top-left of a cell) for a design-space cell.
    func point(_ dx: Double, _ dy: Double) -> CGPoint {
        CGPoint(x: originX + (CGFloat(x0) + dx) * cell, y: dy * cell)
    }
}

// MARK: - Backdrop (sky, surface, soil, tunnels, decor)

enum BurrowArt {
    static func backdrop(_ L: BurrowLayout, holes: [CellAnchor]) -> PixelBuffer {
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
        let b1 = S + 1 + Int(Double(soil) * 0.24)
        let b2 = b1 + Int(Double(soil) * 0.27)
        let b3 = b2 + Int(Double(soil) * 0.24)
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

        // Pebbles on the main chamber floor (grounds the grub).
        r(C.x + 2, C.maxY - 2, 3, 2, I.speck); r(C.maxX - 6, C.maxY - 3, 4, 3, I.speck); r(C.maxX - 8, C.maxY - 1, 2, 1, I.speck)

        // Right side-chamber: glowing amber on a pedestal.
        let R = L.sideR, gy = R.maxY - 9
        r(R.x + 4, R.maxY - 3, 6, 3, I.root)
        r(R.x + 6, gy, 2, 1, I.amber); r(R.x + 5, gy + 1, 4, 1, I.amber); r(R.x + 4, gy + 2, 6, 2, I.amber)
        r(R.x + 5, gy + 4, 4, 1, I.amber); r(R.x + 6, gy + 5, 2, 1, I.amber); r(R.x + 5, gy + 2, 1, 1, I.amberHi)
        r(R.x + 2, gy, 1, 1, I.amberHi); r(R.x + 11, gy + 1, 1, 1, I.amberHi); r(R.x + 12, gy + 5, 1, 1, I.amberHi)

        // Left side-chamber: mushroom lamp + little stool.
        let Lc = L.sideL
        r(Lc.x + 3, Lc.maxY - 6, 2, 6, I.cream)
        r(Lc.x + 1, Lc.maxY - 8, 6, 2, I.mushroomHi); r(Lc.x + 2, Lc.maxY - 9, 4, 1, I.mushroomHi)
        r(Lc.x + 2, Lc.maxY - 8, 1, 1, I.mushroomGlint); r(Lc.x + 5, Lc.maxY - 9, 1, 1, I.mushroomGlint)
        r(Lc.x, Lc.maxY - 11, 1, 1, I.mushroomHi); r(Lc.x + 9, Lc.maxY - 10, 1, 1, I.mushroomHi)
        r(Lc.x + 7, Lc.maxY - 4, 4, 1, I.cream); r(Lc.x + 7, Lc.maxY - 3, 1, 3, I.cream); r(Lc.x + 10, Lc.maxY - 3, 1, 3, I.cream)

        // Pockets left by digging.
        for a in holes {
            let p = L.resolve(a)
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
        // round body: four stepped rows top and bottom around a 12-row full-width band
        for (i, span) in [(6, 14), (4, 16), (2, 18), (1, 19)].enumerated() {
            r(span.0, o + i, span.1 - span.0 + 1, 1, body)
            r(span.0, o + 19 - i, span.1 - span.0 + 1, 1, body)
        }
        r(0, o + 4, 21, 12, body)
        // antennae: stalk, one step outward, white tip
        r(7, o - 3, 1, 3, body); r(6, o - 4, 1, 1, body); r(6, o - 6, 1, 2, I.white)
        r(13, o - 3, 1, 3, body); r(14, o - 4, 1, 1, body); r(14, o - 6, 1, 2, I.white)
        // cream highlight + side shade
        r(4, o + 2, 3, 1, I.cream)
        r(17, o + 4, 4, 12, shade)
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

    static let sulk = frame(sulk: true)
    static let idle = frame()
    static let blink = frame(blink: true)
    static let chomp = frame(chomp: true)
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
}
