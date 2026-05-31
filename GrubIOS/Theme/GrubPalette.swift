import SwiftUI

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
    static let orange = Color(hex: "#e07020")

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
        "E": Color(hex: "#e07020"),
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
