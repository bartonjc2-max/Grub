import SwiftUI

// MARK: - Game Font
struct GrubFont {
    static let name = "PressStart2P-Regular"

    static func size(_ s: CGFloat) -> Font {
        .custom(name, size: s)
    }
}
