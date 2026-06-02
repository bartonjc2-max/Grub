import SwiftUI

// MARK: - Sprite & Background Renderer (generic)
struct SpriteRenderer {
    static func drawSprite(context: inout GraphicsContext, sprite: [[Character]], origin: CGPoint, scale: CGFloat) {
        for row in 0..<sprite.count {
            for col in 0..<sprite[row].count {
                let ch = sprite[row][col]
                if ch == "0" { continue }
                guard let color = GrubPalette.paletteMap[ch] else { continue }
                let rect = CGRect(
                    x: origin.x + CGFloat(col) * scale,
                    y: origin.y + CGFloat(row) * scale,
                    width: scale,
                    height: scale
                )
                context.fill(Path(rect), with: .color(color))
            }
        }
    }

    // MARK: - Time Phase

    enum TimePhase {
        case dawn, day, dusk, night

        static var current: TimePhase {
            let hour = Calendar.current.component(.hour, from: Date())
            if hour >= 5 && hour < 8 { return .dawn }
            if hour >= 8 && hour < 18 { return .day }
            if hour >= 18 && hour < 21 { return .dusk }
            return .night
        }

        var skyColors: [Color] {
            switch self {
            case .dawn: return [
                Color(hex: "#0e0e2a"), Color(hex: "#1a1040"), Color(hex: "#2a1848"),
                Color(hex: "#3a2050"), Color(hex: "#4a2850"), Color(hex: "#5a3048"),
                Color(hex: "#6a3848"), Color(hex: "#7a4040"),
            ]
            case .day: return [
                Color(hex: "#0e0e2a"), Color(hex: "#12123a"), Color(hex: "#161640"),
                Color(hex: "#1a1a44"), Color(hex: "#1e1e48"), Color(hex: "#1a1a3e"),
                Color(hex: "#1a1a3e"), Color(hex: "#1a1a3e"),
            ]
            case .dusk: return [
                Color(hex: "#0a0a1e"), Color(hex: "#1a1030"), Color(hex: "#2a1838"),
                Color(hex: "#3a2040"), Color(hex: "#4a2838"), Color(hex: "#5a3030"),
                Color(hex: "#6a3830"), Color(hex: "#7a4028"),
            ]
            case .night: return [
                Color(hex: "#060612"), Color(hex: "#080818"), Color(hex: "#0a0a1e"),
                Color(hex: "#0c0c22"), Color(hex: "#0e0e26"), Color(hex: "#0e0e26"),
                Color(hex: "#0e0e26"), Color(hex: "#0e0e26"),
            ]
            }
        }

        var groundTop: Color {
            switch self {
            case .dawn: return Color(hex: "#3a2a4e")
            case .day: return Color(hex: "#4a3860")
            case .dusk: return Color(hex: "#382848")
            case .night: return Color(hex: "#2a1e3e")
            }
        }

        var groundMid: Color {
            switch self {
            case .dawn: return Color(hex: "#2a1e3a")
            case .day: return Color(hex: "#302444")
            case .dusk: return Color(hex: "#281c38")
            case .night: return Color(hex: "#1e1430")
            }
        }

        var groundDark: Color {
            switch self {
            case .dawn: return Color(hex: "#1e1630")
            case .day: return Color(hex: "#241a38")
            case .dusk: return Color(hex: "#1c142e")
            case .night: return Color(hex: "#140e24")
            }
        }

        var sporeOpacity: Double {
            switch self {
            case .dawn: return 0.25
            case .day: return 0.2
            case .dusk: return 0.3
            case .night: return 0.55
            }
        }

        var starOpacity: Double {
            switch self {
            case .dawn: return 0.15
            case .day: return 0.0
            case .dusk: return 0.2
            case .night: return 0.7
            }
        }

        var showDrips: Bool { self != .night }

        var mushGlowOpacity: Double {
            switch self {
            case .night: return 0.4
            default: return 0.0
            }
        }

        var isNight: Bool { self == .night }

        /// Full-screen translucent overlay tint — recreates time-of-day mood over a
        /// static (fixed-lighting) background PNG. Day = clear; others tint + darken.
        var tintColor: Color {
            switch self {
            case .day:   return Color.clear
            case .dawn:  return Color(red: 0.95, green: 0.55, blue: 0.35).opacity(0.10) // warm
            case .dusk:  return Color(red: 0.55, green: 0.30, blue: 0.55).opacity(0.16) // purple
            case .night: return Color(red: 0.04, green: 0.05, blue: 0.12).opacity(0.42) // deep blue, darken
            }
        }
    }

