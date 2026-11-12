import SwiftUI

/// Home screen for the pixel-burrow redesign, built from the "Grub Hero Art" canvas:
/// a side-on burrow cross-section with the grub in its central chamber, the GRUB title
/// in the night sky, and buried finds marked with amber "!" (HATCH → RETURN → DIG → FEED).
/// The three places the burrow is split across. One screen was carrying the pet, the dig
/// sites, the decor, the collection and the stats at once — sixteen tap targets — and Jesse
/// called it, correctly, too busy. Order matters: it is the loop, left to right.
enum BurrowPage: Int, CaseIterable, Hashable {
    case burrow, dig, collection

    var title: String {
        switch self {
        case .burrow:     return "BURROW"
        case .dig:        return "DIG"
        case .collection: return "COLLECTION"
        }
    }
}

struct BurrowHomeView: View {
    @StateObject private var model = BurrowHomeModel()
    @State private var page: BurrowPage = .burrow
    @Environment(\.displayScale) private var displayScale
    @Environment(\.scenePhase) private var scenePhase
    private let minuteTick = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private static let bangHot = PixelBuffer(art: ["A", "A", "A", ".", "A"], palette: ["A": BurrowInk.white])

    var body: some View {
        GeometryReader { geo in
            let L = BurrowLayout(size: geo.size, displayScale: displayScale)
            TabView(selection: $page) {
                ForEach(BurrowPage.allCases, id: \.self) { p in
                    world(p, L, size: geo.size).tag(p)
                }
            }
            // Our own dots, drawn in pixels above the HUD — the system ones land underneath it.
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onAppear {
                place(L)
                #if DEBUG
                if let n = BurrowDebug.page, let p = BurrowPage(rawValue: n) { page = p }
                #endif
            }
            .onChange(of: geo.size) { _, _ in place(L) }
        }
        .ignoresSafeArea()
        .background(Color(ink: BurrowInk.sky).ignoresSafeArea())
        .overlay(alignment: .bottom) { bottomHUD }
        .overlay(alignment: .top) { modeBar }
        .overlay {
            if model.showBag {
                FindsBagView(bag: model.bag, tiers: model.tiers, banks: model.banks,
                             canAct: model.canAct, freeSlots: model.freeSlots.count,
                             onEat: { k in closeBag(); model.feed(kind: k) },
                             onPlace: { k in closeBag(); model.startPlacing(k) },
                             close: closeBag)
                    .transition(.opacity)
            }
        }
        .overlay {
            if model.showMolt {
                MoltPanelView(molt: model.molt, odds: model.odds) { withAnimation(.easeOut(duration: 0.15)) { model.showMolt = false } }
                    .transition(.opacity)
            }
        }
        .overlay {
            if model.confirmingMolt {
                MoltConfirmView(confirm: { model.confirmMolt() }, notYet: { model.cancelMolt() })
                    .transition(.opacity)
            }
        }
        .overlay {
            if model.namingEgg {
                NamePromptView(initial: model.randomEggName(),
                               random: { model.randomEggName() },
                               submit: { model.nameEgg($0) },
                               cancel: { model.cancelNaming() })
                    .transition(.opacity)
            }
        }
        .overlay {
            if let sp = model.revealing {
                RevealCardView(species: sp,
                               pin: { withAnimation(.easeOut(duration: 0.15)) { model.pin() } },
                               later: { withAnimation(.easeOut(duration: 0.15)) { model.dismissReveal() } })
                    .transition(.opacity)
            }
        }
        .overlay {
            // The dimmer has to be here, in the group attached *after* bottomHUD, and it has
            // to swallow taps: the HUD's DIG and FINDS buttons and the grub's own tap gesture
            // are not gated on `canStartTrip`, so without it they stay live under the grid.
            if let trip = model.trip, let find = model.tripFind {
                GeometryReader { geo in
                    DigTripView(model: model, trip: trip, find: find,
                                layout: BurrowLayout(size: geo.size, displayScale: displayScale),
                                size: geo.size)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
                .ignoresSafeArea()
                .transition(.opacity)
            }
        }
        .overlay {
            if model.showBox {
                SpecimenBoxView(specimens: model.specimens) { withAnimation(.easeOut(duration: 0.15)) { model.showBox = false } }
                    .transition(.opacity)
            }
        }
        .onReceive(minuteTick) { _ in model.tick() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: model.tick()
            case .background: model.leaveTrip(); model.persist()
            default: break
            }
        }
        #if DEBUG
        .task {
            if BurrowDebug.showBag { model.showBag = true }
            await runDemoIfRequested()
            await runMoltDemoIfRequested()
            await runLoopDemoIfRequested()
            await runDigDemoIfRequested()
        }
        #endif
    }

    private func place(_ L: BurrowLayout) {
        model.grubTop = (L.chamber.midX, L.chamber.maxY - GrubArt.height)
        model.layout = L
    }

    private func closeBag() { withAnimation(.easeOut(duration: 0.15)) { model.showBag = false } }

