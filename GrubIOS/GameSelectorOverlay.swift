import SwiftUI

struct GameSelectorOverlayView: View {
    @ObservedObject var game: GameState

    var body: some View {
        ZStack {
            Color(hex: "#1a1a2e").opacity(0.93)
                .ignoresSafeArea()
                .onTapGesture { game.showGameSelector = false }

            VStack(spacing: 0) {
                Text("ARCADE")
                    .font(GrubFont.size(14))
                    .foregroundColor(GrubPalette.green)
                    .tracking(2)
                    .padding(.bottom, 4)

                if game.winStreak > 0 {
                    Text("WIN STREAK: \(game.winStreak)")
                        .font(GrubFont.size(9))
                        .foregroundColor(GrubPalette.yellow)
                        .padding(.bottom, 8)
                }

                VStack(spacing: 8) {
                    ForEach(MinigameType.allCases, id: \.rawValue) { gameType in
                        let unlocked = game.isGameUnlocked(gameType)
                        Button {
                            if unlocked { game.openGame(gameType) }
                        } label: {
                            HStack {
                                Text(gameType.name)
                                    .font(GrubFont.size(11))
                                    .foregroundColor(unlocked ? GrubPalette.pale : GrubPalette.pale.opacity(0.3))
                                Spacer()
                                if unlocked {
                                    if let hs = game.highScores[gameType.rawValue] {
                                        Text("BEST: \(hs)")
                                            .font(GrubFont.size(8))
                                            .foregroundColor(GrubPalette.yellow)
                                    }
                                } else {
                                    Text("LVL \(gameType.unlockLevel)")
                                        .font(GrubFont.size(8))
                                        .foregroundColor(GrubPalette.pale.opacity(0.3))
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(unlocked ? GrubPalette.moss : GrubPalette.void_color)
                            .border(unlocked ? GrubPalette.green : GrubPalette.deepMoss, width: 2)
                        }
                        .disabled(!unlocked)
                        .buttonStyle(PixelButtonStyle())
                    }
                }

                Button {
                    game.audio.play(.tap)
                    game.showGameSelector = false
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
