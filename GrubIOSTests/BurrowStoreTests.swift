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

    func test_a_version_1_save_still_loads() throws {
        let store = BurrowStore(directory: tempDir())
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        try Data(Self.v1JSON.utf8).write(to: store.fileURL)

        let save = store.load()

        XCTAssertEqual(save.name, "PIP", "the grub survived the upgrade")
        XCTAssertEqual(save.buried.map(\.kind), [.berry, .crystal], "kinds are preserved as-is")
        XCTAssertEqual(save.holes, [1])
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.corruptURL.path),
                       "a v1 save must never be treated as corrupt")
    }
}
