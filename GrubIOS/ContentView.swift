import SwiftUI

struct ContentView: View {
    @ObservedObject var game: GameState

    var body: some View {
        ZStack {
            // Full-screen background
            GrubPalette.void_color.ignoresSafeArea()

            VStack(spacing: 0) {
                // Safe area top fill
                GrubPalette.moss.ignoresSafeArea(edges: .top)
                    .frame(height: 0)

                TopBarView(game: game)
                ViewportView(game: game)
                if game.isDying {
                    DyingBannerView(game: game)
                } else if game.isNight {
                    NapBannerView(game: game)
                } else if game.isOnExpedition {
                    ExpeditionBannerView(game: game)
                }
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
            if game.showForageOverlay {
                ForageOverlayView(game: game)
            }
            if game.showForageResults {
                ForageResultsView(game: game)
            }
            if game.showInventoryOverlay {
                InventoryOverlayView(game: game)
            }
            if game.showGameSelector {
                GameSelectorOverlayView(game: game)
            }
            if game.showBurrowOverlay {
                BurrowOverlayView(game: game)
            }
            if game.showExpeditionOverlay {
                ExpeditionOverlayView(game: game)
            }
            if game.showExpeditionResults {
                ExpeditionResultsView(game: game)
            }
            if game.showJournalOverlay {
                JournalOverlayView(game: game, initialTab: game.journalInitialTab)
            }
            if game.showSettingsMenu {
                SettingsMenuView(game: game)
            }

            // Expedition find popup
            if let findId = game.expeditionFindPopup {
                ExpeditionFindPopup(itemId: findId)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .animation(.easeOut(duration: 0.3), value: game.expeditionFindPopup)
                    .allowsHitTesting(false)
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

    var body: some View {
        HStack(spacing: 0) {
            // Name — plain display, no action
            Text(game.name.isEmpty ? "GRUB" : game.name)
                .font(GrubFont.size(12))
                .foregroundColor(GrubPalette.green)

            Spacer()

            // LVL
            Text("LV\(game.ownerLevel)")
                .font(GrubFont.size(10))
                .foregroundColor(GrubPalette.yellow)

            // Divider dot
            Text("\u{00B7}")
                .font(GrubFont.size(10))
                .foregroundColor(GrubPalette.pale.opacity(0.3))
                .padding(.horizontal, 6)

            // Journal button
            Button {
                game.audio.play(.tap)
                game.journalInitialTab = 0
                game.showJournalOverlay = true
            } label: {
                Text("LOG")
                    .font(GrubFont.size(10))
                    .foregroundColor(GrubPalette.pale.opacity(0.6))
            }

            Text("\u{00B7}")
                .font(GrubFont.size(10))
                .foregroundColor(GrubPalette.pale.opacity(0.3))
                .padding(.horizontal, 6)

            // Settings button
            Button {
                game.audio.play(.tap)
                game.showSettingsMenu = true
            } label: {
                Text("\u{2699}")
                    .font(.system(size: 16))
                    .foregroundColor(GrubPalette.pale.opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(GrubPalette.moss.ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(GrubPalette.deepMoss)
                .frame(height: 1)
        }
    }
}

// MARK: - Viewport
struct ViewportView: View {
    @ObservedObject var game: GameState

    var body: some View {
        Canvas { context, size in
            SpriteRenderer.drawBackground(context: &context, size: size, tick: game.animTick)

            if game.isOnExpedition {
                let tick = game.animTick
                let miniScale = min(size.width, size.height) / 32.0 * 0.18
                let baseY = size.height * 0.58 - 16 * miniScale
                let px = max(2, min(size.width, size.height) / 64)
                let w = size.width

                // 8 behavior phases, ~200 ticks each = ~80s full cycle
                let masterCycle = tick % 1600
                let phase = masterCycle / 200

                let spriteState: String
                var grubX: CGFloat
                var grubY: CGFloat = baseY
                var grubScale = miniScale
                var showDust = false
                var showDig = false
                var showSparkle = false
                var showQuestion = false

                let phaseT = Double(masterCycle % 200) / 200.0  // 0..1 within phase

                switch phase {
                case 0:
                    // Walk in from left
                    spriteState = "idle"
                    grubX = CGFloat(phaseT) * w * 0.4
                    grubY = baseY + CGFloat(sin(Double(tick) * 0.3) * 1.5)
                    showDust = true

                case 1:
                    // Stop, look around — head turns
                    spriteState = "tap_peek"
                    grubX = w * 0.4
                    // Little side-to-side sway
                    grubX += CGFloat(sin(Double(tick) * 0.08) * 3.0)
                    showQuestion = phaseT > 0.3 && phaseT < 0.7

                case 2:
                    // Dig! Crouch down and throw dirt
                    spriteState = "tap_spin"
                    grubX = w * 0.4
                    // Bob down while digging
                    grubY = baseY + CGFloat(sin(Double(tick) * 0.5) * 2.0) + 2
                    showDig = true

                case 3:
                    // Found something! Jump up with sparkle
                    spriteState = "tap_jump"
                    grubX = w * 0.4
                    let jumpPhase = sin(Double(tick) * 0.2) * 4.0
                    grubY = baseY + CGFloat(min(0, jumpPhase))
                    showSparkle = true

                case 4:
                    // Dash right fast (off screen)
                    spriteState = "idle"
                    grubX = w * 0.4 + CGFloat(phaseT * phaseT) * w * 0.8
                    grubY = baseY + CGFloat(sin(Double(tick) * 0.5) * 1.0)
                    showDust = true

                case 5:
                    // Gone — nothing visible, just dots
                    spriteState = "idle"
                    grubX = w * 2 // off screen
                    // Show "..." in the distance
                    if Int(phaseT * 6) % 2 == 0 {
                        let dotY = baseY + 10 * miniScale
                        for i in 0..<3 {
                            let dotRect = CGRect(x: w * 0.85 + CGFloat(i) * px * 2, y: dotY, width: px, height: px)
                            context.fill(Path(dotRect), with: .color(GrubPalette.pale.opacity(0.3)))
                        }
                    }

                case 6:
                    // Dash back from right, carrying something
                    spriteState = "tap_bounce"
                    grubX = w * 1.0 - CGFloat(phaseT) * w * 0.5
                    grubY = baseY + CGFloat(sin(Double(tick) * 0.4) * 1.5)
                    showDust = true
                    showSparkle = phaseT > 0.7

                default:
                    // Stop in center, look at camera, then restart
                    spriteState = "tap_wave"
                    grubX = w * 0.5
                    grubY = baseY + CGFloat(sin(Double(tick) * 0.1) * 1.0)
                    // Slowly shrink as if walking into distance
                    if phaseT > 0.6 {
                        let shrink = 1.0 - (phaseT - 0.6) / 0.4 * 0.5
                        grubScale = miniScale * CGFloat(shrink)
                        grubY = baseY + CGFloat((phaseT - 0.6) / 0.4 * 8.0)
                    }
                }

                // Draw mini grub
                if grubX > -32 * miniScale && grubX < w + 32 * miniScale {
                    let miniSprite = SpriteRenderer.makeGrubSprite(state: spriteState, tick: tick)
                    SpriteRenderer.drawSprite(context: &context, sprite: miniSprite,
                        origin: CGPoint(x: grubX, y: grubY), scale: grubScale)
                }

                // Dust particles
                if showDust {
                    let dustFrame = tick % 16
                    if dustFrame < 8 {
                        let dx = grubX - CGFloat(dustFrame) * px * 0.6
                        let dy = grubY + 16 * miniScale - CGFloat(dustFrame / 3) * px
                        context.fill(Path(CGRect(x: dx, y: dy, width: px, height: px)),
                            with: .color(GrubPalette.pale.opacity(0.12)))
                        context.fill(Path(CGRect(x: dx - px * 2, y: dy + px, width: px, height: px)),
                            with: .color(GrubPalette.pale.opacity(0.06)))
                    }
                }

                // Dig particles — dirt flying up
                if showDig {
                    let digFrame = tick % 12
                    let dirtColors: [Color] = [GrubPalette.yellow.opacity(0.3), GrubPalette.pale.opacity(0.2), GrubPalette.orange.opacity(0.2)]
                    for i in 0..<3 {
                        let dirtX = grubX + 8 * miniScale + CGFloat(i * 4 - 4) * px
                        let dirtY = grubY + 12 * miniScale - CGFloat(digFrame + i * 2) * px * 0.5
                        if digFrame < 8 {
                            context.fill(Path(CGRect(x: dirtX, y: dirtY, width: px, height: px)),
                                with: .color(dirtColors[i]))
                        }
                    }
                }

                // Sparkle effect
                if showSparkle {
                    let sp = tick % 12
                    let sparkColor = GrubPalette.yellow.opacity(0.5)
                    if sp < 4 {
                        context.fill(Path(CGRect(x: grubX + 2 * miniScale, y: grubY - 4 * miniScale, width: px, height: px)), with: .color(sparkColor))
                        context.fill(Path(CGRect(x: grubX + 20 * miniScale, y: grubY - 2 * miniScale, width: px, height: px)), with: .color(sparkColor))
                    } else if sp < 8 {
                        context.fill(Path(CGRect(x: grubX + 12 * miniScale, y: grubY - 6 * miniScale, width: px, height: px)), with: .color(sparkColor))
                        context.fill(Path(CGRect(x: grubX - 2 * miniScale, y: grubY, width: px, height: px)), with: .color(sparkColor))
                    }
                }

                // Question mark
                if showQuestion {
                    context.fill(Path(CGRect(x: grubX + 10 * miniScale, y: grubY - 8 * miniScale, width: px * 2, height: px)), with: .color(GrubPalette.green.opacity(0.5)))
                    context.fill(Path(CGRect(x: grubX + 11 * miniScale, y: grubY - 6 * miniScale, width: px, height: px)), with: .color(GrubPalette.green.opacity(0.5)))
                    context.fill(Path(CGRect(x: grubX + 11 * miniScale, y: grubY - 4 * miniScale, width: px, height: px)), with: .color(GrubPalette.green.opacity(0.5)))
                }

                // Status text
                let statusTexts = ["EXPLORING...", "SEARCHING...", "DIGGING...", "FOUND SOMETHING!", "RUNNING!", "...", "COMING BACK!", "HI!"]
                let statusText = statusTexts[min(phase, statusTexts.count - 1)]
                context.draw(Text(statusText)
                    .font(GrubFont.size(7))
                    .foregroundColor(GrubPalette.green.opacity(0.5)),
                    at: CGPoint(x: w / 2, y: size.height * 0.32))

            } else {
                // Normal — pet sprite in foreground
                let scale = min(size.width, size.height) / 32.0 * 0.7
                let petX = size.width / 2 - 16 * scale
                let petY = size.height * 0.45 - 16 * scale

                // PNG-state dispatch — every gameplay state maps to a PixelLab-generated
                // PNG with the same character lineage (1e12a98f). Procedural fallback only
                // for tap_* action animations and any unmapped state.
                let anim = game.currentPetAnim
                let baseAssetName: String? = {
                    switch anim {
                    case "idle", "energized", "sleeping":  return "grub_S"
                    case "eating", "drinking":             return "grub_S_eat"
                    case "sad", "unhappy":                 return "grub_S_sad"
                    case "sick":                           return "grub_S_sick"
                    case "starving", "hungry":             return "grub_S_starving"
                    case "angry":                          return "grub_S_angry"
                    case "dying":                          return "grub_S_dying"
                    case "dead":                           return "grub_S_dead"
                    default:                               return nil   // tap_*, unmapped
                    }
                }()

                if let baseName = baseAssetName, UIImage(named: baseName) != nil {
                    // Per-state animation profile (bob amplitude, speed, breathing).
                    // Dead = fully static. Dying = weak/heavy. Eating = chompy.
                    // Everything else = normal idle.
                    let t = Double(game.animTick)
                    let bobAmp:     Double
                    let bobSpeed:   Double
                    let breatheAmp: Double
                    let stretchMod: Double
                    let useBlink:   Bool

                    switch anim {
                    case "dead":
                        bobAmp = 0; bobSpeed = 0.08; breatheAmp = 0; stretchMod = 0;     useBlink = false
                    case "dying":
                        bobAmp = 1.5; bobSpeed = 0.04; breatheAmp = 0.015; stretchMod = 0.01; useBlink = false
                    case "eating", "drinking":
                        bobAmp = 4.0; bobSpeed = 0.16; breatheAmp = 0.02; stretchMod = 0.04;  useBlink = false
                    case "idle", "energized", "sleeping":
                        bobAmp = 3.0; bobSpeed = 0.08; breatheAmp = 0.02; stretchMod = 0.025; useBlink = true
                    default:
                        // Stat-driven states (sad/sick/starving/angry/hungry/unhappy): gentle idle, no blink
                        bobAmp = 3.0; bobSpeed = 0.08; breatheAmp = 0.02; stretchMod = 0.025; useBlink = false
                    }

                    let bobPhase = sin(t * bobSpeed)
                    let bob = CGFloat(bobPhase * bobAmp)
                    let breathe = 1.0 + sin(t * 0.04) * breatheAmp
                    let stretchY = CGFloat(breathe + bobPhase * stretchMod)
                    let stretchX = CGFloat(breathe - bobPhase * (stretchMod * 0.6))

                    let baseDraw = 32 * scale
                    let drawW = baseDraw * stretchX
                    let drawH = baseDraw * stretchY
                    let feetY = petY + baseDraw
                    let drawX = petX + (baseDraw - drawW) / 2
                    let drawY = feetY - drawH + bob

                    // Idle-only blink alternation (~5 ticks closed every 80)
                    let assetName: String = (useBlink && (game.animTick % 80) < 5)
                        ? "grub_S_blink"
                        : baseName
                    let sprite = Image(assetName).interpolation(.none)
                    context.draw(sprite, in: CGRect(x: drawX, y: drawY, width: drawW, height: drawH))
                } else {
                    // Procedural fallback for tap_* and any unmapped state
                    let sprite = SpriteRenderer.makeGrubSprite(state: anim, tick: game.animTick)
                    SpriteRenderer.drawSprite(context: &context, sprite: sprite,
                                              origin: CGPoint(x: petX, y: petY),
                                              scale: scale)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .onTapGesture {
            game.tapGrub()
        }
    }
}

// MARK: - Pet Info Bar
// MARK: - Dying Banner
// MARK: - Nap Banner
struct NapBannerView: View {
    @ObservedObject var game: GameState

    var body: some View {
        VStack(spacing: 2) {
            HStack {
                Text("NAPPING")
                    .font(GrubFont.size(9))
                    .foregroundColor(GrubPalette.pale.opacity(0.5))
                Text("zzz")
                    .font(GrubFont.size(8))
                    .foregroundColor(GrubPalette.purple.opacity(game.animTick % 20 < 10 ? 0.8 : 0.4))
                Spacer()
                Text(game.napTimeString)
                    .font(GrubFont.size(11))
                    .foregroundColor(GrubPalette.pale)
            }
            Text("DECAY SLOWED \u{00B7} GRUB SLEEPS 10PM-6AM")
                .font(GrubFont.size(6))
                .foregroundColor(GrubPalette.pale.opacity(0.25))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(GrubPalette.void_color)
    }
}

struct DyingBannerView: View {
    @ObservedObject var game: GameState

    var body: some View {
        HStack {
            Text("DYING!")
                .font(GrubFont.size(10))
                .foregroundColor(GrubPalette.red)
            Spacer()
            Text(game.dyingTimeString)
                .font(GrubFont.size(12))
                .foregroundColor(game.dyingTimeRemaining < 300 ? GrubPalette.red : GrubPalette.yellow)
            Spacer()
            Text("HEAL HIM!")
                .font(GrubFont.size(8))
                .foregroundColor(GrubPalette.pale.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(GrubPalette.void_color)
        .overlay(
            Rectangle().fill(GrubPalette.red.opacity(game.animTick % 20 < 10 ? 0.4 : 0.1)).frame(height: 2),
            alignment: .top
        )
    }
}

struct ExpeditionBannerView: View {
    @ObservedObject var game: GameState

    var body: some View {
        Button {
            game.audio.play(.menuOpen)
            game.showExpeditionOverlay = true
        } label: {
            HStack {
                Text("EXPLORING")
                    .font(GrubFont.size(9))
                    .foregroundColor(GrubPalette.yellow)
                let _ = game.animTick
                Text(game.isExpeditionComplete ? "DONE!" : game.expeditionTimeString)
                    .font(GrubFont.size(11))
                    .foregroundColor(game.isExpeditionComplete ? GrubPalette.green : GrubPalette.pale)
                Spacer()
                Text(game.isExpeditionComplete ? "COLLECT" : "VIEW")
                    .font(GrubFont.size(8))
                    .foregroundColor(GrubPalette.pale.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(GrubPalette.void_color)
            .overlay(
                Rectangle().fill(GrubPalette.yellow.opacity(0.4)).frame(height: 1),
                alignment: .top
            )
        }
    }
}

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
            Rectangle().fill(GrubPalette.deepMoss).frame(height: 1)
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
        VStack(spacing: 0) {
            PixelStatRow(label: "HNG", value: game.hunger, color: GrubPalette.green, tick: game.animTick)
            PixelStatRow(label: "HAP", value: game.happiness, color: GrubPalette.yellow, tick: game.animTick)
            PixelStatRow(label: "HP", value: game.health, color: GrubPalette.red, tick: game.animTick)
        }
        .background(GrubPalette.void_color)
        .overlay(alignment: .bottom) {
            Rectangle().fill(GrubPalette.deepMoss).frame(height: 1)
        }
    }
}

struct PixelStatRow: View {
    let label: String
    let value: Int
    let color: Color
    let tick: Int

    private var isCritical: Bool { value < 20 }
    private var pulseOn: Bool { !isCritical || (tick / 8) % 2 == 0 }

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(GrubFont.size(7))
                .foregroundColor(isCritical ? color : color.opacity(0.6))
                .frame(width: 28, alignment: .leading)

            // Pixel bar rendered via Canvas
            Canvas { ctx, size in
                let px: CGFloat = 3
                let cols = Int(size.width / px)
                let filledCols = Int(Double(cols) * Double(value) / 100.0)
                let rows = Int(size.height / px)

                // Empty track
                for c in 0..<cols {
                    for r in 0..<rows {
                        let rect = CGRect(x: CGFloat(c) * px, y: CGFloat(r) * px, width: px - 0.5, height: px - 0.5)
                        ctx.fill(Path(rect), with: .color(GrubPalette.moss.opacity(0.4)))
                    }
                }

                // Filled portion
                if pulseOn {
                    for c in 0..<filledCols {
                        for r in 0..<rows {
                            let rect = CGRect(x: CGFloat(c) * px, y: CGFloat(r) * px, width: px - 0.5, height: px - 0.5)
                            // Top row highlight
                            if r == 0 {
                                ctx.fill(Path(rect), with: .color(color.opacity(0.6)))
                            } else {
                                ctx.fill(Path(rect), with: .color(color))
                            }
                        }
                    }
                }
            }
            .frame(height: 9)

            // Value
            Text("\(value)")
                .font(GrubFont.size(8))
                .foregroundColor(isCritical ? GrubPalette.red : GrubPalette.pale.opacity(0.7))
                .frame(width: 28, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .overlay(alignment: .top) {
            Rectangle().fill(GrubPalette.deepMoss.opacity(0.3)).frame(height: 0.5)
        }
    }
}

// MARK: - Action Buttons
struct ActionButtonsView: View {
    @ObservedObject var game: GameState

    var body: some View {
        HStack(spacing: 4) {
            ActionButton(icon: { AnyView(PixelIcon.meat(size: 28)) }, label: "FEED", borderColor: GrubPalette.green) {
                game.audio.play(.tap)
                game.showFeedOverlay = true
            }

            ActionButton(icon: { AnyView(PixelIcon.dice(size: 28)) }, label: "PLAY", borderColor: GrubPalette.green) {
                game.openPlay()
            }

            ActionButton(icon: { AnyView(PixelIcon.shovel(size: 28)) }, label: "DIG", borderColor: GrubPalette.green) {
                game.audio.play(.dig)
                game.showForageOverlay = true
            }

            ActionButton(icon: { AnyView(PixelIcon.chest(size: 28)) }, label: "PACK", borderColor: GrubPalette.green) {
                game.audio.play(.tap)
                game.showInventoryOverlay = true
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(GrubPalette.moss.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle().fill(GrubPalette.deepMoss).frame(height: 1)
        }
    }
}

struct ActionButton: View {
    let icon: () -> AnyView
    let label: String
    let borderColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                icon()
                Text(label)
                    .font(GrubFont.size(9))
                    .foregroundColor(GrubPalette.pale)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .background(GrubPalette.void_color)
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
struct ExpeditionFindPopup: View {
    let itemId: String

    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                PixelIcon.ingredientIcon(itemId, size: 24)
                Text("FOUND \(ingredientCatalog[itemId]?.name ?? itemId.uppercased())!")
                    .font(GrubFont.size(8))
                    .foregroundColor(GrubPalette.pale)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(GrubPalette.moss)
            .border(GrubPalette.yellow, width: 1)
            .padding(.bottom, 120)
        }
    }
}

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
