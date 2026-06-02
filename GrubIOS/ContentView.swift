import SwiftUI

struct ContentView: View {
    @ObservedObject var game: GameState

    var body: some View {
        ZStack {
            // Full-screen background
            GrubPalette.void_color.ignoresSafeArea()

            // ---- Full-screen cave habitat ----
            // 1. Static backdrop PNG (full-bleed, zoomed in to crop empty ceiling).
            //    scaleEffect 1.25 anchored .bottom shows the bottom ~80% of the cave so
            //    the tall empty ceiling crops off and the scene frames Grub instead of
            //    dwarfing him. The painted floor lands at ~0.72 screen (see GrubLayer).
            Image("cave_home")
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .scaleEffect(1.25, anchor: .bottom)
                .ignoresSafeArea()
                .clipped()

            // 2. Animated atmosphere (particles + time-of-day tint) over the PNG
            Canvas { ctx, size in
                SpriteRenderer.drawAtmosphere(context: &ctx, size: size, tick: game.animTick)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // 3. Grub (transparent layer; tap to interact)
            //    MUST share the cave's full-screen coordinate space — otherwise the
            //    safe-area-inset Canvas makes 0.76 map above the cave floor (floating).
            GrubLayer(game: game)
                .ignoresSafeArea()

            // 4. Floating HUD (respects safe area)
            VStack(spacing: 0) {
                // Top bar — identity left, nav right, vertically centered as a unit
                HStack(alignment: .center) {
                    IdentityCluster(game: game)
                    Spacer()
                    MetaNavCluster(game: game)
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)

                // Banner appears just under the identity row when active
                Group {
                    if game.isDying {
                        DyingBannerView(game: game)
                    } else if game.isNight {
                        NapBannerView(game: game)
                    } else if game.isOnExpedition {
                        ExpeditionBannerView(game: game)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)

                Spacer()

                // Bottom dock — stats + buttons, translucent so the floor shows through
                VStack(spacing: 0) {
                    StatBarsView(game: game)
                    ActionButtonsView(game: game)
                }
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

// MARK: - Floating HUD clusters
private func hudShadow<V: View>(_ v: V) -> some View {
    v.shadow(color: .black.opacity(0.8), radius: 0, x: 1, y: 1)
}

/// Top-left: pet name + age, floating over the scene.
struct IdentityCluster: View {
    @ObservedObject var game: GameState
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            hudShadow(Text(game.name.isEmpty ? "GRUB" : game.name)
                .font(GrubFont.size(12))
                .foregroundColor(GrubPalette.green))
            hudShadow(Text("AGE \(game.ageDays)D")
                .font(GrubFont.size(8))
                .foregroundColor(GrubPalette.pale.opacity(0.6)))
        }
    }
}

/// Top-right: level + journal + settings, floating over the scene.
/// Tap targets stay ≥44pt tall, but visible glyphs sit on an even rhythm so the
/// row doesn't look bunched-then-gapped.
struct MetaNavCluster: View {
    @ObservedObject var game: GameState
    var body: some View {
        HStack(spacing: 14) {
            hudShadow(Text("LV\(game.ownerLevel)")
                .font(GrubFont.size(10))
                .foregroundColor(GrubPalette.yellow))

            Button {
                game.audio.play(.tap)
                game.journalInitialTab = 0
                game.showJournalOverlay = true
            } label: {
                hudShadow(Text("LOG")
                    .font(GrubFont.size(10))
                    .foregroundColor(GrubPalette.pale.opacity(0.7)))
                    .frame(height: 44)
                    .contentShape(Rectangle())
            }

            Button {
                game.audio.play(.tap)
                game.showSettingsMenu = true
            } label: {
                PixelIcon.gear(size: 16)
                    .frame(width: 28, height: 44)
                    .contentShape(Rectangle())
            }
        }
    }
}

// MARK: - Viewport
struct GrubLayer: View {
    @ObservedObject var game: GameState

    var body: some View {
        Canvas { context, size in
            // Transparent layer: the cave_home PNG + drawAtmosphere render BELOW this
            // in ContentView's ZStack. This Canvas draws only Grub (+ expedition scene).
            if game.isOnExpedition {
                let tick = game.animTick
                let miniScale = min(size.width, size.height) / 32.0 * 0.18
                // Floor-Y (O-4): match the normal pet's floor (0.80, on the dirt path)
                let baseY = size.height * 0.84 - 32 * miniScale
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

                // Draw mini grub — V3 PNG hero with directional walks during the walking
                // phases (0=walk in left→right, 4=dash right, 6=dash back right→left).
                // Other phases are static stops/diggings/jumps → use grub_S (camera-facing).
                if grubX > -32 * miniScale && grubX < w + 32 * miniScale {
                    // Pick PNG asset based on phase
                    let pngName: String = {
                        switch phase {
                        case 0, 4:
                            // Walking right → cycle east walk frames at ~6 fps
                            let frame = (tick / 4) % 4
                            return "grub_E_walk_\(frame)"
                        case 6:
                            // Walking left → cycle west walk frames at ~6 fps
                            let frame = (tick / 4) % 4
                            return "grub_W_walk_\(frame)"
                        default:
                            return "grub_S"
                        }
                    }()

                    if UIImage(named: pngName) != nil {
                        let resolved = Image(pngName).interpolation(.none)
                        let drawSize = 32 * grubScale
                        context.draw(resolved,
                                     in: CGRect(x: grubX, y: grubY,
                                                width: drawSize, height: drawSize))
                    } else {
                        // Procedural fallback if asset missing
                        let miniSprite = SpriteRenderer.makeGrubSprite(state: spriteState, tick: tick)
                        SpriteRenderer.drawSprite(context: &context, sprite: miniSprite,
                            origin: CGPoint(x: grubX, y: grubY), scale: grubScale)
                    }
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
                // Normal — pet sprite in foreground.
                // Floor-Y (O-4): GrubLayer is full-screen (ignoresSafeArea) so `size`
                // matches the cave render. Measured geometry: the cave's dark dirt PATH
                // (walkable ledge) is ~0.78–0.80 of screen height; the bright pool (~0.88)
                // sits behind the stat dock (top at ~0.855). Stand Grub with feet on the
                // dirt path at 0.80 — on the visible floor, just above the dock.
                // Cave is now zoomed 1.25x (bottom-anchored), so its painted dirt path
                // sits higher on screen (~0.75). Keep Grub's visible feet just above the
                // stat dock (~0.855). PNG has ~4px padding below feet, so target
                // drawn-bottom 0.84 → visible feet ~0.80.
                // feetY = petY + 32*scale  =>  petY = 0.84*h - 32*scale.
                let scale = min(size.width, size.height) / 32.0 * 0.7
                let petX = size.width / 2 - 16 * scale
                let petY = size.height * 0.84 - 32 * scale

                // PNG-state dispatch — every gameplay state maps to a PixelLab-generated
                // PNG with the same character lineage (1e12a98f). Procedural fallback only
                // for tap_* action animations and any unmapped state.
                let anim = game.currentPetAnim
                let baseAssetName: String? = {
                    switch anim {
                    case "idle", "energized", "sleeping", "playing":  return "grub_S"
                    case "eating", "drinking":                         return "grub_S_eat"
                    case "sad", "unhappy":                             return "grub_S_sad"
                    case "sick":                                       return "grub_S_sick"
                    case "starving", "hungry":                         return "grub_S_starving"
                    case "angry":                                      return "grub_S_angry"
                    case "dying":                                      return "grub_S_dying"
                    case "dead":                                       return "grub_S_dead"
                    // Tap interactions — keep V3 hero; the bob/squash exaggeration below
                    // sells the motion. tap_grumpy reuses the angry expression;
                    // tap_sick reuses the sick expression. Others keep idle face.
                    case "tap_grumpy":                                 return "grub_S_angry"
                    case "tap_sick":                                   return "grub_S_sick"
                    case _ where anim.hasPrefix("tap_"):               return "grub_S"
                    default:                                           return nil   // truly unmapped
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
                    case "playing", "tap_jump", "tap_bounce", "tap_spin":
                        // Excited / interaction bounce — big amplitude, fast, exaggerated squash
                        bobAmp = 6.0; bobSpeed = 0.32; breatheAmp = 0.025; stretchMod = 0.06; useBlink = false
                    case _ where anim.hasPrefix("tap_"):
                        // Other taps (wave, nuzzle, chirp, peek, grumpy, sick) — mild reaction
                        bobAmp = 2.0; bobSpeed = 0.20; breatheAmp = 0.02; stretchMod = 0.03; useBlink = false
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

                    // Contact shadow — grounds the sprite. Drawn BEFORE the body so it
                    // sits under the feet. Anchored at the fixed ground line (feetY, ~4px
                    // above the transparent PNG bottom), and it shrinks + fades as Grub
                    // bobs UP (bobPhase>0 = higher = smaller/lighter shadow) to sell weight.
                    if anim != "dead" {
                        let liftT = max(0, bobPhase)                       // 0 grounded … 1 peak
                        let shW = baseDraw * (0.78 - 0.10 * liftT)         // wider than body so it reads
                        let shH = shW * 0.20                               // flat ellipse
                        let shAlpha = 0.45 - 0.18 * liftT                  // darker; fades with lift
                        let groundY = petY + baseDraw - 4 * scale          // visible-feet line
                        let shRect = CGRect(x: petX + (baseDraw - shW) / 2,
                                            y: groundY - shH / 2,
                                            width: shW, height: shH)
                        context.fill(Path(ellipseIn: shRect),
                                     with: .color(.black.opacity(shAlpha)))
                    }

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

// MARK: - Stat Bars
struct StatBarsView: View {
    @ObservedObject var game: GameState

    var body: some View {
        VStack(spacing: 0) {
            // HP first — "am I alive?" is the most urgent read for a casual player
            PixelStatRow(label: "HP",  iconAsset: "ui_icon_heart",     value: game.health,    color: GrubPalette.red,    tick: game.animTick)
            PixelStatRow(label: "HNG", iconAsset: "ui_icon_drumstick", value: game.hunger,    color: GrubPalette.green,  tick: game.animTick)
            PixelStatRow(label: "HAP", iconAsset: "ui_icon_star",      value: game.happiness, color: GrubPalette.yellow, tick: game.animTick)
        }
        .background(GrubPalette.void_color.opacity(0.5))
        .overlay(alignment: .top) {
            Rectangle().fill(GrubPalette.deepMoss).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(GrubPalette.deepMoss).frame(height: 1)
        }
    }
}

struct PixelStatRow: View {
    let label: String
    let iconAsset: String      // PixelLab-generated UI icon; falls back to text label if missing
    let value: Int
    let color: Color
    let tick: Int

    private var isCritical: Bool { value < 20 }
    private var pulseOn: Bool { !isCritical || (tick / 8) % 2 == 0 }

    var body: some View {
        HStack(spacing: 6) {
            // Icon if the generated asset shipped, else fall back to the text label
            if UIImage(named: iconAsset) != nil {
                Image(iconAsset)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 14, height: 14)
                    .opacity(isCritical ? 1.0 : 0.85)
                    .frame(width: 28, alignment: .leading)
            } else {
                Text(label)
                    .font(GrubFont.size(7))
                    .foregroundColor(isCritical ? color : color.opacity(0.6))
                    .frame(width: 28, alignment: .leading)
            }

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
            // Category-coded borders: feed=green (food), play=yellow (fun),
            // dig=orange (effort/forage), pack=pale (inventory)
            ActionButton(icon: { AnyView(PixelIcon.meat(size: 28)) }, label: "FEED", borderColor: GrubPalette.green) {
                game.audio.play(.tap)
                game.showFeedOverlay = true
            }

            ActionButton(icon: { AnyView(PixelIcon.dice(size: 28)) }, label: "PLAY", borderColor: GrubPalette.yellow) {
                game.openPlay()
            }

            ActionButton(icon: { AnyView(PixelIcon.shovel(size: 28)) }, label: "DIG", borderColor: GrubPalette.orange) {
                game.audio.play(.dig)
                game.showForageOverlay = true
            }

            ActionButton(icon: { AnyView(PixelIcon.chest(size: 28)) }, label: "PACK", borderColor: GrubPalette.bone) {
                game.audio.play(.tap)
                game.showInventoryOverlay = true
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(GrubPalette.moss.opacity(0.55).ignoresSafeArea(edges: .bottom))
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
