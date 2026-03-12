import SwiftUI

struct ContentView: View {
    @StateObject private var game = GameState()
    @State private var showStats = false

    var body: some View {
        ZStack {
            // Full-screen background
            GrubPalette.void_color.ignoresSafeArea()

            VStack(spacing: 0) {
                // Safe area top fill
                GrubPalette.moss.ignoresSafeArea(edges: .top)
                    .frame(height: 0)

                TopBarView(game: game, showStats: $showStats)
                ViewportView(game: game)
                PetInfoBar(game: game)
                StatBarsView(game: game)
                ActionButtonsView(game: game)

                // Safe area bottom fill
                GrubPalette.moss.ignoresSafeArea(edges: .bottom)
                    .frame(height: 0)
            }

            // Overlays
            if game.showEventOverlay {
                EventOverlayView(game: game)
            }
            if game.showFeedOverlay {
                FeedOverlayView(game: game)
            }
            if game.showMinigame {
                MinigameOverlayView(game: game)
                    .ignoresSafeArea()
            }
            if game.showEvolution {
                EvolutionOverlayView(game: game)
                    .ignoresSafeArea()
            }
            if game.showDeathOverlay {
                DeathOverlayView(game: game)
                    .ignoresSafeArea()
            }
            if game.showNameEntry {
                NameEntryView(game: game)
                    .ignoresSafeArea()
            }
            if showStats {
                StatsMenuView(game: game, isShowing: $showStats)
            }

            // Scanline overlay (above everything, non-interactive)
            ScanlineOverlay()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            if game.showToast {
                ToastView(message: game.toastMessage)
                    .allowsHitTesting(false)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            game.onBackground()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            game.onForeground()
        }
        .statusBarHidden()
    }
}

// MARK: - Top Bar
struct TopBarView: View {
    @ObservedObject var game: GameState
    @Binding var showStats: Bool

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                PixelIcon.star(size: 20)
                Text("LVL")
                    .font(GrubFont.size(13))
                    .foregroundColor(GrubPalette.pale)
                Text("\(game.ownerLevel)")
                    .font(GrubFont.size(13))
                    .foregroundColor(GrubPalette.green)
            }

            Spacer()

            Button {
                game.audio.play(.tap)
                showStats = true
            } label: {
                HStack(spacing: 8) {
                    PixelIcon.statsIcon(size: 18)
                    Text(game.name.isEmpty ? "GRUB" : game.name)
                        .font(GrubFont.size(13))
                        .foregroundColor(GrubPalette.green)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                PixelIcon.coin(size: 20)
                Text("\(game.crumbs)")
                    .font(GrubFont.size(13))
                    .foregroundColor(GrubPalette.yellow)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(GrubPalette.moss.ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(GrubPalette.green)
                .frame(height: 2)
        }
    }
}

// MARK: - Viewport
struct ViewportView: View {
    @ObservedObject var game: GameState

