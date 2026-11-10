import SwiftUI

/// "Grub & the Deep" — new-direction care Home screen (visual prototype).
/// 3-zone HUD: top stat strip (Belly / Bond framing the lantern), center hero stage
/// (Grub in the nest), a delve tunnel-mouth low-center, and a compact care bar.
/// Values are placeholder; interactivity + real GameState come in later passes.
struct GrubDeepHomeView: View {
    @State private var waddle = false

    // Warm cave palette (no blue / no purple).
    private let caveDark = Color(hex: "#17100c")
    private let panelBg  = Color(hex: "#241a12")
    private let btnBg     = Color(hex: "#39291a")
    private let line     = Color(hex: "#3b2c20")
    private let amber    = Color(hex: "#f2a94e")
    private let amberHi  = Color(hex: "#ffc877")
    private let ember    = Color(hex: "#e8692f")
    private let moss     = Color(hex: "#9ac64c")
    private let cream    = Color(hex: "#f4e9d6")

    private let grubWidth: CGFloat = 0.36
    private let grubCenterY: CGFloat = 0.57
    private let delveCenterY: CGFloat = 0.80

    var body: some View {
        ZStack {
            // Full-bleed scene: background, Grub, and the delve tunnel set into the floor.
            GeometryReader { geo in
                ZStack {
                    Image("bg_home_deep")
                        .resizable().interpolation(.none).scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height).clipped()

                    Image("grub_deep_s")
                        .resizable().interpolation(.none).scaledToFit()
                        .frame(width: geo.size.width * grubWidth)
                        .rotationEffect(.degrees(waddle ? 4 : -4), anchor: .bottom)
                        .offset(y: waddle ? -4 : 0)
                        .animation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true), value: waddle)
                        .position(x: geo.size.width * 0.5, y: geo.size.height * grubCenterY)

                    delveTunnel()
                        .position(x: geo.size.width * 0.5, y: geo.size.height * delveCenterY)
                }
            }
            .ignoresSafeArea()

            // HUD — respects the safe area.
            VStack(spacing: 0) {
                // Top stat strip: Belly (left) + Bond (right), framing the lantern.
                HStack(alignment: .top) {
                    statCluster(icon: "fork.knife", label: "BELLY", value: 0.72, tint: amber)
                    Spacer()
                    statCluster(icon: "sparkles", label: "BOND", value: 0.55, tint: moss, trailing: true)
                }
                .padding(.horizontal, 12)
                .padding(.top, 6)

                // Centered name + level pills.
                HStack(spacing: 6) {
                    Text("GRUB").font(GrubFont.size(10)).foregroundColor(cream)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(caveDark.opacity(0.5)))
                    Text("Lv 3").font(GrubFont.size(7)).foregroundColor(caveDark)
                        .padding(.horizontal, 7).padding(.vertical, 5)
                        .background(Capsule().fill(amberHi))
                }
                .padding(.top, 6)

                Spacer()

                // Compact care bar (floats, knocked back so Grub stays the star).
                HStack(spacing: 14) {
                    careButton(icon: "fork.knife", title: "FEED", tint: amber)
                    careButton(icon: "heart.fill", title: "PLAY", tint: moss)
                }
                .padding(.bottom, 10)
            }
        }
        .onAppear { waddle = true }
    }

    // MARK: - Components

    private func statCluster(icon: String, label: String, value: CGFloat, tint: Color, trailing: Bool = false) -> some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 10, weight: .bold)).foregroundColor(tint)
                Text(label).font(GrubFont.size(8)).foregroundColor(cream)
            }
            ZStack(alignment: .leading) {
                Capsule().fill(caveDark).frame(width: 94, height: 9)
                Capsule().fill(tint).frame(width: 94 * value, height: 9)
            }
        }
        .padding(7)
        .background(RoundedRectangle(cornerRadius: 10).fill(panelBg.opacity(0.92)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(line, lineWidth: 2))
    }

    private func careButton(icon: String, title: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 17, weight: .bold)).foregroundColor(cream)
            Text(title).font(GrubFont.size(8)).foregroundColor(cream)
        }
        .frame(width: 120)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 13).fill(btnBg))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(tint, lineWidth: 2))
    }

    /// A glowing tunnel mouth set into the dirt floor — "tap the tunnel = descend to delve".
    private func delveTunnel() -> some View {
        VStack(spacing: 5) {
            ZStack {
                // Shadow pool — seats the tunnel into the dirt floor.
                Ellipse().fill(Color.black.opacity(0.32)).frame(width: 118, height: 44)
                    .blur(radius: 9).offset(y: 17)
                Ellipse()
                    .fill(RadialGradient(colors: [Color(hex: "#3a2714"), caveDark],
                                         center: .center, startRadius: 2, endRadius: 48))
                    .frame(width: 96, height: 56)
                Ellipse().fill(amber.opacity(0.20)).frame(width: 58, height: 30).blur(radius: 7)
                Ellipse().stroke(ember, lineWidth: 3).frame(width: 96, height: 56)
                Image(systemName: "stairs").font(.system(size: 22, weight: .heavy)).foregroundColor(amberHi)
            }
            Text("DELVE").font(GrubFont.size(8)).foregroundColor(cream)
                .padding(.horizontal, 9).padding(.vertical, 3)
                .background(Capsule().fill(caveDark.opacity(0.72)))
        }
    }
}

#Preview {
    GrubDeepHomeView()
}
