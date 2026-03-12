# Grub Overhaul: Foraging, Crafting & Progression

## Overview

Rework GrubIOS from a shallow Tamagotchi clone into a survival-crafting pet game. Replace the flat feed/play/meds loop with a foraging + crafting economy, deeper minigames, inventory management, and progression-gated unlocks. Overhaul the UI with better status bars and a 4-button bottom nav.

## Core Loop

```
Forage (active + passive) -> Gather Ingredients -> Craft Food/Items ->
Feed/Heal Grub -> Play Minigames -> Level Up -> Unlock Recipes & Games
```

Every action feeds back into the loop. Foraging provides ingredients. Crafting turns ingredients into usable food and medicine. Feeding and healing keep Grub alive. Minigames provide happiness, XP, and rare ingredients. Leveling unlocks new recipes and games.

---

## 1. Ingredients System

12 ingredients organized by rarity. Each has a pixel icon rendered in the same style as existing PixelIcon assets (9x9 or 11x11 grid).

### Common (passive + forage)
| Ingredient | Color Theme | Description |
|---|---|---|
| Moss Clump | Green | Basic plant matter, everywhere |
| Cave Beetle | Brown/dark | Crunchy protein source |
| Mud Root | Brown/tan | Starchy underground tuber |
| Dew Drop | Blue/cyan | Water condensation |

### Uncommon (forage + minigame rewards)
| Ingredient | Color Theme | Description |
|---|---|---|
| Glowshroom | Purple/glow | Bioluminescent mushroom |
| Crystal Shard | Cyan/white | Cave mineral |
| Pale Worm | Pink/bone | Rare cave dweller |
| Slime Berry | Green/red | Grows on cave walls |

### Rare (forage risk, events, streaks)
| Ingredient | Color Theme | Description |
|---|---|---|
| Moon Petal | Silver/blue | Only found at night |
| Ember Seed | Orange/red | Dangerous to collect |
| Ancient Spore | Purple/gold | Event-exclusive |
| Golden Bug | Gold | Minigame streak reward |

### Data Model

```swift
struct Ingredient: Codable, Identifiable {
    let id: String          // e.g. "moss_clump"
    let name: String        // e.g. "MOSS CLUMP"
    let rarity: Rarity      // .common, .uncommon, .rare
    var quantity: Int        // current held amount
}

// Stored as dictionary [String: Int] in GameState for persistence
// Max 20 total ingredient stacks
```

---

## 2. Foraging System

### Active Foraging

Triggered by the FORAGE button in the bottom nav. Opens an area selection overlay.

**Three areas:**

| Area | Loot Table | Risk |
|---|---|---|
| Shallow Cave | 70% common, 25% uncommon, 5% rare | None |
| Deep Burrow | 30% common, 50% uncommon, 20% rare | 20% chance: -10 happiness ("Grub got spooked!") |
| Surface | 40% common, 20% uncommon, 40% rare (different pool) | 15% chance: -5 health ("Grub got scratched!") |

- Returns 2-4 ingredients per forage
- Night foraging (9PM-7AM): Moon Petal added to Surface loot table
- Deep Burrow: Ember Seed chance only here
- **45-minute real-time cooldown** between active forages
- Grants 3 XP per forage
- Shows results as an overlay: "GRUB FOUND:" with item icons listed

**Cooldown persistence:** Stored as `lastForageTime: Date` in UserDefaults. Cooldown survives app close.

### Passive Gathering

- Every 2 hours of real time (while app is closed or open), Grub finds 1-2 common ingredients
- Max 8 passive items accumulate (capped)
- On app open, if passive items exist, show a "FOUND ITEMS" toast or small overlay listing what was found
- Passive items are always common rarity
- Calculated on `onForeground()` based on time elapsed since last passive collection
- If ingredient inventory is at 20 stacks, passive items are lost — toast shows "Inventory full! Make room to gather."

### Forage Overlay UI

```
+----------------------------+
|       SEND GRUB OUT        |
|                            |
|  [ SHALLOW CAVE ]          |
|  Safe - Common items       |
|                            |
|  [ DEEP BURROW ]           |
|  Risky - Better items      |
|                            |
|  [ SURFACE ]               |
|  Mixed - Night specials    |
|                            |
|  Cooldown: 32 MIN          |
|                            |
|       [ CLOSE ]            |
+----------------------------+
```

When on cooldown, area buttons are grayed out with remaining time shown.

---

## 3. Crafting & Recipes

### Recipe Scroll System