    #if DEBUG
    /// `-burrowDemo` (use with `-burrowReset`). Times are seconds after the view appears:
    ///  1.5/3.0/4.5 dig all three · 6.0 eat berry · 7.5 eat root (variety → +joy; fed state until 10.0)
    /// 10.0 start placing the crystal (slots glow until 12.5) · 12.5 place it in slot 2
    /// 15.0 pet · 16.0 select the crystal (REMOVE bar until 19.0) · 19.0 remove · 21.5 open Finds
    private func runDemoIfRequested() async {
        guard BurrowDebug.demo else { return }
        func wait(_ s: Double) async { try? await Task.sleep(nanoseconds: UInt64(s * 1_000_000_000)) }
        await wait(1.5)
        // Three finds, each dug straight off its own grid — the demo cheats by reading
        // findTile, which is the point: it's showing the loop, not playing the game.
        for _ in 0..<3 {
            guard let f = model.buried.first else { break }
            model.startTrip(spot: f.spot)
            await wait(0.8)
            model.strike(tile: f.findTile)
            await wait(0.7)
        }
        model.feed(); await wait(1.5)                   //  6.0
        model.feed(); await wait(2.5)                   //  7.5
        model.startPlacing(.crystal); await wait(2.5)   // 10.0
        model.tapSlot(2); await wait(2.5)               // 12.5
        model.pet(); await wait(1.0)                    // 15.0
        model.tapSlot(2); await wait(3.0)               // 16.0
        model.removeSelected(); await wait(2.5)         // 19.0
        withAnimation { model.showBag = true }          // 21.5
    }

    /// `-burrowDigDemo` (use with `-burrowReset`). Hatches, then plays one dig at spot 0:
    /// a cold tile, a warm one, a rock twice, then the find — clay's 5 strikes, exactly spent.
    private func runDigDemoIfRequested() async {
        guard BurrowDebug.digDemo else { return }
        func wait(_ s: Double) async { try? await Task.sleep(nanoseconds: UInt64(s * 1_000_000_000)) }

        // Hatch the way the loop demo does; there is no debug hatch flag.
        await wait(1.0); _ = model.nameEgg("DIG")
        for _ in 0..<BurrowRules.crackTaps { await wait(0.6); model.tapGrub() }
        await wait(1.0)

        guard let find = model.buried.first(where: { $0.spot == 0 }) else {
            assertionFailure("the dig demo expects a find at spot 0"); return
        }
        assert(BurrowSpots.layer(0) == .clay, "the dig demo assumes spot 0 is clay")
        assert(find.tiles.indices.contains { find.tiles[$0].isRock && DigGrid.distance($0, find.findTile) <= 2 },
               "the fresh seed no longer puts a rock near the find; rescript the demo")

        // Pick the script from the grid rather than hard-coding tile numbers, so it survives
        // a change of seed: one cold tile, one warm, then the nearby rock, then the find.
        let f = find.findTile
        let cold = find.tiles.indices.first { find.tiles[$0] == .soil && DigGrid.distance($0, f) >= 3 }
        let warm = find.tiles.indices.first { find.tiles[$0] == .soil && DigGrid.distance($0, f) == 2 }
        let rock = find.tiles.indices.first { find.tiles[$0].isRock && DigGrid.distance($0, f) <= 2 }

        withAnimation { model.startTrip(spot: 0) }
        // Wait for the crawl and the zoom to finish. Striking before the grid is up is
        // ignored by design, and an earlier version of this demo silently lost its first
        // strike that way — the screenshots showed a dig that had never happened.
        while model.trip != nil, model.trip?.phase != .digging {
            await wait(0.1)
        }
        // Two reads, then straight to it: clay grants 6, so finding it on the third strike
        // leaves 3 in hand and pays the clean-dig bonus. The demo shows the good outcome.
        for tile in [cold, warm, f].compactMap({ $0 }) {
            await wait(1.4)
            model.strike(tile: tile)
        }
    }

    /// `-burrowMoltDemo` (use with `-burrowReset -burrowMoltReady`). Seconds after the view appears:
    /// 2.0 open the molt panel (until 5.0) · 5.0 close; grub glows · 7.0 tap → MOLT NOW? (until 9.5)
    /// 9.5 confirm → cocoon (until 12.5) · 12.5 reveal card (until 15.5) · 15.5 dismiss; adult stands.
    /// `-burrowLoopDemo` (use with `-burrowReset -burrowAdult horn`). Seconds after the view appears:
    /// 2.0 tap the adult → reveal with PIN IT (until 4.5) · 4.5 pin → box opens (until 7.5)
    /// 7.5 close → horn-spotted egg · 9.5 tap → name prompt (until 12.0) · 12.0 name PIP
    /// 13.0 / 14.5 crack, crack (2/3 until 16.0) · 16.0 crack → violet-tinted larva hatches.
    private func runLoopDemoIfRequested() async {
        guard BurrowDebug.loopDemo else { return }
        func wait(_ s: Double) async { try? await Task.sleep(nanoseconds: UInt64(s * 1_000_000_000)) }
        await wait(2.0); model.tapGrub()
        await wait(2.5); withAnimation { model.pin() }
        await wait(3.0); withAnimation { model.showBox = false }
        await wait(2.0); model.tapGrub()
        await wait(2.5); _ = model.nameEgg("PIP")
        await wait(1.0); model.tapGrub()
        await wait(1.5); model.tapGrub()
        await wait(1.5); model.tapGrub()
    }

