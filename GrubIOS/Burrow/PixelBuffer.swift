import SwiftUI
import UIKit

// MARK: - Palette (from the "Grub Hero Art" redesign canvas)

/// Colours from the pixel-burrow redesign, with the "Rust Clay" background palette
/// (picked 2026-11-10 over the original Midnight Plum: 0b0d24 / 4a2c5a / 2a1836 /
/// 24152e / 1c1026 / 150b1e / 33203f / 3a2247 / 0d0814). Kept as 0xRRGGBB so the
/// bitmap renderer and SwiftUI share one source of truth.
enum BurrowInk {
    static let sky: UInt32          = 0x0d1226
    static let surface: UInt32      = 0x7a3e2a
    // The four bands darken **and cool** with depth: warm rust topsoil, duller clay, then
    // mineral soil and bedrock that shift toward the sky's blue-violet. Darkening alone was
    // the old scheme (74 → 62 → 51 → 40 on red, one hue) and it made the layers invisible —
    // which hid the whole loose/clay/deep difficulty model from the player.
    static let soil1: UInt32        = 0x5a2e1b
    static let soil2: UInt32        = 0x47281f
    static let soil3: UInt32        = 0x34232b
    static let soil4: UInt32        = 0x221d2b
    static let speck: UInt32        = 0x6b3b26
    /// Flecks, one per band: a lighter version of that band, so texture reads as texture and
    /// recedes behind the mounds instead of competing with them.
    static let speck1: UInt32       = 0x6d3a22
    static let speck2: UInt32       = 0x58331f
    static let speck3: UInt32       = 0x453039
    static let speck4: UInt32       = 0x302a3a
    static let root: UInt32         = 0x5e3322
    static let hollow: UInt32       = 0x140a06
    static let dirt: UInt32         = 0x9a5638
    /// Freshly turned earth — the lit crown of a dig mound — and the shadow it casts.
    static let dirtHi: UInt32       = 0xc07a47
    static let shade: UInt32        = 0x19100a
    /// A plant green for the food tell. Deliberately not `leaf`/`teal`: those are the grub's
    /// own colours, and a marker wearing them reads as another grub, not as a thing to tap.
    static let sprig: UInt32        = 0x7ab648
    /// The decor tell's gold. Deliberately not `amber`/`amberHi`: at luminance 228 `amberHi`
    /// was the brightest pixel in the game — brighter than the moon (223) and well past the
    /// grub (162), so a buried trinket out-shouted the pet. These sit at 146/115, bracketing
    /// the food tell's `sprig` (152) so gold and green read at the same weight and both stay
    /// under the grub.
    static let tellGold: UInt32     = 0xcf8a1e
    static let tellGoldLo: UInt32   = 0xa8691a
    static let teal: UInt32         = 0x4ecca3
    static let cream: UInt32        = 0xe8e0c0
    static let creamDim: UInt32     = 0xc9c0a0
    static let mushroom: UInt32     = 0x7b2d8b
    static let mushroomHi: UInt32   = 0xb04fc4
    static let mushroomGlint: UInt32 = 0xf0c8f8
    static let berry: UInt32        = 0xe94560
    static let berryHi: UInt32      = 0xf4c0d1
    static let amber: UInt32        = 0xf5a623
    static let amberHi: UInt32      = 0xffe2a8
    static let amberLo: UInt32      = 0x854f0b
    static let violet: UInt32       = 0x8f6fe0
    static let violetHi: UInt32     = 0xc9b8f5
    static let leaf: UInt32         = 0x5dcaa5
    static let copper: UInt32       = 0xc97b3a
    static let white: UInt32        = 0xffffff
    static let mutedText: UInt32    = 0xb9b0d0
    static let pink: UInt32         = 0xed93b1   // STALK; mushroom caps
    static let steel: UInt32        = 0x6f8fb0   // SHELL
    static let steelHi: UInt32      = 0xa9c0d8
}

extension Color {
    init(ink: UInt32) {
        self.init(.sRGB,
                  red: Double((ink >> 16) & 0xFF) / 255,
                  green: Double((ink >> 8) & 0xFF) / 255,
                  blue: Double(ink & 0xFF) / 255,
                  opacity: 1)
    }
}

