import SwiftUI

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

    // MARK: - Pixel Grid Helper

    static func pixelGrid(size: CGFloat, grid: [String], colors: [Character: Color]) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / CGFloat(grid[0].count)
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

    // MARK: - Ingredient Icons

    static func mossClump(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "000000000", "000220000", "002222000", "022222200",
            "022922200", "022222200", "002222000", "000220000", "000000000",
        ], colors: ["2": Color(hex: "#4ecca3"), "9": Color(hex: "#2a7a60")])
    }

    static func caveBeetle(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "000000000", "001000100", "010111010", "011111110",
            "011171110", "011111110", "010111010", "001000100", "000000000",
        ], colors: ["1": Color(hex: "#1a1a2e"), "7": Color(hex: "#16213e")])
    }

    static func mudRoot(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "000010000", "000110000", "001551000", "000155100",
            "000155100", "001551000", "001550000", "000550000", "000000000",
        ], colors: ["1": Color(hex: "#1a1a2e"), "5": Color(hex: "#c0b89a")])
    }

    static func dewDrop(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "000010000", "000110000", "001221000", "012222100",
            "012A22100", "012222100", "001221000", "000110000", "000000000",
        ], colors: ["1": Color(hex: "#1a1a2e"), "2": Color(hex: "#4ecca3"), "A": Color(hex: "#ffffff")])
    }

    static func glowshroom(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "000666000", "006666600", "066A66600", "066666600",
            "006666600", "000111000", "000555000", "000555000", "000000000",
        ], colors: ["6": Color(hex: "#7b2d8b"), "A": Color(hex: "#ffffff"), "1": Color(hex: "#1a1a2e"), "5": Color(hex: "#c0b89a")])
    }

    static func crystalShard(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "000010000", "000110000", "001221000", "001AA1000",
            "012AA2100", "012222100", "012222100", "001111000", "000000000",
        ], colors: ["1": Color(hex: "#1a1a2e"), "2": Color(hex: "#4ecca3"), "A": Color(hex: "#ffffff")])
    }

    static func paleWorm(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "000000000", "033000000", "033300000", "003330000",
            "000333000", "000033300", "000003330", "000000330", "000000000",
        ], colors: ["3": Color(hex: "#e8e8d0")])
    }

    static func slimeBerry(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "000220000", "002002000", "001441000", "014444100",
            "014A44100", "014444100", "001441000", "000110000", "000000000",
        ], colors: ["1": Color(hex: "#1a1a2e"), "2": Color(hex: "#4ecca3"), "4": Color(hex: "#e94560"), "A": Color(hex: "#ffffff")])
    }

    static func moonPetal(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "000010000", "000110000", "001AA1000", "01AAAA100",
            "01ABAA100", "01AAAA100", "001AA1000", "000110000", "000000000",
        ], colors: ["1": Color(hex: "#1a1a2e"), "A": Color(hex: "#ffffff"), "B": Color(hex: "#c8c8b8")])
    }

    static func emberSeed(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "000050000", "000550000", "001551000", "015555100",
            "015A55100", "015555100", "001551000", "000110000", "000000000",
        ], colors: ["1": Color(hex: "#1a1a2e"), "5": Color(hex: "#f5a623"), "A": Color(hex: "#ffffff")])
    }

    static func ancientSpore(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "000060000", "006566000", "065656600", "065A56600",
            "065656600", "006566000", "000660000", "000000000", "000000000",
        ], colors: ["6": Color(hex: "#7b2d8b"), "5": Color(hex: "#f5a623"), "A": Color(hex: "#ffffff")])
    }

    static func goldenBug(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "000000000", "001000100", "010555010", "055555550",
            "055A55550", "055555550", "010555010", "001000100", "000000000",
        ], colors: ["1": Color(hex: "#1a1a2e"), "5": Color(hex: "#f5a623"), "A": Color(hex: "#ffffff")])
    }

    // MARK: - UI Icons

    static func heart(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "011011000", "111111100", "111111100", "111111100",
            "011111000", "001110000", "000100000", "000000000", "000000000",
        ], colors: ["1": Color(hex: "#e94560")])
    }

    static func leaf(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "000001100", "000011000", "000112000", "001122000",
            "012220000", "022200000", "012000000", "001000000", "000000000",
        ], colors: ["1": Color(hex: "#2a7a60"), "2": Color(hex: "#4ecca3")])
    }

    static func bag(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "001111000", "010000100", "011111100", "015555100",
            "015555100", "015555100", "015555100", "011111100", "000000000",
        ], colors: ["1": Color(hex: "#1a1a2e"), "5": Color(hex: "#c0b89a")])
    }

    static func drumstick(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "000111000", "001444100", "014444100", "014444100",
            "001441000", "000110000", "000550000", "000550000", "000000000",
        ], colors: ["1": Color(hex: "#1a1a2e"), "4": Color(hex: "#e94560"), "5": Color(hex: "#c0b89a")])
    }

    // Shovel — for DIG button
    static func shovel(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "000030000",
            "000130000",
            "000130000",
            "000130000",
            "000130000",
            "012222210",
            "122222210",
            "012222100",
            "001111000",
        ], colors: [
            "1": Color(hex: "#1a1a2e"),
            "2": Color(hex: "#888880"),
            "3": Color(hex: "#c0b89a"),
        ])
    }

    // Chest — for PACK button
    static func chest(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "000000000",
            "011111110",
            "155555510",
            "155555510",
            "111111110",
            "155525510",
            "155555510",
            "155555510",
            "111111110",
        ], colors: [
            "1": Color(hex: "#1a1a2e"),
            "5": Color(hex: "#c0b89a"),
            "2": Color(hex: "#f5a623"),
        ])
    }

    // Book — for JOURNAL button
    static func book(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "000000000",
            "011111100",
            "015555100",
            "015555100",
            "011111100",
            "015555100",
            "015555100",
            "011111100",
            "000000000",
        ], colors: [
            "1": Color(hex: "#4ecca3"),
            "5": Color(hex: "#e8e8d0"),
        ])
    }

    // Gear — for SETTINGS button
    static func gear(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "010010100",
            "011111100",
            "011111100",
            "111111110",
            "011111100",
            "011111100",
            "010110100",
            "000110000",
            "000000000",
        ], colors: [
            "1": Color(hex: "#c0b89a"),
        ])
    }

    // Dice — for PLAY button
    static func dice(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "000000000",
            "011111110",
            "017111710",
            "011111110",
            "011171110",
            "011111110",
            "017111710",
            "011111110",
            "000000000",
        ], colors: [
            "1": Color(hex: "#e8e8d0"),
            "7": Color(hex: "#1a1a2e"),
        ])
    }

    // MARK: - Ingredient Icon Mapper

    @ViewBuilder
    static func ingredientIcon(_ id: String, size: CGFloat = 16) -> some View {
        switch id {
        case "moss_clump": mossClump(size: size)
        case "cave_beetle": caveBeetle(size: size)
        case "mud_root": mudRoot(size: size)
        case "dew_drop": dewDrop(size: size)
        case "glowshroom": glowshroom(size: size)
        case "crystal_shard": crystalShard(size: size)
        case "pale_worm": paleWorm(size: size)
        case "slime_berry": slimeBerry(size: size)
        case "moon_petal": moonPetal(size: size)
        case "ember_seed": emberSeed(size: size)
        case "ancient_spore": ancientSpore(size: size)
        case "golden_bug": goldenBug(size: size)
        default: mossClump(size: size)
        }
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
