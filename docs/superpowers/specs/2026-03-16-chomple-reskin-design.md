# Chomple Reskin — Design Spec

**Date:** 2026-03-16
**Status:** Draft
**Author:** Jesse + Claude

## Overview

Reskin the Grub virtual pet game as "Chomple" — a goofy, toothy, Fuggler-inspired (but legally distinct) monster pet. This is the first of multiple planned reskins, so the architecture must support a shared game engine with swappable skins.

## Goals

1. Extract a reusable **PetEngine** Swift Package from GrubIOS
2. Refactor GrubIOS to be a thin skin on top of PetEngine (zero gameplay changes)
3. Build ChompleIOS as a second skin with new theme, character, content, and expanded adventures
4. Make adding future skins trivial (~5-6 files per new pet)

## Non-Goals

- Changing Grub's gameplay or content
- Adding multiplayer, IAP, or networking
- Redesigning the core game loop (forage → craft → feed → evolve stays)

---

## Architecture

### Project Structure

```
grub/
├── PetEngine/                        # Swift Package — shared game logic
│   ├── Sources/PetEngine/
│   │   ├── Core/
│   │   │   ├── GameState.swift
│   │   │   ├── GameState+Foraging.swift
│   │   │   ├── GameState+Crafting.swift
│   │   │   ├── GameState+Minigames.swift
│   │   │   ├── GameState+Personality.swift
│   │   │   ├── GameState+Journal.swift
│   │   │   ├── GameState+Burrow.swift
│   │   │   ├── GameState+Expeditions.swift
│   │   │   ├── GameState+Ads.swift
│   │   │   ├── AudioEngine.swift
│   │   │   ├── AdManager.swift
│   │   │   └── AdService.swift
│   │   ├── Protocols/
│   │   │   ├── ThemeProvider.swift
│   │   │   ├── ContentProvider.swift
│   │   │   └── SpriteProvider.swift
│   │   └── Views/
│   │       ├── RootView.swift
│   │       ├── ContentView.swift
│   │       ├── SplashView.swift
│   │       ├── GameOverlays.swift
│   │       ├── ForageOverlay.swift
│   │       ├── InventoryOverlay.swift
│   │       ├── BurrowOverlay.swift
│   │       ├── ExpeditionOverlay.swift
│   │       ├── GameSelectorOverlay.swift
│   │       ├── JournalOverlay.swift
│   │       └── SettingsMenuView.swift
│   └── Package.swift
│
├── GrubIOS/                          # Skin 1 — existing app (unchanged behavior)
│   ├── GrubIOSApp.swift
│   ├── GrubTheme.swift               # ThemeProvider — Swamp Candy palette
│   ├── GrubContent.swift             # ContentProvider — current RecipeData
│   ├── GrubSprite.swift              # SpriteProvider — current grub drawing
│   ├── AdConfig.swift
│   └── Assets.xcassets/
│
├── ChompleIOS/                       # Skin 2 — new app
│   ├── ChompleIOSApp.swift
│   ├── ChompleTheme.swift            # ThemeProvider — Hot Pink Chaos palette
│   ├── ChompleContent.swift          # ContentProvider — new ingredients, events, etc.
│   ├── ChompleSprite.swift           # SpriteProvider — toothy monster drawing
│   ├── AdConfig.swift
│   └── Assets.xcassets/
│
└── docs/
```

### Three Protocols

These define the boundary between the shared engine and each skin.

#### ThemeProvider

Maps 1:1 to the existing `GrubPalette` colors to ensure nothing is missed during extraction.

