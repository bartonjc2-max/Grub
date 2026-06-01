import SwiftUI

// MARK: - Feed Overlay
struct FeedOverlayView: View {
    @ObservedObject var game: GameState

    var body: some View {
        ZStack {
            Color(hex: "#1a1a2e").opacity(0.93)
                .ignoresSafeArea()
                .onTapGesture { game.showFeedOverlay = false }

            VStack(spacing: 0) {
                Text("FEED GRUB")
                    .font(GrubFont.size(14))
                    .foregroundColor(GrubPalette.green)
                    .tracking(2)
                    .padding(.bottom, 20)

                ScrollView {
                    if game.craftedItems.isEmpty {
                        Text("NO FOOD!\nCRAFT SOME IN\nINVENTORY.")
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
                                                .font(GrubFont.size(9))
                                                .foregroundColor(GrubPalette.pale)
                                            feedEffectsText(recipe.effects)
                                        }
                                        Spacer()
                                        Text("x\(count)")
                                            .font(GrubFont.size(9))
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
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(GrubPalette.moss)
                                    .border(GrubPalette.deepMoss, width: 2)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)

                Button {
                    game.audio.play(.tap)
                    game.showFeedOverlay = false
                } label: {
                    Text("CLOSE")
                        .font(GrubFont.size(11))
                        .foregroundColor(GrubPalette.green)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .overlay(
                            Rectangle().stroke(GrubPalette.green, lineWidth: 2)
                        )
                }
                .padding(.top, 16)
            }
            .padding(24)
            .background(GrubPalette.void_color)
            .border(GrubPalette.green, width: 2)
            .padding(.horizontal, 30)
        }
        .transition(.opacity)
    }

    private func feedEffectsText(_ effects: StatEffects) -> some View {
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

// MARK: - Event Overlay
struct EventOverlayView: View {
    @ObservedObject var game: GameState

    var body: some View {
        VStack {
            VStack(spacing: 0) {
                if let event = game.pendingEvent {
                    Text(event.text)
                        .font(GrubFont.size(11))
                        .foregroundColor(GrubPalette.pale)
                        .lineSpacing(8)
                        .padding(.bottom, 14)

                    HStack(spacing: 10) {
                        Button {
                            game.resolveEvent(choice: 0)
                        } label: {
                            Text(event.optionA.label)
                                .font(GrubFont.size(9))
                                .foregroundColor(GrubPalette.yellow)
                                .multilineTextAlignment(.center)
                                .lineSpacing(6)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 8)
                                .background(GrubPalette.moss)
                                .border(GrubPalette.yellow, width: 2)
                        }

                        Button {
                            game.resolveEvent(choice: 1)
                        } label: {
                            Text(event.optionB.label)
                                .font(GrubFont.size(9))
                                .foregroundColor(GrubPalette.yellow)
                                .multilineTextAlignment(.center)
                                .lineSpacing(6)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 8)
                                .background(GrubPalette.moss)
                                .border(GrubPalette.yellow, width: 2)
                        }
                    }
                }
            }
            .padding(16)
            .background(GrubPalette.void_color)
            .overlay(alignment: .bottom) {
                Rectangle().fill(GrubPalette.yellow).frame(height: 2)
            }

            Spacer()
        }
        .transition(.move(edge: .top))
        .animation(.easeOut(duration: 0.2), value: game.showEventOverlay)
    }
}

// MARK: - Minigame Overlay
struct MinigameOverlayView: View {
    @ObservedObject var game: GameState

    private var gameName: String {
        switch game.mgGame {
        case 0: return "DODGE"
        case 1: return "FEED ME"
        case 2: return "MEMORY"
        case 3: return "BUG CATCH"
        case 4: return "RHYTHM"
        default: return "MINI-GAME"
        }
    }

    private var isRoundBased: Bool {
        game.mgGame == 0 || game.mgGame == 1
    }

