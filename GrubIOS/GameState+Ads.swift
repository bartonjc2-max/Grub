import Foundation

extension GameState {

    // MARK: - Interstitial Triggers

    /// Call at natural break points (after minigame, after expedition return, after evolution).
    /// Respects the 5-minute cooldown automatically.
    func tryShowInterstitial() {
        adManager.showInterstitialIfReady()
    }

    // MARK: - Rewarded Ad Handlers

    /// Generic entry point: show a rewarded ad, then apply the reward on success.
    func showRewardedAd(for rewardType: AdRewardType) {
        adManager.showRewarded(for: rewardType) { [weak self] earned in
            guard let self = self, earned else { return }
            DispatchQueue.main.async {
                self.applyReward(rewardType)
            }
        }
    }

    private func applyReward(_ type: AdRewardType) {
        switch type {
        case .skipExpeditionTimer:
            // Instantly complete the expedition
            if isOnExpedition {
                expeditionStartTime = Date().addingTimeInterval(-86400) // set to distant past
                displayToast("EXPEDITION COMPLETE!")
                audio.play(.expeditionReturn)
            }

        case .skipForageCooldown:
            // Reset forage cooldown
            lastForageTime = nil
            displayToast("READY TO FORAGE!")
            audio.play(.itemFound)

        case .reviveGrub:
            // Revive with 25% stats
            hunger = 25
            happiness = 25
            health = 25
            isAlive = true
            dyingStartTime = nil
            showDeathOverlay = false
            displayToast("\(name) REVIVED!")
            audio.play(.revive)

        case .doubleMinigameXP:
            // Grant bonus XP equal to what was just earned (effectively doubling)
            let bonusXP = lastMinigameXP
            addXP(bonusXP)
            displayToast("+\(bonusXP) BONUS XP!")
            audio.play(.levelup)

        case .doubleForageLoot:
            // Duplicate all items in forageResults
            let dupes = forageResults
            for item in dupes {
                addIngredient(item)
            }
            forageResults.append(contentsOf: dupes)
            displayToast("LOOT DOUBLED!")
            audio.play(.rareFind)

        case .bonusExpeditionLoot:
            // Roll an extra rare drop
            let rareDrop = rareIngredients.randomElement() ?? "moon_petal"
            addIngredient(rareDrop)
            expeditionResults.append(rareDrop)
            let name = ingredientCatalog[rareDrop]?.name ?? rareDrop
            displayToast("BONUS: \(name)!")
            audio.play(.lootSparkle)
        }
    }

}
