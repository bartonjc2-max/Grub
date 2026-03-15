import SwiftUI

// MARK: - Game Font
struct GrubFont {
    static let name = "PressStart2P-Regular"

    static func size(_ s: CGFloat) -> Font {
        .custom(name, size: s)
    }
}

// MARK: - Color Palette (Swamp Candy)
struct GrubPalette {
    static let void_color = Color(hex: "#1a1a2e")
    static let moss = Color(hex: "#16213e")
    static let green = Color(hex: "#4ecca3")
    static let pale = Color(hex: "#e8e8d0")
    static let red = Color(hex: "#e94560")
    static let yellow = Color(hex: "#f5a623")
    static let purple = Color(hex: "#7b2d8b")
    static let white = Color(hex: "#f0f0f0")
    static let moonpale = Color(hex: "#c8c8b8")
    static let dimGreen = Color(hex: "#2a7a60")
    static let grey = Color(hex: "#888880")
    static let bone = Color(hex: "#c0b89a")
    static let nearBlack = Color(hex: "#0d0d0d")
    static let deepMoss = Color(hex: "#2a2a4e")
    static let orange = Color(hex: "#e07020")

    static let paletteMap: [Character: Color] = [
        "1": Color(hex: "#1a1a2e"),
        "2": Color(hex: "#4ecca3"),
        "3": Color(hex: "#e8e8d0"),
        "4": Color(hex: "#e94560"),
        "5": Color(hex: "#f5a623"),
        "6": Color(hex: "#7b2d8b"),
        "7": Color(hex: "#16213e"),
        "8": Color(hex: "#c8c8b8"),
        "9": Color(hex: "#2a7a60"),
        "A": Color(hex: "#ffffff"),
        "B": Color(hex: "#888880"),
        "C": Color(hex: "#c0b89a"),
        "D": Color(hex: "#0d0d0d"),
        "E": Color(hex: "#e07020"),
    ]
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Sprite Generator
struct SpriteRenderer {
    /// Generate a 32x32 grub sprite as a grid of palette indices
    static func makeGrubSprite(state: String, tick: Int = 0) -> [[Character]] {
        let s = 32
        var data = Array(repeating: Array(repeating: Character("0"), count: s), count: s)

        let bodyCol: Character = state == "dead" ? "B" : state == "dying" ? (tick % 10 < 5 ? "9" : "D") : state == "sick" || state == "starving" ? "9" : state == "angry" ? "E" : state == "energized" ? "3" : "2"
        let highlightCol: Character = state == "dead" ? "C" : state == "dying" ? "D" : state == "energized" ? "A" : "3"

        func px(_ r: Int, _ c: Int, _ col: Character) {
            if r >= 0 && r < s && c >= 0 && c < s { data[r][c] = col }
        }

        func circle(_ cr: Int, _ cc: Int, _ rad: Int, _ col: Character) {
            for r in (cr - rad)...(cr + rad) {
                for c in (cc - rad)...(cc + rad) {
                    if (r - cr) * (r - cr) + (c - cc) * (c - cc) <= rad * rad {
                        px(r, c, col)
                    }
                }
            }
        }

        func rect(_ r: Int, _ c: Int, _ w: Int, _ h: Int, _ col: Character) {
            for i in r..<(r + h) {
                for j in c..<(c + w) {
                    px(i, j, col)
                }
            }
        }

        // ── Idle sub-animation system ──
        // 8-second master cycle at 20fps = 160 ticks
        let idleCycle = tick % 160
        // Which "behavior" block we're in (changes every ~24 seconds = 3 full cycles)
        let behaviorSlot = (tick / 160) % 8

        // Bob: varies by behavior
        let bob: Int
        if state == "sleeping" || state == "starving" {
            bob = 0
        } else if state == "hungry" {
            // Slow, heavy bob — sluggish
            bob = Int(sin(Double(tick) * 0.04) * 1.0)
        } else if state == "unhappy" {
            // Barely moves — dejected
            bob = Int(sin(Double(tick) * 0.03) * 0.5)
        } else if state == "angry" {
            // Rapid shaking
            bob = tick % 4 < 2 ? 1 : -1
        } else if state == "energized" {
            // Fast bouncy
            bob = Int(sin(Double(tick) * 0.3) * 2.0)
        } else if state == "tap_jump" {
            // Surprised jump up
            let p = tick % 30
            if p < 10 { bob = -4 } else if p < 20 { bob = -2 } else { bob = 0 }
        } else if state == "tap_wave" {
            // Gentle side-to-side wave
            bob = Int(sin(Double(tick) * 0.15) * 1.0)
        } else if state == "tap_spin" {
            // Quick wiggle/spin
            bob = Int(sin(Double(tick) * 0.4) * 2.0)
        } else if state == "tap_nuzzle" {
            // Lean forward gently
            bob = Int(sin(Double(tick) * 0.08) * 1.5) + 1
        } else if state == "tap_chirp" {
            // Quick hop hop
            let p = tick % 16
            bob = p < 4 ? -3 : p < 8 ? 0 : p < 12 ? -2 : 0
        } else if state == "tap_peek" {
            // Shrink down then pop up
            let p = tick % 30
            if p < 10 { bob = 3 } else if p < 15 { bob = -3 } else { bob = 0 }
        } else if state == "tap_bounce" {
            // Continuous bounce
            bob = Int(sin(Double(tick) * 0.35) * 3.0)
        } else if state == "tap_hungry" {
            // Slump
            bob = 2
        } else if state == "tap_grumpy" {
            // Angry shake
            bob = tick % 4 < 2 ? 1 : -1
        } else if state == "tap_sick" {
            // Wobble weakly
            bob = Int(sin(Double(tick) * 0.06) * 1.0)
        } else if state == "idle" {
            switch behaviorSlot {
            case 0, 1: // Normal gentle bob
                bob = Int(sin(Double(tick) * 0.1) * 1.5)
            case 2: // Excited bounce
                bob = Int(sin(Double(tick) * 0.25) * 2.5)
            case 3: // Slow heavy breathing
                bob = Int(sin(Double(tick) * 0.05) * 1.0)
            case 4: // Jittery
                bob = tick % 6 < 3 ? 1 : -1
            case 5: // Hop (brief jump mid-cycle)
                let hopPhase = idleCycle
                if hopPhase > 60 && hopPhase < 80 {
                    bob = -3
                } else if hopPhase >= 80 && hopPhase < 90 {
                    bob = Int(sin(Double(tick) * 0.15) * 1.5)
                } else {
                    bob = Int(sin(Double(tick) * 0.1) * 1.5)
                }
            default: // Normal
                bob = Int(sin(Double(tick) * 0.1) * 1.5)
            }
        } else {
            bob = Int(sin(Double(tick) * 0.1) * 1.5)
        }

        // Horizontal sway for look-around
        let sway: Int
        if state == "tap_spin" {
            sway = Int(sin(Double(tick) * 0.5) * 3.0)
        } else if state == "tap_wave" {
            sway = Int(sin(Double(tick) * 0.12) * 2.0)
        } else if state == "tap_nuzzle" {
            sway = Int(sin(Double(tick) * 0.1) * 1.5)
        } else if state == "idle" && (behaviorSlot == 6 || behaviorSlot == 7) {
            sway = Int(sin(Double(tick) * 0.06) * 2.0)
        } else {
            sway = 0
        }

        let cy = 16 + bob
        let cx = 16 + sway

        // Body
        circle(cy, cx, 9, "1")
        circle(cy, cx, 8, bodyCol)

        // Highlight
        px(cy - 5, cx - 3, highlightCol)
        px(cy - 5, cx - 2, highlightCol)
        px(cy - 6, cx - 2, highlightCol)

        // ── Arms ──
        let leftArmX = cx - 10
        let rightArmX = cx + 7
        if state == "playing" || state == "energized" {
            // Arms up
            rect(cy + 1, leftArmX, 4, 2, "1"); rect(cy + 1, leftArmX + 1, 3, 1, bodyCol)
            rect(cy + 1, rightArmX, 4, 2, "1"); rect(cy + 1, rightArmX + 1, 3, 1, bodyCol)
        } else if state == "angry" {
            // Arms raised, fists clenched — shaking fists
            let fistShake = tick % 8 < 4 ? 0 : 1
            rect(cy - fistShake, leftArmX, 4, 2, "1"); rect(cy - fistShake, leftArmX + 1, 3, 1, bodyCol)
            rect(cy + fistShake, rightArmX, 4, 2, "1"); rect(cy + fistShake, rightArmX + 1, 3, 1, bodyCol)
        } else if state == "hungry" || state == "starving" {
            // Arms clutching belly
            rect(cy + 4, cx - 7, 3, 2, "1"); rect(cy + 4, cx - 6, 2, 1, bodyCol)
            rect(cy + 4, cx + 4, 3, 2, "1"); rect(cy + 4, cx + 5, 2, 1, bodyCol)
        } else if state == "unhappy" {
            // Arms drooping low
            rect(cy + 5, leftArmX + 1, 3, 2, "1"); rect(cy + 5, leftArmX + 2, 2, 1, bodyCol)
            rect(cy + 5, rightArmX, 3, 2, "1"); rect(cy + 5, rightArmX + 1, 2, 1, bodyCol)
        } else if state == "tap_wave" {
            // One arm up waving
            let waveUp = tick % 20 < 10
            if waveUp {
                rect(cy - 2, leftArmX, 4, 2, "1"); rect(cy - 2, leftArmX + 1, 3, 1, bodyCol)
            } else {
                rect(cy, leftArmX, 4, 2, "1"); rect(cy, leftArmX + 1, 3, 1, bodyCol)
            }
            rect(cy + 3, rightArmX, 3, 2, "1"); rect(cy + 3, rightArmX + 1, 2, 1, bodyCol)
        } else if state == "tap_jump" || state == "tap_bounce" || state == "tap_chirp" {
            // Both arms up
            rect(cy, leftArmX, 4, 2, "1"); rect(cy, leftArmX + 1, 3, 1, bodyCol)
            rect(cy, rightArmX, 4, 2, "1"); rect(cy, rightArmX + 1, 3, 1, bodyCol)
        } else if state == "tap_spin" {
            // Arms out to sides, spinning
            let armPhase = tick % 12
            let leftY = armPhase < 6 ? cy + 1 : cy + 3
            let rightY = armPhase < 6 ? cy + 3 : cy + 1
            rect(leftY, leftArmX, 4, 2, "1"); rect(leftY, leftArmX + 1, 3, 1, bodyCol)
            rect(rightY, rightArmX, 4, 2, "1"); rect(rightY, rightArmX + 1, 3, 1, bodyCol)
        } else if state == "tap_nuzzle" {
            // Arms tucked in, cozy
            rect(cy + 2, cx - 8, 3, 2, "1"); rect(cy + 2, cx - 7, 2, 1, bodyCol)
            rect(cy + 2, cx + 5, 3, 2, "1"); rect(cy + 2, cx + 6, 2, 1, bodyCol)
        } else if state == "tap_peek" {
            // Arms covering face then revealing
            let p = tick % 30
            if p < 10 {
                rect(cy - 2, cx - 7, 4, 3, "1"); rect(cy - 2, cx - 6, 3, 2, bodyCol)
                rect(cy - 2, cx + 3, 4, 3, "1"); rect(cy - 2, cx + 4, 3, 2, bodyCol)
            } else {
                rect(cy + 1, leftArmX, 4, 2, "1"); rect(cy + 1, leftArmX + 1, 3, 1, bodyCol)
                rect(cy + 1, rightArmX, 4, 2, "1"); rect(cy + 1, rightArmX + 1, 3, 1, bodyCol)
            }
        } else if state == "tap_grumpy" {
            // Arms crossed
            rect(cy + 2, cx - 6, 5, 2, "1"); rect(cy + 2, cx - 5, 4, 1, bodyCol)
            rect(cy + 2, cx + 1, 5, 2, "1"); rect(cy + 2, cx + 2, 4, 1, bodyCol)
        } else if state == "idle" && behaviorSlot == 2 {
            // Wave: one arm up, one down, alternating
            let waveUp = idleCycle % 40 < 20
            if waveUp {
                rect(cy - 1, leftArmX, 4, 2, "1"); rect(cy - 1, leftArmX + 1, 3, 1, bodyCol)
                rect(cy + 3, rightArmX, 3, 2, "1"); rect(cy + 3, rightArmX + 1, 2, 1, bodyCol)
            } else {
                rect(cy + 3, leftArmX + 1, 3, 2, "1"); rect(cy + 3, leftArmX + 2, 2, 1, bodyCol)
                rect(cy - 1, rightArmX, 4, 2, "1"); rect(cy - 1, rightArmX + 1, 3, 1, bodyCol)
            }
        } else if state == "idle" && behaviorSlot == 4 {
            // Fidget: arms twitch
            let fidget = idleCycle % 20 < 10 ? 1 : 0
            rect(cy + 3 - fidget, leftArmX + 1, 3, 2, "1"); rect(cy + 3 - fidget, leftArmX + 2, 2, 1, bodyCol)
            rect(cy + 3 + fidget, rightArmX, 3, 2, "1"); rect(cy + 3 + fidget, rightArmX + 1, 2, 1, bodyCol)
        } else {
            // Default arms down
            rect(cy + 3, leftArmX + 1, 3, 2, "1"); rect(cy + 3, leftArmX + 2, 2, 1, bodyCol)
            rect(cy + 3, rightArmX, 3, 2, "1"); rect(cy + 3, rightArmX + 1, 2, 1, bodyCol)
        }

        // ── Eyes ──
        let leftEyeC = cx - 5
        let rightEyeC = cx + 2

        if state == "dead" {
            // X eyes
            px(cy - 3, leftEyeC, "1"); px(cy - 2, leftEyeC + 1, "1")
            px(cy - 3, leftEyeC + 2, "1"); px(cy - 2, leftEyeC - 1, "1")
            px(cy - 3, rightEyeC, "1"); px(cy - 2, rightEyeC + 1, "1")
            px(cy - 3, rightEyeC + 2, "1"); px(cy - 2, rightEyeC - 1, "1")
        } else if state == "dying" {
            // Flickering spiral eyes — desperate
            let flicker = tick % 20 < 10
            if flicker {
                // Spiral dots
                px(cy - 3, leftEyeC, "D"); px(cy - 2, leftEyeC + 2, "D")
                px(cy - 3, rightEyeC + 2, "D"); px(cy - 2, rightEyeC, "D")
            } else {
                // X eyes fading in
                px(cy - 3, leftEyeC, "1"); px(cy - 2, leftEyeC + 1, "1")
                px(cy - 3, rightEyeC, "1"); px(cy - 2, rightEyeC + 1, "1")
            }
        } else if state == "sleeping" {
            // Flat line eyes
            rect(cy - 3, leftEyeC, 4, 1, "1")
            rect(cy - 3, rightEyeC, 4, 1, "1")
        } else if state == "starving" {
            // Spiral/dazed eyes — tiny dots
            px(cy - 3, leftEyeC + 1, "1")
            px(cy - 3, rightEyeC + 1, "1")
        } else if state == "hungry" {
            // Half-lidded, tired eyes
            for r in (cy-3)...(cy-2) { for c in leftEyeC...(leftEyeC+2) { px(r, c, "1") } }
            for r in (cy-3)...(cy-2) { for c in rightEyeC...(rightEyeC+2) { px(r, c, "1") } }
            // Heavy lids — cover top row
            for c in leftEyeC...(leftEyeC+2) { px(cy - 3, c, bodyCol) }
            for c in rightEyeC...(rightEyeC+2) { px(cy - 3, c, bodyCol) }
            // Dim glint
            px(cy - 3, leftEyeC, "9"); px(cy - 3, rightEyeC, "9")
        } else if state == "angry" {
            // Angry slant eyes — V brows
            for r in (cy-4)...(cy-2) { for c in leftEyeC...(leftEyeC+2) { px(r, c, "1") } }
            for r in (cy-4)...(cy-2) { for c in rightEyeC...(rightEyeC+2) { px(r, c, "1") } }
            // Angry brow — slanted inward
            px(cy - 5, leftEyeC + 2, "1"); px(cy - 5, leftEyeC + 3, "1")
            px(cy - 6, leftEyeC + 3, "1")
            px(cy - 5, rightEyeC, "1"); px(cy - 5, rightEyeC - 1, "1")
            px(cy - 6, rightEyeC - 1, "1")
            // Red glint
            px(cy - 4, leftEyeC, "6"); px(cy - 4, rightEyeC, "6")
        } else if state == "unhappy" {
            // Sad droopy eyes — normal eyes but looking down
            for r in (cy-3)...(cy-2) { for c in leftEyeC...(leftEyeC+2) { px(r, c, "1") } }
            for r in (cy-3)...(cy-2) { for c in rightEyeC...(rightEyeC+2) { px(r, c, "1") } }
            // Glint at bottom (looking down)
            px(cy - 2, leftEyeC + 1, "9"); px(cy - 2, rightEyeC + 1, "9")
        } else if state == "energized" {
            // Wide bright eyes — extra big with double glint
            for r in (cy-5)...(cy-2) { for c in (leftEyeC-1)...(leftEyeC+2) { px(r, c, "1") } }
            for r in (cy-5)...(cy-2) { for c in (rightEyeC)...(rightEyeC+3) { px(r, c, "1") } }
            // Double glints — sparkly
            px(cy - 5, leftEyeC - 1, "A"); px(cy - 4, leftEyeC + 1, "A")
            px(cy - 5, rightEyeC + 3, "A"); px(cy - 4, rightEyeC + 1, "A")
        } else if state == "tap_jump" {
            // Wide surprised eyes
            for r in (cy-5)...(cy-2) { for c in leftEyeC...(leftEyeC+3) { px(r, c, "1") } }
            for r in (cy-5)...(cy-2) { for c in rightEyeC...(rightEyeC+3) { px(r, c, "1") } }
            px(cy - 5, leftEyeC, "A"); px(cy - 5, rightEyeC + 3, "A")
        } else if state == "tap_wave" {
            // Happy closed-eye smile (^_^)
            px(cy - 4, leftEyeC, "1"); px(cy - 3, leftEyeC + 1, "1"); px(cy - 4, leftEyeC + 2, "1")
            px(cy - 4, rightEyeC, "1"); px(cy - 3, rightEyeC + 1, "1"); px(cy - 4, rightEyeC + 2, "1")
        } else if state == "tap_spin" {
            // Dizzy spiral eyes — alternating dots
            let sp = tick % 12
            if sp < 6 {
                px(cy - 4, leftEyeC, "1"); px(cy - 3, leftEyeC + 2, "1")
                px(cy - 3, rightEyeC, "1"); px(cy - 4, rightEyeC + 2, "1")
            } else {
                px(cy - 3, leftEyeC, "1"); px(cy - 4, leftEyeC + 2, "1")
                px(cy - 4, rightEyeC, "1"); px(cy - 3, rightEyeC + 2, "1")
            }
        } else if state == "tap_nuzzle" {
            // Blissful closed eyes — happy curves
            rect(cy - 3, leftEyeC, 3, 1, "1")
            rect(cy - 3, rightEyeC, 3, 1, "1")
            px(cy - 4, leftEyeC, "1"); px(cy - 4, leftEyeC + 2, "1")
            px(cy - 4, rightEyeC, "1"); px(cy - 4, rightEyeC + 2, "1")
        } else if state == "tap_chirp" {
            // Bright excited eyes with double glint
            for r in (cy-4)...(cy-2) { for c in leftEyeC...(leftEyeC+2) { px(r, c, "1") } }
            for r in (cy-4)...(cy-2) { for c in rightEyeC...(rightEyeC+2) { px(r, c, "1") } }
            px(cy - 4, leftEyeC, "A"); px(cy - 3, leftEyeC + 2, "A")
            px(cy - 4, rightEyeC + 2, "A"); px(cy - 3, rightEyeC, "A")
        } else if state == "tap_peek" {
            // Hidden then peek — eyes appear after hide phase
            let p = tick % 30
            if p < 10 {
                // Hiding — no eyes visible (arms cover face)
            } else {
                // Peek! Big sparkly eyes
                for r in (cy-5)...(cy-2) { for c in leftEyeC...(leftEyeC+3) { px(r, c, "1") } }
                for r in (cy-5)...(cy-2) { for c in rightEyeC...(rightEyeC+3) { px(r, c, "1") } }
                px(cy - 5, leftEyeC, "A"); px(cy - 4, leftEyeC + 2, "A")
                px(cy - 5, rightEyeC + 3, "A"); px(cy - 4, rightEyeC + 1, "A")
            }
        } else if state == "tap_bounce" {
            // Joyful squinting eyes
            px(cy - 4, leftEyeC, "1"); px(cy - 3, leftEyeC + 1, "1"); px(cy - 4, leftEyeC + 2, "1")
            px(cy - 4, rightEyeC, "1"); px(cy - 3, rightEyeC + 1, "1"); px(cy - 4, rightEyeC + 2, "1")
        } else if state == "tap_hungry" {
            // Pleading puppy eyes — big with tears
            for r in (cy-5)...(cy-2) { for c in leftEyeC...(leftEyeC+3) { px(r, c, "1") } }
            for r in (cy-5)...(cy-2) { for c in rightEyeC...(rightEyeC+3) { px(r, c, "1") } }
            px(cy - 5, leftEyeC + 1, "A"); px(cy - 5, rightEyeC + 2, "A")
            // Tear
            px(cy - 1, leftEyeC + 1, "3")
        } else if state == "tap_grumpy" {
            // Angry narrowed eyes
            for r in (cy-3)...(cy-2) { for c in leftEyeC...(leftEyeC+2) { px(r, c, "1") } }
            for r in (cy-3)...(cy-2) { for c in rightEyeC...(rightEyeC+2) { px(r, c, "1") } }
            // Angry brows
            px(cy - 4, leftEyeC + 2, "1"); px(cy - 5, leftEyeC + 3, "1")
            px(cy - 4, rightEyeC, "1"); px(cy - 5, rightEyeC - 1, "1")
        } else if state == "tap_sick" {
            // Woozy uneven eyes
            for r in (cy-4)...(cy-2) { for c in leftEyeC...(leftEyeC+2) { px(r, c, "1") } }
            px(cy - 3, rightEyeC, "1"); px(cy - 3, rightEyeC + 1, "1")
            px(cy - 4, leftEyeC, "9")
        } else {
            // Blink check — blink for 6 ticks every ~90 ticks
            let blinkCycle = tick % 90
            let isBlinking = state == "idle" && blinkCycle >= 84

            // Look direction for eye glint position
            let lookOffset: Int
            if state == "idle" && behaviorSlot == 6 {
                lookOffset = -1
            } else if state == "idle" && behaviorSlot == 7 {
                lookOffset = 1
            } else if state == "idle" && behaviorSlot == 5 && idleCycle > 100 {
                lookOffset = 0
            } else {
                lookOffset = 0
            }

            if isBlinking {
                rect(cy - 3, leftEyeC, 3, 1, "1")
                rect(cy - 3, rightEyeC, 3, 1, "1")
            } else {
                // Normal 3x3 eyes with glint
                for r in (cy-4)...(cy-2) { for c in leftEyeC...(leftEyeC+2) { px(r, c, "1") } }
                for r in (cy-4)...(cy-2) { for c in rightEyeC...(rightEyeC+2) { px(r, c, "1") } }

                let leftGlintC = leftEyeC + max(0, min(2, 0 + lookOffset))
                let rightGlintC = rightEyeC + max(0, min(2, 0 + lookOffset))
                px(cy - 4, leftGlintC, "A")
                px(cy - 4, rightGlintC, "A")

                // Squint when jittery
                if state == "idle" && behaviorSlot == 4 && idleCycle % 30 < 8 {
                    for c in leftEyeC...(leftEyeC+2) { px(cy - 4, c, bodyCol) }
                    for c in rightEyeC...(rightEyeC+2) { px(cy - 4, c, bodyCol) }
                }
            }
        }

        // ── Mouth ──
        if state == "eating" {
            // Chewing animation — mouth opens and closes
            let chewPhase = tick % 20
            if chewPhase < 10 {
                // Mouth open wide — nom!
                rect(cy + 3, cx - 3, 6, 3, "1"); rect(cy + 4, cx - 2, 4, 2, "4")
            } else {
                // Mouth closed — chew
                rect(cy + 3, cx - 2, 5, 1, "1")
                px(cy + 4, cx - 1, "1"); px(cy + 4, cx, "1")
            }
            // Food crumbs flying out
            let crumbTick = tick % 30
            if crumbTick < 8 {
                px(cy + 2, cx + 5 + crumbTick / 3, "5")
                px(cy + 4, cx - 5 - crumbTick / 3, "5")
            }
            if crumbTick > 10 && crumbTick < 20 {
                px(cy + 1, cx + 4 + (crumbTick - 10) / 3, "5")
            }
            // Happy squint while eating
            if chewPhase < 10 {
                for c in (cx-5)...(cx-3) { px(cy - 4, c, bodyCol) }
                for c in (cx+2)...(cx+4) { px(cy - 4, c, bodyCol) }
            }
        } else if state == "drinking" {
            // Drinking animation — head tilts back, gulp visible
            let gulpPhase = tick % 24
            if gulpPhase < 12 {
                // Mouth open, tilted up — drinking
                px(cy + 2, cx - 1, "1"); px(cy + 2, cx, "1")
                px(cy + 3, cx - 2, "1"); px(cy + 3, cx + 1, "1")
                // Liquid color inside mouth
                px(cy + 2, cx - 1, "2"); px(cy + 2, cx, "2")
            } else {
                // Gulp — closed, satisfied
                px(cy + 3, cx - 1, "1"); px(cy + 3, cx, "1")
            }
            // Sparkle effect (health restoration)
            let sparkTick = tick % 16
            if sparkTick < 4 {
                px(cy - 9, cx - 5, "A"); px(cy - 7, cx + 6, "2")
            } else if sparkTick < 8 {
                px(cy - 8, cx + 5, "A"); px(cy - 10, cx - 3, "2")
            } else if sparkTick < 12 {
                px(cy - 6, cx - 7, "A"); px(cy - 9, cx + 4, "2")
            }
            // Happy closed eyes while drinking
            rect(cy - 3, cx - 5, 3, 1, "1")
            rect(cy - 3, cx + 2, 3, 1, "1")
            // Eyebrow raise
            px(cy - 5, cx - 4, "1"); px(cy - 5, cx + 3, "1")
        } else if state == "starving" {
            // Wobbly open mouth — gasping
            let gasp = tick % 30
            if gasp < 15 {
                rect(cy + 3, cx - 2, 4, 3, "1"); rect(cy + 4, cx - 1, 2, 1, "4")
            } else {
                px(cy + 3, cx - 1, "1"); px(cy + 3, cx, "1")
            }
        } else if state == "hungry" {
            // Flat frown — not happy about being hungry
            rect(cy + 4, cx - 2, 4, 1, "1")
            px(cy + 3, cx - 3, "1"); px(cy + 3, cx + 2, "1")
        } else if state == "angry" {
            // Gritting teeth, snarl
            rect(cy + 3, cx - 3, 6, 1, "1")
            // Teeth
            px(cy + 4, cx - 2, "A"); px(cy + 4, cx, "A"); px(cy + 4, cx + 2, "A")
            px(cy + 4, cx - 1, "1"); px(cy + 4, cx + 1, "1")
        } else if state == "unhappy" {
            // Sad wavering frown
            px(cy + 4, cx - 2, "1"); px(cy + 5, cx - 3, "1")
            px(cy + 5, cx - 1, "1"); px(cy + 5, cx, "1")
            px(cy + 4, cx + 1, "1")
        } else if state == "energized" {
            // Big :D grin
            rect(cy + 3, cx - 3, 7, 2, "1"); rect(cy + 4, cx - 2, 5, 1, "A")
        } else if state == "tap_jump" {
            // Surprised "O"
            px(cy + 3, cx - 1, "1"); px(cy + 3, cx, "1")
            px(cy + 4, cx - 2, "1"); px(cy + 4, cx + 1, "1")
            px(cy + 5, cx - 1, "1"); px(cy + 5, cx, "1")
        } else if state == "tap_wave" || state == "tap_bounce" {
            // Big smile
            px(cy + 3, cx - 3, "1"); px(cy + 3, cx - 2, "1"); px(cy + 3, cx - 1, "1")
            px(cy + 3, cx, "1"); px(cy + 3, cx + 1, "1"); px(cy + 3, cx + 2, "1")
            px(cy + 4, cx - 3, "1"); px(cy + 4, cx + 2, "1")
        } else if state == "tap_spin" {
            // Dizzy wavy mouth
            let sp = tick % 16
            if sp < 8 {
                px(cy + 3, cx - 2, "1"); px(cy + 4, cx - 1, "1"); px(cy + 3, cx, "1"); px(cy + 4, cx + 1, "1")
            } else {
                px(cy + 4, cx - 2, "1"); px(cy + 3, cx - 1, "1"); px(cy + 4, cx, "1"); px(cy + 3, cx + 1, "1")
            }
        } else if state == "tap_nuzzle" {
            // Tiny content smile
            px(cy + 3, cx - 1, "1"); px(cy + 3, cx, "1")
            px(cy + 4, cx - 2, "1"); px(cy + 4, cx + 1, "1")
        } else if state == "tap_chirp" {
            // Open chirping mouth
            let chirp = tick % 12
            if chirp < 6 {
                rect(cy + 3, cx - 2, 4, 2, "1"); rect(cy + 4, cx - 1, 2, 1, "4")
            } else {
                px(cy + 3, cx - 1, "1"); px(cy + 3, cx, "1")
            }
        } else if state == "tap_peek" {
            // Hidden then big grin
            let p = tick % 30
            if p >= 10 {
                rect(cy + 3, cx - 3, 7, 2, "1"); rect(cy + 4, cx - 2, 5, 1, "4")
            }
        } else if state == "tap_hungry" {
            // Drooling frown
            px(cy + 4, cx - 2, "1"); px(cy + 5, cx - 3, "1")
            px(cy + 5, cx - 1, "1"); px(cy + 4, cx, "1")
            // Drool
            let drool = tick % 20
            if drool < 10 { px(cy + 5, cx + 1, "3"); px(cy + 6, cx + 1, "3") }
        } else if state == "tap_grumpy" {
            // Snarl
            rect(cy + 3, cx - 3, 6, 1, "1")
            px(cy + 4, cx - 2, "A"); px(cy + 4, cx, "A"); px(cy + 4, cx + 2, "A")
        } else if state == "tap_sick" {
            // Queasy wavy mouth
            px(cy + 4, cx - 2, "1"); px(cy + 3, cx - 1, "1"); px(cy + 4, cx, "1"); px(cy + 3, cx + 1, "1")
        } else if state == "dying" {
            // Gasping open mouth
            let gasp = tick % 20 < 10
            if gasp {
                px(cy + 3, cx - 2, "1"); px(cy + 3, cx - 1, "1")
                px(cy + 4, cx - 2, "1"); px(cy + 4, cx - 1, "1")
                px(cy + 3, cx, "1")
            } else {
                px(cy + 3, cx - 1, "1")
            }
        } else if state == "sad" || state == "sick" {
            // Frown
            px(cy + 3, cx - 2, "1"); px(cy + 4, cx - 3, "1")
            px(cy + 4, cx - 1, "1"); px(cy + 3, cx, "1")
        } else if state == "playing" {
            // Big grin
            px(cy + 3, cx - 3, "1"); px(cy + 3, cx - 2, "1")
            px(cy + 4, cx - 2, "1"); px(cy + 4, cx - 1, "1")
            px(cy + 3, cx, "1"); px(cy + 3, cx + 1, "1")
        } else if state == "idle" {
            // Idle mouth variations
            switch behaviorSlot {
            case 0, 6, 7: // Neutral smile
                px(cy + 3, cx - 2, "1"); px(cy + 3, cx - 1, "1"); px(cy + 3, cx, "1")
                px(cy + 4, cx - 3, "1"); px(cy + 4, cx + 1, "1")
            case 1: // Tiny 'o' — curious
                px(cy + 3, cx - 1, "1"); px(cy + 3, cx, "1")
                px(cy + 4, cx - 1, "1"); px(cy + 4, cx, "1")
            case 2: // Wide smile (excited)
                px(cy + 3, cx - 3, "1"); px(cy + 3, cx - 2, "1")
                px(cy + 4, cx - 2, "1"); px(cy + 4, cx - 1, "1")
                px(cy + 4, cx, "1"); px(cy + 3, cx + 1, "1")
                px(cy + 3, cx + 2, "1")
            case 3: // Breathing — mouth opens slightly on "exhale"
                let exhale = sin(Double(tick) * 0.05) > 0.3
                if exhale {
                    px(cy + 3, cx - 1, "1"); px(cy + 3, cx, "1")
                    px(cy + 4, cx - 2, "1"); px(cy + 4, cx + 1, "1")
                    px(cy + 5, cx - 1, "1"); px(cy + 5, cx, "1")
                } else {
                    px(cy + 3, cx - 1, "1"); px(cy + 3, cx, "1")
                }
            case 4: // Gritting (jittery)
                rect(cy + 3, cx - 2, 5, 1, "1")
                px(cy + 4, cx - 2, "1"); px(cy + 4, cx, "1"); px(cy + 4, cx + 2, "1")
            case 5: // :D after hop
                if idleCycle > 60 && idleCycle < 100 {
                    rect(cy + 3, cx - 2, 5, 2, "1"); rect(cy + 4, cx - 1, 3, 1, "4")
                } else {
                    px(cy + 3, cx - 2, "1"); px(cy + 3, cx - 1, "1"); px(cy + 3, cx, "1")
                    px(cy + 4, cx - 3, "1"); px(cy + 4, cx + 1, "1")
                }
            default:
                px(cy + 3, cx - 2, "1"); px(cy + 3, cx - 1, "1"); px(cy + 3, cx, "1")
                px(cy + 4, cx - 3, "1"); px(cy + 4, cx + 1, "1")
            }
        } else {
            // Default mouth
            px(cy + 3, cx - 2, "1"); px(cy + 3, cx - 1, "1"); px(cy + 3, cx, "1")
            px(cy + 4, cx - 3, "1"); px(cy + 4, cx + 1, "1")
        }

        // ── Sick sweat ──
        if state == "sick" {
            let sweatDrop = (tick % 40) < 20
            px(cy - 6, cx - 6, "3"); px(cy - 5, cx - 7, "3")
            if sweatDrop { px(cy - 4, cx - 7, "3") }
        }

        // ── Dying flicker — red pixels shedding off ──
        if state == "dying" {
            let f = tick % 30
            // Flickering red sparks around body
            if f < 8 {
                px(cy - 7, cx - 5, "D"); px(cy - 6, cx + 6, "D")
                px(cy + 5, cx - 7, "D"); px(cy + 6, cx + 4, "D")
            } else if f < 16 {
                px(cy - 5, cx + 7, "D"); px(cy - 8, cx + 3, "D")
                px(cy + 4, cx + 6, "D"); px(cy + 7, cx - 3, "D")
            } else if f < 24 {
                px(cy - 6, cx - 7, "D"); px(cy - 9, cx - 2, "D")
                px(cy + 3, cx - 5, "D"); px(cy + 5, cx + 5, "D")
            }
            // Body shiver — shift pixels
            let shiver = tick % 6 < 3 ? 1 : -1
            px(cy, cx + shiver + 8, bodyCol)
        }

        // ── Hungry stomach rumble lines ──
        if state == "hungry" || state == "starving" {
            let rumble = tick % 40
            if rumble < 10 {
                px(cy + 6, cx - 4, "9"); px(cy + 6, cx - 3, "9"); px(cy + 6, cx - 2, "9")
            } else if rumble < 20 {
                px(cy + 7, cx - 3, "9"); px(cy + 7, cx - 2, "9"); px(cy + 7, cx - 1, "9")
            }
            // Starving gets extra wobble lines
            if state == "starving" {
                let wobble = tick % 20
                if wobble < 10 {
                    px(cy + 5, cx + 3, "9"); px(cy + 5, cx + 4, "9")
                }
            }
        }

        // ── Angry steam puffs ──
        if state == "angry" {
            let steamPhase = tick % 30
            if steamPhase < 8 {
                px(cy - 8, cx - 5, "E"); px(cy - 9, cx - 4, "E")
                px(cy - 8, cx + 5, "E"); px(cy - 9, cx + 4, "E")
            } else if steamPhase < 16 {
                px(cy - 9, cx - 6, "E"); px(cy - 10, cx - 5, "E")
                px(cy - 9, cx + 6, "E"); px(cy - 10, cx + 5, "E")
            }
        }

        // ── Unhappy tear drops ──
        if state == "unhappy" {
            let tearPhase = tick % 50
            let tearY = cy - 1 + tearPhase / 10
            if tearPhase < 30 {
                px(tearY, leftEyeC + 1, "3")
            }
        }

        // ── Tap reaction particles ──
        if state == "tap_chirp" {
            // Musical notes floating up
            let notePhase = tick % 30
            let noteY = cy - 8 - notePhase / 4
            if notePhase < 20 { px(noteY, cx + 6, "2"); px(noteY - 1, cx + 7, "2") }
        }
        if state == "tap_spin" {
            // Motion blur dots around body
            let sp = tick % 8
            px(cy, cx - 11 + sp, "2"); px(cy, cx + 11 - sp, "2")
        }
        if state == "tap_nuzzle" {
            // Little hearts float up
            let hPhase = tick % 40
            if hPhase < 20 {
                let hY = cy - 8 - hPhase / 5
                px(hY, cx + 5, "6"); px(hY, cx + 6, "6")
                px(hY + 1, cx + 5, "6")
            }
        }
        if state == "tap_jump" {
            // Exclamation mark above head
            px(cy - 11, cx, "A"); px(cy - 12, cx, "A"); px(cy - 13, cx, "A")
            px(cy - 15, cx, "A")
        }
        if state == "tap_grumpy" {
            // Anger symbol
            let ang = tick % 16
            if ang < 8 {
                px(cy - 10, cx + 4, "6"); px(cy - 10, cx + 5, "6")
                px(cy - 9, cx + 4, "6"); px(cy - 9, cx + 5, "6")
            }
        }

        // ── Energized sparkles everywhere ──
        if state == "energized" {
            let sp = tick % 20
            if sp < 5 {
                px(cy - 10, cx - 6, "A"); px(cy - 8, cx + 7, "5"); px(cy + 6, cx - 5, "A")
            } else if sp < 10 {
                px(cy - 9, cx + 5, "A"); px(cy - 7, cx - 8, "5"); px(cy + 7, cx + 4, "A")
            } else if sp < 15 {
                px(cy - 11, cx - 3, "5"); px(cy - 6, cx + 8, "A"); px(cy + 5, cx + 6, "5")
            }
        }

        // ── Sleeping Zs (animated drift) ──
        if state == "sleeping" {
            let zPhase = tick % 80
            if zPhase > 15 {
                let zOff = zPhase / 20
                px(5 - zOff, cx + 4 + zOff, "2")
                px(5 - zOff, cx + 5 + zOff, "2")
                px(6 - zOff, cx + 4 + zOff, "2")
            }
            if zPhase > 40 {
                let zOff2 = (zPhase - 40) / 20
                px(3 - zOff2, cx + 6 + zOff2, "2")
                px(3 - zOff2, cx + 7 + zOff2, "2")
                px(4 - zOff2, cx + 6 + zOff2, "2")
            }
        }

        // ── Idle sparkles (happy state) ──
        if state == "idle" && behaviorSlot == 2 {
            let sparkPhase = idleCycle % 30
            if sparkPhase < 8 {
                px(cy - 9, cx - 6, "A")
                px(cy - 8, cx + 7, "5")
            } else if sparkPhase < 16 {
                px(cy - 7, cx + 8, "A")
                px(cy - 10, cx - 4, "5")
            }
        }

        // ── Idle particles: curiosity dots float up ──
        if state == "idle" && behaviorSlot == 1 {
            let dotPhase = idleCycle % 50
            if dotPhase > 10 && dotPhase < 40 {
                let dotY = cy - 8 - (dotPhase - 10) / 5
                px(dotY, cx + 6, "2")
            }
        }

        // ── Antennae / feelers on top of head ──
        if state != "dead" && state != "sleeping" {
            let antennaWave = Int(sin(Double(tick) * 0.15) * 1.5)
            px(cy - 9, cx - 2 + antennaWave, "2")
            px(cy - 10, cx - 3 + antennaWave, "2")
            px(cy - 9, cx + 2 - antennaWave, "2")
            px(cy - 10, cx + 3 - antennaWave, "2")
            // Antenna tips glow slightly
            px(cy - 11, cx - 3 + antennaWave, "A")
            px(cy - 11, cx + 3 - antennaWave, "A")
        }

        return data
    }

