import XCTest
@testable import GrubIOS

@MainActor   // GameState is @MainActor
final class GameStateHooksTests: XCTestCase {
    func test_useCraftedItem_logs_home_action() {
        let spy = NullAnalytics()
        let defaults = UserDefaults(suiteName: "hooks_\(UUID().uuidString)")!
        let game = GameState(defaults: defaults, startGameLoop: false, analytics: spy)
        // Seed a real crafted item so useCraftedItem takes the real path.
        game.craftedItems["moss_gruel"] = 1
        game.useCraftedItem("moss_gruel")
        XCTAssertTrue(spy.logged.contains("home_action"),
                      "expected 'home_action' to be logged on feed; got \(spy.logged)")
    }

    func test_craft_logs_home_action_when_ingredients_present() {
        let spy = NullAnalytics()
        let defaults = UserDefaults(suiteName: "hooks_\(UUID().uuidString)")!
        let game = GameState(defaults: defaults, startGameLoop: false, analytics: spy)
        // moss_gruel needs 2x moss_clump; seed and ensure unlocked
        game.ingredients["moss_clump"] = 2
        game.unlockedRecipes.insert("moss_gruel")
        game.craft("moss_gruel")
        XCTAssertTrue(spy.logged.contains("home_action"),
                      "expected 'home_action' on craft; got \(spy.logged)")
    }
}