```swift
protocol ThemeProvider {
    // Palette — maps to current GrubPalette named colors
    var voidColor: Color { get }       // GrubPalette.void_color — main background
    var moss: Color { get }            // GrubPalette.moss — panels, overlays
    var deepMoss: Color { get }        // GrubPalette.deepMoss — borders, dividers
    var green: Color { get }           // GrubPalette.green — primary accent
    var pale: Color { get }            // GrubPalette.pale — primary text
    var red: Color { get }             // GrubPalette.red — critical/health
    var yellow: Color { get }          // GrubPalette.yellow — secondary accent
    var purple: Color { get }          // GrubPalette.purple — effects
    var white: Color { get }           // GrubPalette.white — highlights
    var moonpale: Color { get }        // GrubPalette.moonpale — muted text
    var dimGreen: Color { get }        // GrubPalette.dimGreen — dim accent
    var grey: Color { get }            // GrubPalette.grey — neutral
    var bone: Color { get }            // GrubPalette.bone — secondary neutral
    var nearBlack: Color { get }       // GrubPalette.nearBlack — true dark
    var orange: Color { get }          // GrubPalette.orange — tertiary accent

    // Full 14-color sprite palette map (Character → Color)
    var spritePalette: [Character: Color] { get }

    // Typography
    var fontName: String { get }

    // UI Strings
    var appName: String { get }
    var statNames: StatNames { get }       // hunger/happiness/health labels
    var buttonLabels: ButtonLabels { get } // feed/play/dig/pack labels

    // All other UI strings (banners, toasts, overlay text)
    var strings: UIStrings { get }
}

// Consolidates all hardcoded UI text
struct UIStrings {
    let dyingBanner: String          // "DYING!" vs "TANTRUM!"
    let healPrompt: String           // "HEAL HIM!" vs "CALM DOWN!"
    let nappingBanner: String        // "NAPPING" (same)
    let nightBanner: String          // "GRUB SLEEPS 10PM-6AM" vs "CHOMPLE SLEEPS..."
    let deathMessage: String         // "Grub has died" vs n/a
    let tantrumMessage: String?      // nil for Grub, "Chomple is having a meltdown!" for Chomple
    let tapToStart: String           // "TAP TO START" (same)
    // ... extensible for other hardcoded strings found during extraction
}
```

#### ContentProvider

Uses actual type names from the existing codebase (`IngredientDef`, `RecipeDef`, etc.).
`ForageArea` changes from an enum to a struct so skins can define arbitrary biomes.
`PersonalityTrait` changes from enum with computed description to data-driven.
Event actions use an `EventAction` enum instead of closures to decouple from `GameState`.

```swift
// ForageArea becomes a struct (was enum with 3 cases)
struct ForageAreaDef: Identifiable {
    let id: String
    let name: String
    let description: String
    let riskLevel: RiskLevel       // .none, .low, .medium, .high, .veryHigh
    let hungerCost: Int
    let cooldownSeconds: Int
    let poisonChance: Double       // 0.0–1.0
    let hpRiskChance: Double       // 0.0–1.0
    let hpRiskAmount: Int
}

// Event actions as enum instead of (GameState) -> Void closures
enum EventAction {
    case modifyStat(Stat, Int)             // .modifyStat(.happiness, +10)
    case addIngredient(String)             // .addIngredient("moss_clump")
    case addRandomIngredient(Rarity)       // .addRandomIngredient(.uncommon)
    case addXP(Int)
    case addCoins(Int)
    case openRandomGame
    case unlockRandomScrollRecipe
    case applyStatus(StatusEffect)
    case composite([EventAction])          // multiple actions
}

protocol ContentProvider {
    var ingredients: [String: IngredientDef] { get }
    var recipes: [String: RecipeDef] { get }
    var forageAreas: [ForageAreaDef] { get }
    var lootTables: [String: LootTable] { get }
    var gameEvents: [GameEvent] { get }         // uses EventAction, not closures
    var expeditions: [ExpeditionDef] { get }
    var decorations: [String: DecorationDef] { get }
    var journalEntries: [JournalEntry] { get }
    var personalityDescriptions: [String: String] { get }  // trait id → display name
    var evolutionNames: [String: String] { get }

    // Balance tuning
    var decayRates: DecayRates { get }           // hunger/happiness/health per minute
    var xpThresholds: [Int] { get }              // level-up XP requirements
    var deathBehavior: DeathBehavior { get }      // permanent death vs tantrum
}

struct DecayRates {
    let hungerPerMinute: Double    // default 0.1
    let happinessPerMinute: Double // default ~0.067
    let healthPerMinute: Double    // default 0.125
    let nightMultiplier: Double    // default 0.5
}
```

#### SpriteProvider

The existing `SpriteRenderer` has two layers: a generic pixel-grid renderer (`drawSprite(grid:)`)
that draws any `[[Character]]` array, and `makeGrubSprite()` which generates the grub-specific grid.
The generic renderer stays in PetEngine as a utility. Only the sprite-generation logic moves to skins.

