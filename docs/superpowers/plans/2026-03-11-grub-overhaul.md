# Grub Overhaul Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform GrubIOS from a shallow Tamagotchi into a survival-crafting pet game with foraging, crafting, inventory, deeper minigames, and progression-gated unlocks.

**Architecture:** All game state lives in `GameState` (ObservableObject) with extensions for new subsystems. Static data (recipes, ingredients) lives in `RecipeData.swift`. New overlays get their own files. Persistence uses the existing `UserDefaults` dictionary pattern with migration support.

**Tech Stack:** Swift 5.9, SwiftUI, iOS 17+, Canvas for pixel rendering, UserDefaults for persistence, xcodegen for project generation.

**Spec:** `docs/superpowers/specs/2026-03-11-grub-overhaul-design.md`

---

## File Map

### New Files
| File | Responsibility |
|---|---|
| `GrubIOS/RecipeData.swift` | Static ingredient definitions, recipe definitions, loot tables, rarity enum |
| `GrubIOS/GameState+Foraging.swift` | Active forage logic, passive gathering, loot rolling, area selection |
| `GrubIOS/GameState+Crafting.swift` | Recipe unlock checks, craft action, ingredient management |
| `GrubIOS/GameState+Minigames.swift` | All 5 minigame implementations (moved from GameState + 3 new games) |
| `GrubIOS/ForageOverlay.swift` | Forage area selector overlay UI |
| `GrubIOS/InventoryOverlay.swift` | Inventory screen: ingredients grid, food/meds list, crafting sub-screen |
| `GrubIOS/GameSelectorOverlay.swift` | Arcade game selector overlay UI |

### Modified Files
| File | Changes |
|---|---|
| `GrubIOS/GameState.swift` | Add new @Published properties (ingredients, craftedItems, unlockedRecipes, etc.), update save/load with migration, update restartGame(), remove old food/medicine/crumbs systems, add activeEffects, update applyDecay() for status effects |
| `GrubIOS/ContentView.swift` | Rework StatBarsView (segmented, icons, 22px), rework ActionButtonsView (4 buttons), rework TopBarView (items count replaces crumbs), add new overlay toggles |
| `GrubIOS/GameOverlays.swift` | Rework FeedOverlay (shows crafted food), rework MinigameOverlay (use game selector), rework EventOverlay (ingredient rewards), update StatsMenuView |
| `GrubIOS/SpriteRenderer.swift` | Add 12 ingredient PixelIcons, add UI icons (heart, leaf, bag, drumstick, stomach, skull, lightning), add orange to GrubPalette |

---

## Chunk 1: Data Foundation

### Task 1: Static Data Definitions

**Files:**
- Create: `GrubIOS/RecipeData.swift`

- [ ] **Step 1: Create RecipeData.swift with all type definitions**

```swift
// GrubIOS/RecipeData.swift
import Foundation

// MARK: - Rarity
enum Rarity: String, Codable, CaseIterable {
    case common, uncommon, rare
}

// MARK: - Ingredient Definition (static catalog)
struct IngredientDef {
    let id: String
    let name: String
    let rarity: Rarity
    let iconName: String  // maps to PixelIcon method
}

// MARK: - Recipe Types
struct RecipeIngredient: Codable, Equatable {
    let id: String
    let quantity: Int
}

struct StatEffects: Codable, Equatable {
    let hunger: Int
    let happiness: Int
    let health: Int

    static let zero = StatEffects(hunger: 0, happiness: 0, health: 0)
}

enum UnlockType: Codable, Equatable {
    case starter
    case level(Int)
    case scroll
}

struct RecipeDef {
    let id: String
    let name: String
    let ingredients: [RecipeIngredient]
    let effects: StatEffects
    let unlockType: UnlockType
    /// If true, applies the "energized" status effect on use
    let grantsEnergized: Bool
}

// MARK: - Status Effects
enum EffectType: String, Codable, CaseIterable {
    case overfed
    case poisoned
    case energized
}

struct ActiveEffect: Codable, Equatable {
    let type: EffectType
    let expiresAt: Date
}

// MARK: - Forage Area
enum ForageArea: String, CaseIterable {
    case shallowCave = "SHALLOW CAVE"
    case deepBurrow = "DEEP BURROW"
    case surface = "SURFACE"

    var description: String {
        switch self {
        case .shallowCave: return "SAFE - COMMON ITEMS"
        case .deepBurrow: return "RISKY - BETTER ITEMS"
        case .surface: return "MIXED - NIGHT SPECIALS"
        }
    }
}

// MARK: - Ingredient Catalog
let ingredientCatalog: [String: IngredientDef] = {
    let defs: [IngredientDef] = [
        // Common
        IngredientDef(id: "moss_clump", name: "MOSS CLUMP", rarity: .common, iconName: "mossClump"),
        IngredientDef(id: "cave_beetle", name: "CAVE BEETLE", rarity: .common, iconName: "caveBeetle"),
        IngredientDef(id: "mud_root", name: "MUD ROOT", rarity: .common, iconName: "mudRoot"),
        IngredientDef(id: "dew_drop", name: "DEW DROP", rarity: .common, iconName: "dewDrop"),
        // Uncommon
        IngredientDef(id: "glowshroom", name: "GLOWSHROOM", rarity: .uncommon, iconName: "glowshroom"),
        IngredientDef(id: "crystal_shard", name: "CRYSTAL SHARD", rarity: .uncommon, iconName: "crystalShard"),
        IngredientDef(id: "pale_worm", name: "PALE WORM", rarity: .uncommon, iconName: "paleWorm"),
        IngredientDef(id: "slime_berry", name: "SLIME BERRY", rarity: .uncommon, iconName: "slimeBerry"),
        // Rare
        IngredientDef(id: "moon_petal", name: "MOON PETAL", rarity: .rare, iconName: "moonPetal"),
        IngredientDef(id: "ember_seed", name: "EMBER SEED", rarity: .rare, iconName: "emberSeed"),
        IngredientDef(id: "ancient_spore", name: "ANCIENT SPORE", rarity: .rare, iconName: "ancientSpore"),
        IngredientDef(id: "golden_bug", name: "GOLDEN BUG", rarity: .rare, iconName: "goldenBug"),
    ]
    return Dictionary(uniqueKeysWithValues: defs.map { ($0.id, $0) })
}()

// Convenience lists by rarity
let commonIngredients = ingredientCatalog.values.filter { $0.rarity == .common }.map(\.id)
let uncommonIngredients = ingredientCatalog.values.filter { $0.rarity == .uncommon }.map(\.id)
let rareIngredients = ingredientCatalog.values.filter { $0.rarity == .rare }.map(\.id)

// MARK: - Recipe Catalog
let recipeCatalog: [String: RecipeDef] = {
    let defs: [RecipeDef] = [
        // Starter
        RecipeDef(id: "moss_gruel", name: "MOSS GRUEL",
                  ingredients: [.init(id: "moss_clump", quantity: 2)],
                  effects: StatEffects(hunger: 15, happiness: 0, health: 0),
                  unlockType: .starter, grantsEnergized: false),
        RecipeDef(id: "bug_snack", name: "BUG SNACK",
                  ingredients: [.init(id: "cave_beetle", quantity: 2)],
                  effects: StatEffects(hunger: 10, happiness: 5, health: 0),
                  unlockType: .starter, grantsEnergized: false),
        RecipeDef(id: "mud_paste", name: "MUD PASTE",
                  ingredients: [.init(id: "mud_root", quantity: 1), .init(id: "dew_drop", quantity: 1)],
                  effects: StatEffects(hunger: 0, happiness: 0, health: 15),
                  unlockType: .starter, grantsEnergized: false),
        // Level-unlocked
        RecipeDef(id: "shroom_stew", name: "SHROOM STEW",
                  ingredients: [.init(id: "glowshroom", quantity: 1), .init(id: "moss_clump", quantity: 1), .init(id: "dew_drop", quantity: 1)],
                  effects: StatEffects(hunger: 30, happiness: 10, health: 0),
                  unlockType: .level(2), grantsEnergized: false),
        RecipeDef(id: "crystal_tonic", name: "CRYSTAL TONIC",
                  ingredients: [.init(id: "crystal_shard", quantity: 1), .init(id: "dew_drop", quantity: 1)],
                  effects: StatEffects(hunger: 0, happiness: 0, health: 30),
                  unlockType: .level(3), grantsEnergized: false),
        RecipeDef(id: "worm_jerky", name: "WORM JERKY",
                  ingredients: [.init(id: "pale_worm", quantity: 2)],
                  effects: StatEffects(hunger: 20, happiness: 15, health: 0),
                  unlockType: .level(4), grantsEnergized: false),
        RecipeDef(id: "berry_jam", name: "BERRY JAM",
                  ingredients: [.init(id: "slime_berry", quantity: 2), .init(id: "moss_clump", quantity: 1)],
                  effects: StatEffects(hunger: 25, happiness: 20, health: 0),
                  unlockType: .level(5), grantsEnergized: false),
        RecipeDef(id: "moon_brew", name: "MOON BREW",
                  ingredients: [.init(id: "moon_petal", quantity: 1), .init(id: "dew_drop", quantity: 1), .init(id: "crystal_shard", quantity: 1)],
                  effects: StatEffects(hunger: 0, happiness: 10, health: 40),
                  unlockType: .level(6), grantsEnergized: true),
        RecipeDef(id: "ember_cake", name: "EMBER CAKE",
                  ingredients: [.init(id: "ember_seed", quantity: 1), .init(id: "slime_berry", quantity: 1), .init(id: "mud_root", quantity: 1)],
                  effects: StatEffects(hunger: 40, happiness: 25, health: 0),
                  unlockType: .level(7), grantsEnergized: false),
        // Scroll-unlocked
        RecipeDef(id: "spore_elixir", name: "SPORE ELIXIR",
                  ingredients: [.init(id: "ancient_spore", quantity: 1), .init(id: "glowshroom", quantity: 1), .init(id: "crystal_shard", quantity: 1)],
                  effects: StatEffects(hunger: 0, happiness: 0, health: 100),
                  unlockType: .scroll, grantsEnergized: true),
        RecipeDef(id: "golden_feast", name: "GOLDEN FEAST",
                  ingredients: [.init(id: "golden_bug", quantity: 1), .init(id: "moon_petal", quantity: 1), .init(id: "ember_seed", quantity: 1)],
                  effects: StatEffects(hunger: 30, happiness: 30, health: 30),
                  unlockType: .scroll, grantsEnergized: false),
        RecipeDef(id: "beetle_brew", name: "BEETLE BREW",
                  ingredients: [.init(id: "cave_beetle", quantity: 2), .init(id: "glowshroom", quantity: 1)],
                  effects: StatEffects(hunger: 0, happiness: 35, health: 0),
                  unlockType: .scroll, grantsEnergized: false),
        RecipeDef(id: "root_steak", name: "ROOT STEAK",
                  ingredients: [.init(id: "mud_root", quantity: 2), .init(id: "pale_worm", quantity: 1)],
                  effects: StatEffects(hunger: 35, happiness: 0, health: 10),
                  unlockType: .scroll, grantsEnergized: false),
        RecipeDef(id: "dew_elixir", name: "DEW ELIXIR",
                  ingredients: [.init(id: "dew_drop", quantity: 3), .init(id: "crystal_shard", quantity: 1)],
                  effects: StatEffects(hunger: 0, happiness: 15, health: 25),
                  unlockType: .scroll, grantsEnergized: false),
    ]
    return Dictionary(uniqueKeysWithValues: defs.map { ($0.id, $0) })
}()

let starterRecipeIds: Set<String> = ["moss_gruel", "bug_snack", "mud_paste"]

// Scroll-type recipe IDs (for event unlocks)
let scrollRecipeIds: [String] = recipeCatalog.values
    .filter { $0.unlockType == .scroll }
    .map(\.id)

// MARK: - Loot Tables
struct LootTable {
    let commonWeight: Double
    let uncommonWeight: Double
    let rareWeight: Double
    let riskChance: Double       // 0.0 - 1.0
    let riskStatType: String     // "happiness" or "health"
    let riskAmount: Int          // negative
    let riskMessage: String
    let itemCount: ClosedRange<Int>  // how many items per forage
    let specialPool: [String]?   // extra ingredients available only here
    let excludePool: [String]?   // ingredients NOT available here

    func rollRarity() -> Rarity {
        let roll = Double.random(in: 0...1)
        if roll < commonWeight { return .common }
        if roll < commonWeight + uncommonWeight { return .uncommon }
        return .rare
    }
}

let lootTables: [ForageArea: LootTable] = [
    .shallowCave: LootTable(
        commonWeight: 0.70, uncommonWeight: 0.25, rareWeight: 0.05,
        riskChance: 0, riskStatType: "", riskAmount: 0, riskMessage: "",
        itemCount: 2...4,
        specialPool: nil, excludePool: ["moon_petal", "ember_seed"]
    ),
    .deepBurrow: LootTable(
        commonWeight: 0.30, uncommonWeight: 0.50, rareWeight: 0.20,
        riskChance: 0.20, riskStatType: "happiness", riskAmount: -10,
        riskMessage: "GRUB GOT SPOOKED!",
        itemCount: 2...4,
        specialPool: ["ember_seed"], excludePool: ["moon_petal"]
    ),
    .surface: LootTable(
        commonWeight: 0.40, uncommonWeight: 0.20, rareWeight: 0.40,
        riskChance: 0.15, riskStatType: "health", riskAmount: -5,
        riskMessage: "GRUB GOT SCRATCHED!",
        itemCount: 2...4,
        specialPool: nil, excludePool: ["ember_seed"]
    ),
]
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -project GrubIOS.xcodeproj -scheme GrubIOS -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/GrubBuild build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add GrubIOS/RecipeData.swift
git commit -m "feat: add static data definitions for ingredients, recipes, loot tables"
```

