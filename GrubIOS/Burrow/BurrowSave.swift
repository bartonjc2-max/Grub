import Foundation

/// All burrow game state. Pure data — the rules live in `BurrowRules`.
/// Every spec field exists from version 1 so later phases need no migration.
struct BurrowSave: Codable, Equatable {
    static let currentVersion = 1

    var version = BurrowSave.currentVersion
    var stage: GrubStage
    var name: String
    var eggCracks = 0
    var belly: Int
    var joy: Int
    var molt: Int
    var digs: Int
    var buried: [BuriedFind]
    var holes: [Int] = []
    var bag: [FindKind: Int]
    var placed: [Int: FindKind] = [:]
    var eaten: [FindKind: Int] = [:]
    var lastMeal: FindKind?
    var lineage: Species?
    var tint: Species?
    var adult: Species?
    var specimens: [Specimen] = []
    var lastTick: Date
    var digTimer: TimeInterval = 0
    var buryTimer: TimeInterval = 0
    var bellyTimer: TimeInterval = 0
    var joyTimer: TimeInterval = 0
    var lastPetAt: Date

    /// A brand-new game. Phase 1 starts at `.larva` named GRUB (phase 4 switches to `.egg`).
    static func fresh(now: Date) -> BurrowSave {
        BurrowSave(stage: .larva, name: "GRUB",
                   belly: 6, joy: 6, molt: 0, digs: 3,
                   buried: [BuriedFind(spot: 0, kind: .berry),
                            BuriedFind(spot: 1, kind: .amber),
                            BuriedFind(spot: 2, kind: .crystal)],
                   bag: [.berry: 1],
                   lastTick: now,
                   lastPetAt: now.addingTimeInterval(-86_400))
    }
}
