import Foundation
import Combine

// MARK: - Decay Constants
struct DecayConstants {
    static let hungerPerMin: Double = 1.0 / 10.0
    static let happinessPerMin: Double = 1.0 / 15.0
    static let healthPerMin: Double = 1.0 / 8.0
    static let nightMult: Double = 0.5
    static let critThresh: Double = 20
}

// MARK: - XP Thresholds
let xpThresholds = [0, 40, 90, 160, 250, 360, 490, 640, 810, 1000]

// MARK: - Evolution Names
let evoNames: [String: String] = [
    "fed_1": "CHUBBY GRUB",
    "played_1": "ATHLETIC GRUB",
    "feral_1": "FERAL GRUB",
    "fed_2": "PUDDING GRUB",
    "played_2": "SPEEDY GRUB",
    "feral_2": "GREMLIN GRUB",
]

// MARK: - Event
struct GameEvent {
    let text: String
    let optionA: EventOption
    let optionB: EventOption
}

struct EventOption {
    let label: String
    let action: (GameState) -> Void
}

let gameEvents: [GameEvent] = [
    // 1 — Shiny find
    GameEvent(
        text: "YOUR GRUB FOUND SOMETHING\nSHINY IN THE DIRT.",
        optionA: EventOption(label: "KEEP IT\n+1 CRYSTAL SHARD", action: { s in s.addIngredient("crystal_shard") }),
        optionB: EventOption(label: "TOSS IT BACK\n+10 HAPPINESS", action: { s in s.happiness = min(100, s.happiness + 10) })
    ),
    // 2 — Strange creature
    GameEvent(
        text: "A STRANGE CREATURE\nAPPEARED. GRUB IS NERVOUS.",
        optionA: EventOption(label: "COMFORT\n+1 PALE WORM", action: { s in s.addIngredient("pale_worm") }),
        optionB: EventOption(label: "PLAY GAME\nTO SCARE IT", action: { s in s.showMinigame = true })
    ),
    // 3 — Suspicious food
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
    // 4 — Creative mood
    GameEvent(
        text: "GRUB IS IN A CREATIVE\nMOOD TODAY.",
        optionA: EventOption(label: "EXPLORE\n+2 UNCOMMON", action: { s in
            let items = uncommonIngredients.shuffled().prefix(2)
            for item in items { s.addIngredient(item) }
        }),
        optionB: EventOption(label: "REST\n+15 HAPPINESS", action: { s in s.happiness = min(100, s.happiness + 15) })
    ),
    // 5 — Old scroll
    GameEvent(
        text: "GRUB FOUND AN OLD\nSCROLL IN THE MUD.",
        optionA: EventOption(label: "STUDY IT\nNEW RECIPE?", action: { s in s.unlockRandomScrollRecipe() }),
        optionB: EventOption(label: "TRADE IT\n+1 RARE", action: { s in
            let rare = rareIngredients.filter { $0 != "golden_bug" }.randomElement() ?? "moon_petal"
            s.addIngredient(rare)
        })
    ),
    // 6 — Rain
    GameEvent(
        text: "RAIN DRIPS THROUGH\nTHE CAVE CEILING.",
        optionA: EventOption(label: "COLLECT DEW\n+3 DEW DROPS", action: { s in s.addIngredient("dew_drop", count: 3) }),
        optionB: EventOption(label: "TAKE SHELTER\n+10 HAP +5 HP", action: { s in
            s.happiness = min(100, s.happiness + 10)
            s.health = min(100, s.health + 5)
        })
    ),
    // 7 — Beetle swarm
    GameEvent(
        text: "A SWARM OF BEETLES\nSCURRIES PAST GRUB.",
        optionA: EventOption(label: "GRAB SOME\n+3 CAVE BEETLES", action: { s in s.addIngredient("cave_beetle", count: 3) }),
        optionB: EventOption(label: "FOLLOW THEM\n+2 XP", action: { s in s.addXP(2) })
    ),
    // 8 — Glowing puddle
    GameEvent(
        text: "A PUDDLE GLOWS FAINTLY\nIN THE DARK.",
        optionA: EventOption(label: "DRINK IT\n+20 HP", action: { s in s.health = min(100, s.health + 20) }),
        optionB: EventOption(label: "BOTTLE IT\n+1 DEW +1 GLOW", action: { s in
            s.addIngredient("dew_drop")
            s.addIngredient("glowshroom")
        })
    ),
    // 9 — Tremor
    GameEvent(
        text: "THE CAVE TREMBLES.\nLOOSE ROCKS FALL.",
        optionA: EventOption(label: "DODGE!\n+2 XP", action: { s in
            s.addXP(2)
            s.displayToast("NICE DODGE!")
        }),
        optionB: EventOption(label: "DIG THROUGH\n+2 MUD ROOTS", action: { s in
            s.addIngredient("mud_root", count: 2)
            s.health = max(5, s.health - 5)
            s.displayToast("SCRAPED BUT FOUND ROOTS")
        })
    ),
    // 10 — Moss patch
    GameEvent(
        text: "GRUB FOUND A THICK\nPATCH OF CAVE MOSS.",
        optionA: EventOption(label: "HARVEST IT\n+4 MOSS CLUMPS", action: { s in s.addIngredient("moss_clump", count: 4) }),
        optionB: EventOption(label: "NAPS IN IT\n+15 HAP +10 HP", action: { s in
            s.happiness = min(100, s.happiness + 15)
            s.health = min(100, s.health + 10)
        })
    ),
    // 11 — Worm nest
    GameEvent(
        text: "GRUB STUMBLED INTO\nA WORM NEST!",
        optionA: EventOption(label: "GRAB WORMS\n+2 PALE WORMS", action: { s in s.addIngredient("pale_worm", count: 2) }),
        optionB: EventOption(label: "BACK AWAY\n+5 HAPPINESS", action: { s in s.happiness = min(100, s.happiness + 5) })
    ),
    // 12 — Ember crack
    GameEvent(
        text: "A CRACK IN THE WALL\nGLOWS WITH HEAT.",
        optionA: EventOption(label: "REACH IN\n+1 EMBER SEED", action: { s in
            s.addIngredient("ember_seed")
            s.health = max(5, s.health - 5)
            s.displayToast("HOT! BUT WORTH IT")
        }),
        optionB: EventOption(label: "WARM UP\n+10 HAP +10 HP", action: { s in
            s.happiness = min(100, s.happiness + 10)
            s.health = min(100, s.health + 10)
        })
    ),
    // 13 — Mushroom ring
    GameEvent(
        text: "GLOWING MUSHROOMS FORM\nA PERFECT RING.",
        optionA: EventOption(label: "PICK THEM\n+2 GLOWSHROOMS", action: { s in s.addIngredient("glowshroom", count: 2) }),
        optionB: EventOption(label: "SIT INSIDE\nENERGIZED 30M", action: { s in
            let expiry = Date().addingTimeInterval(1800)
            s.activeEffects.append(ActiveEffect(type: .energized, expiresAt: expiry))
            s.displayToast("ENERGIZED!")
        })
    ),
    // 14 — Berry bush
    GameEvent(
        text: "A BUSH OF STRANGE\nBERRIES GROWS HERE.",
        optionA: EventOption(label: "EAT THEM\n+20 HUNGER", action: { s in
            s.hunger = min(100, s.hunger + 20)
            s.fedCount += 1
        }),
        optionB: EventOption(label: "COLLECT\n+2 SLIME BERRIES", action: { s in s.addIngredient("slime_berry", count: 2) })
    ),
    // 15 — Golden glint
    GameEvent(
        text: "SOMETHING GOLD SCUTTLES\nBEHIND A ROCK.",
        optionA: EventOption(label: "CHASE IT\n70% GOLDEN BUG", action: { s in
            if Double.random(in: 0...1) < 0.7 {
                s.addIngredient("golden_bug")
                s.displayToast("CAUGHT IT!")
            } else {
                s.displayToast("IT GOT AWAY...")
            }
        }),
        optionB: EventOption(label: "LET IT GO\n+3 XP", action: { s in s.addXP(3) })
    ),
    // 16 — Moon light
    GameEvent(
        text: "MOONLIGHT FILTERS DOWN\nTHROUGH A CRACK ABOVE.",
        optionA: EventOption(label: "BASK IN IT\n+1 MOON PETAL", action: { s in s.addIngredient("moon_petal") }),
        optionB: EventOption(label: "MEDITATE\n+20 HAPPINESS", action: { s in s.happiness = min(100, s.happiness + 20) })
    ),
    // 17 — Old stash
    GameEvent(
        text: "GRUB FOUND SOMEONE'S\nOLD INGREDIENT STASH.",
        optionA: EventOption(label: "TAKE ALL\n+1 OF 3 RANDOM", action: { s in
            let all = Array(ingredientCatalog.keys).shuffled().prefix(3)
            for item in all { s.addIngredient(item) }
        }),
        optionB: EventOption(label: "JUST THE BEST\n+1 RARE", action: { s in
            s.addIngredient(rareIngredients.randomElement()!)
        })
    ),
    // 18 — Spore cloud
    GameEvent(
        text: "A PUFF OF ANCIENT\nSPORES FILLS THE AIR.",
        optionA: EventOption(label: "BREATHE IN\n+1 ANCIENT SPORE", action: { s in
            s.addIngredient("ancient_spore")
            if Double.random(in: 0...1) < 0.3 {
                s.health = max(5, s.health - 5)
                s.displayToast("*COUGH* BUT GOT SPORE")
            }
        }),
        optionB: EventOption(label: "HOLD BREATH\n+5 HP", action: { s in s.health = min(100, s.health + 5) })
    ),
    // 19 — Crystal cave
    GameEvent(
        text: "GRUB WANDERED INTO A\nCRYSTAL-LINED CAVERN.",
        optionA: EventOption(label: "MINE CRYSTALS\n+2 CRYSTAL SHARD", action: { s in s.addIngredient("crystal_shard", count: 2) }),
        optionB: EventOption(label: "ADMIRE THEM\n+15 HAP +2 XP", action: { s in
            s.happiness = min(100, s.happiness + 15)
            s.addXP(2)
        })
    ),
    // 20 — Friendly grub
    GameEvent(
        text: "ANOTHER GRUB APPEARED!\nIT LOOKS FRIENDLY.",
        optionA: EventOption(label: "PLAY TOGETHER\n+20 HAPPINESS", action: { s in
            s.happiness = min(100, s.happiness + 20)
            s.addXP(1)
        }),
        optionB: EventOption(label: "TRADE ITEMS\n+2 UNCOMMON", action: { s in
            let items = uncommonIngredients.shuffled().prefix(2)
            for item in items { s.addIngredient(item) }
        })
    ),
    // 21 — Hungry rumble
    GameEvent(
        text: "GRUB'S STOMACH\nRUMBLES LOUDLY.",
        optionA: EventOption(label: "SCROUNGE\n+2 MOSS +1 ROOT", action: { s in
            s.addIngredient("moss_clump", count: 2)
            s.addIngredient("mud_root")
        }),
        optionB: EventOption(label: "IGNORE IT\n+5 XP", action: { s in s.addXP(5) })
    ),
    // 22 — Underground stream
    GameEvent(
        text: "AN UNDERGROUND STREAM\nBUBBLES NEARBY.",
        optionA: EventOption(label: "DRINK\n+15 HP +10 HNG", action: { s in
            s.health = min(100, s.health + 15)
            s.hunger = min(100, s.hunger + 10)
        }),
        optionB: EventOption(label: "FISH IN IT\n+1 PALE WORM +1 DEW", action: { s in
            s.addIngredient("pale_worm")
            s.addIngredient("dew_drop")
        })
    ),
    // 23 — Cave painting
    GameEvent(
        text: "GRUB FOUND ANCIENT\nCAVE PAINTINGS.",
        optionA: EventOption(label: "STUDY THEM\nNEW RECIPE?", action: { s in s.unlockRandomScrollRecipe() }),
        optionB: EventOption(label: "COPY THEM\n+3 XP", action: { s in s.addXP(3) })
    ),
    // 24 — Echo chamber
    GameEvent(
        text: "THIS CHAMBER ECHOES\nWITH STRANGE SOUNDS.",
        optionA: EventOption(label: "SHOUT!\n+10 HAPPINESS", action: { s in
            s.happiness = min(100, s.happiness + 10)
            s.displayToast("ECHOOO!")
        }),
        optionB: EventOption(label: "LISTEN\n+2 XP", action: { s in
            s.addXP(2)
            s.displayToast("GRUB LEARNED SOMETHING")
        })
    ),
    // 25 — Rotting log
    GameEvent(
        text: "A ROTTING LOG BLOCKS\nTHE PATH AHEAD.",
        optionA: EventOption(label: "BREAK IT\n+3 CAVE BEETLES", action: { s in s.addIngredient("cave_beetle", count: 3) }),
        optionB: EventOption(label: "CLIMB OVER\n+1 XP +1 MOSS", action: { s in
            s.addXP(1)
            s.addIngredient("moss_clump")
        })
    ),
    // 26 — Dripping stalactite
    GameEvent(
        text: "A STALACTITE DRIPS\nWITH MINERAL WATER.",
        optionA: EventOption(label: "COLLECT\n+2 DEW DROPS", action: { s in s.addIngredient("dew_drop", count: 2) }),
        optionB: EventOption(label: "LICK IT\n+10 HP", action: { s in
            s.health = min(100, s.health + 10)
            s.displayToast("MINERAL-Y!")
        })
    ),
    // 27 — Sleepy grub
    GameEvent(
        text: "GRUB IS FEELING\nVERY SLEEPY...",
        optionA: EventOption(label: "TAKE A NAP\n+20 HP +10 HAP", action: { s in
            s.health = min(100, s.health + 20)
            s.happiness = min(100, s.happiness + 10)
        }),
        optionB: EventOption(label: "POWER THROUGH\n+3 XP", action: { s in s.addXP(3) })
    ),
    // 28 — Treasure chest
    GameEvent(
        text: "A TINY CHEST SITS\nHALF-BURIED IN DIRT.",
        optionA: EventOption(label: "OPEN IT\n3 RANDOM ITEMS", action: { s in
            for _ in 0..<3 {
                let pool = commonIngredients + uncommonIngredients
                s.addIngredient(pool.randomElement()!)
            }
        }),
        optionB: EventOption(label: "TRAP? LEAVE IT\n+5 HAP SAFE", action: { s in s.happiness = min(100, s.happiness + 5) })
    ),
    // 29 — Slime trail
    GameEvent(
        text: "A TRAIL OF SLIME\nLEADS DEEPER INTO CAVE.",
        optionA: EventOption(label: "FOLLOW IT\n+2 SLIME BERRIES", action: { s in s.addIngredient("slime_berry", count: 2) }),
        optionB: EventOption(label: "TASTE IT\n50/50 +20HNG/-5HP", action: { s in
            if Double.random(in: 0...1) < 0.5 {
                s.hunger = min(100, s.hunger + 20)
                s.displayToast("SURPRISINGLY TASTY!")
            } else {
                s.health = max(5, s.health - 5)
                s.displayToast("BAD IDEA...")
            }
        })
    ),
    // 30 — Old recipe book
    GameEvent(
        text: "A TATTERED RECIPE BOOK\nLIES ON A LEDGE.",
        optionA: EventOption(label: "READ IT\nNEW RECIPE?", action: { s in s.unlockRandomScrollRecipe() }),
        optionB: EventOption(label: "USE AS FUEL\n+1 EMBER SEED", action: { s in s.addIngredient("ember_seed") })
    ),
    // 31 — Mineral vein
    GameEvent(
        text: "A VEIN OF MINERALS\nSPARKLES IN THE WALL.",
        optionA: EventOption(label: "MINE IT\n+1 CRYSTAL +1 EMBER", action: { s in
            s.addIngredient("crystal_shard")
            s.addIngredient("ember_seed")
        }),
        optionB: EventOption(label: "MARK LOCATION\n+4 XP", action: { s in s.addXP(4) })
    ),
    // 32 — Wind gust
    GameEvent(
        text: "A GUST OF WIND BLOWS\nTHROUGH THE TUNNEL.",
        optionA: EventOption(label: "CHASE DEBRIS\n+2 MOSS +1 DEW", action: { s in
            s.addIngredient("moss_clump", count: 2)
            s.addIngredient("dew_drop")
        }),
        optionB: EventOption(label: "ENJOY BREEZE\n+10 HAP", action: { s in s.happiness = min(100, s.happiness + 10) })
    ),
    // 33 — Petal drift
    GameEvent(
        text: "GLOWING PETALS DRIFT\nDOWN FROM ABOVE.",
        optionA: EventOption(label: "CATCH THEM\n+1 MOON PETAL", action: { s in s.addIngredient("moon_petal") }),
        optionB: EventOption(label: "MAKE A WISH\n+2 XP +5 HAP", action: { s in
            s.addXP(2)
            s.happiness = min(100, s.happiness + 5)
        })
    ),
    // 34 — Burrow challenge
    GameEvent(
        text: "A NARROW TUNNEL LEADS\nTO AN UNKNOWN AREA.",
        optionA: EventOption(label: "SQUEEZE IN\n+1 RARE ITEM", action: { s in
            s.addIngredient(rareIngredients.randomElement()!)
            s.health = max(5, s.health - 3)
        }),
        optionB: EventOption(label: "DIG WIDER\n+2 MUD ROOTS", action: { s in s.addIngredient("mud_root", count: 2) })
    ),
    // 35 — Minigame challenge
    GameEvent(
        text: "GRUB WANTS TO\nPROVE ITS SKILLS!",
        optionA: EventOption(label: "ACCEPT\nPLAY GAME!", action: { s in
            s.showMinigame = true
            s.addXP(1)
        }),
        optionB: EventOption(label: "MAYBE LATER\n+5 HAP", action: { s in s.happiness = min(100, s.happiness + 5) })
    ),
    // 36 — Ingredient feast
    GameEvent(
        text: "A PILE OF INGREDIENTS\nSPILLED FROM A CRACK.",
        optionA: EventOption(label: "GRAB COMMONS\n+2 OF EACH", action: { s in
            for id in commonIngredients { s.addIngredient(id, count: 2) }
        }),
        optionB: EventOption(label: "DIG DEEPER\n+1 UNCOMMON EACH", action: { s in
            for id in uncommonIngredients { s.addIngredient(id) }
        })
    ),
    // 37 — Energized spring
    GameEvent(
        text: "A BUBBLING SPRING HUMS\nWITH ENERGY.",
        optionA: EventOption(label: "DRINK DEEP\nENERGIZED 30M", action: { s in
            let expiry = Date().addingTimeInterval(1800)
            s.activeEffects.append(ActiveEffect(type: .energized, expiresAt: expiry))
            s.health = min(100, s.health + 10)
        }),
        optionB: EventOption(label: "FILL BOTTLES\n+3 DEW DROPS", action: { s in s.addIngredient("dew_drop", count: 3) })
    ),
    // 38 — Spider web
    GameEvent(
        text: "GRUB WALKED INTO\nA GIANT SPIDER WEB!",
        optionA: EventOption(label: "STRUGGLE FREE\n-5 HP +1 XP", action: { s in
            s.health = max(5, s.health - 5)
            s.addXP(1)
        }),
        optionB: EventOption(label: "CHECK WEB\n+1 GOLDEN BUG?", action: { s in
            if Double.random(in: 0...1) < 0.4 {
                s.addIngredient("golden_bug")
                s.displayToast("FOUND ONE TRAPPED!")
            } else {
                s.addIngredient("cave_beetle")
                s.displayToast("JUST A BEETLE...")
            }
        })
    ),
    // 39 — Full belly
    GameEvent(
        text: "GRUB BURPS CONTENTEDLY\nAFTER A BIG MEAL.",
        optionA: EventOption(label: "FOOD COMA\n+20 HAP +10 HP", action: { s in
            s.happiness = min(100, s.happiness + 20)
            s.health = min(100, s.health + 10)
        }),
        optionB: EventOption(label: "GO EXPLORING\n+2 RANDOM ITEMS", action: { s in
            let pool = commonIngredients + uncommonIngredients
            for _ in 0..<2 { s.addIngredient(pool.randomElement()!) }
        })
    ),
    // 40 — Mysterious merchant
    GameEvent(
        text: "A HOODED FIGURE OFFERS\nGRUB A TRADE.",
        optionA: EventOption(label: "TRADE 5 HP\n+1 ANCIENT SPORE", action: { s in
            s.health = max(5, s.health - 5)
            s.addIngredient("ancient_spore")
        }),
        optionB: EventOption(label: "DECLINE\n+10 HAP (WISE)", action: { s in
            s.happiness = min(100, s.happiness + 10)
            s.displayToast("PROBABLY FOR THE BEST")
        })
    ),
]