- 3 recipes known from game start
- Additional recipes unlock via:
  - Owner level milestones (automatic)
  - Recipe scrolls found while foraging (rare)
  - Recipe scrolls from event rewards
  - High score milestones in minigames
- Recipe scrolls are consumed instantly on discovery — they are NOT inventory items. When found, a toast shows "NEW RECIPE: [name]!" and the recipe ID is added to `unlockedRecipes`.
- Unlocked recipes persist in UserDefaults as `Set<String>`

### Recipe List

**Starter Recipes (known from start):**

| Recipe | Ingredients | Effect |
|---|---|---|
| Moss Gruel | 2x Moss Clump | HNG +15 |
| Bug Snack | 2x Cave Beetle | HNG +10, HAP +5 |
| Mud Paste | 1x Mud Root + 1x Dew Drop | HP +15 |

**Level-Unlocked Recipes:**

| Recipe | Unlock | Ingredients | Effect |
|---|---|---|---|
| Shroom Stew | Level 2 | 1x Glowshroom + 1x Moss Clump + 1x Dew Drop | HNG +30, HAP +10 |
| Crystal Tonic | Level 3 | 1x Crystal Shard + 1x Dew Drop | HP +30 |
| Worm Jerky | Level 4 | 2x Pale Worm | HNG +20, HAP +15 |
| Berry Jam | Level 5 | 2x Slime Berry + 1x Moss Clump | HNG +25, HAP +20 |
| Moon Brew | Level 6 | 1x Moon Petal + 1x Dew Drop + 1x Crystal Shard | HP +40, HAP +10 |
| Ember Cake | Level 7 | 1x Ember Seed + 1x Slime Berry + 1x Mud Root | HNG +40, HAP +25 |

**Scroll-Unlocked Recipes (found via forage/events):**

| Recipe | Source | Ingredients | Effect |
|---|---|---|---|
| Spore Elixir | Event scroll | 1x Ancient Spore + 1x Glowshroom + 1x Crystal Shard | Full heal (HP=100) |
| Golden Feast | Forage scroll | 1x Golden Bug + 1x Moon Petal + 1x Ember Seed | All stats +30 |
| Beetle Brew | Forage scroll | 2x Cave Beetle + 1x Glowshroom | HAP +35 |
| Root Steak | Minigame scroll | 2x Mud Root + 1x Pale Worm | HNG +35, HP +10 |
| Dew Elixir | Minigame scroll | 3x Dew Drop + 1x Crystal Shard | HP +25, HAP +15 |

### Crafting Data Model

```swift
struct RecipeIngredient: Codable {
    let id: String       // ingredientId
    let quantity: Int
}

struct StatEffects: Codable {
    let hunger: Int
    let happiness: Int
    let health: Int
}

enum UnlockType: Codable, Equatable {
    case starter
    case level(Int)
    case scroll
}

struct Recipe: Codable, Identifiable {
    let id: String                        // e.g. "moss_gruel"
    let name: String                      // e.g. "MOSS GRUEL"
    let ingredients: [RecipeIngredient]    // list of {id, quantity}
    let effects: StatEffects
    let unlockType: UnlockType
}

// Crafted items stored as [String: Int] (recipeId: quantity)
// No cap on crafted item storage (incentivize crafting)
```

**Note:** Recipes are defined as static data, not persisted. Only `unlockedRecipes: Set<String>` is saved. The `Recipe` struct is `Codable` for potential future use but the master list lives in code.

### Crafting UI

Accessed from the ITEMS screen. Shows known recipes in a scrollable list.

```
+----------------------------+
|         CRAFTING           |
|                            |
|  MOSS GRUEL          [2x] |
|  2x Moss Clump            |
|  HNG +15      [ CRAFT ]   |
|                            |
|  BUG SNACK           [0x] |
|  2x Cave Beetle            |
|  HNG +10 HAP +5   [ CRAFT ]|
|                            |
|  SHROOM STEW   (locked)   |
|  Unlocks at Level 2        |
|                            |
|       [ CLOSE ]            |
+----------------------------+
```