    /// Render a sprite grid to a SwiftUI Canvas context
    static func drawSprite(context: inout GraphicsContext, sprite: [[Character]], origin: CGPoint, scale: CGFloat) {
        for row in 0..<sprite.count {
            for col in 0..<sprite[row].count {
                let ch = sprite[row][col]
                if ch == "0" { continue }
                guard let color = GrubPalette.paletteMap[ch] else { continue }
                let rect = CGRect(
                    x: origin.x + CGFloat(col) * scale,
                    y: origin.y + CGFloat(row) * scale,
                    width: scale,
                    height: scale
                )
                context.fill(Path(rect), with: .color(color))
            }
        }
    }

    // MARK: - Time Phase

    enum TimePhase {
        case dawn, day, dusk, night

        static var current: TimePhase {
            let hour = Calendar.current.component(.hour, from: Date())
            if hour >= 5 && hour < 8 { return .dawn }
            if hour >= 8 && hour < 18 { return .day }
            if hour >= 18 && hour < 21 { return .dusk }
            return .night
        }

        var skyColors: [Color] {
            switch self {
            case .dawn: return [
                Color(hex: "#0e0e2a"), Color(hex: "#1a1040"), Color(hex: "#2a1848"),
                Color(hex: "#3a2050"), Color(hex: "#4a2850"), Color(hex: "#5a3048"),
                Color(hex: "#6a3848"), Color(hex: "#7a4040"),
            ]
            case .day: return [
                Color(hex: "#0e0e2a"), Color(hex: "#12123a"), Color(hex: "#161640"),
                Color(hex: "#1a1a44"), Color(hex: "#1e1e48"), Color(hex: "#1a1a3e"),
                Color(hex: "#1a1a3e"), Color(hex: "#1a1a3e"),
            ]
            case .dusk: return [
                Color(hex: "#0a0a1e"), Color(hex: "#1a1030"), Color(hex: "#2a1838"),
                Color(hex: "#3a2040"), Color(hex: "#4a2838"), Color(hex: "#5a3030"),
                Color(hex: "#6a3830"), Color(hex: "#7a4028"),
            ]
            case .night: return [
                Color(hex: "#060612"), Color(hex: "#080818"), Color(hex: "#0a0a1e"),
                Color(hex: "#0c0c22"), Color(hex: "#0e0e26"), Color(hex: "#0e0e26"),
                Color(hex: "#0e0e26"), Color(hex: "#0e0e26"),
            ]
            }
        }

