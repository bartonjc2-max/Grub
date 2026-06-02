import SwiftUI

/// Renders a DescentEngine frame pixel-perfect. Pure presentation — no logic.
struct DescentSceneView: View {
    let engine: DescentEngine

    var body: some View {
        Canvas { ctx, size in
            let cols = engine.width, rows = engine.height
            guard cols > 0, rows > 0 else { return }
            let tile = (size.width / CGFloat(cols)).rounded(.down)
            let originX = ((size.width - tile * CGFloat(cols)) / 2).rounded()
            let originY = ((size.height - tile * CGFloat(rows)) / 2).rounded()
            func rect(_ x: Int, _ y: Int) -> CGRect {
                CGRect(x: originX + CGFloat(x) * tile, y: originY + CGFloat(y) * tile,
                       width: tile, height: tile)
            }

            // Tiles
            for y in 0..<rows {
                for x in 0..<cols {
                    let t = engine.tiles[y][x]
                    let color: Color
                    switch t {
                    case .wall:   color = GrubPalette.deepMoss
                    case .stairs: color = GrubPalette.yellow.opacity(0.85)
                    default:      color = GrubPalette.moss.opacity(0.35)
                    }
                    ctx.fill(Path(rect(x, y)), with: .color(color))
                }
            }

            // Enemies (slime): PNG if present else procedural spiky red blob.
            for enemy in engine.enemies {
                let r = rect(enemy.tile.x, enemy.tile.y).insetBy(dx: tile * 0.1, dy: tile * 0.1)
                if let _ = UIImage(named: "descent_slime") {
                    ctx.draw(Image("descent_slime").interpolation(.none).resizable(),
                             in: r)
                } else {
                    ctx.fill(Path(ellipseIn: r), with: .color(GrubPalette.red))
                    ctx.fill(Path(ellipseIn: r.insetBy(dx: tile*0.28, dy: tile*0.28)),
                             with: .color(.black.opacity(0.8)))   // angry core
                }
            }

            // Grub: directional PNG, dimmed/blinking during i-frames.
            let gr = rect(engine.grub.x, engine.grub.y)
            let blink = engine.isInIFrames ? 0.45 : 1.0
            let assetName = grubAsset(for: engine.facing)
            if let _ = UIImage(named: assetName) {
                ctx.opacity = blink
                ctx.draw(Image(assetName).interpolation(.none).resizable(), in: gr)
                ctx.opacity = 1.0
            } else {
                ctx.fill(Path(ellipseIn: gr.insetBy(dx: tile*0.1, dy: tile*0.1)),
                         with: .color(GrubPalette.green.opacity(blink)))
            }

            // Attack flash on the faced tile.
            if engine.attackFlashRemaining > 0 {
                let f = engine.grub + engine.facing
                ctx.fill(Path(rect(f.x, f.y)), with: .color(.white.opacity(0.5)))
            }
        }
        .background(GrubPalette.void_color)
    }

    /// Map a Direction8 to the existing 8-dir Grub asset names.
    private func grubAsset(for dir: Direction8) -> String {
        switch dir {
        case .n: return "grub_N"
        case .ne: return "grub_NE"
        case .e: return "grub_E"
        case .se: return "grub_SE"
        case .s: return "grub_S"
        case .sw: return "grub_SW"
        case .w: return "grub_W"
        case .nw: return "grub_NW"
        }
    }
}
