import Foundation

extension GameState {
    // MARK: - Personality

    /// Track a care action for personality development
    func trackCare(_ action: String) {
        careHistory[action] = (careHistory[action] ?? 0) + 1
        evaluatePersonality()
        save()
    }

    /// Evaluate which personality trait dominates based on care history
    func evaluatePersonality() {
        let feeds = careHistory["feed"] ?? 0
        let plays = careHistory["play"] ?? 0
        let forages = careHistory["forage"] ?? 0
        let crafts = careHistory["craft"] ?? 0
        let neglects = careHistory["neglect"] ?? 0
        let overfeeds = careHistory["overfeed"] ?? 0
        let lowHealth = careHistory["lowHealth"] ?? 0
        let discoveries = careHistory["discover"] ?? 0
        let wins = careHistory["minigameWin"] ?? 0

        // Determine dominant trait based on care patterns
        var scores: [(PersonalityTrait, Int)] = [
            (.scrappy, forages * 3),
            (.cheerful, plays * 2 + feeds),
            (.hardy, lowHealth * 4),
            (.curious, discoveries * 3 + forages),
            (.picky, overfeeds * 5),
            (.lazy, neglects * 3),
            (.fierce, wins * 3),
            (.gentle, feeds * 2),
        ]

        scores.sort { $0.1 > $1.1 }

        // Need at least 10 total actions before assigning a trait
        if totalCareActions >= Self.traitThreshold, let top = scores.first, top.1 > 0 {
            let newTrait = top.0.rawValue
            if personalityTrait != newTrait {
                personalityTrait = newTrait
                displayToast("GRUB IS \(newTrait.uppercased())!")
            }
        }
    }

    /// Get the active personality trait enum value
    var activeTrait: PersonalityTrait? {
        PersonalityTrait(rawValue: personalityTrait)
    }

    /// Check if a specific bonus is active from personality
    func hasTraitBonus(_ trait: PersonalityTrait) -> Bool {
        activeTrait == trait
    }

    /// Get XP multiplier based on personality
    var xpMultiplier: Double {
        hasTraitBonus(.cheerful) ? 1.5 : 1.0
    }

    /// Get forage yield multiplier
    var forageYieldMultiplier: Double {
        hasTraitBonus(.scrappy) ? 1.5 : 1.0
    }

    /// Get decay multiplier for a stat
    func decayMultiplier(for stat: String) -> Double {
        var mult = 1.0
        if hasTraitBonus(.lazy) { mult *= 0.8 }
        if hasTraitBonus(.hardy) && stat == "health" { mult *= 0.7 }
        return mult
    }

    /// Get food happiness bonus from gentle trait
    var foodHappinessBonus: Int {
        hasTraitBonus(.gentle) ? 5 : 0
    }

    /// Get minigame reward bonus from fierce trait
    var minigameRewardBonus: Int {
        hasTraitBonus(.fierce) ? 1 : 0
    }

    /// Get rare find chance bonus from curious trait
    var rareChanceBonus: Double {
        hasTraitBonus(.curious) ? 0.2 : 0.0
    }

    /// Total care actions taken
    var totalCareActions: Int {
        careHistory.values.reduce(0, +)
    }

    /// Threshold needed to lock in a trait
    static let traitThreshold: Int = 10

    /// Sorted trait scores for display (top 3)
    var traitScores: [(trait: PersonalityTrait, score: Int)] {
        let feeds = careHistory["feed"] ?? 0
        let plays = careHistory["play"] ?? 0
        let forages = careHistory["forage"] ?? 0
        let neglects = careHistory["neglect"] ?? 0
        let overfeeds = careHistory["overfeed"] ?? 0
        let lowHealth = careHistory["lowHealth"] ?? 0
        let discoveries = careHistory["discover"] ?? 0
        let wins = careHistory["minigameWin"] ?? 0

        let scores: [(PersonalityTrait, Int)] = [
            (.scrappy, forages * 3),
            (.cheerful, plays * 2 + feeds),
            (.hardy, lowHealth * 4),
            (.curious, discoveries * 3 + forages),
            (.picky, overfeeds * 5),
            (.lazy, neglects * 3),
            (.fierce, wins * 3),
            (.gentle, feeds * 2),
        ]

        return scores
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
    }

    /// Flavor hint for what's developing
    var traitHint: String? {
        guard let top = traitScores.first else { return nil }
        switch top.trait {
        case .scrappy: return "GRUB ENJOYS DIGGING AROUND..."
        case .cheerful: return "GRUB SEEMS REALLY HAPPY LATELY..."
        case .hardy: return "GRUB IS GETTING TOUGHER..."
        case .curious: return "GRUB IS ALWAYS SNIFFING AROUND..."
        case .picky: return "GRUB IS GETTING FUSSY ABOUT FOOD..."
        case .lazy: return "GRUB SEEMS... UNMOTIVATED..."
        case .fierce: return "GRUB HAS A COMPETITIVE STREAK..."
        case .gentle: return "GRUB IS WARM AND CONTENT..."
        }
    }
}