        var groundTop: Color {
            switch self {
            case .dawn: return Color(hex: "#3a2a4e")
            case .day: return Color(hex: "#4a3860")
            case .dusk: return Color(hex: "#382848")
            case .night: return Color(hex: "#2a1e3e")
            }
        }

        var groundMid: Color {
            switch self {
            case .dawn: return Color(hex: "#2a1e3a")
            case .day: return Color(hex: "#302444")
            case .dusk: return Color(hex: "#281c38")
            case .night: return Color(hex: "#1e1430")
            }
        }

        var groundDark: Color {
            switch self {
            case .dawn: return Color(hex: "#1e1630")
            case .day: return Color(hex: "#241a38")
            case .dusk: return Color(hex: "#1c142e")
            case .night: return Color(hex: "#140e24")
            }
        }

        var sporeOpacity: Double {
            switch self {
            case .dawn: return 0.25
            case .day: return 0.2
            case .dusk: return 0.3
            case .night: return 0.55
            }
        }

        var starOpacity: Double {
            switch self {
            case .dawn: return 0.15
            case .day: return 0.0
            case .dusk: return 0.2
            case .night: return 0.7
            }
        }

        var showDrips: Bool { self != .night }

        var mushGlowOpacity: Double {
            switch self {
            case .night: return 0.4
            default: return 0.0
            }
        }

