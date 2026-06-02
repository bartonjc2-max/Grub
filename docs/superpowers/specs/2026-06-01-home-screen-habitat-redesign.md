# Home Screen Redesign: Full-Screen Cave Habitat

**Date:** 2026-06-01
**Status:** Draft (pending author review)
**Author:** Jesse + Claude
**Related:** `2026-05-31-grub-descent-direction-design.md` (the two-loop Descent direction this serves)

---

## 1. Why

The current home screen is **five stacked horizontal bands** — top bar → viewport → (banner) → stat bars → action buttons. The viewport is squeezed into the middle ~45% of the screen; the chrome eats the rest. After a full art pass (V3 hero, 6 emotional states, walk frames, eating, blink, PixelLab stat icons), the **presentation layer is now the weakest part of the screen** — the beautiful hero sits in a small box surrounded by admin-panel chrome.

This redesign makes the **cave the whole screen** and floats a minimal translucent HUD over it. Same systems, same gameplay — a presentation re-layer that lets the art breathe and turns the home screen into an immersive "living cave habitat."

### Goals
- G1. Full-screen cave scene; Grub roams a larger floor; HUD overlays the scene instead of stacking below it.
- G2. Preserve **every** existing system: stats, feed/play/forage/inventory, banners (dying/nap/expedition), overlays, time-of-day animation, all V3 sprites.
- G3. Zero gameplay/logic change — this is layout + a new background asset only.
- G4. Keep it **always-shippable** and reversible (the old band layout stays in git; the new layout is additive where possible).

### Non-Goals
- NG1. Not building the Descent (Phase 2). The DESCEND button is *staged* (§5) but not wired to a Descent — DIG/forage stays in that slot until Phase 2.
- NG2. No in-scene descent feature (pit/shaft/portal). Explored and rejected — it wasted vertical art space and cluttered a calm home. The Descent launches from the button row.
- NG3. No decoration-on-scene placement system (the `placedDecorations` BurrowOverlay stays as-is for now; "furnish the cave" is a possible later feature, explicitly out of scope).
- NG4. No new gameplay states, stats, or economy.

### Success criteria
- SC1. App builds and all existing tests pass.
- SC2. Every function reachable today is reachable in the new layout. **Regression checklist (the `body` rewrite touches all of these — each must survive):** FEED, PLAY, DIG, PACK (inventory), LOG (journal), ⚙ (settings); the modal overlays — event, feed, minigame, evolution, death, name-entry, forage, forage-results, inventory, game-selector, burrow, expedition, expedition-results, journal, settings-menu; the expedition-find popup; the `ScanlineOverlay`; the `ToastView`; the dying/nap/expedition banners; and the two `.onReceive` lifecycle handlers (`willResignActive`/`didBecomeActive`) + `.statusBarHidden()`.
- SC3. The cave scene fills the full screen; Grub + all his animation states render on the floor correctly; the procedural particle/time-of-day layer still animates on top.
- SC4. HUD is legible over the scene at phone size (stats readable, buttons tappable ≥44pt).
- SC5. Existing saves load unchanged; no migration needed (no new persisted state).

---

## 2. The scene

**Backdrop asset:** a single minimal cave chamber ("Cave 2" from the 2026-06-01 PixelLab bake-off) — teal/purple organic columns, a few subtle crystals, a clear floor pool at the bottom, darker simple zones top and bottom for HUD overlay. Generated via PixelLab pixflux with `grub_S` as palette anchor, so it matches the hero exactly.

