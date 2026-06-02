# Grub: The Descent — Combat-Feel Prototype (Phase 0) Design

**Date:** 2026-06-01
**Status:** Approved (Jesse, 2026-06-01)
**Author:** Jesse + Claude
**Branch:** `descent` (base of all Descent work)
**Parent spec:** `Grub-Descent-Direction-Design.md` (Revision 3, approved) — this document implements that spec's **Phase 0 combat-feel prototype** only.

---

## 1. Why this document exists

The approved direction spec mandates a **standalone combat-feel prototype before any floor content is built** (Phase 0): "standalone controls + one enemy on one test floor; author approves game-feel before floor work." It explicitly **gates the fun success-criterion (SC2)** — if flicking Grub around and fighting does not feel good, no amount of floors, loot, or polish will save the Descent loop.

This spec scopes *only* that prototype. It deliberately excludes loot, the at-risk HUD, the floor pool, the pre-Descent link screen, the first-session script, the share card, and rewarded ads — all of which are Phase 2 (v1.2) and all of which assume the feel is already proven.

The single question this prototype answers: **does moving Grub and bonking an enemy feel good on touch?**

## 2. Scope

### In scope
- One hardcoded one-screen room.
- 8-direction grid movement with smooth visual interpolation (the direction spec's decided model, §5.6/§6.6).
- One enemy (a fanged slime) with chase AI.
- Attack (hit the faced tile) and Interact (descend via stairs).
- A fixed 3 hearts; lose all → death; reach stairs + Interact → win.
- Real PixelLab art for the slime; the existing directional Grub PNGs for the player.
- A DEBUG-only entry point and a headless launch hook for screenshots.
- Unit tests on the engine.

### Out of scope (Phase 2+, not this prototype)
- Loot, provisional-loot banking, the two persistence commit points.
- The at-risk HUD, depth tiers, the Extract/Descend decision, death-penalty tiers.
- The home-stat → run-resource link (hearts are fixed at 3 here).
- Multiple floors / the floor pool / seeded population.
- Torch/fog, Jump/Dodge, hazards.
- The pre-Descent link screen, first-session onboarding script, share card.
- Rewarded ("Second Wind", "Double Loot") and interstitial ads.
- `GameState+Descent.swift` and any write to the persistent save (the prototype never persists).

### Success criterion
A human (Jesse) plays the prototype on the simulator/device and judges the moment-to-moment feel. Done = the feel is approved (proceed to Phase 2) or rejected with specific tuning/model feedback (iterate). All existing tests remain green; the new engine tests pass.

## 3. Decisions locked during brainstorming

| Decision | Choice |
|---|---|
| Build scope | Combat-feel prototype only (direction-spec Phase 0). |
| Approach | **A** — real spec-layout files, minimal content; the prototype becomes Phase 2's spine (no throwaway). |
| Enemy | Fanged slime / hostile blob — an "evil mirror" of Grub, rendered deliberately distinct (dark/red, spikes, fangs, angry eyes). |
| Enemy art | Real PixelLab art generated now (placeholder blob renders until it lands). |
| Feel target | **Snappy / arcade** — fast movement, short attack cooldown, generous i-frames, enemy dies in 1–2 hits. |
| Entry point | DEBUG-only: DIG button presents the Descent (on-theme — the direction spec plans "DESCEND replaces DIG"); release DIG = forage, untouched. |

## 4. Architecture

New files under `GrubIOS/Descent/` (matches direction spec §6.5, stripped to prototype scope):

| File | Responsibility | SwiftUI? |
|---|---|---|
| `DescentTuning.swift` | All feel constants in one struct (mirrors the existing `DecayConstants` pattern). | No |
| `DescentEngine.swift` | Pure value-type `struct` engine: run state + `mutating` update/intent methods; grid collision, enemy chase AI, combat, i-frames, win/death. Defines runtime types `GridPoint`, `Direction8`, `Tile`, `EnemyInstance`, `RunStatus`. | **No (SwiftUI-free, unit-testable)** |
| `DescentSceneView.swift` | `Canvas` rendering engine state (tilemap → slime → Grub → flashes), pixel-perfect (`.interpolation(.none)`). | Yes |
| `DescentControlsView.swift` | Left virtual joystick (8-way quantized) + right Attack/Interact buttons. Emits intents. | Yes |
| `DescentView.swift` | Container: owns `@State var engine`, drives the `TimelineView(.animation)` loop, hosts scene + controls, overlays win/death cards, handles dismissal back to home. | Yes |

The engine is a **`struct`**, not an `ObservableObject` — kept SwiftUI/Combine-free so it is a pure, trivially testable value type (direction spec §6.5 requires a "SwiftUI-free, unit-testable" engine). The view holds it in `@State`; each `TimelineView` tick calls `engine.update(dt:)` and the mutation re-renders. No `GameState+Descent.swift` in this phase because there is nothing to persist.

## 5. The room & tile model

- A hardcoded grid, **11 wide × 15 tall** (portrait, one screen, no scrolling — direction spec §6.6).
- `[[Character]]` using the direction spec's legend: `#` wall (impassable), `.` floor (passable), `E` entry/Grub spawn, `>` stairs down (Interact target), `S` slime spawn. Unknown chars → treated as floor and logged in DEBUG.
- Border walls plus a couple of interior wall clumps so movement and collision are visually legible.
- Tile size in points = `floor(sceneWidth / 11)`, pixel-snapped; the scene is centered.
- **Floor-1-passable rule (direction spec §5.6/SC3):** a clear path from `E` to `>` exists that does **not** require killing the slime — combat is optional, so the room is always beatable even if the combat feel is wrong. (Engine test asserts this path exists.)

## 6. Movement & controls

- **Joystick:** holding it moves Grub tile-by-tile in the 8-way-quantized joystick direction at `grubStepDuration` cadence, stopping when the next tile is a wall. The renderer interpolates Grub's on-screen position between the previous and current tile for smoothness; collision is per-tile.
- **Facing:** follows the joystick direction (8-way), selecting the directional Grub PNG.
- **Attack button:** hits the single tile Grub currently faces; respects `attackCooldown`.
- **Interact button:** dimmed unless Grub stands on `>`; pressing it on the stairs ends the run as a win. (Interact has no other targets in the prototype.)
- Controls are thumb-reachable; no precise taps required.

## 7. Combat & tuning

`DescentTuning` initial (snappy/arcade) values — playtest starting points, all in one struct:

| Constant | Value | Meaning |
|---|---|---|
| `grubStepDuration` | 0.13 s/tile (~7 tiles/s) | Fast, flickable movement. |
| `attackCooldown` | 0.25 s | Rapid bonking. |
| `attackFlashDuration` | 0.12 s | Grub attack pose flash + slime hit flash. |
| `enemyHP` | 2 | Dies in 1–2 hits. |
| `enemyStepDuration` | 0.22 s/tile (~4.5 tiles/s) | Slower than Grub → catchable but threatening. |
| `enemyTouchDamage` | 1 | Hearts removed per contact. |
| `enemyContactIFrames` | 0.8 s | Invulnerability after a hit (direction spec §7 value). |
| `startHearts` | 3 | Fixed for the prototype (home-stat link is Phase 2). |
| `gridWidth × gridHeight` | 11 × 15 | One-screen floor size. |

- **Enemy AI:** `.chase` — each enemy step, move one tile greedily toward Grub (reduce the larger axis distance first; never step into a wall). Slow enough to read and dodge.
- **Taking damage:** if the slime enters Grub's tile while Grub is **not** in i-frames → `−enemyTouchDamage` hearts, trigger a hurt flash, and start `enemyContactIFrames`. During i-frames, contact does nothing.
- **Attacking:** Attack damages an enemy occupying the faced tile by 1 HP, with a hit flash; HP ≤ 0 removes the slime.
- **End states (`RunStatus`):** `.playing` → `.dead` (hearts ≤ 0) or `.won` (Interact on `>`). Both show a simple full-screen card with a "Back" button returning to home.

## 8. Enemy art

- Generate a **top-down fanged slime** via PixelLab — dark/red palette, spikes, fangs, angry eyes, clearly distinct from Grub's soft green round blob.
- One top-down sprite is sufficient for the prototype (a slime reads radially symmetric; directional variants are deferred). Generated via the `pixellab_wait.sh` notify-on-ready poller.
- Until the PNG lands, the scene renders a **procedural placeholder** (a dark-red spiky blob) so engine/controls work is never blocked on art. The final PNG drops into the asset catalog as `descent_slime` and the renderer prefers it when present (same `UIImage(named:)`-or-fallback pattern as the nav icons).

## 9. Entry point (DEBUG only)

- In DEBUG builds, the home screen's **DIG** action presents `DescentView` as a `fullScreenCover`. This is on-theme: the direction spec plans "DESCEND replaces DIG." Release builds leave DIG = forage completely untouched (`#if DEBUG` guard around the routing only).
- A launch-environment hook `GRUB_DESCENT=1` (DEBUG only, same mechanism as the existing `GRUB_AUTOSTART`) presents the Descent immediately on launch, so the scene can be screenshotted headlessly on the simulator without a tap.

## 10. Testing

`DescentEngineTests` (pure struct ⇒ fast, deterministic):
- Movement steps one tile per `grubStepDuration` in the joystick direction; **wall collision** blocks the step.
- 8-way quantization: a diagonal joystick vector selects the correct `Direction8`.
- Attack reduces the HP of an enemy on the faced tile; a 2-HP slime dies after two hits; Attack on an empty faced tile does nothing.
- Contact removes a heart and starts i-frames; a second contact **during** i-frames removes nothing; after i-frames expire, contact removes again.
- Hearts reaching 0 sets `.dead`.
- Interact on `>` sets `.won`; Interact off the stairs does nothing.
- An `E`→`>` path exists that never enters the slime's tile (floor-1-passable invariant).

All existing tests (28) must stay green.

## 11. Regression safety

- The prototype writes nothing to `GameState`/UserDefaults — the home/base loop is provably untouched (direction spec §11).
- The only production-code change outside `Descent/` is the DEBUG-guarded DIG routing + the DEBUG launch hook in `ContentView`/`SplashView`-adjacent code; release behavior is unchanged.
- New files compile into the existing single target via XcodeGen folder references (no `project.yml` change expected; confirm after `xcodegen generate`).

## 12. What this prototype deliberately does not decide

Final feel numbers (§7 are starting points to be tuned on-device), whether grid-stepping ultimately feels right vs. a free-movement model (the prototype is exactly where that judgment gets made — if grid-stepping feels bad, that is a valid prototype outcome feeding back into the direction spec), enemy directional variants, and all Phase 2 systems listed under §2 "out of scope."
