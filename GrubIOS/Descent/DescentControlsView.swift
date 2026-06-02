import SwiftUI

/// Left thumb: drag joystick (8-way quantized). Right thumb: Attack / Interact.
/// Emits intents via closures — holds no game state.
struct DescentControlsView: View {
    var onMove: (Direction8?) -> Void
    var onAttack: () -> Void
    var onInteract: () -> Void
    var interactEnabled: Bool

    @State private var knob: CGSize = .zero
    private let radius: CGFloat = 55

    var body: some View {
        HStack(alignment: .bottom) {
            joystick
            Spacer()
            buttons
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 36)
    }

    private var joystick: some View {
        ZStack {
            Circle().fill(GrubPalette.moss.opacity(0.30)).frame(width: radius * 2, height: radius * 2)
            Circle().fill(GrubPalette.pale.opacity(0.7)).frame(width: 46, height: 46)
                .offset(knob)
        }
        .frame(width: radius * 2, height: radius * 2)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    let clamped = clamp(v.translation, to: radius)
                    knob = clamped
                    onMove(Direction8.from(dx: Double(clamped.width), dy: Double(clamped.height)))
                }
                .onEnded { _ in knob = .zero; onMove(nil) }
        )
    }

    private var buttons: some View {
        VStack(spacing: 16) {
            actionButton("DIG IN", color: GrubPalette.green, enabled: interactEnabled, action: onInteract)
            actionButton("HIT", color: GrubPalette.red, enabled: true, action: onAttack)
        }
    }

    private func actionButton(_ label: String, color: Color, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(GrubFont.size(12))
                .foregroundColor(GrubPalette.void_color)
                .frame(width: 84, height: 64)
                .background(color.opacity(enabled ? 0.9 : 0.3))
        }
        .disabled(!enabled)
        .buttonStyle(PixelButtonStyle())
    }

    private func clamp(_ t: CGSize, to r: CGFloat) -> CGSize {
        let mag = (t.width * t.width + t.height * t.height).squareRoot()
        guard mag > r, mag > 0 else { return t }
        return CGSize(width: t.width / mag * r, height: t.height / mag * r)
    }
}