    var body: some View {
        ZStack {
            GrubPalette.void_color.ignoresSafeArea()

            VStack(spacing: 14) {
                Text(gameName)
                    .font(GrubFont.size(14))
                    .foregroundColor(GrubPalette.green)
                    .tracking(2)

                if isRoundBased {
                    HStack(spacing: 0) {
                        Text("ROUND \(game.mgRound)/5")
                            .font(GrubFont.size(9))
                            .foregroundColor(GrubPalette.pale)
                        Text("  |  ")
                            .font(GrubFont.size(9))
                            .foregroundColor(GrubPalette.pale.opacity(0.5))
                        Text("\(game.mgWins) WINS")
                            .font(GrubFont.size(9))
                            .foregroundColor(GrubPalette.pale)
                    }
                } else if game.mgGame == 3 {
                    Text("TIME: \(String(format: "%.1f", max(0, game.mgBugTimeLeft)))s  |  CAUGHT: \(game.mgBugScore)/8")
                        .font(GrubFont.size(9))
                        .foregroundColor(GrubPalette.pale)
                } else if game.mgGame == 2 {
                    Text("PAIRS: \(game.mgWins)/6  |  FLIPS: \(game.mgMemoryFlips)")
                        .font(GrubFont.size(9))
                        .foregroundColor(GrubPalette.pale)
                } else if game.mgGame == 4 {
                    Text("ROUND: \(game.mgWins + 1)")
                        .font(GrubFont.size(9))
                        .foregroundColor(GrubPalette.pale)
                }

                Text(game.mgPrompt)
                    .font(GrubFont.size(10))
                    .foregroundColor(GrubPalette.yellow)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 36)

                // Game-specific canvas
                if game.mgGame == 2 {
                    MemoryCardGridView(game: game)
                } else if game.mgGame == 3 {
                    BugCatchCanvasView(game: game)
                        .frame(width: 260, height: 200)
                        .border(GrubPalette.green, width: 2)
                } else {
                    MinigameCanvasView(game: game)
                        .frame(width: 260, height: 160)
                        .border(GrubPalette.green, width: 2)
                }

                // Game-specific controls
                if game.mgGame == 0 {
                    // Dodge controls
                    HStack(spacing: 16) {
                        Button {
                            game.mgChoice(side: "left")
                        } label: {
                            HStack(spacing: 8) {
                                PixelIcon.arrowLeft(size: 16)
                                Text("LEFT")
                                    .font(GrubFont.size(12))
                                    .foregroundColor(GrubPalette.pale)
                            }
                            .frame(minWidth: 110)
                            .padding(.vertical, 18)
                            .padding(.horizontal, 16)
                            .background(GrubPalette.moss)
                            .border(GrubPalette.green, width: 2)
                        }

                        Button {
                            game.mgChoice(side: "right")
                        } label: {
                            HStack(spacing: 8) {
                                Text("RIGHT")
                                    .font(GrubFont.size(12))
                                    .foregroundColor(GrubPalette.pale)
                                PixelIcon.arrowRight(size: 16)
                            }
                            .frame(minWidth: 110)
                            .padding(.vertical, 18)
                            .padding(.horizontal, 16)
                            .background(GrubPalette.moss)
                            .border(GrubPalette.green, width: 2)
                        }
                    }
                } else if game.mgGame == 1 {
                    // Feed Me controls
                    HStack(spacing: 14) {
                        ForEach(0..<3, id: \.self) { idx in
                            Button {
                                game.mgFoodChoice(index: idx)
                            } label: {
                                Text(idx < game.mgFoodItems.count ? game.mgFoodItems[idx].uppercased() : "?")
                                    .font(GrubFont.size(8))
                                    .foregroundColor(GrubPalette.pale)
                                    .frame(minWidth: 60, minHeight: 50)
                                    .padding(8)
                                    .background(GrubPalette.moss)
                                    .border(GrubPalette.green, width: 2)
                            }
                        }
                    }
                } else if game.mgGame == 4 {
                    // Rhythm controls
                    RhythmButtonsView(game: game)
                }

                Text(game.mgResult)
                    .font(GrubFont.size(12))
                    .foregroundColor(game.mgResult.contains("CORRECT") || game.mgResult.contains("GREAT") || game.mgResult.contains("GOOD") ? GrubPalette.green : GrubPalette.red)
                    .frame(minHeight: 24)

                HStack(spacing: 12) {
                    if game.adManager.isRewardedReady && game.lastMinigameXP > 0 {
                        Button {
                            game.showRewardedAd(for: .doubleMinigameXP)
                        } label: {
                            HStack(spacing: 4) {
                                Text("\u{25B6}")
                                    .font(.system(size: 9))
                                Text("2X XP")
                                    .font(GrubFont.size(9))
                            }
                            .foregroundColor(GrubPalette.yellow)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .overlay(Rectangle().stroke(GrubPalette.yellow, lineWidth: 2))
                        }
                    }

                    Button {
                        game.closeMinigame()
                    } label: {
                        Text("EXIT")
                            .font(GrubFont.size(10))
                            .foregroundColor(GrubPalette.red)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .overlay(Rectangle().stroke(GrubPalette.red, lineWidth: 2))
                    }
                }
            }
            .padding(20)
        }
        .transition(.opacity)
    }
}

