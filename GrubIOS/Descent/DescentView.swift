import SwiftUI

/// Hosts the scene + controls, drives the engine from a TimelineView loop,
/// and shows the win/death result card. Self-contained; takes a dismiss closure.
struct DescentView: View {
    var onExit: () -> Void

    @State private var engine = DescentEngine(layout: DescentEngine.prototypeRoom)
    @State private var lastTick: TimeInterval? = nil

    var body: some View {
        ZStack {
            GrubPalette.void_color.ignoresSafeArea()

            TimelineView(.animation) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                let shake = shakeOffset(now: now)
                // Render the scene; advance the engine as a side-effect of the tick.
                DescentSceneView(engine: engine)
                    .ignoresSafeArea()
                    .offset(x: shake.width, y: shake.height)
                    .onChange(of: now) { _, t in step(to: t) }
            }

            // Top HUD: hearts + the objective so the goal is never a mystery.
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    ForEach(0..<engine.tuning.startHearts, id: \.self) { i in
                        Image(systemName: i < engine.hearts ? "heart.fill" : "heart")
                            .foregroundColor(GrubPalette.red)
                    }
                    Spacer()
                }
                HStack(spacing: 6) {
                    Text("REACH THE PORTAL")
                        .font(GrubFont.size(10))
                        .foregroundColor(GrubPalette.yellow)
                    Spacer()
                }
                Spacer()
            }
            .padding(.horizontal, 18).padding(.top, 12)

            // Controls
            VStack {
                Spacer()
                DescentControlsView(
                    onMove: { engine.setMove($0) },
                    onAttack: { engine.attack() },
                    onInteract: { engine.interact() },
                    interactEnabled: engine.tile(at: engine.grub) == .stairs
                )
            }

            // Hit flash — brief red wash on contact so damage reads clearly.
            if engine.hurtFlashRemaining > 0 {
                let intensity = engine.hurtFlashRemaining / engine.tuning.hurtFlashDuration
                GrubPalette.red.opacity(0.38 * intensity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            if engine.status != .playing { resultCard }
        }
        .statusBarHidden()
    }

    /// Small screen shake driven by the engine's flash timers — bigger on a hurt,
    /// a touch on a hit. Oscillates with wall-clock time so it reads as a shudder.
    private func shakeOffset(now: TimeInterval) -> CGSize {
        let mag = (engine.hurtFlashRemaining > 0 ? 7.0 : 0) + (engine.attackFlashRemaining > 0 ? 2.5 : 0)
        guard mag > 0 else { return .zero }
        return CGSize(width: CGFloat(sin(now * 90) * mag),
                      height: CGFloat(cos(now * 110) * mag))
    }

    private func step(to t: TimeInterval) {
        defer { lastTick = t }
        guard let last = lastTick else { return }
        let dt = min(t - last, 1.0 / 20.0)        // clamp to avoid huge jumps
        guard dt > 0 else { return }
        engine.update(dt)
    }

    private var resultCard: some View {
        VStack(spacing: 20) {
            Text(engine.status == .won ? "YOU MADE IT" : "YOU DIED")
                .font(GrubFont.size(20))
                .foregroundColor(engine.status == .won ? GrubPalette.green : GrubPalette.red)
            Button(action: onExit) {
                Text("BACK")
                    .font(GrubFont.size(14))
                    .foregroundColor(GrubPalette.void_color)
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background(GrubPalette.pale)
            }
            .buttonStyle(PixelButtonStyle())
        }
        .padding(36)
        .background(GrubPalette.void_color.opacity(0.92))
    }
}
