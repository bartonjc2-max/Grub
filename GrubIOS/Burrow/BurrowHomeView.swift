import SwiftUI

/// Home screen for the pixel-burrow redesign, built from the "Grub Hero Art" canvas:
/// a side-on burrow cross-section with the grub in its central chamber, the GRUB title
/// in the night sky, and buried finds marked with amber "!" (HATCH → RETURN → DIG → FEED).
struct BurrowHomeView: View {
    @StateObject private var model = BurrowHomeModel()
    @Environment(\.displayScale) private var displayScale
    @State private var showBag = false
    @State private var lastLayout: BurrowLayout?

    private static let bangHot = PixelBuffer(art: ["A", "A", "A", ".", "A"], palette: ["A": BurrowInk.white])

    var body: some View {
        GeometryReader { geo in
            let L = BurrowLayout(size: geo.size, displayScale: displayScale)
            ZStack(alignment: .topLeading) {
                BurrowBackdrop(layout: L, holes: model.holes).equatable()
                titleBlock(L, width: geo.size.width)
                TimelineView(.animation(minimumInterval: 1.0 / 24)) { tl in
                    livingLayer(L, t: tl.date.timeIntervalSinceReferenceDate)
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .clipped()
            .onAppear { place(L) }
            .onChange(of: geo.size) { _, _ in place(L) }
        }
        .ignoresSafeArea()
        .background(Color(ink: BurrowInk.sky).ignoresSafeArea())
        .overlay(alignment: .bottom) { bottomHUD }
        .overlay {
            if showBag {
                FindsBagView(bag: model.bag) { withAnimation(.easeOut(duration: 0.15)) { showBag = false } }
                    .transition(.opacity)
            }
        }
        #if DEBUG
        .task { await runDemoIfRequested() }
        #endif
    }

    private func place(_ L: BurrowLayout) {
        model.grubTop = (L.chamber.midX, L.chamber.maxY - GrubArt.height)
        lastLayout = L
    }

    #if DEBUG
    /// `-burrowDemo` launch argument: scripts dig → dig → feed → pet → Finds so the
    /// interactions can be screenshotted headlessly. Compiled out of release builds.
    private func runDemoIfRequested() async {
        guard ProcessInfo.processInfo.arguments.contains("-burrowDemo") else { return }
        func wait(_ s: Double) async { try? await Task.sleep(nanoseconds: UInt64(s * 1_000_000_000)) }
        await wait(1.5)
        guard let L = lastLayout else { return }
        model.dig(model.finds[0], in: L)
        await wait(1.5); model.dig(model.finds[1], in: L)
        await wait(1.5); model.feed()
        await wait(1.5); model.pet()
        await wait(2.0); withAnimation { showBag = true }
    }
    #endif

    // MARK: - Sky title (as the hero poster)

    private func titleBlock(_ L: BurrowLayout, width: CGFloat) -> some View {
        // Press Start 2P is an 8×8 font, so 8 cells tall puts title pixels on the world grid.
        let size = (L.cell * 8).rounded()
        let shadow = L.cell / 2
        return VStack(spacing: L.cell * 2) {
            ZStack {
                Text("GRUB").font(GrubFont.size(size)).kerning(L.cell)
                    .foregroundColor(Color(ink: BurrowInk.teal))
                    .offset(x: shadow, y: shadow)
                Text("GRUB").font(GrubFont.size(size)).kerning(L.cell)
                    .foregroundColor(Color(ink: BurrowInk.cream))
            }
            Text("DIG. MOLT. COLLECT.").font(GrubFont.size(8)).kerning(1)
                .foregroundColor(Color(ink: BurrowInk.mutedText))
        }
        .frame(width: width)
        .position(x: width / 2, y: CGFloat(L.surface - 13) * L.cell)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Animated layer (markers, grub, effects)

    @ViewBuilder
    private func livingLayer(_ L: BurrowLayout, t: TimeInterval) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(model.finds.filter { !$0.dug }) { f in marker(f, L, t) }
            grub(L, t)
            ForEach(model.fx) { e in effect(e, L, t) }
        }
    }

    @ViewBuilder
    private func marker(_ f: BuriedFind, _ L: BurrowLayout, _ t: TimeInterval) -> some View {
        let p = L.resolve(f.anchor)
        let phase = Double((f.anchor.x * 7 + f.anchor.dy) % 10) / 10
        let bob = Int(t / 0.45 + phase * 2) % 2
        let hinted = t - model.digHintAt < 1.6
        let hot = hinted && Int(t / 0.14) % 2 == 0
        let twinkle = Int(t / 0.3 + phase * 3) % 3 != 0
        let cx = L.point(Double(p.x) + 0.5, 0).x

        PixelImage(buffer: hot ? Self.bangHot : IconArt.bang, cell: L.cell)
            .position(x: cx, y: (CGFloat(p.y - 5 - bob) + 0.5) * L.cell)
        if twinkle {
            PixelImage(buffer: IconArt.sparkle, cell: L.cell)
                .position(x: cx, y: (CGFloat(p.y) + 0.5) * L.cell)
        }
        Color.clear
            .frame(width: 48, height: 64)
            .contentShape(Rectangle())
            .position(x: cx, y: CGFloat(p.y - 3) * L.cell)
            .onTapGesture { model.dig(f, in: L) }
            .accessibilityElement()
            .accessibilityLabel("Buried find")
            .accessibilityHint("Dig it up")
            .accessibilityAddTraits(.isButton)
    }

    private func grub(_ L: BurrowLayout, _ t: TimeInterval) -> some View {
        let gx = L.chamber.midX - GrubArt.width / 2
        let gy = L.chamber.maxY - GrubArt.height
        let bounce = Int(t / 0.4) % 3 == 1 ? 1 : 0
        let hopP = (t - model.hopAt) / 0.42
        let hop = (hopP >= 0 && hopP < 1) ? Int((sin(hopP * .pi) * 5).rounded()) : 0
        let chomping = t - model.chompAt < 0.9
        let blinking = t.truncatingRemainder(dividingBy: 3.7) < 0.14 || hop > 0
        let sprite = chomping ? (Int(t / 0.15) % 2 == 0 ? GrubArt.chomp : GrubArt.idle)
                              : (blinking ? GrubArt.blink : GrubArt.idle)
        let origin = L.point(Double(gx), Double(gy - bounce - hop))

        return PixelImage(buffer: sprite, cell: L.cell)
            .contentShape(Rectangle())
            .onTapGesture { model.pet() }
            .position(x: origin.x + CGFloat(GrubArt.width) * L.cell / 2,
                      y: origin.y + CGFloat(GrubArt.height) * L.cell / 2)
            .accessibilityLabel("Grub")
            .accessibilityHint("Pet your grub")
            .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private func effect(_ e: BurrowFX, _ L: BurrowLayout, _ t: TimeInterval) -> some View {
        let age = t - e.born
        let fade = age > e.life - 0.3 ? max(0, (e.life - age) / 0.3) : 1
        if age >= 0 && age < e.life {
            switch e.kind {
            case .dirt:
                ForEach(0..<9, id: \.self) { k in
                    let a = Double(k) / 9 * .pi * 2 + 0.4
                    let dx = cos(a) * 10 * age
                    let dy = (sin(a) * 6 - 11) * age + 34 * age * age
                    let ink: UInt32 = [BurrowInk.dirt, BurrowInk.surface, BurrowInk.creamDim][k % 3]
                    let c = L.point((e.x + dx).rounded() + 0.5, (e.y + dy).rounded() + 0.5)
                    Rectangle().fill(Color(ink: ink))
                        .frame(width: L.cell, height: L.cell)
                        .position(c)
                }
            case .reveal(let kind):
                let spr = kind.sprite
                let rise = (min(age / 0.3, 1) * 7).rounded()
                let c = L.point(e.x + 0.5, e.y - rise - Double(spr.height) / 2)
                PixelImage(buffer: spr, cell: L.cell)
                    .position(c)
                    .opacity(fade)
            case .text(let s, let ink):
                let rise = (age * 5).rounded()
                let c = L.point(e.x + 0.5, e.y - rise)
                pixelLabel(s, ink: ink, size: 9)
                    .position(c)
                    .opacity(fade)
            case .heart:
                let rise = (age * 9).rounded()
                let c = L.point(e.x + 0.5, e.y - 3 - rise)
                PixelImage(buffer: IconArt.heart, cell: L.cell)
                    .position(c)
                    .opacity(fade)
            }
        }
    }

    private func pixelLabel(_ s: String, ink: UInt32, size: CGFloat) -> some View {
        ZStack {
            Text(s).font(GrubFont.size(size)).foregroundColor(Color(ink: BurrowInk.hollow)).offset(x: 2, y: 2)
            Text(s).font(GrubFont.size(size)).foregroundColor(Color(ink: ink))
        }
        .fixedSize()
    }

    // MARK: - Bottom HUD (stats + actions)

    private var bottomHUD: some View {
        VStack(spacing: 10) {
            if let msg = model.toast {
                Text(msg)
                    .font(GrubFont.size(9)).lineSpacing(6).multilineTextAlignment(.center)
                    .foregroundColor(Color(ink: BurrowInk.cream))
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color(ink: BurrowInk.hollow))
                    .overlay(Rectangle().strokeBorder(Color(ink: BurrowInk.amber), lineWidth: 3))
                    .transition(.opacity)
            }
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    statBar("BELLY", model.belly, BurrowInk.berry)
                    statBar("JOY", model.joy, BurrowInk.teal)
                    statBar("MOLT", model.molt, BurrowInk.amber)
                }
                HStack(spacing: 10) {
                    hudButton(icon: FindKind.berry.sprite, title: "FEED", count: model.foodCount) { model.feed() }
                    hudButton(icon: IconArt.shovel, title: "DIG", count: model.digsLeft,
                              hot: model.digsLeft > 0 && model.finds.contains { !$0.dug }) { model.digHint() }
                    hudButton(icon: IconArt.pouch, title: "FINDS", count: model.findCount) {
                        withAnimation(.easeOut(duration: 0.15)) { showBag = true }
                    }
                }
            }
            .padding(12)
            .background(Color(ink: BurrowInk.hollow))
            .overlay(Rectangle().strokeBorder(Color(ink: BurrowInk.soil1), lineWidth: 4))
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
        .animation(.easeOut(duration: 0.15), value: model.toast)
    }

