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

let commonIngredients = ingredientCatalog.values.filter { $0.rarity == .common }.map(\.id).sorted()
let uncommonIngredients = ingredientCatalog.values.filter { $0.rarity == .uncommon }.map(\.id).sorted()
let rareIngredients = ingredientCatalog.values.filter { $0.rarity == .rare }.map(\.id).sorted()

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

// MARK: - Personality Traits
enum PersonalityTrait: String, Codable, CaseIterable {
    case scrappy    // From frequent foraging — better forage yields
    case cheerful   // From high happiness maintenance — bonus XP
    case hardy      // From surviving low health often — slower health decay
    case curious    // From discovering many ingredients — better rare chances
    case picky      // From overfeeding — rejects low-tier food but bonus from high-tier
    case lazy       // From neglect — slower stat decay overall
    case fierce     // From many minigame wins — better minigame rewards
    case gentle     // From frequent feeding — bonus happiness from food

    var description: String {
        switch self {
        case .scrappy: return "FORAGE YIELDS +50%"
        case .cheerful: return "XP GAIN +50%"
        case .hardy: return "HEALTH DECAY -30%"
        case .curious: return "RARE FIND CHANCE +20%"
        case .picky: return "GOOD FOOD +50% EFFECT"
        case .lazy: return "ALL DECAY -20%"
        case .fierce: return "MINIGAME REWARDS +1"
        case .gentle: return "FOOD GIVES +5 HAP"
        }
    }
}

// MARK: - Burrow Decorations
struct DecorationDef {
    let id: String
    let name: String
    let ingredients: [RecipeIngredient]
    let bonusType: DecorationBonus
    let slot: DecorationSlot
}

enum DecorationSlot: String, Codable, CaseIterable {
    case floor      // Ground level items
    case wall       // Wall-mounted items
    case ceiling    // Hanging items
    case corner     // Corner accent pieces
}

enum DecorationBonus: String, Codable {
    case healthDecay     // Slower health decay
    case happinessDecay  // Slower happiness decay
    case hungerDecay     // Slower hunger decay
    case forageLuck      // Better forage results
    case xpBoost         // Bonus XP
    case passiveGather   // Faster passive gathering
    case eventChance     // More frequent events
    case minigameBonus   // Better minigame rewards
}

let decorationCatalog: [String: DecorationDef] = {
    let defs: [DecorationDef] = [
        // Floor decorations
        DecorationDef(id: "moss_bed", name: "MOSS BED",
            ingredients: [.init(id: "moss_clump", quantity: 4), .init(id: "pale_worm", quantity: 1)],
            bonusType: .healthDecay, slot: .floor),
        DecorationDef(id: "berry_rug", name: "BERRY RUG",
            ingredients: [.init(id: "slime_berry", quantity: 3), .init(id: "moss_clump", quantity: 2)],
            bonusType: .happinessDecay, slot: .floor),
        DecorationDef(id: "root_table", name: "ROOT TABLE",
            ingredients: [.init(id: "mud_root", quantity: 4), .init(id: "crystal_shard", quantity: 1)],
            bonusType: .hungerDecay, slot: .floor),
        // Wall decorations
        DecorationDef(id: "crystal_lamp", name: "CRYSTAL LAMP",
            ingredients: [.init(id: "crystal_shard", quantity: 3), .init(id: "dew_drop", quantity: 2)],
            bonusType: .forageLuck, slot: .wall),
        DecorationDef(id: "spore_painting", name: "SPORE PAINTING",
            ingredients: [.init(id: "ancient_spore", quantity: 1), .init(id: "slime_berry", quantity: 2)],
            bonusType: .xpBoost, slot: .wall),
        DecorationDef(id: "beetle_display", name: "BEETLE DISPLAY",
            ingredients: [.init(id: "cave_beetle", quantity: 4), .init(id: "crystal_shard", quantity: 1)],
            bonusType: .eventChance, slot: .wall),
        // Ceiling decorations
        DecorationDef(id: "glow_mobile", name: "GLOW MOBILE",
            ingredients: [.init(id: "glowshroom", quantity: 3), .init(id: "dew_drop", quantity: 2)],
            bonusType: .passiveGather, slot: .ceiling),
        DecorationDef(id: "moon_chime", name: "MOON CHIME",
            ingredients: [.init(id: "moon_petal", quantity: 2), .init(id: "crystal_shard", quantity: 1)],
            bonusType: .minigameBonus, slot: .ceiling),
        // Corner decorations
        DecorationDef(id: "ember_hearth", name: "EMBER HEARTH",
            ingredients: [.init(id: "ember_seed", quantity: 2), .init(id: "mud_root", quantity: 3)],
            bonusType: .healthDecay, slot: .corner),
        DecorationDef(id: "worm_farm", name: "WORM FARM",
            ingredients: [.init(id: "pale_worm", quantity: 3), .init(id: "moss_clump", quantity: 2)],
            bonusType: .hungerDecay, slot: .corner),
        DecorationDef(id: "golden_shrine", name: "GOLDEN SHRINE",
            ingredients: [.init(id: "golden_bug", quantity: 1), .init(id: "ember_seed", quantity: 1), .init(id: "crystal_shard", quantity: 2)],
            bonusType: .xpBoost, slot: .corner),
        DecorationDef(id: "dew_fountain", name: "DEW FOUNTAIN",
            ingredients: [.init(id: "dew_drop", quantity: 5), .init(id: "crystal_shard", quantity: 2)],
            bonusType: .happinessDecay, slot: .floor),
    ]
    return Dictionary(uniqueKeysWithValues: defs.map { ($0.id, $0) })
}()