// MARK: - Memory Card Grid
struct MemoryCardGridView: View {
    @ObservedObject var game: GameState

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    private let symbolColors: [String: Color] = [
        "A": GrubPalette.green, "B": GrubPalette.yellow, "C": GrubPalette.red,
        "D": GrubPalette.purple, "E": GrubPalette.orange, "F": GrubPalette.pale,
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(0..<12, id: \.self) { idx in
                Button {
                    game.memoryFlip(index: idx)
                } label: {
                    ZStack {
                        if idx < game.mgMemoryMatched.count && game.mgMemoryMatched[idx] {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(GrubPalette.deepMoss)
                                .frame(height: 44)
                            Text(idx < game.mgMemoryCards.count ? game.mgMemoryCards[idx] : "?")
                                .font(GrubFont.size(14))
                                .foregroundColor((symbolColors[idx < game.mgMemoryCards.count ? game.mgMemoryCards[idx] : "A"] ?? GrubPalette.green).opacity(0.4))
                        } else if idx < game.mgMemoryRevealed.count && game.mgMemoryRevealed[idx] {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(GrubPalette.moss)
                                .frame(height: 44)
                            Text(idx < game.mgMemoryCards.count ? game.mgMemoryCards[idx] : "?")
                                .font(GrubFont.size(14))
                                .foregroundColor(symbolColors[idx < game.mgMemoryCards.count ? game.mgMemoryCards[idx] : "A"] ?? GrubPalette.green)
                        } else {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(GrubPalette.moss)
                                .frame(height: 44)
                            Text("?")
                                .font(GrubFont.size(12))
                                .foregroundColor(GrubPalette.pale.opacity(0.3))
                        }
                    }
                }
                .disabled(idx < game.mgMemoryMatched.count && game.mgMemoryMatched[idx])
            }
        }
        .padding(.horizontal, 12)
    }
}

// MARK: - Bug Catch Canvas
struct BugCatchCanvasView: View {
    @ObservedObject var game: GameState

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Canvas { context, size in
                    context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(GrubPalette.moss))
                }

                ForEach(0..<game.mgBugs.count, id: \.self) { idx in
                    if !game.mgBugs[idx].caught {
                        Circle()
                            .fill(idx % 3 == 0 ? GrubPalette.green : idx % 3 == 1 ? GrubPalette.yellow : GrubPalette.red)
                            .frame(width: 20, height: 20)
                            .position(
                                x: game.mgBugs[idx].x * geo.size.width,
                                y: game.mgBugs[idx].y * geo.size.height
                            )
                            .onTapGesture {
                                game.catchBug(at: idx)
                            }
                    }
                }
            }
        }
    }
}

// MARK: - Rhythm Buttons
struct RhythmButtonsView: View {
    @ObservedObject var game: GameState

    private let buttonColors: [Color] = [GrubPalette.green, GrubPalette.yellow, GrubPalette.red, GrubPalette.purple]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { idx in
                Button {
                    game.rhythmTap(idx)
                } label: {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(buttonColors[idx])
                        .opacity(game.mgRhythmHighlight == idx ? 1.0 : 0.4)
                        .frame(width: 56, height: 56)
                        .border(game.mgRhythmHighlight == idx ? GrubPalette.pale : GrubPalette.deepMoss, width: 2)
                }
                .disabled(game.mgRhythmShowingSequence)
            }
        }
    }
}

