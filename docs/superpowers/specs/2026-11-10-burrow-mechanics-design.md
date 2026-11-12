# Burrow Mechanics — Design

Date: 2026-11-10 · Branch: `the-deep` · Status: approved by Jesse in chat (pacing B, molt C, neglect A, inheritance C)

## Goal

Turn the pixel-burrow home screen (`GrubIOS/Burrow/`) into the real game loop from the
gameplay-flow board (`docs/burrow/gameplay-flow.html`):

**HATCH → RETURN → DIG → FEED + FURNISH → MOLT → COLLECT** (then a new egg).

The home screen, the Rust Clay palette and the round contact-sheet grub already exist; today
all state is hard-coded and in memory. This spec covers rules, save data, and the screens the
loop needs.

**Pacing target:** players come back a few times a day. A player visiting 2–4 times a day
takes one grub from hatch to molt in about **2.3–2.5 days**; the belly cap, not visit count,
is the limit there, so moderate players are not left behind. A once-a-day player takes about
4.5 days — slower, never punished. (Figures from a minute-step simulation of these exact
rules, 30 seeds per profile; see "Stat roles".)

## Decisions (from Jesse)

| Question | Choice |
|---|---|
| Return pacing | **B** — a dig regrows every 3 h (max 3); one grub ≈ 2–3 days |
| How the adult is chosen | **C** — weighted chance; food and decor shift odds, rolled at molt |
| Neglect | **A** — sulk only; nothing is ever lost |
| Inheritance | **C** — colour tint *and* a small odds head start |

## Stat roles

Each bar has one job, one logical cause, and a payoff the player can see. They chain:
**finds → food → BELLY → MOLT**, and **petting + varied meals + decor → JOY → more finds**.

| Stat | What it means | Goes up | Goes down | Why the player cares |
|---|---|---|---|---|
| **BELLY** | fuel | a meal: +3 | −1 every 2 h | Meals are the only way to grow (each meal is +1 MOLT). The cap (TOO FULL at 10) spaces meals out, so it is the pacing gate. At 0 the grub **sulks**: Joy drains hourly. |
| **JOY** | mood | pet: +1 (once per 15 min); a meal **different from the last one**: +1 | −1 every 4 h, **+1 h per placed decor** (up to 8 h); every 1 h while sulking | At 7+ the grub is **HAPPY**: every dig has a 35 % chance to turn up a **bonus find**. The JOY bar shows a HAPPY tag so the payoff is visible. _(Superseded by the dig spec, 2026-11-10: the hidden bonus-find roll is gone; a happy grub gets +2 strikes in the dig mini-game instead. See `2026-11-10-dig-minigame-design.md`.)_ |
| **MOLT** | growth | +1 per meal | never | At 10 the grub is ready to molt. What it ate and the decor shape *which* adult (odds); MOLT only says *when*. |

Why this shape:

- **Belly** is the clock. It caps useful meals at about 4 a day, so growth takes the same
  ~2.3–2.5 days whether you visit 2 or 4 times. Neglect slows things (sulking), nothing is lost.
- **Joy** rewards care with *stuff*, not speed. More finds means more food in stock, more
  decor, and more control over the molt odds. It works for twice-a-day players too: with
  these rules they get ~7.6 finds a day instead of 6.
- **Varied meals** add a real choice: steering toward one species means eating its food, but
  eating the same thing twice in a row earns no Joy.
- **Decor** has two jobs: it shifts the molt odds and makes the home cosy (slower Joy drain).
- **Molt** is progress only, and every meal moves it. Earlier drafts also had a "happy bonus"
  that gave extra MOLT while Joy was high. It is **removed**: it made Joy a speed stat that
  only frequent players could keep up.

Simulated with `docs/burrow/stat-sim.py` (minute steps, 30 seeds; each visit digs
everything, places decor, feeds while Belly ≤ 7, pets once):