---

### Task 2: GameState New Properties + Save/Load Migration

**Files:**
- Modify: `GrubIOS/GameState.swift`

- [ ] **Step 1: Add new @Published properties to GameState**

Add after the existing `legacyTrait` property (around line 113):

```swift
    // Foraging & Crafting
    @Published var ingredients: [String: Int] = [:]
    @Published var craftedItems: [String: Int] = [:]
    @Published var unlockedRecipes: Set<String> = starterRecipeIds
    @Published var lastForageTime: Date? = nil
    @Published var passiveGatherTime: Date = Date()
    @Published var activeEffects: [ActiveEffect] = []

    // Minigame progression
    @Published var highScores: [String: Int] = [:]
    @Published var winStreak: Int = 0

    // Lifetime stats
    @Published var forageCount: Int = 0
    @Published var recipesFound: Int = 0
    @Published var itemsCrafted: Int = 0

    // New UI state
    @Published var showForageOverlay: Bool = false
    @Published var showInventoryOverlay: Bool = false
    @Published var showGameSelector: Bool = false
    @Published var showForageResults: Bool = false
    @Published var forageResults: [String] = []  // ingredient IDs found
    @Published var passiveResults: [String] = []  // passive items to collect
```

- [ ] **Step 2: Remove old crumbs/food/medicine properties and systems**

Remove from GameState:
- `@Published var crumbs: Int = 0` (line 104)
- `@Published var medicineCooldown: Date = Date.distantPast` (line 110)
- The `feed(index:)` method (lines 381-399)
- The `giveMedicine(free:)` method (lines 402-413)
- The `medicineCooldownRemaining` and `isMedicineOnCooldown` computed properties (lines 415-421)
- The `addCrumbs(_:)` method (lines 337-342)

Remove from top of file:
- The `FoodItem` struct and `foodItems` array (lines 27-39)

Update `addXP` to remove the crumbs sound (keep XP logic only).

- [ ] **Step 3: Update save() to include new properties**

Replace the `save()` method body with:

```swift
    func save() {
        var data: [String: Any] = [
            "name": name,
            "hunger": hunger,
            "happiness": happiness,
            "health": health,
            "lastSeen": lastSeen.timeIntervalSince1970,
            "ageDays": ageDays,
            "birthTime": birthTime.timeIntervalSince1970,
            "isAlive": isAlive,
            "evoStage": evoStage,
            "evoBranch": evoBranch,
            "ownerXP": ownerXP,
            "ownerLevel": ownerLevel,
            "fedCount": fedCount,
            "playedCount": playedCount,
            "neglectCount": neglectCount,
            "totalDeaths": totalDeaths,
            "lastEvent": lastEvent.timeIntervalSince1970,
            "legacyTrait": legacyTrait,
            // New properties
            "ingredients": ingredients,
            "craftedItems": craftedItems,
            "unlockedRecipes": Array(unlockedRecipes),
            "highScores": highScores,
            "winStreak": winStreak,
            "forageCount": forageCount,
            "recipesFound": recipesFound,
            "itemsCrafted": itemsCrafted,
            "passiveGatherTime": passiveGatherTime.timeIntervalSince1970,
        ]
        if let lft = lastForageTime {
            data["lastForageTime"] = lft.timeIntervalSince1970
        }
        // Active effects
        let effectsData = activeEffects.map { e -> [String: Any] in
            ["type": e.type.rawValue, "expiresAt": e.expiresAt.timeIntervalSince1970]
        }
        data["activeEffects"] = effectsData
        UserDefaults.standard.set(data, forKey: "grub_state")
    }
```

- [ ] **Step 4: Update load() with migration support**

Replace the `load()` method body with:

```swift
    func load() {
        guard let data = UserDefaults.standard.dictionary(forKey: "grub_state") else { return }
        name = data["name"] as? String ?? ""
        hunger = data["hunger"] as? Int ?? 100
        happiness = data["happiness"] as? Int ?? 100
        health = data["health"] as? Int ?? 100
        lastSeen = Date(timeIntervalSince1970: data["lastSeen"] as? Double ?? Date().timeIntervalSince1970)
        ageDays = data["ageDays"] as? Int ?? 0
        birthTime = Date(timeIntervalSince1970: data["birthTime"] as? Double ?? Date().timeIntervalSince1970)
        isAlive = data["isAlive"] as? Bool ?? true
        evoStage = data["evoStage"] as? Int ?? 0
        evoBranch = data["evoBranch"] as? String ?? ""
        ownerXP = data["ownerXP"] as? Int ?? 0
        ownerLevel = data["ownerLevel"] as? Int ?? 1
        fedCount = data["fedCount"] as? Int ?? 0
        playedCount = data["playedCount"] as? Int ?? 0
        neglectCount = data["neglectCount"] as? Int ?? 0
        totalDeaths = data["totalDeaths"] as? Int ?? 0
        lastEvent = Date(timeIntervalSince1970: data["lastEvent"] as? Double ?? 0)
        legacyTrait = data["legacyTrait"] as? String ?? ""

        // New properties with migration defaults
        ingredients = data["ingredients"] as? [String: Int] ?? [:]
        craftedItems = data["craftedItems"] as? [String: Int] ?? [:]
        // Starter recipes seeded by default for migration
        if let savedRecipes = data["unlockedRecipes"] as? [String] {
            unlockedRecipes = Set(savedRecipes)
        } else {
            unlockedRecipes = starterRecipeIds
        }
        highScores = data["highScores"] as? [String: Int] ?? [:]
        winStreak = data["winStreak"] as? Int ?? 0
        forageCount = data["forageCount"] as? Int ?? 0
        recipesFound = data["recipesFound"] as? Int ?? 0
        itemsCrafted = data["itemsCrafted"] as? Int ?? 0
        passiveGatherTime = Date(timeIntervalSince1970: data["passiveGatherTime"] as? Double ?? Date().timeIntervalSince1970)

        if let lft = data["lastForageTime"] as? Double {
            lastForageTime = Date(timeIntervalSince1970: lft)
        }
        // Load active effects
        if let effectsArr = data["activeEffects"] as? [[String: Any]] {
            activeEffects = effectsArr.compactMap { dict in
                guard let typeStr = dict["type"] as? String,
                      let type = EffectType(rawValue: typeStr),
                      let exp = dict["expiresAt"] as? Double else { return nil }
                return ActiveEffect(type: type, expiresAt: Date(timeIntervalSince1970: exp))
            }
        }

        if !name.isEmpty { showNameEntry = false }
    }
```