// MARK: - Game State
class GameState: ObservableObject {
    // Core stats
    @Published var name: String = ""
    @Published var hunger: Int = 100
    @Published var happiness: Int = 100
    @Published var health: Int = 100
    @Published var lastSeen: Date = Date()
    @Published var ageDays: Int = 0
    @Published var birthTime: Date = Date()
    @Published var isAlive: Bool = true
    @Published var dyingStartTime: Date? = nil
    @Published var lastNapTime: Date = Date()

    // Evolution
    @Published var evoStage: Int = 0
    @Published var evoBranch: String = ""

    // Owner progression
    @Published var ownerXP: Int = 0
    @Published var ownerLevel: Int = 1

    // Tracking
    @Published var fedCount: Int = 0
    @Published var playedCount: Int = 0
    @Published var neglectCount: Int = 0
    @Published var totalDeaths: Int = 0
    @Published var lastEvent: Date = Date.distantPast
    @Published var legacyTrait: String = ""

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
    @Published var sleepTapCount: Int = 0

    // Lifetime stats
    @Published var forageCount: Int = 0
    @Published var recipesFound: Int = 0
    @Published var itemsCrafted: Int = 0

    // Personality
    @Published var personalityTrait: String = ""
    @Published var careHistory: [String: Int] = [:]  // tracks care patterns

