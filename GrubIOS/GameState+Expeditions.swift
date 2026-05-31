import Foundation
import SwiftUI

extension GameState {
    // MARK: - Expeditions

    /// Whether grub is currently on an expedition
    var isOnExpedition: Bool {
        !activeExpeditionId.isEmpty && expeditionStartTime != nil
    }

    /// Time remaining on current expedition in seconds
    var expeditionTimeRemaining: TimeInterval {
        guard let start = expeditionStartTime,
              let def = expeditionCatalog[activeExpeditionId] else { return 0 }
        let elapsed = Date().timeIntervalSince(start)
        let total = Double(def.durationMinutes) * 60
        return max(0, total - elapsed)
    }

    /// Whether current expedition is complete
    /// Wall-clock date when the current expedition completes, or nil if none active.
    /// Used by NotificationScheduler (Phase 1) to schedule "expedition ready" reminders.
    var expeditionEndDate: Date? {
        guard let start = expeditionStartTime,
              let def = expeditionCatalog[activeExpeditionId] else { return nil }
        return start.addingTimeInterval(Double(def.durationMinutes) * 60)
    }

    var isExpeditionComplete: Bool {
        isOnExpedition && expeditionTimeRemaining <= 0
    }

    /// Formatted time remaining string
    var expeditionTimeString: String {
        let remaining = expeditionTimeRemaining
        if remaining <= 0 { return "DONE!" }
        let mins = Int(remaining) / 60
        let secs = Int(remaining) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    /// Hunger + happiness cost to start an expedition, scaled by duration
    static func expeditionCost(durationMinutes: Int) -> (hunger: Int, happiness: Int) {
        let hungerCost = 5 + (durationMinutes / 10) * 2
        let happinessCost = 3 + (durationMinutes / 10)
        return (hungerCost, happinessCost)
    }

    /// Send grub on an expedition — pre-rolls all loot with scheduled find times
    func startExpedition(_ expedId: String) {
        guard !isOnExpedition else {
            displayToast("ALREADY EXPLORING!")
            return
        }
        guard let def = expeditionCatalog[expedId] else { return }
        guard ownerLevel >= def.unlockLevel else {
            displayToast("NEED LEVEL \(def.unlockLevel)!")
            return
        }
        let cost = Self.expeditionCost(durationMinutes: def.durationMinutes)
        guard hunger > cost.hunger else {
            displayToast("TOO HUNGRY TO EXPLORE!")
            return
        }
        guard happiness > cost.happiness else {
            displayToast("GRUB DOESN'T WANT TO GO!")
            return
        }

        // Pay stat costs upfront
        hunger = max(0, hunger - cost.hunger)
        happiness = max(0, happiness - cost.happiness)

        let now = Date()
        activeExpeditionId = expedId
        expeditionStartTime = now
        expeditionCollectedFinds = []

        // Pre-roll loot and schedule find times spread across the duration
        var finds: [(id: String, time: Double)] = []
        let totalSeconds = Double(def.durationMinutes) * 60
        let startTs = now.timeIntervalSince1970

        // Roll regular loot
        let count = Int.random(in: def.lootCount)
        for i in 0..<count {
            let roll = Double.random(in: 0...1)
            var cumulative = 0.0
            var picked = def.lootPool.first?.id ?? "moss_clump"
            for (id, weight) in def.lootPool {
                cumulative += weight
                if roll <= cumulative {
                    picked = id
                    break
                }
            }
            // Bonus rare chance from curious trait + decorations
            if Double.random(in: 0...1) < def.bonusRareChance + rareChanceBonus + decorationForageLuckBonus {
                picked = rareIngredients.randomElement() ?? picked
            }
            // Spread finds evenly across 20%-90% of the duration
            let fraction = 0.2 + 0.7 * (Double(i) + Double.random(in: 0...0.8)) / Double(count)
            finds.append((id: picked, time: startTs + totalSeconds * fraction))
        }

        // Guaranteed rare on higher tiers
        if def.unlockLevel >= 3 {
            let rareItem = rareIngredients.randomElement() ?? "moon_petal"
            let fraction = 0.6 + Double.random(in: 0...0.25)
            finds.append((id: rareItem, time: startTs + totalSeconds * fraction))
        }

        // Sort by time
        finds.sort { $0.time < $1.time }
        expeditionPendingFinds = finds

        audio.play(.expeditionGo)
        displayToast("\(def.name) STARTED!")
        save()
    }

    /// Called every second from game loop — checks if any finds are due
    func checkExpeditionFinds() {
        guard isOnExpedition else { return }
        let now = Date().timeIntervalSince1970

        // Collect all finds that are due
        while let first = expeditionPendingFinds.first, first.time <= now {
            expeditionPendingFinds.removeFirst()
            let itemId = first.id
            addIngredient(itemId)
            expeditionCollectedFinds.append(itemId)

            // Show popup with animation so SwiftUI transition renders
            withAnimation(.easeOut(duration: 0.3)) {
                expeditionFindPopup = itemId
            }
            audio.play(.lootSparkle)
            displayToast("FOUND \(ingredientCatalog[itemId]?.name ?? itemId.uppercased())!")

            // Auto-dismiss popup after 3 seconds
            let work = DispatchWorkItem { [weak self] in
                withAnimation(.easeIn(duration: 0.3)) {
                    if self?.expeditionFindPopup == itemId {
                        self?.expeditionFindPopup = nil
                    }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: work)
            save()
        }
    }

    /// Collect expedition — finalize, check scroll + risk, show summary
    func collectExpedition() {
        guard isExpeditionComplete,
              let def = expeditionCatalog[activeExpeditionId] else { return }

        // Collect any remaining pending finds (e.g. app was closed)
        for find in expeditionPendingFinds {
            addIngredient(find.id)
            expeditionCollectedFinds.append(find.id)
        }
        expeditionPendingFinds = []

        var results = expeditionCollectedFinds

        // Recipe scroll chance — expedition exclusive
        let scrollChance: Double = Double(def.unlockLevel) * 0.05
        if Double.random(in: 0...1) < scrollChance {
            let locked = scrollRecipeIds.filter { !unlockedRecipes.contains($0) }
            if let recipe = locked.randomElement() {
                unlockedRecipes.insert(recipe)
                recipesFound += 1
                if let name = recipeCatalog[recipe]?.name {
                    results.append("SCROLL:\(name)")
                }
            }
        }

        // XP reward
        addXP(def.xpReward)

        // Risk check — harder expeditions can hurt more
        if Double.random(in: 0...1) < def.riskChance {
            health = max(5, health - def.riskDamage)
            happiness = max(0, happiness - def.riskDamage / 2)
            results.append("RISK:\(def.riskMessage)")
        }

        expeditionResults = results
        showExpeditionResults = true
        expeditionsCompleted += 1
        activeExpeditionId = ""
        expeditionStartTime = nil
        expeditionCollectedFinds = []
        expeditionFindPopup = nil
        audio.play(.expeditionReturn)
        trackCare("expedition")
        checkJournalUnlocks()
        save()
        // Show interstitial at natural break point
        tryShowInterstitial()
    }

    /// Check expeditions on foreground return
    func checkExpeditionOnReturn() {
        if isExpeditionComplete {
            displayToast("EXPEDITION COMPLETE!")
        }
    }
}