        var isNight: Bool { self == .night }
    }

    /// Draw the background scene — pixel-art cave burrow (everything snapped to grid)
    static func drawBackground(context: inout GraphicsContext, size: CGSize, tick: Int) {
        let w = size.width
        let h = size.height

        // Pixel grid size — everything snaps to this for chunky pixel look
        let px: CGFloat = max(4, floor(min(w, h) / 64))

        func block(_ x: CGFloat, _ y: CGFloat, _ bw: CGFloat, _ bh: CGFloat, _ color: Color) {
            let sx = floor(x / px) * px
            let sy = floor(y / px) * px
            let sw = ceil(bw / px) * px
            let sh = ceil(bh / px) * px
            context.fill(Path(CGRect(x: sx, y: sy, width: sw, height: sh)), with: .color(color))
        }

        let phase = TimePhase.current

        // Banded sky (pixel rows, not smooth gradient)
        let skyBands = 8
        let skyColors = phase.skyColors
        let groundStart = h * 0.72
        let bandH = groundStart / CGFloat(skyBands)
        for i in 0..<skyBands {
            block(0, CGFloat(i) * bandH, w, bandH + px, skyColors[i])
        }

        // Stars (small pixel dots with twinkling)
        let starPositions: [(CGFloat, CGFloat)] = [
            (0.1, 0.08), (0.25, 0.15), (0.45, 0.05), (0.6, 0.12),
            (0.78, 0.08), (0.92, 0.18), (0.15, 0.28), (0.5, 0.22),
            (0.85, 0.32), (0.35, 0.35), (0.7, 0.25),
        ]
        if phase.starOpacity > 0 {
            let starColor = Color(hex: "#4ecca3")
            for (i, (sx, sy)) in starPositions.enumerated() {
                let twinkle = sin(Double(tick + i * 37) * 0.05) * 0.3 + 0.7
                block(sx * w, sy * groundStart, px, px,
                      starColor.opacity(phase.starOpacity * twinkle))
            }
        }

        // Stalactites from ceiling (chunky pixel blocks)
        let ceilColor = Color(hex: phase.isNight ? "#060612" : "#0a0a1e")
        // Ceiling bar
        block(0, 0, w, px * 2, ceilColor)
        // Stalactite shapes (each is a stack of blocks getting narrower)
        let stalactiteData: [(CGFloat, [Int])] = [
            (0.08, [5, 4, 3, 2, 1]),
            (0.22, [4, 3, 2, 2, 1, 1]),
            (0.42, [3, 2, 1, 1]),
            (0.58, [5, 4, 3, 2, 1, 1]),
            (0.75, [3, 3, 2, 1]),
            (0.92, [4, 3, 2, 1, 1]),
        ]
        for (sx, widths) in stalactiteData {
            var y = px * 2
            for bw in widths {
                let totalW = CGFloat(bw) * px
                block(sx * w - totalW / 2, y, totalW, px, ceilColor)
                y += px
            }
        }

        // Rock texture spots on cave walls (blocky)
        let rockColor = Color(hex: phase.isNight ? "#0c0c20" : "#151538")
        let rockSpots: [(CGFloat, CGFloat, Int, Int)] = [
            (0.05, 0.3, 3, 2), (0.88, 0.25, 2, 3), (0.12, 0.5, 2, 2),
            (0.92, 0.55, 3, 2), (0.03, 0.6, 2, 1), (0.8, 0.15, 2, 2),
            (0.5, 0.45, 1, 2), (0.3, 0.55, 2, 1), (0.7, 0.5, 1, 1),
        ]
        for (rx, ry, rw, rh) in rockSpots {
            block(rx * w, ry * groundStart, CGFloat(rw) * px, CGFloat(rh) * px, rockColor)
        }

        // Ground — chunky pixel rows with earthy palette
        let dirtDark = phase.groundDark
        let dirtMid = phase.groundMid
        let dirtLight = Color(hex: "#2e2040")
        let mossGreen = phase.groundMid
        let mossBright = phase.groundTop
        let dirtDeep = phase.groundDark

        // Grass/moss top edge — irregular pixel line
        let grassY = groundStart
        // Main ground fill
        block(0, grassY, w, h - grassY, dirtDark)

        // Mossy top row — bright green irregular edge
        let mossPattern = [1,1,0,1,1,1,0,0,1,1,1,1,0,1,1,0,1,1,1,0,1,1,0,0,1,1,1,1,0,1,1,1]
        let mossCols = Int(w / px)
        for c in 0..<mossCols {
            let patIdx = c % mossPattern.count
            if mossPattern[patIdx] == 1 {
                block(CGFloat(c) * px, grassY, px, px, mossBright)
            } else {
                block(CGFloat(c) * px, grassY, px, px, mossGreen)
            }
        }
        // Second row — dimmer moss
        for c in 0..<mossCols {
            let patIdx = (c + 3) % mossPattern.count
            block(CGFloat(c) * px, grassY + px, px, px, patIdx % 3 == 0 ? mossGreen : dirtMid)
        }

        // Dirt texture rows
        let dirtRows = Int((h - grassY - px * 2) / px)
        for r in 0..<dirtRows {
            let y = grassY + px * 2 + CGFloat(r) * px
            for c in 0..<mossCols {
                let hash = (r * 17 + c * 31) % 7
                let color: Color
                if hash == 0 { color = dirtLight }
                else if hash == 1 { color = dirtDeep }
                else if hash == 2 && r < 3 { color = Color(hex: "#342650") }
                else { color = dirtDark }
                block(CGFloat(c) * px, y, px, px, color)
            }
        }

        // Mushrooms — blocky pixel art
        let mushData: [(CGFloat, Color, Int)] = [
            (0.08, Color(hex: "#9b3dab"), 3),
            (0.28, Color(hex: "#7b2d8b"), 2),
            (0.72, Color(hex: "#ab4dbb"), 4),
            (0.9, Color(hex: "#8b3d9b"), 2),
        ]
        for (mx, capColor, capW) in mushData {
            let baseX = floor(mx * w / px) * px
            let baseY = grassY - px
            let stemColor = Color(hex: "#c0b89a")
            // Stem (1px wide, 2px tall)
            block(baseX, baseY - px, px, px * 2, stemColor)
            // Cap
            let totalCapW = CGFloat(capW) * px
            block(baseX - totalCapW / 2 + px / 2, baseY - px * 2, totalCapW, px, capColor)
            // Cap highlight
            block(baseX - totalCapW / 2 + px / 2, baseY - px * 2, px, px, capColor.opacity(0.7))
        }

        // Animated floating spores
        let sporeColor = Color(hex: "#4ecca3")
        let sporeData: [(baseX: CGFloat, baseY: CGFloat, speed: CGFloat, phaseOffset: Int)] = [
            (0.15, 0.7, 0.3, 0), (0.4, 0.8, 0.2, 40), (0.65, 0.6, 0.35, 80),
            (0.82, 0.75, 0.25, 120), (0.25, 0.65, 0.15, 60), (0.55, 0.85, 0.3, 100),
            (0.9, 0.7, 0.2, 20), (0.1, 0.9, 0.28, 140), (0.48, 0.72, 0.18, 90),
            (0.72, 0.82, 0.32, 50),
        ]
        for spore in sporeData {
            let cycle = 400
            let t = (tick + spore.phaseOffset) % cycle
            let yOffset = CGFloat(t) * spore.speed
            let y = (spore.baseY * groundStart) - yOffset
            let wrappedY = y < 0 ? y + groundStart : y
            if wrappedY < groundStart {
                block(spore.baseX * w, wrappedY, px, px, sporeColor.opacity(phase.sporeOpacity))
            }
        }

        // Dripping water
        if phase.showDrips {
            let dripSources: [(x: CGFloat, startY: CGFloat, cycle: Int)] = [
                (0.25, 0.06, 120), (0.62, 0.04, 160), (0.45, 0.08, 140),
            ]
            for drip in dripSources {
                let t = tick % drip.cycle
                let progress = CGFloat(t) / CGFloat(drip.cycle)
                let dropY = drip.startY * h + progress * (groundStart - drip.startY * h)
                if progress < 0.3 {
                    block(drip.x * w, drip.startY * h, px, px,
                          Color(hex: "#4ecca3").opacity(0.3 * Double(progress / 0.3)))
                }
                if progress >= 0.3 && progress < 0.9 {
                    block(drip.x * w, dropY, px, px * 2, Color(hex: "#4ecca3").opacity(0.25))
                }
                if progress >= 0.9 {
                    let splash = (progress - 0.9) / 0.1
                    block(drip.x * w - px, groundStart - px, px * 3, px,
                          Color(hex: "#4ecca3").opacity(0.2 * (1 - Double(splash))))
                }
            }
        }

        // Mushroom glow at night
        if phase.mushGlowOpacity > 0 {
            for (mx, _, capW) in mushData {
                let glow = sin(Double(tick) * 0.03) * 0.15 + phase.mushGlowOpacity
                let baseX = floor(mx * w / px) * px
                let glowSize = CGFloat(capW + 2) * px
                block(baseX - glowSize / 2 + px / 2, grassY - px * 3,
                      glowSize, px * 2,
                      Color(hex: "#7b2d8b").opacity(glow))
            }
        }

        // Ambient drifting particles
        let particles: [(baseX: CGFloat, y: CGFloat, speed: CGFloat, offset: Int)] = [
            (0.0, 0.35, 0.15, 0), (0.3, 0.55, 0.1, 200), (0.7, 0.25, 0.12, 100),
        ]
        for p in particles {
            let cycle = 600
            let t = (tick + p.offset) % cycle
            let x = (p.baseX + CGFloat(t) * p.speed / CGFloat(cycle))
            let wrappedX = x.truncatingRemainder(dividingBy: 1.0)
            block(wrappedX * w, p.y * groundStart, px, px,
                  GrubPalette.pale.opacity(0.06))
        }

        // Vignette (still smooth — this is a screen effect, not world art)
        let vigGradient = Gradient(stops: [
            .init(color: .clear, location: 0.3),
            .init(color: Color.black.opacity(0.45), location: 1.0),
        ])
        context.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .radialGradient(vigGradient, center: CGPoint(x: w / 2, y: h * 0.42),
                                           startRadius: h * 0.28, endRadius: h * 0.72))
    }
}

