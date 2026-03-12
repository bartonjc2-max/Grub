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
    let iconName: String
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

// MARK: - Bug Catch game state
struct BugState {
    var x: Double
    var y: Double
    var dx: Double
    var dy: Double
    var caught: Bool
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
// 12 ingredients: 4 common, 4 uncommon, 4 rare
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

let commonIngredients = ingredientCatalog.values.filter { $0.rarity == .common }.map(\.id)
let uncommonIngredients = ingredientCatalog.values.filter { $0.rarity == .uncommon }.map(\.id)
let rareIngredients = ingredientCatalog.values.filter { $0.rarity == .rare }.map(\.id)

// MARK: - Recipe Catalog
// 14 recipes: 3 starter, 6 level-unlocked, 5 scroll-unlocked
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

let scrollRecipeIds: [String] = recipeCatalog.values
    .filter { $0.unlockType == .scroll }
    .map(\.id)

// MARK: - Loot Tables
struct LootTable {
    let commonWeight: Double
    let uncommonWeight: Double
    let rareWeight: Double
    let riskChance: Double
    let riskStatType: String
    let riskAmount: Int
    let riskMessage: String
    let itemCount: ClosedRange<Int>
    let specialPool: [String]?
    let excludePool: [String]?

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
        itemCount: 2...4, specialPool: nil, excludePool: ["moon_petal", "ember_seed"]
    ),
    .deepBurrow: LootTable(
        commonWeight: 0.30, uncommonWeight: 0.50, rareWeight: 0.20,
        riskChance: 0.20, riskStatType: "happiness", riskAmount: -10,
        riskMessage: "GRUB GOT SPOOKED!",
        itemCount: 2...4, specialPool: ["ember_seed"], excludePool: ["moon_petal"]
    ),
    .surface: LootTable(
        commonWeight: 0.40, uncommonWeight: 0.20, rareWeight: 0.40,
        riskChance: 0.15, riskStatType: "health", riskAmount: -5,
        riskMessage: "GRUB GOT SCRATCHED!",
        itemCount: 2...4, specialPool: nil, excludePool: ["ember_seed"]
    ),
]