struct MinigameCanvasView: View {
    @ObservedObject var game: GameState

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(GrubPalette.moss))

            if game.mgGame == 0 {
                let w = size.width
                let h = size.height
                if game.mgWallSide == "left" {
                    context.fill(Path(CGRect(x: 0, y: 0, width: w * 0.3, height: h)),
                                 with: .color(GrubPalette.red))
                    context.fill(Path(CGRect(x: w * 0.4, y: h * 0.3, width: w * 0.4, height: h * 0.35)),
                                 with: .color(GrubPalette.green))
                } else {
                    context.fill(Path(CGRect(x: w * 0.7, y: 0, width: w * 0.3, height: h)),
                                 with: .color(GrubPalette.red))
                    context.fill(Path(CGRect(x: w * 0.2, y: h * 0.3, width: w * 0.4, height: h * 0.35)),
                                 with: .color(GrubPalette.green))
                }
                context.draw(Text("DODGE!").font(GrubFont.size(12)).foregroundColor(GrubPalette.pale),
                             at: CGPoint(x: w / 2, y: 20))
            } else {
                // V3 PNG hero (sad) — falls back to procedural only if asset missing.
                let scale: CGFloat = 2.5
                let ox = (size.width - 32 * scale) / 2
                let oy = (size.height - 32 * scale) / 2
                if UIImage(named: "grub_S_sad") != nil {
                    let sprite = Image("grub_S_sad").interpolation(.none)
                    context.draw(sprite, in: CGRect(x: ox, y: oy, width: 32 * scale, height: 32 * scale))
                } else {
                    let proc = SpriteRenderer.makeGrubSprite(state: "sad", tick: game.animTick)
                    SpriteRenderer.drawSprite(context: &context, sprite: proc,
                                              origin: CGPoint(x: ox, y: oy), scale: scale)
                }
            }
        }
    }
}

// MARK: - Evolution Overlay
struct EvolutionOverlayView: View {
    @ObservedObject var game: GameState
    @State private var flashWhite = true

    var body: some View {
        ZStack {
            (flashWhite ? Color.white : Color.black)
                .ignoresSafeArea()
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        flashWhite = false
                    }
                }

            VStack(spacing: 24) {
                // PNG hero for the evolution reveal (idle pose, pixel-perfect)
                GrubSpriteView(state: "idle", tick: game.animTick)
                    .frame(width: 192, height: 192)

                Text("\(game.name) EVOLVED INTO\n\(game.evoDisplayName)!")
                    .font(GrubFont.size(11))
                    .foregroundColor(GrubPalette.purple)
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)

                Text(evoBonus(game.evoStage))
                    .font(GrubFont.size(8))
                    .foregroundColor(GrubPalette.yellow)
                    .multilineTextAlignment(.center)

                Text("TAP TO CONTINUE")
                    .font(GrubFont.size(8))
                    .foregroundColor(GrubPalette.pale.opacity(0.5))
                    .opacity(pulsingOpacity())
            }
        }
        .onTapGesture {
            game.audio.play(.tap)
            game.showEvolution = false
        }
        .transition(.opacity)
    }

    private func pulsingOpacity() -> Double {
        return game.animTick % 40 < 20 ? 0.5 : 0.1
    }

    private func evoBonus(_ stage: Int) -> String {
        switch stage {
        case 1: return "NEW LOOK UNLOCKED!\nSTATS GROW FASTER"
        case 2: return "FINAL FORM!\nLEGACY BONUS UNLOCKED"
        default: return "SOMETHING CHANGED..."
        }
    }
}

// MARK: - Death Overlay
struct DeathOverlayView: View {
    @ObservedObject var game: GameState