    private func statBar(_ label: String, _ value: Int, _ ink: UInt32) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).font(GrubFont.size(7)).foregroundColor(Color(ink: BurrowInk.cream))
            HStack(spacing: 2) {
                ForEach(0..<BurrowHomeModel.maxStat, id: \.self) { i in
                    Rectangle().fill(Color(ink: i < value ? ink : BurrowInk.soil1)).frame(height: 9)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label.capitalized) \(value) of \(BurrowHomeModel.maxStat)")
    }

    private func hudButton(icon: PixelBuffer, title: String, count: Int, hot: Bool = false,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                PixelImage(buffer: icon, cell: 4)
                Text(title).font(GrubFont.size(8)).foregroundColor(Color(ink: BurrowInk.cream))
            }
            .frame(maxWidth: .infinity, minHeight: 62)
            .background(Color(ink: BurrowInk.soil4))
            .overlay(Rectangle().strokeBorder(Color(ink: hot ? BurrowInk.amber : BurrowInk.soil1), lineWidth: 3))
            .overlay(alignment: .topTrailing) {
                Text("\(count)")
                    .font(GrubFont.size(8))
                    .foregroundColor(Color(ink: BurrowInk.hollow))
                    .padding(.horizontal, 5).padding(.vertical, 4)
                    .background(Color(ink: count > 0 ? BurrowInk.amber : BurrowInk.creamDim))
                    .offset(x: 4, y: -6)
            }
        }
        .buttonStyle(PixelPressStyle())
        .accessibilityLabel("\(title.capitalized), \(count)")
    }
}

