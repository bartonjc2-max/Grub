import SwiftUI

/// The dig mini-game: a 5 × 5 patch of soil at one spot. Each strike breaks a tile and tells
/// you how close the find was — hot, warm or cold — and you have a limited number of them.
/// Spec: docs/superpowers/specs/2026-11-10-dig-minigame-design.md §1.
struct DigGridView: View {
    @ObservedObject var model: BurrowHomeModel
    let trip: DigTrip
    let find: BuriedFind
    let layout: BurrowLayout
    let width: CGFloat
    @Environment(\.displayScale) private var displayScale

    /// Points per art pixel, sized so the 5 × 9-pixel grid fills ~86 % of the screen width and
    /// lands on whole device pixels (the art is nearest-neighbour, so a fractional pixel size
    /// would make some rows a hair thicker than others).
    ///
    /// The burrow draws 64 design cells across the same width; this draws 5 tiles. That ~12×
    /// difference is the zoom — Task 18's transition animates between the two.
    private var px: CGFloat {
        let ideal = width * 0.86 / CGFloat(DigGrid.side * DigArt.side)
        return max(1, (ideal * displayScale).rounded(.down)) / displayScale
    }

    var body: some View {
        VStack(spacing: px * 4) {
            header
            grid
            Button("BACK") { model.leaveTrip() }
                .font(GrubFont.size(9))
                .foregroundColor(Color(ink: BurrowInk.cream))
                .padding(.horizontal, 18).padding(.vertical, 12)
                .background(Color(ink: BurrowInk.hollow))
                .overlay(Rectangle().strokeBorder(Color(ink: BurrowInk.soil1), lineWidth: 3))
                .buttonStyle(PixelPressStyle())
                .accessibilityHint("Leave the dig. Broken tiles stay broken.")
        }
    }

    private var header: some View {
        VStack(spacing: px * 2) {
            Text(BurrowSpots.layer(trip.spot).label)
                .font(GrubFont.size(10))
                .foregroundColor(Color(ink: BurrowInk.cream))
            if let c = find.condition {
                Text(c.label)
                    .font(GrubFont.size(7))
                    .foregroundColor(Color(ink: BurrowInk.amber))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .overlay(Rectangle().strokeBorder(Color(ink: BurrowInk.amberLo), lineWidth: 2))
            }
            strikeRow
        }
    }

    /// One shovel per strike left, so the budget is readable at a glance rather than counted.
    private var strikeRow: some View {
        HStack(spacing: px) {
            ForEach(0..<max(trip.strikesLeft, 0), id: \.self) { _ in
                PixelImage(buffer: IconArt.shovel, cell: px)
            }
        }
        .frame(height: px * 6)
        .accessibilityElement()
        .accessibilityLabel("\(trip.strikesLeft) strikes left")
    }

    private var grid: some View {
        VStack(spacing: 0) {
            ForEach(0..<DigGrid.side, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<DigGrid.side, id: \.self) { col in
                        tile(row * DigGrid.side + col)
                    }
                }
            }
        }
        .overlay(Rectangle().strokeBorder(Color(ink: BurrowInk.hollow), lineWidth: 3))
    }

    private func tile(_ i: Int) -> some View {
        PixelImage(buffer: buffer(for: i), cell: px)
            .contentShape(Rectangle())
            .onTapGesture { model.strike(tile: i) }
            .accessibilityElement()
            .accessibilityLabel("Row \(DigGrid.row(i) + 1), column \(DigGrid.col(i) + 1)")
            .accessibilityValue(label(for: i))
            .accessibilityAddTraits(.isButton)
    }

    /// A broken tile's heat isn't stored — the save keeps only `.broken` — so it's recomputed
    /// from the find's position. That's not a leak: the player paid a strike to learn it.
    private func heat(_ i: Int) -> Heat {
        DigGrid.heat(distance: DigGrid.distance(i, find.findTile), wet: find.condition == .wet)
    }

    private func buffer(for i: Int) -> PixelBuffer {
        switch find.tiles[i] {
        case .soil:          return DigArt.soil
        case .root:          return DigArt.root
        case .rock(let hp):  return hp > 1 ? DigArt.rockWhole : DigArt.rockCracked
        case .broken:
            switch heat(i) {
            case .hot:  return DigArt.brokenHot
            case .warm: return DigArt.brokenWarm
            case .cold: return DigArt.brokenCold
            }
        }
    }

    private func label(for i: Int) -> String {
        switch find.tiles[i] {
        case .soil:         return "not dug"
        case .root:         return "root, can't dig"
        case .rock(let hp): return hp > 1 ? "rock" : "cracked rock"
        case .broken:       return heat(i).rawValue
        }
    }
}

extension SoilLayer {
    var label: String {
        switch self {
        case .loose: return "LOOSE SOIL"
        case .clay:  return "CLAY"
        case .deep:  return "DEEP SOIL"
        }
    }
}

extension DigCondition {
    var label: String {
        switch self {
        case .wet:      return "WET — HARD TO READ"
        case .rocky:    return "ROCKY"
        case .rooty:    return "ROOTY"
        case .glinting: return "SOMETHING GLINTS"
        }
    }
}
