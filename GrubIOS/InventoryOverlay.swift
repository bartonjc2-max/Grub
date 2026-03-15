import SwiftUI

struct InventoryOverlayView: View {
    @ObservedObject var game: GameState
    @State private var selectedTab: Int = 0
    @State private var showCrafting: Bool = false

    var body: some View {
        ZStack {
            Color(hex: "#1a1a2e").opacity(0.93)
                .ignoresSafeArea()
                .onTapGesture {
                    if showCrafting { showCrafting = false }
                    else { game.showInventoryOverlay = false }
                }

            VStack(spacing: 0) {
                // Title
                HStack {
                    Text("INVENTORY")
                        .font(GrubFont.size(14))
                        .foregroundColor(GrubPalette.green)
                        .tracking(2)
                    Spacer()
                    Text("\(game.ingredients.count)/20")
                        .font(GrubFont.size(8))
                        .foregroundColor(game.ingredients.count >= 18 ? GrubPalette.red : GrubPalette.pale.opacity(0.5))
                }
                .padding(.bottom, 12)

                // Tabs
                HStack(spacing: 0) {
                    TabButton(title: "INGREDIENTS", isSelected: selectedTab == 0) { selectedTab = 0 }
                    TabButton(title: "FOOD", isSelected: selectedTab == 1) { selectedTab = 1 }
                }
                .padding(.bottom, 8)

                // Content
                if showCrafting {
                    CraftingListView(game: game, showCrafting: $showCrafting)
                } else if selectedTab == 0 {
                    IngredientsGridView(game: game)
                } else {
                    CraftedFoodListView(game: game)
                }

                // Bottom buttons
                HStack(spacing: 8) {
                    if !showCrafting {
                        Button {
                            game.audio.play(.tap)
                            showCrafting = true
                        } label: {
                            Text("RECIPES")
                                .font(GrubFont.size(11))
                                .foregroundColor(GrubPalette.void_color)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(GrubPalette.green)
                        }

                        Button {
                            game.audio.play(.tap)
                            game.showInventoryOverlay = false
                            game.showBurrowOverlay = true
                        } label: {
                            Text("BURROW")
                                .font(GrubFont.size(11))
                                .foregroundColor(GrubPalette.void_color)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(GrubPalette.yellow)
                        }
                    }

                    Button {
                        game.audio.play(.tap)
                        if showCrafting { showCrafting = false }
                        else { game.showInventoryOverlay = false }
                    } label: {
                        Text(showCrafting ? "BACK" : "CLOSE")
                            .font(GrubFont.size(11))
                            .foregroundColor(GrubPalette.green)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .overlay(Rectangle().stroke(GrubPalette.green, lineWidth: 2))
                    }
                }
                .padding(.top, 12)
            }
            .padding(20)
            .background(GrubPalette.void_color)
            .border(GrubPalette.green, width: 2)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
            .onTapGesture { } // Block taps from passing through to background
        }
        .transition(.opacity)
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(GrubFont.size(10))
                .foregroundColor(isSelected ? GrubPalette.void_color : GrubPalette.green)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? GrubPalette.green : GrubPalette.void_color)
                .border(GrubPalette.green, width: 1)
        }
    }
}

struct IngredientsGridView: View {
    @ObservedObject var game: GameState

