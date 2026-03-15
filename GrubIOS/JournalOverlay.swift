import SwiftUI

struct JournalOverlayView: View {
    @ObservedObject var game: GameState
    @State private var selectedTab: Int

    init(game: GameState, initialTab: Int = 0) {
        self._game = ObservedObject(wrappedValue: game)
        self._selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        ZStack {
            GrubPalette.void_color.opacity(0.9).ignoresSafeArea()
                .onTapGesture { game.showJournalOverlay = false }

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("JOURNAL")
                        .font(GrubFont.size(14))
                        .foregroundColor(GrubPalette.green)
                    Spacer()
                    Button("X") { game.showJournalOverlay = false }
                        .font(GrubFont.size(14))
                        .foregroundColor(GrubPalette.red)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(GrubPalette.moss)

                // Tabs
                HStack(spacing: 0) {
                    JournalTab(title: "STATS", selected: selectedTab == 0) { selectedTab = 0 }
                    JournalTab(title: "TRAIT", selected: selectedTab == 1) { selectedTab = 1 }
                }
                .background(GrubPalette.deepMoss)

                Rectangle().fill(GrubPalette.green).frame(height: 2)

                // Content
                switch selectedTab {
                case 0: statsTab
                case 1: traitTab
                default: statsTab
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 40)
        }
    }

    var statsTab: some View {
        ScrollView {
            VStack(spacing: 8) {
                StatRow(label: "TIMES FED", value: "\(game.fedCount)")
                StatRow(label: "GAMES PLAYED", value: "\(game.playedCount)")
                StatRow(label: "FORAGING TRIPS", value: "\(game.forageCount)")
                StatRow(label: "ITEMS CRAFTED", value: "\(game.itemsCrafted)")
                StatRow(label: "RECIPES FOUND", value: "\(game.recipesFound)")
                StatRow(label: "EXPEDITIONS", value: "\(game.expeditionsCompleted)")
                StatRow(label: "DECORATIONS", value: "\(game.placedDecorations.count)")
                StatRow(label: "JOURNAL", value: "\(game.unlockedJournalIds.count)/\(journalEntries.count)")
                StatRow(label: "WIN STREAK", value: "\(game.winStreak)")
                StatRow(label: "LEVEL", value: "\(game.ownerLevel)")
                StatRow(label: "AGE", value: "\(game.ageDays) DAYS")
                StatRow(label: "DEATHS", value: "\(game.totalDeaths)")
            }
            .padding(16)
        }
    }

    var traitTab: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Active trait display
                if let trait = game.activeTrait {
                    Text(trait.rawValue.uppercased())
                        .font(GrubFont.size(16))
                        .foregroundColor(GrubPalette.green)

                    Text(trait.description)
                        .font(GrubFont.size(10))
                        .foregroundColor(GrubPalette.yellow)

                    Rectangle().fill(GrubPalette.deepMoss).frame(height: 1)
                        .padding(.vertical, 4)
                } else {
                    // Hint text before trait locks in
                    if let hint = game.traitHint {
                        Text(hint)
                            .font(GrubFont.size(9))
                            .foregroundColor(GrubPalette.yellow.opacity(0.8))
                            .multilineTextAlignment(.center)
                    } else {
                        Text("NO TENDENCIES YET")
                            .font(GrubFont.size(10))
                            .foregroundColor(GrubPalette.pale.opacity(0.3))
                    }

                    // Progress to trait unlock
                    let progress = min(1.0, Double(game.totalCareActions) / Double(GameState.traitThreshold))
                    HStack(spacing: 6) {
                        Text("FORMING")
                            .font(GrubFont.size(7))
                            .foregroundColor(GrubPalette.pale.opacity(0.4))
                        traitProgressBar(progress: progress)
                        Text("\(game.totalCareActions)/\(GameState.traitThreshold)")
                            .font(GrubFont.size(7))
                            .foregroundColor(GrubPalette.pale.opacity(0.4))
                    }
                    .padding(.vertical, 4)

                    Rectangle().fill(GrubPalette.deepMoss).frame(height: 1)
                        .padding(.vertical, 4)
                }

