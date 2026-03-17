import Foundation
import PetEngine

final class GrubContent: ContentProvider {

    // MARK: - Ingredient Catalog
    let ingredients: [String: IngredientDef] = {
        let defs: [IngredientDef] = [
            IngredientDef(id: "moss_clump", name: "MOSS CLUMP", rarity: .common, iconName: "mossClump"),
            IngredientDef(id: "cave_beetle", name: "CAVE BEETLE", rarity: .common, iconName: "caveBeetle"),
            IngredientDef(id: "mud_root", name: "MUD ROOT", rarity: .common, iconName: "mudRoot"),
            IngredientDef(id: "dew_drop", name: "DEW DROP", rarity: .common, iconName: "dewDrop"),
            IngredientDef(id: "glowshroom", name: "GLOWSHROOM", rarity: .uncommon, iconName: "glowshroom"),
            IngredientDef(id: "crystal_shard", name: "CRYSTAL SHARD", rarity: .uncommon, iconName: "crystalShard"),
            IngredientDef(id: "pale_worm", name: "PALE WORM", rarity: .uncommon, iconName: "paleWorm"),
            IngredientDef(id: "slime_berry", name: "SLIME BERRY", rarity: .uncommon, iconName: "slimeBerry"),
            IngredientDef(id: "moon_petal", name: "MOON PETAL", rarity: .rare, iconName: "moonPetal"),
            IngredientDef(id: "ember_seed", name: "EMBER SEED", rarity: .rare, iconName: "emberSeed"),
            IngredientDef(id: "ancient_spore", name: "ANCIENT SPORE", rarity: .rare, iconName: "ancientSpore"),
            IngredientDef(id: "golden_bug", name: "GOLDEN BUG", rarity: .rare, iconName: "goldenBug"),
        ]
        return Dictionary(uniqueKeysWithValues: defs.map { ($0.id, $0) })
    }()