- [ ] **Step 5: Update restartGame() for death/restart behavior**

Replace the `restartGame()` method:

```swift
    func restartGame() {
        audio.play(.tap)
        let savedLegacy = computeLegacyTrait()
        let savedDeaths = totalDeaths
        let savedXP = ownerXP
        let savedLevel = ownerLevel
        let savedRecipes = unlockedRecipes
        let savedHighScores = highScores
        let savedRecipesFound = recipesFound
        let savedItemsCrafted = itemsCrafted

        // Reset per-pet state
        name = ""
        hunger = 100
        happiness = 100
        health = 100
        lastSeen = Date()
        ageDays = 0
        birthTime = Date()
        isAlive = true
        evoStage = 0
        evoBranch = ""
        fedCount = 0
        playedCount = 0
        neglectCount = 0
        lastEvent = Date.distantPast

        // Reset foraging/crafting (per-pet)
        ingredients = [:]
        craftedItems = [:]
        lastForageTime = nil
        passiveGatherTime = Date()
        activeEffects = []
        winStreak = 0
        forageCount = 0
        forageResults = []
        passiveResults = []

        // Restore progression (persists across deaths)
        ownerXP = savedXP
        ownerLevel = savedLevel
        totalDeaths = savedDeaths
        legacyTrait = savedLegacy
        unlockedRecipes = savedRecipes
        highScores = savedHighScores
        recipesFound = savedRecipesFound
        itemsCrafted = savedItemsCrafted

        showDeathOverlay = false
        showNameEntry = true
        save()
    }
```

- [ ] **Step 6: Update computeLegacyTrait() (remove crumbs reference)**

```swift
    func computeLegacyTrait() -> String {
        if ageDays > 20 { return "LONG-LIVED: NEXT PET\nHEALTH DECAYS 20% SLOWER" }
        if itemsCrafted > 50 { return "MASTER CRAFTER: NEXT PET\nSTARTS WITH 3 MOSS CLUMPS" }
        if neglectCount == 0 { return "WELL-TENDED: NEXT PET\nSTARTS AT 80 HUNGER" }
        if evoStage >= 1 { return "EVOLVED STOCK: NEXT PET\nEVOLVES 1 DAY EARLY" }
        return "HARDENED: NEXT PET\nDECAYS 10% SLOWER"
    }
```

- [ ] **Step 7: Update applyDecay() to check active effects**

Add at the start of `applyDecay()`, after calculating `effectiveMin`:

```swift
        // Prune expired effects
        activeEffects.removeAll { $0.expiresAt < now }

        // Apply effect modifiers
        let isEnergized = activeEffects.contains { $0.type == .energized }
        let isPoisoned = activeEffects.contains { $0.type == .poisoned }
        let decayMult: Double = isEnergized ? 0.5 : 1.0

        let hDrop = effectiveMin * DecayConstants.hungerPerMin * decayMult
        let hpDrop = effectiveMin * DecayConstants.happinessPerMin * decayMult
```

And for health decay, apply poison multiplier:

```swift
        let healthDecayMult = isPoisoned ? 2.0 : decayMult
        let heDrop = critMin * DecayConstants.healthPerMin * healthDecayMult
```

(Replace the existing `hDrop`, `hpDrop`, and `heDrop` calculations with these.)

- [ ] **Step 8: Update events to reward ingredients**

Replace the `gameEvents` array with ingredient-based rewards:

```swift
let gameEvents: [GameEvent] = [
    GameEvent(
        text: "YOUR GRUB FOUND SOMETHING\nSHINY IN THE DIRT.",
        optionA: EventOption(label: "KEEP IT\n+1 CRYSTAL SHARD", action: { s in s.addIngredient("crystal_shard") }),
        optionB: EventOption(label: "TOSS IT BACK\n+10 HAPPINESS", action: { s in s.happiness = min(100, s.happiness + 10) })
    ),
    GameEvent(
        text: "A STRANGE CREATURE\nAPPEARED. GRUB IS NERVOUS.",
        optionA: EventOption(label: "COMFORT\n+1 PALE WORM", action: { s in s.addIngredient("pale_worm") }),
        optionB: EventOption(label: "PLAY GAME\nTO SCARE IT", action: { s in s.showMinigame = true })
    ),
    GameEvent(
        text: "YOUR GRUB ATE SOMETHING\nSUSPICIOUS.",
        optionA: EventOption(label: "SPIT IT OUT\n+1 GLOWSHROOM", action: { s in s.addIngredient("glowshroom") }),
        optionB: EventOption(label: "SWALLOW\n50/50 RISK", action: { s in
            if Double.random(in: 0...1) < 0.5 {
                s.addIngredient("ancient_spore")
                s.displayToast("+1 ANCIENT SPORE!")
            } else {
                s.health = max(5, s.health - 10)
                s.displayToast("OUCH! -10 HP")
            }
        })
    ),
    GameEvent(
        text: "GRUB IS IN A CREATIVE\nMOOD TODAY.",
        optionA: EventOption(label: "EXPLORE\n+2 UNCOMMON", action: { s in
            let items = uncommonIngredients.shuffled().prefix(2)
            for item in items { s.addIngredient(item) }
        }),
        optionB: EventOption(label: "REST\n+15 HAPPINESS", action: { s in s.happiness = min(100, s.happiness + 15) })
    ),
    GameEvent(
        text: "GRUB FOUND AN OLD\nSCROLL IN THE MUD.",
        optionA: EventOption(label: "STUDY IT\nNEW RECIPE?", action: { s in s.unlockRandomScrollRecipe() }),
        optionB: EventOption(label: "TRADE IT\n+1 RARE", action: { s in
            let rare = rareIngredients.filter { $0 != "golden_bug" }.randomElement() ?? "moon_petal"
            s.addIngredient(rare)
        })
    ),
    GameEvent(
        text: "RAIN DRIPS THROUGH\nTHE CAVE CEILING.",
        optionA: EventOption(label: "COLLECT DEW\n+3 DEW DROPS", action: { s in
            for _ in 0..<3 { s.addIngredient("dew_drop") }
        }),
        optionB: EventOption(label: "TAKE SHELTER\n+10 HAP +5 HP", action: { s in
            s.happiness = min(100, s.happiness + 10)
            s.health = min(100, s.health + 5)
        })
    ),
]
```

- [ ] **Step 9: Add helper methods used by events**

Add to GameState (these will be expanded in the foraging/crafting extensions):

```swift
    // MARK: - Ingredient Helpers
    func addIngredient(_ id: String, count: Int = 1) {
        let current = ingredients[id] ?? 0
        ingredients[id] = current + count
    }

    var totalIngredientStacks: Int {
        ingredients.filter { $0.value > 0 }.count
    }

    func unlockRandomScrollRecipe() {
        let locked = scrollRecipeIds.filter { !unlockedRecipes.contains($0) }
        if let recipe = locked.randomElement() {
            unlockedRecipes.insert(recipe)
            recipesFound += 1
            if let def = recipeCatalog[recipe] {
                displayToast("NEW RECIPE: \(def.name)!")
            }
            audio.play(.levelup)
        } else {
            displayToast("NO NEW RECIPES!")
        }
    }

    func checkLevelRecipeUnlocks() {
        for (id, recipe) in recipeCatalog {
            if case .level(let lvl) = recipe.unlockType, ownerLevel >= lvl {
                if !unlockedRecipes.contains(id) {
                    unlockedRecipes.insert(id)
                    recipesFound += 1
                    displayToast("NEW RECIPE: \(recipe.name)!")
                }
            }
        }
    }
```

Update `addXP` to call `checkLevelRecipeUnlocks()` after leveling:

```swift
    func addXP(_ amount: Int) {
        ownerXP += amount
        while ownerLevel < xpThresholds.count && ownerXP >= xpThresholds[ownerLevel] {
            ownerLevel += 1
            audio.play(.levelup)
            displayToast("LEVEL UP! LVL \(ownerLevel)")
            checkLevelRecipeUnlocks()
        }
    }
```

- [ ] **Step 10: Update resolveEvent to remove crumbs reward**

```swift
    func resolveEvent(choice: Int) {
        audio.play(.tap)
        guard let event = pendingEvent else { return }
        if choice == 0 {
            event.optionA.action(self)
        } else {
            event.optionB.action(self)
        }
        pendingEvent = nil
        showEventOverlay = false
        addXP(5)
        save()
    }
```

- [ ] **Step 11: Build to verify compilation**

Run: `xcodebuild -project GrubIOS.xcodeproj -scheme GrubIOS -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/GrubBuild build 2>&1 | tail -10`
Expected: Build errors from UI code referencing removed properties (crumbs, feed, medicine). These will be fixed in Chunk 2. If there are other errors, fix them now.

- [ ] **Step 12: Commit**

```bash
git add GrubIOS/GameState.swift
git commit -m "feat: add foraging/crafting state, save migration, ingredient-based events, remove crumbs"
```

---

## Chunk 2: Foraging & Crafting Logic

### Task 3: Foraging Extension

**Files:**
- Create: `GrubIOS/GameState+Foraging.swift`

- [ ] **Step 1: Create GameState+Foraging.swift**