    var body: some View {
        ZStack {
            Color(hex: "#0d0d0d").ignoresSafeArea()

            VStack(spacing: 18) {
                // V3 PNG hero (dead with X eyes) — fallback to procedural if asset missing
                Group {
                    if UIImage(named: "grub_S_dead") != nil {
                        Image("grub_S_dead")
                            .interpolation(.none)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Canvas { context, size in
                            let sprite = SpriteRenderer.makeGrubSprite(state: "dead", tick: 0)
                            let scale = size.width / 32
                            SpriteRenderer.drawSprite(context: &context, sprite: sprite, origin: .zero, scale: scale)
                        }
                    }
                }
                .frame(width: 192, height: 192)

                Text("R.I.P.")
                    .font(GrubFont.size(18))
                    .foregroundColor(GrubPalette.grey)
                    .tracking(3)

                Text(game.name)
                    .font(GrubFont.size(14))
                    .foregroundColor(GrubPalette.bone)

                Text("LIVED \(game.ageDays) DAYS")
                    .font(GrubFont.size(10))
                    .foregroundColor(Color(hex: "#6a6a6a"))

                Text(game.legacyTrait)
                    .font(GrubFont.size(8))
                    .foregroundColor(GrubPalette.purple)
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
                    .padding(.top, 4)

                if game.adManager.isRewardedReady {
                    Button {
                        game.showRewardedAd(for: .reviveGrub)
                    } label: {
                        HStack(spacing: 6) {
                            Text("\u{25B6}")
                                .font(.system(size: 10))
                            Text("WATCH AD TO REVIVE")
                                .font(GrubFont.size(9))
                        }
                        .foregroundColor(GrubPalette.yellow)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .overlay(Rectangle().stroke(GrubPalette.yellow, lineWidth: 2))
                    }
                    .padding(.top, 10)
                }

                Button {
                    game.restartGame()
                } label: {
                    Text("ADOPT NEW GRUB")
                        .font(GrubFont.size(10))
                        .foregroundColor(GrubPalette.grey)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .overlay(
                            Rectangle().stroke(GrubPalette.grey, lineWidth: 2)
                        )
                }
                .padding(.top, 10)
            }
        }
        .transition(.opacity)
    }
}

// MARK: - Name Entry (UIKit ViewController for reliable text input)
struct NameEntryView: UIViewControllerRepresentable {
    @ObservedObject var game: GameState

    func makeUIViewController(context: Context) -> NameEntryViewController {
        let vc = NameEntryViewController()
        vc.onConfirm = { name in
            game.confirmName(name)
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: NameEntryViewController, context: Context) {}
}

class NameEntryViewController: UIViewController, UITextFieldDelegate {
    var onConfirm: ((String) -> Void)?
    private var textField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.102, green: 0.102, blue: 0.180, alpha: 1) // void

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 30),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -30),
        ])

        let pixelFont = UIFont(name: "PressStart2P-Regular", size: 24) ?? UIFont.monospacedSystemFont(ofSize: 24, weight: .bold)
        let smallFont = UIFont(name: "PressStart2P-Regular", size: 9) ?? UIFont.monospacedSystemFont(ofSize: 9, weight: .regular)
        let medFont = UIFont(name: "PressStart2P-Regular", size: 14) ?? UIFont.monospacedSystemFont(ofSize: 14, weight: .bold)
        let btnFont = UIFont(name: "PressStart2P-Regular", size: 12) ?? UIFont.monospacedSystemFont(ofSize: 12, weight: .bold)

        // Title
        let title = UILabel()
        title.text = "GRUB"
        title.font = pixelFont
        title.textColor = UIColor(red: 0.306, green: 0.800, blue: 0.639, alpha: 1) // green
        title.textAlignment = .center
        stack.addArrangedSubview(title)

        // Subtitle
        let subtitle = UILabel()
        subtitle.text = "A TINY CREATURE THAT\nNEEDS YOUR ATTENTION.\nNAME YOUR GRUB."
        subtitle.font = smallFont
        subtitle.textColor = UIColor(red: 0.91, green: 0.91, blue: 0.816, alpha: 0.6) // pale
        subtitle.textAlignment = .center
        subtitle.numberOfLines = 0
        stack.addArrangedSubview(subtitle)

        // Sprite placeholder (static)
        let spriteView = GrubSpriteUIView(frame: CGRect(x: 0, y: 0, width: 160, height: 160))
        spriteView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            spriteView.widthAnchor.constraint(equalToConstant: 160),
            spriteView.heightAnchor.constraint(equalToConstant: 160),
        ])
        stack.addArrangedSubview(spriteView)

        // Text field
        textField = UITextField()
        textField.font = medFont
        textField.textColor = UIColor(red: 0.91, green: 0.91, blue: 0.816, alpha: 1)
        textField.tintColor = UIColor(red: 0.306, green: 0.800, blue: 0.639, alpha: 1)
        textField.textAlignment = .center
        textField.autocapitalizationType = .allCharacters
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no
        textField.returnKeyType = .done
        textField.keyboardAppearance = .dark
        textField.backgroundColor = UIColor(red: 0.086, green: 0.129, blue: 0.243, alpha: 1) // moss
        textField.delegate = self
        textField.attributedPlaceholder = NSAttributedString(
            string: "NAME...",
            attributes: [
                .foregroundColor: UIColor(white: 0.8, alpha: 0.3),
                .font: medFont
            ]
        )

        let tfContainer = UIView()
        tfContainer.backgroundColor = .clear
        tfContainer.layer.borderColor = UIColor(red: 0.306, green: 0.800, blue: 0.639, alpha: 1).cgColor
        tfContainer.layer.borderWidth = 2
        tfContainer.translatesAutoresizingMaskIntoConstraints = false
        textField.translatesAutoresizingMaskIntoConstraints = false
        tfContainer.addSubview(textField)
        NSLayoutConstraint.activate([
            tfContainer.widthAnchor.constraint(equalToConstant: 280),
            tfContainer.heightAnchor.constraint(equalToConstant: 50),
            textField.leadingAnchor.constraint(equalTo: tfContainer.leadingAnchor, constant: 12),
            textField.trailingAnchor.constraint(equalTo: tfContainer.trailingAnchor, constant: -12),
            textField.topAnchor.constraint(equalTo: tfContainer.topAnchor),
            textField.bottomAnchor.constraint(equalTo: tfContainer.bottomAnchor),
        ])
        stack.addArrangedSubview(tfContainer)

        // Adopt button
        let button = UIButton(type: .system)
        button.setTitle("ADOPT", for: .normal)
        button.titleLabel?.font = btnFont
        button.setTitleColor(UIColor(red: 0.102, green: 0.102, blue: 0.180, alpha: 1), for: .normal)
        button.backgroundColor = UIColor(red: 0.306, green: 0.800, blue: 0.639, alpha: 1)
        button.contentEdgeInsets = UIEdgeInsets(top: 16, left: 36, bottom: 16, right: 36)
        button.addTarget(self, action: #selector(adoptTapped), for: .touchUpInside)
        stack.addArrangedSubview(button)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textField.becomeFirstResponder()
    }

    @objc private func adoptTapped() {
        let name = textField.text?.trimmingCharacters(in: .whitespaces).uppercased() ?? ""
        onConfirm?(name)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        adoptTapped()
        return true
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let current = textField.text ?? ""
        guard let stringRange = Range(range, in: current) else { return false }
        let updated = current.replacingCharacters(in: stringRange, with: string)
        return updated.count <= 10
    }
}