- **Asset:** `cave_home.imageset` (portrait, ~180×390 native → scaled to fill). Stored in `Assets.xcassets`.
- **Rendering:** drawn as the bottom layer, `aspectRatio(.fill)`, `interpolation(.none)`, ignoring safe area so it bleeds edge-to-edge.
- **Animation layer (corrected after code review):** `SpriteRenderer.drawBackground` currently has **no separable tint pass** — its time-of-day color shift IS the hand-drawn walls/sky/ground (each structural `block()` is filled with `phase.skyColors[i]` / `phase.groundDark` etc., verified at SpriteRenderer.swift:137–198). The only structure-independent atmosphere elements are stars, spores, drips, mushroom glow, ambient particles, and the vignette. Therefore we **cannot** simply "skip the walls and keep the tint" — skipping the walls skips the tint.

  **Resolved mechanism (was O-1+O-3, now decided):** refactor `drawBackground` into two functions:
  - `drawStructure(context:size:tick:)` — the existing hand-drawn cave (sky bands, ground, stalactites, rocks). **Not called** in the new home layout (the PNG replaces it). Kept for any fallback / other callers.
  - `drawAtmosphere(context:size:tick:)` — stars + spores + drips + mushroom-glow + ambient particles + vignette, **PLUS a newly-authored full-screen translucent tint rect** whose color is derived from `TimePhase.current` (e.g. a transparent warm overlay at dusk, cool dark at night). This is the *new* piece — it recreates the day/dusk/night recoloring as an overlay so it can sit on top of the fixed-lighting PNG. The home layout calls **only** `drawAtmosphere`, composited over `cave_home`.

  This gives `ParticleOverlay` a clean, independently-testable boundary and makes the time-of-day shift work over a static PNG.

**Grub placement (corrected scope):** `ViewportView`'s Canvas currently contains TWO Grub-render branches sharing one context: the **normal pet branch** (state dispatch, bob/breathe/squash/blink, floor at `size.height * 0.45`) AND the **expedition branch** (~180 lines: 8-phase walk/dig/jump behavior, its own particles + status text, floor at `size.height * 0.58`). `GrubLayer` must absorb **both** branches — extracting only the normal pet would orphan the expedition Canvas code. The sprite *logic* is untouched; both branches move together into `GrubLayer`, and both floor constants (0.45 and 0.58) are re-derived against the cave PNG's floor band (O-4).

---

## 3. The HUD (floating, translucent)

Overlaid on the scene via a `ZStack`, pinned to safe-area edges. Three clusters:

### Top-left — identity + stats
- Name (green) + "AGE Nd" (muted), plain text with a 1px drop-shadow for legibility over the scene (no panel).
- Below: **stat cluster** — 3 compact rows (icon + bar), order **HP / HNG / HAP**, on a low-opacity (~50%) dark panel with a 1px border. Reuses the `ui_icon_heart/drumstick/star` assets + the existing critical-pulse logic.

### Top-right — meta nav
- `LV{n}` (yellow) · `LOG` · `⚙` (PixelIcon.gear) as floating text/icon with drop-shadow. 44pt tap targets (already done in the prior top-bar commit — port the same treatment).

### Bottom — action row
- Translucent panel (~55% opacity) pinned to the bottom safe edge.
- 4 buttons, category-colored borders (from the prior commit): **FEED** (green) · **PLAY** (yellow) · **DIG** (orange) · **PACK** (bone).
- Buttons keep the existing `ActionButton` + `PixelButtonStyle` (0.95 press scale) and PixelIcon glyphs.

**Legibility:** every floating text element gets a drop-shadow; panels sit at enough opacity that bar fills and labels read against the busiest part of the cave. (O-2: confirm opacity values against the real scene on-device.)

---

## 4. Banners (dying / nap / expedition)

Today these inject as a horizontal band between viewport and stats. In the full-screen layout they become a **slim translucent strip overlaid near the top** of the scene (just under the identity cluster), appearing only when active. Same content, same conditions (`isDying` / `isNight` / `isOnExpedition`), repositioned. The expedition mini-Grub walk animation continues to play in the scene itself (unchanged).

---

## 5. The DESCEND button — staged, not dead

