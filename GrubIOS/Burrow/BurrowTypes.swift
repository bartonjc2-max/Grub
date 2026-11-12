import Foundation

/// The six adults from the species contact sheet (docs/burrow/species-contact-sheet.html).
enum Species: String, Codable, CaseIterable, CodingKeyRepresentable {
    case grub, horn, fuzz, shell, claws, stalk

    var label: String { rawValue.uppercased() }

    var blurb: String {
        switch self {
        case .grub:  return "THE ORIGINAL"
        case .horn:  return "STUBBORN DIGGER"
        case .fuzz:  return "SOFT, SHEDS TUFTS"
        case .shell: return "ROLLS UP TIGHT"
        case .claws: return "BORN TO DIG"
        case .stalk: return "SEES ROUND CORNERS"
        }
    }

    /// Body colour, 0xRRGGBB.
    var color: UInt32 {
        switch self {
        case .grub:  return 0x4ecca3
        case .horn:  return 0x8f6fe0
        case .fuzz:  return 0xf5a623
        case .shell: return 0x6f8fb0
        case .claws: return 0xc97b3a
        case .stalk: return 0xed93b1
        }
    }
}

enum GrubStage: String, Codable { case egg, larva, adult }

/// Something you can dig up (spec §2). Foods are eaten; decor is placed in the burrow.
enum FindKind: String, Codable, CaseIterable, Identifiable, CodingKeyRepresentable {
    case berry, amber, bone, crystal          // phase 1
    case root, mushroom, honeydew, shell      // phase 2 (append new cases, never reorder)

    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
    var isFood: Bool { Self.feedOrder.contains(self) }
    var isDecor: Bool { !isFood }

    /// The species this find nudges the molt odds toward.
    var leansTo: Species {
        switch self {
        case .berry:    return .grub
        case .root:     return .claws
        case .mushroom: return .stalk
        case .honeydew: return .fuzz
        case .crystal:  return .horn
        case .shell:    return .shell
        case .amber:    return .fuzz
        case .bone:     return .claws
        }
    }

    /// Decor comes out of the ground in three conditions. Three, not more: four kinds × three
    /// tiers is twelve visibly different objects, which is enough of a chase without a dozen
    /// new sprites — and unlike a longer list of kinds, it does not run out, because the top
    /// tier of every kind is a long way off. A longer list would only move the wall.
    static let maxTier = 3
    static func tierName(_ t: Int) -> String {
        switch max(1, min(maxTier, t)) {
        case 1:  return "CHIPPED"
        case 2:  return "FINE"
        default: return "PRISTINE"
        }
    }

    /// Foods, in the order auto-feed tries them.
    static let feedOrder: [FindKind] = [.berry, .root, .mushroom, .honeydew]
}

/// A find waiting in the soil, with the dig grid the player works through to reach it.
struct BuriedFind: Codable, Equatable {
    var spot: Int        // index into BurrowSpots.spots
    var kind: FindKind
    var condition: DigCondition?
    var findTile: Int
    var tiles: [DigTile]
    /// Set the first time the player digs here; drives the condition badge and the spur.
    var visited: Bool

    /// A grid is "missing" when it came from a v1 save (or a part-written v2 one).
    var needsGrid: Bool { tiles.count != DigGrid.tileCount }

    init(spot: Int, kind: FindKind, condition: DigCondition?,
         findTile: Int, tiles: [DigTile], visited: Bool = false) {
        self.spot = spot; self.kind = kind; self.condition = condition
        self.findTile = findTile; self.tiles = tiles; self.visited = visited
    }

    /// Convenience used by `fresh` and the tests: builds a grid from a seed derived from the
    /// spot, so the same spot always gets the same grid.
    init(spot: Int, kind: FindKind, condition: DigCondition? = nil) {
        var rng = BurrowRNG(seed: BuriedFind.seed(for: spot))
        let g = DigGen.make(layer: BurrowSpots.layer(spot), condition: condition, rng: &rng)
        self.init(spot: spot, kind: kind, condition: condition,
                  findTile: g.findTile, tiles: g.tiles)
    }

    static func seed(for spot: Int) -> UInt64 { 0x5EED_0000 &+ UInt64(spot) }

    /// v1 saves have only `spot` and `kind`. Decoding the rest leniently is what keeps
    /// `BurrowStore.load` from treating every existing save as corrupt.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        spot = try c.decode(Int.self, forKey: .spot)
        kind = try c.decode(FindKind.self, forKey: .kind)
        condition = try c.decodeIfPresent(DigCondition.self, forKey: .condition)
        findTile = try c.decodeIfPresent(Int.self, forKey: .findTile) ?? 0
        tiles = try c.decodeIfPresent([DigTile].self, forKey: .tiles) ?? []
        visited = try c.decodeIfPresent(Bool.self, forKey: .visited) ?? false
    }
}

struct Specimen: Codable, Equatable {
    var name: String
    var species: Species
    var pinnedAt: Date
}
