import SwiftUI

// MARK: - Game Font
struct GrubFont {
    static let name = "PressStart2P-Regular"

    static func size(_ s: CGFloat) -> Font {
        .custom(name, size: s)
    }
}

// MARK: - Color Palette (Swamp Candy)
struct GrubPalette {
    static let void_color = Color(hex: "#1a1a2e")
    static let moss = Color(hex: "#16213e")
    static let green = Color(hex: "#4ecca3")
    static let pale = Color(hex: "#e8e8d0")
    static let red = Color(hex: "#e94560")
    static let yellow = Color(hex: "#f5a623")
    static let purple = Color(hex: "#7b2d8b")
    static let white = Color(hex: "#f0f0f0")
    static let moonpale = Color(hex: "#c8c8b8")
    static let dimGreen = Color(hex: "#2a7a60")
    static let grey = Color(hex: "#888880")
    static let bone = Color(hex: "#c0b89a")
    static let nearBlack = Color(hex: "#0d0d0d")
    static let deepMoss = Color(hex: "#2a2a4e")

    static let paletteMap: [Character: Color] = [
        "1": Color(hex: "#1a1a2e"),
        "2": Color(hex: "#4ecca3"),
        "3": Color(hex: "#e8e8d0"),
        "4": Color(hex: "#e94560"),
        "5": Color(hex: "#f5a623"),
        "6": Color(hex: "#7b2d8b"),
        "7": Color(hex: "#16213e"),
        "8": Color(hex: "#c8c8b8"),
        "9": Color(hex: "#2a7a60"),
        "A": Color(hex: "#ffffff"),
        "B": Color(hex: "#888880"),
        "C": Color(hex: "#c0b89a"),
        "D": Color(hex: "#0d0d0d"),
    ]
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Sprite Generator
struct SpriteRenderer {
    /// Generate a 32x32 grub sprite as a grid of palette indices
    static func makeGrubSprite(state: String, tick: Int = 0) -> [[Character]] {
        let s = 32
        var data = Array(repeating: Array(repeating: Character("0"), count: s), count: s)

        let bodyCol: Character = state == "dead" ? "B" : state == "sick" ? "9" : "2"
        let highlightCol: Character = state == "dead" ? "C" : "3"
        let bob = state == "sleeping" ? 0 : Int(sin(Double(tick) * 0.1) * 1.5)

        func px(_ r: Int, _ c: Int, _ col: Character) {
            if r >= 0 && r < s && c >= 0 && c < s { data[r][c] = col }
        }

        func circle(_ cr: Int, _ cc: Int, _ rad: Int, _ col: Character) {
            for r in (cr - rad)...(cr + rad) {
                for c in (cc - rad)...(cc + rad) {
                    if (r - cr) * (r - cr) + (c - cc) * (c - cc) <= rad * rad {
                        px(r, c, col)
                    }
                }
            }
        }

        func rect(_ r: Int, _ c: Int, _ w: Int, _ h: Int, _ col: Character) {
            for i in r..<(r + h) {
                for j in c..<(c + w) {
                    px(i, j, col)
                }
            }
        }

        let cy = 16 + bob

        // Body
        circle(cy, 16, 9, "1")
        circle(cy, 16, 8, bodyCol)

        // Highlight
        px(cy - 5, 13, highlightCol)
        px(cy - 5, 14, highlightCol)
        px(cy - 6, 14, highlightCol)

        // Arms
        if state == "playing" {
            rect(cy + 1, 4, 4, 2, "1"); rect(cy + 1, 5, 3, 1, bodyCol)
            rect(cy + 1, 24, 4, 2, "1"); rect(cy + 1, 25, 3, 1, bodyCol)
        } else {
            rect(cy + 3, 6, 3, 2, "1"); rect(cy + 3, 7, 2, 1, bodyCol)
            rect(cy + 3, 23, 3, 2, "1"); rect(cy + 3, 24, 2, 1, bodyCol)
        }

        // Eyes
        if state == "dead" {
            px(cy - 3, 12, "1"); px(cy - 2, 13, "1"); px(cy - 3, 14, "1"); px(cy - 2, 11, "1")
            px(cy - 3, 18, "1"); px(cy - 2, 19, "1"); px(cy - 3, 20, "1"); px(cy - 2, 17, "1")
        } else if state == "sleeping" {
            rect(cy - 3, 11, 4, 1, "1")
            rect(cy - 3, 17, 4, 1, "1")
        } else {
            // Glint eyes: 3x3 dark with white glint top-left
            for r in (cy-4)...(cy-2) { for c in 11...13 { px(r, c, "1") } }
            px(cy - 4, 11, "A")
            for r in (cy-4)...(cy-2) { for c in 18...20 { px(r, c, "1") } }
            px(cy - 4, 18, "A")
        }

        // Mouth
        if state == "eating" {
            rect(cy + 3, 13, 6, 3, "1"); rect(cy + 4, 14, 4, 2, "4")
        } else if state == "sad" || state == "sick" {
            px(cy + 3, 14, "1"); px(cy + 4, 13, "1"); px(cy + 4, 15, "1"); px(cy + 3, 16, "1")
        } else if state == "playing" {
            px(cy + 3, 13, "1"); px(cy + 3, 14, "1"); px(cy + 4, 14, "1"); px(cy + 4, 15, "1")
            px(cy + 3, 16, "1"); px(cy + 3, 17, "1")
        } else {
            px(cy + 3, 14, "1"); px(cy + 3, 15, "1"); px(cy + 3, 16, "1")
            px(cy + 4, 13, "1"); px(cy + 4, 17, "1")
        }

        // Sick sweat
        if state == "sick" {
            px(cy - 6, 10, "3"); px(cy - 5, 9, "3")
        }

        // Sleeping Zs
        if state == "sleeping" && tick % 60 > 20 {
            px(5, 20, "2"); px(5, 21, "2"); px(6, 20, "2"); px(6, 21, "2")
            if tick % 60 > 40 {
                px(3, 22, "2"); px(3, 23, "2"); px(4, 22, "2"); px(4, 23, "2")
            }
        }

        return data
    }

