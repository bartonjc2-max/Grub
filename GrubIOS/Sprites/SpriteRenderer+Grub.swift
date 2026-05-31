import SwiftUI

// MARK: - Procedural Grub Sprite
extension SpriteRenderer {
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
}
