import XCTest
@testable import GrubIOS

@MainActor
final class BurrowHomeModelTests: XCTestCase {
    let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// A model over a temp-dir store holding a molt-ready larva.
    func moltReadyModel() throws -> BurrowHomeModel {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("burrow-model-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let store = BurrowStore(directory: dir)
        var s = BurrowSave.fresh(now: t0)
        s.stage = .larva; s.name = "GRUB"
        s.molt = BurrowRules.moltGoal
        try store.save(s)
        let t0 = self.t0
        return BurrowHomeModel(store: store, clock: { t0 })
    }

    func test_tap_when_molt_ready_asks_first() throws {
        let m = try moltReadyModel()
        m.tapGrub()
        XCTAssertTrue(m.confirmingMolt)
        XCTAssertEqual(m.stage, .larva, "a tap alone never molts")
    }

    func test_not_yet_keeps_the_larva() throws {
        let m = try moltReadyModel()
        m.tapGrub(); m.cancelMolt()
        XCTAssertFalse(m.confirmingMolt)
        XCTAssertEqual(m.stage, .larva)
        XCTAssertTrue(m.isMoltReady)
    }

    func test_confirm_molts() throws {
        let m = try moltReadyModel()
        m.tapGrub(); m.confirmMolt()
        XCTAssertFalse(m.confirmingMolt)
        XCTAssertEqual(m.stage, .adult)
        XCTAssertNotNil(m.adult)
    }

    func eggModel() throws -> BurrowHomeModel {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("burrow-egg-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let store = BurrowStore(directory: dir)
        try store.save(BurrowSave.fresh(now: t0))
        let t0 = self.t0
        return BurrowHomeModel(store: store, clock: { t0 })
    }

    func test_first_tap_on_an_unnamed_egg_asks_for_a_name() throws {
        let m = try eggModel()
        XCTAssertEqual(m.stage, .egg)
        m.tapGrub()
        XCTAssertTrue(m.namingEgg)
        XCTAssertEqual(m.eggCracks, 0)
    }

    func test_bad_name_keeps_the_prompt_good_name_closes_it() throws {
        let m = try eggModel()
        m.tapGrub()
        XCTAssertFalse(m.nameEgg("R2D2"))
        XCTAssertTrue(m.namingEgg)
        XCTAssertTrue(m.nameEgg("pip"))
        XCTAssertFalse(m.namingEgg)
        XCTAssertEqual(m.name, "PIP")
    }

    func test_three_taps_hatch_the_named_egg() throws {
        let m = try eggModel()
        m.tapGrub(); _ = m.nameEgg("PIP")
        m.tapGrub(); m.tapGrub()
        XCTAssertEqual(m.eggCracks, 2)
        m.tapGrub()
        XCTAssertEqual(m.stage, .larva)
        XCTAssertFalse(m.showBox)
    }
}
