# Dig Mini-Game — Design

Date: 2026-11-10 · Branch: `the-deep` · Status: approved by Jesse in chat (search B, misses A,
spot variety C, stats A, plus "the grub physically travels to the dig")

## Why

Jesse's first TestFlight impression: "you only have three same dig spots and there's nothing
other than a falling something that indicates that's a dig spot. No variation no skill."
Today a dig is one tap on a `!` marker (`BurrowRules.dig`). This replaces it with a short
skill game played at the spot, plus a crawl-and-zoom trip to get there.

Builds on `2026-11-10-burrow-mechanics-design.md`. Everything there stands except where this
spec says otherwise (the dig itself, the happy bonus roll, spot markers, the pacing test).

## Decisions (from Jesse)

| Question | Choice |
|---|---|
| What skill | **B** — hot/cold search on a small grid with limited strikes |
| Running out of strikes | **A** — progress kept; the find stays buried, broken tiles stay broken |
| Spot variety | **C** — depth sets the soil, plus a random per-spot condition |
| Mood stats | **A** — happy +2 strikes, sulking −1; the hidden 35 % bonus roll is removed |
| Getting there | The grub crawls through the tunnels to the spot, then the view zooms in. No hard cut. |

## 1. The dig (rules)

### Cost and strikes

- A **trip** costs one dig charge (`digs`, unchanged: max 3, +1 every 3 h).
- A trip grants strikes:

  `strikes = max(2, soilStrikes + conditionStrikes + moodStrikes)`

  - soilStrikes: loose 6 · clay 6 · deep 5
  - conditionStrikes: wet +2 · otherwise 0
  - moodStrikes: `isSulking(s) ? −1 : isHappy(s) ? +2 : 0`, using the existing helpers.
    Sulking wins when both hold (belly 0 with joy still high). Both helpers require
    `.larva`, so **an egg always gets +0** — stats don't exist yet at that stage.
- Mood is read once, when the trip starts, and is not recomputed if `advance` runs mid-trip.
- The worst case is 4 — deep (5) + sulking (−1) — so `max(2, …)` never actually clamps
  today. It stays as a guard for future tuning; the test asserts the sum, not the clamp.

> **Pacing note, 2026-11-10.** Clay and deep were 5 and 4 when this spec was written. Measured
> against the finished mini-game (`BurrowPacingTests`, the greedy solver playing every trip), a
> once-a-day player then took **6.5 days** to molt against the parent spec's 5.5-day bar: the
> one-tap dig never failed *and* paid a 35 % bonus find, and both are gone. One extra strike on
> clay and deep brings it to **5.3 days** (2–4 visits a day: 2.4–2.5, bar 3). Loose soil keeps
> its 6 — it already solved every grid, so a 7th strike moved nothing. The cost is that a
> greedy player now wins 96–100 % of grids rather than 82–100 %; the layers' difficulty is
> carried by their obstacles and find tables more than by their strike counts.

### The clean dig (added 2026-11-11)

Finding the item with **3 or more strikes still in hand** pays a bonus find, drawn from the
spot's own soil table. The grid says so at once ("CLEAN DIG! + <kind>"), and the burrow plays
its own version once the grub is home.

**Why it exists.** The mini-game as first built was won 96–100 % of the time, and a win cost
3.3–4.0 strikes of a 5–6 budget — so the budget was barely doing anything and there was
nothing to play *for*. That cannot be fixed by cutting strikes: 25 tiles sorted into 3 answers
puts the information floor at **2.93 strikes**, so the search was already being solved at its
theoretical minimum. Trimming the budget would have converted skill into luck, which is how
the rooty problem happened. The lever had to be what a dig is *worth*, not whether it is won.

**Why 3.** Measured over 6,000 seeded trips, the spare-strike distribution is 0: 6 %, 1: 23 %,
2: 31 %, 3: 21 %, 4: 7 %, 5+: 4 %, lost: 4 %. A threshold of ≥2 fires on 65 % of trips (the
default outcome), ≥4 on 12 % (not worth chasing), and **≥3 on 34 %** — which happens to be the
rate of the hidden bonus-find roll this replaces. Same payoff, earned instead of rolled.