    private func runMoltDemoIfRequested() async {
        guard BurrowDebug.moltDemo else { return }
        func wait(_ s: Double) async { try? await Task.sleep(nanoseconds: UInt64(s * 1_000_000_000)) }
        await wait(2.0); withAnimation { model.showMolt = true }
        await wait(3.0); withAnimation { model.showMolt = false }
        await wait(2.0); model.tapGrub()
        await wait(2.5); model.confirmMolt()
        await wait(6.0); withAnimation { model.dismissReveal() }
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

    // MARK: - Pages

    /// One page of the burrow. Every page draws the same world — it is one cross-section and
    /// that is most of its charm — and differs in what it puts *on* it. Before the split the
    /// single screen carried sixteen tap targets and five systems at once (the pet, the dig
    /// sites, the decor, the collection and the stats), which is what made it unreadable.
    @ViewBuilder
    private func world(_ p: BurrowPage, _ L: BurrowLayout, size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            BurrowBackdrop(page: p, layout: L, holes: model.holes, spurs: model.spurs).equatable()
            // The title is an identity beat for a new egg, not a permanent fixture, and it
            // belongs to the page the egg is on.
            if p == .burrow, model.stage == .egg {
                titleBlock(L, width: size.width)
                    .transition(.opacity)
            }
            TimelineView(.animation(minimumInterval: 1.0 / 24)) { tl in
                livingLayer(p, L, t: tl.date.timeIntervalSinceReferenceDate)
                    .frame(width: size.width, height: size.height, alignment: .topLeading)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipped()
        .animation(.easeOut(duration: 0.6), value: model.stage)
    }

    // MARK: - Animated layer (markers, grub, effects)

    @ViewBuilder
    private func livingLayer(_ p: BurrowPage, _ L: BurrowLayout, t: TimeInterval) -> some View {
        ZStack(alignment: .topLeading) {
            if p == .collection {
                specimenShelf(L)
                ForEach(0..<BurrowRules.decorSlots, id: \.self) { i in decorSlot(i, L, t) }
            }
            if p == .dig {
                ForEach(model.buried, id: \.spot) { f in
                    marker(spot: f.spot, L, t)
                }
            }
            // The grub belongs to its chamber, and only the BURROW page draws one. Putting it
            // on the soil face or in the gallery would be putting it nowhere.
            if p == .burrow, !model.isAwayDigging { grub(L, t) }
            ForEach(model.fx) { e in effect(e, L, t) }
        }
    }

    @ViewBuilder
    private func marker(spot: Int, _ L: BurrowLayout, _ t: TimeInterval) -> some View {
        let p = BurrowSpots.resolve(spot, L)
        let find = model.buried.first { $0.spot == spot }
        let phase = Double((spot * 7) % 10) / 10
        let hinted = t - model.digHintAt < 1.6
        let hot = hinted && Int(t / 0.14) % 2 == 0
        let cx = L.point(BurrowSpots.markerCentre(spot, L, width: MarkerArt.mound.width), 0).x
        // A glinting spot starts with one tile already broken, so counting broken tiles alone
        // would advertise the condition before the player has ever been there.
        let freebie = find?.condition == .glinting ? 1 : 0
        let opened = (find?.visited ?? false)
            && (find?.tiles.filter { $0 == .broken }.count ?? 0) > freebie
        let mound = opened ? MarkerArt.moundOpen : MarkerArt.mound
        // The mound is ground, so it does not bob — that is the point of it. Only the tell
        // on top moves, which is what carries the eye without unmooring the site.
        let tell = hot ? Self.bangHot : MarkerArt.tell(food: find?.kind.isFood ?? true)
        let bob = Int(t / 0.45 + phase * 2) % 2

        // Rows p.y-4 … p.y+1, so the mound's last row — its cast shadow — lands on the soil
        // at the spot itself. `.position` centres, hence the half-height offsets.
        PixelImage(buffer: mound, cell: L.cell)
            .position(x: cx, y: (CGFloat(p.y) - 4 + CGFloat(mound.height) / 2) * L.cell)
        PixelImage(buffer: tell, cell: L.cell)
            .position(x: cx, y: (CGFloat(p.y) - 4 - CGFloat(bob) - CGFloat(tell.height) / 2) * L.cell)
        if let c = find?.condition, find?.visited == true {
            PixelImage(buffer: MarkerArt.badge(c), cell: L.cell)
                .position(x: cx + 6 * L.cell, y: (CGFloat(p.y) - 3) * L.cell)
        }
        Color.clear
            .frame(width: 56, height: 64)
            .contentShape(Rectangle())
            .position(x: cx, y: CGFloat(p.y - 2) * L.cell)
            .onTapGesture { model.startTrip(spot: spot) }
            .accessibilityElement()
            .accessibilityLabel(markerLabel(spot: spot, find: find))
            .accessibilityHint("Go and dig it up")
            .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private func decorSlot(_ i: Int, _ L: BurrowLayout, _ t: TimeInterval) -> some View {
        if let p = L.decorSlot(i) {
            let kind = model.placed[i]
            let lit = model.placing != nil && kind == nil && Int(t / 0.3) % 2 == 0
            let selected = model.selectedSlot == i
            let shelf = L.decorIsShelf(i)
            let plinth = shelf ? (lit ? IconArt.shelfLit : IconArt.shelfDim)
                               : (lit ? IconArt.pedestalLit : IconArt.pedestalDim)
            let base = L.point(Double(p.x - 3), Double(p.y))
            let cx = L.point(Double(p.x) + 0.5, 0).x
            // A back wall behind each slot, so the plinth sits in a recess carved out of the
            // chamber instead of floating in the dark. Without it an empty slot reads as a
            // gap in the art — which is exactly how the old 6×2 bar read.
            Rectangle()
                .fill(Color(ink: lit ? BurrowInk.soil1 : BurrowInk.soil2))
                .frame(width: 10 * L.cell, height: 9 * L.cell)
                .position(x: cx, y: (CGFloat(p.y) + CGFloat(plinth.height) - 4.5) * L.cell)
            PixelImage(buffer: plinth, cell: L.cell)
                .position(x: base.x + 3 * L.cell,
                          y: base.y + CGFloat(plinth.height) * L.cell / 2)
            if kind == nil {
                let o = IconArt.slotEmpty
                PixelImage(buffer: o, cell: L.cell)
                    .position(x: cx, y: (CGFloat(p.y) - CGFloat(o.height) / 2) * L.cell)
                    .opacity(lit ? 1 : 0.5)
            }
            if let kind {
                // The slot shows the best one of this kind the player owns, so a furnished
                // burrow quietly improves as they dig rather than freezing after week one.
                let spr = kind.sprite(tier: model.tier(kind))
                let bob = selected && Int(t / 0.25) % 2 == 0 ? 1 : 0
                // Whole-cell top-left so 5-wide sprites stay on the pixel grid: centred on the
                // 6-wide pedestal (x-3…x+2), bottom row just above the pedestal top (row p.y).
                let left = p.x - 3 + (6 - spr.width) / 2
                let top = p.y - bob - spr.height
                let o = L.point(Double(left), Double(top))
                PixelImage(buffer: spr, cell: L.cell)
                    .position(x: o.x + CGFloat(spr.width) * L.cell / 2,
                              y: o.y + CGFloat(spr.height) * L.cell / 2)
                let pips = IconArt.pips(tier: model.tier(kind), bank: model.bank(kind))
                PixelImage(buffer: pips, cell: L.cell)
                    .position(x: cx, y: (CGFloat(p.y) + CGFloat(plinth.height) + 1) * L.cell)
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

    /// The specimen ledge running across the gallery, newest first.
    ///
    /// It used to be split between the two side rooms, which were 12 and 14 cells wide and
    /// showed three busts between them. One wall in a room built for it shows eight, and the
    /// rest are a tap away.
    @ViewBuilder
    private func specimenShelf(_ L: BurrowLayout) -> some View {
        let s = L.shelf
        let shown = Array(model.specimens.reversed().prefix(L.shelfSlots))
        // The ledge is drawn whether or not anything stands on it, so an empty gallery reads
        // as a shelf waiting to be filled rather than as a blank wall.
        Rectangle()
            .fill(Color(ink: BurrowInk.root))
            .frame(width: CGFloat(s.width) * L.cell, height: L.cell)
            .position(x: L.point(Double(s.x0) + Double(s.width) / 2, 0).x,
                      y: (CGFloat(s.y) + 0.5) * L.cell)
        // Centred rather than left-packed: three busts shoved into the left end of a wide
        // ledge reads as a layout bug, not as a collection with room to grow.
        let startX = s.x0 + max(0, (s.width - shown.count * 6) / 2)
        ForEach(Array(shown.enumerated()), id: \.offset) { k, sp in
            let spr = IconArt.specimen(sp.species)
            let o = L.point(Double(startX + k * 6), Double(s.y - spr.height))
            PixelImage(buffer: spr, cell: L.cell)
                .position(x: o.x + CGFloat(spr.width) * L.cell / 2,
                          y: o.y + CGFloat(spr.height) * L.cell / 2)
        }
        // Before the first molt there is nothing to show, so the first place says what it is for.
        if shown.isEmpty {
            let o = IconArt.slotEmpty
            PixelImage(buffer: o, cell: L.cell)
                .position(x: L.point(Double(s.x0) + 3, 0).x,
                          y: (CGFloat(s.y) - 1 - CGFloat(o.height) / 2) * L.cell)
                .opacity(0.5)
        }
        Color.clear
            .frame(width: CGFloat(s.width) * L.cell, height: 10 * L.cell)
            .contentShape(Rectangle())
            .position(x: L.point(Double(s.x0) + Double(s.width) / 2, 0).x,
                      y: (CGFloat(s.y) - 4) * L.cell)
            .onTapGesture { withAnimation(.easeOut(duration: 0.15)) { model.showBox = true } }
            .accessibilityElement()
            .accessibilityLabel(model.specimens.isEmpty
                                ? "Specimen shelf, empty"
                                : "Specimen shelf, \(model.specimens.count) pinned")
            .accessibilityHint("Open the specimen box")
            .accessibilityAddTraits(.isButton)
    }

    private func grub(_ L: BurrowLayout, _ t: TimeInterval) -> some View {
        let F = GrubArt.frames(tint: model.tint)
        let sulking = model.isSulking
        let bounce = !sulking && Int(t / 0.4) % 3 == 1 ? 1 : 0
        let hopP = (t - model.hopAt) / 0.42
        let hop = (hopP >= 0 && hopP < 1) ? Int((sin(hopP * .pi) * 5).rounded()) : 0
        let inCocoon = t - model.moltAt < BurrowHomeModel.cocoonSeconds
        let sprite: PixelBuffer
        if inCocoon {
            sprite = SpeciesArt.cocoon
        } else if model.stage == .egg {
            sprite = SpeciesArt.egg(cracks: model.eggCracks, tint: model.tint)
        } else if model.stage == .adult, let sp = model.adult {
            sprite = SpeciesArt.adult(sp)
        } else {
            let chomping = t - model.chompAt < 0.9
            let blinking = t.truncatingRemainder(dividingBy: 3.7) < 0.14 || hop > 0
            sprite = chomping ? (Int(t / 0.15) % 2 == 0 ? F.chomp : F.idle)
                              : (blinking ? F.blink : (sulking ? F.sulk : F.idle))
        }
        // Cocoon wobbles ±1 cell; a just-cracked egg shakes; the larva/adult bounce and hop.
        let shaking = model.stage == .egg && t - model.crackAt < 0.3
        let wobble = inCocoon ? Int((sin(t * 9) * 1.4).rounded()) : (shaking ? (Int(t / 0.05) % 2 == 0 ? 1 : -1) : 0)
        let gx = L.chamber.midX - sprite.width / 2 + wobble
        let gy = L.chamber.maxY - sprite.height - ((inCocoon || model.stage == .egg) ? 0 : bounce + hop)
        let origin = L.point(Double(gx), Double(gy))
        let glowing = model.isMoltReady && !inCocoon && Int(t / 0.4) % 2 == 0

        return ZStack(alignment: .topLeading) {
            if glowing {
                ForEach(0..<4, id: \.self) { k in
                    let d = [(-1, 0), (1, 0), (0, -1), (0, 1)][k]
                    PixelImage(buffer: SpeciesArt.glow, cell: L.cell)
                        .offset(x: CGFloat(d.0) * L.cell, y: CGFloat(d.1) * L.cell)
                }
            }
            PixelImage(buffer: sprite, cell: L.cell)
        }
        .contentShape(Rectangle())
        .onTapGesture { if !inCocoon { model.tapGrub() } }
        .position(x: origin.x + CGFloat(sprite.width) * L.cell / 2,
                  y: origin.y + CGFloat(sprite.height) * L.cell / 2)
        .accessibilityLabel(grubLabel(sulking: sulking, inCocoon: inCocoon))
        .accessibilityHint(model.stage == .egg ? (model.name.isEmpty ? "Name your egg" : "Tap to hatch")
                           : (model.isMoltReady ? "Start the molt" : (model.stage == .adult ? "See your adult" : "Pet your grub")))
        .accessibilityAddTraits(.isButton)
    }

    private func grubLabel(sulking: Bool, inCocoon: Bool) -> String {
        if model.stage == .egg { return model.name.isEmpty ? "Egg" : "Egg named \(model.name)" }
        if inCocoon { return "Cocoon" }
        if model.stage == .adult, let sp = model.adult { return "Adult \(sp.label.capitalized)" }
        if model.isMoltReady { return "Grub, ready to molt" }
        return sulking ? "Grub, hungry and sulking" : "Grub"
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
                let spr = kind.sprite(tier: model.tier(kind))
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


    // MARK: - Mode bar (placing / removing decor)

    /// Shown over the sky, not above the HUD, so it never covers a decor slot
    /// (the left side-room sits just above the HUD).
    @ViewBuilder
    private var modeBar: some View {
        Group {
            if let kind = model.placing {
                hudBar("PLACE \(kind.label):\nTAP A GLOWING SPOT", button: "CANCEL",
                       action: { model.cancelPlacing() })
            } else if let slot = model.selectedSlot, let kind = model.placed[slot] {
                hudBar("REMOVE \(kind.label)?", button: "REMOVE", secondary: "KEEP",
                       action: { model.removeSelected() }, secondaryAction: { model.clearSelection() })
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .animation(.easeOut(duration: 0.15), value: model.placing)
        .animation(.easeOut(duration: 0.15), value: model.selectedSlot)
    }

    /// Says what the marker's art says: the soil, and whether this dig has been started.
    private func markerLabel(spot: Int, find: BuriedFind?) -> String {
        var parts = ["Buried find", BurrowSpots.layer(spot).label.lowercased()]
        if find?.visited == true {
            if let c = find?.condition { parts.append(c.label.lowercased()) }
            parts.append("started")
        }
        return parts.joined(separator: ", ")
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
            pageBar
            VStack(spacing: 14) {
                switch page {
                case .burrow:     burrowHUD
                case .dig:        digHUD
                case .collection: collectionHUD
                }
            }
            .padding(12)
            .background(Color(ink: BurrowInk.hollow))
            .overlay(Rectangle().strokeBorder(Color(ink: BurrowInk.soil1), lineWidth: 4))
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
        .animation(.easeOut(duration: 0.15), value: model.toast)
        .animation(.easeOut(duration: 0.2), value: page)
    }

    /// Where you are and what else there is. Pixel dots rather than the system page control,
    /// which draws underneath the HUD and in the wrong idiom.
    private var pageBar: some View {
        VStack(spacing: 7) {
            // The box holds the dots and nothing else. With the name inside it, the box
            // changed width as you swiped and the dots shuffled sideways under your thumb.
            HStack(spacing: 4) {
                ForEach(BurrowPage.allCases, id: \.self) { p in
                    Button { withAnimation(.easeOut(duration: 0.25)) { page = p } } label: {
                        Rectangle()
                            .fill(Color(ink: p == page ? BurrowInk.amber : BurrowInk.root))
                            .frame(width: 8, height: 8)
                            // An 8-point dot is not a tap target; the padding is.
                            .padding(5)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PixelPressStyle())
                    .accessibilityLabel(p.title)
                    .accessibilityAddTraits(p == page ? [.isSelected, .isButton] : .isButton)
                }
            }
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Color(ink: BurrowInk.hollow))
            .overlay(Rectangle().strokeBorder(Color(ink: BurrowInk.soil1), lineWidth: 3))

            Text(page.title).font(GrubFont.size(7))
                .foregroundColor(Color(ink: BurrowInk.cream))
                .accessibilityHidden(true)      // the dots already say it
        }
    }

    /// The pet. Its state, and the one thing you do to it directly.
    @ViewBuilder
    private var burrowHUD: some View {
        if model.stage == .adult, let sp = model.adult {
            stageBanner("MOLTED INTO \(sp.label)!", "TAP IT TO PIN IT", ink: sp.color)
        } else if model.stage == .egg {
            stageBanner("A NEW EGG!",
                        model.name.isEmpty ? "TAP IT TO NAME IT" : "TAP TO HATCH \(model.eggCracks)/\(BurrowRules.crackTaps)",
                        ink: GrubArt.bodyColor(tint: model.tint))
        } else {
            HStack(spacing: 12) {
                statBar("BELLY", model.belly, BurrowInk.berry)
                statBar("JOY", model.joy, BurrowInk.teal, tag: model.isHappy ? "HAPPY" : nil)
                Button { model.showMolt = true } label: {
                    statBar("MOLT", model.molt, BurrowInk.amber, tag: model.isMoltReady ? "READY" : nil)
                }
                .buttonStyle(PixelPressStyle())
                .accessibilityHint("Show molt odds")
            }
            HStack(spacing: 10) {
                hudButton(icon: FindKind.berry.sprite, title: "FEED", count: model.foodCount) { model.feed() }
                    .disabled(!model.canAct).opacity(model.canAct ? 1 : 0.4)
                // A player who never swipes never digs, so the pet's page has to say there is
                // something to go and do — and take them there.
                hudButton(icon: IconArt.shovel, title: "DIG", count: model.digsLeft,
                          hot: model.digsLeft > 0 && !model.buried.isEmpty) {
                    withAnimation(.easeOut(duration: 0.25)) { page = .dig }
                }
            }
        }
    }

    /// The soil and what is in it.
    @ViewBuilder
    private var digHUD: some View {
        Text(model.buried.isEmpty ? "NOTHING BURIED YET"
                                  : "\(model.buried.count) SPOT\(model.buried.count == 1 ? "" : "S") TO DIG")
            .font(GrubFont.size(8))
            .foregroundColor(Color(ink: BurrowInk.cream))
        hudButton(icon: IconArt.shovel, title: "DIG", count: model.digsLeft,
                  hot: model.digsLeft > 0 && !model.buried.isEmpty) { model.digHint() }
    }

    /// What you have earned and where you put it.
    @ViewBuilder
    private var collectionHUD: some View {
        Text(model.specimens.isEmpty ? "NOTHING PINNED YET"
                                     : "\(model.specimens.count) PINNED")
            .font(GrubFont.size(8))
            .foregroundColor(Color(ink: BurrowInk.cream))
        hudButton(icon: IconArt.pouch, title: "FINDS", count: model.findCount) {
            model.cancelPlacing()
            model.clearSelection()
            withAnimation(.easeOut(duration: 0.15)) { model.showBag = true }
        }
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

    private func stageBanner(_ title: String, _ sub: String, ink: UInt32) -> some View {
        VStack(spacing: 6) {
            Text(title).font(GrubFont.size(9)).foregroundColor(Color(ink: ink))
            Text(sub).font(GrubFont.size(7)).foregroundColor(Color(ink: BurrowInk.mutedText))
        }
        .frame(maxWidth: .infinity, minHeight: 34)
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
    let page: BurrowPage
    let layout: BurrowLayout
    let holes: [Int]
    /// Spots the grub has visited. A stored property, not a computed one: the view is
    /// `.equatable()` over what it stores, so a backdrop input kept anywhere else would not
    /// redraw until the layout happened to change.
    let spurs: [Int]

    var body: some View {
        PixelImage(buffer: BurrowArt.backdrop(page, layout, holes: holes, spurs: spurs),
                   cell: layout.cell)
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
    let tiers: [FindKind: Int]
    let banks: [FindKind: Int]
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
                PixelImage(buffer: n > 0 ? k.sprite(tier: tiers[k] ?? 1)
                                         : k.sprite.silhouette(BurrowInk.root), cell: 6)
                    .frame(width: 60, height: 60)
                    // Dark soil behind found items so every sprite reads (the bone is cream).
                    .background(Color(ink: n > 0 ? BurrowInk.soil2 : BurrowInk.soil4))
                    .overlay(Rectangle().strokeBorder(
                        Color(ink: isPicked ? BurrowInk.teal : (n > 0 ? BurrowInk.amberLo : BurrowInk.soil1)),
                        lineWidth: 3))
                Text(n > 0 ? k.label : "???").font(GrubFont.size(6))
                    .foregroundColor(Color(ink: BurrowInk.cream))
                // Decor says what condition yours is in and how close the next one is, so a
                // duplicate reads as progress rather than as another dead copy.
                if n > 0, k.isDecor {
                    let tier = tiers[k] ?? 1
                    PixelImage(buffer: IconArt.pips(tier: tier, bank: banks[k] ?? 0), cell: 3)
                    Text(FindKind.tierName(tier)).font(GrubFont.size(6))
                        .foregroundColor(Color(ink: BurrowInk.tellGold))
                } else {
                    Text(n > 0 ? "x\(n)" : " ").font(GrubFont.size(8))
                        .foregroundColor(Color(ink: BurrowInk.amber))
                }
            }
        }
        .buttonStyle(PixelPressStyle())
        .disabled(n == 0)
        .accessibilityLabel(n == 0 ? "Not found yet"
                            : k.isDecor ? "\(FindKind.tierName(tiers[k] ?? 1).capitalized) \(k.label.capitalized), \(n)"
                                        : "\(k.label.capitalized), \(n)")
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

/// "MOLT NOW?" — the only way into the irreversible molt (reasoner review, board #287).
struct MoltConfirmView: View {
    let confirm: () -> Void
    let notYet: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea().onTapGesture(perform: notYet)
            VStack(spacing: 16) {
                Text("MOLT NOW?").font(GrubFont.size(14)).foregroundColor(Color(ink: BurrowInk.amber))
                Text("THIS PICKS THE ADULT.\nNO GOING BACK.")
                    .font(GrubFont.size(8)).lineSpacing(6).multilineTextAlignment(.center)
                    .foregroundColor(Color(ink: BurrowInk.cream))
                HStack(spacing: 12) {
                    Button(action: notYet) {
                        Text("NOT YET").font(GrubFont.size(9)).foregroundColor(Color(ink: BurrowInk.hollow))
                            .padding(.horizontal, 14).padding(.vertical, 11)
                            .background(Color(ink: BurrowInk.creamDim))
                    }
                    .buttonStyle(PixelPressStyle())
                    Button(action: confirm) {
                        Text("MOLT").font(GrubFont.size(9)).foregroundColor(Color(ink: BurrowInk.hollow))
                            .padding(.horizontal, 18).padding(.vertical, 11)
                            .background(Color(ink: BurrowInk.amber))
                    }
                    .buttonStyle(PixelPressStyle())
                }
            }
            .padding(24)
            .background(Color(ink: BurrowInk.hollow))
            .overlay(Rectangle().strokeBorder(Color(ink: BurrowInk.amber), lineWidth: 4))
            .padding(32)
        }
    }
}

/// Live molt odds (spec §4): six bars, one per species.
struct MoltPanelView: View {
    let molt: Int
    let odds: [Species: Double]
    let close: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea().onTapGesture(perform: close)
            VStack(spacing: 14) {
                Text("MOLT").font(GrubFont.size(14)).foregroundColor(Color(ink: BurrowInk.cream))
                Text("\(molt)/\(BurrowRules.moltGoal)").font(GrubFont.size(9))
                    .foregroundColor(Color(ink: BurrowInk.amber))
                VStack(spacing: 10) {
                    ForEach(Species.allCases, id: \.self) { sp in row(sp) }
                }
                Text("FOOD AND DECOR SHIFT THE ODDS.\nEVERY MEAL IS +1 MOLT.")
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

    private func row(_ sp: Species) -> some View {
        let p = odds[sp] ?? 0
        let filled = Int((p * 20).rounded())
        return HStack(spacing: 8) {
            PixelImage(buffer: SpeciesArt.adult(sp), cell: 1)
                .frame(width: 36, height: 28)
            Text(sp.label).font(GrubFont.size(7)).foregroundColor(Color(ink: BurrowInk.cream))
                .frame(width: 52, alignment: .leading)
            HStack(spacing: 1) {
                ForEach(0..<20, id: \.self) { i in
                    Rectangle().fill(Color(ink: i < filled ? sp.color : BurrowInk.soil1)).frame(width: 5, height: 9)
                }
            }
            Text("\(Int((p * 100).rounded()))%").font(GrubFont.size(7))
                .foregroundColor(Color(ink: BurrowInk.cream))
                .frame(width: 36, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(sp.label.capitalized) \(Int((p * 100).rounded())) percent")
    }
}

/// Shown after the cocoon: the adult, its name and blurb. Phase 4 adds PIN IT.
struct RevealCardView: View {
    let species: Species
    let pin: () -> Void
    let later: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("IT MOLTED!").font(GrubFont.size(12)).foregroundColor(Color(ink: BurrowInk.cream))
                PixelImage(buffer: SpeciesArt.adult(species), cell: 6)
                    .padding(14)
                    .background(Color(ink: BurrowInk.soil2))
                    .overlay(Rectangle().strokeBorder(Color(ink: species.color), lineWidth: 3))
                Text(species.label).font(GrubFont.size(16)).foregroundColor(Color(ink: species.color))
                Text(species.blurb).font(GrubFont.size(8)).foregroundColor(Color(ink: BurrowInk.mutedText))
                HStack(spacing: 12) {
                    Button(action: later) {
                        Text("LATER").font(GrubFont.size(9)).foregroundColor(Color(ink: BurrowInk.hollow))
                            .padding(.horizontal, 14).padding(.vertical, 11)
                            .background(Color(ink: BurrowInk.creamDim))
                    }
                    .buttonStyle(PixelPressStyle())
                    Button(action: pin) {
                        Text("PIN IT").font(GrubFont.size(9)).foregroundColor(Color(ink: BurrowInk.hollow))
                            .padding(.horizontal, 18).padding(.vertical, 11)
                            .background(Color(ink: BurrowInk.amber))
                    }
                    .buttonStyle(PixelPressStyle())
                }
            }
            .padding(24)
            .background(Color(ink: BurrowInk.hollow))
            .overlay(Rectangle().strokeBorder(Color(ink: BurrowInk.soil1), lineWidth: 4))
            .padding(20)
        }
    }
}

/// Every pinned adult (spec §5). Adults use their plain species colours.
struct SpecimenBoxView: View {
    let specimens: [Specimen]
    let close: () -> Void
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)
    private static let date: DateFormatter = { let f = DateFormatter(); f.dateFormat = "MMM d"; return f }()

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea().onTapGesture(perform: close)
            VStack(spacing: 14) {
                Text("SPECIMENS").font(GrubFont.size(14)).foregroundColor(Color(ink: BurrowInk.cream))
                if specimens.isEmpty {
                    Text("NO SPECIMENS YET.\nMOLT A GRUB AND PIN IT.")
                        .font(GrubFont.size(8)).lineSpacing(6).multilineTextAlignment(.center)
                        .foregroundColor(Color(ink: BurrowInk.mutedText))
                        .padding(.vertical, 30)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(Array(specimens.enumerated()), id: \.offset) { _, s in cell(s) }
                        }
                    }
                    .frame(maxHeight: 420)
                }
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

    private func cell(_ s: Specimen) -> some View {
        VStack(spacing: 6) {
            PixelImage(buffer: SpeciesArt.adult(s.species), cell: 3)
                .frame(width: 120, height: 92)
                .background(Color(ink: BurrowInk.soil2))
                .overlay(Rectangle().strokeBorder(Color(ink: s.species.color), lineWidth: 3))
            Text(s.name).font(GrubFont.size(8)).foregroundColor(Color(ink: BurrowInk.cream))
            Text(s.species.label).font(GrubFont.size(7)).foregroundColor(Color(ink: s.species.color))
            Text(Self.date.string(from: s.pinnedAt).uppercased()).font(GrubFont.size(6))
                .foregroundColor(Color(ink: BurrowInk.mutedText))
        }
        .accessibilityElement(children: .combine)
    }
}

/// Name a new egg: A–Z and spaces, 1–10 letters (spec §5).
struct NamePromptView: View {
    let random: () -> String
    let submit: (String) -> Bool
    let cancel: () -> Void
    @State private var text: String
    @State private var invalid = false

    init(initial: String, random: @escaping () -> String,
         submit: @escaping (String) -> Bool, cancel: @escaping () -> Void) {
        self.random = random; self.submit = submit; self.cancel = cancel
        _text = State(initialValue: initial)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea().onTapGesture(perform: cancel)
            VStack(spacing: 16) {
                Text("NAME YOUR EGG").font(GrubFont.size(12)).foregroundColor(Color(ink: BurrowInk.cream))
                TextField("", text: $text)
                    .font(GrubFont.size(14)).multilineTextAlignment(.center)
                    .foregroundColor(Color(ink: BurrowInk.amber))
                    .textInputAutocapitalization(.characters).autocorrectionDisabled()
                    .padding(12)
                    .background(Color(ink: BurrowInk.soil4))
                    .overlay(Rectangle().strokeBorder(Color(ink: BurrowInk.soil1), lineWidth: 3))
                    .onChange(of: text) { _, new in
                        invalid = false
                        if new.count > BurrowRules.maxNameLength { text = String(new.prefix(BurrowRules.maxNameLength)) }
                    }
                    .onSubmit { invalid = !submit(text) }
                Text(invalid ? "USE 1-10 LETTERS" : "A-Z, UP TO 10").font(GrubFont.size(6))
                    .foregroundColor(Color(ink: invalid ? BurrowInk.berry : BurrowInk.mutedText))
                HStack(spacing: 12) {
                    Button { text = random() } label: {
                        Text("RANDOM").font(GrubFont.size(9)).foregroundColor(Color(ink: BurrowInk.hollow))
                            .padding(.horizontal, 14).padding(.vertical, 11)
                            .background(Color(ink: BurrowInk.creamDim))
                    }
                    .buttonStyle(PixelPressStyle())
                    Button { invalid = !submit(text) } label: {
                        Text("OK").font(GrubFont.size(9)).foregroundColor(Color(ink: BurrowInk.hollow))
                            .padding(.horizontal, 22).padding(.vertical, 11)
                            .background(Color(ink: BurrowInk.amber))
                    }
                    .buttonStyle(PixelPressStyle())
                }
            }
            .padding(24)
            .background(Color(ink: BurrowInk.hollow))
            .overlay(Rectangle().strokeBorder(Color(ink: BurrowInk.amber), lineWidth: 4))
            .padding(32)
        }
    }
}

#Preview {
    BurrowHomeView()
}
