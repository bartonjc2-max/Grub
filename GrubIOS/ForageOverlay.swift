import SwiftUI

struct ForageOverlayView: View {
    @ObservedObject var game: GameState

    var body: some View {
        ZStack {
            Color(hex: "#1a1a2e").opacity(0.93)
                .ignoresSafeArea()
                .onTapGesture { game.showForageOverlay = false }

            VStack(spacing: 0) {
                Text("FORAGE")
                    .font(GrubFont.size(14))
                    .foregroundColor(GrubPalette.green)
                    .tracking(2)
                    .padding(.bottom, 16)

                if !game.canForage {
                    Text("COOLDOWN: \(game.forageTimeRemaining)m")
                        .font(GrubFont.size(11))
                        .foregroundColor(GrubPalette.yellow)
                        .padding(.bottom, 12)
                }

                VStack(spacing: 10) {
                    ForageAreaButton(area: .shallowCave, enabled: game.canForage) {
                        game.forage(area: .shallowCave)
                    }
                    ForageAreaButton(area: .deepBurrow, enabled: game.canForage) {
                        game.forage(area: .deepBurrow)
                    }
                    ForageAreaButton(area: .surface, enabled: game.canForage) {
                        game.forage(area: .surface)
                    }
                }

                Button {
                    game.audio.play(.tap)
                    game.showForageOverlay = false
                } label: {
                    Text("CLOSE")
                        .font(GrubFont.size(11))
                        .foregroundColor(GrubPalette.green)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .overlay(Rectangle().stroke(GrubPalette.green, lineWidth: 2))
                }
                .padding(.top, 16)
            }
            .padding(24)
            .background(GrubPalette.void_color)
            .border(GrubPalette.green, width: 2)
            .padding(.horizontal, 24)
        }
        .transition(.opacity)
    }
}

struct ForageAreaButton: View {
    let area: ForageArea
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(area.rawValue)
                    .font(GrubFont.size(11))
                    .foregroundColor(enabled ? GrubPalette.pale : GrubPalette.pale.opacity(0.4))
                Text(area.description)
                    .font(GrubFont.size(8))
                    .foregroundColor(enabled ? GrubPalette.green.opacity(0.7) : GrubPalette.pale.opacity(0.3))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(GrubPalette.moss)
            .border(enabled ? GrubPalette.green : GrubPalette.deepMoss, width: 2)
        }
        .disabled(!enabled)
        .buttonStyle(PixelButtonStyle())
    }
}

struct ForageResultsView: View {
    @ObservedObject var game: GameState

    var body: some View {
        ZStack {
            Color(hex: "#1a1a2e").opacity(0.93)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("GRUB FOUND")
                    .font(GrubFont.size(14))
                    .foregroundColor(GrubPalette.green)
                    .tracking(2)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 12) {
                    ForEach(Array(game.forageResults.enumerated()), id: \.offset) { _, itemId in
                        VStack(spacing: 4) {
                            PixelIcon.ingredientIcon(itemId, size: 28)
                            Text(ingredientCatalog[itemId]?.name ?? "???")
                                .font(GrubFont.size(6))
                                .foregroundColor(GrubPalette.pale)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding(.horizontal, 8)

                Button {
                    game.audio.play(.tap)
                    game.showForageResults = false
                    game.forageResults = []
                } label: {
                    Text("COLLECT")
                        .font(GrubFont.size(11))
                        .foregroundColor(GrubPalette.void_color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(GrubPalette.green)
                }
                .padding(.top, 8)
            }
            .padding(24)
            .background(GrubPalette.void_color)
            .border(GrubPalette.green, width: 2)
            .padding(.horizontal, 24)
        }
        .transition(.opacity)
    }
}
