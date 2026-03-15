import Foundation

extension GameState {
    // MARK: - Journal

    /// Check all journal entries and unlock any that are newly met
    func checkJournalUnlocks() {
        for entry in journalEntries {
            if unlockedJournalIds.contains(entry.id) { continue }
            if isJournalConditionMet(entry.unlockCondition) {
                unlockedJournalIds.insert(entry.id)
                displayToast("JOURNAL: \(entry.title)!")
                trackCare("discover")
            }
        }
    }

    /// Check if a specific journal unlock condition is met
    fileprivate func isJournalConditionMet(_ condition: JournalUnlock) -> Bool {
        switch condition {
        case .ingredient(let id):
            return (ingredients[id] ?? 0) > 0
        case .recipe(let id):
            return unlockedRecipes.contains(id)
        case .decoration(let id):
            return placedDecorations.contains(id)
        case .expedition:
            return expeditionsCompleted > 0
        case .milestone(let stat, let threshold):
            return milestoneValue(for: stat) >= threshold
        case .trait(let trait):
            return personalityTrait == trait.rawValue
        }
    }

    /// Get the current value for a milestone stat
    fileprivate func milestoneValue(for stat: String) -> Int {
        switch stat {
        case "fedCount": return fedCount
        case "playedCount": return playedCount
        case "forageCount": return forageCount
        case "itemsCrafted": return itemsCrafted
        case "ownerLevel": return ownerLevel
        case "expeditionsCompleted": return expeditionsCompleted
        default: return 0
        }
    }

    /// Journal completion percentage
    var journalCompletion: Int {
        guard !journalEntries.isEmpty else { return 0 }
        return (unlockedJournalIds.count * 100) / journalEntries.count
    }

}