    /// Render a sprite grid to a SwiftUI Canvas context
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

    /// Draw the background scene — pixel-art cave burrow (everything snapped to grid)
    static func drawBackground(context: inout GraphicsContext, size: CGSize, isNight: Bool) {
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

        // Sky colors
        let skyTop = Color(hex: isNight ? "#08081a" : "#0e0e2a")
        let skyMid = Color(hex: isNight ? "#10102a" : "#1a1a3e")
        let skyBot = Color(hex: isNight ? "#14142e" : "#222248")

        // Banded sky (pixel rows, not smooth gradient)
        let skyBands = 8
        let skyColors = [skyTop, skyTop, skyTop, skyMid, skyMid, skyBot, skyBot, skyBot]
        let groundStart = h * 0.72
        let bandH = groundStart / CGFloat(skyBands)
        for i in 0..<skyBands {
            block(0, CGFloat(i) * bandH, w, bandH + px, skyColors[i])
        }

        // Stars (small pixel dots, night only shows more)
        let starPositions: [(CGFloat, CGFloat)] = [
            (0.1, 0.08), (0.25, 0.15), (0.45, 0.05), (0.6, 0.12),
            (0.78, 0.08), (0.92, 0.18), (0.15, 0.28), (0.5, 0.22),
            (0.85, 0.32), (0.35, 0.35), (0.7, 0.25),
        ]
        let starColor = Color(hex: isNight ? "#4ecca3" : "#2a7a60")
        for (i, (sx, sy)) in starPositions.enumerated() {
            if !isNight && i > 5 { break } // fewer stars in day
            block(sx * w, sy * groundStart, px, px, starColor.opacity(isNight ? 0.6 : 0.25))
        }

        // Stalactites from ceiling (chunky pixel blocks)
        let ceilColor = Color(hex: isNight ? "#060612" : "#0a0a1e")
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
        let rockColor = Color(hex: isNight ? "#0c0c20" : "#151538")
        let rockSpots: [(CGFloat, CGFloat, Int, Int)] = [
            (0.05, 0.3, 3, 2), (0.88, 0.25, 2, 3), (0.12, 0.5, 2, 2),
            (0.92, 0.55, 3, 2), (0.03, 0.6, 2, 1), (0.8, 0.15, 2, 2),
            (0.5, 0.45, 1, 2), (0.3, 0.55, 2, 1), (0.7, 0.5, 1, 1),
        ]
        for (rx, ry, rw, rh) in rockSpots {
            block(rx * w, ry * groundStart, CGFloat(rw) * px, CGFloat(rh) * px, rockColor)
        }

        // Ground — chunky pixel rows with earthy palette
        let dirtDark = Color(hex: "#1a3020")
        let dirtMid = Color(hex: "#243828")
        let dirtLight = Color(hex: "#1e2e1e")
        let mossGreen = Color(hex: "#2a7a60")
        let mossBright = Color(hex: "#3a9a70")
        let dirtDeep = Color(hex: "#142018")

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
                else if hash == 2 && r < 3 { color = Color(hex: "#1e3a22") }
                else { color = dirtDark }
                block(CGFloat(c) * px, y, px, px, color)
            }
        }