// Simple UIView that draws the grub sprite
class GrubSpriteUIView: UIView {
    private var displayLink: CADisplayLink?
    private var tick: Int = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        displayLink = CADisplayLink(target: self, selector: #selector(animate))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 10, maximum: 15)
        displayLink?.add(to: .main, forMode: .common)
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit { displayLink?.invalidate() }

    @objc private func animate() {
        tick += 1
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.interpolationQuality = .none
        // PNG hero (idle), pixel-perfect via interpolationQuality.none above.
        if let img = UIImage(named: "grub_S") {
            img.draw(in: rect)
            return
        }
        // Procedural fallback if the asset is missing for any reason.
        let sprite = SpriteRenderer.makeGrubSprite(state: "idle", tick: tick)
        let scale = rect.width / 32
        for (r, row) in sprite.enumerated() {
            for (c, ch) in row.enumerated() {
                if ch == "0" { continue }
                guard let color = GrubPalette.paletteMap[ch] else { continue }
                UIColor(color).setFill()
                let pixRect = CGRect(x: CGFloat(c) * scale, y: CGFloat(r) * scale, width: scale, height: scale)
                ctx.fill(pixRect)
            }
        }
    }
}

// MARK: - Minigame Food Helpers
private let mgFoodNameMap: [String: String] = [
    "🍖": "MEAT", "🥦": "VEGGIE", "🍰": "CAKE", "🍕": "PIZZA", "🥕": "CARROT"
]

@ViewBuilder
func mgFoodIcon(_ emoji: String, size: CGFloat) -> some View {
    switch emoji {
    case "🍖":
        PixelIcon.meat(size: size)
    case "🥦":
        PixelIcon.broccoli(size: size)
    case "🍰":
        PixelIcon.cake(size: size)
    case "🍕":
        PixelIcon.pizza(size: size)
    case "🥕":
        PixelIcon.carrot(size: size)
    default:
        PixelIcon.nut(size: size)
    }
}

func mgFoodLabel(_ emoji: String) -> String {
    mgFoodNameMap[emoji] ?? "FOOD"
}

