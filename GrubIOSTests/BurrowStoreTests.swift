import XCTest
@testable import GrubIOS

final class BurrowStoreTests: XCTestCase {
    let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func test_fresh_save_matches_spec() {
        let s = BurrowSave.fresh(now: t0)
        XCTAssertEqual(s.version, BurrowSave.currentVersion)
        XCTAssertEqual(s.stage, .egg)
        XCTAssertEqual(s.name, "")
        XCTAssertEqual(s.eggCracks, 0)
        XCTAssertEqual([s.belly, s.joy, s.molt, s.digs], [6, 6, 0, 3])
        XCTAssertEqual(s.bag, [.berry: 1])
        XCTAssertEqual(s.buried, [BuriedFind(spot: 0, kind: .berry),
                                  BuriedFind(spot: 1, kind: .root),
                                  BuriedFind(spot: 2, kind: .crystal)])
        XCTAssertTrue(s.holes.isEmpty && s.placed.isEmpty && s.eaten.isEmpty && s.specimens.isEmpty)
        XCTAssertEqual(s.lastTick, t0)
        XCTAssertEqual(s.lastPetAt, t0.addingTimeInterval(-86_400))
    }

    func test_save_json_round_trip() throws {
        var s = BurrowSave.fresh(now: t0)
        s.placed = [1: .amber]
        s.eaten = [.berry: 2]
        s.lastMeal = .berry
        s.lineage = .horn
        s.specimens = [Specimen(name: "BOB", species: .stalk, pinnedAt: t0)]
        let data = try JSONEncoder().encode(s)
        XCTAssertEqual(try JSONDecoder().decode(BurrowSave.self, from: data), s)
        // Enum-keyed dictionaries must encode as readable objects, not arrays.
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(json.contains("\"berry\":1"), json)
    }

