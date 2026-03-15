import Foundation

extension GameState {
    // MARK: - Crafting

    /// Check if the player has all ingredients for a recipe
    func canCraft(_ recipeId: String) -> Bool {
        guard let recipe = recipeCatalog[recipeId] else { return false }
        guard unlockedRecipes.contains(recipeId) else { return false }
        for req in recipe.ingredients {
            if (ingredients[req.id] ?? 0) < req.quantity { return false }
        }
        return true
    }

    /// Craft a recipe: consume ingredients, produce crafted item
    func craft(_ recipeId: String) {
        guard canCraft(recipeId), let recipe = recipeCatalog[recipeId] else {
            displayToast("CAN'T CRAFT!")
            return
        }

        // Consume ingredients
        for req in recipe.ingredients {
            ingredients[req.id] = (ingredients[req.id] ?? 0) - req.quantity
            if ingredients[req.id]! <= 0 { ingredients.removeValue(forKey: req.id) }
        }

        // Produce crafted item
        craftedItems[recipeId] = (craftedItems[recipeId] ?? 0) + 1
        itemsCrafted += 1
        addXP(1)
        audio.play(.craftDone)
        displayToast("CRAFTED \(recipe.name)!")
        trackCare("craft")
        checkJournalUnlocks()
        save()
    }

    /// Use a crafted food/medicine item on Grub
    func useCraftedItem(_ recipeId: String) {
        guard let count = craftedItems[recipeId], count > 0,
              let recipe = recipeCatalog[recipeId] else {
            displayToast("NONE LEFT!")
            return
        }

        // Check overfed
        let newHunger = hunger + recipe.effects.hunger
        if newHunger > 95 && recipe.effects.hunger > 0 {
            happiness = max(0, happiness - 5)
            trackCare("overfeed")
            displayToast("OVERFED! -5 HAP")
        }
        trackCare("feed")

        // Apply gentle trait bonus
        if foodHappinessBonus > 0 {
            happiness = min(100, happiness + foodHappinessBonus)
        }

        // Apply picky trait bonus: +50% effect from uncommon+ recipes
        let pickyMult: Double = hasTraitBonus(.picky) && recipe.unlockType != .starter ? 1.5 : 1.0

        // Apply effects
        if recipe.effects.health == 100 {
            // Full heal (Spore Elixir)
            health = 100
        } else {
            health = min(100, health + Int(Double(recipe.effects.health) * pickyMult))
        }
        hunger = min(100, hunger + Int(Double(recipe.effects.hunger) * pickyMult))
        happiness = min(100, happiness + Int(Double(recipe.effects.happiness) * pickyMult))

        // Energized effect
        if recipe.grantsEnergized {
            let expiry = Date().addingTimeInterval(1800) // 30 minutes
            activeEffects.append(ActiveEffect(type: .energized, expiresAt: expiry))
        }

        // Consume item
        craftedItems[recipeId] = count - 1
        if craftedItems[recipeId]! <= 0 { craftedItems.removeValue(forKey: recipeId) }

        // Track feeding for evolution
        if recipe.effects.hunger > 0 { fedCount += 1 }

        audio.play(.feed)
        addXP(1)

        // Close overlays so the player can see the animation
        showFeedOverlay = false
        showInventoryOverlay = false

        // Animation — eating for food, drinking for health items
        if recipe.effects.health > recipe.effects.hunger {
            petStateAnim = "drinking"
        } else {
            petStateAnim = "eating"
        }
        animStateTimer?.invalidate()
        animStateTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
            DispatchQueue.main.async { self?.petStateAnim = "idle" }
        }

        save()
    }

    /// Get sorted list of available recipes (unlocked, grouped by craftability)
    func sortedRecipes() -> [(id: String, def: RecipeDef, craftable: Bool)] {
        let unlocked = unlockedRecipes.compactMap { id -> (String, RecipeDef, Bool)? in
            guard let def = recipeCatalog[id] else { return nil }
            return (id, def, canCraft(id))
        }
        // Craftable first, then alphabetical
        return unlocked.sorted { a, b in
            if a.2 != b.2 { return a.2 }
            return a.1.name < b.1.name
        }
    }

    /// Get recipes the player hasn't unlocked yet (for display as locked)
    func lockedRecipes() -> [(id: String, def: RecipeDef)] {
        recipeCatalog.compactMap { id, def in
            if unlockedRecipes.contains(id) { return nil }
            if case .level = def.unlockType {
                return (id, def)
            }
            return nil
        }.sorted { a, b in
            if case .level(let la) = a.def.unlockType, case .level(let lb) = b.def.unlockType {
                return la < lb
            }
            return false
        }
    }
}