    /// Mushroom positions/colors — shared by drawStructure (caps) and drawAtmosphere (glow).
    private static let mushData: [(CGFloat, Color, Int)] = [
        (0.08, Color(hex: "#9b3dab"), 3),
        (0.28, Color(hex: "#7b2d8b"), 2),
        (0.72, Color(hex: "#ab4dbb"), 4),
        (0.9, Color(hex: "#8b3d9b"), 2),
    ]

    /// Full background = hand-drawn cave structure + animated atmosphere.
    /// Kept as a wrapper so existing callers are unaffected. The full-screen home
    /// layout calls drawAtmosphere() ONLY, over the cave_home PNG.
    static func drawBackground(context: inout GraphicsContext, size: CGSize, tick: Int) {
        drawStructure(context: &context, size: size, tick: tick)
        drawAtmosphere(context: &context, size: size, tick: tick)
    }

    /// Hand-drawn pixel cave: sky bands, stalactites, rock spots, ground, mushrooms.
    /// Time-of-day color is baked into these fills. NOT used by the home layout
    /// (the cave_home PNG replaces it); retained for fallback / other callers.
    static func drawStructure(context: inout GraphicsContext, size: CGSize, tick: Int) {
        let w = size.width
        let h = size.height

        // Pixel grid size — everything snaps to this for chunky pixel look
        let px: CGFloat = max(4, floor(min(w, h) / 64))

        func block(_ x: CGFloat, _ y: CGFloat, _ bw: CGFloat, _ bh: CGFloat, _ color: Color) {
            let sx = floor(x / px) * px
            let sy = floor(y / px) * px
            let sw = ceil(bw / px) * px
            let sh = ceil(bh / px) * px
            context.fill(Path(CGRect(x: sx, y: sy, width: sw, height: sh)), with: .color(color))
        }

        let phase = TimePhase.current

        // Banded sky (pixel rows, not smooth gradient)
        let skyBands = 8
        let skyColors = phase.skyColors
        let groundStart = h * 0.72
        let bandH = groundStart / CGFloat(skyBands)
        for i in 0..<skyBands {
            block(0, CGFloat(i) * bandH, w, bandH + px, skyColors[i])
        }

        // Stars (small pixel dots with twinkling)
        let starPositions: [(CGFloat, CGFloat)] = [
            (0.1, 0.08), (0.25, 0.15), (0.45, 0.05), (0.6, 0.12),
            (0.78, 0.08), (0.92, 0.18), (0.15, 0.28), (0.5, 0.22),
            (0.85, 0.32), (0.35, 0.35), (0.7, 0.25),
        ]
        if phase.starOpacity > 0 {
            let starColor = Color(hex: "#4ecca3")
            for (i, (sx, sy)) in starPositions.enumerated() {
                let twinkle = sin(Double(tick + i * 37) * 0.05) * 0.3 + 0.7
                block(sx * w, sy * groundStart, px, px,
                      starColor.opacity(phase.starOpacity * twinkle))
            }
        }

        // Stalactites from ceiling (chunky pixel blocks)
        let ceilColor = Color(hex: phase.isNight ? "#060612" : "#0a0a1e")
        // Ceiling bar
        block(0, 0, w, px * 2, ceilColor)
        // Stalactite shapes (each is a stack of blocks getting narrower)
        let stalactiteData: [(CGFloat, [Int])] = [
            (0.08, [5, 4, 3, 2, 1]),
            (0.22, [4, 3, 2, 2, 1, 1]),
            (0.42, [3, 2, 1, 1]),
            (0.58, [5, 4, 3, 2, 1, 1]),
            (0.75, [3, 3, 2, 1]),
            (0.92, [4, 3, 2, 1, 1]),
        ]
        for (sx, widths) in stalactiteData {
            var y = px * 2
            for bw in widths {
                let totalW = CGFloat(bw) * px
                block(sx * w - totalW / 2, y, totalW, px, ceilColor)
                y += px
            }
        }

        // Rock texture spots on cave walls (blocky)
        let rockColor = Color(hex: phase.isNight ? "#0c0c20" : "#151538")
        let rockSpots: [(CGFloat, CGFloat, Int, Int)] = [
            (0.05, 0.3, 3, 2), (0.88, 0.25, 2, 3), (0.12, 0.5, 2, 2),
            (0.92, 0.55, 3, 2), (0.03, 0.6, 2, 1), (0.8, 0.15, 2, 2),
            (0.5, 0.45, 1, 2), (0.3, 0.55, 2, 1), (0.7, 0.5, 1, 1),
        ]
        for (rx, ry, rw, rh) in rockSpots {
            block(rx * w, ry * groundStart, CGFloat(rw) * px, CGFloat(rh) * px, rockColor)
        }

        // Ground — chunky pixel rows with earthy palette
        let dirtDark = phase.groundDark
        let dirtMid = phase.groundMid
        let dirtLight = Color(hex: "#2e2040")
        let mossGreen = phase.groundMid
        let mossBright = phase.groundTop
        let dirtDeep = phase.groundDark

        // Grass/moss top edge — irregular pixel line
        let grassY = groundStart
        // Main ground fill
        block(0, grassY, w, h - grassY, dirtDark)

        // Mossy top row — bright green irregular edge
        let mossPattern = [1,1,0,1,1,1,0,0,1,1,1,1,0,1,1,0,1,1,1,0,1,1,0,0,1,1,1,1,0,1,1,1]
        let mossCols = Int(w / px)
        for c in 0..<mossCols {
            let patIdx = c % mossPattern.count
            if mossPattern[patIdx] == 1 {
                block(CGFloat(c) * px, grassY, px, px, mossBright)
            } else {
                block(CGFloat(c) * px, grassY, px, px, mossGreen)
            }
        }
        // Second row — dimmer moss
        for c in 0..<mossCols {
            let patIdx = (c + 3) % mossPattern.count
            block(CGFloat(c) * px, grassY + px, px, px, patIdx % 3 == 0 ? mossGreen : dirtMid)
        }

        // Dirt texture rows
        let dirtRows = Int((h - grassY - px * 2) / px)
        for r in 0..<dirtRows {
            let y = grassY + px * 2 + CGFloat(r) * px
            for c in 0..<mossCols {
                let hash = (r * 17 + c * 31) % 7
                let color: Color
                if hash == 0 { color = dirtLight }
                else if hash == 1 { color = dirtDeep }
                else if hash == 2 && r < 3 { color = Color(hex: "#342650") }
                else { color = dirtDark }
                block(CGFloat(c) * px, y, px, px, color)
            }
        }

        // Mushrooms — blocky pixel art
        for (mx, capColor, capW) in Self.mushData {
            let baseX = floor(mx * w / px) * px
            let baseY = grassY - px
            let stemColor = Color(hex: "#c0b89a")
            // Stem (1px wide, 2px tall)
            block(baseX, baseY - px, px, px * 2, stemColor)
            // Cap
            let totalCapW = CGFloat(capW) * px
            block(baseX - totalCapW / 2 + px / 2, baseY - px * 2, totalCapW, px, capColor)
            // Cap highlight
            block(baseX - totalCapW / 2 + px / 2, baseY - px * 2, px, px, capColor.opacity(0.7))
        }
    }