    // Burrow decorations
    @Published var placedDecorations: [String] = []  // decoration IDs placed in burrow

    // Expeditions
    @Published var activeExpeditionId: String = ""
    @Published var expeditionStartTime: Date? = nil
    @Published var expeditionsCompleted: Int = 0
    @Published var expeditionPendingFinds: [(id: String, time: Double)] = [] // (itemId, timestamp)
    @Published var expeditionCollectedFinds: [String] = [] // items found so far
    @Published var expeditionFindPopup: String? = nil // current popup item

    // Journal
    @Published var unlockedJournalIds: Set<String> = []

    // New UI state
    @Published var showBurrowOverlay: Bool = false
    @Published var showExpeditionOverlay: Bool = false
    @Published var showExpeditionResults: Bool = false
    @Published var expeditionResults: [String] = []
    @Published var showJournalOverlay: Bool = false
    @Published var journalInitialTab: Int = 0
    @Published var showForageOverlay: Bool = false
    @Published var showInventoryOverlay: Bool = false
    @Published var showGameSelector: Bool = false
    @Published var showSettingsMenu: Bool = false
    @Published var showForageResults: Bool = false
    @Published var forageResults: [String] = []
    @Published var passiveResults: [String] = []

    // UI state
    @Published var showNameEntry: Bool = true
    @Published var showFeedOverlay: Bool = false
    @Published var showMinigame: Bool = false
    @Published var showEventOverlay: Bool = false
    @Published var showDeathOverlay: Bool = false
    @Published var showEvolution: Bool = false
    @Published var toastMessage: String = ""
    @Published var soundEnabled: Bool = true
    @Published var showToast: Bool = false
    @Published var petStateAnim: String = "idle"
    @Published var animTick: Int = 0

