import SwiftUI

/// Renders Grub.
///
/// For the **idle** state (the resting hero pose) this uses the authored 84×84
/// directional PNGs in `Assets.xcassets` with `.interpolation(.none)` so pixels
/// stay crisp at any scale.
///
/// For every other animation state (eating, sad, dying, sleeping, …) it falls
/// back to the existing procedural character-grid renderer, since those
/// frames are not authored as PNGs yet.
struct GrubSpriteView: View {
    let state: String
    let tick: Int
    let direction: SpriteRenderer.Direction8

    init(state: String = "idle",
         tick: Int = 0,
         direction: SpriteRenderer.Direction8 = .s) {
        self.state = state
        self.tick = tick
        self.direction = direction
    }

    var body: some View {
        if state == "idle" {
            Image(direction.assetName)
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Canvas { ctx, size in
                let grid = SpriteRenderer.makeGrubSprite(state: state, tick: tick)
                let scale = min(size.width, size.height) / 32.0
                let originX = (size.width - 32 * scale) / 2
                let originY = (size.height - 32 * scale) / 2
                SpriteRenderer.drawSprite(context: &ctx,
                                          sprite: grid,
                                          origin: CGPoint(x: originX, y: originY),
                                          scale: scale)
            }
        }
    }
}