```swift
import Foundation

extension GameState {
    static let forageCooldownSeconds: TimeInterval = 2700 // 45 minutes
    static let passiveGatherInterval: TimeInterval = 7200 // 2 hours
    static let maxPassiveItems: Int = 8
    static let maxIngredientStacks: Int = 20

    var canForage: Bool {
        guard let last = lastForageTime else { return true }
        return Date().timeIntervalSince(last) >= Self.forageCooldownSeconds
    }

    var forageTimeRemaining: Int {
        guard let last = lastForageTime else { return 0 }
        let remaining = Self.forageCooldownSeconds - Date().timeIntervalSince(last)
        return max(0, Int(ceil(remaining / 60)))
    }

    // MARK: - Active Foraging
    func forage(area: ForageArea) {
        guard canForage else {
            displayToast("COOLDOWN: \(forageTimeRemaining)m")
            return
        }
        guard let table = lootTables[area] else { return }

        audio.play(.tap)
        var found: [String] = []
        let count = Int.random(in: table.itemCount)

        for _ in 0..<count {
            if totalIngredientStacks >= Self.maxIngredientStacks && found.isEmpty {
                displayToast("INVENTORY FULL!")
                return
            }
            let rarity = table.rollRarity()
            if let ingredient = rollIngredient(rarity: rarity, area: area, table: table) {
                found.append(ingredient)
                addIngredient(ingredient)
            }
        }

        // Night bonus: Moon Petal chance on Surface
        if area == .surface && isNight && Double.random(in: 0...1) < 0.3 {
            found.append("moon_petal")
            addIngredient("moon_petal")
        }

        // Risk check
        if table.riskChance > 0 && Double.random(in: 0...1) < table.riskChance {
            if table.riskStatType == "happiness" {
                happiness = max(0, happiness + table.riskAmount)
            } else if table.riskStatType == "health" {
                health = max(0, health + table.riskAmount)
                // Deep Burrow poison effect
                if area == .deepBurrow {
                    let poisonExpiry = Date().addingTimeInterval(300) // 5 minutes
                    activeEffects.append(ActiveEffect(type: .poisoned, expiresAt: poisonExpiry))
                }
            }
            displayToast(table.riskMessage)
        }

        lastForageTime = Date()
        forageCount += 1
        addXP(3)

        forageResults = found
        showForageResults = true
        showForageOverlay = false
        save()
    }

    private func rollIngredient(rarity: Rarity, area: ForageArea, table: LootTable) -> String? {
        var pool: [String]
        switch rarity {
        case .common: pool = commonIngredients
        case .uncommon: pool = uncommonIngredients
        case .rare: pool = rareIngredients.filter { $0 != "golden_bug" } // Golden Bug is minigame-only
        }

        // Apply area exclusions
        if let exclude = table.excludePool {
            pool = pool.filter { !exclude.contains($0) }
        }

        // Apply area specials (boost chance of special items)
        if let special = table.specialPool, rarity == .rare {
            pool = pool + special // double weight for specials
        }

        return pool.randomElement()
    }

    // MARK: - Passive Gathering
    func collectPassiveItems() {
        let now = Date()
        let elapsed = now.timeIntervalSince(passiveGatherTime)
        let intervals = min(Int(elapsed / Self.passiveGatherInterval), Self.maxPassiveItems / 2)

        guard intervals > 0 else { return }

        if totalIngredientStacks >= Self.maxIngredientStacks {
            displayToast("INVENTORY FULL!")
            passiveGatherTime = now
            save()
            return
        }

        var found: [String] = []
        for _ in 0..<intervals {
            let count = Int.random(in: 1...2)
            for _ in 0..<count {
                if found.count >= Self.maxPassiveItems { break }
                if let item = commonIngredients.randomElement() {
                    found.append(item)
                    addIngredient(item)
                }
            }
        }

        passiveGatherTime = now
        if !found.isEmpty {
            passiveResults = found
        }
        save()
    }
}
```

- [ ] **Step 2: Update onForeground() in GameState.swift to call collectPassiveItems()**

```swift
    func onForeground() {
        guard isAlive, !name.isEmpty else { return }
        applyDecay()
        collectPassiveItems()
        save()
        checkForEvent()
    }
```

- [ ] **Step 3: Build to verify**

Run: `xcodebuild ... build 2>&1 | tail -5`

- [ ] **Step 4: Commit**

```bash
git add GrubIOS/GameState+Foraging.swift GrubIOS/GameState.swift
git commit -m "feat: add active foraging and passive gathering systems"
```

---

### Task 4: Crafting Extension

**Files:**
- Create: `GrubIOS/GameState+Crafting.swift`

- [ ] **Step 1: Create GameState+Crafting.swift**

```swift
import Foundation

extension GameState {
    // MARK: - Crafting

    /// Check if the player has all ingredients for a recipe
    func canCraft(_ recipeId: String) -> Bool {
        guard let recipe = recipeCatalog[recipeId] else { return false }
        guard unlockedRecipes.contains(recipeId) else { return false }
        for req in recipe.ingredients {
            if (ingredients[req.id] ?? 0) < req.quantity { return false }
        }
        return true
    }

    /// Craft a recipe: consume ingredients, produce crafted item
    func craft(_ recipeId: String) {
        guard canCraft(recipeId), let recipe = recipeCatalog[recipeId] else {
            displayToast("CAN'T CRAFT!")
            return
        }

        // Consume ingredients
        for req in recipe.ingredients {
            ingredients[req.id] = (ingredients[req.id] ?? 0) - req.quantity
            if ingredients[req.id]! <= 0 { ingredients.removeValue(forKey: req.id) }
        }

        // Produce crafted item
        craftedItems[recipeId] = (craftedItems[recipeId] ?? 0) + 1
        itemsCrafted += 1
        addXP(1)
        audio.play(.feed)
        displayToast("CRAFTED \(recipe.name)!")
        save()
    }

    /// Use a crafted food/medicine item on Grub
    func useCraftedItem(_ recipeId: String) {
        guard let count = craftedItems[recipeId], count > 0,
              let recipe = recipeCatalog[recipeId] else {
            displayToast("NONE LEFT!")
            return
        }

        // Check overfed
        let newHunger = hunger + recipe.effects.hunger
        if newHunger > 95 && recipe.effects.hunger > 0 {
            happiness = max(0, happiness - 5)
            displayToast("OVERFED! -5 HAP")
        }

        // Apply effects
        if recipe.effects.health == 100 {
            // Full heal (Spore Elixir)
            health = 100
        } else {
            health = min(100, health + recipe.effects.health)
        }
        hunger = min(100, hunger + recipe.effects.hunger)
        happiness = min(100, happiness + recipe.effects.happiness)

        // Energized effect
        if recipe.grantsEnergized {
            let expiry = Date().addingTimeInterval(1800) // 30 minutes
            activeEffects.append(ActiveEffect(type: .energized, expiresAt: expiry))
        }

        // Consume item
        craftedItems[recipeId] = count - 1
        if craftedItems[recipeId]! <= 0 { craftedItems.removeValue(forKey: recipeId) }

        // Track feeding for evolution
        if recipe.effects.hunger > 0 { fedCount += 1 }

        audio.play(.feed)
        addXP(1)

        // Animation
        petStateAnim = recipe.effects.health > recipe.effects.hunger ? "idle" : "eating"
        animStateTimer?.invalidate()
        animStateTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            DispatchQueue.main.async { self?.petStateAnim = "idle" }
        }

        save()
    }

    /// Get sorted list of available recipes (unlocked, grouped by craftability)
    func sortedRecipes() -> [(id: String, def: RecipeDef, craftable: Bool)] {
        let unlocked = unlockedRecipes.compactMap { id -> (String, RecipeDef, Bool)? in
            guard let def = recipeCatalog[id] else { return nil }
            return (id, def, canCraft(id))
        }
        // Craftable first, then alphabetical
        return unlocked.sorted { a, b in
            if a.2 != b.2 { return a.2 }
            return a.1.name < b.1.name
        }
    }

    /// Get recipes the player hasn't unlocked yet (for display as locked)
    func lockedRecipes() -> [(id: String, def: RecipeDef)] {
        recipeCatalog.compactMap { id, def in
            if unlockedRecipes.contains(id) { return nil }
            if case .level(let lvl) = def.unlockType {
                return (id, def)
            }
            return nil
        }.sorted { a, b in
            if case .level(let la) = a.def.unlockType, case .level(let lb) = b.def.unlockType {
                return la < lb
            }
            return false
        }
    }
}
```

- [ ] **Step 2: Make animStateTimer accessible from extension**

In `GameState.swift`, change `animStateTimer` from `private` to `internal`:

```swift
    var animStateTimer: Timer?  // was: private var animStateTimer: Timer?
```

- [ ] **Step 3: Build to verify**

- [ ] **Step 4: Commit**

```bash
git add GrubIOS/GameState+Crafting.swift GrubIOS/GameState.swift
git commit -m "feat: add crafting system with recipe validation, item usage, effects"
```

---

## Chunk 3: Minigame Rework

### Task 5: Extract & Expand Minigames

**Files:**
- Create: `GrubIOS/GameState+Minigames.swift`
- Modify: `GrubIOS/GameState.swift` (remove old minigame code)

- [ ] **Step 1: Move minigame state properties**

In `GameState.swift`, keep the minigame @Published properties where they are but remove all minigame methods: `openPlay()`, `setupMGRound()`, `mgChoice()`, `mgFoodChoice()`, `mgRoundResult()`, `closeMinigame()` (lines 481-572).

- [ ] **Step 2: Create GameState+Minigames.swift with all 5 games**

