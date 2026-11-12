import Foundation

/// All burrow game state. Pure data — the rules live in `BurrowRules`.
/// Version 2 added the dig grid to `BuriedFind`; version 3 added decor tiers; version 4
/// moved the dig sites out of a frozen table and into the save, so they can move.
/// See `BurrowStore.migrate` and the lenient `init(from:)` below.
struct BurrowSave: Codable, Equatable {
    static let currentVersion = 4

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
    /// The best tier of each decor kind the player holds, and surplus progress toward the
    /// next one. Keyed by kind, not per item: `placed` stores only the kind, so a furnished
    /// slot shows whatever the best one you own looks like and improves the moment this ticks.
    var bestTier: [FindKind: Int] = [:]
    var bank: [FindKind: Int] = [:]
    /// Where the eight dig sites currently are. Empty means a save from before they could
    /// move, which reads as the old fixed map; `migrate` fills it in.
    var spots: [SpotPlacement] = []
    var lastTick: Date
    var digTimer: TimeInterval = 0
    var buryTimer: TimeInterval = 0
    var bellyTimer: TimeInterval = 0
    var joyTimer: TimeInterval = 0
    var lastPetAt: Date

    /// Where a dig site is now. Out-of-range or an empty map falls back to the fixed table
    /// the game shipped with, so nothing can read a position that does not exist.
    func placement(_ spot: Int) -> SpotPlacement {
        let map = spots.isEmpty ? BurrowSpots.fallback : spots
        return map.indices.contains(spot) ? map[spot] : BurrowSpots.fallback[0]
    }
    func layer(_ spot: Int) -> SoilLayer { placement(spot).layer }

    /// The tier of `kind` the player holds. Absent means 1 — a save written before tiers
    /// existed holds plain things, and plain is exactly tier 1, so nothing needs migrating.
    func tier(_ kind: FindKind) -> Int { min(FindKind.maxTier, max(1, bestTier[kind] ?? 1)) }

    /// A brand-new game: an unnamed egg (spec §5 "First launch").
    /// The three starter finds are deliberately plain (`condition: nil`) so a first dig is
    /// simple; each still gets a grid, from its spot's seed.
    static func fresh(now: Date) -> BurrowSave {
        var rng = BurrowRNG(seed: 0x5EED_0F15)
        return BurrowSave(stage: .egg, name: "",
                   belly: 6, joy: 6, molt: 0, digs: 3,
                   buried: [BuriedFind(spot: 0, kind: .berry),
                            BuriedFind(spot: 1, kind: .root),
                            BuriedFind(spot: 2, kind: .crystal)],
                   bag: [.berry: 1],
                   spots: BurrowSpots.generate(rng: &rng),
                   lastTick: now,
                   lastPetAt: now.addingTimeInterval(-86_400))
    }
}

// The decoder lives in an extension so the memberwise `init` survives — declaring an
// initialiser inside the struct body would suppress it, and `fresh` relies on it.
extension BurrowSave {
    enum CodingKeys: String, CodingKey {
        case version, stage, name, eggCracks, belly, joy, molt, digs, buried, holes, bag,
             placed, eaten, lastMeal, lineage, tint, adult, specimens, bestTier, bank, spots,
             lastTick, digTimer, buryTimer, bellyTimer, joyTimer, lastPetAt
    }

