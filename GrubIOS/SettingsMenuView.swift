import SwiftUI

struct SettingsMenuView: View {
    @ObservedObject var game: GameState
    @State private var showResetConfirm = false

    var body: some View {
        ZStack {
            GrubPalette.void_color.opacity(0.9).ignoresSafeArea()
                .onTapGesture { game.showSettingsMenu = false }

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("SETTINGS")
                        .font(GrubFont.size(14))
                        .foregroundColor(GrubPalette.green)
                    Spacer()
                    Button("X") { game.showSettingsMenu = false }
                        .font(GrubFont.size(14))
                        .foregroundColor(GrubPalette.red)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(GrubPalette.moss)

                Rectangle().fill(GrubPalette.green).frame(height: 2)

                // SOUND row
                HStack {
                    Text("SOUND")
                        .font(GrubFont.size(11))
                        .foregroundColor(GrubPalette.pale)
                    Spacer()
                    Button(game.soundEnabled ? "ON" : "OFF") {
                        game.soundEnabled.toggle()
                        game.audio.enabled = game.soundEnabled
                        game.audio.play(.tap)
                        game.save()
                    }
                    .font(GrubFont.size(11))
                    .foregroundColor(GrubPalette.void_color)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(game.soundEnabled ? GrubPalette.green : GrubPalette.pale.opacity(0.3))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(GrubPalette.void_color)
                .overlay(
                    Rectangle().fill(GrubPalette.deepMoss).frame(height: 1),
                    alignment: .bottom
                )

                // RESET GRUB row
                if showResetConfirm {
                    VStack(spacing: 8) {
                        Text("ARE YOU SURE?")
                            .font(GrubFont.size(11))
                            .foregroundColor(GrubPalette.red)

                        HStack(spacing: 16) {
                            Button("YES") {
                                game.restartGame()
                                game.showSettingsMenu = false
                            }
                            .font(GrubFont.size(11))
                            .foregroundColor(GrubPalette.void_color)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(GrubPalette.red)

                            Button("NO") {
                                showResetConfirm = false
                            }
                            .font(GrubFont.size(11))
                            .foregroundColor(GrubPalette.void_color)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(GrubPalette.green)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(GrubPalette.void_color)
                    .overlay(
                        Rectangle().fill(GrubPalette.deepMoss).frame(height: 1),
                        alignment: .bottom
                    )
                } else {
                    HStack {
                        Button("RESET GRUB") {
                            showResetConfirm = true
                        }
                        .font(GrubFont.size(11))
                        .foregroundColor(GrubPalette.red)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(GrubPalette.void_color)
                    .overlay(
                        Rectangle().fill(GrubPalette.deepMoss).frame(height: 1),
                        alignment: .bottom
                    )
                }

                // CREDITS row
                VStack(spacing: 4) {
                    Text("CREDITS")
                        .font(GrubFont.size(11))
                        .foregroundColor(GrubPalette.pale)
                    Text("MADE BY JESSE")
                        .font(GrubFont.size(9))
                        .foregroundColor(GrubPalette.pale.opacity(0.5))
                    Text("V1.0")
                        .font(GrubFont.size(9))
                        .foregroundColor(GrubPalette.pale.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(GrubPalette.void_color)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 40)
        }
    }
}