    var body: some View {
        Canvas { context, size in
            SpriteRenderer.drawBackground(context: &context, size: size, isNight: game.isNight)

            // Pet sprite — scale to fill viewport nicely
            let sprite = SpriteRenderer.makeGrubSprite(state: game.currentPetAnim, tick: game.animTick)
            let scale = min(size.width, size.height) / 32.0 * 0.7
            let petX = size.width / 2 - 16 * scale
            let petY = size.height * 0.45 - 16 * scale
            SpriteRenderer.drawSprite(context: &context, sprite: sprite, origin: CGPoint(x: petX, y: petY), scale: scale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .onTapGesture {
            game.audio.play(.tap)
        }
    }
}

// MARK: - Pet Info Bar
struct PetInfoBar: View {
    @ObservedObject var game: GameState

    var body: some View {
        HStack {
            Text(game.name.isEmpty ? "???" : game.name)
                .font(GrubFont.size(13))
                .foregroundColor(GrubPalette.green)

            Spacer()

            Text("AGE: \(game.ageDays)D")
                .font(GrubFont.size(11))
                .foregroundColor(GrubPalette.pale.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(GrubPalette.moss)
        .overlay(alignment: .top) {
            Rectangle().fill(GrubPalette.green).frame(height: 2)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(GrubPalette.deepMoss).frame(height: 1)
        }
    }
}

// MARK: - Stat Bars
struct StatBarsView: View {
    @ObservedObject var game: GameState

    var body: some View {
        VStack(spacing: 6) {
            StatBarRow(label: "HNG", value: game.hunger, color: game.hunger > 50 ? GrubPalette.green : game.hunger > 20 ? GrubPalette.yellow : GrubPalette.red, isCritical: game.hunger < 20)
            StatBarRow(label: "HAP", value: game.happiness, color: game.happiness > 50 ? GrubPalette.purple : game.happiness > 20 ? GrubPalette.yellow : GrubPalette.red, isCritical: game.happiness < 20)
            StatBarRow(label: "HP", value: game.health, color: game.health > 50 ? GrubPalette.green : game.health > 20 ? GrubPalette.yellow : GrubPalette.red, isCritical: game.health < 20)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(GrubPalette.void_color)
        .overlay(alignment: .bottom) {
            Rectangle().fill(GrubPalette.deepMoss).frame(height: 1)
        }
    }
}

struct StatBarRow: View {
    let label: String
    let value: Int
    let color: Color
    let isCritical: Bool

    @State private var pulseOpacity: Double = 1.0

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(GrubFont.size(11))
                .foregroundColor(GrubPalette.pale.opacity(0.8))
                .frame(width: 42, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(GrubPalette.moss)
                        .border(GrubPalette.deepMoss, width: 1)

                    Rectangle()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(max(0, value)) / 100)
                        .opacity(isCritical ? pulseOpacity : 1)
                        .overlay(alignment: .top) {
                            Rectangle()
                                .fill(Color.white.opacity(0.25))
                                .frame(height: 2)
                        }
                }
            }
            .frame(height: 18)

            Text("\(value)")
                .font(GrubFont.size(11))
                .foregroundColor(GrubPalette.pale)
                .frame(width: 40, alignment: .trailing)
        }
        .onChange(of: isCritical) { _, crit in
            if crit {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    pulseOpacity = 0.3
                }
            } else {
                pulseOpacity = 1.0
            }
        }
    }
}

// MARK: - Action Buttons
struct ActionButtonsView: View {
    @ObservedObject var game: GameState

    var body: some View {
        HStack(spacing: 0) {
            ActionButton(icon: { AnyView(PixelIcon.meat(size: 34)) }, label: "FEED", borderColor: GrubPalette.green) {
                game.audio.play(.tap)
                game.showFeedOverlay = true
            }

            ActionButton(icon: { AnyView(PixelIcon.gamepad(size: 34)) }, label: "PLAY", borderColor: GrubPalette.green) {
                game.openPlay()
            }

            ActionButton(icon: { AnyView(PixelIcon.pill(size: 34)) }, label: "MEDS", borderColor: GrubPalette.red) {
                game.audio.play(.tap)
                game.giveMedicine()
            }
            .opacity(game.isMedicineOnCooldown ? 0.4 : 1.0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(GrubPalette.moss.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle().fill(GrubPalette.green).frame(height: 2)
        }
    }
}

struct ActionButton: View {
    let icon: () -> AnyView
    let label: String
    let borderColor: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                icon()
                Text(label)
                    .font(GrubFont.size(11))
                    .foregroundColor(isPressed ? GrubPalette.void_color : GrubPalette.pale)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(isPressed ? borderColor : GrubPalette.void_color)
            .border(borderColor, width: 2)
        }
        .buttonStyle(PixelButtonStyle())
    }
}

struct PixelButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// MARK: - Toast
struct ToastView: View {
    let message: String

    var body: some View {
        VStack {
            Text(message)
                .font(GrubFont.size(12))
                .foregroundColor(GrubPalette.void_color)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(GrubPalette.green)
                .padding(.top, 60)

            Spacer()
        }
        .allowsHitTesting(false)
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.easeInOut(duration: 0.3), value: message)
    }
}
