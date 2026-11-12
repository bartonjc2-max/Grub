import SwiftUI

/// The journey to a dig and back: the grub crawls out along the tunnels, the view zooms in on
/// the patch of soil, the player digs, and then it all plays backwards. Spec §2.
///
/// The phases live on the model (`TripPhase`) so they can be tested; this view only draws them
/// and sets the timers that step from one to the next. A tap anywhere skips ahead.
struct DigTripView: View {
    @ObservedObject var model: BurrowHomeModel
    let trip: DigTrip
    let find: BuriedFind
    let layout: BurrowLayout
    let size: CGSize

    @State private var startedAt = Date()
    @Environment(\.displayScale) private var displayScale

    private static let crawlBase: TimeInterval = 1.4
    private static let crawlCap: TimeInterval = 2.0
    private static let zoom: TimeInterval = 0.6
    private static let prizeHold: TimeInterval = 2.0
    private static let burrowIn: TimeInterval = 0.75
    private static let surfacing: TimeInterval = 0.55

    /// How small the grub gets by the time it reaches the spot. The burrow is drawn side-on,
    /// so there is no perspective to shrink it — this *is* the depth cue, and it is the beat
    /// that turns the walk into a journey instead of a sprite sliding across a backdrop.
    private static let farScale: Double = 0.45

    private var path: [Waypoint] { BurrowWaypoints.path(to: trip.spot, layout) }

    private var duration: TimeInterval {
        switch trip.phase {
        case .crawlingOut, .crawlingHome:
            return min(Self.crawlCap, Self.crawlBase + Double(path.count) * 0.05)
        case .burrowingIn: return Self.burrowIn
        case .surfacing:   return Self.surfacing
        case .zoomingIn: return Self.zoom
        // A clean dig puts a banner on the grid, so the way out is held long enough to read
        // it. Without this the reward is a 0.6 s flash behind a shrinking grid.
        case .zoomingOut: return model.cleanDigPrize == nil ? Self.zoom : Self.prizeHold
        case .digging: return .infinity
        }
    }

    var body: some View {
        ZStack {
            Color(ink: BurrowInk.hollow)
                .opacity(dimmer)
                .ignoresSafeArea()
                // Only intercept taps when it is actually covering something.
                .allowsHitTesting(dimmer > 0)
                .animation(.easeInOut(duration: Self.zoom), value: trip.phase)

            switch trip.phase {
            case .crawlingOut, .crawlingHome:
                TimelineView(.animation(minimumInterval: 1.0 / 24)) { tl in
                    traveller(at: eased(progress(tl.date)))
                }
            case .burrowingIn, .surfacing:
                TimelineView(.animation(minimumInterval: 1.0 / 24)) { tl in
                    let p = progress(tl.date)
                    burrower(at: trip.phase == .surfacing ? 1 - p : p)
                }
            case .zoomingIn, .zoomingOut, .digging:
                TimelineView(.animation(minimumInterval: 1.0 / 24)) { tl in
                    let p = trip.phase == .digging ? 1 : progress(tl.date)
                    // While a prize is showing, the grid stays put until the last third, so
                    // the banner isn't shrinking away while it is being read.
                    let out = model.cleanDigPrize == nil ? p : max(0, (p - 0.66) * 3)
                    let t = trip.phase == .zoomingOut ? 1 - out : p
                    grid
                        .scaleEffect(0.12 + 0.88 * eased(t), anchor: spotAnchor)
                        .opacity(trip.phase == .digging ? 1 : eased(t))
                }
            }
        }
        // A tap anywhere hurries the journey along — but not during the dig, where every tap
        // belongs to a tile.
        .contentShape(Rectangle())
        .onTapGesture { if trip.phase != .digging { model.skip() } }
        .task(id: trip.phase) {
            startedAt = Date()
            guard duration.isFinite else { return }
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            model.skip()
        }
    }

    private var grid: some View {
        DigGridView(model: model, trip: trip, find: find, layout: layout, width: size.width)
            .frame(width: size.width, height: size.height)
    }

    /// 0 while crawling (the burrow stays in view), full once the grid is up. A plain value
    /// per phase, tweened by the animation modifier on the view — reading the clock here
    /// instead only sampled it when the body happened to re-render, which left the burrow
    /// half-faded at odd moments.
    private var dimmer: Double {
        switch trip.phase {
        case .crawlingOut, .crawlingHome, .burrowingIn, .surfacing: return 0
        case .zoomingIn, .zoomingOut, .digging: return 0.95
        }
    }

    /// Keep a shrinking sprite on whole device pixels — the same rule `BurrowLayout` uses for
    /// the world grid. Scaled off the grid, the grub shimmers and tears as it recedes.
    private func cell(for scale: Double) -> CGFloat {
        max(1, (layout.cell * CGFloat(scale) * displayScale).rounded()) / displayScale
    }

