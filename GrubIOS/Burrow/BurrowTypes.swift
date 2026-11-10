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

/// Something you can dig up. Phase 1 has the four finds that already have sprites;
/// phase 2 adds root, mushroom, honeydew and shell.
enum FindKind: String, Codable, CaseIterable, Identifiable, CodingKeyRepresentable {
    case berry, amber, bone, crystal

    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
    var isFood: Bool { self == .berry }

    /// The species this find nudges the molt odds toward.
    var leansTo: Species {
        switch self {
        case .berry:   return .grub
        case .amber:   return .fuzz
        case .bone:    return .claws
        case .crystal: return .horn
        }
    }

    /// Relative chance of being buried (spec "Finds and digging").
    var buryWeight: Int {
        switch self {
        case .berry:   return 30
        case .amber:   return 7
        case .bone:    return 7
        case .crystal: return 8
        }
    }

    /// Auto-feed tries foods in this order.
    static let feedOrder: [FindKind] = allCases.filter(\.isFood)
}

struct BuriedFind: Codable, Equatable {
    var spot: Int        // index into BurrowSpots.anchors
    var kind: FindKind
}

struct Specimen: Codable, Equatable {
    var name: String
    var species: Species
    var pinnedAt: Date
}
