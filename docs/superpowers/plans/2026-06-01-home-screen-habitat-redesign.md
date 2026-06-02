# Home Screen Habitat Redesign — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 5-stacked-band home screen with a full-screen cave habitat (PixelLab "Cave 2" PNG) and a floating translucent HUD, with zero gameplay change.

**Architecture:** A `ZStack` composes four layers bottom-to-top: `CaveBackdrop` (static PNG, full-bleed) → atmosphere overlay (`drawAtmosphere`: particles + a new time-of-day tint rect) → `GrubLayer` (the existing `ViewportView` Canvas with its background call removed, so it's transparent and shows the cave through) → `HUDOverlay` (floating stats/nav/buttons/banners). All existing modal overlays, scanline, toast, and lifecycle handlers stay as ZStack siblings above the scene. The only logic change is splitting `SpriteRenderer.drawBackground` into `drawStructure` + `drawAtmosphere`.

**Tech Stack:** Swift 5 / SwiftUI, iOS 17, XcodeGen, XCTest. PNG asset from PixelLab (`/tmp/mincave_2.png`, 180×388). Sim: `id=B30DE184-06D2-4A74-8EC5-24DB2377A109` (iPhone 17 / iOS 26.2).

**Spec:** `docs/superpowers/specs/2026-06-01-home-screen-habitat-redesign.md`

**Branch:** `descent` (continue — this is the active working branch, currently at commit `58f2da3`).

---

## Verified facts (trust these — measured against the repo)

- Cave PNG source: `/tmp/mincave_2.png`, **180×388 px** (O-6 resolved).
- `SpriteRenderer.drawBackground(context:size:tick:)` = SpriteRenderer.swift **lines 118–333**. Internal sections:
  - **STRUCTURE** (baked time-of-day color): sky bands (135–143), stalactites (159–191), ground (192–236), mushrooms (237–256).
  - **ATMOSPHERE** (structure-independent): stars (144–158), spores (257–275), drips (276–299), mushroom-glow (300–311), ambient particles (312–324), vignette (325–332).
  - Note: stars sit at line 144 (between sky and stalactites) but are atmosphere — they move to `drawAtmosphere`.
- `ViewportView` = ContentView.swift **lines 181–467**. One `Canvas`:
  - Line **186**: `SpriteRenderer.drawBackground(...)` — the ONLY background call; removing it makes the Canvas transparent.
  - Lines **188–459**: `if game.isOnExpedition { …expedition branch (floor 0.58)… } else { …normal pet branch (floor 0.45)… }`.
  - Lines 461–465: `.frame(maxWidth:.infinity,maxHeight:.infinity).clipped().onTapGesture { game.tapGrub() }`.
- `ContentView.body` = lines **6–110**: outer `ZStack` → inner band `VStack` (11–32: TopBar/Viewport/banner-if/StatBars/ActionButtons) + 15 modal overlays (34–82) + expedition-find popup (85–91) + ScanlineOverlay (93–96) + ToastView (98–101) + `.onReceive` willResignActive (103) + didBecomeActive (106) + `.statusBarHidden()` (109).
- Banner views: `NapBannerView` (472), `DyingBannerView` (499), `ExpeditionBannerView` (526) — currently rendered as a band between viewport and stats (ContentView lines 18–24).
- `PetInfoBar` (558) — already unused (removed from layout in commit 9f4c66e); delete it.
- `TimePhase` enum (SpriteRenderer.swift 24–116): `.current` computed from clock; 4 cases (dawn/day/dusk/night), each exposing `skyColors`, `groundTop/Mid/Dark`, `sporeOpacity`, `starOpacity`, `mushGlowOpacity`. **No tint primitive exists** — the tint rect in Task 2 is new.

---

## File Structure

| File | Responsibility |
|---|---|
| `Assets.xcassets/cave_home.imageset` | NEW — the Cave 2 backdrop PNG + Contents.json |
| `SpriteRenderer.swift` | Split `drawBackground` → `drawStructure` + `drawAtmosphere` (+ new `TimePhase.tintColor`); keep `drawBackground` as a wrapper calling both (back-compat) |
| `ContentView.swift` | Rewrite `body` inner content as the 4-layer ZStack; convert `ViewportView`→`GrubLayer` (drop its bg call); restyle TopBar/StatBars/ActionButtons as floating overlays; banners→overlaid strip; delete `PetInfoBar` |
| `GrubIOSTests/GrubAssetTests.swift` | Add `test_cave_home_resolves` |
| `GrubIOSTests/AtmosphereSplitTests.swift` | NEW — assert `drawStructure`/`drawAtmosphere` exist and `drawBackground` still callable (compile-level smoke) |

---

## Chunk 1: Asset + drawBackground split (no visual change yet)

### Task 1: Add the cave_home backdrop asset

**Files:**
- Create: `GrubIOS/Assets.xcassets/cave_home.imageset/cave_home.png` + `Contents.json`
- Test: `GrubIOSTests/GrubAssetTests.swift`

- [ ] **Step 1: Write the failing test**

Add to `GrubAssetTests.swift` (alongside the existing icon tests):
```swift
func test_cave_home_resolves() {
    let appBundle = Bundle(identifier: "com.jessedev.GrubIOS") ?? Bundle(for: GrubAssetTests.self)
    let img = UIImage(named: "cave_home", in: appBundle, with: nil) ?? UIImage(named: "cave_home")
    XCTAssertNotNil(img, "cave_home backdrop not found in bundle")
}
```

- [ ] **Step 2: Run it — expect FAIL** (asset missing)

```bash
cd ~/Documents/Code/grub/GrubIOS
xcodegen generate
xcodebuild test -project GrubIOS.xcodeproj -scheme GrubIOS \
  -destination 'id=B30DE184-06D2-4A74-8EC5-24DB2377A109' \
  -only-testing:GrubIOSTests/GrubAssetTests/test_cave_home_resolves 2>&1 | tail -5
```
Expected: FAIL (`cave_home backdrop not found`).

- [ ] **Step 3: Create the imageset**

```bash
DST=GrubIOS/Assets.xcassets/cave_home.imageset
mkdir -p "$DST"
cp /tmp/mincave_2.png "$DST/cave_home.png"
cat > "$DST/Contents.json" <<'JSON'
{
  "images" : [
    { "filename" : "cave_home.png", "idiom" : "universal", "scale" : "1x" },
    { "idiom" : "universal", "scale" : "2x" },
    { "idiom" : "universal", "scale" : "3x" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON
```
> If `/tmp/mincave_2.png` is gone (temp cleared), regenerate via the PixelLab pixflux call in the spec's §2 (the minimal-cave prompt) or ask the user — do NOT substitute a different image.

- [ ] **Step 4: Run test — expect PASS**

```bash
xcodegen generate
xcodebuild test -project GrubIOS.xcodeproj -scheme GrubIOS \
  -destination 'id=B30DE184-06D2-4A74-8EC5-24DB2377A109' \
  -only-testing:GrubIOSTests/GrubAssetTests/test_cave_home_resolves 2>&1 | tail -5
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add GrubIOS/Assets.xcassets/cave_home.imageset GrubIOSTests/GrubAssetTests.swift project.yml
git commit -m "feat: add cave_home backdrop asset (PixelLab Cave 2, 180x388)"
```

### Task 2: Split drawBackground into structure + atmosphere

**Files:**
- Modify: `GrubIOS/SpriteRenderer.swift` (lines 118–333 + TimePhase enum)
- Test: `GrubIOSTests/AtmosphereSplitTests.swift`

The refactor is **mechanical**: move the structure sections into `drawStructure`, the atmosphere sections into `drawAtmosphere`, add a `TimePhase.tintColor`, and make `drawBackground` a wrapper that calls `drawStructure` then `drawAtmosphere` (so every existing caller — including the soon-to-be-removed ViewportView call and any others — keeps working unchanged).

- [ ] **Step 1: Add `tintColor` to TimePhase**

In `SpriteRenderer.swift`, inside the `TimePhase` enum (after `mushGlowOpacity`), add a full-screen overlay tint that recreates the day/dusk/night recoloring for use over a fixed-lighting PNG:
```swift
/// Full-screen translucent overlay tint, recreates time-of-day mood over a
/// static (fixed-lighting) background PNG. Day = clear; others tint + darken.
var tintColor: Color {
    switch self {
    case .day:   return Color.clear
    case .dawn:  return Color(red: 0.95, green: 0.55, blue: 0.35).opacity(0.10) // warm
    case .dusk:  return Color(red: 0.55, green: 0.30, blue: 0.55).opacity(0.16) // purple
    case .night: return Color(red: 0.04, green: 0.05, blue: 0.12).opacity(0.42) // deep blue, darken
    }
}
```
(Values are starting points — O-2/O-3 tuning happens in Task 5 playtest.)

- [ ] **Step 2: Extract `drawStructure`**

Create `static func drawStructure(context: inout GraphicsContext, size: CGSize, tick: Int)` containing the CURRENT body lines for: the `w/h/px/block` setup, `let phase = TimePhase.current`, sky bands, stalactites, ground, mushrooms. (Everything EXCEPT stars, spores, drips, mushroom-glow, ambient particles, vignette.)

- [ ] **Step 3: Extract `drawAtmosphere`**

Create `static func drawAtmosphere(context: inout GraphicsContext, size: CGSize, tick: Int)` containing: the `w/h/px/block` setup + `let phase = TimePhase.current`, then stars, spores, drips, mushroom-glow, ambient particles, vignette — AND append at the end:
```swift
// Time-of-day tint over the (static) backdrop
if phase.tintColor != .clear {
    context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(phase.tintColor))
}
```

- [ ] **Step 4: Make `drawBackground` a wrapper**

Replace the old `drawBackground` body with:
```swift
static func drawBackground(context: inout GraphicsContext, size: CGSize, tick: Int) {
    drawStructure(context: &context, size: size, tick: tick)
    drawAtmosphere(context: &context, size: size, tick: tick)
}
```
This preserves byte-for-byte behavior for any existing caller (the wrapper draws structure then atmosphere, same as before — except the new tint rect, which is `.clear` during `.day` and a subtle overlay otherwise; acceptable since the old code already recolored by phase).

- [ ] **Step 5: Write the smoke test**

```swift
// GrubIOSTests/AtmosphereSplitTests.swift
import XCTest
import SwiftUI
@testable import GrubIOS

@MainActor
final class AtmosphereSplitTests: XCTestCase {
    // Compile-level guarantee that the split functions exist with the right
    // signature and run without trapping on a real GraphicsContext.
    func test_atmosphere_and_structure_render_without_crash() {
        let size = CGSize(width: 180, height: 388)
        let renderer = ImageRenderer(content: Canvas { ctx, sz in
            SpriteRenderer.drawStructure(context: &ctx, size: sz, tick: 0)
            SpriteRenderer.drawAtmosphere(context: &ctx, size: sz, tick: 0)
            SpriteRenderer.drawBackground(context: &ctx, size: sz, tick: 0)
        }.frame(width: size.width, height: size.height))
        XCTAssertNotNil(renderer.uiImage, "split renderers should produce an image")
    }
}
```

- [ ] **Step 6: Run tests — expect PASS**

```bash
xcodegen generate
xcodebuild test -project GrubIOS.xcodeproj -scheme GrubIOS \
  -destination 'id=B30DE184-06D2-4A74-8EC5-24DB2377A109' 2>&1 \
  | grep -aE "Executed [0-9]+ tests|TEST SUCCEEDED|TEST FAILED" | tail -2
```
Expected: TEST SUCCEEDED (all prior tests + the new smoke test).

- [ ] **Step 7: Commit**

```bash
git add GrubIOS/SpriteRenderer.swift GrubIOSTests/AtmosphereSplitTests.swift project.yml
git commit -m "refactor: split drawBackground into drawStructure + drawAtmosphere + TimePhase.tintColor"
```

---

## Chunk 2: Full-screen layout

### Task 3: Convert ViewportView → transparent GrubLayer

**Files:**
- Modify: `GrubIOS/ContentView.swift` (ViewportView, line 186)

The lowest-risk move: `GrubLayer` IS `ViewportView` with the background call deleted. The 180-line expedition branch and the normal pet branch are untouched.

- [ ] **Step 1: Rename + strip the background call**

In `ContentView.swift`:
- Rename `struct ViewportView` → `struct GrubLayer`.
- Delete line 186 (`SpriteRenderer.drawBackground(context: &context, size: size, tick: game.animTick)`). The Canvas now starts directly with `if game.isOnExpedition {`.
- Leave `.frame(maxWidth:.infinity,maxHeight:.infinity).clipped().onTapGesture { game.tapGrub() }` intact.

> Do NOT touch the expedition branch or the normal pet branch — only the one background line is removed. The Canvas is now transparent where it doesn't draw the pet.

- [ ] **Step 2: Build — expect a reference error**

```bash
xcodebuild build -project GrubIOS.xcodeproj -scheme GrubIOS \
  -destination 'id=B30DE184-06D2-4A74-8EC5-24DB2377A109' 2>&1 | grep -aE 'error:|BUILD' | tail -5
```
Expected: BUILD FAILED — `ViewportView` referenced in ContentView body (line 17) no longer exists. (This is expected; fixed in Task 4.)

- [ ] **Step 3: Commit (WIP — compiles after Task 4)**

Defer commit to Task 4 (this task alone leaves the build red). Proceed directly to Task 4.

### Task 4: Rewrite ContentView.body as the 4-layer ZStack

**Files:**
- Modify: `GrubIOS/ContentView.swift` (body lines 6–110; banner restyle; delete PetInfoBar)

- [ ] **Step 1: Replace the inner band VStack with the layered scene**

Replace the inner `VStack(spacing: 0) { …TopBar/Viewport/banner/StatBars/ActionButtons… }` (lines 11–32) with a full-bleed scene + floating HUD. Keep everything else in the ZStack (overlays, scanline, toast, handlers). New inner content:

```swift
// ---- Full-screen cave scene ----
// 1. Static backdrop
Image("cave_home")
    .interpolation(.none)
    .resizable()
    .aspectRatio(contentMode: .fill)
    .ignoresSafeArea()

// 2. Atmosphere (particles + time-of-day tint) over the PNG
Canvas { ctx, size in
    SpriteRenderer.drawAtmosphere(context: &ctx, size: size, tick: game.animTick)
}
.ignoresSafeArea()
.allowsHitTesting(false)

// 3. Grub (transparent layer; tap to interact)
GrubLayer(game: game)

// 4. Floating HUD
VStack {
    HStack(alignment: .top) {
        IdentityCluster(game: game)
        Spacer()
        MetaNavCluster(game: game)
    }
    // banners appear just under identity when active
    if game.isDying {
        DyingBannerView(game: game)
    } else if game.isNight {
        NapBannerView(game: game)
    } else if game.isOnExpedition {
        ExpeditionBannerView(game: game)
    }
    Spacer()
    StatBarsView(game: game)          // restyled translucent (Task 4 Step 3)
    ActionButtonsView(game: game)     // restyled translucent (Task 4 Step 3)
}
.padding(.horizontal, 12)
```

- [ ] **Step 2: Add IdentityCluster + MetaNavCluster (lift from old TopBarView)**

The old `TopBarView` (still present) splits into two floating clusters. Add:
```swift
struct IdentityCluster: View {
    @ObservedObject var game: GameState
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(game.name.isEmpty ? "GRUB" : game.name)
                .font(GrubFont.size(12)).foregroundColor(GrubPalette.green)
                .shadow(color: .black.opacity(0.8), radius: 0, x: 1, y: 1)
            Text("AGE \(game.ageDays)D")
                .font(GrubFont.size(8)).foregroundColor(GrubPalette.pale.opacity(0.6))
                .shadow(color: .black.opacity(0.8), radius: 0, x: 1, y: 1)
        }
    }
}

struct MetaNavCluster: View {
    @ObservedObject var game: GameState
    var body: some View {
        HStack(spacing: 6) {
            Text("LV\(game.ownerLevel)")
                .font(GrubFont.size(10)).foregroundColor(GrubPalette.yellow)
                .shadow(color: .black.opacity(0.8), radius: 0, x: 1, y: 1)
            Button {
                game.audio.play(.tap); game.journalInitialTab = 0; game.showJournalOverlay = true
            } label: {
                Text("LOG").font(GrubFont.size(10)).foregroundColor(GrubPalette.pale.opacity(0.7))
                    .frame(minWidth: 36, minHeight: 44).contentShape(Rectangle())
            }
            Button {
                game.audio.play(.tap); game.showSettingsMenu = true
            } label: {
                PixelIcon.gear(size: 18).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
            }
        }
    }
}
```
Delete the old `TopBarView` struct (its job is now covered). Delete the unused `PetInfoBar` struct.

- [ ] **Step 3: Restyle StatBarsView + ActionButtonsView backgrounds to translucent**

In `StatBarsView`: change `.background(GrubPalette.void_color)` → `.background(GrubPalette.void_color.opacity(0.5))` and wrap in `.padding(.bottom, 4)`. Keep the border overlays.
In `ActionButtonsView`: change `.background(GrubPalette.moss.ignoresSafeArea(edges: .bottom))` → `.background(GrubPalette.moss.opacity(0.55))`. Keep category-colored buttons + border.

- [ ] **Step 4: Build — expect SUCCEEDED**

```bash
xcodebuild build -project GrubIOS.xcodeproj -scheme GrubIOS \
  -destination 'id=B30DE184-06D2-4A74-8EC5-24DB2377A109' 2>&1 | grep -aE 'error:|BUILD' | tail -5
```
Expected: BUILD SUCCEEDED. If errors reference a removed struct, fix the reference (don't re-add the struct).

- [ ] **Step 5: Run full test suite — expect PASS**

```bash
xcodebuild test -project GrubIOS.xcodeproj -scheme GrubIOS \
  -destination 'id=B30DE184-06D2-4A74-8EC5-24DB2377A109' 2>&1 \
  | grep -aE "Executed [0-9]+ tests|TEST SUCCEEDED|TEST FAILED" | tail -2
```
Expected: TEST SUCCEEDED.

- [ ] **Step 6: Commit**

```bash
git add GrubIOS/ContentView.swift project.yml
git commit -m "feat: full-screen cave habitat layout with floating HUD

ViewportView -> GrubLayer (transparent, bg call removed). ContentView.body
inner content is now ZStack: cave_home PNG -> drawAtmosphere -> GrubLayer ->
floating HUD (IdentityCluster/MetaNavCluster/StatBars/ActionButtons + banners).
All 15 modal overlays, scanline, toast, lifecycle handlers preserved.
TopBarView + PetInfoBar deleted."
```

---

## Chunk 3: On-device tuning + regression

### Task 5: Visual verification + floor/opacity/safe-area tuning (O-2, O-4, O-5)

**Files:**
- Modify: `GrubIOS/ContentView.swift` (GrubLayer floor constants; HUD opacities/padding as needed)

- [ ] **Step 1: Deploy to sim**

```bash
SIM=B30DE184-06D2-4A74-8EC5-24DB2377A109; BID=com.jessedev.GrubIOS
xcodebuild build -project GrubIOS.xcodeproj -scheme GrubIOS -destination "id=$SIM" -derivedDataPath /tmp/grub_dd >/dev/null 2>&1
APP=/tmp/grub_dd/Build/Products/Debug-iphonesimulator/GrubIOS.app
xcrun simctl terminate $SIM $BID 2>/dev/null; xcrun simctl install $SIM "$APP"; xcrun simctl launch $SIM $BID
sleep 6; xcrun simctl io $SIM screenshot /tmp/home_v2.png
```
Then view `/tmp/home_v2.png`.

- [ ] **Step 2: O-4 — fix Grub's floor Y to land on the PNG floor band**

The cave PNG's floor band is its lower section. In `GrubLayer`, the normal pet branch uses `petY = size.height * 0.45` and the expedition branch `baseY = size.height * 0.58`. These were tuned for the OLD procedural floor. Adjust both so Grub's feet sit on the `cave_home` floor (measure from the screenshot; the Cave 2 floor pool is ~78–82% down). Likely `~0.72` normal / `~0.74` expedition — but set by eye against the screenshot, re-deploy, confirm feet touch the floor.

- [ ] **Step 3: O-2 — tune HUD opacities for legibility**

Against the screenshot, confirm stat bars + button labels read over the cave. If washed out, raise panel opacities (stat `0.5→0.6`, button `0.55→0.65`). Re-deploy, confirm.

- [ ] **Step 4: O-5 — safe area check**

Confirm the HUD top cluster isn't under the notch and the button row isn't under the home indicator. The scene `.ignoresSafeArea()`; the HUD `VStack` must respect it (it does by default since it's not given `.ignoresSafeArea`). Verify on the screenshot; add `.padding(.top, …)` only if needed.

- [ ] **Step 5: Regression pass (SC2) — manual, document results**

Drive the sim and confirm each reachable:
- FEED → feed overlay; PLAY → minigame/selector; DIG → forage overlay; PACK → inventory; LOG → journal; ⚙ → settings.
- Trigger an event (or wait) → event overlay renders over the scene.
- Background/foreground the app (Cmd+Shift+H, reopen) → `onBackground`/`onForeground` fire (stats decay applied), notifications reschedule.
- Confirm ScanlineOverlay still tints; ToastView still appears on actions.
- Inject low stats (plist edit) → dying banner appears as overlaid strip; pet shows dying PNG.
Document pass/fail for each in the commit message.

- [ ] **Step 6: Commit tuning**

```bash
git add GrubIOS/ContentView.swift
git commit -m "polish: tune Grub floor-Y, HUD opacity, safe-area for cave habitat (O-2/O-4/O-5)

Regression pass: <paste FEED/PLAY/DIG/PACK/LOG/settings/event/lifecycle/
scanline/toast/banner results here>"
```

### Task 6: Night-mode check (O-3) — tint rect vs second PNG

**Files:** possibly `GrubIOS/SpriteRenderer.swift` (`TimePhase.tintColor` night value)

- [ ] **Step 1: Force night + screenshot**

Temporarily hard-code `TimePhase.current` to `.night` (or set device clock), deploy, screenshot. View it.

- [ ] **Step 2: Judge**

If the night tint rect convincingly reads as night over the cave PNG → tune the night `tintColor` opacity and done. If it looks muddy/flat → fall back: generate a darker night `cave_home_night` PNG (PixelLab, same prompt + "dark night lighting") and swap the backdrop `Image` by `TimePhase.current`. **Surface this decision to the user with both screenshots before generating the night PNG.**

- [ ] **Step 3: Revert the hard-coded phase; commit whatever tuning landed**

```bash
git add GrubIOS/SpriteRenderer.swift
git commit -m "polish: tune night-mode tint over cave habitat (O-3)"
```

---

## Definition of done

- [ ] `cave_home` asset ships; `test_cave_home_resolves` passes.
- [ ] `drawBackground` split into `drawStructure` + `drawAtmosphere`; smoke test passes; old callers unaffected.
- [ ] Home screen is the full-screen cave with floating HUD; no stacked bands.
- [ ] Grub stands on the cave floor (both normal + expedition branches); all V3 states render over the scene.
- [ ] Atmosphere particles + time-of-day tint animate over the PNG.
- [ ] All 15 overlays + scanline + toast + banners + lifecycle handlers work (SC2 checklist documented).
- [ ] HUD legible + tappable; safe areas respected.
- [ ] Night mode resolved (tint rect, or 2nd PNG with user sign-off).
- [ ] Full test suite green; no save migration needed.
- [ ] `TopBarView` + `PetInfoBar` deleted.

## Out of scope (do NOT do here)
- The Descent / DESCEND button (Phase 2). DIG stays.
- Decoration-on-scene placement.
- Any gameplay/economy/save change.