```swift
protocol SpriteProvider {
    // Returns a 32x32 character grid for the current animation state
    // The engine's generic pixel-grid renderer draws it using theme.spritePalette
    func makeSpriteGrid(state: SpriteState, frame: Int) -> [[Character]]

    // Optional: custom background drawing (default is solid voidColor)
    func drawBackground(context: inout GraphicsContext,
                        size: CGSize,
                        theme: ThemeProvider)
}

// PetEngine keeps the generic renderer as a utility:
// SpriteRenderer.draw(grid: [[Character]], palette: [Character: Color], ...)
```

#### AudioProfile

Parameterizes the procedural synth engine per skin.

```swift
struct AudioProfile {
    let basePitch: Double          // multiplier on all tone frequencies (1.0 = Grub default)
    let noiseMix: Double           // 0.0–1.0, how much noise vs tone (higher = crunchier)
    let attackSpeed: Double        // envelope attack multiplier
    let decaySpeed: Double         // envelope decay multiplier
}
```

### How It Wires Together

Each app's entry point creates its providers and passes them to the shared RootView:

```swift
// ChompleIOSApp.swift
@main
struct ChompleIOSApp: App {
    let theme = ChompleTheme()
    let content = ChompleContent()
    let sprite = ChompleSprite()

    var body: some Scene {
        WindowGroup {
            RootView(theme: theme, content: content, sprite: sprite)
        }
    }
}
```

The engine views reference `theme.green` instead of `GrubPalette.green`, `content.ingredients` instead of hardcoded catalogs, and `sprite.makeSpriteGrid(...)` instead of `SpriteRenderer.makeGrubSprite()`.

### Key Migration Details

**GameState parameterization:** `GameState` currently reads global constants (`ingredientCatalog`, `recipeCatalog`, `lootTables`, etc.) and references `GrubPalette` directly. During extraction, `GameState.init()` takes a `ContentProvider` parameter. All global constant references become `content.ingredients`, `content.recipes`, etc. The `@StateObject` creation in `RootView` becomes `GameState(content: content)`.

**Event closures → EventAction enum:** The current `EventOption.action: (GameState) -> Void` closures are replaced with `EventAction` enum values. `GameState` gets an `apply(_ action: EventAction)` method that interprets the enum. This decouples event definitions from the concrete class.

**Ad injection:** `AdManager.shared` singleton is replaced with `AdManager(config:)` initialized per-skin. Each skin's `AdConfig.swift` provides its ad unit IDs. The `AdService` protocol remains unchanged.

**UserDefaults isolation:** Each skin is a separate app target with its own bundle ID, so `UserDefaults.standard` is automatically namespaced. No code changes needed.

---

## Chomple Skin Definition

### Character Design

Fuggler-inspired, legally distinct toothy monster:

- **Wide, square-ish torso** — shoulders wider than hips, trapezoidal silhouette
- **Big head blends into body** — no neck, head IS the top of the body
- **Big googly eyes** — yellow irises, black pupils, white highlights
- **Wide toothy grin** — 5-6 mismatched human-like teeth (signature feature)
- **Tuft of yellow/orange hair** on top
- **Lighter belly patch** — soft pink oval
- **Stubby arms** stick out from wide shoulders
- **Short legs** at the narrow bottom
- **Jagged pixel edges** to suggest fur (vs Grub's smooth bug shape)
- **32x32 pixel grid**, same as Grub

### Color Palette — "Hot Pink Chaos"

| Role | Hex | Use |
|------|-----|-----|
| BG (void) | `#1a0a1a` | Deep plum-black, main background |
| Panel | `#2a1030` | Dark purple, overlays & panels |
| Separator | `#3a1a40` | Medium purple, borders & dividers |
| Primary | `#E8368B` | Hot pink — monster body, main accent |
| Secondary | `#36E739` | Neon green — play button, secondary |
| Accent | `#DCC541` | Golden yellow — eyes, hair, warnings |
| Critical | `#E94560` | Red — low GRIT, danger states |
| Text | `#f0e8d0` | Warm cream — primary text |
| Dim text | `#a89880` | Muted tan — secondary text |

Full 14-color sprite palette extends the above with: lighter pink (belly), darker pink (shadow/fur detail), mouth interior dark, tooth white, orange (hair), purple (effects).

### UI Renaming

| Concept | Grub | Chomple |
|---------|------|---------|
| App name | GRUB | CHOMPLE |
| Stat 1 | Hunger | BELLY |
| Stat 2 | Happiness | MOOD |
| Stat 3 | Health | GRIT |
| Button 1 | FEED | CHOMP |
| Button 2 | PLAY | PLAY |
| Button 3 | DIG | ROAM |
| Button 4 | PACK | STASH |

### Tone

Lighter, goofier, comedic. Events are silly — Chomple finds a sock and eats it, gets spooked by a butterfly, tries to befriend a rock. No dark consequences. Comedy over drama.

---

## Expanded Adventures & Foraging

### Foraging: 3 → 8 Biomes

| Biome | Risk | Loot Flavor | Exclusive Items |
|-------|------|-------------|-----------------|
| Dumpster | None | Trash treasures | Soggy Fry, Lint Ball, Shiny Wrapper |
| Backyard | Low | Garden scraps | Dandelion, Mud Clump, Worm |
| Playground | Low | Lost & found | Sticky Candy, Lost Button, Crayon Stub |
| Sewer | Medium | Underground goods | Glowmoss, Rusty Coin, Pipe Gunk |
| Rooftops | Medium | Sky scavenging | Feather, Bird Egg, Antenna Wire |
| Haunted Shed | High | Spooky loot | Cobweb, Dusty Jar, Mystery Goo |
| Construction Site | High | Industrial salvage | Bolt, Tar Chunk, Rebar Shard |
| The Void | Very High | Rare weirdness | Void Crumb, Static Fuzz, Nothing |

### Branching Expeditions

Multi-step adventures with 2-3 decision points per expedition:

```
Start → Scene 1 (choice A/B) → Scene 2 (choice A/B) → Outcome + Loot
```

Different paths yield different loot tiers. 8 expeditions at launch:

1. **"The Sock Drawer"** — Chomple investigates a mysterious dresser
2. **"Sewer Safari"** — Navigate underground tunnels, befriend or flee from rats
3. **"Rooftop Rumble"** — Climb to the top, deal with pigeons and wind
4. **"Midnight Snack Run"** — Raid a kitchen at night, avoid the cat
5. **"The Yard Sale"** — Browse tables of junk, haggle with a raccoon
6. **"Haunted Basement"** — Spooky exploration, more funny than scary
7. **"Construction Chaos"** — Dodge machines, find industrial treasures
8. **"Void Picnic"** — Surreal adventure, nonsensical choices, best loot

Completing all 8 unlocks a secret 9th expedition. Tracked via a `completedExpeditions: Set<String>` on GameState; when count == 8, the 9th becomes visible in the expedition list.

**Cooldown:** 2 hours between expeditions.

#### Branching Expedition Data Model

The current `ExpeditionDef` is flat (duration + loot pool). For branching, we add a scene graph:

```swift
struct BranchingExpedition {
    let id: String
    let name: String
    let description: String
    let unlockLevel: Int
    let cooldownSeconds: Int
    let scenes: [String: ExpeditionScene]   // scene id → scene
    let startScene: String                   // id of first scene
}

struct ExpeditionScene {
    let narration: String                    // "You enter a dark tunnel..."
    let choices: [ExpeditionChoice]          // 2 options (A/B)
}

struct ExpeditionChoice {
    let label: String                        // "Befriend the rat" / "Run away"
    let nextScene: String?                   // nil = expedition ends
    let outcome: ExpeditionOutcome?          // nil if more scenes follow
}

struct ExpeditionOutcome {
    let narration: String                    // "The rat gives you a shiny coin!"
    let loot: [LootDrop]                     // items received
    let statEffects: [EventAction]           // stat changes
    let journalUnlock: String?               // journal entry id to unlock
}
```

Grub's existing flat expeditions still work — `ExpeditionDef` wraps into a single-scene `BranchingExpedition` with no choices. Both formats are supported via the `ContentProvider`.

### Recipes (rethemed, ~16 total)

Examples:
- **Trash Stew** (Soggy Fry + Mud Clump + Worm) → +30 BELLY
- **Lint Blanket** (Lint Ball + Cobweb + Feather) → +20 MOOD
- **Gunk Tonic** (Pipe Gunk + Mystery Goo + Glowmoss) → +25 GRIT
- **Void Snack** (Void Crumb + Static Fuzz + Nothing) → +15 all stats

Recipes scale from easy common-ingredient starters to rare multi-biome combinations.

---

## Evolution

Same mechanic (stage 1 at LV3, stage 2 at LV6), rethemed:

| Care Pattern | Stage 1 (LV3) | Stage 2 (LV6) |
|---|---|---|
| Fed (dominant chomp) | **CHONKY CHOMPLE** — wider, bigger belly | **MEGA CHOMPLE** — absolute unit |
| Played (dominant play) | **ZIPPY CHOMPLE** — leaner, bouncier | **TURBO CHOMPLE** — vibrating with energy |
| Feral (dominant roam) | **SCRAPPY CHOMPLE** — rougher fur, wilder eyes | **GREMLIN CHOMPLE** — chaotic, extra teeth |

Each evolution changes the sprite proportions and palette accents while keeping the core silhouette recognizable.

---

## Personality Traits (rethemed)

| Grub Trait | Chomple Name | Bonus (unchanged) |
|---|---|---|
| Scrappy | Dumpster Diver | Forage yields +50% |
| Cheerful | Class Clown | XP gain +50% |
| Hardy | Thick Skin | GRIT decay -30% |
| Curious | Nosy | Rare find chance +20% |
| Picky | Food Critic | Good food effects +50% |
| Lazy | Couch Blob | All decay -20% |
| Fierce | Brawler | Minigame rewards +1 |
| Gentle | Softie | Feeding gives +5 MOOD |

---

## Death → Tantrum (Chomple-only mechanic)

No permanent death. When GRIT hits 0:

1. Chomple throws a tantrum (flailing animation, ~30 seconds)
2. Falls asleep (greyed-out sprite, snoring SFX)
3. Wakes up after **1 hour** with 20 GRIT, 10 BELLY, 10 MOOD
4. Journal entry unlocked: "The Big Nap"

This is a **ContentProvider-level override** — Grub keeps its death mechanic, Chomple replaces it with the tantrum. The engine supports both via a `deathBehavior` enum on the content provider:

```swift
enum DeathBehavior {
    case permanentDeath(reviveWindowHours: Int)
    case tantrum(sleepDurationMinutes: Int, wakeStats: StatBlock)
}
```

---

## Audio

Same procedural synth engine (`AudioEngine`), parameterized per skin:

- **Chomple:** Higher pitched, goofier tones, squeakier voice
- **Chomp sounds:** Crunchier (more noise mix in the oscillator)
- **Adventure fanfare:** More playful/chaotic
- **Tantrum SFX:** Rapid escalating tones + noise burst → gentle snoring loop

Audio parameters exposed via ThemeProvider or a separate `AudioProfile` struct.

---

## Splash Screen

Same structure as Grub:
- Title: "CHOMPLE" in hot pink (#E8368B)
- Monster sprite (idle animation) instead of grub
- Loading bar in neon green (#36E739)
- "TAP TO START" in cream (#f0e8d0)
- Background: plum-black (#1a0a1a)

---

## Implementation Phases

### Phase 1: Extract PetEngine
- Pull all shared logic out of GrubIOS into PetEngine Swift Package
- Define ThemeProvider, ContentProvider, SpriteProvider protocols
- Refactor GrubIOS to implement the three protocols
- **Verification:** Grub must work identically after extraction (zero gameplay changes)

### Phase 2: Build Chomple Skin
- Create ChompleIOS Xcode target
- Implement ChompleTheme (Hot Pink Chaos palette)
- Implement ChompleSprite (toothy monster, 32x32 pixel art)
- Implement ChompleContent (8 biomes, 8 expeditions, 16 recipes, events, journal)
- Wire up AdConfig with new ad unit IDs

### Phase 3: Expand Adventures
- Add branching expedition system to PetEngine (benefits both skins)
- Implement 8 Chomple expeditions with branching narratives
- Add tantrum/death behavior abstraction
- Add 5 new biomes to foraging system

### Phase 4: Polish & Ship
- Audio parameter tuning for Chomple voice
- App icon and App Store assets
- App Store listing (screenshots, description, preview video)
- Support/privacy pages on existing GitHub Pages site

---

## Resolved Decisions

1. **AdMob:** Each skin gets its own AdMob app ID (separate is safer for policy).
2. **Font:** Keep PressStart2P for Chomple (consistent retro feel across all skins).
3. **Minigames:** Same 5 games, same mechanics, rethemed visuals only (button labels via ThemeProvider). New minigames can be added to PetEngine later and benefit all skins.

---

## Success Criteria

- [ ] Grub works identically after PetEngine extraction (regression test)
- [ ] Chomple builds and runs as a separate app target
- [ ] All 8 biomes, 8 expeditions, and 16 recipes functional
- [ ] Tantrum mechanic works instead of death
- [ ] Branching expeditions have 2-3 decision points each
- [ ] Adding a third skin requires only ~5-6 new files