```swift
import Foundation

// MARK: - Minigame Definitions
enum MinigameType: String, CaseIterable {
    case dodge = "dodge"
    case feedMe = "feed_me"
    case memory = "memory"
    case bugCatch = "bug_catch"
    case rhythm = "rhythm"

    var name: String {
        switch self {
        case .dodge: return "DODGE"
        case .feedMe: return "FEED ME"
        case .memory: return "MEMORY"
        case .bugCatch: return "BUG CATCH"
        case .rhythm: return "RHYTHM"
        }
    }

    var unlockLevel: Int {
        switch self {
        case .dodge, .feedMe: return 1
        case .memory: return 3
        case .bugCatch: return 5
        case .rhythm: return 7
        }
    }

    var totalRounds: Int {
        switch self {
        case .dodge, .feedMe: return 5
        case .memory, .bugCatch, .rhythm: return 1
        }
    }
}

extension GameState {
    // MARK: - Game Selector
    func isGameUnlocked(_ game: MinigameType) -> Bool {
        ownerLevel >= game.unlockLevel
    }

    func unlockedGames() -> [MinigameType] {
        MinigameType.allCases.filter { isGameUnlocked($0) }
    }

    // MARK: - Open Specific Game
    func openGame(_ game: MinigameType) {
        guard isGameUnlocked(game) else { return }
        audio.play(.tap)
        mgGame = game == .dodge ? 0 : game == .feedMe ? 1 : game == .memory ? 2 : game == .bugCatch ? 3 : 4
        mgRound = 1
        mgWins = 0
        mgResult = ""
        mgPrompt = "GET READY..."
        showGameSelector = false
        showMinigame = true
        setupMGRound()
    }

    func openPlay() {
        audio.play(.tap)
        showGameSelector = true
    }

    // MARK: - Setup Round
    func setupMGRound() {
        mgResult = ""
        mgTimer?.invalidate()

        switch mgGame {
        case 0: // Dodge
            mgWallSide = Bool.random() ? "left" : "right"
            mgWaiting = true
            mgPrompt = "WHICH SIDE IS SAFE?"
        case 1: // Feed Me
            let allFoods = ["meat", "veggie", "cake", "pizza", "carrot"]
            mgFoodItems = Array(allFoods.shuffled().prefix(3))
            mgTargetFood = Int.random(in: 0...2)
            mgPrompt = "FEED: \(mgFoodItems[mgTargetFood].uppercased())"
            mgWaiting = true
            // Timer shrinks per round: 3.0, 2.5, 2.0, 1.5, 1.0
            let timeout = max(1.0, 3.5 - Double(mgRound) * 0.5)
            mgTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
                DispatchQueue.main.async {
                    guard let self = self, self.mgWaiting else { return }
                    self.mgRoundResult(won: false)
                }
            }
        case 2: // Memory
            setupMemoryGame()
        case 3: // Bug Catch
            setupBugCatchGame()
        case 4: // Rhythm
            setupRhythmGame()
        default: break
        }
    }

    // MARK: - Dodge
    func mgChoice(side: String) {
        guard mgWaiting, mgGame == 0 else { return }
        mgWaiting = false
        mgTimer?.invalidate()
        let correct = side != mgWallSide
        mgRoundResult(won: correct)
    }

    // MARK: - Feed Me
    func mgFoodChoice(index: Int) {
        guard mgWaiting, mgGame == 1 else { return }
        mgWaiting = false
        mgTimer?.invalidate()
        let correct = index == mgTargetFood
        mgRoundResult(won: correct)
    }

    // MARK: - Memory Game State
    // Memory uses mgFoodItems as card grid (12 cards = 6 pairs)
    // mgTargetFood = total flips, mgWins = pairs found
    @Published var mgMemoryCards: [String] = []
    @Published var mgMemoryRevealed: [Bool] = []
    @Published var mgMemoryMatched: [Bool] = []
    @Published var mgFirstFlip: Int? = nil
    @Published var mgMemoryFlips: Int = 0

    func setupMemoryGame() {
        let symbols = ["A", "B", "C", "D", "E", "F"]
        mgMemoryCards = (symbols + symbols).shuffled()
        mgMemoryRevealed = Array(repeating: false, count: 12)
        mgMemoryMatched = Array(repeating: false, count: 12)
        mgFirstFlip = nil
        mgMemoryFlips = 0
        mgWins = 0
        mgWaiting = true
        mgPrompt = "MATCH THE PAIRS"
    }

    func memoryFlip(index: Int) {
        guard mgWaiting, mgGame == 2 else { return }
        guard !mgMemoryRevealed[index], !mgMemoryMatched[index] else { return }

        mgMemoryRevealed[index] = true
        mgMemoryFlips += 1

        if let first = mgFirstFlip {
            // Second flip
            mgWaiting = false // block input during check
            if mgMemoryCards[first] == mgMemoryCards[index] {
                // Match!
                mgMemoryMatched[first] = true
                mgMemoryMatched[index] = true
                mgWins += 1
                audio.play(.win)

                if mgWins >= 6 {
                    // All matched - game over
                    let score = max(1, 12 - (mgMemoryFlips - 6))
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.finishScoreGame(score: score, maxScore: 6, gameName: "memory")
                    }
                } else {
                    mgWaiting = true
                }
            } else {
                // No match - flip back after delay
                audio.play(.lose)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                    guard let self = self else { return }
                    self.mgMemoryRevealed[first] = false
                    self.mgMemoryRevealed[index] = false
                    self.mgWaiting = true
                }
            }
            mgFirstFlip = nil
        } else {
            mgFirstFlip = index
        }
    }

    // MARK: - Bug Catch
    @Published var mgBugs: [(x: Double, y: Double, dx: Double, dy: Double, caught: Bool)] = []
    @Published var mgBugScore: Int = 0
    @Published var mgBugTimeLeft: Double = 15

    func setupBugCatchGame() {
        mgBugs = (0..<8).map { _ in
            (x: Double.random(in: 0.1...0.9),
             y: Double.random(in: 0.1...0.9),
             dx: Double.random(in: -0.01...0.01),
             dy: Double.random(in: -0.01...0.01),
             caught: false)
        }
        mgBugScore = 0
        mgBugTimeLeft = 15
        mgWaiting = true
        mgPrompt = "CATCH THE BUGS!"

        mgTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            DispatchQueue.main.async {
                guard let self = self, self.mgGame == 3 else { timer.invalidate(); return }
                self.mgBugTimeLeft -= 0.1
                // Move bugs
                for i in 0..<self.mgBugs.count where !self.mgBugs[i].caught {
                    self.mgBugs[i].x += self.mgBugs[i].dx
                    self.mgBugs[i].y += self.mgBugs[i].dy
                    // Bounce
                    if self.mgBugs[i].x < 0 || self.mgBugs[i].x > 1 { self.mgBugs[i].dx *= -1 }
                    if self.mgBugs[i].y < 0 || self.mgBugs[i].y > 1 { self.mgBugs[i].dy *= -1 }
                    self.mgBugs[i].x = min(1, max(0, self.mgBugs[i].x))
                    self.mgBugs[i].y = min(1, max(0, self.mgBugs[i].y))
                }
                if self.mgBugTimeLeft <= 0 {
                    timer.invalidate()
                    self.finishScoreGame(score: self.mgBugScore, maxScore: 8, gameName: "bug_catch")
                }
            }
        }
    }

    func catchBug(at index: Int) {
        guard mgWaiting, mgGame == 3, index < mgBugs.count, !mgBugs[index].caught else { return }
        mgBugs[index].caught = true
        mgBugScore += 1
        audio.play(.win)
    }

    // MARK: - Rhythm (Simon Says)
    @Published var mgRhythmSequence: [Int] = []
    @Published var mgRhythmPlayerIndex: Int = 0
    @Published var mgRhythmShowingSequence: Bool = false
    @Published var mgRhythmHighlight: Int = -1

    func setupRhythmGame() {
        mgRhythmSequence = [Int.random(in: 0...3)]
        mgRhythmPlayerIndex = 0
        mgWins = 0  // tracks rounds survived
        mgWaiting = false
        mgPrompt = "WATCH THE PATTERN"
        showRhythmSequence()
    }

    func showRhythmSequence() {
        mgRhythmShowingSequence = true
        mgRhythmHighlight = -1
        var delay = 0.5
        for (i, btn) in mgRhythmSequence.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.mgRhythmHighlight = btn
                self?.audio.play(.tap)
            }
            delay += 0.5
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.mgRhythmHighlight = -1
            }
            delay += 0.2
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.mgRhythmShowingSequence = false
            self?.mgRhythmPlayerIndex = 0
            self?.mgWaiting = true
            self?.mgPrompt = "YOUR TURN"
        }
    }

    func rhythmTap(_ button: Int) {
        guard mgWaiting, mgGame == 4, !mgRhythmShowingSequence else { return }

        if button == mgRhythmSequence[mgRhythmPlayerIndex] {
            audio.play(.tap)
            mgRhythmPlayerIndex += 1
            if mgRhythmPlayerIndex >= mgRhythmSequence.count {
                // Completed this round
                mgWins += 1
                mgRhythmSequence.append(Int.random(in: 0...3))
                mgWaiting = false
                mgPrompt = "ROUND \(mgWins + 1)"
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.showRhythmSequence()
                }
            }
        } else {
            // Failed
            audio.play(.lose)
            finishScoreGame(score: mgWins, maxScore: 10, gameName: "rhythm")
        }
    }

    // MARK: - Round-Based Result (Dodge & Feed Me)
    func mgRoundResult(won: Bool) {
        if won {
            mgWins += 1
            audio.play(.win)
            mgResult = "CORRECT!"
        } else {
            audio.play(.lose)
            mgResult = "WRONG!"
        }

        let totalRounds = 5
        if mgRound >= totalRounds {
            let gameWon = mgWins >= 3
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.finishRoundGame(won: gameWon)
            }
        } else {
            mgRound += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
                self?.setupMGRound()
            }
        }
    }

    // MARK: - Finish Handlers
    private func finishRoundGame(won: Bool) {
        let gameId = mgGame == 0 ? "dodge" : "feed_me"
        let score = mgWins

        // Update high score
        if score > (highScores[gameId] ?? 0) {
            highScores[gameId] = score
        }

        happiness = min(100, happiness + (won ? 15 : 5))
        playedCount += 1
        addXP(3)

        // Ingredient rewards
        if won {
            let reward = uncommonIngredients.randomElement() ?? "glowshroom"
            addIngredient(reward)
            let count = Int.random(in: 1...2)
            if count > 1, let extra = uncommonIngredients.randomElement() {
                addIngredient(extra)
            }
        }

        // Win streak
        if won {
            winStreak += 1
            if winStreak >= 3 {
                addIngredient("golden_bug")
                displayToast("3-WIN STREAK! +GOLDEN BUG!")
                winStreak = 0
            }
        } else {
            winStreak = 0
        }

        save()
        showMinigame = false
        if won { petStateAnim = "playing" }
        animStateTimer?.invalidate()
        animStateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async { self?.petStateAnim = "idle" }
        }
    }

    func finishScoreGame(score: Int, maxScore: Int, gameName: String) {
        // Update high score
        if score > (highScores[gameName] ?? 0) {
            highScores[gameName] = score
        }

        // Determine reward tier
        let ratio = Double(score) / Double(maxScore)
        let hapBonus: Int
        var ingredientReward: String?

        if ratio >= 0.75 {
            hapBonus = 20
            ingredientReward = rareIngredients.filter { $0 != "golden_bug" }.randomElement()
            mgResult = "GREAT! SCORE: \(score)"
        } else if ratio >= 0.4 {
            hapBonus = 15
            ingredientReward = uncommonIngredients.randomElement()
            mgResult = "GOOD! SCORE: \(score)"
        } else {
            hapBonus = 10
            ingredientReward = commonIngredients.randomElement()
            mgResult = "OK. SCORE: \(score)"
        }

        happiness = min(100, happiness + hapBonus)
        playedCount += 1
        addXP(3)

        if let reward = ingredientReward {
            addIngredient(reward)
        }

        // Win streak (score games count as win if ratio >= 0.4)
        if ratio >= 0.4 {
            winStreak += 1
            if winStreak >= 3 {
                addIngredient("golden_bug")
                displayToast("3-WIN STREAK! +GOLDEN BUG!")
                winStreak = 0
            }
        } else {
            winStreak = 0
        }

        save()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.showMinigame = false
            self?.petStateAnim = ratio >= 0.4 ? "playing" : "idle"
            self?.animStateTimer?.invalidate()
            self?.animStateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                DispatchQueue.main.async { self?.petStateAnim = "idle" }
            }
        }
    }

    func closeMinigame() {
        audio.play(.tap)
        mgTimer?.invalidate()
        showMinigame = false
    }
}
```

