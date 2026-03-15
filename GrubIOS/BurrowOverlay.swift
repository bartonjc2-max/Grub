import SwiftUI

struct BurrowOverlayView: View {
    @ObservedObject var game: GameState

    var body: some View {
        ZStack {
            GrubPalette.void_color.opacity(0.9).ignoresSafeArea()
                .onTapGesture { game.showBurrowOverlay = false }

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("BURROW")
                        .font(GrubFont.size(14))
                        .foregroundColor(GrubPalette.green)
                    Spacer()
                    Text("\(game.placedDecorations.count)/12")
                        .font(GrubFont.size(10))
                        .foregroundColor(GrubPalette.pale)
                    Spacer()
                    Button("X") { game.showBurrowOverlay = false }
                        .font(GrubFont.size(14))
                        .foregroundColor(GrubPalette.red)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(GrubPalette.moss)

                Rectangle().fill(GrubPalette.green).frame(height: 2)

                // Decoration list
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(game.sortedDecorations(), id: \.id) { item in
                            DecorationRow(game: game, id: item.id, def: item.def,
                                        placed: item.placed, craftable: item.craftable)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 40)
        }
    }
}

struct DecorationRow: View {
    @ObservedObject var game: GameState
    let id: String
    let def: DecorationDef
    let placed: Bool
    let craftable: Bool

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(def.name)
                        .font(GrubFont.size(10))
                        .foregroundColor(placed ? GrubPalette.green : GrubPalette.pale)
                    Text("[\(def.slot.rawValue.uppercased())]")
                        .font(GrubFont.size(7))
                        .foregroundColor(GrubPalette.pale.opacity(0.4))
                }

                Text(def.bonusType.rawValue.uppercased())
                    .font(GrubFont.size(7))
                    .foregroundColor(GrubPalette.yellow.opacity(0.7))

                // Ingredients needed
                HStack(spacing: 4) {
                    ForEach(def.ingredients, id: \.id) { req in
                        let have = game.ingredients[req.id] ?? 0
                        let enough = have >= req.quantity
                        Text("\(ingredientCatalog[req.id]?.name ?? req.id) x\(req.quantity)")
                            .font(GrubFont.size(6))
                            .foregroundColor(enough ? GrubPalette.green : GrubPalette.red.opacity(0.7))
                    }
                }
            }

            Spacer()

            if placed {
                Button("REMOVE") {
                    game.audio.play(.tap)
                    game.removeDecoration(id)
                }
                .font(GrubFont.size(8))
                .foregroundColor(GrubPalette.void_color)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(GrubPalette.red)
            } else {
                Button("BUILD") {
                    game.audio.play(.tap)
                    game.buildDecoration(id)
                }
                .font(GrubFont.size(8))
                .foregroundColor(GrubPalette.void_color)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(craftable ? GrubPalette.green : GrubPalette.moss)
                .disabled(!craftable)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(placed ? GrubPalette.moss.opacity(0.3) : GrubPalette.void_color)
        .overlay(
            Rectangle().fill(GrubPalette.deepMoss).frame(height: 1),
            alignment: .bottom
        )
    }
}