- Green "CRAFT" button when all ingredients available
- Grayed out when missing ingredients (shows what's missing)
- Locked recipes show unlock condition
- Crafting consumes ingredients, produces 1 crafted item
- Crafting grants 1 XP

---

## 4. Inventory Screen

Replaces the MEDS button/overlay. The ITEMS button opens this screen.

### Layout

Two tabs within the overlay: **INGREDIENTS** and **FOOD/MEDS**

**Ingredients tab:**
- Grid of held ingredients with quantity badges
- Pixel icon + name + quantity for each
- Max 20 ingredient stacks shown
- "CRAFT" button at bottom opens crafting sub-screen

**Food/Meds tab:**
- List of crafted items ready to use
- Tap item to use on Grub (plays feed/heal animation)
- Shows effect preview before confirming
- No cap on crafted item storage

### Data Model Changes to GameState

```swift
// New @Published properties:
var ingredients: [String: Int] = [:]        // ingredientId: quantity
var craftedItems: [String: Int] = [:]       // recipeId: quantity
var unlockedRecipes: Set<String> = []       // recipeIds
var lastForageTime: Date? = nil
var passiveGatherTime: Date = Date()
var activeEffects: [ActiveEffect] = []
static let forageCooldownSeconds: Int = 2700  // 45 minutes (constant)

// Computed:
var canForage: Bool { /* check cooldown */ }
var forageTimeRemaining: Int { /* seconds left */ }
var totalIngredientStacks: Int { /* count of non-zero entries */ }
```

---

## 5. Minigame Rework

### Game Selector

Player chooses which game to play. Opens a selection screen instead of jumping straight in.

### 5 Minigames

| Game | Unlock | Rounds | Mechanic |
|---|---|---|---|
| Dodge | Start | 5 | Left/right wall dodge. Walls appear faster each round (1.5s -> 1.0s -> 0.7s -> 0.5s -> 0.4s). |
| Feed Me | Start | 5 | Match the highlighted food. Timer shrinks: 3s -> 2.5s -> 2s -> 1.5s -> 1s. |
| Memory | Level 3 | 1 | 4x3 grid of 6 pairs. Flip two cards at a time. Score = 12 - (flips - 6). Min score 1. |
| Bug Catch | Level 5 | 1 | 15-second timer. Bugs (pixel sprites) crawl across canvas. Tap to catch. Score = bugs caught. |
| Rhythm | Level 7 | Open | Simon-says with 4 colored buttons. Sequence grows by 1 each round. Score = longest sequence. |

### Rewards

- **Win** (Dodge/Feed Me: 3+ of 5 correct): +15 happiness, 1-2 uncommon ingredients, 3 XP
- **Lose**: +5 happiness, 3 XP
- **Memory/Bug Catch/Rhythm**: Rewards scale with score
  - Low score: +10 happiness, 1 common ingredient
  - Mid score: +15 happiness, 1 uncommon ingredient
  - High score: +20 happiness, 1 rare ingredient (not Golden Bug)
- **3-game win streak** (tracked across games): +1 Golden Bug
- **High score milestones**: First time beating a threshold in any game = recipe scroll

### High Scores

```swift
var highScores: [String: Int] = [:]  // gameId: best score
var winStreak: Int = 0
```

### Game Selector UI

```
+----------------------------+
|         ARCADE             |
|                            |
|  [D] DODGE       HI: 4    |
|  [F] FEED ME     HI: 5    |
|  [M] MEMORY      LVL 3    |
|  [B] BUG CATCH   LVL 5    |
|  [R] RHYTHM      LVL 7    |
|                            |
|  STREAK: 2                 |
|                            |
|       [ CLOSE ]            |
+----------------------------+
```

Locked games show required level, grayed out.

---

## 6. Bottom Navigation

Replace current 3-button layout:

```
[ FEED ]  [ PLAY ]  [ FORAGE ]  [ ITEMS ]
   drumstick  gamepad   leaf      bag
```

- **FEED** — opens crafted food list. Tap to use. If empty, shows "Nothing to feed! Craft some food."
- **PLAY** — opens game selector (arcade)
- **FORAGE** — opens area selector or shows cooldown. Badge shows passive items to collect.
- **ITEMS** — opens inventory (ingredients tab + food/meds tab + crafting)

Each button: 40px pixel icon on top, label text below. Active button has accent color border.

---

## 7. Status Bars Rework

### Visual Changes

- **Height**: 22px (up from 14px)
- **Segmented**: 10 visible segments per bar (each = 10 stat points)
- **Icons**: Pixel art icons replace text labels
  - Hunger: drumstick icon (11x11)
  - Health: heart icon (11x11)
  - Happiness: star icon (11x11)
- **Value inside bar**: Right-aligned within the filled portion, white text
- **Color per segment**: Filled segments use the stat color. Individual segments darken slightly at borders for visual separation.
- **Stat colors** (uniform across all stats, replacing per-stat colors):
  - 70-100: green (#4ecca3)
  - 40-69: yellow (#f5a623)
  - 20-39: orange (#e07020) — **new color, add to GrubPalette as `orange`**
  - 0-19: red (#e94560), pulsing animation

### Status Effects

Status effects are temporary modifiers with expiration timestamps.

```swift
struct ActiveEffect: Codable {
    let type: EffectType
    let expiresAt: Date
}

enum EffectType: String, Codable {
    case overfed     // -5 happiness on application (instant, no duration)
    case poisoned    // health decay 2x faster
    case energized   // all decay 0.5x slower
}

// Stored as [ActiveEffect] in GameState, persisted as array of dicts
var activeEffects: [ActiveEffect] = []
```

**Effect details:**
- **Overfed** (hunger > 95 after feeding): instant -5 happiness, no lingering effect. Stomach icon flashes briefly. Threshold is 95 (not 90) to avoid punishing normal high-value recipes.
- **Poisoned** (from risky Deep Burrow forage, 20% chance): skull icon, health decay runs at 2x for 5 minutes. Stored with `expiresAt`. Checked in `applyDecay()`.
- **Energized** (from Moon Brew or Spore Elixir recipes): lightning icon, all decay runs at 0.5x for 30 minutes. Stored with `expiresAt`. Checked in `applyDecay()`.

Small 8x8 pixel icons appear to the right of the relevant stat bar when active. Expired effects are pruned on each decay tick.

---

## 8. Events Rework

Events now reward ingredients and recipe scrolls instead of flat stat bonuses.

### Updated Events

| Event | Option A | Option B |
|---|---|---|
| FOUND SOMETHING SHINY | KEEP IT: +1 Crystal Shard | TOSS IT: +10 happiness |
| STRANGE CREATURE | COMFORT: +1 Pale Worm | PLAY WITH IT: trigger minigame |
| ATE SOMETHING WEIRD | SPIT IT OUT: +1 Glowshroom | SWALLOW: 50% +1 Ancient Spore, 50% -10 health |
| CREATIVE MOOD | EXPLORE: +2 random uncommon ingredients | REST: +15 happiness |
| FOUND OLD SCROLL | STUDY IT: unlock random scroll-type recipe (cannot bypass level locks) | TRADE IT: +1 rare ingredient |
| RAIN IN THE CAVE | COLLECT DEW: +3 Dew Drop | TAKE SHELTER: +10 happiness, +5 health |

Events still grant 5 XP on resolution.

---

## 9. Economy Changes

### Removed
- **Crumbs as currency** — removed from the game entirely
- **Flat food costs** — no more "10 crumbs for a meal"
- **Medicine cooldown** — healing gated by ingredients instead

### Kept
- **Owner XP and levels** — same thresholds, same persistence across deaths
- **Evolution system** — same branches, same day triggers, fedCount now tracks crafted food used
- **Stat decay** — same rates, same night modifier, same floors

### New Tracking
- `forageCount` — total forages done (can influence feral evolution branch)
- `recipesFound` — total recipes unlocked
- `itemsCrafted` — total items crafted

### Death/Restart Behavior

On death and restart (`restartGame()`):

**Persists across deaths (progression):**
- Owner XP, owner level
- `unlockedRecipes` — recipes are knowledge, not perishable
- `highScores` — lifetime records
- `totalDeaths`
- `recipesFound`, `itemsCrafted` (lifetime stats)

**Resets on death (per-pet):**
- `ingredients` — cleared to empty
- `craftedItems` — cleared to empty
- `winStreak` — reset to 0
- `forageCount` — reset to 0
- `lastForageTime` — cleared (can forage immediately with new pet)
- `passiveGatherTime` — reset to now
- `activeEffects` — cleared
- All existing per-pet resets (hunger, happiness, health, age, evo, etc.)

### Save Migration

Existing saves missing new keys will use these defaults:
- `ingredients`: `{}` (empty)
- `craftedItems`: `{}` (empty)
- `unlockedRecipes`: `["moss_gruel", "bug_snack", "mud_paste"]` — **starter recipes are seeded by default**, not empty
- `highScores`: `{}` (empty)
- `winStreak`: `0`
- All other new keys: `0` or empty

The `load()` function already uses nil-coalescing, so this works naturally. The only special case is `unlockedRecipes` which must default to the 3 starter recipe IDs, not an empty set.

---

## 10. Persistence Changes

All new state saves to UserDefaults alongside existing data:

```swift
// Added to save/load dictionary:
"ingredients": [String: Int]
"craftedItems": [String: Int]
"unlockedRecipes": [String]
"lastForageTime": Double (timeIntervalSince1970)
"passiveGatherTime": Double
"highScores": [String: Int]
"winStreak": Int
"activeEffects": [[String: Any]]  // [{type: String, expiresAt: Double}]
"forageCount": Int
"recipesFound": Int
"itemsCrafted": Int
```

---

## 11. Top Bar Changes

With crumbs removed, the top bar changes:

```
LVL 3          GRUB_NAME          ITEMS: 12
  star            stats              bag
```

Right side shows total ingredient count instead of crumbs.

---

## 12. File Structure

---

## 13. Dynamic Background

The viewport background should feel alive and change based on time of day.

### Time States (4 phases, based on real device clock)

| Phase | Hours | Sky Color | Ground Color | Features |
|---|---|---|---|---|
| Dawn | 5AM-8AM | Deep blue → warm purple | Dark mossy | Orange/pink horizon glow at bottom of sky, spores fade in |
| Day | 8AM-6PM | Dark indigo/navy | Green-brown earth | Brightest spores, dripping water drops, mushroom caps slightly brighter |
| Dusk | 6PM-9PM | Purple → deep red-orange | Darkening moss | Warm glow on horizon, spores dim, sky bands shift to warm |
| Night | 9PM-5AM | Near-black | Very dark | Brighter stars, glowing spores pulse slowly, mushroom caps glow faintly, no drips |

### Animated Elements (driven by `animTick`)

All animations use `animTick` (already at 20fps) to avoid new timers:

1. **Floating spores** — drift slowly upward. Y position: `baseY - (animTick % cycleLength) * speed`. When they reach the top, wrap to bottom. Different spores have different speeds for parallax.

2. **Dripping water** (day/dawn/dusk only) — drops fall from stalactites. Each drip has a cycle: grow at stalactite tip → fall → splash. Use `animTick % dripCycle` to determine phase. 2-3 drip sources.

3. **Star twinkle** (night) — stars pulse opacity using `sin(animTick * twinkleSpeed)`. Each star has a different phase offset.

4. **Mushroom glow pulse** (night) — mushroom caps gently pulse brighter/dimmer using `sin(animTick * glowSpeed)`. Subtle — opacity varies 0.7-1.0.

5. **Ambient particles** — tiny pixel dots that drift horizontally across the screen, very slow. 3-4 particles. Gives a sense of air movement in the cave.

### Implementation

All animation is in `drawBackground()` which already receives `animTick` via the Canvas closure (it re-renders every tick). Add a `tick: Int` parameter to `drawBackground()`.

Compute `timePhase` from the device clock hour:
```swift
enum TimePhase { case dawn, day, dusk, night }
var timePhase: TimePhase {
    let hour = Calendar.current.component(.hour, from: Date())
    if hour >= 5 && hour < 8 { return .dawn }
    if hour >= 8 && hour < 18 { return .day }
    if hour >= 18 && hour < 21 { return .dusk }
    return .night
}
```

Color palettes per phase are defined as arrays — the sky banding loop picks colors based on `timePhase`.

### Modified Files
- `SpriteRenderer.swift` — rewrite `drawBackground()` to accept `tick` parameter, add time phases, animate spores/drips/stars/mushrooms
- `ContentView.swift` — pass `game.animTick` to `drawBackground()`

### Modified Files
- `GameState.swift` — core state: new @Published properties, reworked feed/medicine, save/load migration
- `ContentView.swift` — status bars rework, bottom nav 4-button layout, top bar changes
- `GameOverlays.swift` — reworked FeedOverlay (shows crafted food), reworked MinigameOverlay
- `SpriteRenderer.swift` — new PixelIcon methods for all 12 ingredients + new UI icons (heart, leaf, bag, drumstick)

### New Files (Swift extensions and overlay splits to keep files manageable)
- `GameState+Foraging.swift` — forage logic, passive gathering, loot tables, area selection
- `GameState+Crafting.swift` — recipe definitions, craft logic, recipe unlock checks
- `GameState+Minigames.swift` — extract existing minigame logic + add Memory, Bug Catch, Rhythm games
- `ForageOverlay.swift` — forage area selector overlay
- `InventoryOverlay.swift` — inventory screen (ingredients + food/meds tabs + crafting sub-screen)
- `GameSelectorOverlay.swift` — arcade game selector overlay
- `RecipeData.swift` — static recipe and ingredient definition data
