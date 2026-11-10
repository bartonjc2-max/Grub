import XCTest
@testable import GrubIOS

final class BurrowStoreTests: XCTestCase {
    let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func test_fresh_save_matches_phase1_spec() {
        let s = BurrowSave.fresh(now: t0)
        XCTAssertEqual(s.version, BurrowSave.currentVersion)
        XCTAssertEqual(s.stage, .larva)
        XCTAssertEqual(s.name, "GRUB")
        XCTAssertEqual([s.belly, s.joy, s.molt, s.digs], [6, 6, 0, 3])
        XCTAssertEqual(s.bag, [.berry: 1])
        XCTAssertEqual(s.buried, [BuriedFind(spot: 0, kind: .berry),
                                  BuriedFind(spot: 1, kind: .amber),
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
}