// MARK: - Expeditions
struct ExpeditionDef {
    let id: String
    let name: String
    let description: String
    let durationMinutes: Int
    let unlockLevel: Int
    let lootPool: [(id: String, weight: Double)]
    let lootCount: ClosedRange<Int>
    let riskChance: Double
    let riskDamage: Int
    let riskMessage: String
    let xpReward: Int
    let bonusRareChance: Double
}

let expeditionCatalog: [String: ExpeditionDef] = {
    let defs: [ExpeditionDef] = [
        ExpeditionDef(id: "shallow_scout", name: "SHALLOW SCOUT",
            description: "QUICK LOOK AROUND\nNO DANGER",
            durationMinutes: 5, unlockLevel: 1,
            lootPool: [("moss_clump", 0.3), ("cave_beetle", 0.3), ("mud_root", 0.2), ("dew_drop", 0.2)],
            lootCount: 2...3, riskChance: 0, riskDamage: 0, riskMessage: "",
            xpReward: 1, bonusRareChance: 0),
        ExpeditionDef(id: "deep_dive", name: "DEEP DIVE",
            description: "DEEPER TUNNELS\nBETTER LOOT, SOME RISK",
            durationMinutes: 10, unlockLevel: 2,
            lootPool: [("glowshroom", 0.25), ("crystal_shard", 0.25), ("pale_worm", 0.2), ("slime_berry", 0.2), ("cave_beetle", 0.1)],
            lootCount: 3...5, riskChance: 0.15, riskDamage: 8, riskMessage: "GRUB GOT SCRAPED!",
            xpReward: 2, bonusRareChance: 0.05),
        ExpeditionDef(id: "crystal_mines", name: "CRYSTAL MINES",
            description: "GLITTERING TUNNELS\nGOOD LOOT, REAL DANGER",
            durationMinutes: 20, unlockLevel: 3,
            lootPool: [("crystal_shard", 0.35), ("ember_seed", 0.15), ("glowshroom", 0.2), ("dew_drop", 0.15), ("moon_petal", 0.1), ("cave_beetle", 0.05)],
            lootCount: 4...6, riskChance: 0.2, riskDamage: 12, riskMessage: "CAVE-IN! GRUB IS HURT!",
            xpReward: 3, bonusRareChance: 0.1),
        ExpeditionDef(id: "surface_run", name: "SURFACE RUN",
            description: "BRAVE THE SURFACE\nRARE FINDS, HIGH RISK",
            durationMinutes: 30, unlockLevel: 4,
            lootPool: [("moon_petal", 0.25), ("slime_berry", 0.2), ("ancient_spore", 0.1), ("golden_bug", 0.05), ("ember_seed", 0.15), ("crystal_shard", 0.15), ("glowshroom", 0.1)],
            lootCount: 4...7, riskChance: 0.25, riskDamage: 15, riskMessage: "PREDATOR ATTACK!",
            xpReward: 5, bonusRareChance: 0.15),
        ExpeditionDef(id: "ancient_ruins", name: "ANCIENT RUINS",
            description: "FORGOTTEN DEPTHS\nBEST LOOT, MOST DANGER",
            durationMinutes: 45, unlockLevel: 6,
            lootPool: [("ancient_spore", 0.2), ("golden_bug", 0.1), ("moon_petal", 0.2), ("ember_seed", 0.2), ("crystal_shard", 0.15), ("glowshroom", 0.15)],
            lootCount: 5...8, riskChance: 0.3, riskDamage: 20, riskMessage: "ANCIENT TRAP TRIGGERED!",
            xpReward: 8, bonusRareChance: 0.2),
    ]
    return Dictionary(uniqueKeysWithValues: defs.map { ($0.id, $0) })
}()