// MARK: - Pixel Icon Renderer
struct PixelIcon {
    /// Render a small pixel-art icon as a grid of colors
    /// Each icon is defined as a grid string where characters map to colors

    static func star(size: CGFloat = 16) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 9
            // 9x9 star shape
            let grid: [String] = [
                "000010000",
                "000010000",
                "001111100",
                "011111110",
                "111111111",
                "011111110",
                "001101100",
                "001001000",
                "010000100",
            ]
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if ch == "1" {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(GrubPalette.yellow))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    static func coin(size: CGFloat = 16) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 9
            let grid: [String] = [
                "000111000",
                "001111100",
                "011151110",
                "011515110",
                "011151110",
                "011515110",
                "011151110",
                "001111100",
                "000111000",
            ]
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                    if ch == "1" {
                        context.fill(Path(rect), with: .color(GrubPalette.yellow))
                    } else if ch == "5" {
                        context.fill(Path(rect), with: .color(Color(hex: "#c8912a")))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    static func meat(size: CGFloat = 20) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 11
            let grid: [String] = [
                "00000000000",
                "00011100000",
                "00144410000",
                "01444441000",
                "01444441000",
                "01444441100",
                "00144441100",
                "00014441000",
                "00001CC1000",
                "00001CC1000",
                "00000110000",
            ]
            let colors: [Character: Color] = [
                "1": Color(hex: "#1a1a2e"),
                "4": Color(hex: "#e94560"),
                "C": Color(hex: "#c0b89a"),
            ]
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if let color = colors[ch] {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    static func gamepad(size: CGFloat = 20) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 11
            let grid: [String] = [
                "00000000000",
                "01111111100",
                "11122111110",
                "11122111110",
                "11111111110",
                "11111122110",
                "11111122110",
                "01111111100",
                "00111111000",
                "00011110000",
                "00000000000",
            ]
            let colors: [Character: Color] = [
                "1": Color(hex: "#16213e"),
                "2": Color(hex: "#4ecca3"),
            ]
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if let color = colors[ch] {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    static func pill(size: CGFloat = 20) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 9
            let grid: [String] = [
                "000111000",
                "001441100",
                "014444100",
                "014444100",
                "01AAAA100",
                "01AAAA100",
                "001AA1100",
                "000111000",
                "000000000",
            ]
            let colors: [Character: Color] = [
                "1": Color(hex: "#1a1a2e"),
                "4": Color(hex: "#e94560"),
                "A": Color(hex: "#ffffff"),
            ]
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if let color = colors[ch] {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    static func nut(size: CGFloat = 16) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 9
            let grid: [String] = [
                "000111000",
                "001111100",
                "011555110",
                "015555510",
                "015555510",
                "015555510",
                "011555110",
                "001111100",
                "000111000",
            ]
            let colors: [Character: Color] = [
                "1": Color(hex: "#1a1a2e"),
                "5": Color(hex: "#c0b89a"),
            ]
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if let color = colors[ch] {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    static func bento(size: CGFloat = 16) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 9
            let grid: [String] = [
                "111111111",
                "144414441",
                "144414441",
                "144414441",
                "111111111",
                "122212221",
                "122212221",
                "122212221",
                "111111111",
            ]
            let colors: [Character: Color] = [
                "1": Color(hex: "#1a1a2e"),
                "4": Color(hex: "#e94560"),
                "2": Color(hex: "#4ecca3"),
            ]
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if let color = colors[ch] {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    static func cake(size: CGFloat = 16) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 9
            let grid: [String] = [
                "000050000",
                "000050000",
                "001111100",
                "014444410",
                "01AAAA10",
                "014444410",
                "011111110",
                "015555510",
                "011111110",
            ]
            let colors: [Character: Color] = [
                "1": Color(hex: "#1a1a2e"),
                "4": Color(hex: "#e94560"),
                "5": Color(hex: "#f5a623"),
                "A": Color(hex: "#ffffff"),
                "0": nil,
            ].compactMapValues { $0 }
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if let color = colors[ch] {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    static func arrowLeft(size: CGFloat = 16) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 7
            let grid: [String] = [
                "0001000",
                "0011000",
                "0111110",
                "1111110",
                "0111110",
                "0011000",
                "0001000",
            ]
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if ch == "1" {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(GrubPalette.pale))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    static func arrowRight(size: CGFloat = 16) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 7
            let grid: [String] = [
                "0001000",
                "0001100",
                "0111110",
                "0111111",
                "0111110",
                "0001100",
                "0001000",
            ]
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if ch == "1" {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(GrubPalette.pale))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    static func broccoli(size: CGFloat = 16) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 9
            let grid: [String] = [
                "000222000",
                "002222200",
                "022222220",
                "022222220",
                "022222220",
                "002222200",
                "000111000",
                "000111000",
                "000111000",
            ]
            let colors: [Character: Color] = [
                "1": Color(hex: "#2a7a60"),
                "2": Color(hex: "#4ecca3"),
            ]
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if let color = colors[ch] {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    static func pizza(size: CGFloat = 16) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 9
            let grid: [String] = [
                "000010000",
                "000110000",
                "001551000",
                "001555100",
                "015555510",
                "015545510",
                "155555551",
                "155454551",
                "111111111",
            ]
            let colors: [Character: Color] = [
                "1": Color(hex: "#c0b89a"),
                "5": Color(hex: "#f5a623"),
                "4": Color(hex: "#e94560"),
            ]
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if let color = colors[ch] {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    static func carrot(size: CGFloat = 16) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 9
            let grid: [String] = [
                "000222000",
                "002020200",
                "000222000",
                "000550000",
                "000555000",
                "005555000",
                "005555500",
                "055555500",
                "005555000",
            ]
            let colors: [Character: Color] = [
                "2": Color(hex: "#4ecca3"),
                "5": Color(hex: "#f5a623"),
            ]
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if let color = colors[ch] {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    static func statsIcon(size: CGFloat = 16) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 9
            let grid: [String] = [
                "000000010",
                "000000110",
                "000001110",
                "000011110",
                "001011110",
                "011011110",
                "111011110",
                "111011110",
                "111111111",
            ]
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if ch == "1" {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(GrubPalette.green))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    // MARK: - Pixel Grid Helper

    static func pixelGrid(size: CGFloat, grid: [String], colors: [Character: Color]) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / CGFloat(grid[0].count)
            for (r, row) in grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    if let color = colors[ch] {
                        let rect = CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s + 0.5, height: s + 0.5)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    // MARK: - Ingredient Icons

    static func mossClump(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "000000000", "000220000", "002222000", "022222200",
            "022922200", "022222200", "002222000", "000220000", "000000000",
        ], colors: ["2": Color(hex: "#4ecca3"), "9": Color(hex: "#2a7a60")])
    }

    static func caveBeetle(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "000000000", "001000100", "010111010", "011111110",
            "011171110", "011111110", "010111010", "001000100", "000000000",
        ], colors: ["1": Color(hex: "#1a1a2e"), "7": Color(hex: "#16213e")])
    }

    static func mudRoot(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "000010000", "000110000", "001551000", "000155100",
            "000155100", "001551000", "001550000", "000550000", "000000000",
        ], colors: ["1": Color(hex: "#1a1a2e"), "5": Color(hex: "#c0b89a")])
    }

    static func dewDrop(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "000010000", "000110000", "001221000", "012222100",
            "012A22100", "012222100", "001221000", "000110000", "000000000",
        ], colors: ["1": Color(hex: "#1a1a2e"), "2": Color(hex: "#4ecca3"), "A": Color(hex: "#ffffff")])
    }

    static func glowshroom(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "000666000", "006666600", "066A66600", "066666600",
            "006666600", "000111000", "000555000", "000555000", "000000000",
        ], colors: ["6": Color(hex: "#7b2d8b"), "A": Color(hex: "#ffffff"), "1": Color(hex: "#1a1a2e"), "5": Color(hex: "#c0b89a")])
    }

