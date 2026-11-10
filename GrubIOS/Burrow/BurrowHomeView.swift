import SwiftUI

/// Home screen for the pixel-burrow redesign, built from the "Grub Hero Art" canvas:
/// a side-on burrow cross-section with the grub in its central chamber, the GRUB title
/// in the night sky, and buried finds marked with amber "!" (HATCH → RETURN → DIG → FEED).
struct BurrowHomeView: View {
    @StateObject private var model = BurrowHomeModel()
    @Environment(\.displayScale) private var displayScale
    @State private var showBag = false
    @Environment(\.scenePhase) private var scenePhase
    private let minuteTick = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

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
                FindsBagView(bag: model.bag, canAct: model.canAct, freeSlots: model.freeSlots.count,
                             onEat: { k in closeBag(); model.feed(kind: k) },
                             onPlace: { k in closeBag(); model.startPlacing(k) },
                             close: closeBag)
                    .transition(.opacity)
            }
        }
        .onReceive(minuteTick) { _ in model.tick() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: model.tick()
            case .background: model.persist()
            default: break
            }
        }
        #if DEBUG
        .task {
            if BurrowDebug.showBag { showBag = true }
            await runDemoIfRequested()
        }
        #endif
    }

    private func place(_ L: BurrowLayout) {
        model.grubTop = (L.chamber.midX, L.chamber.maxY - GrubArt.height)
        model.layout = L
    }

    private func closeBag() { withAnimation(.easeOut(duration: 0.15)) { showBag = false } }

    #if DEBUG
    /// `-burrowDemo` (use with `-burrowReset`). Times are seconds after the view appears:
    ///  1.5/3.0/4.5 dig all three · 6.0 eat berry · 7.5 eat root (variety → +joy; fed state until 10.0)
    /// 10.0 start placing the crystal (slots glow until 12.5) · 12.5 place it in slot 2
    /// 15.0 pet · 16.0 select the crystal (REMOVE bar until 19.0) · 19.0 remove · 21.5 open Finds
    private func runDemoIfRequested() async {
        guard BurrowDebug.demo else { return }
        func wait(_ s: Double) async { try? await Task.sleep(nanoseconds: UInt64(s * 1_000_000_000)) }
        await wait(1.5)
        for _ in 0..<3 {
            if let f = model.buried.first { model.dig(spot: f.spot) }
            await wait(1.5)
        }
        model.feed(); await wait(1.5)                   //  6.0
        model.feed(); await wait(2.5)                   //  7.5
        model.startPlacing(.crystal); await wait(2.5)   // 10.0
        model.tapSlot(2); await wait(2.5)               // 12.5
        model.pet(); await wait(1.0)                    // 15.0
        model.tapSlot(2); await wait(3.0)               // 16.0
        model.removeSelected(); await wait(2.5)         // 19.0
        withAnimation { showBag = true }                // 21.5
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
            ForEach(0..<BurrowRules.decorSlots, id: \.self) { i in decorSlot(i, L, t) }
            ForEach(model.buried, id: \.spot) { f in
                if let a = BurrowSpots.anchor(f.spot) { marker(spot: f.spot, anchor: a, L, t) }
            }
            grub(L, t)
            ForEach(model.fx) { e in effect(e, L, t) }
        }
    }

    @ViewBuilder
    private func marker(spot: Int, anchor: CellAnchor, _ L: BurrowLayout, _ t: TimeInterval) -> some View {
        let p = L.resolve(anchor)
        let phase = Double((anchor.x * 7 + anchor.dy) % 10) / 10
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
            .onTapGesture { model.dig(spot: spot) }
            .accessibilityElement()
            .accessibilityLabel("Buried find")
            .accessibilityHint("Dig it up")
            .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private func decorSlot(_ i: Int, _ L: BurrowLayout, _ t: TimeInterval) -> some View {
        if let p = L.decorSlot(i) {
            let kind = model.placed[i]
            let lit = model.placing != nil && kind == nil && Int(t / 0.3) % 2 == 0
            let selected = model.selectedSlot == i
            let base = L.point(Double(p.x - 3), Double(p.y))
            PixelImage(buffer: lit ? IconArt.pedestalLit : IconArt.pedestalDim, cell: L.cell)
                .position(x: base.x + 3 * L.cell, y: base.y + L.cell)
            if let kind {
                let spr = kind.sprite
                let bob = selected && Int(t / 0.25) % 2 == 0 ? 1 : 0
                // Whole-cell top-left so 5-wide sprites stay on the pixel grid: centred on the
                // 6-wide pedestal (x-3…x+2), bottom row just above the pedestal top (row p.y).
                let left = p.x - 3 + (6 - spr.width) / 2
                let top = p.y - bob - spr.height
                let o = L.point(Double(left), Double(top))
                PixelImage(buffer: spr, cell: L.cell)
                    .position(x: o.x + CGFloat(spr.width) * L.cell / 2,
                              y: o.y + CGFloat(spr.height) * L.cell / 2)
            }
            let tappable = (model.placing != nil && kind == nil) || (model.placing == nil && kind != nil)
            if tappable {
                Color.clear
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
                    .position(L.point(Double(p.x), Double(p.y - 3)))
                    .onTapGesture { model.tapSlot(i) }
                    .accessibilityElement()
                    .accessibilityLabel(kind.map { "\($0.label.capitalized) decoration" } ?? "Empty spot")
                    .accessibilityHint(kind == nil ? "Place it here" : "Remove it")
                    .accessibilityAddTraits(.isButton)
            }
        }
    }

    private func grub(_ L: BurrowLayout, _ t: TimeInterval) -> some View {
        let gx = L.chamber.midX - GrubArt.width / 2
        let gy = L.chamber.maxY - GrubArt.height
        let sulking = model.isSulking
        let bounce = !sulking && Int(t / 0.4) % 3 == 1 ? 1 : 0
        let hopP = (t - model.hopAt) / 0.42
        let hop = (hopP >= 0 && hopP < 1) ? Int((sin(hopP * .pi) * 5).rounded()) : 0
        let chomping = t - model.chompAt < 0.9
        let blinking = t.truncatingRemainder(dividingBy: 3.7) < 0.14 || hop > 0
        let sprite = chomping ? (Int(t / 0.15) % 2 == 0 ? GrubArt.chomp : GrubArt.idle)
                              : (blinking ? GrubArt.blink : (sulking ? GrubArt.sulk : GrubArt.idle))
        let origin = L.point(Double(gx), Double(gy - bounce - hop))

        return PixelImage(buffer: sprite, cell: L.cell)
            .contentShape(Rectangle())
            .onTapGesture { model.pet() }
            .position(x: origin.x + CGFloat(GrubArt.width) * L.cell / 2,
                      y: origin.y + CGFloat(GrubArt.height) * L.cell / 2)
            .accessibilityLabel(sulking ? "Grub, hungry and sulking" : "Grub")
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
            if let msg = model.toast {      // toasts stay visible above a bar (e.g. TOO FULL! while placing)
                Text(msg)
                    .font(GrubFont.size(9)).lineSpacing(6).multilineTextAlignment(.center)
                    .foregroundColor(Color(ink: BurrowInk.cream))
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color(ink: BurrowInk.hollow))
                    .overlay(Rectangle().strokeBorder(Color(ink: BurrowInk.amber), lineWidth: 3))
                    .transition(.opacity)
            }
            if let kind = model.placing {
                hudBar("PLACE \(kind.label):\nTAP A GLOWING SPOT", button: "CANCEL",
                       action: { model.cancelPlacing() })
            } else if let slot = model.selectedSlot, let kind = model.placed[slot] {
                hudBar("REMOVE \(kind.label)?", button: "REMOVE", secondary: "KEEP",
                       action: { model.removeSelected() }, secondaryAction: { model.clearSelection() })
            }
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    statBar("BELLY", model.belly, BurrowInk.berry)
                    statBar("JOY", model.joy, BurrowInk.teal, tag: model.isHappy ? "HAPPY" : nil)
                    statBar("MOLT", model.molt, BurrowInk.amber)
                }
                HStack(spacing: 10) {
                    hudButton(icon: FindKind.berry.sprite, title: "FEED", count: model.foodCount) { model.feed() }
                    hudButton(icon: IconArt.shovel, title: "DIG", count: model.digsLeft,
                              hot: model.digsLeft > 0 && !model.buried.isEmpty) { model.digHint() }
                    hudButton(icon: IconArt.pouch, title: "FINDS", count: model.findCount) {
                        model.cancelPlacing()
                        model.clearSelection()
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
        .animation(.easeOut(duration: 0.15), value: model.placing)
        .animation(.easeOut(duration: 0.15), value: model.selectedSlot)
    }

    private func statBar(_ label: String, _ value: Int, _ ink: UInt32, tag: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Text(label).font(GrubFont.size(7)).foregroundColor(Color(ink: BurrowInk.cream))
                if let tag {
                    Text(tag).font(GrubFont.size(6)).foregroundColor(Color(ink: ink))
                }
            }
            HStack(spacing: 2) {
                ForEach(0..<BurrowRules.maxStat, id: \.self) { i in
                    Rectangle().fill(Color(ink: i < value ? ink : BurrowInk.soil1)).frame(height: 9)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label.capitalized) \(value) of \(BurrowRules.maxStat)" + (tag.map { ", \($0.lowercased())" } ?? ""))
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

    private func hudBar(_ text: String, button: String, secondary: String? = nil,
                        action: @escaping () -> Void, secondaryAction: (() -> Void)? = nil) -> some View {
        HStack(spacing: 10) {
            Text(text)
                .font(GrubFont.size(8)).lineSpacing(5)
                .foregroundColor(Color(ink: BurrowInk.cream))
                .frame(maxWidth: .infinity, alignment: .leading)
            if let secondary, let secondaryAction {
                pixelButton(secondary, ink: BurrowInk.creamDim, action: secondaryAction)
            }
            pixelButton(button, ink: BurrowInk.amber, action: action)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Color(ink: BurrowInk.hollow))
        .overlay(Rectangle().strokeBorder(Color(ink: BurrowInk.teal), lineWidth: 3))
    }

    private func pixelButton(_ title: String, ink: UInt32, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(GrubFont.size(8)).foregroundColor(Color(ink: BurrowInk.hollow))
                .padding(.horizontal, 10).padding(.vertical, 9)
                .background(Color(ink: ink))
        }
        .buttonStyle(PixelPressStyle())
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

/// What the grub has dug up (spec §3). Pick a find, then EAT it (food) or PLACE it (decor).
struct FindsBagView: View {
    let bag: [FindKind: Int]
    let canAct: Bool
    let freeSlots: Int
    let onEat: (FindKind) -> Void
    let onPlace: (FindKind) -> Void
    let close: () -> Void
    @State private var picked: FindKind?

    private let columns = Array(repeating: GridItem(.fixed(64), spacing: 10), count: 4)

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea().onTapGesture(perform: close)
            VStack(spacing: 16) {
                Text("FINDS").font(GrubFont.size(14)).foregroundColor(Color(ink: BurrowInk.cream))
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(FindKind.allCases) { cell($0) }
                }
                actionRow
                Text("FOOD FEEDS YOUR GRUB.\nDECOR GOES IN THE ROOMS.")
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
        .onChange(of: bag) { _, newBag in
            if let k = picked, (newBag[k] ?? 0) == 0 { picked = nil }
        }
    }

    private func cell(_ k: FindKind) -> some View {
        let n = bag[k] ?? 0
        let isPicked = picked == k
        return Button { picked = isPicked ? nil : k } label: {
            VStack(spacing: 6) {
                PixelImage(buffer: n > 0 ? k.sprite : k.sprite.silhouette(BurrowInk.root), cell: 6)
                    .frame(width: 60, height: 60)
                    .background(Color(ink: n > 0 ? BurrowInk.cream : BurrowInk.soil4))
                    .overlay(Rectangle().strokeBorder(
                        Color(ink: isPicked ? BurrowInk.teal : (n > 0 ? BurrowInk.amberLo : BurrowInk.soil1)),
                        lineWidth: 3))
                Text(n > 0 ? k.label : "???").font(GrubFont.size(6))
                    .foregroundColor(Color(ink: BurrowInk.cream))
                Text(n > 0 ? "x\(n)" : " ").font(GrubFont.size(8))
                    .foregroundColor(Color(ink: BurrowInk.amber))
            }
        }
        .buttonStyle(PixelPressStyle())
        .disabled(n == 0)
        .accessibilityLabel(n > 0 ? "\(k.label.capitalized), \(n)" : "Not found yet")
    }

    @ViewBuilder
    private var actionRow: some View {
        if let k = picked, canAct {
            let full = k.isDecor && freeSlots == 0
            Button { k.isFood ? onEat(k) : onPlace(k) } label: {
                Text(k.isFood ? "EAT \(k.label)" : (full ? "ROOMS FULL" : "PLACE \(k.label)"))
                    .font(GrubFont.size(9)).foregroundColor(Color(ink: BurrowInk.hollow))
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    .background(Color(ink: full ? BurrowInk.creamDim : BurrowInk.teal))
            }
            .buttonStyle(PixelPressStyle())
            .disabled(full)
        } else {
            Text(canAct ? "TAP A FIND" : " ")
                .font(GrubFont.size(8)).foregroundColor(Color(ink: BurrowInk.mutedText))
                .frame(height: 34)
        }
    }
}

#Preview {
    BurrowHomeView()
}