                // Tendency bars — show top scoring traits
                let scores = game.traitScores
                if !scores.isEmpty {
                    Text(game.activeTrait != nil ? "TENDENCIES" : "DEVELOPING")
                        .font(GrubFont.size(8))
                        .foregroundColor(GrubPalette.pale.opacity(0.4))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    let maxScore = max(scores.first?.score ?? 1, 1)
                    ForEach(scores.prefix(5), id: \.trait) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(item.trait.rawValue.uppercased())
                                    .font(GrubFont.size(8))
                                    .foregroundColor(item.trait == game.activeTrait ? GrubPalette.green : GrubPalette.pale.opacity(0.6))
                                    .frame(width: 80, alignment: .leading)

                                traitBar(
                                    value: Double(item.score) / Double(maxScore),
                                    color: item.trait == game.activeTrait ? GrubPalette.green : GrubPalette.pale.opacity(0.3)
                                )
                            }
                            Text(traitExplanation(item.trait))
                                .font(GrubFont.size(6))
                                .foregroundColor(GrubPalette.pale.opacity(0.3))
                                .padding(.leading, 2)
                        }
                    }
                }

                Spacer()
            }
            .padding(20)
        }
    }

    func traitExplanation(_ trait: PersonalityTrait) -> String {
        switch trait {
        case .scrappy: return "EARNED BY FORAGING OFTEN"
        case .cheerful: return "EARNED BY KEEPING HAPPINESS HIGH"
        case .hardy: return "EARNED BY SURVIVING LOW HEALTH"
        case .curious: return "EARNED BY FINDING MANY INGREDIENTS"
        case .picky: return "EARNED BY OVERFEEDING"
        case .lazy: return "EARNED FROM NEGLECT"
        case .fierce: return "EARNED BY WINNING MINIGAMES"
        case .gentle: return "EARNED BY FEEDING OFTEN"
        }
    }

    func traitBar(value: Double, color: Color) -> some View {
        Canvas { ctx, size in
            let px: CGFloat = 3
            let cols = Int(size.width / px)
            let filled = Int(Double(cols) * min(1, value))
            let rows = 2

            for c in 0..<cols {
                for r in 0..<rows {
                    let rect = CGRect(x: CGFloat(c) * px, y: CGFloat(r) * px, width: px - 0.5, height: px - 0.5)
                    if c < filled {
                        ctx.fill(Path(rect), with: .color(color))
                    } else {
                        ctx.fill(Path(rect), with: .color(GrubPalette.moss.opacity(0.3)))
                    }
                }
            }
        }
        .frame(height: 6)
    }

    func traitProgressBar(progress: Double) -> some View {
        Canvas { ctx, size in
            let px: CGFloat = 3
            let cols = Int(size.width / px)
            let filled = Int(Double(cols) * min(1, progress))

            for c in 0..<cols {
                let rect = CGRect(x: CGFloat(c) * px, y: 0, width: px - 0.5, height: size.height)
                if c < filled {
                    ctx.fill(Path(rect), with: .color(GrubPalette.yellow.opacity(0.6)))
                } else {
                    ctx.fill(Path(rect), with: .color(GrubPalette.moss.opacity(0.3)))
                }
            }
        }
        .frame(height: 6)
    }
}

struct JournalTab: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(GrubFont.size(9))
                .foregroundColor(selected ? GrubPalette.green : GrubPalette.pale.opacity(0.4))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selected ? GrubPalette.moss : Color.clear)
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(GrubFont.size(9))
                .foregroundColor(GrubPalette.pale.opacity(0.5))
            Spacer()
            Text(value)
                .font(GrubFont.size(9))
                .foregroundColor(GrubPalette.green)
        }
        .padding(.vertical, 2)
    }
}
