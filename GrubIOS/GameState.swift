import Foundation
import Combine

// MARK: - Decay Constants
struct DecayConstants {
    static let hungerPerMin: Double = 1.0 / 30.0
    static let happinessPerMin: Double = 1.0 / 45.0
    static let healthPerMin: Double = 1.0 / 15.0
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

    // Lifetime stats
    @Published var forageCount: Int = 0
    @Published var recipesFound: Int = 0
    @Published var itemsCrafted: Int = 0

    // New UI state
    @Published var showForageOverlay: Bool = false
    @Published var showInventoryOverlay: Bool = false
    @Published var showGameSelector: Bool = false
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

    private var gameTimer: Timer?
    private var decayTimer: Timer?
    var mgTimer: Timer?
    var animStateTimer: Timer?

    let audio = AudioEngine()

    init() {
        load()
        if !name.isEmpty {
            showNameEntry = false
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
                self?.animTick += 1
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
        let decayMult: Double = isEnergized ? 0.5 : 1.0

        let hDrop = effectiveMin * DecayConstants.hungerPerMin * decayMult
        let hpDrop = effectiveMin * DecayConstants.happinessPerMin * decayMult

        let newHunger = max(floors.hunger, Double(hunger) - hDrop)
        let newHappy = max(floors.happiness, Double(happiness) - hpDrop)

        let critMinH = estimateCriticalMinutes(startVal: Double(hunger), decayPerMin: DecayConstants.hungerPerMin, elapsed: effectiveMin)
        let critMinHp = estimateCriticalMinutes(startVal: Double(happiness), decayPerMin: DecayConstants.happinessPerMin, elapsed: effectiveMin)
        let critMin = max(critMinH, critMinHp)
        let healthDecayMult = isPoisoned ? 2.0 : decayMult
        let heDrop = critMin * DecayConstants.healthPerMin * healthDecayMult
        let newHealth = max(floors.health, Double(health) - heDrop)

        hunger = min(100, Int(round(newHunger)))
        happiness = min(100, Int(round(newHappy)))
        health = min(100, Int(round(newHealth)))
        lastSeen = now

        if elapsedHours > 4 && (hunger < 20 || happiness < 20) {
            neglectCount += 1
        }

        ageDays = Int(now.timeIntervalSince(birthTime) / 86400)

        if elapsedHours >= 24 && health <= 0 {
            triggerDeath()
            return false
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
            fedCount = 0
            playedCount = 0
            neglectCount = 0
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
        ownerXP += amount
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

    // MARK: - Minigames
    func openPlay() {
        audio.play(.tap)
        mgGame = Int.random(in: 0...1)
        mgRound = 1
        mgWins = 0
        mgResult = ""
        showMinigame = true
        setupMGRound()
    }

    func setupMGRound() {
        mgResult = ""
        mgTimer?.invalidate()

        if mgGame == 0 {
            // Left or Right
            mgWallSide = Bool.random() ? "left" : "right"
            mgWaiting = true
            mgPrompt = "WHICH SIDE IS SAFE?"
        } else {
            // Feed the right food
            let allFoods = ["🍖", "🥦", "🍰", "🍕", "🥕"]
            mgFoodItems = Array(allFoods.shuffled().prefix(3))
            mgTargetFood = Int.random(in: 0...2)
            mgPrompt = "FEED IT: \(mgFoodItems[mgTargetFood])"
            mgWaiting = true

            // Auto-fail after 3 seconds
            mgTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                DispatchQueue.main.async {
                    guard let self = self, self.mgWaiting else { return }
                    self.mgRoundResult(won: false)
                }
            }
        }
    }

    func mgChoice(side: String) {
        guard mgWaiting, mgGame == 0 else { return }
        mgWaiting = false
        mgTimer?.invalidate()
        let correct = side != mgWallSide
        mgRoundResult(won: correct)
    }

    func mgFoodChoice(index: Int) {
        guard mgWaiting, mgGame == 1 else { return }
        mgWaiting = false
        mgTimer?.invalidate()
        let correct = index == mgTargetFood
        mgRoundResult(won: correct)
    }

    func mgRoundResult(won: Bool) {
        if won {
            mgWins += 1
            audio.play(.win)
            mgResult = "✓ CORRECT!"
        } else {
            audio.play(.lose)
            mgResult = "✗ WRONG!"
        }

        if mgRound >= 3 {
            let gameWon = mgWins >= 2
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                guard let self = self else { return }
                self.happiness = min(100, self.happiness + (gameWon ? 20 : 10))
                self.playedCount += 1
                self.addXP(3)
                self.save()
                self.showMinigame = false
                if gameWon { self.petStateAnim = "playing" }
                self.animStateTimer?.invalidate()
                self.animStateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                    DispatchQueue.main.async { self?.petStateAnim = "idle" }
                }
            }
        } else {
            mgRound += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
                self?.setupMGRound()
            }
        }
    }

    func closeMinigame() {
        audio.play(.tap)
        mgTimer?.invalidate()
        showMinigame = false
    }

    // MARK: - Toast
    func displayToast(_ message: String) {
        toastMessage = message
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.showToast = false
        }
    }

    // MARK: - Computed
    var isNight: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 7 || hour >= 21
    }

    var currentPetAnim: String {
        if !isAlive { return "dead" }
        if isNight { return "sleeping" }
        if health < 20 { return "sick" }
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
        save()
        checkForEvent()
    }
}