The Descent (Phase 2) doesn't exist yet. Author decision: the 4th-from-left adventure slot becomes **DESCEND** *when Phase 2 ships*, at which point forage (DIG) folds into PACK/inventory (foraged items already live there). **Until then:** the row stays **FEED / PLAY / DIG / PACK** exactly as today. This redesign shipping does **not** add a non-functional button. A one-line comment marks the slot that will convert. (This keeps NG1 honest — no dead UI.)

---

## 6. Architecture & files

This is a re-layer of `ContentView`. Approach: a new top-level `HomeScreenView` (full-screen ZStack) replaces the current `VStack`-of-bands `body`, **reusing the existing subviews as overlay content** rather than rewriting them.

| File | Change |
|---|---|
| `Assets.xcassets/cave_home.imageset` | NEW — the Cave 2 backdrop PNG + Contents.json |
| `ContentView.swift` | Restructure `body` inner content: `ZStack { CaveBackdrop; ParticleOverlay; GrubLayer; HUDOverlay }`. **Preserve all existing siblings of the band-VStack** — the ~16 modal overlays, ScanlineOverlay, ToastView, expedition-find popup, `.onReceive` lifecycle handlers, `.statusBarHidden()` (these stay as ZStack layers above the new scene). Extract BOTH Grub-render branches (normal + expedition) into `GrubLayer`. Keep `TopBarView`/`StatBarsView`/`ActionButtonsView` but restyle as floating edge-pinned overlays. Banners → overlaid strips. Delete the unused `PetInfoBar`. |
| `SpriteRenderer.swift` | Split `drawBackground` → `drawStructure(context:size:tick:)` (existing hand-drawn cave, unused by home layout) + `drawAtmosphere(context:size:tick:)` (stars/spores/drips/glow/particles/vignette + a NEW `TimePhase`-derived full-screen tint rect). Home calls only `drawAtmosphere` over the PNG. (resolves O-1/O-3) |
| `GrubAssetTests.swift` | Add `test_cave_home_resolves`. |

**Boundaries:**
- `CaveBackdrop` — static PNG, one job, no state beyond the image.
- `ParticleOverlay` — the existing procedural particles/tint, now transparent-bg.
- `GrubLayer` — the pet sprite render (lifted from ViewportView, logic unchanged).
- `HUDOverlay` — identity + stats + nav + buttons + banners, all floating.

Each is independently testable/inspectable. The old `ViewportView` is decomposed into `CaveBackdrop` + `ParticleOverlay` + `GrubLayer`; `PetInfoBar` (already unused) is deleted.

---

## 7. Risks & open items

| ID | Item | Default |
|---|---|---|
| ~~O-1~~ | **RESOLVED** (§2/§6): split into `drawStructure` + `drawAtmosphere`; home calls `drawAtmosphere` (particles + new tint rect) over the PNG. | — |
| O-2 | HUD panel opacities — must verify legibility on-device against the busiest cave region | Start ~50% stat panel / ~55% button panel; tune in playtest |
| ~~O-3~~ | **RESOLVED** (§2): the day/dusk/night tint is re-authored as a `TimePhase`-derived full-screen translucent rect in `drawAtmosphere`. Generate a 2nd night PNG only if the tint rect can't sell night convincingly (fallback, not default). | — |
| O-4 | Grub floor Y for BOTH branches (normal `0.45`, expedition `0.58`) re-derived against the cave PNG's floor band | Measure the PNG floor band, set one shared floor constant |
| O-5 | Safe-area handling — full-bleed scene must not put HUD under the notch/home indicator | Pin HUD inside safe area; scene ignores it |
| O-6 | Confirm exported `cave_home` PNG dimensions before authoring the imageset Contents.json | Verify actual px before plan |

**Reversibility:** the old band layout is one git revert away; no save-format change means rollback is clean.

---

## 8. What this deliberately does NOT change
Gameplay, stats, economy, overlays' internals, the Descent plan, the decoration system, audio, ads, save format. Purely how the home screen is composed.
