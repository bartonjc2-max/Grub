import Foundation

/// Adult sprites from the species contact sheet, plus the cocoon and the molt-ready glow.
enum SpeciesArt {
    /// A rect on the contact sheet's 24×24 grid.
    struct R { let x, y, w, h: Int; let c: UInt32
        init(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ c: UInt32) { self.x = x; self.y = y; self.w = w; self.h = h; self.c = c }
    }

    /// The adult as it stands in the chamber and on the reveal card.
    static func adult(_ sp: Species) -> PixelBuffer { cache[sp] ?? GrubArt.idle }

    private static let cache: [Species: PixelBuffer] = {
        var out: [Species: PixelBuffer] = [.grub: GrubArt.idle]
        for sp in Species.allCases where sp != .grub { out[sp] = scaled(rects(sp)) }
        return out
    }()

    /// Edge scaling ×1.5: left/top floor, right/bottom ceil, cropped to the bounding box.
    static func scaled(_ rs: [R]) -> PixelBuffer {
        let s = rs.map { r -> (Int, Int, Int, Int, UInt32) in
            let x0 = Int((Double(r.x) * 1.5).rounded(.down)), y0 = Int((Double(r.y) * 1.5).rounded(.down))
            let x1 = Int((Double(r.x + r.w) * 1.5).rounded(.up)), y1 = Int((Double(r.y + r.h) * 1.5).rounded(.up))
            return (x0, y0, x1 - x0, y1 - y0, r.c)
        }
        let minX = s.map(\.0).min() ?? 0, minY = s.map(\.1).min() ?? 0
        let maxX = s.map { $0.0 + $0.2 }.max() ?? 1, maxY = s.map { $0.1 + $0.3 }.max() ?? 1
        var b = PixelBuffer(width: maxX - minX, height: maxY - minY)
        for (x, y, w, h, c) in s { b.fill(x - minX, y - minY, w, h, c) }
        return b
    }

    // Exact rects from docs/burrow/species-contact-sheet.html, in SVG paint order.
    private static func rects(_ sp: Species) -> [R] {
        switch sp {
        case .grub:
            return []
        case .horn:
            return [
            R(8,10,8,1,0x8f6fe0), R(6,11,12,1,0x8f6fe0), R(5,12,14,7,0x8f6fe0), R(6,19,12,1,0x8f6fe0),
            R(8,20,8,1,0x8f6fe0), R(5,20,2,1,0x8f6fe0), R(17,20,2,1,0x8f6fe0), R(16,12,3,7,0x6a4fc0),
            R(11,7,2,3,0xe8e0c0), R(11,5,1,2,0xe8e0c0), R(10,3,1,2,0xe8e0c0), R(12,4,1,1,0xe8e0c0),
            R(7,13,3,3,0x0d0814), R(14,13,3,3,0x0d0814), R(7,13,1,1,0xffffff), R(14,13,1,1,0xffffff),
            R(11,17,2,1,0x0d0814)
            ]
        case .fuzz:
            return [
            R(8,8,8,1,0xf5a623), R(6,9,12,1,0xf5a623), R(5,10,14,9,0xf5a623), R(6,19,12,1,0xf5a623),
            R(8,20,8,1,0xf5a623), R(5,16,14,1,0x854f0b), R(6,19,12,1,0x854f0b), R(4,9,1,1,0xffe2a8),
            R(3,12,2,1,0xffe2a8), R(4,15,1,1,0xffe2a8), R(3,18,2,1,0xffe2a8), R(19,9,1,1,0xffe2a8),
            R(19,12,2,1,0xffe2a8), R(19,15,1,1,0xffe2a8), R(19,18,2,1,0xffe2a8), R(7,6,1,2,0xffe2a8),
            R(11,5,1,3,0xffe2a8), R(15,6,1,2,0xffe2a8), R(9,21,1,1,0xffe2a8), R(14,21,1,1,0xffe2a8),
            R(7,11,3,3,0x0d0814), R(14,11,3,3,0x0d0814), R(7,11,1,1,0xffffff), R(14,11,1,1,0xffffff),
            R(11,14,2,1,0x0d0814)
            ]
        case .shell:
            return [
            R(5,14,14,5,0xc9c0a0), R(6,19,12,1,0xc9c0a0), R(8,20,8,1,0xc9c0a0), R(9,7,6,1,0x6f8fb0),
            R(7,8,10,1,0x6f8fb0), R(6,9,12,1,0x6f8fb0), R(5,10,14,4,0x6f8fb0), R(5,11,14,1,0x4f6f90),
            R(5,13,14,1,0x4f6f90), R(6,21,1,1,0x4f6f90), R(9,21,1,1,0x4f6f90), R(14,21,1,1,0x4f6f90),
            R(17,21,1,1,0x4f6f90), R(4,14,16,1,0x9fb8d0), R(8,8,3,1,0x9fb8d0), R(7,15,3,3,0x0d0814),
            R(14,15,3,3,0x0d0814), R(7,15,1,1,0xffffff), R(14,15,1,1,0xffffff), R(11,18,2,1,0x0d0814)
            ]
        case .claws:
            return [
            R(8,8,8,1,0xc97b3a), R(6,9,12,1,0xc97b3a), R(5,10,14,9,0xc97b3a), R(6,19,12,1,0xc97b3a),
            R(8,20,8,1,0xc97b3a), R(4,13,1,2,0xc97b3a), R(19,13,1,2,0xc97b3a), R(9,6,1,2,0xc97b3a),
            R(14,6,1,2,0xc97b3a), R(16,10,3,9,0xa05f28), R(1,11,3,1,0xe8e0c0), R(0,12,4,4,0xe8e0c0),
            R(1,16,3,1,0xe8e0c0), R(20,11,3,1,0xe8e0c0), R(20,12,4,4,0xe8e0c0), R(20,16,3,1,0xe8e0c0),
            R(1,13,1,3,0xc9c0a0), R(22,13,1,3,0xc9c0a0), R(7,11,3,3,0x0d0814), R(14,11,3,3,0x0d0814),
            R(7,11,1,1,0xffffff), R(14,11,1,1,0xffffff), R(11,16,2,1,0x0d0814)
            ]
        case .stalk:
            return [
            R(7,13,10,1,0xed93b1), R(5,14,14,1,0xed93b1), R(4,15,16,5,0xed93b1), R(5,20,14,1,0xed93b1),
            R(8,7,1,6,0xed93b1), R(15,7,1,6,0xed93b1), R(18,15,2,5,0xd4537e), R(6,17,2,1,0xd4537e),
            R(15,17,2,1,0xd4537e), R(7,4,3,3,0xffffff), R(14,4,3,3,0xffffff), R(8,5,1,1,0x0d0814),
            R(15,5,1,1,0x0d0814), R(11,17,2,1,0x0d0814), R(21,20,2,1,0xf4c0d1)
            ]
        }
    }

