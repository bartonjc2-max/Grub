import Foundation

extension GameState {
    static let forageCooldownSeconds: TimeInterval = 900 // 15 minutes
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
    static let forageCost: Int = 5

    func forage(area: ForageArea) {
        guard canForage else {
            displayToast("COOLDOWN: \(forageTimeRemaining)m")
            return
        }
        guard hunger > Self.forageCost else {
            displayToast("TOO HUNGRY TO FORAGE!")
            return
        }
        guard let table = lootTables[area] else { return }

        // Foraging costs hunger
        hunger = max(0, hunger - Self.forageCost)
        audio.play(.dig)
        var found: [String] = []
        let baseCount = Int.random(in: table.itemCount)
        let count = Int(Double(baseCount) * forageYieldMultiplier)

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
        trackCare("forage")
        checkJournalUnlocks()

        forageResults = found
        showForageResults = true
        showForageOverlay = false
        save()
    }

    fileprivate func rollIngredient(rarity: Rarity, area: ForageArea, table: LootTable) -> String? {
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
        let gatherInterval = decorationPassiveBonus ? Self.passiveGatherInterval * 0.75 : Self.passiveGatherInterval
        let intervals = min(Int(elapsed / gatherInterval), Self.maxPassiveItems / 2)

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