| Player | Days to molt | Finds/day | Meals/day | Time sulking | Time HAPPY |
|---|---|---|---|---|---|
| 4 visits/day | 2.3 | 9.5 | 4.1 | 0 % | 97 % |
| 2 visits/day | 2.4 | 7.6 | 4.0 | 1 % | 87 % |
| 1 visit/day | 4.5 | 3.0 | 2.2 | 44 % | 0 % |

## Reference art

- Species contact sheet: `docs/burrow/species-contact-sheet.html` (6 inline SVGs, 24×24
  viewBox; copied from the "Grub Hero Art" Design canvas,
  https://claude.ai/artifact/HYqg6Qvqs8cSKLLrBruyYi, artboard `Hero-variations.dc.html`).
- Gameplay flow: `docs/burrow/gameplay-flow.html`.

| Species | Colour | Blurb |
|---|---|---|
| GRUB | `#4ecca3` | THE ORIGINAL |
| HORN | `#8f6fe0` | STUBBORN DIGGER |
| FUZZ | `#f5a623` | SOFT, SHEDS TUFTS |
| SHELL | `#6f8fb0` | ROLLS UP TIGHT |
| CLAWS | `#c97b3a` | BORN TO DIG |
| STALK | `#ed93b1` | SEES ROUND CORNERS |

## Architecture

Three units, one direction of dependency: **view → model → rules → save**.

1. **`BurrowSave`** (`Burrow/BurrowSave.swift`) — a `Codable` value type holding *all* game state
   plus `version`. No logic beyond `static func fresh(now:) -> BurrowSave`.
   **`BurrowStore`** (same file) persists it as JSON: `init(directory: URL)` (default:
   Application Support; tests inject a temp dir), `load() -> BurrowSave`, `save(_:) throws`.
   A missing file yields `fresh`. An unreadable or newer-version file is renamed
   `burrow.corrupt.json` and yields `fresh`, so nothing is silently destroyed.
   `FindKind` and `Species` are `String` enums conforming to `CodingKeyRepresentable` so
   dictionaries encode as readable JSON objects.
2. **`BurrowRules`** (`Burrow/BurrowRules.swift`) — pure static functions, no UIKit, no timers,
   no singletons. Every mutating rule has the shape
   `static func x(_ s: BurrowSave, …, now: Date) -> BurrowResult` where
   `struct BurrowResult { var save: BurrowSave; var events: [BurrowEvent] }`.
   Rules that need randomness take `rng: inout some RandomNumberGenerator`.
3. **`BurrowHomeModel`** (existing file, slimmed) — the `@MainActor` view model. Owns the
   current `BurrowSave` and a `BurrowStore`; calls rules on taps, on scene-activate and on a
   60 s tick; maps `BurrowEvent`s to the existing FX (dirt, reveal, text, hearts, haptics,
   toasts); writes the save after every rule call that changed it and on
   `scenePhase == .background`.

The old `GameState` is not touched. `RootView` already shows `BurrowHomeView`. The existing
`BuriedFind` (UUID + `CellAnchor`) is **replaced** by the spot-index version below; the view's
`marker`/`dig` code moves to spot indices, resolving positions through a `BurrowSpots` table
of 8 `CellAnchor`s.

### Rules API

```swift
enum BurrowRules {
  static let moltGoal = 10
  static let happyJoy = 7, bonusFindChance = 0.35   // bonusFindChance removed by the dig spec
  static func advance(_ s: BurrowSave, to now: Date, rng: inout some RandomNumberGenerator) -> BurrowResult
  static func dig(_ s: BurrowSave, spot: Int, now: Date, rng: inout some RandomNumberGenerator) -> BurrowResult
  static func feed(_ s: BurrowSave, kind: FindKind?, now: Date) -> BurrowResult   // nil = first food in bag order
  static func pet(_ s: BurrowSave, now: Date) -> BurrowResult
  static func place(_ s: BurrowSave, kind: FindKind, slot: Int, now: Date) -> BurrowResult
  static func remove(_ s: BurrowSave, slot: Int, now: Date) -> BurrowResult
  static func odds(_ s: BurrowSave) -> [Species: Double]
  static func startMolt(_ s: BurrowSave, now: Date, rng: inout some RandomNumberGenerator) -> BurrowResult
  static func pin(_ s: BurrowSave, now: Date) -> BurrowResult
  static func name(_ s: BurrowSave, _ name: String, now: Date) -> BurrowResult
  static func crackEgg(_ s: BurrowSave, now: Date) -> BurrowResult
}

enum BurrowEvent: Equatable {
  case buried(spot: Int, kind: FindKind)
  case dugUp(spot: Int, kind: FindKind), bonusFind(spot: Int, kind: FindKind)
  case ate(FindKind, joyGained: Bool), petted(joyGained: Bool)
  case placed(slot: Int, kind: FindKind), removed(slot: Int, kind: FindKind)
  case moltReady                       // emitted by any rule whose call moves molt from < goal to ≥ goal
  case molted(Species), pinned(Specimen), named(String), eggCracked(stage: Int), hatched
  case refused(Refusal)
}
enum Refusal: Equatable { case noDigs, nothingBuriedThere, noFood, notFood, tooFull, slotTaken,
  notDecor, notInBag, emptySlot, notMoltReady, wrongStage, badName }
```

A refused rule returns the save unchanged plus `.refused(reason)`; the model turns each
reason into a toast. No rule ever crashes on bad input. `.moltReady` needs no stored flag: it
is emitted only on the crossing, and the "ready" glow is derived (`molt >= moltGoal`).

### Save contents (`BurrowSave`, version 1)

- `stage`: `.egg | .larva | .adult` (adult = rolled and revealed, waiting to be pinned)
- `name: String` (empty until named), `eggCracks: Int` (0…3)
- `belly, joy: Int` (0…10), `molt: Int` (0…`moltGoal`)
- `digs: Int` (0…3)
- `buried: [BuriedFind]` — `{ spot: Int, kind: FindKind }`, at most 4, one per spot
- `holes: [Int]` — spots dug and not yet reburied (drawn as dug pockets)
- `bag: [FindKind: Int]`
- `placed: [Int: FindKind]` — decor slot index (0…3) → item
- `eaten: [FindKind: Int]` — this grub's diet, for the odds; `lastMeal: FindKind?` — for the
  variety Joy rule
- `lineage: Species?` (parent species, head start), `tint: Species?` (parent colour)
- `adult: Species?` — set by `startMolt`
- `specimens: [Specimen]` — `{ name, species, pinnedAt }`
- `lastTick: Date`, timer accumulators in seconds: `digTimer, buryTimer, bellyTimer,
  joyTimer`
- `lastPetAt: Date`

**`fresh(now:)`:** stage `.egg`, belly 6, joy 6, molt 0, digs 3, bag `[berry: 1]`, 3 finds
buried (berry, root, crystal at spots 0, 1, 2), no holes, no decor, no lineage/tint, all
timers 0, `lastTick = now`, `lastPetAt = now − 1 day` (so the first pet counts).

## Rules

### 1. Time — `advance`

Called on launch, on scene-activate, and every 60 s while open.
`elapsed = now − lastTick`. If negative (clock moved back): set `lastTick = now`, no other
change. Otherwise clamp to **72 h** (beyond that every value is at its floor or cap) and
**simulate in 1-minute steps** (≤ 4,320 steps). Each step adds 60 s to the active timers and
pays out whole periods, re-checking conditions every step, so linked timers (belly hitting 0
mid-gap switches joy to the hourly drain) are exact.

| Timer | Period | Effect | Active when |
|---|---|---|---|
| dig | 3 h | `digs += 1` | `digs < 3`; **reset to 0 while at the cap** (no banking) |
| bury | 2 h | bury one weighted-random find in a random free spot (not in `buried`); removes that spot from `holes`. _(Superseded by the dig spec, 2026-11-10: the kind is rolled from the spot's soil layer, not one global table. See `2026-11-10-dig-minigame-design.md`.)_ | `buried.count < 4`; reset to 0 while at the cap |
| belly | 2 h | `belly −= 1` | stage `.larva` and `belly > 0` |
| joy | `4 h + 1 h × placed decor` (max 8 h); **1 h while belly = 0** | `joy −= 1` | stage `.larva` and `joy > 0` |

When the joy period changes (decor placed/removed, belly hits or leaves 0), the accumulator
carries over; the next payout comes when it reaches the new period.

**Sulking** is derived, not stored: `stage == .larva && belly == 0`. Its only effect is the
hourly Joy drain (and the droopy pose); feeding works normally and ends it at once.
**Happy** is derived too: `joy ≥ happyJoy` (7) — the JOY bar shows a HAPPY tag.

**Pacing:** see "Stat roles" for the reasoning and the simulation table. In short, belly loses
12/day and a meal restores 3, so about 4 meals/day are useful → `moltGoal` 10 in ≈ 2.3–2.5 days.

### 2. Finds and digging

`FindKind` grows from 4 to 8. Burial picks a kind by weight:

| Kind | Type | Leans to | Bury weight |
|---|---|---|---|
| berry | food | GRUB | 30 |
| root | food | CLAWS | 15 |
| mushroom | food | STALK | 15 |
| honeydew | food | FUZZ | 10 |
| crystal | decor | HORN | 8 |
| shell | decor | SHELL | 8 |
| amber | decor | FUZZ | 7 |
| bone | decor | CLAWS | 7 |

**Spots:** `BurrowSpots` = 8 fixed `CellAnchor`s in open soil (the current 4 plus 4 more),
none inside a chamber, tunnel, title or HUD area. `dig(spot)` requires a find buried there
(`.nothingBuriedThere`) and `digs > 0` (`.noDigs` → toast "NO DIGS LEFT / BACK SOON").
It removes the find, adds the spot to `holes`, `digs −= 1`, `bag[kind] += 1`. If the grub is
**happy** (`.larva` and `joy ≥ 7`), roll `bonusFindChance` (35 %): on success add one more
weighted-random find to the bag and emit `.bonusFind` (the view pops a second item with
"BONUS!"). A hole stays drawn until the bury timer reuses that spot.

### 3. Feeding, petting, furnishing

All three require stage `.larva` (`.wrongStage` otherwise).

- **Feed:** `kind == nil` eats the first food in bag order berry → root → mushroom →
  honeydew; the Finds panel can feed a specific food (EAT). Auto with no food in the bag →
  `.noFood`; a specific kind that is decor → `.notFood`, or not in the bag → `.notInBag`; belly
  already 10 → `.tooFull` (nothing used). Otherwise `belly += 3` (cap 10), `molt += 1`
  (cap `moltGoal`; counts even while sulking), `eaten[kind] += 1`, and `joy += 1` (cap 10)
  **only if `kind != lastMeal`**; then `lastMeal = kind`. Auto-feed prefers a food different
  from `lastMeal` (bag order), falling back to a repeat.
- **Pet** (tap the grub when not molt-ready): hearts always (`.petted`); `joy += 1` only if
  `now − lastPetAt ≥ 15 min`, then `lastPetAt = now`.
- **Furnish:** 4 decor slots — 0 left side-room, 1 right side-room, 2 main-chamber left
  corner, 3 main-chamber right corner. In the Finds panel a decor item has PLACE → the free
  slots glow on the burrow → tap one. `place` errors: `.notDecor`, `.notInBag`, `.slotTaken`.
  Tapping a placed item → REMOVE (back to bag; `.emptySlot` if none). The baked-in amber
  pedestal and mushroom lamp leave the backdrop; empty slots render as small pedestals.

### 4. Molt (weighted chance)

```
weight[s] = 1                              (GRUB starts at 2)
          + Σ eaten foods leaning to s     × 1
          + Σ placed decor leaning to s    × 2   (counted while placed)
          + (lineage == s ? 2 : 0)
odds[s]   = weight[s] / Σ weight
```

- Tapping the MOLT stat bar opens the **molt panel**: six labelled bars with live odds and
  the progress `molt / moltGoal`. The MOLT stat bar's 10 segments map 1:1 to `molt`.
- When `molt ≥ moltGoal` the grub glows and **a tap on the grub starts the molt instead of
  petting**. `startMolt` (requires `.larva` and molt-ready, else `.notMoltReady`) rolls
  `adult` from `odds` **immediately** and sets `stage = .adult`; the save never holds a
  half-finished molt. The cocoon (~3 s wobble) and the reveal (sprite, name, blurb) are
  view-only animations played on the `.molted` event. If the app is killed mid-animation,
  the next launch simply shows the revealed adult waiting to be pinned.

### 5. Collect and hatch

- **Pin it** (button under the revealed adult; `pin` requires `.adult`): appends
  `Specimen(name, adult, now)`, then starts a new egg: `stage = .egg`, `lineage = adult`,
  `tint = adult`, belly 6, joy 6, molt 0, `eaten = [:]`, `lastMeal = nil`, `name = ""`,
  `eggCracks = 0`, `adult = nil`, belly/joy timers 0. Bag, placed decor, buried finds, holes and digs
  carry over (the burrow is the player's).
- **Specimen box:** a full-screen panel opened from a small box button at the top-left of
  the home screen and automatically after pinning. A grid of pinned adults (sprite, name,
  species, date); empty cells are dark. Scrolls when it outgrows the screen.
- **Hatch:** stage `.egg` shows an egg in the main chamber; FEED is disabled (see HUD by stage).
  First tap opens a name prompt (Press Start 2P text field, A–Z and space, 1–10 characters,
  prefilled with a random name from a list of ~20; `name` rejects anything else with
  `.badName`). After naming, each tap is `crackEgg` (wobble/crack frame per crack); the third
  crack sets `stage = .larva` and emits `.hatched`. Digging still works during `.egg`.
- **Tint:** larva body colour = `lerp(teal, tint.color, 0.25)` per channel; side shade =
  body × 0.82. Not cumulative across generations (always mixed from teal). Tint applies to
  the larva only; adults (reveal and specimen box) always use their plain species colours.
- **HUD by stage:** `.larva` — everything active. `.egg` — stat bars hidden, FEED disabled,
  DIG active, FINDS opens read-only (no EAT/PLACE/REMOVE — those need `.larva`).
  `.adult` — stat bars hidden, FEED disabled, DIG and FINDS (read-only) active, and a
  PIN IT button sits under the revealed adult.
- **First launch** starts at `.egg` (see `fresh`), so a new player names and hatches first.

## Art needed

In the existing ASCII-sprite / rect style in `BurrowArt.swift`, on the 64-column grid:

- Finds: root, mushroom, honeydew, shell (berry, amber, bone, crystal exist).
- Decor-slot pedestal (empty) and placed versions of crystal, shell, amber, bone.
- Larva: droopy (sulk) pose; glow overlay (molt-ready).
- Egg: idle + 3 crack frames. Cocoon: idle + wobble.
- Six adults, redrawn from the contact sheet at 1.5× like the larva.
- Icons: specimen box button, pin.

## Error handling

- Save write failure: keep running from memory, retry on the next write, log once.
- Corrupt or future-version save: rename aside, start fresh (see Architecture).
- Clock: backward jumps reset `lastTick` only; forward jumps are capped at 72 h.
- Every rule precondition failure is a `.refused` event → toast. No crashes.

## Testing

`GrubIOSTests/BurrowRulesTests.swift` and `BurrowStoreTests.swift` (follow
`SaveVersionTests.swift`), fixed clock and seeded RNG:

- dig regrowth: 3 h period, cap 3, timer resets at cap, partial time carries below cap
- burying: 2 h, cap 4, never two finds in one spot, clears the hole, weights within tolerance
  over 10k draws
- belly/joy decay; joy switches to hourly at belly 0 *mid-gap* (the 1-minute simulation);
  each placed decor lengthens the joy period by 1 h (max 8 h); feeding raises molt while sulking
- bonus find: only when happy, rate ≈ 35 % over many seeded digs, never while joy < 7 _(Superseded by the dig spec, 2026-11-10: the hidden bonus-find roll is gone; a happy grub gets +2 strikes in the dig mini-game instead. See `2026-11-10-dig-minigame-design.md`.)_
- 72 h clamp; backward clock only resets `lastTick`
- feed: auto order prefers variety, specific kind, TOO FULL, NO FOOD, NOT FOOD; +joy only for
  a different food than `lastMeal`; pet cooldown 15 min
- pacing regression: a test port of the simulation (4/2/1 visits a day) asserts days-to-molt
  stays within ±0.5 day of the "Stat roles" table
- place/remove errors and bag bookkeeping
- odds formula (base, diet, placed decor ×2 only while placed, lineage +2); roll distribution
  matches odds over many seeded rolls; `.moltReady` emitted exactly on the crossing
- startMolt sets `adult` and `.adult` atomically; pin carries lineage/tint, resets per-grub
  fields, keeps bag/decor/burrow; name validation; three cracks hatch
- store: JSON round-trip, missing file → fresh, corrupt and future-version files renamed

Each phase is also checked by hand in the iPhone 13 simulator using DEBUG launch args: the
existing `-burrowDemo` script (extended per phase) and a new `-burrowSkipHours N` that
advances the clock before the first frame.

## Build order

One implementation plan per phase; each phase ships playable.

1. **Save + time** — `BurrowSave`/`BurrowStore`, `advance`, `dig`, `BurrowSpots`, model
   rewiring, current FEED/pet moved onto rules, `-burrowSkipHours`. (Starts at `.larva` with
   a placeholder name until phase 4 adds the egg.)
2. **Feed + furnish** — 4 new finds, Finds panel EAT/PLACE/REMOVE, decor slots and art.
3. **Molt** — odds panel, glow, tap-to-molt, cocoon/reveal animations, six adult sprites.
4. **Collect + hatch** — pin, specimen box, egg, naming, cracks, tint, lineage, `fresh` starts
   at `.egg`.

## Home-screen legibility (2026-11-12)

Jesse, on the shipped build: "the dig sites aren't defined well, and the holes to place
trinkets don't read coherent or confuse the user — they seem like a waste of the Home
Screen." Measured against the running app, all three complaints were one failure: nothing on
the screen was **anchored**, so everything read as scatter.

- **Dig sites are mounds, not icons.** A spot was a 3×3 sprite floating six rows above
  undisturbed soil — and the food one wore `teal`, the grub's own colour, so it read as
  flora. It is now a raised mound of turned earth (`MarkerArt.mound`) whose bottom row is the
  shadow it casts on the soil. The cast shadow is the whole difference between a glint and a
  place. One vocabulary: a mound always means "dig here".
  - Three states, all from data that already existed: untouched (`buried`, not `visited`),
    opened (`moundOpen`, once the player has broken a tile themselves), and spent — already
    drawn, as the pocket `backdrop` carves for every spot in `save.holes`.
  - The food/decor tell survives, because with three digs a day choosing what to go after is
    most of the daily decision. It is demoted to a small mark sitting *on* the crown: a
    `sprig`-green plant for food, an amber glint for decor. Never the grub's teal.
  - `BurrowSpots.markerCentre` clamps the mound to the design grid: spots 5 and 6 sit within
    half a mound of the bezel, and a sliced mound stops reading as a mound. Art only — the
    spot itself never moves, so the save and the dig rules are untouched.

- **The soil layers are visible.** The four bands were `4a2618 / 3e2014 / 331a10 / 28140c` —
  74 → 62 → 51 → 40 on red, one hue — so the loose/clay/deep model the whole dig difficulty
  rests on was invisible. They now darken **and cool** with depth, warm rust topsoil to a
  blue-violet bedrock that meets the sky's family, and each band's flecks are a lighter
  version of itself with a second pass of grit in the lower two.

- **Decor moved into the chamber; the side rooms hold the collection.** A slot was a 6×2 bar
  on the floor of an unlit cavity. All four are now in the chamber — 0 and 1 standing on the
  floor either side of the grub, 2 and 3 on the walls above — each in a recess with a back
  wall, so an empty slot reads as somewhere to put something rather than as a gap in the art.
  `placed[i]` is unchanged, so this is layout only and no save migrates.
  - The side rooms hold the **specimen shelf**: the newest pinned adults on a ledge, newest
    first, tap for the full `SpecimenBoxView`. A lit shelf is still a shelf — the rooms needed
    a reason to be looked at, and the collection is the one thing that grows forever. It was
    behind a modal behind a 20px button in the sky; now it is on the screen every open.
  - Adult sprites are ~21 cells wide and the rooms are 12 and 14, so the shelf shows a
    species-tinted bust (`IconArt.specimen`) rather than the adult itself.

## Decor tiers and the dig cut-scene (2026-11-12)

Jesse, on the home-screen build: "we need a lot of decor variety — 'I found the 4 things and
then displayed them' isn't exactly repeatable engagement," and "when it's dig time you get an
animation of grub coming out of his tunnel, getting smaller to imply going into the
background, then digging into something and disappearing."

**The decor dead end, measured.** Four decor kinds against four slots. 32.5 % of every dig
yields decor (loose 20 %, clay 30 %, deep 55 %, across 3 loose / 3 clay / 2 deep spots). Over
300 simulated runs all four kinds are owned by day 6 at three digs a day, day 12 at the 90th
percentile, day 18 once a day. After that decor cannot be eaten and PLACE is disabled with the
slots full, so it lands in the bag forever: ~30 % of everything dug, dead, from week one.

**Tiers, not more kinds.** A longer list only moves the wall. Each decor kind now has three
conditions — chipped, fine, pristine — rolled at dig time from soil depth + a glinting spot + a
clean dig, so the shelves are tied back to digging deep and digging well. Measured: 74 / 20 /
4 %, every kind pristine around day 37 at three digs a day (90th percentile day 50), day 111
once a day. Tiers are a treatment over the four existing sprites (a bite out of the corner, the
thing as drawn, a glint), so twelve recognisable objects cost four drawings.

- `bestTier` and `bank` are keyed by **kind**, not per item. `placed` stores only the kind, so a
  furnished slot shows the best one owned and improves the moment a better one is dug.
- Surplus banks: 12 duplicates buy the next tier of that kind, or — once it is pristine — of
  whichever kind is furthest behind. Nothing is wasted until the whole set is pristine.
- **Save safety.** Swift's synthesized `Decodable` ignores property defaults, and
  `BurrowStore.load` treats a decode failure as corruption, so adding a field to `BurrowSave`
  the obvious way would have deleted every save. It now has a lenient `init(from:)`, and `load`
  reads a missing `version` as 1 instead of as corruption. `BurrowStoreTests` guards both.

**The trip is a cut-scene.** It was a cut pretending to be one: the grub walked at constant
size, then vanished mid-stride while the grid appeared. Now it shrinks to `farScale` 0.45 as it
travels (the burrow is side-on, so the ramp *is* the depth cue), digs into the mound in a
`burrowingIn` phase, throws dirt and sinks out of sight, and the grid blooms from that same
hole — the zoom anchor moved to the mound crown. `surfacing` mirrors it on the way back. An egg
ends its trip at the zoom-out; it never travelled. Tap-to-skip still covers every beat.

Interpretation flagged to Jesse: "into the top of the game area" is built as receding **toward
the mound**, not flying up and off, because flying up severs the grub↔mound link and the
continuous hand-off into the grid. Swapping the shrink vector is cheap if he wants the other.

## Out of scope

Local notifications ("digs are back"), sound, multiple burrows, cloud sync, migrating
anything from the old `GameState` save, monetisation.
