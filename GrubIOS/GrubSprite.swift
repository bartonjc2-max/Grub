import SwiftUI
import PetEngine

final class GrubSprite: SpriteProvider {

    func makeSpriteGrid(state: String, frame: Int) -> [[Character]] {
        SpriteRenderer.makeGrubSprite(state: state, tick: frame)
    }

    func drawBackground(context: inout GraphicsContext, size: CGSize, frame: Int, theme: any ThemeProvider) {
        SpriteRenderer.drawBackground(context: &context, size: size, tick: frame)
    }
}
