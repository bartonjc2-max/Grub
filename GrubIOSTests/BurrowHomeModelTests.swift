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
}
