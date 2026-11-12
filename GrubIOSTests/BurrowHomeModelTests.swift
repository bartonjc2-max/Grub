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


    // MARK: the dig trip

    /// A larva model whose spot-0 grid is known: find at 12, rock at 10, root at 0.
    /// Rigged rather than generated — spot 0 is clay, so its real grid has rocks wherever
    /// the seed put them, and a test that assumes tile 11 is plain soil would be a coin flip.
    func larvaModel() throws -> (BurrowHomeModel, BurrowStore) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("burrow-dig-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let store = BurrowStore(directory: dir)
        var s = BurrowSave.fresh(now: t0)
        s.stage = .larva; s.name = "GRUB"
        var tiles = [DigTile](repeating: .soil, count: 25)
        tiles[0] = .root
        tiles[10] = .rock(hp: 2)
        s.buried = [BuriedFind(spot: 0, kind: .berry, condition: nil, findTile: 12, tiles: tiles)]
        try store.save(s)
        let t0 = self.t0
        return (BurrowHomeModel(store: store, clock: { t0 }), store)
    }

    func test_starting_a_trip_opens_the_grid_with_strikes() throws {
        let (m, _) = try larvaModel()
        m.startTrip(spot: 0); m.advanceTo(.digging)
        XCTAssertEqual(m.trip?.spot, 0)
        XCTAssertEqual(m.trip?.strikesLeft, 6, "clay")
        XCTAssertEqual(m.digsLeft, 2)
    }

    func test_a_strike_is_written_to_disk_before_the_trip_ends() throws {
        let (m, store) = try larvaModel()
        m.startTrip(spot: 0); m.advanceTo(.digging)
        m.strike(tile: 11)
        XCTAssertEqual(m.trip?.strikesLeft, 5)
        // The whole point of persisting per strike: a kill mid-trip keeps the progress.
        XCTAssertEqual(store.load(now: t0).buried.first?.tiles[11], .broken)
    }

    func test_a_refused_strike_costs_nothing() throws {
        let (m, _) = try larvaModel()
        m.startTrip(spot: 0); m.advanceTo(.digging)
        m.strike(tile: 11)          // soil, breaks
        m.strike(tile: 11)          // already broken → refused
        m.strike(tile: 0)           // root → refused
        XCTAssertEqual(m.trip?.strikesLeft, 5, "only the first strike counted")
    }

    func test_running_out_ends_the_trip_and_keeps_progress() throws {
        let (m, _) = try larvaModel()
        m.startTrip(spot: 0); m.advanceTo(.digging)
        for t in [1, 2, 3, 4, 5, 6] { m.strike(tile: t) }   // 6 soil tiles, none is the find
        XCTAssertEqual(m.trip?.phase, .zoomingOut, "it walks home rather than vanishing")
        XCTAssertEqual(m.save.buried.first?.tiles.filter { $0 == .broken }.count, 6,
                       "the holes stay dug")
    }

    func test_leaving_keeps_progress_too() throws {
        let (m, _) = try larvaModel()
        m.startTrip(spot: 0); m.advanceTo(.digging)
        m.strike(tile: 11)
        m.leaveTrip()
        XCTAssertNil(m.trip)
        XCTAssertEqual(m.save.buried.first?.tiles[11], .broken)
    }

    func test_cannot_start_a_trip_while_one_is_running() throws {
        let (m, _) = try larvaModel()
        m.startTrip(spot: 0)
        XCTAssertFalse(m.canStartTrip)
    }

    func test_cannot_start_a_trip_while_a_panel_is_open() throws {
        let (m, _) = try larvaModel()
        m.showBag = true
        XCTAssertFalse(m.canStartTrip)
        m.showBag = false
        XCTAssertTrue(m.canStartTrip)
    }

    func test_finding_the_item_ends_the_trip() throws {
        let (m, _) = try larvaModel()
        m.startTrip(spot: 0); m.advanceTo(.digging)
        m.strike(tile: 12)
        XCTAssertEqual(m.trip?.phase, .zoomingOut)
        XCTAssertEqual(m.bag[.berry], 2)
        XCTAssertTrue(m.save.buried.isEmpty)
    }


    // MARK: trip phases

    /// A fresh egg over the same rigged spot-0 grid, to check the egg skips the crawl.
    func eggModelWithRiggedSpot() throws -> BurrowHomeModel {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("burrow-egg-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let store = BurrowStore(directory: dir)
        var s = BurrowSave.fresh(now: t0)
        var tiles = [DigTile](repeating: .soil, count: 25)
        tiles[0] = .root
        s.buried = [BuriedFind(spot: 0, kind: .berry, condition: nil, findTile: 12, tiles: tiles)]
        try store.save(s)
        let t0 = self.t0
        return BurrowHomeModel(store: store, clock: { t0 })
    }

    func test_a_larva_crawls_out_first() throws {
        let (m, _) = try larvaModel()
        m.startTrip(spot: 0)
        XCTAssertEqual(m.trip?.phase, .crawlingOut)
    }

    func test_an_egg_skips_the_crawl() throws {
        let m = try eggModelWithRiggedSpot()
        m.startTrip(spot: 0)
        XCTAssertEqual(m.trip?.phase, .zoomingIn, "an egg can't travel")
    }

    /// The cut-scene's beats, in order. `burrowingIn` is the hinge — the grub digs into the
    /// mound and goes under, and the grid blooms out of that same hole. It is short on screen
    /// (0.75 s), which makes it easy to break without anyone noticing, so the order is pinned
    /// here rather than left to a screenshot that has to be caught at the right instant.
    func test_phases_run_in_order_and_skip_jumps_one_at_a_time() throws {
        let (m, _) = try larvaModel()
        m.startTrip(spot: 0)
        m.skip(); XCTAssertEqual(m.trip?.phase, .burrowingIn, "it digs in before the grid")
        m.skip(); XCTAssertEqual(m.trip?.phase, .zoomingIn)
        m.skip(); XCTAssertEqual(m.trip?.phase, .digging)
        m.skip(); XCTAssertEqual(m.trip?.phase, .digging, "skip does nothing while digging")
    }

    func test_finding_the_item_returns_home_rather_than_vanishing() throws {
        let (m, _) = try larvaModel()
        m.startTrip(spot: 0); m.advanceTo(.digging)
        m.strike(tile: 12)                      // the find
        XCTAssertEqual(m.trip?.phase, .zoomingOut, "the trip plays out backwards")
        m.skip(); XCTAssertEqual(m.trip?.phase, .surfacing, "it climbs back out of the hole")
        m.skip(); XCTAssertEqual(m.trip?.phase, .crawlingHome)
        m.skip(); XCTAssertNil(m.trip, "home again")
    }

    /// An egg never travelled, so it has nothing to surface from. Before the cut-scene it was
    /// sent down the walk-home path anyway, which drew a larva sprite crawling for an egg.
    func test_an_egg_ends_the_trip_at_the_zoom_out() throws {
        let m = try eggModelWithRiggedSpot()
        m.startTrip(spot: 0); m.advanceTo(.zoomingOut)
        m.skip()
        XCTAssertNil(m.trip, "an egg has no journey to play backwards")
    }

    /// Regression: the trip view looked the find up in `save.buried`, which a successful dig
    /// empties — so the overlay vanished, nothing advanced the phases, and the grub was left
    /// hidden outside its chamber for good.
    func test_the_grid_survives_the_find_being_dug_up() throws {
        let (m, _) = try larvaModel()
        m.startTrip(spot: 0); m.advanceTo(.digging)
        m.strike(tile: 12)
        XCTAssertTrue(m.save.buried.isEmpty, "the find left the save")
        XCTAssertNotNil(m.tripFind, "but the trip can still draw its grid")
        XCTAssertEqual(m.tripFind?.tiles[12], .broken)
        m.skip(); m.skip(); m.skip()        // surfacing → crawling home → home
        XCTAssertNil(m.trip)
        XCTAssertNil(m.tripFind, "and it is cleared when the trip ends")
    }

    func test_no_striking_before_the_grid_is_up() throws {
        let (m, _) = try larvaModel()
        m.startTrip(spot: 0)                    // still crawling out
        m.strike(tile: 11)
        XCTAssertEqual(m.save.buried.first?.tiles[11], .soil, "the shovel waits for the grid")
    }
}