    static func crystalShard(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "000010000", "000110000", "001221000", "001AA1000",
            "012AA2100", "012222100", "012222100", "001111000", "000000000",
        ], colors: ["1": Color(hex: "#1a1a2e"), "2": Color(hex: "#4ecca3"), "A": Color(hex: "#ffffff")])
    }

    static func paleWorm(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "000000000", "033000000", "033300000", "003330000",
            "000333000", "000033300", "000003330", "000000330", "000000000",
        ], colors: ["3": Color(hex: "#e8e8d0")])
    }

    static func slimeBerry(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "000220000", "002002000", "001441000", "014444100",
            "014A44100", "014444100", "001441000", "000110000", "000000000",
        ], colors: ["1": Color(hex: "#1a1a2e"), "2": Color(hex: "#4ecca3"), "4": Color(hex: "#e94560"), "A": Color(hex: "#ffffff")])
    }

    static func moonPetal(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "000010000", "000110000", "001AA1000", "01AAAA100",
            "01ABAA100", "01AAAA100", "001AA1000", "000110000", "000000000",
        ], colors: ["1": Color(hex: "#1a1a2e"), "A": Color(hex: "#ffffff"), "B": Color(hex: "#c8c8b8")])
    }

    static func emberSeed(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "000050000", "000550000", "001551000", "015555100",
            "015A55100", "015555100", "001551000", "000110000", "000000000",
        ], colors: ["1": Color(hex: "#1a1a2e"), "5": Color(hex: "#f5a623"), "A": Color(hex: "#ffffff")])
    }

    static func ancientSpore(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "000060000", "006566000", "065656600", "065A56600",
            "065656600", "006566000", "000660000", "000000000", "000000000",
        ], colors: ["6": Color(hex: "#7b2d8b"), "5": Color(hex: "#f5a623"), "A": Color(hex: "#ffffff")])
    }

    static func goldenBug(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "000000000", "001000100", "010555010", "055555550",
            "055A55550", "055555550", "010555010", "001000100", "000000000",
        ], colors: ["1": Color(hex: "#1a1a2e"), "5": Color(hex: "#f5a623"), "A": Color(hex: "#ffffff")])
    }

    // MARK: - UI Icons

    static func heart(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "011011000", "111111100", "111111100", "111111100",
            "011111000", "001110000", "000100000", "000000000", "000000000",
        ], colors: ["1": Color(hex: "#e94560")])
    }

    static func leaf(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "000001100", "000011000", "000112000", "001122000",
            "012220000", "022200000", "012000000", "001000000", "000000000",
        ], colors: ["1": Color(hex: "#2a7a60"), "2": Color(hex: "#4ecca3")])
    }

    static func bag(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "001111000", "010000100", "011111100", "015555100",
            "015555100", "015555100", "015555100", "011111100", "000000000",
        ], colors: ["1": Color(hex: "#1a1a2e"), "5": Color(hex: "#c0b89a")])
    }

    static func drumstick(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "000111000", "001444100", "014444100", "014444100",
            "001441000", "000110000", "000550000", "000550000", "000000000",
        ], colors: ["1": Color(hex: "#1a1a2e"), "4": Color(hex: "#e94560"), "5": Color(hex: "#c0b89a")])
    }

    // Shovel — for DIG button
    static func shovel(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "000030000",
            "000130000",
            "000130000",
            "000130000",
            "000130000",
            "012222210",
            "122222210",
            "012222100",
            "001111000",
        ], colors: [
            "1": Color(hex: "#1a1a2e"),
            "2": Color(hex: "#888880"),
            "3": Color(hex: "#c0b89a"),
        ])
    }

    // Chest — for PACK button
    static func chest(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "000000000",
            "011111110",
            "155555510",
            "155555510",
            "111111110",
            "155525510",
            "155555510",
            "155555510",
            "111111110",
        ], colors: [
            "1": Color(hex: "#1a1a2e"),
            "5": Color(hex: "#c0b89a"),
            "2": Color(hex: "#f5a623"),
        ])
    }

    // Book — for JOURNAL button
    static func book(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "000000000",
            "011111100",
            "015555100",
            "015555100",
            "011111100",
            "015555100",
            "015555100",
            "011111100",
            "000000000",
        ], colors: [
            "1": Color(hex: "#4ecca3"),
            "5": Color(hex: "#e8e8d0"),
        ])
    }

    // Gear — for SETTINGS button
    static func gear(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "010010100",
            "011111100",
            "011111100",
            "111111110",
            "011111100",
            "011111100",
            "010110100",
            "000110000",
            "000000000",
        ], colors: [
            "1": Color(hex: "#c0b89a"),
        ])
    }

    // Dice — for PLAY button
    static func dice(size: CGFloat = 16) -> some View {
        pixelGrid(size: size, grid: [
            "000000000",
            "011111110",
            "017111710",
            "011111110",
            "011171110",
            "011111110",
            "017111710",
            "011111110",
            "000000000",
        ], colors: [
            "1": Color(hex: "#e8e8d0"),
            "7": Color(hex: "#1a1a2e"),
        ])
    }

    // MARK: - Ingredient Icon Mapper

    @ViewBuilder
    static func ingredientIcon(_ id: String, size: CGFloat = 16) -> some View {
        switch id {
        case "moss_clump": mossClump(size: size)
        case "cave_beetle": caveBeetle(size: size)
        case "mud_root": mudRoot(size: size)
        case "dew_drop": dewDrop(size: size)
        case "glowshroom": glowshroom(size: size)
        case "crystal_shard": crystalShard(size: size)
        case "pale_worm": paleWorm(size: size)
        case "slime_berry": slimeBerry(size: size)
        case "moon_petal": moonPetal(size: size)
        case "ember_seed": emberSeed(size: size)
        case "ancient_spore": ancientSpore(size: size)
        case "golden_bug": goldenBug(size: size)
        default: mossClump(size: size)
        }
    }
}

// MARK: - Scanline Overlay
struct ScanlineOverlay: View {
    var body: some View {
        Canvas { context, size in
            var y: CGFloat = 0
            while y < size.height {
                let rect = CGRect(x: 0, y: y + 2, width: size.width, height: 2)
                context.fill(Path(rect), with: .color(Color.black.opacity(0.08)))
                y += 4
            }
        }
        .allowsHitTesting(false)
    }
}