        // Mushrooms — blocky pixel art
        let mushData: [(CGFloat, Color, Int)] = [
            (0.08, Color(hex: "#9b3dab"), 3),
            (0.28, Color(hex: "#7b2d8b"), 2),
            (0.72, Color(hex: "#ab4dbb"), 4),
            (0.9, Color(hex: "#8b3d9b"), 2),
        ]
        for (mx, capColor, capW) in mushData {
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

        // Floating spore particles (single pixel blocks)
        let sporeColor = Color(hex: "#4ecca3")
        let sporePos: [(CGFloat, CGFloat)] = [
            (0.15, 0.3), (0.4, 0.18), (0.65, 0.38), (0.82, 0.22),
            (0.25, 0.5), (0.55, 0.55), (0.9, 0.4), (0.1, 0.6),
            (0.48, 0.42), (0.72, 0.58),
        ]
        for (sx, sy) in sporePos {
            block(sx * w, sy * groundStart, px, px, sporeColor.opacity(isNight ? 0.5 : 0.2))
        }

        // Vignette (still smooth — this is a screen effect, not world art)
        let vigGradient = Gradient(stops: [
            .init(color: .clear, location: 0.3),
            .init(color: Color.black.opacity(0.45), location: 1.0),
        ])
        context.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .radialGradient(vigGradient, center: CGPoint(x: w / 2, y: h * 0.42),
                                           startRadius: h * 0.28, endRadius: h * 0.72))
    }
}

// MARK: - Pixel Icon Renderer
struct PixelIcon {
    /// Render a small pixel-art icon as a grid of colors
    /// Each icon is defined as a grid string where characters map to colors

