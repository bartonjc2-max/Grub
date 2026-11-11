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

    private static let crawlBase: TimeInterval = 1.0
    private static let crawlCap: TimeInterval = 1.5
    private static let zoom: TimeInterval = 0.6
    private static let prizeHold: TimeInterval = 2.0

    private var path: [Waypoint] { BurrowWaypoints.path(to: trip.spot, layout) }

    private var duration: TimeInterval {
        switch trip.phase {
        case .crawlingOut, .crawlingHome:
            return min(Self.crawlCap, Self.crawlBase + Double(path.count) * 0.05)
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
                .allowsHitTesting(trip.phase != .crawlingOut && trip.phase != .crawlingHome)
                .animation(.easeInOut(duration: Self.zoom), value: trip.phase)

            switch trip.phase {
            case .crawlingOut, .crawlingHome:
                TimelineView(.animation(minimumInterval: 1.0 / 24)) { tl in
                    traveller(at: eased(progress(tl.date)))
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
        case .crawlingOut, .crawlingHome: return 0
        case .zoomingIn, .zoomingOut, .digging: return 0.95
        }
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
        let p = BurrowSpots.resolve(trip.spot, layout)
        let screen = layout.point(Double(p.x) + 0.5, Double(p.y))
        return UnitPoint(x: min(1, max(0, screen.x / size.width)),
                         y: min(1, max(0, screen.y / size.height)))
    }

    /// The grub itself, somewhere along the route. `crawlingHome` runs the path backwards.
    @ViewBuilder
    private func traveller(at t: Double) -> some View {
        let route = trip.phase == .crawlingHome ? path.reversed().map { $0 } : path
        let i = min(route.count - 1, Int((Double(route.count - 1) * t).rounded()))
        let w = route[i]
        let sprite = GrubArt.frames(tint: model.tint).idle
        // A little squash as it crawls, on the same 24 fps clock as the rest of the burrow.
        let wiggle = Int((sin(t * 22) * 1.2).rounded())
        // Spots 0, 3 and 5 sit within half a sprite of the left edge, so centring the grub on
        // the waypoint would slice it in half against the bezel. Keep it inside the design grid.
        let half = Double(sprite.width) / 2
        let cx = min(Double(BurrowLayout.designCols) - half, max(half, Double(w.x)))
        let origin = layout.point(cx - half,
                                  Double(w.y) - Double(sprite.height) / 2 + Double(wiggle))

        PixelImage(buffer: sprite, cell: layout.cell)
            .position(x: origin.x + CGFloat(sprite.width) * layout.cell / 2,
                      y: origin.y + CGFloat(sprite.height) * layout.cell / 2)
            .accessibilityHidden(true)
    }
}