    /// The guard that matters most in this file.
    ///
    /// Swift's synthesized `Decodable` ignores a property's default value — a missing key
    /// throws — and `load` treats any decode failure as corruption: it moves the file aside
    /// and hands back a fresh egg. So adding a field to `BurrowSave` without a lenient
    /// decoder would delete every player's game on the update that ships it. This decodes a
    /// save written before a field existed and asserts it survives, which is the behaviour
    /// the *next* field added to that struct depends on, not just today's two.
    func test_a_save_missing_newer_fields_survives_rather_than_being_wiped() throws {
        var s = BurrowSave.fresh(now: t0)
        s.name = "PIP"
        s.placed = [1: .amber]
        s.specimens = [Specimen(name: "PIP", species: .horn, pinnedAt: t0)]
        let full = try JSONSerialization.jsonObject(with: JSONEncoder().encode(s)) as! [String: Any]

        // Every key that carries a default, removed — i.e. a file written by any older build.
        var old = full
        for k in ["bestTier", "bank", "holes", "placed", "eaten", "specimens", "eggCracks",
                  "digTimer", "buryTimer", "bellyTimer", "joyTimer", "version", "name"] {
            old.removeValue(forKey: k)
        }
        let data = try JSONSerialization.data(withJSONObject: old)

        let dir = tempDir()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = BurrowStore(directory: dir)
        try data.write(to: store.fileURL)

        let loaded = store.load(now: t0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.corruptURL.path),
                       "an older save is not corruption")
        XCTAssertEqual(loaded.stage, .egg, "the real fields came through")
        XCTAssertEqual(loaded.belly, 6)
        XCTAssertEqual(loaded.bag, [.berry: 1])
        XCTAssertEqual(loaded.buried.count, 3)
        XCTAssertTrue(loaded.bestTier.isEmpty, "the new fields fall back to their defaults")
        XCTAssertTrue(loaded.bank.isEmpty)
        XCTAssertEqual(loaded.tier(.crystal), 1, "and read as plain, which is tier 1")
        XCTAssertEqual(loaded.version, BurrowSave.currentVersion, "migrated forward")
    }

    /// A save that is genuinely broken — missing a field that never had a default — must
    /// still be treated as corruption, or half a game comes back looking whole.
    func test_a_save_missing_a_required_field_is_still_corruption() throws {
        var full = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(BurrowSave.fresh(now: t0))) as! [String: Any]
        full.removeValue(forKey: "belly")
        let dir = tempDir()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = BurrowStore(directory: dir)
        try JSONSerialization.data(withJSONObject: full).write(to: store.fileURL)

        _ = store.load(now: t0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.corruptURL.path),
                      "kept, not deleted")
    }

    private func tempDir() -> URL {
        let d = FileManager.default.temporaryDirectory.appendingPathComponent("burrow-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: d) }
        return d
    }

    func test_store_missing_file_gives_fresh() {
        let store = BurrowStore(directory: tempDir())
        XCTAssertEqual(store.load(now: t0), .fresh(now: t0))
    }

    func test_store_round_trip() throws {
        let store = BurrowStore(directory: tempDir())
        var s = BurrowSave.fresh(now: t0)
        s.digs = 1
        try store.save(s)
        XCTAssertEqual(store.load(now: t0.addingTimeInterval(99)), s)
    }

    func test_store_corrupt_file_is_moved_aside() throws {
        let dir = tempDir()
        let store = BurrowStore(directory: dir)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: store.fileURL)
        XCTAssertEqual(store.load(now: t0), .fresh(now: t0))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.corruptURL.path))
    }

    func test_store_future_version_is_moved_aside() throws {
        let dir = tempDir()
        let store = BurrowStore(directory: dir)
        var s = BurrowSave.fresh(now: t0)
        s.version = BurrowSave.currentVersion + 1
        try store.save(s)
        XCTAssertEqual(store.load(now: t0), .fresh(now: t0))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.corruptURL.path))
    }

    /// A real v1 payload: BuriedFind had only spot + kind. Shared by the migration tests.
    static let v1JSON = """
    {"version":1,"stage":"larva","name":"PIP","eggCracks":3,"belly":6,"joy":6,"molt":2,
     "digs":3,"buried":[{"spot":0,"kind":"berry"},{"spot":3,"kind":"crystal"}],
     "holes":[1],"bag":{"root":2},"placed":{},"eaten":{},"specimens":[],
     "lastTick":750000000,"digTimer":0,"buryTimer":0,"bellyTimer":0,"joyTimer":0,
     "lastPetAt":749990000}
    """

    /// A store in a fresh temp dir, pre-loaded with `json`.
    func storeHolding(_ json: String) throws -> BurrowStore {
        let store = BurrowStore(directory: tempDir())
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        try Data(json.utf8).write(to: store.fileURL)
        return store
    }

    func test_a_version_1_save_still_loads() throws {
        let store = try storeHolding(Self.v1JSON)

        let save = store.load()

        XCTAssertEqual(save.name, "PIP", "the grub survived the upgrade")
        XCTAssertEqual(save.buried.map(\.kind), [.berry, .crystal], "kinds are preserved as-is")
        XCTAssertEqual(save.holes, [1])
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.corruptURL.path),
                       "a v1 save must never be treated as corrupt")
    }

    func test_a_v1_save_gains_grids_and_is_brought_to_the_current_version() throws {
        let save = try storeHolding(Self.v1JSON).load()
        XCTAssertEqual(save.version, BurrowSave.currentVersion)
        XCTAssertEqual(save.buried.count, 2)
        for f in save.buried {
            XCTAssertEqual(f.tiles.count, DigGrid.tileCount, "spot \(f.spot) got a grid")
            XCTAssertNotEqual(f.tiles[f.findTile], .root, "spot \(f.spot)")
        }
    }

    func test_the_migrated_save_is_written_back_so_it_only_happens_once() throws {
        let store = try storeHolding(Self.v1JSON)
        _ = store.load()
        let onDisk = try JSONDecoder().decode(BurrowSave.self, from: Data(contentsOf: store.fileURL))
        XCTAssertEqual(onDisk.version, BurrowSave.currentVersion,
                       "the upgrade was saved, not redone every launch")
        XCTAssertEqual(onDisk.buried.first?.tiles.count, DigGrid.tileCount)
    }

    func test_migrating_the_same_save_twice_gives_the_same_grids() throws {
        let first = try storeHolding(Self.v1JSON).load()
        let second = try storeHolding(Self.v1JSON).load()
        XCTAssertEqual(first.buried.map(\.tiles), second.buried.map(\.tiles),
                       "the spot-derived seed must make migration repeatable")
        XCTAssertEqual(first.buried.map(\.findTile), second.buried.map(\.findTile))
    }

    func test_a_part_written_v2_save_is_repaired() throws {
        // version 2, but a buried find with no grid — a hand-edit, or a crash mid-write.
        let broken = Self.v1JSON.replacingOccurrences(of: "\"version\":1", with: "\"version\":2")
        let save = try storeHolding(broken).load()
        XCTAssertEqual(save.buried.first?.tiles.count, DigGrid.tileCount,
                       "a missing grid is repaired regardless of version")
    }
}