    var body: some View {
        ScrollView {
            if game.ingredients.isEmpty {
                Text("NO INGREDIENTS\nGO FORAGE!")
                    .font(GrubFont.size(11))
                    .foregroundColor(GrubPalette.pale.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 24)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 56))], spacing: 10) {
                    ForEach(game.ingredients.sorted(by: { $0.key < $1.key }), id: \.key) { id, count in
                        VStack(spacing: 2) {
                            ZStack(alignment: .topTrailing) {
                                PixelIcon.ingredientIcon(id, size: 32)
                                Text("x\(count)")
                                    .font(GrubFont.size(7))
                                    .foregroundColor(GrubPalette.yellow)
                                    .offset(x: 4, y: -4)
                            }
                            Text(ingredientCatalog[id]?.name ?? "???")
                                .font(GrubFont.size(6))
                                .foregroundColor(rarityColor(ingredientCatalog[id]?.rarity ?? .common))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .frame(maxHeight: 200)
    }

    func rarityColor(_ rarity: Rarity) -> Color {
        switch rarity {
        case .common: return GrubPalette.pale
        case .uncommon: return GrubPalette.green
        case .rare: return GrubPalette.yellow
        }
    }
}

struct CraftedFoodListView: View {
    @ObservedObject var game: GameState

    var body: some View {
        ScrollView {
            if game.craftedItems.isEmpty {
                Text("NO FOOD!\nCRAFT SOME.")
                    .font(GrubFont.size(11))
                    .foregroundColor(GrubPalette.pale.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 8) {
                    ForEach(game.craftedItems.sorted(by: { $0.key < $1.key }), id: \.key) { id, count in
                        if let recipe = recipeCatalog[id] {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(recipe.name)
                                        .font(GrubFont.size(10))
                                        .foregroundColor(GrubPalette.pale)
                                    craftedEffectsText(recipe.effects)
                                }
                                Spacer()
                                Text("x\(count)")
                                    .font(GrubFont.size(10))
                                    .foregroundColor(GrubPalette.yellow)
                                Button {
                                    game.useCraftedItem(id)
                                } label: {
                                    Text("USE")
                                        .font(GrubFont.size(9))
                                        .foregroundColor(GrubPalette.void_color)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(GrubPalette.green)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(GrubPalette.moss)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: 200)
    }

    func craftedEffectsText(_ effects: StatEffects) -> some View {
        let parts = [
            effects.hunger > 0 ? "+\(effects.hunger) HNG" : nil,
            effects.happiness > 0 ? "+\(effects.happiness) HAP" : nil,
            effects.health > 0 ? "+\(effects.health) HP" : nil,
        ].compactMap { $0 }
        return Text(parts.joined(separator: " "))
            .font(GrubFont.size(7))
            .foregroundColor(GrubPalette.green.opacity(0.7))
    }
}

struct CraftingListView: View {
    @ObservedObject var game: GameState
    @Binding var showCrafting: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("RECIPES")
                    .font(GrubFont.size(12))
                    .foregroundColor(GrubPalette.green)
                    .padding(.bottom, 4)

                ForEach(game.sortedRecipes(), id: \.id) { id, def, craftable in
                    RecipeRow(game: game, recipeId: id, def: def, craftable: craftable)
                }

                let locked = game.lockedRecipes()
                if !locked.isEmpty {
                    Text("LOCKED")
                        .font(GrubFont.size(10))
                        .foregroundColor(GrubPalette.pale.opacity(0.4))
                        .padding(.top, 8)

                    ForEach(locked, id: \.id) { id, def in
                        HStack {
                            Text(def.name)
                                .font(GrubFont.size(9))
                                .foregroundColor(GrubPalette.pale.opacity(0.3))
                            Spacer()
                            if case .level(let lvl) = def.unlockType {
                                Text("LVL \(lvl) (YOU: \(game.ownerLevel))")
                                    .font(GrubFont.size(7))
                                    .foregroundColor(GrubPalette.yellow.opacity(0.5))
                            } else if case .scroll = def.unlockType {
                                Text("SCROLL")
                                    .font(GrubFont.size(7))
                                    .foregroundColor(GrubPalette.purple.opacity(0.5))
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .frame(maxHeight: 250)
    }
}

struct RecipeRow: View {
    @ObservedObject var game: GameState
    let recipeId: String
    let def: RecipeDef
    let craftable: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(def.name)
                    .font(GrubFont.size(10))
                    .foregroundColor(craftable ? GrubPalette.pale : GrubPalette.pale.opacity(0.5))
                Spacer()
                if craftable {
                    Button {
                        game.craft(recipeId)
                    } label: {
                        Text("CRAFT")
                            .font(GrubFont.size(9))
                            .foregroundColor(GrubPalette.void_color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(GrubPalette.green)
                    }
                }
            }
            // Ingredient list
            HStack(spacing: 6) {
                ForEach(def.ingredients, id: \.id) { req in
                    let have = game.ingredients[req.id] ?? 0
                    HStack(spacing: 2) {
                        PixelIcon.ingredientIcon(req.id, size: 20)
                        Text("\(have)/\(req.quantity)")
                            .font(GrubFont.size(7))
                            .foregroundColor(have >= req.quantity ? GrubPalette.green : GrubPalette.red)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(GrubPalette.moss.opacity(craftable ? 1 : 0.5))
        .border(craftable ? GrubPalette.green : GrubPalette.deepMoss, width: 1)
    }
}
