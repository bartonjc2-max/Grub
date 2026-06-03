import SwiftUI

/// Renders a DescentEngine frame pixel-perfect. Pure presentation — no logic.
struct DescentSceneView: View {
    let engine: DescentEngine
    var walkFrame: Int = 0          // 0..3 walk-cycle index (driven by the loop)

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
            // Fractional-tile rect for smoothly interpolated entities.
            func rectF(_ fx: Double, _ fy: Double) -> CGRect {
                CGRect(x: originX + CGFloat(fx) * tile, y: originY + CGFloat(fy) * tile,
                       width: tile, height: tile)
            }

            // Tiles
            for y in 0..<rows {
                for x in 0..<cols {
                    let t = engine.tiles[y][x]
                    let r = rect(x, y)
                    switch t {
                    case .wall:
                        // Darker base + a lighter top lip for a touch of depth.
                        ctx.fill(Path(r), with: .color(GrubPalette.deepMoss))
                        let lip = CGRect(x: r.minX, y: r.minY, width: r.width, height: max(1, tile * 0.16))
                        ctx.fill(Path(lip), with: .color(GrubPalette.moss.opacity(0.5)))
                    case .stairs:
                        drawFloor(&ctx, r, x: x, y: y, tile: tile)   // floor under the portal
                    default:
                        drawFloor(&ctx, r, x: x, y: y, tile: tile)
                    }
                }
            }

            // Exit portal on the stairs tile — clearly "go here".
            if let s = stairsTile {
                let r = rect(s.x, s.y)
                let c = CGPoint(x: r.midX, y: r.midY)
                func ring(_ frac: CGFloat, _ color: Color) {
                    let d = tile * frac
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x - d/2, y: c.y - d/2, width: d, height: d)),
                             with: .color(color))
                }
                ring(1.05, GrubPalette.yellow.opacity(0.20))   // glow
                ring(0.78, GrubPalette.yellow.opacity(0.85))
                ring(0.58, GrubPalette.void_color)             // dark mouth
                // downward chevron hint
                var chev = Path()
                let w = tile * 0.22, h = tile * 0.12, cy = c.y + tile * 0.02
                chev.move(to: CGPoint(x: c.x - w, y: cy - h))
                chev.addLine(to: CGPoint(x: c.x, y: cy + h))
                chev.addLine(to: CGPoint(x: c.x + w, y: cy - h))
                ctx.stroke(chev, with: .color(GrubPalette.yellow), lineWidth: max(1, tile * 0.06))
            }

            // Grub contact shadow (grounds him on the floor). Uses the smoothly
            // interpolated visual position so he glides tile-to-tile, not snaps.
            let gr = rectF(engine.grubVisualX, engine.grubVisualY)
            if engine.status != .dead {
                let sh = CGRect(x: gr.minX + tile*0.18, y: gr.maxY - tile*0.22,
                                width: tile*0.64, height: tile*0.20)
                ctx.fill(Path(ellipseIn: sh), with: .color(.black.opacity(0.30)))
            }

            // Enemies (slime): PNG if present else procedural spiky red blob.
            for enemy in engine.enemies {
                let ev = engine.enemyVisualPosition(enemy)
                let er = rectF(ev.x, ev.y)
                // contact shadow
                let esh = CGRect(x: er.minX + tile*0.20, y: er.maxY - tile*0.20,
                                 width: tile*0.60, height: tile*0.18)
                ctx.fill(Path(ellipseIn: esh), with: .color(.black.opacity(0.28)))
                let r = er.insetBy(dx: tile * 0.08, dy: tile * 0.08)
                if UIImage(named: "descent_slime") != nil {
                    ctx.draw(Image("descent_slime").interpolation(.none).resizable(), in: r)
                } else {
                    ctx.fill(Path(ellipseIn: r), with: .color(GrubPalette.red))
                    ctx.fill(Path(ellipseIn: r.insetBy(dx: tile*0.28, dy: tile*0.28)),
                             with: .color(.black.opacity(0.8)))
                }
                // White hit flash when freshly struck.
                if enemy.hitFlash > 0 {
                    ctx.fill(Path(ellipseIn: r), with: .color(.white.opacity(0.7)))
                }
            }

            // Grub: directional PNG (walk cycle when moving), dimmed during i-frames.
            let blink = engine.isInIFrames ? 0.45 : 1.0
            if let name = resolvedGrubAsset() {
                ctx.opacity = blink
                ctx.draw(Image(name).interpolation(.none).resizable(), in: gr)
                ctx.opacity = 1.0
            } else {
                ctx.fill(Path(ellipseIn: gr.insetBy(dx: tile*0.1, dy: tile*0.1)),
                         with: .color(GrubPalette.green.opacity(blink)))
            }

            // Attack swipe flash on the faced tile.
            if engine.attackFlashRemaining > 0 {
                let f = engine.grub + engine.facing
                ctx.fill(Path(rect(f.x, f.y)), with: .color(.white.opacity(0.35)))
            }
        }
        .background(GrubPalette.void_color)
    }

    /// Floor tile with a subtle checker so movement reads against a grid.
    private func drawFloor(_ ctx: inout GraphicsContext, _ r: CGRect, x: Int, y: Int, tile: CGFloat) {
        let base = (x + y) % 2 == 0 ? 0.32 : 0.26
        ctx.fill(Path(r), with: .color(GrubPalette.moss.opacity(base)))
    }

    /// The stairs/exit tile, if any (scanned from the engine grid).
    private var stairsTile: GridPoint? {
        for y in 0..<engine.height {
            for x in 0..<engine.width where engine.tiles[y][x] == .stairs {
                return GridPoint(x: x, y: y)
            }
        }
        return nil
    }

    /// The Grub asset to draw: the per-direction walk frame while moving,
    /// the static directional frame when idle. Falls back through walk → idle →
    /// nil (procedural ellipse) so a missing asset never blanks Grub.
    private func resolvedGrubAsset() -> String? {
        let base = dirCode(engine.facing)            // e.g. "grub_SE"
        if engine.isMoving {
            let walk = "\(base)_walk_\(walkFrame)"    // e.g. "grub_SE_walk_2"
            if UIImage(named: walk) != nil { return walk }
        }
        if UIImage(named: base) != nil { return base }
        return nil
    }

    /// Map a Direction8 to the asset-name direction code.
    private func dirCode(_ dir: Direction8) -> String {
        switch dir {
        case .n:  return "grub_N"
        case .ne: return "grub_NE"
        case .e:  return "grub_E"
        case .se: return "grub_SE"
        case .s:  return "grub_S"
        case .sw: return "grub_SW"
        case .w:  return "grub_W"
        case .nw: return "grub_NW"
        }
    }
}