    // Evolution display
    @Published var evoDisplayBranch: String = ""
    @Published var evoDisplayName: String = ""

    // Event
    @Published var pendingEvent: GameEvent? = nil

    // Minigame state
    @Published var mgGame: Int = 0 // 0=leftright, 1=feedme
    @Published var mgRound: Int = 1
    @Published var mgWins: Int = 0
    @Published var mgWaiting: Bool = false
    @Published var mgWallSide: String = ""
    @Published var mgFoodItems: [String] = []
    @Published var mgTargetFood: Int = 0
    @Published var mgResult: String = ""
    @Published var mgPrompt: String = "GET READY..."

    // Memory game
    @Published var mgMemoryCards: [String] = []
    @Published var mgMemoryRevealed: [Bool] = []
    @Published var mgMemoryMatched: [Bool] = []
    @Published var mgFirstFlip: Int? = nil
    @Published var mgMemoryFlips: Int = 0

    // Bug Catch game
    @Published var mgBugs: [BugState] = []
    @Published var mgBugScore: Int = 0
    @Published var mgBugTimeLeft: Double = 15

    // Rhythm game
    @Published var mgRhythmSequence: [Int] = []
    @Published var mgRhythmPlayerIndex: Int = 0
    @Published var mgRhythmShowingSequence: Bool = false
    @Published var mgRhythmHighlight: Int = -1