    /// Full size in the chamber, `farScale` at the spot.
    private func travelScale(_ along: Double) -> Double {
        1 - (1 - Self.farScale) * min(1, max(0, along))
    }

    private func progress(_ now: Date) -> Double {
        guard duration.isFinite, duration > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(startedAt) / duration))
    }

    /// Ease in and out, so the crawl starts and stops rather than snapping to a constant speed.
    private func eased(_ t: Double) -> Double { t * t * (3 - 2 * t) }

    /// The spot's position as a unit point, so the zoom grows out of the soil being dug
    /// rather than out of the middle of the screen.
    private var spotAnchor: UnitPoint {
        return UnitPoint(x: min(1, max(0, moundX / size.width)),
                         y: min(1, max(0, moundY / size.height)))
    }

    /// Where the mound is on screen — the same clamped centre the burrow draws it at, and the
    /// crown the grub digs into. The grid grows out of this point, so the hole it vanished
    /// into is the hole the mini-game opens from.
    private var moundX: CGFloat {
        layout.point(BurrowSpots.markerCentre(trip.spot, layout, width: MarkerArt.mound.width), 0).x
    }
    private var moundCrownRow: Double { Double(BurrowSpots.resolve(trip.spot, layout).y) - 4 }
    private var moundY: CGFloat { (CGFloat(moundCrownRow) + 2) * layout.cell }

    /// The grub itself, somewhere along the route. `crawlingHome` runs the path backwards.
    @ViewBuilder
    private func traveller(at t: Double) -> some View {
        let home = trip.phase == .crawlingHome
        let route = home ? path.reversed().map { $0 } : path
        let i = min(route.count - 1, Int((Double(route.count - 1) * t).rounded()))
        let w = route[i]
        let sprite = GrubArt.frames(tint: model.tint).idle
        // How far along the *outbound* journey this frame is, so the grub shrinks on the way
        // out and grows again on the way back without two copies of the ramp.
        let scale = travelScale(home ? 1 - t : t)
        let c = cell(for: scale)
        // A little squash as it crawls, on the same 24 fps clock as the rest of the burrow.
        let wiggle = sin(t * 22) * 1.2
        // Spots 0, 3 and 5 sit within half a sprite of the left edge, so centring the grub on
        // the waypoint would slice it in half against the bezel. Keep it inside the design
        // grid — and as it shrinks it is allowed closer in, which is why this uses `scale`.
        let half = Double(sprite.width) * scale / 2
        let cx = min(Double(BurrowLayout.designCols) - half, max(half, Double(w.x)))

        PixelImage(buffer: sprite, cell: c)
            .position(x: layout.point(cx, 0).x,
                      y: (CGFloat(w.y) + CGFloat(wiggle)) * layout.cell)
            .accessibilityHidden(true)
    }

    /// The hinge of the cut-scene: the grub digs into the mound and goes under, throwing dirt.
    /// `p` runs 0 → 1 going in, and the same frames play backwards when it surfaces.
    @ViewBuilder
    private func burrower(at p: Double) -> some View {
        let q = min(1, max(0, p))
        let sprite = GrubArt.frames(tint: model.tint).idle
        let scale = Self.farScale * (1 - eased(q))
        let c = cell(for: scale)
        // It sinks as it shrinks, so it reads as going *into* the ground rather than simply
        // fading out where it stood.
        let bottom = moundCrownRow + q * 3

        if scale > 0.03 {
            PixelImage(buffer: sprite, cell: c)
                .position(x: moundX,
                          y: CGFloat(bottom) * layout.cell - CGFloat(sprite.height) * c / 2)
                .accessibilityHidden(true)
        }
        // Dirt thrown out of the hole. Each speck is one world cell, launched on its own
        // slightly later clock so they don't move as a block.
        ForEach(0..<6, id: \.self) { k in
            let fly = min(1, max(0, (q - Double(k) * 0.07) * 1.7))
            if fly > 0 && fly < 1 {
                let dir: Double = k % 2 == 0 ? -1 : 1
                Rectangle()
                    .fill(Color(ink: k % 2 == 0 ? BurrowInk.dirt : BurrowInk.dirtHi))
                    .frame(width: layout.cell, height: layout.cell)
                    .position(x: moundX + CGFloat(dir * (2 + Double(k % 3)) * fly) * layout.cell,
                              y: CGFloat(moundCrownRow - 3.5 * sin(fly * .pi)) * layout.cell)
                    .opacity(1 - fly)
                    .accessibilityHidden(true)
            }
        }
    }
}
