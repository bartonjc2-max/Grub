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

    /// Relative chance of being buried (spec §2). Sums to 100; foods are 70.
    var buryWeight: Int {
        switch self {
        case .berry:    return 30
        case .root:     return 15
        case .mushroom: return 15
        case .honeydew: return 10
        case .crystal:  return 8
        case .shell:    return 8
        case .amber:    return 7
        case .bone:     return 7
        }
    }

    /// Foods, in the order auto-feed tries them.
    static let feedOrder: [FindKind] = [.berry, .root, .mushroom, .honeydew]
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