- [ ] **Step 3: Add @Published properties for new games to GameState.swift**

The Memory, Bug Catch, and Rhythm properties need to be on GameState directly since @Published doesn't work in extensions. Add to GameState.swift after the existing minigame properties:

```swift
    // Memory game
    @Published var mgMemoryCards: [String] = []
    @Published var mgMemoryRevealed: [Bool] = []
    @Published var mgMemoryMatched: [Bool] = []
    @Published var mgFirstFlip: Int? = nil
    @Published var mgMemoryFlips: Int = 0

    // Bug Catch game
    @Published var mgBugs: [(x: Double, y: Double, dx: Double, dy: Double, caught: Bool)] = []
    @Published var mgBugScore: Int = 0
    @Published var mgBugTimeLeft: Double = 15

    // Rhythm game
    @Published var mgRhythmSequence: [Int] = []
    @Published var mgRhythmPlayerIndex: Int = 0
    @Published var mgRhythmShowingSequence: Bool = false
    @Published var mgRhythmHighlight: Int = -1
```

**Note:** Remove the `@Published` annotations from the extension file — they are declared in GameState.swift. The extension file should just have the methods.

Also make `mgTimer` internal (not private) so the extension can access it:

```swift
    var mgTimer: Timer?  // was: private var mgTimer: Timer?
```

- [ ] **Step 4: Fix tuple not being Codable for mgBugs**

The `mgBugs` property uses tuples which aren't Codable, but this is UI-only state (not persisted), so it's fine. However, `@Published` with tuples may cause issues. Replace with a struct:

Add to `RecipeData.swift`:

```swift
struct BugState {
    var x: Double
    var y: Double
    var dx: Double
    var dy: Double
    var caught: Bool
}
```

Change the property type in GameState:

```swift
    @Published var mgBugs: [BugState] = []
```

Update references in the minigames extension accordingly.

- [ ] **Step 5: Build to verify**

- [ ] **Step 6: Commit**

```bash
git add GrubIOS/GameState+Minigames.swift GrubIOS/GameState.swift GrubIOS/RecipeData.swift
git commit -m "feat: extract minigames to extension, add Memory, Bug Catch, Rhythm games"
```

---

## Chunk 4: New Pixel Icons

### Task 6: Ingredient & UI Icons

**Files:**
- Modify: `GrubIOS/SpriteRenderer.swift`

- [ ] **Step 1: Add orange color to GrubPalette**

```swift
    static let orange = Color(hex: "#e07020")
```

And add to `paletteMap`:

```swift
        "E": Color(hex: "#e07020"),
```

- [ ] **Step 2: Add 12 ingredient icons to PixelIcon**

Add static methods for each ingredient. Each is a 9x9 pixel grid. Example pattern for a few — create all 12 following this style:

```swift
    static func mossClump(size: CGFloat = 16) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 9
            let grid: [String] = [
                "000000000",
                "000220000",
                "002222000",
                "022222200",
                "022922200",
                "022222200",
                "002222000",
                "000220000",
                "000000000",
            ]
            let colors: [Character: Color] = [
                "2": Color(hex: "#4ecca3"),
                "9": Color(hex: "#2a7a60"),
            ]
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if let color = colors[ch] {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    static func caveBeetle(size: CGFloat = 16) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 9
            let grid: [String] = [
                "000000000",
                "001000100",
                "010111010",
                "011111110",
                "011171110",
                "011111110",
                "010111010",
                "001000100",
                "000000000",
            ]
            let colors: [Character: Color] = [
                "1": Color(hex: "#1a1a2e"),
                "7": Color(hex: "#16213e"),
            ]
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if let color = colors[ch] {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    static func mudRoot(size: CGFloat = 16) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 9
            let grid: [String] = [
                "000010000",
                "000110000",
                "001551000",
                "000155100",
                "000155100",
                "001551000",
                "001550000",
                "000550000",
                "000000000",
            ]
            let colors: [Character: Color] = [
                "1": Color(hex: "#1a1a2e"),
                "5": Color(hex: "#c0b89a"),
            ]
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if let color = colors[ch] {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    static func dewDrop(size: CGFloat = 16) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 9
            let grid: [String] = [
                "000010000",
                "000110000",
                "001221000",
                "012222100",
                "012A22100",
                "012222100",
                "001221000",
                "000110000",
                "000000000",
            ]
            let colors: [Character: Color] = [
                "1": Color(hex: "#1a1a2e"),
                "2": Color(hex: "#4ecca3"),
                "A": Color(hex: "#ffffff"),
            ]
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if let color = colors[ch] {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    static func glowshroom(size: CGFloat = 16) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 9
            let grid: [String] = [
                "000666000",
                "006666600",
                "066A66600",
                "066666600",
                "006666600",
                "000111000",
                "000555000",
                "000555000",
                "000000000",
            ]
            let colors: [Character: Color] = [
                "6": Color(hex: "#7b2d8b"),
                "A": Color(hex: "#ffffff"),
                "1": Color(hex: "#1a1a2e"),
                "5": Color(hex: "#c0b89a"),
            ]
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if let color = colors[ch] {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    static func crystalShard(size: CGFloat = 16) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 9
            let grid: [String] = [
                "000010000",
                "000110000",
                "001221000",
                "001AA1000",
                "012AA2100",
                "012222100",
                "012222100",
                "001111000",
                "000000000",
            ]
            let colors: [Character: Color] = [
                "1": Color(hex: "#1a1a2e"),
                "2": Color(hex: "#4ecca3"),
                "A": Color(hex: "#ffffff"),
            ]
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if let color = colors[ch] {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    static func paleWorm(size: CGFloat = 16) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 9
            let grid: [String] = [
                "000000000",
                "033000000",
                "033300000",
                "003330000",
                "000333000",
                "000033300",
                "000003330",
                "000000330",
                "000000000",
            ]
            let colors: [Character: Color] = [
                "3": Color(hex: "#e8e8d0"),
            ]
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if let color = colors[ch] {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    static func slimeBerry(size: CGFloat = 16) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 9
            let grid: [String] = [
                "000220000",
                "002002000",
                "001441000",
                "014444100",
                "014A44100",
                "014444100",
                "001441000",
                "000110000",
                "000000000",
            ]
            let colors: [Character: Color] = [
                "1": Color(hex: "#1a1a2e"),
                "2": Color(hex: "#4ecca3"),
                "4": Color(hex: "#e94560"),
                "A": Color(hex: "#ffffff"),
            ]
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if let color = colors[ch] {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    static func moonPetal(size: CGFloat = 16) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 9
            let grid: [String] = [
                "000010000",
                "000110000",
                "001AA1000",
                "01AAAA100",
                "01ABAA100",
                "01AAAA100",
                "001AA1000",
                "000110000",
                "000000000",
            ]
            let colors: [Character: Color] = [
                "1": Color(hex: "#1a1a2e"),
                "A": Color(hex: "#ffffff"),
                "B": Color(hex: "#c8c8b8"),
            ]
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if let color = colors[ch] {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    static func emberSeed(size: CGFloat = 16) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 9
            let grid: [String] = [
                "000050000",
                "000550000",
                "001551000",
                "015555100",
                "015A55100",
                "015555100",
                "001551000",
                "000110000",
                "000000000",
            ]
            let colors: [Character: Color] = [
                "1": Color(hex: "#1a1a2e"),
                "5": Color(hex: "#f5a623"),
                "A": Color(hex: "#ffffff"),
            ]
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if let color = colors[ch] {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    static func ancientSpore(size: CGFloat = 16) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 9
            let grid: [String] = [
                "000060000",
                "006566000",
                "065656600",
                "065A56600",
                "065656600",
                "006566000",
                "000660000",
                "000000000",
                "000000000",
            ]
            let colors: [Character: Color] = [
                "6": Color(hex: "#7b2d8b"),
                "5": Color(hex: "#f5a623"),
                "A": Color(hex: "#ffffff"),
            ]
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if let color = colors[ch] {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    static func goldenBug(size: CGFloat = 16) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 9
            let grid: [String] = [
                "000000000",
                "001000100",
                "010555010",
                "055555550",
                "055A55550",
                "055555550",
                "010555010",
                "001000100",
                "000000000",
            ]
            let colors: [Character: Color] = [
                "1": Color(hex: "#1a1a2e"),
                "5": Color(hex: "#f5a623"),
                "A": Color(hex: "#ffffff"),
            ]
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if let color = colors[ch] {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }
```

- [ ] **Step 3: Add UI icons (heart, leaf, bag, drumstick, stomach, skull, lightning)**

Add these following the same 9x9 pattern. These are used for stat bars, nav, and status effects:

