import Foundation

/// All burrow game state. Pure data — the rules live in `BurrowRules`.
/// Version 2 added the dig grid to `BuriedFind`; see `BurrowStore.migrate`.
struct BurrowSave: Codable, Equatable {
    static let currentVersion = 2

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

    /// A brand-new game: an unnamed egg (spec §5 "First launch").
    /// The three starter finds are deliberately plain (`condition: nil`) so a first dig is
    /// simple; each still gets a grid, from its spot's seed.
    static func fresh(now: Date) -> BurrowSave {
        BurrowSave(stage: .egg, name: "",
                   belly: 6, joy: 6, molt: 0, digs: 3,
                   buried: [BuriedFind(spot: 0, kind: .berry),
                            BuriedFind(spot: 1, kind: .root),
                            BuriedFind(spot: 2, kind: .crystal)],
                   bag: [.berry: 1],
                   lastTick: now,
                   lastPetAt: now.addingTimeInterval(-86_400))
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
        struct VersionOnly: Decodable { let version: Int }
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
            let g = DigGen.make(layer: BurrowSpots.layer(f.spot), condition: condition, rng: &rng)
            // `kind` is kept exactly as it was, even where it falls outside the layer's table.
            s.buried[i] = BuriedFind(spot: f.spot, kind: f.kind, condition: condition,
                                     findTile: g.findTile, tiles: g.tiles, visited: f.visited)
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