    static func star(size: CGFloat = 16) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 9
            // 9x9 star shape
            let grid: [String] = [
                "000010000",
                "000010000",
                "001111100",
                "011111110",
                "111111111",
                "011111110",
                "001101100",
                "001001000",
                "010000100",
            ]
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if ch == "1" {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(GrubPalette.yellow))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    static func coin(size: CGFloat = 16) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 9
            let grid: [String] = [
                "000111000",
                "001111100",
                "011151110",
                "011515110",
                "011151110",
                "011515110",
                "011151110",
                "001111100",
                "000111000",
            ]
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                    if ch == "1" {
                        context.fill(Path(rect), with: .color(GrubPalette.yellow))
                    } else if ch == "5" {
                        context.fill(Path(rect), with: .color(Color(hex: "#c8912a")))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    static func meat(size: CGFloat = 20) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 11
            let grid: [String] = [
                "00000000000",
                "00011100000",
                "00144410000",
                "01444441000",
                "01444441000",
                "01444441100",
                "00144441100",
                "00014441000",
                "00001CC1000",
                "00001CC1000",
                "00000110000",
            ]
            let colors: [Character: Color] = [
                "1": Color(hex: "#1a1a2e"),
                "4": Color(hex: "#e94560"),
                "C": Color(hex: "#c0b89a"),
            ]
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if let color = colors[ch] {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    static func gamepad(size: CGFloat = 20) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 11
            let grid: [String] = [
                "00000000000",
                "01111111100",
                "11122111110",
                "11122111110",
                "11111111110",
                "11111122110",
                "11111122110",
                "01111111100",
                "00111111000",
                "00011110000",
                "00000000000",
            ]
            let colors: [Character: Color] = [
                "1": Color(hex: "#16213e"),
                "2": Color(hex: "#4ecca3"),
            ]
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if let color = colors[ch] {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    static func pill(size: CGFloat = 20) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 9
            let grid: [String] = [
                "000111000",
                "001441100",
                "014444100",
                "014444100",
                "01AAAA100",
                "01AAAA100",
                "001AA1100",
                "000111000",
                "000000000",
            ]
            let colors: [Character: Color] = [
                "1": Color(hex: "#1a1a2e"),
                "4": Color(hex: "#e94560"),
                "A": Color(hex: "#ffffff"),
            ]
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if let color = colors[ch] {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    static func nut(size: CGFloat = 16) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 9
            let grid: [String] = [
                "000111000",
                "001111100",
                "011555110",
                "015555510",
                "015555510",
                "015555510",
                "011555110",
                "001111100",
                "000111000",
            ]
            let colors: [Character: Color] = [
                "1": Color(hex: "#1a1a2e"),
                "5": Color(hex: "#c0b89a"),
            ]
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if let color = colors[ch] {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    static func bento(size: CGFloat = 16) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 9
            let grid: [String] = [
                "111111111",
                "144414441",
                "144414441",
                "144414441",
                "111111111",
                "122212221",
                "122212221",
                "122212221",
                "111111111",
            ]
            let colors: [Character: Color] = [
                "1": Color(hex: "#1a1a2e"),
                "4": Color(hex: "#e94560"),
                "2": Color(hex: "#4ecca3"),
            ]
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if let color = colors[ch] {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    static func cake(size: CGFloat = 16) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 9
            let grid: [String] = [
                "000050000",
                "000050000",
                "001111100",
                "014444410",
                "01AAAA10",
                "014444410",
                "011111110",
                "015555510",
                "011111110",
            ]
            let colors: [Character: Color] = [
                "1": Color(hex: "#1a1a2e"),
                "4": Color(hex: "#e94560"),
                "5": Color(hex: "#f5a623"),
                "A": Color(hex: "#ffffff"),
                "0": nil,
            ].compactMapValues { $0 }
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if let color = colors[ch] {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    static func arrowLeft(size: CGFloat = 16) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 7
            let grid: [String] = [
                "0001000",
                "0011000",
                "0111110",
                "1111110",
                "0111110",
                "0011000",
                "0001000",
            ]
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if ch == "1" {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(GrubPalette.pale))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    static func arrowRight(size: CGFloat = 16) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 7
            let grid: [String] = [
                "0001000",
                "0001100",
                "0111110",
                "0111111",
                "0111110",
                "0001100",
                "0001000",
            ]
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if ch == "1" {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(GrubPalette.pale))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    static func broccoli(size: CGFloat = 16) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 9
            let grid: [String] = [
                "000222000",
                "002222200",
                "022222220",
                "022222220",
                "022222220",
                "002222200",
                "000111000",
                "000111000",
                "000111000",
            ]
            let colors: [Character: Color] = [
                "1": Color(hex: "#2a7a60"),
                "2": Color(hex: "#4ecca3"),
            ]
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if let color = colors[ch] {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    static func pizza(size: CGFloat = 16) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 9
            let grid: [String] = [
                "000010000",
                "000110000",
                "001551000",
                "001555100",
                "015555510",
                "015545510",
                "155555551",
                "155454551",
                "111111111",
            ]
            let colors: [Character: Color] = [
                "1": Color(hex: "#c0b89a"),
                "5": Color(hex: "#f5a623"),
                "4": Color(hex: "#e94560"),
            ]
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if let color = colors[ch] {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    static func carrot(size: CGFloat = 16) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 9
            let grid: [String] = [
                "000222000",
                "002020200",
                "000222000",
                "000550000",
                "000555000",
                "005555000",
                "005555500",
                "055555500",
                "005555000",
            ]
            let colors: [Character: Color] = [
                "2": Color(hex: "#4ecca3"),
                "5": Color(hex: "#f5a623"),
            ]
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if let color = colors[ch] {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    static func statsIcon(size: CGFloat = 16) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 9
            let grid: [String] = [
                "000000010",
                "000000110",
                "000001110",
                "000011110",
                "001011110",
                "011011110",
                "111011110",
                "111011110",
                "111111111",
            ]
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if ch == "1" {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(GrubPalette.green))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Scanline Overlay
struct ScanlineOverlay: View {
    var body: some View {
        Canvas { context, size in
            var y: CGFloat = 0
            while y < size.height {
                let rect = CGRect(x: 0, y: y + 2, width: size.width, height: 2)
                context.fill(Path(rect), with: .color(Color.black.opacity(0.08)))
                y += 4
            }
        }
        .allowsHitTesting(false)
    }
}
