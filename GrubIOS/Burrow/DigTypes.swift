import Foundation

/// One tile of a dig grid. `rock` needs `hp` strikes before it breaks.
enum DigTile: Codable, Equatable {
    case soil
    case rock(hp: Int)
    case root
    case broken

    /// Can a strike land here at all? (Roots and already-broken tiles can't.)
    var isDiggable: Bool {
        switch self {
        case .soil, .rock: return true
        case .root, .broken: return false
        }
    }

    /// Strikes still needed to break this tile.
    var cost: Int {
        switch self {
        case .soil: return 1
        case .rock(let hp): return hp
        case .root, .broken: return 0
        }
    }

    /// Needed by the generation tests and the `-burrowDigDemo` precondition assert, so it
    /// lives in the app target rather than as a private test helper.
    var isRock: Bool { if case .rock = self { return true }; return false }
}

/// A per-spot twist, rolled when the find is buried. `nil` means a plain spot.
enum DigCondition: String, Codable, CaseIterable, Equatable {
    case wet, rocky, rooty, glinting
}

/// How deep the spot is. Fixed per spot; never saved (it comes from `BurrowSpots`).
enum SoilLayer: String, CaseIterable, Equatable {
    case loose, clay, deep

    /// Strikes a trip to this layer grants, before conditions and mood.
    var strikes: Int {
        switch self {
        case .loose: return 6
        case .clay:  return 5
        case .deep:  return 4
        }
    }

    /// Obstacles the layer places, beyond any the condition adds.
    var rocks: Int { self == .clay ? 3 : 0 }
    var roots: Int { self == .deep ? 3 : 0 }
}

/// What a broken tile tells you about where the find is.
enum Heat: String, Codable, Equatable { case hot, warm, cold }

/// Geometry of the 5 × 5 dig grid. Tiles are indexed row-major, row 0 at the top.
enum DigGrid {
    static let side = 5
    static let tileCount = side * side

    static func row(_ i: Int) -> Int { i / side }
    static func col(_ i: Int) -> Int { i % side }

    /// Manhattan distance between two tile indices.
    static func distance(_ a: Int, _ b: Int) -> Int {
        abs(row(a) - row(b)) + abs(col(a) - col(b))
    }

    /// Spec §1: d == 1 is hot, d == 2 is warm (cold when wet), further is cold.
    /// d == 0 is the find tile itself — `strike` reports a heat for it too, and "hot" is the
    /// only answer that isn't a lie.
    static func heat(distance d: Int, wet: Bool) -> Heat {
        switch d {
        case 0, 1: return .hot
        case 2: return wet ? .cold : .warm
        default: return .cold
        }
    }
}
