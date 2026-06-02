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
                // Render the scene; advance the engine as a side-effect of the tick.
                DescentSceneView(engine: engine)
                    .ignoresSafeArea()
                    .onChange(of: now) { _, t in step(to: t) }
            }

            // Hearts HUD (top-left)
            VStack {
                HStack(spacing: 4) {
                    ForEach(0..<engine.tuning.startHearts, id: \.self) { i in
                        Image(systemName: i < engine.hearts ? "heart.fill" : "heart")
                            .foregroundColor(GrubPalette.red)
                    }
                    Spacer()
                }
                .padding(.horizontal, 18).padding(.top, 12)
                Spacer()
            }

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