    private var gameTimer: Timer?
    private var decayTimer: Timer?
    var mgTimer: Timer?
    var animStateTimer: Timer?
    private var toastWorkItem: DispatchWorkItem?

    let audio = AudioEngine()

    init() {
        load()
        if !name.isEmpty {
            showNameEntry = false
            evaluatePersonality()
            if !isAlive {
                showDeathOverlay = true
            } else {
                let alive = applyDecay()
                if alive {
                    save()
                    checkForEvent()
                }
            }
        }
        startGameLoop()
    }

    deinit {
        gameTimer?.invalidate()
        decayTimer?.invalidate()
        mgTimer?.invalidate()
        animStateTimer?.invalidate()
        toastWorkItem?.cancel()
    }

    // MARK: - Save/Load
    func save() {
        var data: [String: Any] = [
            "name": name,
            "hunger": hunger,
            "happiness": happiness,
            "health": health,
            "lastSeen": lastSeen.timeIntervalSince1970,
            "ageDays": ageDays,
            "birthTime": birthTime.timeIntervalSince1970,
            "lastNapTime": lastNapTime.timeIntervalSince1970,
            "isAlive": isAlive,
            "dyingStartTime": dyingStartTime?.timeIntervalSince1970 ?? 0,
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
            // Personality & Burrow & Journal
            "personalityTrait": personalityTrait,
            "careHistory": careHistory,
            "placedDecorations": placedDecorations,
            "activeExpeditionId": activeExpeditionId,
            "expeditionsCompleted": expeditionsCompleted,
            "unlockedJournalIds": Array(unlockedJournalIds),
            "soundEnabled": soundEnabled,
        ]
        if let lft = lastForageTime {
            data["lastForageTime"] = lft.timeIntervalSince1970
        }
        if let est = expeditionStartTime {
            data["expeditionStartTime"] = est.timeIntervalSince1970
        }
        let pendingData = expeditionPendingFinds.map { ["id": $0.id, "time": $0.time] as [String: Any] }
        data["expeditionPendingFinds"] = pendingData
        data["expeditionCollectedFinds"] = expeditionCollectedFinds
        let effectsData = activeEffects.map { e -> [String: Any] in
            ["type": e.type.rawValue, "expiresAt": e.expiresAt.timeIntervalSince1970]
        }
        data["activeEffects"] = effectsData
        UserDefaults.standard.set(data, forKey: "grub_state")
    }

