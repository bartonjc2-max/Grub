import Foundation

extension GameState {
    // MARK: - Burrow Decorations

    /// Check if player has ingredients to build a decoration
    func canBuildDecoration(_ decoId: String) -> Bool {
        guard let deco = decorationCatalog[decoId] else { return false }
        guard !placedDecorations.contains(decoId) else { return false }
        for req in deco.ingredients {
            if (ingredients[req.id] ?? 0) < req.quantity { return false }
        }
        return true
    }

    /// Build and place a decoration
    func buildDecoration(_ decoId: String) {
        guard canBuildDecoration(decoId), let deco = decorationCatalog[decoId] else {
            displayToast("CAN'T BUILD!")
            return
        }
        // Consume ingredients
        for req in deco.ingredients {
            ingredients[req.id] = (ingredients[req.id] ?? 0) - req.quantity
            if ingredients[req.id]! <= 0 { ingredients.removeValue(forKey: req.id) }
        }
        placedDecorations.append(decoId)
        itemsCrafted += 1
        addXP(2)
        audio.play(.craftDone)
        displayToast("BUILT \(deco.name)!")
        checkJournalUnlocks()
        save()
    }

    /// Remove a placed decoration (returns partial ingredients)
    func removeDecoration(_ decoId: String) {
        guard let idx = placedDecorations.firstIndex(of: decoId),
              let deco = decorationCatalog[decoId] else { return }
        placedDecorations.remove(at: idx)
        // Return half ingredients
        for req in deco.ingredients {
            let returned = max(1, req.quantity / 2)
            addIngredient(req.id, count: returned)
        }
        displayToast("REMOVED \(deco.name)")
        save()
    }

    /// Check if a specific decoration bonus is active
    func hasDecorationBonus(_ bonus: DecorationBonus) -> Bool {
        placedDecorations.contains { id in
            decorationCatalog[id]?.bonusType == bonus
        }
    }

    /// Count how many of a specific bonus type are placed
    func decorationBonusCount(_ bonus: DecorationBonus) -> Int {
        placedDecorations.filter { decorationCatalog[$0]?.bonusType == bonus }.count
    }

    /// Get total decay reduction from decorations (each relevant deco = 10% reduction)
    func decorationDecayMultiplier(for stat: String) -> Double {
        let bonus: DecorationBonus
        switch stat {
        case "health": bonus = .healthDecay
        case "happiness": bonus = .happinessDecay
        case "hunger": bonus = .hungerDecay
        default: return 1.0
        }
        let count = decorationBonusCount(bonus)
        return max(0.5, 1.0 - Double(count) * 0.1)
    }

    /// Get forage luck bonus from decorations
    var decorationForageLuckBonus: Double {
        Double(decorationBonusCount(.forageLuck)) * 0.1
    }

    /// Get XP bonus from decorations
    var decorationXPBonus: Bool {
        hasDecorationBonus(.xpBoost)
    }

    /// Get passive gather speed bonus
    var decorationPassiveBonus: Bool {
        hasDecorationBonus(.passiveGather)
    }

    /// Sorted decorations for display: unbuilt craftable first, then unbuilt uncraftable, placed at end
    func sortedDecorations() -> [(id: String, def: DecorationDef, placed: Bool, craftable: Bool)] {
        decorationCatalog.map { id, def in
            let placed = placedDecorations.contains(id)
            let craftable = canBuildDecoration(id)
            return (id, def, placed, craftable)
        }.sorted { a, b in
            if a.placed != b.placed { return !a.placed }
            if a.craftable != b.craftable { return a.craftable }
            return a.def.name < b.def.name
        }
    }
}