let expeditionsSorted: [ExpeditionDef] = expeditionCatalog.values.sorted { $0.unlockLevel < $1.unlockLevel }

// MARK: - Journal Entries
struct JournalEntry {
    let id: String
    let title: String
    let text: String
    let unlockCondition: JournalUnlock
}

enum JournalUnlock {
    case ingredient(String)          // Discover this ingredient
    case recipe(String)              // Unlock this recipe
    case decoration(String)          // Place this decoration
    case expedition(String)          // Complete this expedition
    case milestone(String, Int)      // stat name, threshold
    case trait(PersonalityTrait)     // Develop this trait
}

let journalEntries: [JournalEntry] = [
    // Ingredient discoveries
    JournalEntry(id: "j_moss", title: "CAVE MOSS", text: "SOFT AND SPONGY. GROWS\nEVERYWHERE DOWN HERE.\nBASIC BUT RELIABLE.", unlockCondition: .ingredient("moss_clump")),
    JournalEntry(id: "j_beetle", title: "CAVE BEETLE", text: "CRUNCHY LITTLE CRITTER.\nTHEY SCATTER WHEN YOU\nDIG IN THE WALLS.", unlockCondition: .ingredient("cave_beetle")),
    JournalEntry(id: "j_root", title: "MUD ROOT", text: "TOUGH AND EARTHY.\nGROWS DEEP IN DAMP\nTUNNELS.", unlockCondition: .ingredient("mud_root")),
    JournalEntry(id: "j_dew", title: "DEW DROP", text: "DRIPS FROM STALACTITES.\nPURE AND REFRESHING.\nESSENTIAL FOR BREWS.", unlockCondition: .ingredient("dew_drop")),
    JournalEntry(id: "j_glow", title: "GLOWSHROOM", text: "PULSES WITH SOFT LIGHT.\nWARMTH IN THE DARK.\nUNCOMMON FIND.", unlockCondition: .ingredient("glowshroom")),
    JournalEntry(id: "j_crystal", title: "CRYSTAL SHARD", text: "SPARKLES LIKE STARLIGHT.\nHARD TO FIND.\nMANY USES.", unlockCondition: .ingredient("crystal_shard")),
    JournalEntry(id: "j_worm", title: "PALE WORM", text: "BLIND BUT FRIENDLY.\nWIGGLES WHEN HELD.\nA CAVE DELICACY.", unlockCondition: .ingredient("pale_worm")),
    JournalEntry(id: "j_berry", title: "SLIME BERRY", text: "GOOPY AND SWEET.\nGROWS ON CAVE WALLS.\nGRUB LOVES THESE.", unlockCondition: .ingredient("slime_berry")),
    JournalEntry(id: "j_moon", title: "MOON PETAL", text: "FELL FROM ABOVE.\nGLOWS IN MOONLIGHT.\nVERY RARE.", unlockCondition: .ingredient("moon_petal")),
    JournalEntry(id: "j_ember", title: "EMBER SEED", text: "HOT TO THE TOUCH.\nFOUND NEAR LAVA VENTS.\nHANDLE WITH CARE.", unlockCondition: .ingredient("ember_seed")),
    JournalEntry(id: "j_spore", title: "ANCIENT SPORE", text: "OLDER THAN THE CAVE.\nHUMS WITH ENERGY.\nLEGENDARY INGREDIENT.", unlockCondition: .ingredient("ancient_spore")),
    JournalEntry(id: "j_gold", title: "GOLDEN BUG", text: "SHIMMERS LIKE TREASURE.\nALMOST TOO PRETTY\nTO USE IN RECIPES.", unlockCondition: .ingredient("golden_bug")),
    // Milestone entries
    JournalEntry(id: "j_fed10", title: "WELL FED", text: "GRUB HAS EATEN 10\nMEALS. A HEALTHY\nAPPETITE!", unlockCondition: .milestone("fedCount", 10)),
    JournalEntry(id: "j_fed50", title: "GOURMAND", text: "50 MEALS! GRUB HAS\nTRIED EVERYTHING\nTHE CAVE OFFERS.", unlockCondition: .milestone("fedCount", 50)),
    JournalEntry(id: "j_craft10", title: "APPRENTICE CHEF", text: "CRAFTED 10 ITEMS.\nGRUB IS LEARNING\nTO COOK!", unlockCondition: .milestone("itemsCrafted", 10)),
    JournalEntry(id: "j_craft50", title: "MASTER CHEF", text: "50 CRAFTED ITEMS!\nGRUB COULD OPEN\nA RESTAURANT.", unlockCondition: .milestone("itemsCrafted", 50)),
    JournalEntry(id: "j_forage10", title: "EXPLORER", text: "10 FORAGING TRIPS.\nGRUB KNOWS THESE\nTUNNELS WELL.", unlockCondition: .milestone("forageCount", 10)),
    JournalEntry(id: "j_forage50", title: "SPELUNKER", text: "50 TRIPS! GRUB IS\nA MASTER OF THE\nUNDERGROUND.", unlockCondition: .milestone("forageCount", 50)),
    JournalEntry(id: "j_lvl5", title: "GROWING UP", text: "LEVEL 5 REACHED.\nGRUB IS NO LONGER\nA BABY!", unlockCondition: .milestone("ownerLevel", 5)),
    JournalEntry(id: "j_lvl10", title: "VETERAN", text: "LEVEL 10! A TRUE\nCAVE DWELLER.", unlockCondition: .milestone("ownerLevel", 10)),
    JournalEntry(id: "j_wins10", title: "GAME CHAMP", text: "WON 10 MINIGAMES!\nGRUB HAS QUICK\nREFLEXES.", unlockCondition: .milestone("playedCount", 10)),
    // Trait entries
    JournalEntry(id: "j_scrappy", title: "SCRAPPY NATURE", text: "GRUB DEVELOPED A\nSCRAPPY PERSONALITY.\nBETTER AT FORAGING!", unlockCondition: .trait(.scrappy)),
    JournalEntry(id: "j_cheerful", title: "CHEERFUL NATURE", text: "GRUB IS ALWAYS HAPPY!\nEARNS BONUS XP\nFROM EVERYTHING.", unlockCondition: .trait(.cheerful)),
    JournalEntry(id: "j_hardy", title: "HARDY NATURE", text: "GRUB IS TOUGH.\nHEALTH LASTS LONGER\nTHAN OTHERS.", unlockCondition: .trait(.hardy)),
    JournalEntry(id: "j_curious", title: "CURIOUS NATURE", text: "GRUB LOVES EXPLORING.\nFINDS RARE ITEMS\nMORE OFTEN.", unlockCondition: .trait(.curious)),
]