    func load() {
        guard let data = UserDefaults.standard.dictionary(forKey: "grub_state") else { return }
        name = data["name"] as? String ?? ""
        hunger = data["hunger"] as? Int ?? 100
        happiness = data["happiness"] as? Int ?? 100
        health = data["health"] as? Int ?? 100
        lastSeen = Date(timeIntervalSince1970: data["lastSeen"] as? Double ?? Date().timeIntervalSince1970)
        ageDays = data["ageDays"] as? Int ?? 0
        birthTime = Date(timeIntervalSince1970: data["birthTime"] as? Double ?? Date().timeIntervalSince1970)
        lastNapTime = Date(timeIntervalSince1970: data["lastNapTime"] as? Double ?? Date().timeIntervalSince1970)
        isAlive = data["isAlive"] as? Bool ?? true
        if let dyingTs = data["dyingStartTime"] as? Double, dyingTs > 0 {
            dyingStartTime = Date(timeIntervalSince1970: dyingTs)
        }
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
        // New systems
        personalityTrait = data["personalityTrait"] as? String ?? ""
        careHistory = data["careHistory"] as? [String: Int] ?? [:]
        placedDecorations = data["placedDecorations"] as? [String] ?? []
        activeExpeditionId = data["activeExpeditionId"] as? String ?? ""
        if let est = data["expeditionStartTime"] as? Double {
            expeditionStartTime = Date(timeIntervalSince1970: est)
        }
        expeditionsCompleted = data["expeditionsCompleted"] as? Int ?? 0
        if let pending = data["expeditionPendingFinds"] as? [[String: Any]] {
            expeditionPendingFinds = pending.compactMap { dict in
                guard let id = dict["id"] as? String, let time = dict["time"] as? Double else { return nil }
                return (id: id, time: time)
            }
        }
        expeditionCollectedFinds = data["expeditionCollectedFinds"] as? [String] ?? []
        if let savedJournal = data["unlockedJournalIds"] as? [String] {
            unlockedJournalIds = Set(savedJournal)
        }
        soundEnabled = data["soundEnabled"] as? Bool ?? true
        audio.enabled = soundEnabled
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

    // MARK: - Game Loop
    func startGameLoop() {
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.animTick += 1
                // Check for expedition finds every second
                if self.animTick % 20 == 0 && self.isOnExpedition {
                    self.checkExpeditionFinds()
                }
                // Notify when expedition completes
                if self.animTick % 20 == 0 && self.isExpeditionComplete && !self.showExpeditionResults && !self.showExpeditionOverlay {
                    self.displayToast("EXPEDITION COMPLETE!")
                    self.showExpeditionOverlay = true
                }
                // Check dying countdown every second
                if self.animTick % 20 == 0 && self.isDying && self.dyingTimeRemaining <= 0 {
                    self.triggerDeath()
                }
            }
        }

        decayTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self, self.isAlive, !self.name.isEmpty else { return }
                let _ = self.applyDecay()
                self.save()
            }
        }
    }

    // MARK: - Decay
    func getFloors(hoursElapsed: Double) -> (hunger: Double, happiness: Double, health: Double) {
        if hoursElapsed < 8 { return (0, 0, 30) }
        if hoursElapsed < 16 { return (10, 10, 20) }
        if hoursElapsed < 24 { return (5, 5, 10) }
        return (0, 0, 0)
    }

    func estimateCriticalMinutes(startVal: Double, decayPerMin: Double, elapsed: Double) -> Double {
        let minsToCrit = (startVal - DecayConstants.critThresh) / decayPerMin
        if minsToCrit >= elapsed { return 0 }
        return elapsed - max(0, minsToCrit)
    }

    @discardableResult
    func applyDecay() -> Bool {
        let now = Date()
        let elapsedMs = now.timeIntervalSince(lastSeen) * 1000
        let elapsedMin = elapsedMs / 60000
        let elapsedHours = elapsedMin / 60
        let floors = getFloors(hoursElapsed: elapsedHours)

        let cappedMin = min(elapsedMin, 1440)
        let nightFraction = min(1, cappedMin / 1440) * (8.0 / 24.0)
        let dayMin = cappedMin * (1 - nightFraction)
        let nightMin = cappedMin * nightFraction
        let effectiveMin = dayMin + nightMin * DecayConstants.nightMult

        // Prune expired effects
        activeEffects.removeAll { $0.expiresAt < now }

        // Apply effect modifiers
        let isEnergized = activeEffects.contains { $0.type == .energized }
        let isPoisoned = activeEffects.contains { $0.type == .poisoned }
        let expeditionMult: Double = isOnExpedition ? 1.5 : 1.0
        let decayMult: Double = (isEnergized ? 0.5 : 1.0) * expeditionMult

        let hDrop = effectiveMin * DecayConstants.hungerPerMin * decayMult * decayMultiplier(for: "hunger") * decorationDecayMultiplier(for: "hunger")
        let hpDrop = effectiveMin * DecayConstants.happinessPerMin * decayMult * decayMultiplier(for: "happiness") * decorationDecayMultiplier(for: "happiness")

        let newHunger = max(floors.hunger, Double(hunger) - hDrop)
        let newHappy = max(floors.happiness, Double(happiness) - hpDrop)

        let critMinH = estimateCriticalMinutes(startVal: Double(hunger), decayPerMin: DecayConstants.hungerPerMin, elapsed: effectiveMin)
        let critMinHp = estimateCriticalMinutes(startVal: Double(happiness), decayPerMin: DecayConstants.happinessPerMin, elapsed: effectiveMin)
        let critMin = max(critMinH, critMinHp)
        let healthDecayMult = isPoisoned ? 2.0 : decayMult
        let heDrop = critMin * DecayConstants.healthPerMin * healthDecayMult * decayMultiplier(for: "health") * decorationDecayMultiplier(for: "health")
        let newHealth = max(floors.health, Double(health) - heDrop)

        hunger = min(100, Int(round(newHunger)))
        happiness = min(100, Int(round(newHappy)))
        health = min(100, Int(round(newHealth)))
        lastSeen = now

        if elapsedHours > 4 && (hunger < 20 || happiness < 20) {
            neglectCount += 1
        }

        ageDays = Int(now.timeIntervalSince(birthTime) / 86400)

        // Dying state: health hit 0 → start countdown
        if health <= 0 && dyingStartTime == nil {
            dyingStartTime = now
            audio.play(.dying)
            displayToast("GRUB IS DYING! HEAL HIM!")
        }

        // If dying and timer ran out → death
        if isDying && dyingTimeRemaining <= 0 {
            triggerDeath()
            return false
        }

        // If was dying but got healed above 0 → saved
        if health > 0 && dyingStartTime != nil {
            dyingStartTime = nil
            displayToast("GRUB PULLED THROUGH!")
            audio.play(.revive)
        }

        checkEvolution()
        return true
    }

    // MARK: - Evolution
    func checkEvolution() {
        if evoStage >= 2 { return }
        let targetDay = evoStage == 0 ? 7 : 14
        if ageDays >= targetDay {
            let maxVal = max(fedCount, playedCount, neglectCount)
            var branch = "fed"
            if playedCount >= maxVal { branch = "played" }
            if neglectCount >= maxVal && neglectCount > 0 { branch = "feral" }
            evoBranch = branch
            evoStage += 1
            showEvolutionOverlay(branch: branch, stage: evoStage)
        }
    }

    func showEvolutionOverlay(branch: String, stage: Int) {
        audio.play(.evolve)
        let key = "\(branch)_\(stage)"
        evoDisplayName = evoNames[key] ?? "EVOLVED GRUB"
        evoDisplayBranch = branch
        showEvolution = true
    }

    // MARK: - XP
    func addXP(_ amount: Int) {
        let decoBonus: Double = decorationXPBonus ? 1.25 : 1.0
        ownerXP += Int(Double(amount) * xpMultiplier * decoBonus)
        while ownerLevel < xpThresholds.count && ownerXP >= xpThresholds[ownerLevel] {
            ownerLevel += 1
            audio.play(.levelup)
            displayToast("LEVEL UP! LVL \(ownerLevel)")
            checkLevelRecipeUnlocks()
        }
    }

    // MARK: - Legacy
    func computeLegacyTrait() -> String {
        if ageDays > 20 { return "LONG-LIVED: NEXT PET\nHEALTH DECAYS 20% SLOWER" }
        if itemsCrafted > 50 { return "MASTER CRAFTER: NEXT PET\nSTARTS WITH 3 MOSS CLUMPS" }
        if neglectCount == 0 { return "WELL-TENDED: NEXT PET\nSTARTS AT 80 HUNGER" }
        if evoStage >= 1 { return "EVOLVED STOCK: NEXT PET\nEVOLVES 1 DAY EARLY" }
        return "HARDENED: NEXT PET\nDECAYS 10% SLOWER"
    }

    // MARK: - Events
    func checkForEvent() {
        let now = Date()
        // Don't fire events until grub is at least 4 hours old
        let hoursSinceBirth = now.timeIntervalSince(birthTime) / 3600
        if hoursSinceBirth < 4 { return }
        let hoursSinceLast = now.timeIntervalSince(lastEvent) / 3600
        if hoursSinceLast < 20 { return }
        if Double.random(in: 0...1) > 0.3 { return }
        pendingEvent = gameEvents.randomElement()
        lastEvent = now
        showEventOverlay = true
        audio.play(.event)
    }

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

    // MARK: - Death & Restart
    func triggerDeath() {
        isAlive = false
        totalDeaths += 1
        audio.play(.death)
        legacyTrait = computeLegacyTrait()
        showDeathOverlay = true
        save()
    }

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

        name = ""
        hunger = 100
        happiness = 100
        health = 100
        lastSeen = Date()
        ageDays = 0
        birthTime = Date()
        isAlive = true
        dyingStartTime = nil
        lastNapTime = Date()
        evoStage = 0
        evoBranch = ""
        fedCount = 0
        playedCount = 0
        neglectCount = 0
        lastEvent = Date.distantPast

        ingredients = [:]
        craftedItems = [:]
        lastForageTime = nil
        passiveGatherTime = Date()
        activeEffects = []
        winStreak = 0
        forageCount = 0
        forageResults = []
        passiveResults = []

        // Reset expedition state
        activeExpeditionId = ""
        expeditionStartTime = nil
        expeditionPendingFinds = []
        expeditionCollectedFinds = []
        expeditionFindPopup = nil
        expeditionsCompleted = 0

        // Reset personality state
        personalityTrait = ""
        careHistory = [:]

        // Reset decorations (ingredients are cleared, so decorations are invalid)
        placedDecorations = []

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

    func confirmName(_ inputName: String) {
        let trimmed = inputName.trimmingCharacters(in: .whitespaces).uppercased()
        if trimmed.isEmpty {
            displayToast("ENTER A NAME!")
            return
        }
        name = trimmed
        audio.play(.tap)
        showNameEntry = false
        save()
        checkForEvent()
    }

    // MARK: - Tap Interaction
    func tapGrub() {
        guard isAlive, !isOnExpedition else { return }

        // Napping — poke him enough and he wakes up mad
        if isNight {
            sleepTapCount += 1
            if sleepTapCount < 3 {
                audio.play(.tap)
                displayToast(sleepTapCount == 1 ? "zzz..." : "zz..z..")
            } else if sleepTapCount == 3 {
                displayToast("...!")
                audio.play(.tap)
            } else if sleepTapCount >= 5 {
                forceWake()
            }
            return
        }

        sleepTapCount = 0
        audio.play(.tap)
        happiness = min(100, happiness + 1)

        // Pick animation + toast based on mood
        let anim: String
        let toast: String

        if hunger < 15 {
            anim = "tap_hungry"
            toast = "*STOMACH GROWLS*"
        } else if happiness < 15 {
            anim = "tap_grumpy"
            toast = "*GRUMBLE*"
        } else if health < 20 {
            anim = "tap_sick"
            toast = "*COUGH*"
        } else {
            let variants: [(String, String)] = [
                ("tap_jump", "!"),
                ("tap_wave", "HI!"),
                ("tap_spin", "*WIGGLE*"),
                ("tap_nuzzle", "*PURR*"),
                ("tap_chirp", "*CHIRP*"),
                ("tap_peek", ":)"),
                ("tap_bounce", "~"),
            ]
            let pick = variants.randomElement()!
            anim = pick.0
            toast = pick.1
        }

        petStateAnim = anim
        animStateTimer?.invalidate()
        animStateTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            DispatchQueue.main.async { self?.petStateAnim = "idle" }
        }
        displayToast(toast)
    }

    // MARK: - Toast
    func displayToast(_ message: String) {
        toastWorkItem?.cancel()
        toastMessage = message
        showToast = true
        let work = DispatchWorkItem { [weak self] in
            self?.showToast = false
        }
        toastWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: work)
    }

    // MARK: - Computed
    static let dyingCountdownSeconds: TimeInterval = 3600 // 60 minutes to save him

    static let napCycleSeconds: TimeInterval = 7200  // every 2 hours
    static let napDurationSeconds: TimeInterval = 900 // 15 minutes

    var isNight: Bool {
        let elapsed = Date().timeIntervalSince(lastNapTime)
        let cyclePos = elapsed.truncatingRemainder(dividingBy: Self.napCycleSeconds)
        // Awake for first portion, napping for last 15 min
        return cyclePos >= (Self.napCycleSeconds - Self.napDurationSeconds)
    }

    var napTimeRemaining: Int {
        let elapsed = Date().timeIntervalSince(lastNapTime)
        let cyclePos = elapsed.truncatingRemainder(dividingBy: Self.napCycleSeconds)
        let napStart = Self.napCycleSeconds - Self.napDurationSeconds
        if cyclePos >= napStart {
            return max(0, Int(Self.napCycleSeconds - cyclePos))
        }
        return 0
    }

    var napTimeString: String {
        let secs = napTimeRemaining
        return String(format: "%d:%02d", secs / 60, secs % 60)
    }

    func forceWake() {
        // Reset nap cycle so he's awake now
        lastNapTime = Date()
        happiness = max(0, happiness - 10)
        sleepTapCount = 0
        audio.play(.growl)
        petStateAnim = "angry"
        displayToast("STOP WAKING ME UP!")
        animStateTimer?.invalidate()
        animStateTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async { self?.petStateAnim = "idle" }
        }
        save()
    }

    var isDying: Bool {
        dyingStartTime != nil && isAlive
    }

    var dyingTimeRemaining: TimeInterval {
        guard let start = dyingStartTime else { return 0 }
        return max(0, Self.dyingCountdownSeconds - Date().timeIntervalSince(start))
    }

    var dyingTimeString: String {
        let remaining = Int(dyingTimeRemaining)
        let mins = remaining / 60
        let secs = remaining % 60
        return String(format: "%d:%02d", mins, secs)
    }

    var currentPetAnim: String {
        if !isAlive { return "dead" }
        if isDying { return "dying" }
        // Woken-up-angry overrides sleeping
        if isNight && petStateAnim != "angry" { return "sleeping" }
        // Action animations override everything
        if petStateAnim == "eating" || petStateAnim == "drinking" || petStateAnim == "angry" || petStateAnim.hasPrefix("tap_") { return petStateAnim }
        // Stat-driven states (priority order)
        if health < 20 { return "sick" }
        if hunger < 15 { return "starving" }
        if hunger < 30 { return "hungry" }
        if happiness < 15 { return "angry" }
        if happiness < 30 { return "unhappy" }
        if activeEffects.contains(where: { $0.type == .energized && $0.expiresAt > Date() }) { return "energized" }
        return petStateAnim
    }

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

    // MARK: - App Lifecycle
    func onBackground() {
        lastSeen = Date()
        save()
    }

    func onForeground() {
        guard isAlive, !name.isEmpty else { return }
        applyDecay()
        collectPassiveItems()
        checkExpeditionOnReturn()
        checkJournalUnlocks()
        save()
        checkForEvent()
    }
}