// MARK: - Bitmap

/// A tiny RGBA bitmap addressed in whole pixels. One bitmap pixel = one on-screen
/// "cell", scaled up nearest-neighbour so every cell stays a crisp square.
struct PixelBuffer {
    let width: Int
    let height: Int
    private(set) var data: [UInt8]

    init(width: Int, height: Int) {
        self.width = max(1, width)
        self.height = max(1, height)
        data = [UInt8](repeating: 0, count: self.width * self.height * 4)
    }

    /// Punch a rect back to transparent. `fill` blends source-over, so it cannot un-draw.
    mutating func clear(_ x: Int, _ y: Int, _ w: Int, _ h: Int) {
        for yy in max(0, y)..<min(height, y + h) {
            for xx in max(0, x)..<min(width, x + w) {
                let i = (yy * width + xx) * 4
                data[i] = 0; data[i + 1] = 0; data[i + 2] = 0; data[i + 3] = 0
            }
        }
    }

    /// Build a sprite from ASCII rows; characters not in `palette` are transparent.
    init(art: [String], palette: [Character: UInt32]) {
        self.init(width: art.map(\.count).max() ?? 1, height: art.count)
        for (y, row) in art.enumerated() {
            for (x, ch) in row.enumerated() {
                if let c = palette[ch] { fill(x, y, 1, 1, c) }
            }
        }
    }

    /// Fill a rect with a 0xRRGGBB colour. `alpha` < 1 blends "source over" what is there
    /// (the hero art's 18% black shading works exactly this way).
    mutating func fill(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ hex: UInt32, alpha: Double = 1) {
        let x0 = max(0, x), y0 = max(0, y)
        let x1 = min(width, x + w), y1 = min(height, y + h)
        guard x0 < x1, y0 < y1 else { return }
        let r = Double((hex >> 16) & 0xFF), g = Double((hex >> 8) & 0xFF), b = Double(hex & 0xFF)
        let a = min(1, max(0, alpha))
        for yy in y0..<y1 {
            var i = (yy * width + x0) * 4
            for _ in x0..<x1 {
                if a >= 1 {
                    data[i] = UInt8(r); data[i + 1] = UInt8(g); data[i + 2] = UInt8(b); data[i + 3] = 255
                } else {
                    // Premultiplied source-over.
                    let da = Double(data[i + 3]) / 255
                    data[i]     = UInt8(min(255, r * a + Double(data[i])     * (1 - a)))
                    data[i + 1] = UInt8(min(255, g * a + Double(data[i + 1]) * (1 - a)))
                    data[i + 2] = UInt8(min(255, b * a + Double(data[i + 2]) * (1 - a)))
                    data[i + 3] = UInt8(min(255, (a + da * (1 - a)) * 255))
                }
                i += 4
            }
        }
    }

    /// Same shape, every visible pixel recoloured — used for "not found yet" silhouettes.
    func silhouette(_ hex: UInt32) -> PixelBuffer {
        var out = PixelBuffer(width: width, height: height)
        for y in 0..<height {
            for x in 0..<width where data[(y * width + x) * 4 + 3] > 0 {
                out.fill(x, y, 1, 1, hex)
            }
        }
        return out
    }

    func cgImage() -> CGImage? {
        guard let provider = CGDataProvider(data: Data(data) as CFData),
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return CGImage(width: width, height: height,
                       bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                       space: space,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false,
                       intent: .defaultIntent)
    }
}

/// Shows a `PixelBuffer` at `cell` points per pixel, nearest-neighbour.
struct PixelImage: View {
    let buffer: PixelBuffer
    let cell: CGFloat

    var body: some View {
        if let cg = buffer.cgImage() {
            Image(decorative: cg, scale: 1)
                .resizable()
                .interpolation(.none)
                .antialiased(false)
                .frame(width: CGFloat(buffer.width) * cell, height: CGFloat(buffer.height) * cell)
        }
    }
}
