# Dig Mini-Game — Design

Date: 2026-11-10 · Branch: `the-deep` · Status: approved by Jesse in chat (search B, misses A,
spot variety C, stats A, plus "the grub physically travels to the dig")

## Why

Jesse's first TestFlight impression: "you only have three same dig spots and there's nothing
other than a falling something that indicates that's a dig spot. No variation no skill."
Today a dig is one tap on a `!` marker (`BurrowRules.dig`). This replaces it with a short
skill game played at the spot, plus a crawl-and-zoom trip to get there.

Builds on `2026-11-10-burrow-mechanics-design.md`. Everything there stands except where this
spec says otherwise (the dig itself, the happy bonus roll, spot markers).

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

  - soilStrikes: loose 6 · clay 5 · deep 4
  - conditionStrikes: wet +2, otherwise 0
  - moodStrikes: happy (`joy ≥ 7`) +2 · sulking (`belly == 0`) −1 · otherwise 0.
    Happy and sulking can't both apply. If they could, sulking would win.
- Mood is read once, when the trip starts.

### The grid

- 5 × 5 tiles, indexed `0..<25` (row-major, row 0 at the top).
- Each tile is one of: **soil**, **rock** (2 hit points), **root** (can't be broken).
- The find sits under exactly one **soil** tile. It is never under a rock or a root.
- Rocks and roots are visible from the start. Only the find position is hidden.
- The player may tap **any** unbroken, non-root tile. There is no adjacency rule; roots just
  hide the clues under them.

### A strike

Tapping a tile uses one strike:

- **Soil:** the tile breaks. If it is the find tile, the find goes into the bag and the trip
  ends in success. Otherwise it shows its heat.
- **Rock:** loses 1 hit point. At 0 it becomes broken soil and shows its heat. The strike
  that breaks it counts like any other.
- **Root / already broken:** refused. No strike is used.

Heat uses Manhattan distance `d` from the tile to the find:

| d | Shows |
|---|---|
| 1 | **hot** (amber glow) |
| 2 | **warm** (dull orange) — shows as cold on a **wet** spot |
| ≥ 3 | **cold** (plain broken dirt) |

### Ending a trip

- **Found:** the spot is used up. `holes` gains the spot (as today) and the buried entry is
  removed.
- **Out of strikes:** the trip ends. Broken tiles and rock damage are saved on the spot; the
  find stays buried. Going back costs another dig charge and grants a fresh set of strikes.
- **Leaving early** (back button, or the app going to the background): the same as running
  out. Strikes you didn't use are lost and progress is kept. A trip never survives a relaunch.

### Soil layers (depth)

Each of the 8 spots has a fixed layer, by its depth on the map:

| Layer | Spots | Strikes | Obstacles | Find weights |
|---|---|---|---|---|
| **loose** | 1, 2, 4 | 6 | none | berry 40 · root 25 · mushroom 15 · shell 10 · bone 10 |
| **clay** | 0, 3, 6 | 5 | 3 rocks | today's weights (30/15/15/10/8/8/7/7) |
| **deep** | 5, 7 | 4 | 3 roots | honeydew 20 · crystal 20 · amber 20 · mushroom 15 · bone 15 · root 10 |

The layer table lives in `BurrowSpots` next to the anchors. If the art shows a spot in a
different band than this table, the plan fixes the table to match the art.

### Conditions

Rolled when the find is buried: none 40 % · wet 15 % · rocky 15 % · rooty 15 % · glinting 15 %.

| Condition | Effect |
|---|---|
| **wet** | +2 strikes; warm tiles show as cold |
| **rocky** | +3 rocks (on top of the layer's) |
| **rooty** | +3 roots (on top of the layer's) |
| **glinting** | one tile at d = 2 starts broken (free clue). If no soil tile is at d = 2, use one at d = 1 instead. |

### Grid generation

Done once, at bury time, from the game RNG (the tests inject a seeded RNG). Steps:

1. Pick the find tile uniformly from all 25 tiles.
2. Place the layer's obstacles, then the condition's extras, uniformly on the other tiles.
   Placement retries until at least 4 soil tiles (other than the find) are at d ≤ 2, so a
   grid always has clues to read.
3. Apply glinting's free tile.

The whole grid is stored in the save, so it never re-rolls.

### Removed

- `bonusFindChance` and the `.bonusFind` event. The happy bonus is now +2 strikes.
- `BurrowRules.dig(_:spot:now:rng:)` in its one-tap form. It is replaced by `startTrip` /
  `strike` / `endTrip`, below.

## 2. Getting there (the trip animation)

All of it is presentation. None of it changes the rules or the save.

1. **Crawl out** (~1–1.5 s depending on distance). The grub leaves the chamber and follows
   the tunnels along a waypoint path to the tunnel point nearest the spot. He then burrows
   the last stretch straight through the soil, drawing a short fresh tunnel behind him.
2. **Zoom in** (~0.6 s). The burrow scales up around the spot. The 5 × 5 grid fades in over
   that patch of soil, drawn with the burrow palette at a larger pixel size. The grub sits at
   the grid's edge.
3. **Dig.** Each strike plays a short shovel swing and a burst of dirt particles. A hot tile
   gets a brief amber pulse. A found item pops up and flies to the Finds button.
4. **Return.** Zoom out (~0.6 s), then crawl home along the same path in reverse.

- Tapping during a crawl or zoom skips to the end of that step.
- The tunnel spur to a spot stays drawn once the spot has been visited. It goes away when
  the spot is buried again, the same way `holes` works today.
- Waypoints: a small fixed graph over the existing tunnels (chamber exit, crawl tunnel,
  connectors, side rooms), defined in layout cells, so it scales with `BurrowLayout`.

## 3. Spots on the map

The generic `!` and falling-dirt marker is replaced by:

- **Find cue:** a sprout for food, a glint for decor.
- **Layer bands:** a faint colour step between the loose, clay and deep soil, so depth reads
  at a glance.
- **Condition badge** (droplet / pebble / root curl / sparkle). It only shows once the spot
  has been visited, so a first visit is a surprise.
- **Progress crack:** a spot with any broken tiles shows a small crack.

The counts don't change: 8 spots, at most 4 buried, one new find buried every 2 h.

## 4. Data

`BuriedFind` grows (all new fields Codable):

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
SoilLayer = .loose | .clay | .deep        // from BurrowSpots, not saved
```

- **Save version 1 → 2.** On load, any v1 `BuriedFind` (spot + kind only) gets a grid
  generated with a fixed seed derived from its spot index, so the migration is repeatable.
  Its `kind` is kept as is, even if it falls outside its layer's table.
- A trip in progress (`DigTrip { spot, strikesLeft }`) lives in the model, never in the save.

## 5. Rules API (pure, in `BurrowRules`, returns `BurrowResult`)

- `startTrip(save, spot)` — refusals: nothing buried there, no digs. Uses a charge, marks the
  spot visited, and returns the strikes granted through the event `.tripStarted(spot:strikes:)`.
- `strike(save, spot, tile, strikesLeft)` — refusals: no strikes left, a root, already broken.
  Updates the tile. Events: `.tileBroken(tile:heat:)` / `.rockChipped(tile:)` /
  `.dugUp(spot:kind:)` (as today).
- Grid generation is a pure function taking `inout` RNG. It is used by `bury` and the
  migration.

The model owns `strikesLeft` and calls `persist()` after every strike, so progress survives
a kill mid-trip.

## 6. Debug and testing

- **Unit tests:**
  - strike maths: mood, wet, the floor of 2
  - heat at each distance, including wet
  - the rock takes 2 hits
  - roots are refused
  - finding the item ends the trip and fills the bag
  - running out keeps progress
  - generation guarantees: the find is on soil, the obstacle counts, at least 4 clue tiles,
    glinting's free tile
  - layer weights
  - v1 → v2 migration, including that it's repeatable
- **New launch argument `-burrowDigDemo` (DEBUG):** crawls to a clay spot, strikes a scripted
  sequence (a cold tile, a warm one, a rock twice, then the find), and returns. Used for
  simulator screenshots of each step.
- **Simulator check:** crawl, zoom, the clue colours, the found pop, the return, the new
  markers, and the condition badge after a visit.
- **Then:** upload to TestFlight as 1.0.3 (6) with the rounded-grub fix.

## Out of scope (for now)

- Bonus items hidden in other tiles, and rewards for strikes left over.
- More than 8 spots, or spots that move.
- Sound effects. The audio MCPs aren't connected.