```swift
    static func heart(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "011011000", "111111100", "111111100", "111111100",
            "011111000", "001110000", "000100000", "000000000", "000000000",
        ], colors: ["1": Color(hex: "#e94560")])
    }

    static func leaf(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "000001100", "000011000", "000112000", "001122000",
            "012220000", "022200000", "012000000", "001000000", "000000000",
        ], colors: ["1": Color(hex: "#2a7a60"), "2": Color(hex: "#4ecca3")])
    }

    static func bag(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "001111000", "010000100", "011111100", "015555100",
            "015555100", "015555100", "015555100", "011111100", "000000000",
        ], colors: ["1": Color(hex: "#1a1a2e"), "5": Color(hex: "#c0b89a")])
    }

    static func drumstick(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "000111000", "001444100", "014444100", "014444100",
            "001441000", "000110000", "000550000", "000550000", "000000000",
        ], colors: ["1": Color(hex: "#1a1a2e"), "4": Color(hex: "#e94560"), "5": Color(hex: "#c0b89a")])
    }

    // Helper to reduce boilerplate
    static func pixelGrid(size: CGFloat, grid: [String], colors: [Character: Color]) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / CGFloat(grid[0].count)
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if let color = colors[ch] {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }
```

- [ ] **Step 4: Add ingredientIcon helper that maps ID to icon view**

```swift
    @ViewBuilder
    static func ingredientIcon(_ id: String, size: CGFloat = 16) -> some View {
        switch id {
        case "moss_clump": mossClump(size: size)
        case "cave_beetle": caveBeetle(size: size)
        case "mud_root": mudRoot(size: size)
        case "dew_drop": dewDrop(size: size)
        case "glowshroom": glowshroom(size: size)
        case "crystal_shard": crystalShard(size: size)
        case "pale_worm": paleWorm(size: size)
        case "slime_berry": slimeBerry(size: size)
        case "moon_petal": moonPetal(size: size)
        case "ember_seed": emberSeed(size: size)
        case "ancient_spore": ancientSpore(size: size)
        case "golden_bug": goldenBug(size: size)
        default: nut(size: size)
        }
    }
```

- [ ] **Step 5: Build to verify**

- [ ] **Step 6: Commit**

```bash
git add GrubIOS/SpriteRenderer.swift
git commit -m "feat: add 12 ingredient icons, UI icons, pixelGrid helper"
```

---

## Chunk 5: New Overlay UIs

### Task 7: Forage Overlay

**Files:**
- Create: `GrubIOS/ForageOverlay.swift`

- [ ] **Step 1: Create ForageOverlay.swift**

```swift
import SwiftUI

struct ForageOverlayView: View {
    @ObservedObject var game: GameState

    var body: some View {
        ZStack {
            Color(hex: "#1a1a2e").opacity(0.93)
                .ignoresSafeArea()
                .onTapGesture { game.showForageOverlay = false }

            VStack(spacing: 0) {
                Text("FORAGE")
                    .font(GrubFont.size(14))
                    .foregroundColor(GrubPalette.green)
                    .tracking(2)
                    .padding(.bottom, 16)

                if !game.canForage {
                    Text("COOLDOWN: \(game.forageTimeRemaining)m")
                        .font(GrubFont.size(11))
                        .foregroundColor(GrubPalette.yellow)
                        .padding(.bottom, 12)
                }

                VStack(spacing: 10) {
                    ForageAreaButton(area: .shallowCave, enabled: game.canForage) {
                        game.forage(area: .shallowCave)
                    }
                    ForageAreaButton(area: .deepBurrow, enabled: game.canForage) {
                        game.forage(area: .deepBurrow)
                    }
                    ForageAreaButton(area: .surface, enabled: game.canForage) {
                        game.forage(area: .surface)
                    }
                }

                Button {
                    game.audio.play(.tap)
                    game.showForageOverlay = false
                } label: {
                    Text("CLOSE")
                        .font(GrubFont.size(11))
                        .foregroundColor(GrubPalette.green)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .overlay(Rectangle().stroke(GrubPalette.green, lineWidth: 2))
                }
                .padding(.top, 16)
            }
            .padding(24)
            .background(GrubPalette.void_color)
            .border(GrubPalette.green, width: 2)
            .padding(.horizontal, 24)
        }
        .transition(.opacity)
    }
}

struct ForageAreaButton: View {
    let area: ForageArea
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(area.rawValue)
                    .font(GrubFont.size(11))
                    .foregroundColor(enabled ? GrubPalette.pale : GrubPalette.grey)
                Text(area.description)
                    .font(GrubFont.size(8))
                    .foregroundColor(enabled ? GrubPalette.dimGreen : GrubPalette.grey.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(GrubPalette.moss)
            .border(enabled ? GrubPalette.green : GrubPalette.deepMoss, width: 2)
        }
        .disabled(!enabled)
        .buttonStyle(PixelButtonStyle())
    }
}

struct ForageResultsView: View {
    @ObservedObject var game: GameState

    var body: some View {
        ZStack {
            Color(hex: "#1a1a2e").opacity(0.93)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("GRUB FOUND")
                    .font(GrubFont.size(14))
                    .foregroundColor(GrubPalette.green)
                    .tracking(2)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 12) {
                    ForEach(Array(game.forageResults.enumerated()), id: \.offset) { _, itemId in
                        VStack(spacing: 4) {
                            PixelIcon.ingredientIcon(itemId, size: 28)
                            Text(ingredientCatalog[itemId]?.name ?? "???")
                                .font(GrubFont.size(6))
                                .foregroundColor(GrubPalette.pale)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding(.horizontal, 8)

                Button {
                    game.audio.play(.tap)
                    game.showForageResults = false
                    game.forageResults = []
                } label: {
                    Text("COLLECT")
                        .font(GrubFont.size(11))
                        .foregroundColor(GrubPalette.void_color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(GrubPalette.green)
                }
                .padding(.top, 8)
            }
            .padding(24)
            .background(GrubPalette.void_color)
            .border(GrubPalette.green, width: 2)
            .padding(.horizontal, 24)
        }
        .transition(.opacity)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add GrubIOS/ForageOverlay.swift
git commit -m "feat: add forage area selector and results overlay"
```

---

### Task 8: Inventory & Crafting Overlay

**Files:**
- Create: `GrubIOS/InventoryOverlay.swift`

- [ ] **Step 1: Create InventoryOverlay.swift**

Full inventory screen with two tabs (INGREDIENTS / FOOD) and crafting sub-screen. This is a larger file — includes the ingredient grid, crafted food list, and recipe list with craft buttons.

The inventory shows ingredients as a grid with quantity badges. The food tab shows crafted items with a USE button. A CRAFT button at the bottom opens the recipe list.

Key components:
- `InventoryOverlayView` — main container with tab switching
- `IngredientsGridView` — shows held ingredients
- `CraftedFoodListView` — shows usable food/meds
- `CraftingListView` — shows recipes with craft buttons

- [ ] **Step 2: Commit**

```bash
git add GrubIOS/InventoryOverlay.swift
git commit -m "feat: add inventory overlay with ingredients, food, and crafting views"
```

---

### Task 9: Game Selector Overlay

**Files:**
- Create: `GrubIOS/GameSelectorOverlay.swift`

- [ ] **Step 1: Create GameSelectorOverlay.swift**

Shows unlocked games with high scores and a win streak counter. Locked games show required level.

- [ ] **Step 2: Commit**

```bash
git add GrubIOS/GameSelectorOverlay.swift
git commit -m "feat: add arcade game selector overlay"
```

---

### Task 10: Update Minigame Overlay for New Games

**Files:**
- Modify: `GrubIOS/GameOverlays.swift`

- [ ] **Step 1: Update MinigameOverlayView**

Add rendering for Memory (4x3 card grid), Bug Catch (tappable canvas with moving bugs), and Rhythm (4 colored buttons with highlight state). Keep Dodge and Feed Me mostly as-is but update round count display to show X/5 instead of X/3.

Update `MinigameCanvasView` to handle all 5 game types.

Update the food choice buttons for Feed Me to use the new string-based food names instead of emoji.

- [ ] **Step 2: Update FeedOverlayView**

Replace the old 3-food-item list with a crafted food list. Show crafted items from `game.craftedItems` with USE buttons. If empty, show "NO FOOD! CRAFT SOME."

- [ ] **Step 3: Update EventOverlayView font sizes**

Bump event text and option button fonts to match the rest of the UI (11-13pt).

- [ ] **Step 4: Update StatsMenuView**

Remove crumbs row. Add rows for: FORAGES, RECIPES, ITEMS CRAFTED. Update font sizes.

- [ ] **Step 5: Build to verify**

- [ ] **Step 6: Commit**

```bash
git add GrubIOS/GameOverlays.swift
git commit -m "feat: update overlays for new game types, crafted food, stats"
```

---

## Chunk 6: Main UI Rework

### Task 11: Status Bars Rework

**Files:**
- Modify: `GrubIOS/ContentView.swift`

- [ ] **Step 1: Replace StatBarRow with segmented bar design**

New `StatBarRow`:
- 22px tall
- Pixel icon (drumstick/heart/star) instead of text label
- 10 segments, each fills based on value
- Color transitions: green (70+), yellow (40-69), orange (20-39), red (0-19)
- Value text rendered right-aligned after the bar
- Status effect icons shown to the right when active

- [ ] **Step 2: Commit**

```bash
git add GrubIOS/ContentView.swift
git commit -m "feat: rework status bars with segments, icons, color transitions"
```

---

### Task 12: Bottom Nav & Top Bar Rework

**Files:**
- Modify: `GrubIOS/ContentView.swift`

- [ ] **Step 1: Replace ActionButtonsView with 4-button nav**

4 buttons: FEED, PLAY, FORAGE, ITEMS
- 40px pixel icons: drumstick, gamepad, leaf, bag
- Label text below each icon
- FORAGE button shows badge when passive items are waiting

- [ ] **Step 2: Update TopBarView**

Replace crumbs display with ingredient count:
```
LVL X          GRUB_NAME          ITEMS: N
```

- [ ] **Step 3: Wire up new overlay toggles in ContentView body**

Add to the overlay ZStack in ContentView:
```swift
if game.showForageOverlay { ForageOverlayView(game: game) }
if game.showForageResults { ForageResultsView(game: game) }
if game.showInventoryOverlay { InventoryOverlayView(game: game) }
if game.showGameSelector { GameSelectorOverlayView(game: game) }
```

Update FEED button to show crafted food overlay (or inventory food tab).
Update PLAY button to call `game.openPlay()` (now opens game selector).
Add FORAGE button action: `game.showForageOverlay = true`.
Add ITEMS button action: `game.showInventoryOverlay = true`.