    // MARK: - Recipe Catalog
    let recipes: [String: RecipeDef] = {
        let defs: [RecipeDef] = [
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

    // MARK: - Forage Areas
    let forageAreas: [ForageArea] = ForageArea.allCases

    // MARK: - Loot Tables
    let lootTables: [ForageArea: LootTable] = [
        .shallowCave: LootTable(
            commonWeight: 0.70, uncommonWeight: 0.25, rareWeight: 0.05,
            riskChance: 0, riskStatType: "", riskAmount: 0, riskMessage: "",
            itemCount: 2...4, specialPool: nil, excludePool: ["moon_petal", "ember_seed"]),
        .deepBurrow: LootTable(
            commonWeight: 0.30, uncommonWeight: 0.50, rareWeight: 0.20,
            riskChance: 0.20, riskStatType: "happiness", riskAmount: -10,
            riskMessage: "GRUB GOT SPOOKED!",
            itemCount: 2...4, specialPool: ["ember_seed"], excludePool: ["moon_petal"]),
        .surface: LootTable(
            commonWeight: 0.40, uncommonWeight: 0.20, rareWeight: 0.40,
            riskChance: 0.15, riskStatType: "health", riskAmount: -5,
            riskMessage: "GRUB GOT SCRATCHED!",
            itemCount: 2...4, specialPool: nil, excludePool: ["ember_seed"]),
    ]

    // MARK: - Decorations
    let decorations: [String: DecorationDef] = {
        let defs: [DecorationDef] = [
            DecorationDef(id: "moss_bed", name: "MOSS BED",
                ingredients: [.init(id: "moss_clump", quantity: 4), .init(id: "pale_worm", quantity: 1)],
                bonusType: .healthDecay, slot: .floor),
            DecorationDef(id: "berry_rug", name: "BERRY RUG",
                ingredients: [.init(id: "slime_berry", quantity: 3), .init(id: "moss_clump", quantity: 2)],
                bonusType: .happinessDecay, slot: .floor),
            DecorationDef(id: "root_table", name: "ROOT TABLE",
                ingredients: [.init(id: "mud_root", quantity: 4), .init(id: "crystal_shard", quantity: 1)],
                bonusType: .hungerDecay, slot: .floor),
            DecorationDef(id: "crystal_lamp", name: "CRYSTAL LAMP",
                ingredients: [.init(id: "crystal_shard", quantity: 3), .init(id: "dew_drop", quantity: 2)],
                bonusType: .forageLuck, slot: .wall),
            DecorationDef(id: "spore_painting", name: "SPORE PAINTING",
                ingredients: [.init(id: "ancient_spore", quantity: 1), .init(id: "slime_berry", quantity: 2)],
                bonusType: .xpBoost, slot: .wall),
            DecorationDef(id: "beetle_display", name: "BEETLE DISPLAY",
                ingredients: [.init(id: "cave_beetle", quantity: 4), .init(id: "crystal_shard", quantity: 1)],
                bonusType: .eventChance, slot: .wall),
            DecorationDef(id: "glow_mobile", name: "GLOW MOBILE",
                ingredients: [.init(id: "glowshroom", quantity: 3), .init(id: "dew_drop", quantity: 2)],
                bonusType: .passiveGather, slot: .ceiling),
            DecorationDef(id: "moon_chime", name: "MOON CHIME",
                ingredients: [.init(id: "moon_petal", quantity: 2), .init(id: "crystal_shard", quantity: 1)],
                bonusType: .minigameBonus, slot: .ceiling),
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
    let expeditions: [String: ExpeditionDef] = {
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

    var expeditionsSorted: [ExpeditionDef] {
        expeditions.values.sorted { $0.unlockLevel < $1.unlockLevel }
    }

    // MARK: - Journal Entries
    let journalEntries: [JournalEntry] = [
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
        JournalEntry(id: "j_fed10", title: "WELL FED", text: "GRUB HAS EATEN 10\nMEALS. A HEALTHY\nAPPETITE!", unlockCondition: .milestone("fedCount", 10)),
        JournalEntry(id: "j_fed50", title: "GOURMAND", text: "50 MEALS! GRUB HAS\nTRIED EVERYTHING\nTHE CAVE OFFERS.", unlockCondition: .milestone("fedCount", 50)),
        JournalEntry(id: "j_craft10", title: "APPRENTICE CHEF", text: "CRAFTED 10 ITEMS.\nGRUB IS LEARNING\nTO COOK!", unlockCondition: .milestone("itemsCrafted", 10)),
        JournalEntry(id: "j_craft50", title: "MASTER CHEF", text: "50 CRAFTED ITEMS!\nGRUB COULD OPEN\nA RESTAURANT.", unlockCondition: .milestone("itemsCrafted", 50)),
        JournalEntry(id: "j_forage10", title: "EXPLORER", text: "10 FORAGING TRIPS.\nGRUB KNOWS THESE\nTUNNELS WELL.", unlockCondition: .milestone("forageCount", 10)),
        JournalEntry(id: "j_forage50", title: "SPELUNKER", text: "50 TRIPS! GRUB IS\nA MASTER OF THE\nUNDERGROUND.", unlockCondition: .milestone("forageCount", 50)),
        JournalEntry(id: "j_lvl5", title: "GROWING UP", text: "LEVEL 5 REACHED.\nGRUB IS NO LONGER\nA BABY!", unlockCondition: .milestone("ownerLevel", 5)),
        JournalEntry(id: "j_lvl10", title: "VETERAN", text: "LEVEL 10! A TRUE\nCAVE DWELLER.", unlockCondition: .milestone("ownerLevel", 10)),
        JournalEntry(id: "j_wins10", title: "GAME CHAMP", text: "WON 10 MINIGAMES!\nGRUB HAS QUICK\nREFLEXES.", unlockCondition: .milestone("playedCount", 10)),
        JournalEntry(id: "j_scrappy", title: "SCRAPPY NATURE", text: "GRUB DEVELOPED A\nSCRAPPY PERSONALITY.\nBETTER AT FORAGING!", unlockCondition: .trait(.scrappy)),
        JournalEntry(id: "j_cheerful", title: "CHEERFUL NATURE", text: "GRUB IS ALWAYS HAPPY!\nEARNS BONUS XP\nFROM EVERYTHING.", unlockCondition: .trait(.cheerful)),
        JournalEntry(id: "j_hardy", title: "HARDY NATURE", text: "GRUB IS TOUGH.\nHEALTH LASTS LONGER\nTHAN OTHERS.", unlockCondition: .trait(.hardy)),
        JournalEntry(id: "j_curious", title: "CURIOUS NATURE", text: "GRUB LOVES EXPLORING.\nFINDS RARE ITEMS\nMORE OFTEN.", unlockCondition: .trait(.curious)),
    ]

    // MARK: - Evolution Names
    let evolutionNames: [String: String] = [
        "fed_1": "CHUBBY GRUB",
        "played_1": "ATHLETIC GRUB",
        "feral_1": "FERAL GRUB",
        "fed_2": "PUDDING GRUB",
        "played_2": "SPEEDY GRUB",
        "feral_2": "GREMLIN GRUB",
    ]

    // MARK: - XP Thresholds
    let xpThresholds: [Int] = [0, 40, 90, 160, 250, 360, 490, 640, 810, 1000]

    // MARK: - Decay Rates
    let decayRates = DecayRates(
        hungerPerMinute: 1.0 / 10.0,
        happinessPerMinute: 1.0 / 15.0,
        healthPerMinute: 1.0 / 8.0,
        nightMultiplier: 0.5,
        criticalThreshold: 20
    )

    // MARK: - Death Behavior
    let deathBehavior: DeathBehavior = .permanentDeath

    // MARK: - Starter / Scroll Recipe IDs
    let starterRecipeIds: Set<String> = ["moss_gruel", "bug_snack", "mud_paste"]

    lazy var scrollRecipeIds: [String] = {
        recipes.values.filter { $0.unlockType == .scroll }.map(\.id)
    }()

    // MARK: - Ingredient Pools
    lazy var commonIngredients: [String] = {
        ingredients.values.filter { $0.rarity == .common }.map(\.id).sorted()
    }()

    lazy var uncommonIngredients: [String] = {
        ingredients.values.filter { $0.rarity == .uncommon }.map(\.id).sorted()
    }()

    lazy var rareIngredients: [String] = {
        ingredients.values.filter { $0.rarity == .rare }.map(\.id).sorted()
    }()

    // MARK: - Game Events
    lazy var gameEvents: [GameEvent] = {
        [
            // 1 - Shiny find
            GameEvent(
                text: "YOUR GRUB FOUND SOMETHING\nSHINY IN THE DIRT.",
                optionA: EventOption(label: "KEEP IT\n+1 CRYSTAL SHARD", action: { o in let s = o as! GameState; s.addIngredient("crystal_shard") }),
                optionB: EventOption(label: "TOSS IT BACK\n+10 HAPPINESS", action: { o in let s = o as! GameState; s.happiness = min(100, s.happiness + 10) })
            ),
            // 2 - Strange creature
            GameEvent(
                text: "A STRANGE CREATURE\nAPPEARED. GRUB IS NERVOUS.",
                optionA: EventOption(label: "COMFORT\n+1 PALE WORM", action: { o in let s = o as! GameState; s.addIngredient("pale_worm") }),
                optionB: EventOption(label: "PLAY GAME\nTO SCARE IT", action: { o in let s = o as! GameState; s.openRandomGame() })
            ),
            // 3 - Suspicious food
            GameEvent(
                text: "YOUR GRUB ATE SOMETHING\nSUSPICIOUS.",
                optionA: EventOption(label: "SPIT IT OUT\n+1 GLOWSHROOM", action: { o in let s = o as! GameState; s.addIngredient("glowshroom") }),
                optionB: EventOption(label: "SWALLOW\n50/50 RISK", action: { o in
                    let s = o as! GameState
                    if Double.random(in: 0...1) < 0.5 {
                        s.addIngredient("ancient_spore")
                        s.displayToast("+1 ANCIENT SPORE!")
                    } else {
                        s.health = max(5, s.health - 10)
                        s.displayToast("OUCH! -10 HP")
                    }
                })
            ),
            // 4 - Creative mood
            GameEvent(
                text: "GRUB IS IN A CREATIVE\nMOOD TODAY.",
                optionA: EventOption(label: "EXPLORE\n+2 UNCOMMON", action: { [weak self] o in
                    let s = o as! GameState
                    let items = (self?.uncommonIngredients ?? []).shuffled().prefix(2)
                    for item in items { s.addIngredient(item) }
                }),
                optionB: EventOption(label: "REST\n+15 HAPPINESS", action: { o in let s = o as! GameState; s.happiness = min(100, s.happiness + 15) })
            ),
            // 5 - Old scroll
            GameEvent(
                text: "GRUB FOUND AN OLD\nSCROLL IN THE MUD.",
                optionA: EventOption(label: "STUDY IT\nNEW RECIPE?", action: { o in let s = o as! GameState; s.unlockRandomScrollRecipe() }),
                optionB: EventOption(label: "TRADE IT\n+1 RARE", action: { [weak self] o in
                    let s = o as! GameState
                    let rare = (self?.rareIngredients ?? []).filter { $0 != "golden_bug" }.randomElement() ?? "moon_petal"
                    s.addIngredient(rare)
                })
            ),
            // 6 - Rain
            GameEvent(
                text: "RAIN DRIPS THROUGH\nTHE CAVE CEILING.",
                optionA: EventOption(label: "COLLECT DEW\n+3 DEW DROPS", action: { o in let s = o as! GameState; s.addIngredient("dew_drop", count: 3) }),
                optionB: EventOption(label: "TAKE SHELTER\n+10 HAP +5 HP", action: { o in
                    let s = o as! GameState
                    s.happiness = min(100, s.happiness + 10)
                    s.health = min(100, s.health + 5)
                })
            ),
            // 7 - Beetle swarm
            GameEvent(
                text: "A SWARM OF BEETLES\nSCURRIES PAST GRUB.",
                optionA: EventOption(label: "GRAB SOME\n+3 CAVE BEETLES", action: { o in let s = o as! GameState; s.addIngredient("cave_beetle", count: 3) }),
                optionB: EventOption(label: "FOLLOW THEM\n+2 XP", action: { o in let s = o as! GameState; s.addXP(2) })
            ),
            // 8 - Glowing puddle
            GameEvent(
                text: "A PUDDLE GLOWS FAINTLY\nIN THE DARK.",
                optionA: EventOption(label: "DRINK IT\n+20 HP", action: { o in let s = o as! GameState; s.health = min(100, s.health + 20) }),
                optionB: EventOption(label: "BOTTLE IT\n+1 DEW +1 GLOW", action: { o in
                    let s = o as! GameState
                    s.addIngredient("dew_drop")
                    s.addIngredient("glowshroom")
                })
            ),
            // 9 - Tremor
            GameEvent(
                text: "THE CAVE TREMBLES.\nLOOSE ROCKS FALL.",
                optionA: EventOption(label: "DODGE!\n+2 XP", action: { o in
                    let s = o as! GameState
                    s.addXP(2)
                    s.displayToast("NICE DODGE!")
                }),
                optionB: EventOption(label: "DIG THROUGH\n+2 MUD ROOTS", action: { o in
                    let s = o as! GameState
                    s.addIngredient("mud_root", count: 2)
                    s.health = max(5, s.health - 5)
                    s.displayToast("SCRAPED BUT FOUND ROOTS")
                })
            ),
            // 10 - Moss patch
            GameEvent(
                text: "GRUB FOUND A THICK\nPATCH OF CAVE MOSS.",
                optionA: EventOption(label: "HARVEST IT\n+4 MOSS CLUMPS", action: { o in let s = o as! GameState; s.addIngredient("moss_clump", count: 4) }),
                optionB: EventOption(label: "NAPS IN IT\n+15 HAP +10 HP", action: { o in
                    let s = o as! GameState
                    s.happiness = min(100, s.happiness + 15)
                    s.health = min(100, s.health + 10)
                })
            ),
            // 11 - Worm nest
            GameEvent(
                text: "GRUB STUMBLED INTO\nA WORM NEST!",
                optionA: EventOption(label: "GRAB WORMS\n+2 PALE WORMS", action: { o in let s = o as! GameState; s.addIngredient("pale_worm", count: 2) }),
                optionB: EventOption(label: "BACK AWAY\n+5 HAPPINESS", action: { o in let s = o as! GameState; s.happiness = min(100, s.happiness + 5) })
            ),
            // 12 - Ember crack
            GameEvent(
                text: "A CRACK IN THE WALL\nGLOWS WITH HEAT.",
                optionA: EventOption(label: "REACH IN\n+1 EMBER SEED", action: { o in
                    let s = o as! GameState
                    s.addIngredient("ember_seed")
                    s.health = max(5, s.health - 5)
                    s.displayToast("HOT! BUT WORTH IT")
                }),
                optionB: EventOption(label: "WARM UP\n+10 HAP +10 HP", action: { o in
                    let s = o as! GameState
                    s.happiness = min(100, s.happiness + 10)
                    s.health = min(100, s.health + 10)
                })
            ),
            // 13 - Mushroom ring
            GameEvent(
                text: "GLOWING MUSHROOMS FORM\nA PERFECT RING.",
                optionA: EventOption(label: "PICK THEM\n+2 GLOWSHROOMS", action: { o in let s = o as! GameState; s.addIngredient("glowshroom", count: 2) }),
                optionB: EventOption(label: "SIT INSIDE\nENERGIZED 30M", action: { o in
                    let s = o as! GameState
                    s.applyEnergized()
                    s.displayToast("ENERGIZED!")
                })
            ),
            // 14 - Berry bush
            GameEvent(
                text: "A BUSH OF STRANGE\nBERRIES GROWS HERE.",
                optionA: EventOption(label: "EAT THEM\n+20 HUNGER", action: { o in
                    let s = o as! GameState
                    s.hunger = min(100, s.hunger + 20)
                    s.fedCount += 1
                }),
                optionB: EventOption(label: "COLLECT\n+2 SLIME BERRIES", action: { o in let s = o as! GameState; s.addIngredient("slime_berry", count: 2) })
            ),
            // 15 - Golden glint
            GameEvent(
                text: "SOMETHING GOLD SCUTTLES\nBEHIND A ROCK.",
                optionA: EventOption(label: "CHASE IT\n70% GOLDEN BUG", action: { o in
                    let s = o as! GameState
                    if Double.random(in: 0...1) < 0.7 {
                        s.addIngredient("golden_bug")
                        s.displayToast("CAUGHT IT!")
                    } else {
                        s.displayToast("IT GOT AWAY...")
                    }
                }),
                optionB: EventOption(label: "LET IT GO\n+3 XP", action: { o in let s = o as! GameState; s.addXP(3) })
            ),
            // 16 - Moon light
            GameEvent(
                text: "MOONLIGHT FILTERS DOWN\nTHROUGH A CRACK ABOVE.",
                optionA: EventOption(label: "BASK IN IT\n+1 MOON PETAL", action: { o in let s = o as! GameState; s.addIngredient("moon_petal") }),
                optionB: EventOption(label: "MEDITATE\n+20 HAPPINESS", action: { o in let s = o as! GameState; s.happiness = min(100, s.happiness + 20) })
            ),
            // 17 - Old stash
            GameEvent(
                text: "GRUB FOUND SOMEONE'S\nOLD INGREDIENT STASH.",
                optionA: EventOption(label: "TAKE ALL\n+1 OF 3 RANDOM", action: { [weak self] o in
                    let s = o as! GameState
                    let all = Array((self?.ingredients.keys ?? [:].keys)).shuffled().prefix(3)
                    for item in all { s.addIngredient(item) }
                }),
                optionB: EventOption(label: "JUST THE BEST\n+1 RARE", action: { [weak self] o in
                    let s = o as! GameState
                    let pool = (self?.rareIngredients ?? []).filter { $0 != "golden_bug" }
                    s.addIngredient(pool.randomElement()!)
                })
            ),
            // 18 - Spore cloud
            GameEvent(
                text: "A PUFF OF ANCIENT\nSPORES FILLS THE AIR.",
                optionA: EventOption(label: "BREATHE IN\n+1 ANCIENT SPORE", action: { o in
                    let s = o as! GameState
                    s.addIngredient("ancient_spore")
                    if Double.random(in: 0...1) < 0.3 {
                        s.health = max(5, s.health - 5)
                        s.displayToast("*COUGH* BUT GOT SPORE")
                    }
                }),
                optionB: EventOption(label: "HOLD BREATH\n+5 HP", action: { o in let s = o as! GameState; s.health = min(100, s.health + 5) })
            ),
            // 19 - Crystal cave
            GameEvent(
                text: "GRUB WANDERED INTO A\nCRYSTAL-LINED CAVERN.",
                optionA: EventOption(label: "MINE CRYSTALS\n+2 CRYSTAL SHARD", action: { o in let s = o as! GameState; s.addIngredient("crystal_shard", count: 2) }),
                optionB: EventOption(label: "ADMIRE THEM\n+15 HAP +2 XP", action: { o in
                    let s = o as! GameState
                    s.happiness = min(100, s.happiness + 15)
                    s.addXP(2)
                })
            ),
            // 20 - Friendly grub
            GameEvent(
                text: "ANOTHER GRUB APPEARED!\nIT LOOKS FRIENDLY.",
                optionA: EventOption(label: "PLAY TOGETHER\n+20 HAPPINESS", action: { o in
                    let s = o as! GameState
                    s.happiness = min(100, s.happiness + 20)
                    s.addXP(1)
                }),
                optionB: EventOption(label: "TRADE ITEMS\n+2 UNCOMMON", action: { [weak self] o in
                    let s = o as! GameState
                    let items = (self?.uncommonIngredients ?? []).shuffled().prefix(2)
                    for item in items { s.addIngredient(item) }
                })
            ),
            // 21 - Hungry rumble
            GameEvent(
                text: "GRUB'S STOMACH\nRUMBLES LOUDLY.",
                optionA: EventOption(label: "SCROUNGE\n+2 MOSS +1 ROOT", action: { o in
                    let s = o as! GameState
                    s.addIngredient("moss_clump", count: 2)
                    s.addIngredient("mud_root")
                }),
                optionB: EventOption(label: "IGNORE IT\n+5 XP", action: { o in let s = o as! GameState; s.addXP(5) })
            ),
            // 22 - Underground stream
            GameEvent(
                text: "AN UNDERGROUND STREAM\nBUBBLES NEARBY.",
                optionA: EventOption(label: "DRINK\n+15 HP +10 HNG", action: { o in
                    let s = o as! GameState
                    s.health = min(100, s.health + 15)
                    s.hunger = min(100, s.hunger + 10)
                }),
                optionB: EventOption(label: "FISH IN IT\n+1 PALE WORM +1 DEW", action: { o in
                    let s = o as! GameState
                    s.addIngredient("pale_worm")
                    s.addIngredient("dew_drop")
                })
            ),
            // 23 - Cave painting
            GameEvent(
                text: "GRUB FOUND ANCIENT\nCAVE PAINTINGS.",
                optionA: EventOption(label: "STUDY THEM\nNEW RECIPE?", action: { o in let s = o as! GameState; s.unlockRandomScrollRecipe() }),
                optionB: EventOption(label: "COPY THEM\n+3 XP", action: { o in let s = o as! GameState; s.addXP(3) })
            ),
            // 24 - Echo chamber
            GameEvent(
                text: "THIS CHAMBER ECHOES\nWITH STRANGE SOUNDS.",
                optionA: EventOption(label: "SHOUT!\n+10 HAPPINESS", action: { o in
                    let s = o as! GameState
                    s.happiness = min(100, s.happiness + 10)
                    s.displayToast("ECHOOO!")
                }),
                optionB: EventOption(label: "LISTEN\n+2 XP", action: { o in
                    let s = o as! GameState
                    s.addXP(2)
                    s.displayToast("GRUB LEARNED SOMETHING")
                })
            ),
            // 25 - Rotting log
            GameEvent(
                text: "A ROTTING LOG BLOCKS\nTHE PATH AHEAD.",
                optionA: EventOption(label: "BREAK IT\n+3 CAVE BEETLES", action: { o in let s = o as! GameState; s.addIngredient("cave_beetle", count: 3) }),
                optionB: EventOption(label: "CLIMB OVER\n+1 XP +1 MOSS", action: { o in
                    let s = o as! GameState
                    s.addXP(1)
                    s.addIngredient("moss_clump")
                })
            ),
            // 26 - Dripping stalactite
            GameEvent(
                text: "A STALACTITE DRIPS\nWITH MINERAL WATER.",
                optionA: EventOption(label: "COLLECT\n+2 DEW DROPS", action: { o in let s = o as! GameState; s.addIngredient("dew_drop", count: 2) }),
                optionB: EventOption(label: "LICK IT\n+10 HP", action: { o in
                    let s = o as! GameState
                    s.health = min(100, s.health + 10)
                    s.displayToast("MINERAL-Y!")
                })
            ),
            // 27 - Sleepy grub
            GameEvent(
                text: "GRUB IS FEELING\nVERY SLEEPY...",
                optionA: EventOption(label: "TAKE A NAP\n+20 HP +10 HAP", action: { o in
                    let s = o as! GameState
                    s.health = min(100, s.health + 20)
                    s.happiness = min(100, s.happiness + 10)
                }),
                optionB: EventOption(label: "POWER THROUGH\n+3 XP", action: { o in let s = o as! GameState; s.addXP(3) })
            ),
            // 28 - Treasure chest
            GameEvent(
                text: "A TINY CHEST SITS\nHALF-BURIED IN DIRT.",
                optionA: EventOption(label: "OPEN IT\n3 RANDOM ITEMS", action: { [weak self] o in
                    let s = o as! GameState
                    let pool = (self?.commonIngredients ?? []) + (self?.uncommonIngredients ?? [])
                    for _ in 0..<3 { s.addIngredient(pool.randomElement()!) }
                }),
                optionB: EventOption(label: "TRAP? LEAVE IT\n+5 HAP SAFE", action: { o in let s = o as! GameState; s.happiness = min(100, s.happiness + 5) })
            ),
            // 29 - Slime trail
            GameEvent(
                text: "A TRAIL OF SLIME\nLEADS DEEPER INTO CAVE.",
                optionA: EventOption(label: "FOLLOW IT\n+2 SLIME BERRIES", action: { o in let s = o as! GameState; s.addIngredient("slime_berry", count: 2) }),
                optionB: EventOption(label: "TASTE IT\n50/50 +20HNG/-5HP", action: { o in
                    let s = o as! GameState
                    if Double.random(in: 0...1) < 0.5 {
                        s.hunger = min(100, s.hunger + 20)
                        s.displayToast("SURPRISINGLY TASTY!")
                    } else {
                        s.health = max(5, s.health - 5)
                        s.displayToast("BAD IDEA...")
                    }
                })
            ),
            // 30 - Old recipe book
            GameEvent(
                text: "A TATTERED RECIPE BOOK\nLIES ON A LEDGE.",
                optionA: EventOption(label: "READ IT\nNEW RECIPE?", action: { o in let s = o as! GameState; s.unlockRandomScrollRecipe() }),
                optionB: EventOption(label: "USE AS FUEL\n+1 EMBER SEED", action: { o in let s = o as! GameState; s.addIngredient("ember_seed") })
            ),
            // 31 - Mineral vein
            GameEvent(
                text: "A VEIN OF MINERALS\nSPARKLES IN THE WALL.",
                optionA: EventOption(label: "MINE IT\n+1 CRYSTAL +1 EMBER", action: { o in
                    let s = o as! GameState
                    s.addIngredient("crystal_shard")
                    s.addIngredient("ember_seed")
                }),
                optionB: EventOption(label: "MARK LOCATION\n+4 XP", action: { o in let s = o as! GameState; s.addXP(4) })
            ),
            // 32 - Wind gust
            GameEvent(
                text: "A GUST OF WIND BLOWS\nTHROUGH THE TUNNEL.",
                optionA: EventOption(label: "CHASE DEBRIS\n+2 MOSS +1 DEW", action: { o in
                    let s = o as! GameState
                    s.addIngredient("moss_clump", count: 2)
                    s.addIngredient("dew_drop")
                }),
                optionB: EventOption(label: "ENJOY BREEZE\n+10 HAP", action: { o in let s = o as! GameState; s.happiness = min(100, s.happiness + 10) })
            ),
            // 33 - Petal drift
            GameEvent(
                text: "GLOWING PETALS DRIFT\nDOWN FROM ABOVE.",
                optionA: EventOption(label: "CATCH THEM\n+1 MOON PETAL", action: { o in let s = o as! GameState; s.addIngredient("moon_petal") }),
                optionB: EventOption(label: "MAKE A WISH\n+2 XP +5 HAP", action: { o in
                    let s = o as! GameState
                    s.addXP(2)
                    s.happiness = min(100, s.happiness + 5)
                })
            ),
            // 34 - Burrow challenge
            GameEvent(
                text: "A NARROW TUNNEL LEADS\nTO AN UNKNOWN AREA.",
                optionA: EventOption(label: "SQUEEZE IN\n+1 RARE ITEM", action: { [weak self] o in
                    let s = o as! GameState
                    s.addIngredient((self?.rareIngredients ?? []).randomElement()!)
                    s.health = max(5, s.health - 3)
                }),
                optionB: EventOption(label: "DIG WIDER\n+2 MUD ROOTS", action: { o in let s = o as! GameState; s.addIngredient("mud_root", count: 2) })
            ),
            // 35 - Minigame challenge
            GameEvent(
                text: "GRUB WANTS TO\nPROVE ITS SKILLS!",
                optionA: EventOption(label: "ACCEPT\nPLAY GAME!", action: { o in
                    let s = o as! GameState
                    s.openRandomGame()
                    s.addXP(1)
                }),
                optionB: EventOption(label: "MAYBE LATER\n+5 HAP", action: { o in let s = o as! GameState; s.happiness = min(100, s.happiness + 5) })
            ),
            // 36 - Ingredient feast
            GameEvent(
                text: "A PILE OF INGREDIENTS\nSPILLED FROM A CRACK.",
                optionA: EventOption(label: "GRAB COMMONS\n+3 RANDOM COMMON", action: { [weak self] o in
                    let s = o as! GameState
                    for _ in 0..<3 { s.addIngredient((self?.commonIngredients ?? []).randomElement()!) }
                }),
                optionB: EventOption(label: "DIG DEEPER\n+2 RANDOM UNCOMMON", action: { [weak self] o in
                    let s = o as! GameState
                    for _ in 0..<2 { s.addIngredient((self?.uncommonIngredients ?? []).randomElement()!) }
                })
            ),
            // 37 - Energized spring
            GameEvent(
                text: "A BUBBLING SPRING HUMS\nWITH ENERGY.",
                optionA: EventOption(label: "DRINK DEEP\nENERGIZED 30M", action: { o in
                    let s = o as! GameState
                    s.applyEnergized()
                    s.health = min(100, s.health + 10)
                }),
                optionB: EventOption(label: "FILL BOTTLES\n+3 DEW DROPS", action: { o in let s = o as! GameState; s.addIngredient("dew_drop", count: 3) })
            ),
            // 38 - Spider web
            GameEvent(
                text: "GRUB WALKED INTO\nA GIANT SPIDER WEB!",
                optionA: EventOption(label: "STRUGGLE FREE\n-5 HP +1 XP", action: { o in
                    let s = o as! GameState
                    s.health = max(5, s.health - 5)
                    s.addXP(1)
                }),
                optionB: EventOption(label: "CHECK WEB\n+1 GOLDEN BUG?", action: { o in
                    let s = o as! GameState
                    if Double.random(in: 0...1) < 0.4 {
                        s.addIngredient("golden_bug")
                        s.displayToast("FOUND ONE TRAPPED!")
                    } else {
                        s.addIngredient("cave_beetle")
                        s.displayToast("JUST A BEETLE...")
                    }
                })
            ),
            // 39 - Full belly
            GameEvent(
                text: "GRUB BURPS CONTENTEDLY\nAFTER A BIG MEAL.",
                optionA: EventOption(label: "FOOD COMA\n+20 HAP +10 HP", action: { o in
                    let s = o as! GameState
                    s.happiness = min(100, s.happiness + 20)
                    s.health = min(100, s.health + 10)
                }),
                optionB: EventOption(label: "GO EXPLORING\n+2 RANDOM ITEMS", action: { [weak self] o in
                    let s = o as! GameState
                    let pool = (self?.commonIngredients ?? []) + (self?.uncommonIngredients ?? [])
                    for _ in 0..<2 { s.addIngredient(pool.randomElement()!) }
                })
            ),
            // 40 - Mysterious merchant
            GameEvent(
                text: "A HOODED FIGURE OFFERS\nGRUB A TRADE.",
                optionA: EventOption(label: "TRADE 5 HP\n+1 ANCIENT SPORE", action: { o in
                    let s = o as! GameState
                    s.health = max(5, s.health - 5)
                    s.addIngredient("ancient_spore")
                }),
                optionB: EventOption(label: "DECLINE\n+10 HAP (WISE)", action: { o in
                    let s = o as! GameState
                    s.happiness = min(100, s.happiness + 10)
                    s.displayToast("PROBABLY FOR THE BEST")
                })
            ),
        ]
    }()
}
