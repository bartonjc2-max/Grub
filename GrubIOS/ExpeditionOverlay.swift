import SwiftUI

struct ExpeditionOverlayView: View {
    @ObservedObject var game: GameState

    var body: some View {
        ZStack {
            GrubPalette.void_color.opacity(0.9).ignoresSafeArea()
                .onTapGesture { game.showExpeditionOverlay = false }

            VStack(spacing: 0) {
                HStack {
                    Text("EXPEDITIONS")
                        .font(GrubFont.size(14))
                        .foregroundColor(GrubPalette.green)
                    Spacer()
                    Button("X") { game.showExpeditionOverlay = false }
                        .font(GrubFont.size(14))
                        .foregroundColor(GrubPalette.red)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(GrubPalette.moss)

                Rectangle().fill(GrubPalette.green).frame(height: 2)

                if game.isOnExpedition {
                    // Active expedition status
                    VStack(spacing: 12) {
                        let def = expeditionCatalog[game.activeExpeditionId]
                        Text(def?.name ?? "EXPLORING...")
                            .font(GrubFont.size(12))
                            .foregroundColor(GrubPalette.yellow)

                        // animTick dependency forces redraw every frame for live countdown
                    let _ = game.animTick
                    Text(game.expeditionTimeString)
                            .font(GrubFont.size(18))
                            .foregroundColor(game.isExpeditionComplete ? GrubPalette.green : GrubPalette.pale)

                        if game.isExpeditionComplete {
                            Button("COLLECT LOOT") {
                                game.audio.play(.lootSparkle)
                                game.collectExpedition()
                                game.showExpeditionOverlay = false
                            }
                            .font(GrubFont.size(11))
                            .foregroundColor(GrubPalette.void_color)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(GrubPalette.green)
                        } else {
                            Text("GRUB IS EXPLORING...")
                                .font(GrubFont.size(9))
                                .foregroundColor(GrubPalette.pale.opacity(0.5))
                        }
                    }
                    .padding(20)
                } else {
                    // Expedition selection
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(expeditionsSorted, id: \.id) { def in
                                ExpeditionRow(game: game, def: def)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 40)
        }
    }
}

struct ExpeditionRow: View {
    @ObservedObject var game: GameState
    let def: ExpeditionDef

    var unlocked: Bool { game.ownerLevel >= def.unlockLevel }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(def.name)
                    .font(GrubFont.size(10))
                    .foregroundColor(unlocked ? GrubPalette.pale : GrubPalette.pale.opacity(0.3))

                Text(def.description)
                    .font(GrubFont.size(7))
                    .foregroundColor(GrubPalette.pale.opacity(0.5))

                HStack(spacing: 8) {
                    Text("\(def.durationMinutes)M")
                        .font(GrubFont.size(7))
                        .foregroundColor(GrubPalette.yellow)
                    let cost = GameState.expeditionCost(durationMinutes: def.durationMinutes)
                    Text("-\(cost.hunger) HNG")
                        .font(GrubFont.size(7))
                        .foregroundColor(GrubPalette.orange)
                    Text("-\(cost.happiness) HAP")
                        .font(GrubFont.size(7))
                        .foregroundColor(GrubPalette.orange)
                    if def.riskChance > 0 {
                        Text("RISK: \(Int(def.riskChance * 100))%")
                            .font(GrubFont.size(7))
                            .foregroundColor(GrubPalette.red)
                    }
                }
                HStack(spacing: 8) {
                    Text("+\(def.xpReward) XP")
                        .font(GrubFont.size(7))
                        .foregroundColor(GrubPalette.green)
                    Text("\(def.lootCount.lowerBound)-\(def.lootCount.upperBound) ITEMS")
                        .font(GrubFont.size(7))
                        .foregroundColor(GrubPalette.green)
                }
            }

            Spacer()

            if unlocked {
                Button("GO") {
                    game.audio.play(.expeditionGo)
                    game.startExpedition(def.id)
                }
                .font(GrubFont.size(10))
                .foregroundColor(GrubPalette.void_color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(GrubPalette.green)
            } else {
                Text("LVL \(def.unlockLevel)")
                    .font(GrubFont.size(8))
                    .foregroundColor(GrubPalette.pale.opacity(0.3))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(GrubPalette.void_color)
        .overlay(
            Rectangle().fill(GrubPalette.deepMoss).frame(height: 1),
            alignment: .bottom
        )
    }
}

struct ExpeditionResultsView: View {
    @ObservedObject var game: GameState

    var body: some View {
        ZStack {
            GrubPalette.void_color.opacity(0.9).ignoresSafeArea()

            VStack(spacing: 12) {
                Text("EXPEDITION COMPLETE!")
                    .font(GrubFont.size(12))
                    .foregroundColor(GrubPalette.green)

                Rectangle().fill(GrubPalette.green).frame(height: 2)

                // Loot grid
                let items = game.expeditionResults.filter { !$0.hasPrefix("RISK:") && !$0.hasPrefix("SCROLL:") }
                let scrolls = game.expeditionResults.filter { $0.hasPrefix("SCROLL:") }
                let risks = game.expeditionResults.filter { $0.hasPrefix("RISK:") }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                    ForEach(items, id: \.self) { itemId in
                        VStack(spacing: 4) {
                            PixelIcon.ingredientIcon(itemId, size: 36)
                            Text(ingredientCatalog[itemId]?.name ?? itemId)
                                .font(GrubFont.size(7))
                                .foregroundColor(GrubPalette.pale)
                                .lineLimit(1)
                        }
                        .padding(6)
                        .background(GrubPalette.moss.opacity(0.3))
                    }
                }
                .padding(.horizontal, 16)

                // Scroll unlocks
                ForEach(scrolls, id: \.self) { scroll in
                    let name = String(scroll.dropFirst(7))
                    Text("RECIPE UNLOCKED: \(name)")
                        .font(GrubFont.size(9))
                        .foregroundColor(GrubPalette.yellow)
                }

                // Risk messages
                ForEach(risks, id: \.self) { risk in
                    let msg = String(risk.dropFirst(5))
                    Text(msg)
                        .font(GrubFont.size(9))
                        .foregroundColor(GrubPalette.red)
                }

                Button("OK") {
                    game.audio.play(.menuClose)
                    game.showExpeditionResults = false
                }
                .font(GrubFont.size(11))
                .foregroundColor(GrubPalette.void_color)
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(GrubPalette.green)
            }
            .padding(20)
        }
    }
}