    /// Silk cocoon, 15×20, shown while the molt plays.
    static let cocoon = PixelBuffer(art: [
        ".....CCCCC.....",
        "...CCCCCCCCC...",
        "..CCDCCCCCCCC..",
        ".CCCCCCCCCDCCC.",
        ".CDDDDDDDDDDDC.",
        ".CCCCCCCCCCCCC.",
        "CCCCCCCCCCCCCCC",
        "CCCDCCCCCCCCCCC",
        "CDDDDDDDDDDDDDC",
        "CCCCCCCCCCCCCCC",
        "CCCCCCCCCCCDCCC",
        "CCCCCCCCCCCCCCC",
        "CDDDDDDDDDDDDDC",
        ".CCCCCCCCCCCCC.",
        ".CCCCCCCDCCCCC.",
        ".CDDDDDDDDDDDC.",
        "..CCCCCCCCCCC..",
        "...CCCCCCCCC...",
        ".....CCCCC.....",
        "......DDD......"],
        palette: ["C": BurrowInk.cream, "D": BurrowInk.creamDim])

    /// The larva's outline colour for the molt-ready glow (drawn at ±1 cell behind the grub).
    static let glow = GrubArt.idle.silhouette(BurrowInk.amberHi)

    /// The egg (15×18): cream shell with spots in the parent's colour (teal for a first egg),
    /// plus 0–3 cracks drawn in hollow.
    static func egg(cracks: Int, tint: Species?) -> PixelBuffer {
        var b = PixelBuffer(art: [
            ".....CCCCC.....",
            "...CCCCCCCCC...",
            "..CCCCCCCCCCC..",
            ".CCCSSCCCCCCCC.",
            ".CCSSSCCCCCSCC.",
            "CCCCSCCCCCSSSCC",
            "CCCCCCCCCCCSCCC",
            "CCCCCCCCCCCCCCC",
            "CCSCCCCCCCCCCCC",
            "CSSSCCCCCSSCCCC",
            "CCSCCCCCSSSSCCC",
            "CCCCCCCCCSSCCCC",
            "CCCCCCCCCCCCCCC",
            ".CCCCCCCCCCCCD.",
            ".CCCCCCCCCCCDD.",
            "..CCCCCCCCCDD..",
            "...DDCCCCDDD...",
            ".....DDDDD....."],
            palette: ["C": BurrowInk.cream, "D": BurrowInk.creamDim, "S": tint?.color ?? BurrowInk.teal])
        let stages: [[(Int, Int)]] = [
            [(7, 1), (8, 2), (7, 3)],
            [(6, 4), (7, 5), (8, 6), (9, 5)],
            [(5, 6), (4, 7), (10, 6), (11, 7), (8, 7), (9, 8)],
        ]
        for stage in stages.prefix(max(0, min(3, cracks))) {
            for (x, y) in stage { b.fill(x, y, 1, 1, BurrowInk.hollow) }
        }
        return b
    }
}