It is harder on deep soil (5 strikes, so a clean dig means finding it in two) than on loose
(6). That is left alone deliberately: deep pockets pay the better base find and the better
bonus, so the layer stays worth visiting.

**The strike row shows the window.** The strikes still inside it are drawn lit; spending them
dims the row, so the stake is legible without a word of explanation.

**Pacing.** The bonus returns molting to the original figures — 2.3 / 2.3 / 4.9 days for
4 / 2 / 1 visits a day, against 2.3 / 2.4 / 4.5 before the mini-game existed. Note the sim
plays every dig with `DigSolver`, which earns the bonus more often than a person will, so a
real once-a-day player sits between 4.9 and the 5.3 measured without it.

**What this does not fix.** The base win is still near-certain. That is the intended shape for
a cozy idle pet: you are never robbed of a dig charge (progress is kept, and that was Jesse's
call), but playing well is now worth something. If the search itself ever needs to get harder,
the lever is grid size, not strike count — 6×6 moves the floor to 3.3 strikes and 7×7 to 3.5.

### The grid

- 5 × 5 tiles, indexed `0..<25` (row-major, row 0 at the top).
- Each tile is one of: **soil**, **rock** (2 hit points), **root** (can't be broken),
  **broken**.
- The find sits under exactly one tile that is **not a root** — so it can hide under a rock,
  which then costs 2 strikes to reach.
- Rocks and roots are visible from the start. Only the find position is hidden.
- The player may tap **any** unbroken, non-root tile. There is no adjacency rule.

### A strike

Tapping a tile uses one strike:

- **Soil:** the tile breaks and shows its heat. If it is the find tile, the find goes to the
  bag and the trip ends in success.
- **Rock:** loses 1 hit point. At 0 it becomes broken and shows its heat, and yields the find
  if it was hiding it. The hit that breaks it counts like any other strike.
- **Root / already broken:** refused. No strike is used.

Heat uses Manhattan distance `d` from the tile to the find:

| d | Shows |
|---|---|
| 1 | **hot** (amber glow) |
| 2 | **warm** (dull orange) — shows as cold on a **wet** spot |
| ≥ 3 | **cold** (plain broken dirt) |

### Ending a trip

- **Found:** the spot is used up. `holes` gains the spot and the buried entry is removed, as
  `dig` does today.
- **Out of strikes:** a toast ("OUT OF STRIKES"), then the view returns home after ~1 s.
  Broken tiles and rock damage are saved; the find stays buried. Going back costs another
  charge and grants a fresh set of strikes.
- **Leaving early** (BACK, or the app going to the background): the same as running out.
  Unused strikes are lost, progress is kept. A trip never survives a relaunch.

### Soil layers (depth)

Each of the 8 spots has a fixed layer. The assignment below is what the **current anchors
actually resolve to** — spot 5 (`chamberTop +28`) always sits 14 rows above spot 3
(`chamberBottom +11`), because the chamber is always 31 rows tall, so spot 5 is clay and
spot 3 is deep:

| Layer | Spots | Strikes | Obstacles | Find weights |
|---|---|---|---|---|
| **loose** | 1, 2, 4 | 6 | none | berry 40 · root 25 · mushroom 15 · shell 10 · bone 10 |
| **clay** | 0, 5, 6 | 5 | 3 rocks | today's weights (30/15/15/10/8/8/7/7) |
| **deep** | 3, 7 | 4 | 3 roots | honeydew 20 · crystal 20 · amber 20 · mushroom 15 · bone 15 · root 10 |

The table lives in `BurrowSpots` beside the anchors and is the rules' source of truth. A test
resolves every anchor at **SE, 15, 15 Pro Max and iPad Pro 11″** and asserts each spot's row
falls in the band its layer claims, so art and rules can't drift apart silently.

**That test fails on iPad today, and fixing it is the plan's first task.** The app ships
iPad-compatible (`TARGETED_DEVICE_FAMILY = "1,2"`), but the anchors use fixed `dy` offsets
while an iPad's burrow is only ~92 rows tall with the same fixed 31-row chamber. Spots 3 and
7 overflow into `soil4`, and on some iPad sizes spot 2 lands a band too deep. The anchors
become proportional to the soil height instead of fixed, until all 8 spots resolve into their
layer's band at every size above. This is a pre-existing iPad layout bug that the layer bands
would otherwise make visible.

### Layers vs the backdrop's bands

`BurrowArt.backdrop` draws **four** soil bands (`soil1`–`soil4`, split at 24 % / 51 % / 75 %
of the soil height). Three layers map onto the first three: loose = `soil1`, clay = `soil2`,
deep = `soil3`. `soil4` is the floor of the burrow and holds no spots. The art does not
change; §3's "layer bands" is a small contrast lift between those existing bands, not a
re-cut.

### Conditions

Rolled when the find is buried: none 40 % · wet 15 % · rocky 15 % · rooty 15 % · glinting 15 %.

| Condition | Effect |
|---|---|
| **wet** | +2 strikes; warm tiles show as cold |
| **rocky** | +3 rocks (on top of the layer's). The cost is that the find may hide under one. |
| **rooty** | +3 roots (on top of the layer's). Roots can never hide the find, so the extra roots shrink the search — rooty is the gentle condition, and that is the point: not every twist should hurt. |

> **Balance note, 2026-11-10.** Rooty originally also cost a strike, on the theory that extra
> roots would otherwise *help*. Measured over 400 seeded grids per combination
> (`DigBalanceTests`), that made deep + rooty a 3-strike search of 25 tiles — winnable about
> **50 %** of the time, against 82–100 % everywhere else. Cutting the extra roots from 3 to 2
> changed nothing (still 50 %): the binding constraint was the strike count, not the clutter.
> Dropping the penalty takes deep + rooty to **95 %** and clay + rooty from 82 % to 96 %,
> without touching the depth gradient. Jesse chose this over giving deep soil a 5th strike.
>
> The same pass showed wet at 68–74 %, but that is the measuring instrument, not the game:
> `DigSolver` deliberately ignores wetness when scoring its next move (simplification 1), so it
> plays wet spots badly. A wet-aware greedy player scores **86–100 %**. Wet is left alone.
| **glinting** | one **eligible** tile at d = 2 starts broken (a free warm clue), where eligible means unbroken, not a root and not the find tile. If none is at d = 2, use one at d = 1. If it lands on a rock, the rock breaks fully rather than losing one hit point. |

### Grid generation

A pure function, run once at bury time from the game RNG. **RNG draw order is fixed** —
spot → kind → condition → find tile → layer obstacles → condition extras → glinting reveal —
because both the seeded tests and the save migration depend on reproducing it exactly.

1. Pick the find tile uniformly from all 25.
2. Place the layer's obstacles, then the condition's extras, uniformly on the other tiles.
   Roots never land on the find tile; rocks may.
3. Apply glinting's free tile, if any.
4. Check the clue constraint: at least **4** tiles other than the find at d ≤ 2 must be
   still diggable (soil or rock — a rock shows heat once broken; roots and the already-broken
   glinting tile don't count). On a **wet** spot, additionally at least **2** diggable tiles
   at d = 1, since d = 2 reads as cold there.
5. If the check fails, retry from step 2, up to **40 attempts**. After that, re-place from
   scratch with one fewer obstacle (roots first, then rocks) and repeat until the check passes
   — a deterministic fallback, so generation always terminates. (It always can: with no
   obstacles even a corner find has 5 tiles at d ≤ 2 and 2 at d = 1.)

The function reports whether the fallback fired, so the generation tests can assert exact
obstacle counts on the normal path and `≤ nominal` when it did. The whole grid is stored in
the save and never re-rolls.

### Removed

- `bonusFindChance` and the `.bonusFind` event. The happy bonus is now +2 strikes.
- `BurrowRules.dig(_:spot:now:rng:)` in its one-tap form, replaced by `startTrip` / `strike`.
- `BurrowRules.weightedKind` and `FindKind.buryWeight`. The per-layer tables above replace
  them, and removing the bonus find removes their only other caller, so the global weights
  would otherwise be dead code.

## 2. Getting there (the trip animation)

Presentation, with two exceptions: `startTrip` sets `visited`, which is saved, and the spur
set below is derived from the save so it survives a relaunch.

1. **Crawl out** (~1–1.5 s by distance). The grub leaves the chamber and follows a waypoint
   path through the existing tunnels to the point nearest the spot, then burrows the last
   stretch through soil, drawing a short fresh spur behind him.
   **In the `.egg` stage there is no crawl** — an egg can't travel, so the view goes straight
   to the zoom and the egg stays in the chamber.
2. **Zoom in** (~0.6 s). The burrow scales up around the spot; the 5 × 5 grid fades in over
   that patch, drawn with the burrow palette at a larger pixel size. The grub (when present)
   sits at the grid's edge.
3. **Dig.** Each strike plays a shovel swing and a dirt burst. A hot tile pulses amber. The
   find pops and flies to the Finds button.
4. **Return.** Zoom out (~0.6 s), then crawl home along the same path reversed.

- Tapping during a crawl or zoom skips to the end of that step.
- While a trip is running (crawl, zoom, grid, return) the HUD buttons, the other markers and
  the grub itself are inert. Only the skip tap, the grid's tiles and BACK respond.
- Spurs stay drawn for visited spots, and clear when the spot is buried again — the same
  lifecycle as `holes`. The spur set is derived from the save as
  `holes ∪ buried.filter(\.visited)` and passed to `BurrowBackdrop` as a second equatable
  input, so it re-renders when a spot becomes visited and is correct after a relaunch. Spurs
  are capped in length and routed from the nearest tunnel point, so spot 2 (upper right,
  ~14 rows out) can't scribble into the title.
- Waypoints are a small fixed graph in layout cells (chamber exit, crawl tunnel, connectors,
  side rooms), so it scales with `BurrowLayout`.

### Stage gating

`BurrowHomeModel.canAct` is only `save.stage == .larva` and guards nothing else, so this path
cannot reuse it — doing so would refuse every egg dig. The marker tap gets its own predicate,
`canStartTrip`, and the marker is drawn inert when it is false:

```
canStartTrip = (stage == .egg || stage == .larva)
             && trip == nil && !inCocoon
             && !placing && !namingEgg && !confirmingMolt && !revealing && !showBox
             && !showingFindsBag
```

The rules refuse independently (`.wrongStage` for `.adult`, `.noDigs`, `.nothingBuriedThere`),
so a stale tap can never start a trip the save disallows.

## 3. Spots on the map

The generic `!` marker is replaced by:

- **Find cue:** a sprout for food, a glint for decor.
- **Layer bands:** a small contrast lift between the existing `soil1`/`soil2`/`soil3` bands,
  so depth reads at a glance.
- **Condition badge** (droplet / pebble / root curl / sparkle), shown only once the spot has
  been visited, so a first visit stays a surprise.
- **Progress crack:** shown when `visited` **and** the player has broken at least one tile
  themselves — that is, broken count exceeds glinting's free tile. Without that second
  clause an untouched glinting spot would advertise its condition through the crack.

Counts are unchanged: 8 spots, at most 4 buried, one new find buried every 2 h.

## 4. Data

`BuriedFind` grows (all Codable):

```
BuriedFind {
  spot: Int
  kind: FindKind
  condition: DigCondition?      // nil = none
  findTile: Int                 // 0..<25
  tiles: [DigTile]              // 25 entries
  visited: Bool
}
DigTile = .soil | .rock(hp: Int) | .root | .broken
DigCondition = .wet | .rocky | .rooty | .glinting
Heat = .hot | .warm | .cold
SoilLayer = .loose | .clay | .deep        // from BurrowSpots, never saved
```

### Save version 1 → 2 (this is the part that must not go wrong)

`BurrowStore.load` decodes `BurrowSave` directly and, on **any** decode failure, renames the
file to `burrow.corrupt.json` and starts a fresh game. New non-optional fields on
`BuriedFind` would therefore delete every existing player's grub. So:

- `BuriedFind` gets a hand-written `init(from:)` using `decodeIfPresent`. A v1 entry (spot +
  kind only) decodes with `tiles` empty, which marks it "needs a grid".
- `BurrowSave.currentVersion` becomes **2**. The existing "newer than we know" branch is
  untouched: a version above 2 is still moved aside.
- `load` runs `BurrowRules.migrateToV2(&save)` after a successful decode when
  `save.version < 2`: every entry with empty `tiles` gets a grid generated from
  `BurrowRNG(seed: migrationSeed(spot))`, the condition is rolled from the same RNG, `kind`
  is kept exactly as it was (even where it falls outside its layer's table), `version` is set
  to 2, and the migrated save is written back. It also repairs any entry whose `tiles.count`
  isn't 25 regardless of version, so a hand-edited or part-written v2 save can't reach the
  grid with no grid to show.
- **Store test:** a real v1 JSON fixture loads, comes back with grids and version 2, keeps
  its original kinds, and leaves no `burrow.corrupt.json` behind. Plus a test that migrating
  the same fixture twice gives identical grids.

### Seeded RNG in the app target

`SeededRNG` currently exists only in `GrubIOSTests`. The migration and `fresh` need one in
the app, so a small SplitMix64 `BurrowRNG` moves to `GrubIOS/Burrow/BurrowRNG.swift` and the
tests use it instead of their own copy.

### `fresh` and the test initialiser

`BurrowSave.fresh(now:)` builds `BuriedFind(spot:kind:)` for spots 0/1/2 and takes no RNG.
It gets its grids from `BurrowRNG` with a fixed seed, so a first launch is identical every
time and `test_fresh_save_matches_spec` can assert exact tiles. Its three spots get
`condition: nil`, keeping the very first dig plain. Spot 2's crystal stays, even though
crystal isn't in the loose table — `fresh`'s kinds are fixed by the parent spec.

So existing tests keep compiling, `BuriedFind(spot:kind:)` stays as a convenience
initialiser that generates a grid from a spot-derived seed.

A trip in progress (`DigTrip { spot, strikesLeft }`) lives in the model, never in the save.

## 5. Rules API (pure, in `BurrowRules`, returning `BurrowResult`)

- `startTrip(save, spot)` — refusals `.nothingBuriedThere`, `.noDigs`, `.wrongStage`. Spends
  a charge, sets `visited`, and reports the strikes granted via `.tripStarted(spot:strikes:)`.
- `strike(save, spot, tile, strikesLeft)` — refusals `.nothingBuriedThere`, `.noStrikes`,
  `.rootTile`, `.alreadyBroken`, `.badTile` (index outside `0..<25`; the UI can't produce it,
  but the function stays total).
  Events, in order: `.rockChipped(tile:)` when a rock survives the hit; otherwise
  `.tileBroken(tile:heat:)` for the tile that just broke — including the hit that finishes a
  rock — followed by `.dugUp(spot:kind:)` when that tile was hiding the find.
- `strikesLeft` is passed in only so the rules can refuse. The model decrements it by 1
  whenever the result is not a refusal, and calls `persist()` after every strike, so progress
  survives a kill mid-trip.
- **Ending a trip is a model action, not a rules function.** The save is already current
  after each strike, so there is nothing for the rules to do.
- Grid generation is a pure function over an `inout` RNG, shared by `bury`, `fresh` and the
  migration.

The four genuinely new `Refusal` cases need toast text, since `BurrowHomeModel.message`
switches exhaustively: `.noStrikes` "OUT OF STRIKES" · `.rootTile` "A ROOT.\nDIG ELSEWHERE" ·
`.alreadyBroken` "ALREADY DUG" · `.badTile` "CAN'T DIG THERE". `.wrongStage` already exists
and keeps its "NOT NOW" — it is shared with `feed`, `pet`, `place`, `remove`, `startMolt`,
`name` and `crackEgg`, so its copy must not change here.

## 6. Debug and testing

**Unit tests**

- strike maths: each layer, each condition, happy / sulking / both, egg gets +0, floor of 2
- heat at d = 1 / 2 / ≥ 3, and warm reading cold when wet
- a rock takes two hits, and a rock can hide the find
- roots and broken tiles are refused and cost no strike
- finding the item fills the bag, adds to `holes` and clears the buried entry
- running out keeps broken tiles and rock damage
- generation: the find is never under a root, obstacle counts per layer and condition, the
  clue constraint (including wet's d = 1 rule), glinting's free tile, the fallback terminates
- layer find-weight tables
- v1 → v2: a real fixture migrates, keeps kinds, bumps the version, isn't moved aside, and
  repeats identically

**Pacing**

`BurrowPacingTests` currently calls `BurrowRules.dig` and assumes one find per charge plus
the 35 % bonus — all three assumptions are gone. The sim gains a deterministic greedy solver,
shared with the tests, and a trip succeeds only when that solver succeeds. The solver is
pinned, because the pacing numbers depend on it:

- It keeps the **candidate set**: every tile that could still hold the find, given the heats
  revealed so far and the rule that the find is never under a root. It starts as all
  non-root tiles.
- Each turn it scores every still-diggable tile by `eliminated / cost`, where `eliminated` is
  the expected shrink in the candidate set if that tile is struck (averaged over the
  candidates, each equally likely) and `cost` is 1 for soil, or the rock's remaining hit
  points.
- It strikes the highest score, breaking ties by the **lowest tile index**.
- Striking a candidate tile that turns out to hold the find ends the trip as a success.

The parent spec's
2.3 / 2.4 / 4.5-day figures are re-measured and the expectations updated to the new numbers,
which must still satisfy: 2–4 visits/day reaches molt in under 3 days, once-a-day in under
5.5 days. If they don't, strike counts get tuned before the numbers are written down.

Failed trips keep a spot occupied, so `buried` sits at its cap of 4 more often and the bury
timer idles — the sim will show how much that costs.

**Before the condition weights are locked**, the same sim runs each layer × condition
combination and reports the solver's success rate. The case to watch is rocky clay: 6 rocks
against 5 strikes means a d ≤ 2 neighbourhood that comes up mostly rock leaves room for only
two clues. If any combination lands below ~70 % for the solver, its numbers are tuned before
the spec's tables are treated as final.

**Also to update or delete**

Four tests go: `test_dig_moves_find_to_bag_and_leaves_hole`, `test_dig_refusals`,
`test_bonus_find_only_when_happy_at_about_35_percent` and `test_bonus_find_lands_in_bag`.
**Keep** `test_digs_regrow_one_per_3h_and_cap_at_3`, `test_dig_timer_carries_partial_time_below_cap`
and `test_dig_timer_does_not_bank_at_cap` — those cover `advance`, not the dig.

`test_bury_weights` is rewritten against the three per-layer tables.
`test_find_table_matches_spec` asserts `foodWeight == 70`, which is no longer any table's
value: food is 80 % loose, 70 % clay, 45 % deep, averaging **67.5 %** over the 8 spots. It
becomes a per-layer assertion plus that average, and the parent spec's "70 % of burials are
food" line is amended to match.

Also: the `.bonusFind` case in `BurrowHomeModel.handle`; `-burrowDemo`'s `model.dig` call;
the "TAP A ! TO DIG" toast, the `digHintAt` marker flash and the markers' accessibility text
("Buried find" / "Dig it up"); and `BurrowSave`'s now-false comment that every field exists
from version 1 so later phases need no migration.

The parent spec keeps its own description of the 35 % bonus in four places (its Stat roles
table, its "happy" section, its constants block and its test list). The blanket supersession
at the top of this spec covers them, but each gets a one-line "superseded by the dig spec"
note so the next reader doesn't re-derive the old rule.

**Accessibility**

Heat is colour-only today. Each tile gets an accessibility label ("row 2, column 3, hot") and
a non-colour cue (a small glyph) so the clues are readable without colour.

**New launch argument `-burrowDigDemo` (DEBUG)**

Hatches to a larva, crawls to a clay spot, strikes a scripted sequence (cold, warm, a rock
twice, then the find) and returns — used for simulator screenshots of each step. It hatches
first because `-burrowReset` leaves the stage at `.egg`, and it uses spot 0, which `fresh`
always buries and which is clay. That sequence spends clay's 5 strikes exactly, with no mood
modifier at joy 6 / belly 6, and it assumes the fixed `fresh` seed puts a rock within d ≤ 2
of the find. The demo asserts both preconditions and trips an assertion failure if the seed
ever stops satisfying them, rather than silently screenshotting the wrong thing.

**Simulator check:** crawl, zoom, clue colours, the found pop, the return, the new markers,
and a condition badge appearing after a visit.

## Out of scope (for now)

- Bonus items hidden in other tiles. (Rewards for strikes left over moved *in* scope on
  2026-11-11 and shipped — see "The clean dig" above.)
- More than 8 spots, or spots that move.
- Sound effects. The audio MCPs aren't connected.