// MARK: - Pieces

/// The static burrow bitmap; only re-rendered when the layout or the dug holes change.
struct BurrowBackdrop: View, Equatable {
    let layout: BurrowLayout
    let holes: [CellAnchor]

    var body: some View {
        PixelImage(buffer: BurrowArt.backdrop(layout, holes: holes), cell: layout.cell)
            .offset(x: layout.originX)
            .accessibilityHidden(true)
    }
}

struct PixelPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.offset(y: configuration.isPressed ? 2 : 0)
    }
}

/// What the grub has dug up. Berries feed it; the rest becomes decor (gameplay-flow step 4).
struct FindsBagView: View {
    let bag: [FindKind: Int]
    let close: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea().onTapGesture(perform: close)
            VStack(spacing: 18) {
                Text("FINDS").font(GrubFont.size(14)).foregroundColor(Color(ink: BurrowInk.cream))
                HStack(spacing: 10) {
                    ForEach(FindKind.allCases) { k in
                        let n = bag[k] ?? 0
                        VStack(spacing: 8) {
                            PixelImage(buffer: n > 0 ? k.sprite : k.sprite.silhouette(BurrowInk.root), cell: 6)
                                .frame(width: 60, height: 60)
                                .background(Color(ink: n > 0 ? BurrowInk.cream : BurrowInk.soil4))
                                .overlay(Rectangle().strokeBorder(Color(ink: n > 0 ? BurrowInk.amberLo : BurrowInk.soil1), lineWidth: 3))
                                .accessibilityLabel(n > 0 ? "\(k.label.capitalized), \(n)" : "Not found yet")
                            Text(n > 0 ? k.label : "???").font(GrubFont.size(6))
                                .foregroundColor(Color(ink: BurrowInk.cream))
                            Text(n > 0 ? "x\(n)" : " ").font(GrubFont.size(8))
                                .foregroundColor(Color(ink: BurrowInk.amber))
                        }
                    }
                }
                Text("BERRIES FEED YOUR GRUB.\nTHE REST WILL BE DECOR.")
                    .font(GrubFont.size(7)).lineSpacing(6).multilineTextAlignment(.center)
                    .foregroundColor(Color(ink: BurrowInk.mutedText))
                Button(action: close) {
                    Text("CLOSE").font(GrubFont.size(10)).foregroundColor(Color(ink: BurrowInk.hollow))
                        .padding(.horizontal, 22).padding(.vertical, 12)
                        .background(Color(ink: BurrowInk.amber))
                }
                .buttonStyle(PixelPressStyle())
            }
            .padding(20)
            .background(Color(ink: BurrowInk.hollow))
            .overlay(Rectangle().strokeBorder(Color(ink: BurrowInk.soil1), lineWidth: 4))
            .padding(20)
        }
    }
}

#Preview {
    BurrowHomeView()
}
