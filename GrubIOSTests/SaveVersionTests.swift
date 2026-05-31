import XCTest
@testable import GrubIOS

@MainActor   // GameState is @MainActor; see plan cross-cutting notes
final class SaveVersionTests: XCTestCase {
    func test_save_writes_save_version() {
        let suiteName = "test_save_version_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // startGameLoop:false avoids leaking timers in tests
        let game = GameState(defaults: defaults, startGameLoop: false)
        game.save()   // save() is unguarded — no hasLoaded hook needed

        let dict = defaults.dictionary(forKey: "grub_state")
        XCTAssertEqual(dict?["saveVersion"] as? Int, GameState.saveVersion)
    }

    func test_legacy_save_without_version_still_loads() {
        // Simulate a pre-versioning save with no saveVersion key
        let suiteName = "test_legacy_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(["name": "Legacy", "hunger": 42], forKey: "grub_state")

        let game = GameState(defaults: defaults, startGameLoop: false)
        // init() calls load(); it must not crash and must restore the stat
        XCTAssertEqual(game.hunger, 42)   // protects SC6
    }
}