- [ ] **Step 4: Build the full project**

Run: `xcodebuild -project GrubIOS.xcodeproj -scheme GrubIOS -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/GrubBuild build 2>&1 | tail -10`
Expected: `** BUILD SUCCEEDED **`

Fix any remaining compilation errors.

- [ ] **Step 5: Commit**

```bash
git add GrubIOS/ContentView.swift
git commit -m "feat: 4-button nav, top bar rework, wire up all overlays"
```

---

## Chunk 7: Dynamic Background

### Task 14: Animated Time-of-Day Background

**Files:**
- Modify: `GrubIOS/SpriteRenderer.swift`
- Modify: `GrubIOS/ContentView.swift`

- [ ] **Step 1: Add TimePhase enum and color palettes to SpriteRenderer**

Add above `drawBackground()`:

```swift
enum TimePhase {
    case dawn, day, dusk, night

    static var current: TimePhase {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 5 && hour < 8 { return .dawn }
        if hour >= 8 && hour < 18 { return .day }
        if hour >= 18 && hour < 21 { return .dusk }
        return .night
    }

    var skyColors: [Color] {
        switch self {
        case .dawn: return [
            Color(hex: "#0e0e2a"), Color(hex: "#1a1040"), Color(hex: "#2a1848"),
            Color(hex: "#3a2050"), Color(hex: "#4a2850"), Color(hex: "#5a3048"),
            Color(hex: "#6a3848"), Color(hex: "#7a4040"),
        ]
        case .day: return [
            Color(hex: "#0e0e2a"), Color(hex: "#12123a"), Color(hex: "#161640"),
            Color(hex: "#1a1a44"), Color(hex: "#1e1e48"), Color(hex: "#1a1a3e"),
            Color(hex: "#1a1a3e"), Color(hex: "#1a1a3e"),
        ]
        case .dusk: return [
            Color(hex: "#0a0a1e"), Color(hex: "#1a1030"), Color(hex: "#2a1838"),
            Color(hex: "#3a2040"), Color(hex: "#4a2838"), Color(hex: "#5a3030"),
            Color(hex: "#6a3830"), Color(hex: "#7a4028"),
        ]
        case .night: return [
            Color(hex: "#060612"), Color(hex: "#080818"), Color(hex: "#0a0a1e"),
            Color(hex: "#0c0c22"), Color(hex: "#0e0e26"), Color(hex: "#0e0e26"),
            Color(hex: "#0e0e26"), Color(hex: "#0e0e26"),
        ]
        }
    }

    var groundTop: Color {
        switch self {
        case .dawn: return Color(hex: "#2a6a40")
        case .day: return Color(hex: "#3a9a70")
        case .dusk: return Color(hex: "#2a6a40")
        case .night: return Color(hex: "#1a4a28")
        }
    }

    var groundMid: Color {
        switch self {
        case .dawn: return Color(hex: "#1e3a22")
        case .day: return Color(hex: "#243828")
        case .dusk: return Color(hex: "#1e3020")
        case .night: return Color(hex: "#142018")
        }
    }

    var groundDark: Color {
        switch self {
        case .dawn: return Color(hex: "#162a18")
        case .day: return Color(hex: "#1a3020")
        case .dusk: return Color(hex: "#16261a")
        case .night: return Color(hex: "#0e1810")
        }
    }

    var sporeOpacity: Double {
        switch self {
        case .dawn: return 0.25
        case .day: return 0.2
        case .dusk: return 0.3
        case .night: return 0.55
        }
    }

    var starOpacity: Double {
        switch self {
        case .dawn: return 0.15
        case .day: return 0.0
        case .dusk: return 0.2
        case .night: return 0.7
        }
    }

    var showDrips: Bool { self != .night }

    var mushGlowOpacity: Double {
        switch self {
        case .night: return 0.4
        default: return 0.0
        }
    }
}
```

- [ ] **Step 2: Rewrite drawBackground() to accept tick and use TimePhase**

Change signature:
```swift
static func drawBackground(context: inout GraphicsContext, size: CGSize, tick: Int) {
```

Replace `isNight` references with `TimePhase.current`. Use `tick` for animations:

**Sky bands** — use `phase.skyColors` array.

**Animated spores** — each spore drifts upward:
```swift
let sporeData: [(baseX: CGFloat, baseY: CGFloat, speed: CGFloat, phase: Int)] = [
    (0.15, 0.7, 0.3, 0), (0.4, 0.8, 0.2, 40), (0.65, 0.6, 0.35, 80),
    (0.82, 0.75, 0.25, 120), (0.25, 0.65, 0.15, 60), (0.55, 0.85, 0.3, 100),
    (0.9, 0.7, 0.2, 20), (0.1, 0.9, 0.28, 140), (0.48, 0.72, 0.18, 90),
    (0.72, 0.82, 0.32, 50),
]
for spore in sporeData {
    let cycle = 400 // ticks for full drift
    let t = (tick + spore.phase) % cycle
    let yOffset = CGFloat(t) * spore.speed
    let y = (spore.baseY * groundStart) - yOffset
    let wrappedY = y < 0 ? y + groundStart : y
    block(spore.baseX * w, wrappedY, px, px, sporeColor.opacity(phase.sporeOpacity))
}
```

**Star twinkle** (night/dusk/dawn):
```swift
if phase.starOpacity > 0 {
    for (i, (sx, sy)) in starPositions.enumerated() {
        let twinkle = sin(Double(tick + i * 37) * 0.05) * 0.3 + 0.7
        block(sx * w, sy * groundStart, px, px,
              starColor.opacity(phase.starOpacity * twinkle))
    }
}
```

**Dripping water** (day/dawn/dusk):
```swift
if phase.showDrips {
    let dripSources: [(x: CGFloat, startY: CGFloat, cycle: Int)] = [
        (0.25, 0.06, 120), (0.62, 0.04, 160), (0.45, 0.08, 140),
    ]
    for drip in dripSources {
        let t = tick % drip.cycle
        let progress = CGFloat(t) / CGFloat(drip.cycle)
        let dropY = drip.startY * h + progress * (groundStart - drip.startY * h)
        // Growing drop at stalactite
        if progress < 0.3 {
            block(drip.x * w, drip.startY * h, px, px,
                  Color(hex: "#4ecca3").opacity(0.3 * Double(progress / 0.3)))
        }
        // Falling drop
        if progress >= 0.3 && progress < 0.9 {
            block(drip.x * w, dropY, px, px * 2, Color(hex: "#4ecca3").opacity(0.25))
        }
        // Splash
        if progress >= 0.9 {
            let splash = (progress - 0.9) / 0.1
            block(drip.x * w - px, groundStart - px, px * 3, px,
                  Color(hex: "#4ecca3").opacity(0.2 * (1 - Double(splash))))
        }
    }
}
```

**Mushroom glow** (night):
```swift
if phase.mushGlowOpacity > 0 {
    for (mx, capColor, capW) in mushData {
        let glow = sin(Double(tick) * 0.03) * 0.15 + phase.mushGlowOpacity
        let baseX = floor(mx * w / px) * px
        let glowSize = CGFloat(capW + 2) * px
        block(baseX - glowSize / 2 + px / 2, grassY - px * 3,
              glowSize, px * 2,
              Color(hex: "#7b2d8b").opacity(glow))
    }
}
```

**Ambient particles** — slow horizontal drift:
```swift
let particles: [(baseX: CGFloat, y: CGFloat, speed: CGFloat, offset: Int)] = [
    (0.0, 0.35, 0.15, 0), (0.3, 0.55, 0.1, 200), (0.7, 0.25, 0.12, 100),
]
for p in particles {
    let cycle = 600
    let t = (tick + p.offset) % cycle
    let x = (p.baseX + CGFloat(t) * p.speed / CGFloat(cycle))
    let wrappedX = x.truncatingRemainder(dividingBy: 1.0)
    block(wrappedX * w, p.y * groundStart, px, px,
          GrubPalette.pale.opacity(0.06))
}
```

- [ ] **Step 3: Update ViewportView to pass tick**

In `ContentView.swift`, change the Canvas call:
```swift
SpriteRenderer.drawBackground(context: &context, size: size, tick: game.animTick)
```

Remove the old `isNight: game.isNight` parameter.

- [ ] **Step 4: Build and test**

- [ ] **Step 5: Commit**

```bash
git add GrubIOS/SpriteRenderer.swift GrubIOS/ContentView.swift
git commit -m "feat: dynamic animated background with 4 time phases, floating spores, drips, twinkling stars"
```

---

## Chunk 8: Integration & Polish

### Task 15: Install, Test, Fix

- [ ] **Step 1: Install and launch on simulator**

```bash
xcrun simctl terminate booted com.jessedev.GrubIOS || true
sleep 1
xcrun simctl install booted /tmp/GrubBuild/Build/Products/Debug-iphonesimulator/GrubIOS.app
xcrun simctl launch booted com.jessedev.GrubIOS
```

- [ ] **Step 2: Manual test checklist**

Test each flow:
- [ ] Name entry still works
- [ ] Status bars render with segments and icons
- [ ] Top bar shows LVL and ingredient count
- [ ] FEED button opens crafted food list (empty at start, shows message)
- [ ] PLAY button opens game selector (2 games unlocked at start)
- [ ] Dodge game works with 5 rounds
- [ ] Feed Me game works with shrinking timer
- [ ] FORAGE button opens area selector
- [ ] Forage returns ingredients and shows results
- [ ] Forage cooldown works (grays out buttons, shows timer)
- [ ] ITEMS button opens inventory
- [ ] Ingredients tab shows held items
- [ ] CRAFT button opens recipe list
- [ ] Crafting consumes ingredients and produces food
- [ ] Food tab shows crafted items
- [ ] Using food applies stats and plays animation
- [ ] Events trigger and give ingredient rewards
- [ ] Passive gathering works on re-open
- [ ] Stats menu shows new tracking rows
- [ ] Death/restart preserves recipes and high scores, resets inventory

- [ ] **Step 3: Fix any bugs found**

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "fix: integration fixes and polish for grub overhaul"
```