    /// Decodes leniently: every field that has a default survives being absent from the file.
    ///
    /// This is load-bearing, not tidiness. Swift's synthesized `Decodable` does **not** fall
    /// back to a property's default value — a missing key throws — and `BurrowStore.load`
    /// treats any decode failure as corruption, moving the save aside and starting a fresh
    /// egg. So adding a field to this struct the obvious way silently deletes every player's
    /// game on the update that ships it. `BuriedFind` has decoded this way since the grid
    /// went in; this does it for the save as a whole, so the *next* field added here is safe
    /// because of the code rather than because someone remembered.
    ///
    /// The fields with no default — stage, the stats, buried, bag, the two dates — stay
    /// required: a file missing those is genuinely broken, and resurrecting half a save is
    /// worse than starting over.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func opt<T: Decodable>(_ k: CodingKeys, _ fallback: T) throws -> T {
            try c.decodeIfPresent(T.self, forKey: k) ?? fallback
        }
        version   = try opt(.version, 1)
        stage     = try c.decode(GrubStage.self, forKey: .stage)
        name      = try opt(.name, "")
        eggCracks = try opt(.eggCracks, 0)
        belly     = try c.decode(Int.self, forKey: .belly)
        joy       = try c.decode(Int.self, forKey: .joy)
        molt      = try c.decode(Int.self, forKey: .molt)
        digs      = try c.decode(Int.self, forKey: .digs)
        buried    = try c.decode([BuriedFind].self, forKey: .buried)
        holes     = try opt(.holes, [])
        bag       = try c.decode([FindKind: Int].self, forKey: .bag)
        placed    = try opt(.placed, [:])
        eaten     = try opt(.eaten, [:])
        lastMeal  = try c.decodeIfPresent(FindKind.self, forKey: .lastMeal)
        lineage   = try c.decodeIfPresent(Species.self, forKey: .lineage)
        tint      = try c.decodeIfPresent(Species.self, forKey: .tint)
        adult     = try c.decodeIfPresent(Species.self, forKey: .adult)
        specimens = try opt(.specimens, [])
        bestTier  = try opt(.bestTier, [:])
        bank      = try opt(.bank, [:])
        spots     = try opt(.spots, [])
        lastTick  = try c.decode(Date.self, forKey: .lastTick)
        digTimer  = try opt(.digTimer, 0)
        buryTimer = try opt(.buryTimer, 0)
        bellyTimer = try opt(.bellyTimer, 0)
        joyTimer  = try opt(.joyTimer, 0)
        lastPetAt = try c.decode(Date.self, forKey: .lastPetAt)
    }
}

/// Reads and writes `burrow.json`. Unreadable or newer-version files are renamed
/// `burrow.corrupt.json` (never deleted) and a fresh game starts.
struct BurrowStore {
    let directory: URL
    var fileURL: URL { directory.appendingPathComponent("burrow.json") }
    var corruptURL: URL { directory.appendingPathComponent("burrow.corrupt.json") }

    static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    init(directory: URL = BurrowStore.defaultDirectory) {
        self.directory = directory
    }

    func load(now: Date = Date()) -> BurrowSave {
        guard let data = try? Data(contentsOf: fileURL) else { return .fresh(now: now) }
        // A missing `version` means "older than versioning", not "corrupt". Reading it
        // strictly would send exactly the saves the lenient decoder exists to rescue
        // straight to moveAside().
        struct VersionOnly: Decodable {
            let version: Int
            init(from d: Decoder) throws {
                version = try d.container(keyedBy: BurrowSave.CodingKeys.self)
                    .decodeIfPresent(Int.self, forKey: .version) ?? 1
            }
        }
        if let v = try? JSONDecoder().decode(VersionOnly.self, from: data),
           v.version <= BurrowSave.currentVersion,
           var save = try? JSONDecoder().decode(BurrowSave.self, from: data) {
            if migrate(&save) { try? self.save(save) }
            return save
        }
        moveAside()
        return .fresh(now: now)
    }

    /// Fill in anything an older save is missing. Returns true if the save changed.
    /// Grids are rebuilt from a spot-derived seed, so migrating twice gives the same burrow.
    /// A missing grid is repaired *regardless of version*, so a part-written v2 save can't
    /// reach the grid screen with nothing to show.
    private func migrate(_ s: inout BurrowSave) -> Bool {
        var changed = s.version != BurrowSave.currentVersion
        for i in s.buried.indices where s.buried[i].needsGrid {
            let f = s.buried[i]
            var rng = BurrowRNG(seed: BuriedFind.seed(for: f.spot))
            let condition = DigGen.rollCondition(rng: &rng)
            let g = DigGen.make(layer: s.layer(f.spot), condition: condition, rng: &rng)
            // `kind` is kept exactly as it was, even where it falls outside the layer's table.
            s.buried[i] = BuriedFind(spot: f.spot, kind: f.kind, condition: condition,
                                     findTile: g.findTile, tiles: g.tiles, visited: f.visited)
            changed = true
        }
        // A save from before the sites could move keeps the map it has been looking at; it
        // starts changing only as spots are used, so the update itself is not a shuffle.
        if s.spots.count != BurrowRules.spotCount {
            s.spots = BurrowSpots.fallback
            changed = true
        }
        s.version = BurrowSave.currentVersion
        return changed
    }

    func save(_ s: BurrowSave) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(s).write(to: fileURL, options: .atomic)
    }

    /// Delete the save (DEBUG `-burrowReset`).
    func reset() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func moveAside() {
        let fm = FileManager.default
        try? fm.removeItem(at: corruptURL)
        try? fm.moveItem(at: fileURL, to: corruptURL)
    }
}