    /// Animated, structure-independent atmosphere: stars, spores, drips, mushroom
    /// glow, ambient particles, vignette, + a time-of-day tint rect. Composites
    /// over either drawStructure() or a static backdrop PNG (the home layout).
    static func drawAtmosphere(context: inout GraphicsContext, size: CGSize, tick: Int) {
        let w = size.width
        let h = size.height
        let px: CGFloat = max(4, floor(min(w, h) / 64))

        func block(_ x: CGFloat, _ y: CGFloat, _ bw: CGFloat, _ bh: CGFloat, _ color: Color) {
            let sx = floor(x / px) * px
            let sy = floor(y / px) * px
            let sw = ceil(bw / px) * px
            let sh = ceil(bh / px) * px
            context.fill(Path(CGRect(x: sx, y: sy, width: sw, height: sh)), with: .color(color))
        }

        let phase = TimePhase.current
        let groundStart = h * 0.72
        let grassY = groundStart

        // Stars (small pixel dots with twinkling)
        let starPositions: [(CGFloat, CGFloat)] = [
            (0.1, 0.08), (0.25, 0.15), (0.45, 0.05), (0.6, 0.12),
            (0.78, 0.08), (0.92, 0.18), (0.15, 0.28), (0.5, 0.22),
            (0.85, 0.32), (0.35, 0.35), (0.7, 0.25),
        ]
        if phase.starOpacity > 0 {
            let starColor = Color(hex: "#4ecca3")
            for (i, (sx, sy)) in starPositions.enumerated() {
                let twinkle = sin(Double(tick + i * 37) * 0.05) * 0.3 + 0.7
                block(sx * w, sy * groundStart, px, px,
                      starColor.opacity(phase.starOpacity * twinkle))
            }
        }

        // Animated floating spores
        let sporeColor = Color(hex: "#4ecca3")
        let sporeData: [(baseX: CGFloat, baseY: CGFloat, speed: CGFloat, phaseOffset: Int)] = [
            (0.15, 0.7, 0.3, 0), (0.4, 0.8, 0.2, 40), (0.65, 0.6, 0.35, 80),
            (0.82, 0.75, 0.25, 120), (0.25, 0.65, 0.15, 60), (0.55, 0.85, 0.3, 100),
            (0.9, 0.7, 0.2, 20), (0.1, 0.9, 0.28, 140), (0.48, 0.72, 0.18, 90),
            (0.72, 0.82, 0.32, 50),
        ]
        for spore in sporeData {
            let cycle = 400
            let t = (tick + spore.phaseOffset) % cycle
            let yOffset = CGFloat(t) * spore.speed
            let y = (spore.baseY * groundStart) - yOffset
            let wrappedY = y < 0 ? y + groundStart : y
            if wrappedY < groundStart {
                block(spore.baseX * w, wrappedY, px, px, sporeColor.opacity(phase.sporeOpacity))
            }
        }

        // Dripping water
        if phase.showDrips {
            let dripSources: [(x: CGFloat, startY: CGFloat, cycle: Int)] = [
                (0.25, 0.06, 120), (0.62, 0.04, 160), (0.45, 0.08, 140),
            ]
            for drip in dripSources {
                let t = tick % drip.cycle
                let progress = CGFloat(t) / CGFloat(drip.cycle)
                let dropY = drip.startY * h + progress * (groundStart - drip.startY * h)
                if progress < 0.3 {
                    block(drip.x * w, drip.startY * h, px, px,
                          Color(hex: "#4ecca3").opacity(0.3 * Double(progress / 0.3)))
                }
                if progress >= 0.3 && progress < 0.9 {
                    block(drip.x * w, dropY, px, px * 2, Color(hex: "#4ecca3").opacity(0.25))
                }
                if progress >= 0.9 {
                    let splash = (progress - 0.9) / 0.1
                    block(drip.x * w - px, groundStart - px, px * 3, px,
                          Color(hex: "#4ecca3").opacity(0.2 * (1 - Double(splash))))
                }
            }
        }

        // Mushroom glow at night
        if phase.mushGlowOpacity > 0 {
            for (mx, _, capW) in Self.mushData {
                let glow = sin(Double(tick) * 0.03) * 0.15 + phase.mushGlowOpacity
                let baseX = floor(mx * w / px) * px
                let glowSize = CGFloat(capW + 2) * px
                block(baseX - glowSize / 2 + px / 2, grassY - px * 3,
                      glowSize, px * 2,
                      Color(hex: "#7b2d8b").opacity(glow))
            }
        }

        // Ambient drifting particles
        let particles: [(baseX: CGFloat, y: CGFloat, speed: CGFloat, offset: Int)] = [
            (0.0, 0.35, 0.15, 0), (0.3, 0.55, 0.1, 200), (0.7, 0.25, 0.12, 100),
        ]
        for p in particles {
            let cycle = 600
            let t = (tick + p.offset) % cycle
            let x = (p.baseX + CGFloat(t) * p.speed / CGFloat(cycle))
            let wrappedX = x.truncatingRemainder(dividingBy: 1.0)
            block(wrappedX * w, p.y * groundStart, px, px,
                  GrubPalette.pale.opacity(0.06))
        }

        // Vignette (still smooth — this is a screen effect, not world art)
        let vigGradient = Gradient(stops: [
            .init(color: .clear, location: 0.3),
            .init(color: Color.black.opacity(0.45), location: 1.0),
        ])
        context.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .radialGradient(vigGradient, center: CGPoint(x: w / 2, y: h * 0.42),
                                           startRadius: h * 0.28, endRadius: h * 0.72))

        // Time-of-day tint over the (static) backdrop. Day = clear (no-op).
        if phase.tintColor != Color.clear {
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(phase.tintColor))
        }
    }
}
