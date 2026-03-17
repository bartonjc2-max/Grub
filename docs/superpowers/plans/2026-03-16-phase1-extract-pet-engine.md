# Phase 1: Extract PetEngine — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract shared game logic from GrubIOS into a reusable PetEngine Swift Package, then refactor GrubIOS as a thin skin on top. Grub must work identically after extraction.

**Architecture:** Three protocols (ThemeProvider, ContentProvider, SpriteProvider) define the skin boundary. PetEngine contains all game logic, views, and utilities. Each skin app (~6 files) implements the protocols and injects them into PetEngine's RootView. The PetEngine package lives at `/Users/jessedev/Documents/Code/PetEngine/` as its own repo. Each skin app (Grub, Chomple, etc.) lives in its own folder under `/Users/jessedev/Documents/Code/`.

**Tech Stack:** Swift, SwiftUI, SPM (Swift Package Manager), GoogleMobileAds

**CRITICAL RULE — Phase 1:** Preserve ALL existing types from RecipeData.swift and GameState.swift EXACTLY as-is. Just make them `public`. Do NOT rename fields, change associated values, or simplify structures. The types in Task 3 below are idealized — the implementing agent MUST use the actual types from the codebase instead:
- `RecipeIngredient` (not `[String: Int]`)
- `StatEffects` (not `RecipeEffect`)
- `UnlockType` with `.level(Int)` associated value (not `RecipeUnlockType`)
- `RecipeDef` with `grantsEnergized: Bool` field
- `LootTable` with ALL fields: `riskChance`, `riskStatType`, `riskAmount`, `riskMessage`, `itemCount`, `specialPool`, `excludePool`, and `rollRarity()` method
- `DecorationDef` with `ingredients: [RecipeIngredient]` and `bonusType: DecorationBonus`
- `DecorationBonus` enum (8 cases: healthDecay, happinessDecay, hungerDecay, forageLuck, xpBoost, passiveGather, eventChance, minigameBonus)
- `ExpeditionDef` with `lootPool: [(id: String, weight: Double)]`, `lootCount`, `riskMessage`, `xpReward`, `bonusRareChance`
- `EffectType` enum, `ActiveEffect` struct, `BugState` struct
- `PersonalityTrait` enum (keep as enum, add display name via ContentProvider)
- `JournalEntry` with `unlockCondition: JournalUnlock`
- `JournalUnlock` enum with `.trait(PersonalityTrait)` case
- `ForageArea` — keep as enum for Phase 1; convert to struct in Phase 2 when adding new biomes
- All `Codable` conformances must be preserved for save/load compatibility
- GameState stats (`hunger`, `happiness`, `health`) are `Int`, not `Double`

The `EventAction` enum conversion and `ForageArea` struct migration happen in Phase 2, not Phase 1. Phase 1 keeps closures and the enum as-is to guarantee zero behavior change.

**Additional corrections:**
- `SpriteState` enum: GameState uses `String` for `petStateAnim`. Phase 1 keeps it as `String`. The `SpriteProvider` protocol takes `String` state, not `SpriteState` enum.
- iOS deployment target: `.iOS(.v17)` (not `.v16`)
- No `@_exported import` — each file imports what it needs
- Theme threading: use `@Environment` with a non-optional key (fatalError if not injected)

**Directory Layout:**
```
/Users/jessedev/Documents/Code/
├── PetEngine/                    # Swift Package (new repo)
│   ├── Package.swift
│   └── Sources/PetEngine/
│       ├── Protocols/            # ThemeProvider, ContentProvider, SpriteProvider
│       ├── Core/                 # GameState, extensions, AudioEngine
│       ├── Views/                # All shared SwiftUI views
│       └── Rendering/            # SpriteRenderer utilities, ScanlineOverlay
├── grub/                         # Existing Grub repo
│   └── GrubIOS/                  # Grub skin (depends on PetEngine via local path)
│       ├── GrubTheme.swift
│       ├── GrubContent.swift
│       ├── GrubSprite.swift
│       └── ...
├── chomple/                      # Future Chomple skin
├── blobbo/                       # Future Blobbo skin
└── ...                           # Other skins
```

---

## Chunk 1: Create PetEngine Package & Define Protocols

### Task 1: Initialize PetEngine Swift Package

**Files:**
- Create: `/Users/jessedev/Documents/Code/PetEngine/Package.swift`
- Create: `/Users/jessedev/Documents/Code/PetEngine/Sources/PetEngine/PetEngine.swift`

- [ ] **Step 1: Create PetEngine directory and initialize SPM package**

```bash
mkdir -p /Users/jessedev/Documents/Code/PetEngine
cd /Users/jessedev/Documents/Code/PetEngine
swift package init --name PetEngine --type library
```

- [ ] **Step 2: Update Package.swift with platform requirements**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PetEngine",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "PetEngine", targets: ["PetEngine"]),
    ],
    targets: [
        .target(name: "PetEngine"),
        .testTarget(name: "PetEngineTests", dependencies: ["PetEngine"]),
    ]
)
```

- [ ] **Step 3: Create subdirectory structure**

```bash
cd /Users/jessedev/Documents/Code/PetEngine/Sources/PetEngine
mkdir -p Protocols Core Views Rendering
```

- [ ] **Step 4: Verify package builds**

```bash
cd /Users/jessedev/Documents/Code/PetEngine
swift build
```
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Initialize git repo and commit**

```bash
cd /Users/jessedev/Documents/Code/PetEngine
git init
git add .
git commit -m "Initialize PetEngine Swift Package"
```

---

### Task 2: Define ThemeProvider Protocol

**Files:**
- Create: `/Users/jessedev/Documents/Code/PetEngine/Sources/PetEngine/Protocols/ThemeProvider.swift`

- [ ] **Step 1: Create ThemeProvider with all 15 palette colors matching GrubPalette**

```swift
import SwiftUI

// Maps 1:1 to GrubPalette's 15 named colors.
// Every skin must provide all 15 — no optional colors.
public protocol ThemeProvider: AnyObject {
    // Palette — original GrubPalette names preserved for easy migration
    var voidColor: Color { get }       // main background
    var moss: Color { get }            // panels, overlays
    var deepMoss: Color { get }        // borders, dividers
    var green: Color { get }           // primary accent
    var pale: Color { get }            // primary text
    var red: Color { get }             // critical/health
    var yellow: Color { get }          // secondary accent
    var purple: Color { get }          // effects
    var white: Color { get }           // highlights
    var moonpale: Color { get }        // muted text
    var dimGreen: Color { get }        // dim accent
    var grey: Color { get }            // neutral
    var bone: Color { get }            // secondary neutral
    var nearBlack: Color { get }       // true dark
    var orange: Color { get }          // tertiary accent

    // Sprite palette map: character → color for pixel grid rendering
    var spritePalette: [Character: Color] { get }

    // Typography
    var fontName: String { get }

    // UI Strings
    var appName: String { get }
    var statLabels: StatLabels { get }
    var buttonLabels: ButtonLabels { get }
    var uiStrings: UIStrings { get }
}

public struct StatLabels {
    public let hunger: String      // "HNG" or "BLY"
    public let happiness: String   // "HAP" or "MOD"
    public let health: String      // "HP" or "GRT"

    public init(hunger: String, happiness: String, health: String) {
        self.hunger = hunger
        self.happiness = happiness
        self.health = health
    }
}

public struct ButtonLabels {
    public let feed: String        // "FEED" or "CHOMP"
    public let play: String        // "PLAY"
    public let dig: String         // "DIG" or "ROAM"
    public let pack: String        // "PACK" or "STASH"

    public init(feed: String, play: String, dig: String, pack: String) {
        self.feed = feed
        self.play = play
        self.dig = dig
        self.pack = pack
    }
}

public struct UIStrings {
    public let dyingBanner: String
    public let healPrompt: String
    public let nappingBanner: String
    public let nightBanner: String
    public let deathMessage: String
    public let tapToStart: String
    public let overfedWarning: String
    public let tooHungryWarning: String
    public let inventoryFullWarning: String
    public let cooldownPrefix: String
    public let foundSomething: String
    public let exploring: String
    public let adoptNew: String

    public init(
        dyingBanner: String, healPrompt: String, nappingBanner: String,
        nightBanner: String, deathMessage: String, tapToStart: String,
        overfedWarning: String, tooHungryWarning: String,
        inventoryFullWarning: String, cooldownPrefix: String,
        foundSomething: String, exploring: String, adoptNew: String
    ) {
        self.dyingBanner = dyingBanner
        self.healPrompt = healPrompt
        self.nappingBanner = nappingBanner
        self.nightBanner = nightBanner
        self.deathMessage = deathMessage
        self.tapToStart = tapToStart
        self.overfedWarning = overfedWarning
        self.tooHungryWarning = tooHungryWarning
        self.inventoryFullWarning = inventoryFullWarning
        self.cooldownPrefix = cooldownPrefix
        self.foundSomething = foundSomething
        self.exploring = exploring
        self.adoptNew = adoptNew
    }
}
```

- [ ] **Step 2: Verify build**

```bash
cd /Users/jessedev/Documents/Code/PetEngine && swift build
```
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add . && git commit -m "feat: add ThemeProvider protocol with all palette colors and UI strings"
```

---

### Task 3: Define ContentProvider Protocol

**Files:**
- Create: `/Users/jessedev/Documents/Code/PetEngine/Sources/PetEngine/Protocols/ContentProvider.swift`

- [ ] **Step 1: Create data types and ContentProvider protocol**

All types use actual names from the existing codebase (`IngredientDef`, `RecipeDef`, etc.) with `ForageArea` changed from enum to struct for extensibility. Event closures replaced with `EventAction` enum.

```swift
import Foundation

// MARK: - Rarity

public enum Rarity: String, Codable, CaseIterable, Sendable {
    case common, uncommon, rare
}

// MARK: - Ingredient

public struct IngredientDef: Sendable {
    public let id: String
    public let name: String
    public let rarity: Rarity

    public init(id: String, name: String, rarity: Rarity) {
        self.id = id; self.name = name; self.rarity = rarity
    }
}

// MARK: - Recipe

public enum RecipeUnlockType: String, Codable, Sendable {
    case starter, level, scroll
}

public struct RecipeEffect: Sendable {
    public let hunger: Int
    public let happiness: Int
    public let health: Int

    public init(hunger: Int, happiness: Int, health: Int) {
        self.hunger = hunger; self.happiness = happiness; self.health = health
    }
}

public struct RecipeDef: Sendable {
    public let id: String
    public let name: String
    public let ingredients: [String: Int]   // ingredient id → count
    public let effects: RecipeEffect
    public let unlockType: RecipeUnlockType
    public let unlockLevel: Int             // 0 if not level-gated

    public init(id: String, name: String, ingredients: [String: Int],
                effects: RecipeEffect, unlockType: RecipeUnlockType, unlockLevel: Int) {
        self.id = id; self.name = name; self.ingredients = ingredients
        self.effects = effects; self.unlockType = unlockType; self.unlockLevel = unlockLevel
    }
}

// MARK: - Forage Area (struct, not enum — supports arbitrary biomes)

public enum RiskLevel: String, Sendable {
    case none, low, medium, high, veryHigh
}

public struct ForageAreaDef: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let riskLevel: RiskLevel
    public let hungerCost: Int
    public let cooldownSeconds: Int
    public let poisonChance: Double
    public let hpRiskChance: Double
    public let hpRiskAmount: Int

    public init(id: String, name: String, description: String, riskLevel: RiskLevel,
                hungerCost: Int, cooldownSeconds: Int, poisonChance: Double,
                hpRiskChance: Double, hpRiskAmount: Int) {
        self.id = id; self.name = name; self.description = description
        self.riskLevel = riskLevel; self.hungerCost = hungerCost
        self.cooldownSeconds = cooldownSeconds; self.poisonChance = poisonChance
        self.hpRiskChance = hpRiskChance; self.hpRiskAmount = hpRiskAmount
    }
}

// MARK: - Loot Table

public struct LootTable: Sendable {
    public let commonWeight: Double
    public let uncommonWeight: Double
    public let rareWeight: Double
    public let exclusiveItems: [String]     // ingredient IDs only found here

    public init(commonWeight: Double, uncommonWeight: Double, rareWeight: Double,
                exclusiveItems: [String] = []) {
        self.commonWeight = commonWeight; self.uncommonWeight = uncommonWeight
        self.rareWeight = rareWeight; self.exclusiveItems = exclusiveItems
    }
}

// MARK: - Event Action (replaces closures)

public enum Stat: String, Sendable {
    case hunger, happiness, health
}

public enum StatusEffect: String, Sendable {
    case energized, poisoned
}

public indirect enum EventAction: Sendable {
    case modifyStat(Stat, Int)
    case addIngredient(String)
    case addRandomIngredient(Rarity)
    case addXP(Int)
    case addCoins(Int)
    case openRandomGame
    case unlockRandomScrollRecipe
    case applyStatus(StatusEffect)
    case displayToast(String)
    case composite([EventAction])
}

// MARK: - Game Event

public struct EventOption: Sendable {
    public let label: String
    public let action: EventAction

    public init(label: String, action: EventAction) {
        self.label = label; self.action = action
    }
}

public struct GameEvent: Sendable {
    public let text: String
    public let optionA: EventOption
    public let optionB: EventOption

    public init(text: String, optionA: EventOption, optionB: EventOption) {
        self.text = text; self.optionA = optionA; self.optionB = optionB
    }
}

// MARK: - Decoration

public enum DecorationSlot: String, Codable, Sendable {
    case floor, wall, ceiling, corner
}

public struct DecorationDef: Sendable {
    public let id: String
    public let name: String
    public let slot: DecorationSlot
    public let cost: [String: Int]          // ingredient id → count
    public let happinessBonus: Int
    public let healthBonus: Int

    public init(id: String, name: String, slot: DecorationSlot, cost: [String: Int],
                happinessBonus: Int, healthBonus: Int) {
        self.id = id; self.name = name; self.slot = slot; self.cost = cost
        self.happinessBonus = happinessBonus; self.healthBonus = healthBonus
    }
}

// MARK: - Expedition

public struct ExpeditionDef: Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let durationMinutes: Int
    public let unlockLevel: Int
    public let lootPool: [String]           // ingredient IDs
    public let riskChance: Double
    public let riskDamage: Int

    public init(id: String, name: String, description: String, durationMinutes: Int,
                unlockLevel: Int, lootPool: [String], riskChance: Double, riskDamage: Int) {
        self.id = id; self.name = name; self.description = description
        self.durationMinutes = durationMinutes; self.unlockLevel = unlockLevel
        self.lootPool = lootPool; self.riskChance = riskChance; self.riskDamage = riskDamage
    }
}

// MARK: - Journal

public struct JournalEntry: Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let condition: JournalCondition

    public init(id: String, title: String, description: String, condition: JournalCondition) {
        self.id = id; self.title = title; self.description = description; self.condition = condition
    }
}

public enum JournalCondition: Sendable {
    case statReached(Stat, Int)
    case levelReached(Int)
    case recipeCrafted(String)
    case traitUnlocked(String)
    case custom(String)                     // checked by ID in GameState
}

// MARK: - Personality

public struct PersonalityDef: Sendable {
    public let id: String
    public let name: String
    public let description: String

    public init(id: String, name: String, description: String) {
        self.id = id; self.name = name; self.description = description
    }
}

// MARK: - Decay / Balance

public struct DecayRates: Sendable {
    public let hungerPerMinute: Double
    public let happinessPerMinute: Double
    public let healthPerMinute: Double
    public let nightMultiplier: Double
    public let criticalThreshold: Double

    public init(hungerPerMinute: Double = 1.0/10.0, happinessPerMinute: Double = 1.0/15.0,
                healthPerMinute: Double = 1.0/8.0, nightMultiplier: Double = 0.5,
                criticalThreshold: Double = 20) {
        self.hungerPerMinute = hungerPerMinute; self.happinessPerMinute = happinessPerMinute
        self.healthPerMinute = healthPerMinute; self.nightMultiplier = nightMultiplier
        self.criticalThreshold = criticalThreshold
    }
}

// MARK: - Death Behavior

public struct WakeStats: Sendable {
    public let hunger: Double
    public let happiness: Double
    public let health: Double

    public init(hunger: Double, happiness: Double, health: Double) {
        self.hunger = hunger; self.happiness = happiness; self.health = health
    }
}

public enum DeathBehavior: Sendable {
    case permanentDeath(reviveWindowHours: Int)
    case tantrum(sleepDurationMinutes: Int, wakeStats: WakeStats)
}

// MARK: - ContentProvider Protocol

public protocol ContentProvider: AnyObject {
    var ingredients: [String: IngredientDef] { get }
    var recipes: [String: RecipeDef] { get }
    var forageAreas: [ForageAreaDef] { get }
    var lootTables: [String: LootTable] { get }     // keyed by ForageAreaDef.id
    var gameEvents: [GameEvent] { get }
    var expeditions: [ExpeditionDef] { get }
    var decorations: [String: DecorationDef] { get }
    var journalEntries: [JournalEntry] { get }
    var personalities: [PersonalityDef] { get }
    var evolutionNames: [String: String] { get }

    // Derived convenience (default implementations provided)
    var starterRecipeIds: Set<String> { get }
    var scrollRecipeIds: [String] { get }
    var commonIngredients: [String] { get }
    var uncommonIngredients: [String] { get }
    var rareIngredients: [String] { get }

    // Balance
    var decayRates: DecayRates { get }
    var xpThresholds: [Int] { get }
    var deathBehavior: DeathBehavior { get }
}

// MARK: - Default Implementations

public extension ContentProvider {
    var starterRecipeIds: Set<String> {
        Set(recipes.values.filter { $0.unlockType == .starter }.map(\.id))
    }

    var scrollRecipeIds: [String] {
        recipes.values.filter { $0.unlockType == .scroll }.map(\.id)
    }

    var commonIngredients: [String] {
        ingredients.values.filter { $0.rarity == .common }.map(\.id)
    }

    var uncommonIngredients: [String] {
        ingredients.values.filter { $0.rarity == .uncommon }.map(\.id)
    }

    var rareIngredients: [String] {
        ingredients.values.filter { $0.rarity == .rare }.map(\.id)
    }
}
```

- [ ] **Step 2: Verify build**

```bash
cd /Users/jessedev/Documents/Code/PetEngine && swift build
```
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add . && git commit -m "feat: add ContentProvider protocol with all game data types"
```

---

### Task 4: Define SpriteProvider Protocol & AudioProfile

**Files:**
- Create: `/Users/jessedev/Documents/Code/PetEngine/Sources/PetEngine/Protocols/SpriteProvider.swift`

- [ ] **Step 1: Create SpriteProvider and AudioProfile**

```swift
import SwiftUI

// MARK: - Sprite State

public enum SpriteState: String, Sendable {
    case idle, sleeping, eating, drinking, dead, dying
    case hungry, unhappy, angry, energized, sick, starving, playing
    case tapJump = "tap_jump"
    case tapWave = "tap_wave"
    case tapSpin = "tap_spin"
    case tapNuzzle = "tap_nuzzle"
    case tapChirp = "tap_chirp"
    case tapPeek = "tap_peek"
    case tapBounce = "tap_bounce"
    case tapHungry = "tap_hungry"
    case tapGrumpy = "tap_grumpy"
    case tapSick = "tap_sick"
}

// MARK: - SpriteProvider

public protocol SpriteProvider: AnyObject {
    /// Returns a 32x32 character grid for the current animation state.
    /// The engine's generic pixel-grid renderer draws it using theme.spritePalette.
    func makeSpriteGrid(state: SpriteState, frame: Int) -> [[Character]]

    /// Draw the background scene behind the pet.
    /// Default: solid voidColor fill.
    func drawBackground(context: inout GraphicsContext, size: CGSize,
                        frame: Int, theme: any ThemeProvider)
}

// Default background implementation
public extension SpriteProvider {
    func drawBackground(context: inout GraphicsContext, size: CGSize,
                        frame: Int, theme: any ThemeProvider) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(theme.voidColor))
    }
}

// MARK: - Audio Profile

public struct AudioProfile: Sendable {
    public let basePitch: Double        // multiplier on tone frequencies (1.0 = default)
    public let noiseMix: Double         // 0.0–1.0, higher = crunchier
    public let attackSpeed: Double      // envelope attack multiplier
    public let decaySpeed: Double       // envelope decay multiplier

    public init(basePitch: Double = 1.0, noiseMix: Double = 0.3,
                attackSpeed: Double = 1.0, decaySpeed: Double = 1.0) {
        self.basePitch = basePitch; self.noiseMix = noiseMix
        self.attackSpeed = attackSpeed; self.decaySpeed = decaySpeed
    }
}
```

- [ ] **Step 2: Verify build**

```bash
cd /Users/jessedev/Documents/Code/PetEngine && swift build
```
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add . && git commit -m "feat: add SpriteProvider protocol and AudioProfile"
```

---

### Task 5: Create PetEngine public entry point and re-export types

**Files:**
- Modify: `/Users/jessedev/Documents/Code/PetEngine/Sources/PetEngine/PetEngine.swift`

- [ ] **Step 1: Replace placeholder with public re-exports**

```swift
// PetEngine — Shared game engine for virtual pet apps
// All public types are exported from protocol files.
// This file ensures the module has a valid entry point.

// Re-export Foundation for consumers
@_exported import Foundation
```

- [ ] **Step 2: Verify build, run any generated tests**

```bash
cd /Users/jessedev/Documents/Code/PetEngine
swift build && swift test
```
Expected: BUILD SUCCEEDED, tests pass (placeholder test)

- [ ] **Step 3: Commit**

```bash
git add . && git commit -m "feat: finalize PetEngine module entry point"
```

---

## Chunk 2: Move Core Game Logic to PetEngine

### Task 6: Move Color extension and SpriteRenderer utilities to PetEngine

**Files:**
- Create: `/Users/jessedev/Documents/Code/PetEngine/Sources/PetEngine/Rendering/ColorExtension.swift`
- Create: `/Users/jessedev/Documents/Code/PetEngine/Sources/PetEngine/Rendering/PixelRenderer.swift`
- Create: `/Users/jessedev/Documents/Code/PetEngine/Sources/PetEngine/Rendering/ScanlineOverlay.swift`
- Source: `/Users/jessedev/Documents/Code/grub/GrubIOS/GrubIOS/SpriteRenderer.swift`

These are the engine-level utilities that every skin uses. The grub-specific sprite drawing (`makeGrubSprite`) stays in GrubIOS.

- [ ] **Step 1: Copy `Color(hex:)` extension to PetEngine**

Read the Color extension from SpriteRenderer.swift (around line 48-70) and copy it to ColorExtension.swift. Make it `public`.

- [ ] **Step 2: Copy generic `drawSprite(context:sprite:origin:scale:)` to PixelRenderer.swift**

This is the method that takes a `[[Character]]` grid and renders it pixel-by-pixel using a palette map. It's engine-level code, not skin-specific. Make it a public static method on a `PixelRenderer` struct. It takes the palette from ThemeProvider.

```swift
import SwiftUI

public struct PixelRenderer {
    public static func drawSprite(
        context: inout GraphicsContext,
        sprite: [[Character]],
        palette: [Character: Color],
        origin: CGPoint,
        scale: CGFloat
    ) {
        // Copy the existing drawSprite logic from SpriteRenderer.swift
        // Replace GrubPalette.paletteMap with the palette parameter
    }
}
```

- [ ] **Step 3: Copy ScanlineOverlay to PetEngine**

Copy the `ScanlineOverlay` view. Make it `public`.

- [ ] **Step 4: Copy PixelIcon to PetEngine**

Copy the `PixelIcon` struct with all static icon methods. Make everything `public`. These are generic game icons (star, coin, heart, etc.) used by the engine views.

- [ ] **Step 5: Verify build**

```bash
cd /Users/jessedev/Documents/Code/PetEngine && swift build
```

- [ ] **Step 6: Commit**

```bash
git add . && git commit -m "feat: add PixelRenderer, ScanlineOverlay, PixelIcon, and Color extension"
```

---

### Task 7: Move AudioEngine to PetEngine

**Files:**
- Create: `/Users/jessedev/Documents/Code/PetEngine/Sources/PetEngine/Core/AudioEngine.swift`
- Source: `/Users/jessedev/Documents/Code/grub/GrubIOS/GrubIOS/AudioEngine.swift`

- [ ] **Step 1: Copy AudioEngine.swift to PetEngine**

Copy the file. Make the class and its methods `public`. Add an `audioProfile: AudioProfile` property that multiplies tone frequencies by `basePitch`, mixes noise by `noiseMix`, etc. Default to `AudioProfile()` for backwards compatibility.

- [ ] **Step 2: Parameterize tone generation**

In the `playTone` or equivalent method, multiply frequency by `audioProfile.basePitch` and adjust noise mix level by `audioProfile.noiseMix`. This is a small change — just wrap existing parameters.

- [ ] **Step 3: Verify build**

```bash
cd /Users/jessedev/Documents/Code/PetEngine && swift build
```

- [ ] **Step 4: Commit**

```bash
git add . && git commit -m "feat: add AudioEngine with configurable AudioProfile"
```

---

### Task 8: Move AdService protocol to PetEngine

**Files:**
- Create: `/Users/jessedev/Documents/Code/PetEngine/Sources/PetEngine/Core/AdService.swift`
- Source: `/Users/jessedev/Documents/Code/grub/GrubIOS/GrubIOS/AdService.swift`

- [ ] **Step 1: Copy AdService.swift to PetEngine**

Copy the protocol definition. Make it `public`. This is the interface — each skin provides its own `AdManager` implementation with its own ad unit IDs.

Note: `AdManager.swift` and `AdConfig.swift` stay in each skin app because they depend on GoogleMobileAds (which PetEngine should NOT depend on to keep it lightweight).

- [ ] **Step 2: Verify build**

```bash
cd /Users/jessedev/Documents/Code/PetEngine && swift build
```

- [ ] **Step 3: Commit**

```bash
git add . && git commit -m "feat: add AdService protocol"
```

---

### Task 9: Move GameState to PetEngine (the big one)

**Files:**
- Create: `/Users/jessedev/Documents/Code/PetEngine/Sources/PetEngine/Core/GameState.swift`
- Create: `/Users/jessedev/Documents/Code/PetEngine/Sources/PetEngine/Core/GameState+Foraging.swift`
- Create: `/Users/jessedev/Documents/Code/PetEngine/Sources/PetEngine/Core/GameState+Crafting.swift`
- Create: `/Users/jessedev/Documents/Code/PetEngine/Sources/PetEngine/Core/GameState+Minigames.swift`
- Create: `/Users/jessedev/Documents/Code/PetEngine/Sources/PetEngine/Core/GameState+Personality.swift`
- Create: `/Users/jessedev/Documents/Code/PetEngine/Sources/PetEngine/Core/GameState+Journal.swift`
- Create: `/Users/jessedev/Documents/Code/PetEngine/Sources/PetEngine/Core/GameState+Burrow.swift`
- Create: `/Users/jessedev/Documents/Code/PetEngine/Sources/PetEngine/Core/GameState+Expeditions.swift`
- Create: `/Users/jessedev/Documents/Code/PetEngine/Sources/PetEngine/Core/GameState+Ads.swift`

This is the largest task. GameState must be parameterized to use ContentProvider instead of global constants.

- [ ] **Step 1: Copy GameState.swift to PetEngine**

Make the class `public`. Add a `content: any ContentProvider` property. Change `init()` to `init(content: any ContentProvider, adService: (any AdService)? = nil)`.

- [ ] **Step 2: Replace all global constant references with content provider**

Search and replace in GameState.swift:
- `DecayConstants.hungerPerMin` → `content.decayRates.hungerPerMinute`
- `DecayConstants.happinessPerMin` → `content.decayRates.happinessPerMinute`
- `DecayConstants.healthPerMin` → `content.decayRates.healthPerMinute`
- `DecayConstants.nightMult` → `content.decayRates.nightMultiplier`
- `DecayConstants.critThresh` → `content.decayRates.criticalThreshold`
- `xpThresholds` → `content.xpThresholds`
- `evoNames` → `content.evolutionNames`
- `starterRecipeIds` → `content.starterRecipeIds`
- `AdManager.shared` → `adService` (injected parameter)

- [ ] **Step 3: Convert event closures to EventAction**

Replace all `gameEvents` definitions. Instead of:
```swift
EventOption(label: "KEEP IT\n+1 CRYSTAL SHARD", action: { s in s.addIngredient("crystal_shard") })
```
Use:
```swift
EventOption(label: "KEEP IT\n+1 CRYSTAL SHARD", action: .addIngredient("crystal_shard"))
```

Add an `apply(_ action: EventAction)` method to GameState:
```swift
public func apply(_ action: EventAction) {
    switch action {
    case .modifyStat(let stat, let amount):
        switch stat {
        case .hunger: hunger = min(100, max(0, hunger + Double(amount)))
        case .happiness: happiness = min(100, max(0, happiness + Double(amount)))
        case .health: health = min(100, max(0, health + Double(amount)))
        }
    case .addIngredient(let id): addIngredient(id)
    case .addRandomIngredient(let rarity): addRandomIngredient(rarity)
    case .addXP(let xp): addXP(xp)
    case .addCoins(let n): coins += n
    case .openRandomGame: openRandomGame()
    case .unlockRandomScrollRecipe: unlockRandomScrollRecipe()
    case .applyStatus(let effect):
        switch effect {
        case .energized: applyEnergized()
        case .poisoned: applyPoisoned()
        }
    case .displayToast(let msg): displayToast(msg)
    case .composite(let actions): actions.forEach { apply($0) }
    }
}
```

Move `gameEvents` from GameState to ContentProvider — each skin defines its own events.

- [ ] **Step 4: Copy all GameState extensions to PetEngine**

For each extension file:
- Make methods `public`
- Replace `ingredientCatalog` → `content.ingredients`
- Replace `recipeCatalog` → `content.recipes`
- Replace `lootTables[area]` → `content.lootTables[area.id]` (ForageArea is now a struct — use the area's `id` as the lookup key)
- Replace `decorationCatalog` → `content.decorations`
- Replace `expeditionCatalog` → `content.expeditions` (adjust to array lookup)
- Replace `journalEntries` → `content.journalEntries`
- Replace `commonIngredients` → `content.commonIngredients`
- Replace `uncommonIngredients` → `content.uncommonIngredients`
- Replace `rareIngredients` → `content.rareIngredients`
- Replace `scrollRecipeIds` → `content.scrollRecipeIds`

- [ ] **Step 5: Handle ForageArea enum → struct migration in GameState+Foraging**

The current code uses `ForageArea` enum cases in switch statements:
```swift
if area == .deepBurrow { ... }
if area == .surface { ... }
```

Replace with ID-based checks:
```swift
if area.poisonChance > 0 && Double.random(in: 0...1) < area.poisonChance { ... }
if area.hpRiskChance > 0 && Double.random(in: 0...1) < area.hpRiskChance { ... }
```

The risk logic is now data-driven via ForageAreaDef properties instead of hardcoded per-case.

- [ ] **Step 6: Verify build**

```bash
cd /Users/jessedev/Documents/Code/PetEngine && swift build
```

Fix any compilation errors from missed references.

- [ ] **Step 7: Commit**

```bash
git add . && git commit -m "feat: add GameState with ContentProvider dependency injection"
```

---

## Chunk 3: Move Views to PetEngine

### Task 10: Move all View files to PetEngine

**Files:**
- Create: `/Users/jessedev/Documents/Code/PetEngine/Sources/PetEngine/Views/RootView.swift`
- Create: `/Users/jessedev/Documents/Code/PetEngine/Sources/PetEngine/Views/ContentView.swift`
- Create: `/Users/jessedev/Documents/Code/PetEngine/Sources/PetEngine/Views/SplashView.swift`
- Create: `/Users/jessedev/Documents/Code/PetEngine/Sources/PetEngine/Views/GameOverlays.swift`
- Create: `/Users/jessedev/Documents/Code/PetEngine/Sources/PetEngine/Views/ForageOverlay.swift`
- Create: `/Users/jessedev/Documents/Code/PetEngine/Sources/PetEngine/Views/InventoryOverlay.swift`
- Create: `/Users/jessedev/Documents/Code/PetEngine/Sources/PetEngine/Views/BurrowOverlay.swift`
- Create: `/Users/jessedev/Documents/Code/PetEngine/Sources/PetEngine/Views/ExpeditionOverlay.swift`
- Create: `/Users/jessedev/Documents/Code/PetEngine/Sources/PetEngine/Views/GameSelectorOverlay.swift`
- Create: `/Users/jessedev/Documents/Code/PetEngine/Sources/PetEngine/Views/JournalOverlay.swift`
- Create: `/Users/jessedev/Documents/Code/PetEngine/Sources/PetEngine/Views/SettingsMenuView.swift`

- [ ] **Step 1: Update RootView to accept providers**

```swift
public struct RootView: View {
    @StateObject private var game: GameState
    let theme: any ThemeProvider
    let sprite: any SpriteProvider

    public init(theme: any ThemeProvider, content: any ContentProvider,
                sprite: any SpriteProvider, adService: (any AdService)? = nil) {
        self.theme = theme
        self.sprite = sprite
        _game = StateObject(wrappedValue: GameState(content: content, adService: adService))
    }

    public var body: some View {
        // Same phase logic, but pass theme/sprite down
    }
}
```

- [ ] **Step 2: Copy all view files, replacing hardcoded references**

For EVERY view file, apply these replacements:
- `GrubPalette.void_color` → `theme.voidColor`
- `GrubPalette.moss` → `theme.moss`
- `GrubPalette.green` → `theme.green`
- `GrubPalette.pale` → `theme.pale`
- `GrubPalette.red` → `theme.red`
- `GrubPalette.yellow` → `theme.yellow`
- `GrubPalette.purple` → `theme.purple`
- `GrubPalette.white` → `theme.white`
- `GrubPalette.moonpale` → `theme.moonpale`
- `GrubPalette.dimGreen` → `theme.dimGreen`
- `GrubPalette.grey` → `theme.grey`
- `GrubPalette.bone` → `theme.bone`
- `GrubPalette.nearBlack` → `theme.nearBlack`
- `GrubPalette.deepMoss` → `theme.deepMoss`
- `GrubPalette.orange` → `theme.orange`
- `GrubFont.size(X)` → `.custom(theme.fontName, size: X)`
- `GrubFont.name` → `theme.fontName`
- `"GRUB"` → `theme.appName`
- `"HNG"` → `theme.statLabels.hunger`
- `"HAP"` → `theme.statLabels.happiness`
- `"HP"` → `theme.statLabels.health`
- `"FEED"` → `theme.buttonLabels.feed`
- `"PLAY"` → `theme.buttonLabels.play`
- `"DIG"` → `theme.buttonLabels.dig`
- `"PACK"` → `theme.buttonLabels.pack`
- Hardcoded banner strings → `theme.uiStrings.*`
- `SpriteRenderer.makeGrubSprite(...)` → `sprite.makeSpriteGrid(...)`
- `SpriteRenderer.drawSprite(...)` → `PixelRenderer.drawSprite(..., palette: theme.spritePalette, ...)`
- `SpriteRenderer.drawBackground(...)` → `sprite.drawBackground(..., theme: theme)`
- `recipeCatalog[...]` → `game.content.recipes[...]`
- `ingredientCatalog[...]` → `game.content.ingredients[...]`

Each view needs `theme` and potentially `sprite` passed via environment or init params. Use `@EnvironmentObject` or pass explicitly — decide based on how deeply nested the usage is. Recommend: pass `theme` via `@Environment` using a custom key.

- [ ] **Step 3: Create ThemeEnvironmentKey**

```swift
// In Protocols/ThemeProvider.swift, add:
private struct ThemeKey: EnvironmentKey {
    static let defaultValue: (any ThemeProvider)? = nil
}

public extension EnvironmentValues {
    var theme: (any ThemeProvider)? {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
```

Then in RootView, inject: `.environment(\.theme, theme)`

- [ ] **Step 4: Fix ForageOverlay for dynamic biomes**

The current ForageOverlay hardcodes 3 buttons for the 3 enum cases. Replace with:
```swift
ForEach(game.content.forageAreas) { area in
    ForageAreaButton(area: area, game: game, theme: theme)
}
```

- [ ] **Step 5: Verify build**

```bash
cd /Users/jessedev/Documents/Code/PetEngine && swift build
```

This will likely have many errors on first attempt. Fix each one methodically.

- [ ] **Step 6: Commit**

```bash
git add . && git commit -m "feat: add all views with ThemeProvider/SpriteProvider integration"
```

---

## Chunk 4: Refactor GrubIOS as a Skin

### Task 11: Add PetEngine as dependency to GrubIOS

**Files:**
- Modify: `/Users/jessedev/Documents/Code/grub/GrubIOS/GrubIOS.xcodeproj/project.pbxproj` (via Xcode or xcodegen)
- Modify: `/Users/jessedev/Documents/Code/grub/GrubIOS/project.yml` (if using xcodegen)

- [ ] **Step 1: Add PetEngine as a local SPM dependency**

In Xcode: File → Add Package Dependencies → Add Local → select `/Users/jessedev/Documents/Code/PetEngine`

Or in project.yml:
```yaml
packages:
  PetEngine:
    path: ../../PetEngine
```

- [ ] **Step 2: Verify GrubIOS still builds (it won't yet — just confirming dependency resolves)**

```bash
cd /Users/jessedev/Documents/Code/grub/GrubIOS
xcodebuild -project GrubIOS.xcodeproj -scheme GrubIOS -sdk iphonesimulator build 2>&1 | tail -3
```

- [ ] **Step 3: Commit**

```bash
cd /Users/jessedev/Documents/Code/grub/GrubIOS
git add . && git commit -m "feat: add PetEngine as local SPM dependency"
```

---

### Task 12: Create GrubTheme

**Files:**
- Create: `/Users/jessedev/Documents/Code/grub/GrubIOS/GrubIOS/GrubTheme.swift`

- [ ] **Step 1: Implement ThemeProvider with existing Swamp Candy palette**

```swift
import SwiftUI
import PetEngine

final class GrubTheme: ThemeProvider {
    let voidColor = Color(hex: "#1a1a2e")
    let moss = Color(hex: "#16213e")
    let deepMoss = Color(hex: "#2a2a4e")
    let green = Color(hex: "#4ecca3")
    let pale = Color(hex: "#e8e8d0")
    let red = Color(hex: "#e94560")
    let yellow = Color(hex: "#f5a623")
    let purple = Color(hex: "#7b2d8b")
    let white = Color(hex: "#f0f0f0")
    let moonpale = Color(hex: "#c8c8b8")
    let dimGreen = Color(hex: "#2a7a60")
    let grey = Color(hex: "#888880")
    let bone = Color(hex: "#c0b89a")
    let nearBlack = Color(hex: "#0d0d0d")
    let orange = Color(hex: "#e07020")

    let spritePalette: [Character: Color] = [
        "1": Color(hex: "#1a1a2e"), "2": Color(hex: "#4ecca3"),
        "3": Color(hex: "#e8e8d0"), "4": Color(hex: "#e94560"),
        "5": Color(hex: "#f5a623"), "6": Color(hex: "#7b2d8b"),
        "7": Color(hex: "#16213e"), "8": Color(hex: "#c8c8b8"),
        "9": Color(hex: "#2a7a60"), "A": Color(hex: "#ffffff"),
        "B": Color(hex: "#888880"), "C": Color(hex: "#c0b89a"),
        "D": Color(hex: "#0d0d0d"), "E": Color(hex: "#e07020"),
    ]

    let fontName = "PressStart2P-Regular"
    let appName = "GRUB"

    let statLabels = StatLabels(hunger: "HNG", happiness: "HAP", health: "HP")
    let buttonLabels = ButtonLabels(feed: "FEED", play: "PLAY", dig: "DIG", pack: "PACK")

    let uiStrings = UIStrings(
        dyingBanner: "DYING!", healPrompt: "HEAL HIM!",
        nappingBanner: "NAPPING", nightBanner: "GRUB SLEEPS 10PM-6AM",
        deathMessage: "YOUR GRUB HAS DIED", tapToStart: "TAP TO START",
        overfedWarning: "OVERFED! -5 HAP", tooHungryWarning: "TOO HUNGRY TO FORAGE!",
        inventoryFullWarning: "INVENTORY FULL!", cooldownPrefix: "COOLDOWN:",
        foundSomething: "YOUR GRUB FOUND SOMETHING...",
        exploring: "GRUB IS EXPLORING...", adoptNew: "ADOPT NEW GRUB"
    )
}
```

- [ ] **Step 2: Commit**

```bash
git add . && git commit -m "feat: add GrubTheme implementing ThemeProvider"
```

---

### Task 13: Create GrubContent

**Files:**
- Create: `/Users/jessedev/Documents/Code/grub/GrubIOS/GrubIOS/GrubContent.swift`

- [ ] **Step 1: Move all RecipeData content into GrubContent**

Copy every catalog from RecipeData.swift (ingredientCatalog, recipeCatalog, lootTables, decorationCatalog, expeditionCatalog, gameEvents, journalEntries) into a class that implements ContentProvider.

Convert `gameEvents` closures to `EventAction` enum values.

Convert `ForageArea` enum cases to `ForageAreaDef` structs:
```swift
ForageAreaDef(id: "shallowCave", name: "SHALLOW CAVE", description: "SAFE - COMMON ITEMS",
              riskLevel: .none, hungerCost: 5, cooldownSeconds: 900,
              poisonChance: 0, hpRiskChance: 0, hpRiskAmount: 0)
```

Convert `PersonalityTrait` enum to `PersonalityDef` array.

Set `decayRates` to match current `DecayConstants`.
Set `xpThresholds` to current values.
Set `deathBehavior` to `.permanentDeath(reviveWindowHours: 12)`.

- [ ] **Step 2: Commit**

```bash
git add . && git commit -m "feat: add GrubContent implementing ContentProvider"
```

---

### Task 14: Create GrubSprite

**Files:**
- Create: `/Users/jessedev/Documents/Code/grub/GrubIOS/GrubIOS/GrubSprite.swift`

- [ ] **Step 1: Move grub-specific sprite logic from SpriteRenderer**

Copy `makeGrubSprite(state:tick:)` and `drawBackground(context:size:tick:)` from SpriteRenderer.swift into a class implementing SpriteProvider.

```swift
import SwiftUI
import PetEngine

final class GrubSprite: SpriteProvider {
    func makeSpriteGrid(state: SpriteState, frame: Int) -> [[Character]] {
        // Copy the existing makeGrubSprite logic
        // Replace string state param with SpriteState enum
    }

    func drawBackground(context: inout GraphicsContext, size: CGSize,
                        frame: Int, theme: any ThemeProvider) {
        // Copy existing drawBackground logic
        // Replace GrubPalette references with theme.*
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add . && git commit -m "feat: add GrubSprite implementing SpriteProvider"
```

---

### Task 15: Update GrubIOSApp entry point

**Files:**
- Modify: `/Users/jessedev/Documents/Code/grub/GrubIOS/GrubIOS/GrubIOSApp.swift`

- [ ] **Step 1: Wire providers into RootView**

```swift
import SwiftUI
import AppTrackingTransparency
import PetEngine

@main
struct GrubIOSApp: App {
    let theme = GrubTheme()
    let content = GrubContent()
    let sprite = GrubSprite()
    let adService = AdManager.shared

    init() {
        AdManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView(theme: theme, content: content, sprite: sprite, adService: adService)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    requestTrackingPermission()
                }
        }
    }

    private func requestTrackingPermission() {
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                ATTrackingManager.requestTrackingAuthorization { status in
                    print("[ATT] Authorization status: \(status.rawValue)")
                }
            }
        }
    }
}
```

- [ ] **Step 2: Delete old files that are now in PetEngine**

Remove from GrubIOS (they now live in PetEngine):
- `GameState.swift` and all `GameState+*.swift` extensions
- `RootView.swift`
- `ContentView.swift`
- `SplashView.swift`
- `GameOverlays.swift`
- `ForageOverlay.swift`
- `InventoryOverlay.swift`
- `BurrowOverlay.swift`
- `ExpeditionOverlay.swift`
- `GameSelectorOverlay.swift`
- `JournalOverlay.swift`
- `SettingsMenuView.swift`
- `AudioEngine.swift`
- `AdService.swift`
- `RecipeData.swift` (replaced by GrubContent.swift)

Keep in GrubIOS:
- `GrubIOSApp.swift` (modified)
- `GrubTheme.swift` (new)
- `GrubContent.swift` (new)
- `GrubSprite.swift` (new)
- `AdManager.swift` (skin-specific, depends on GoogleMobileAds)
- `AdConfig.swift` (skin-specific ad unit IDs)
- `Assets.xcassets/`
- `Info.plist`
- Font files

- [ ] **Step 3: Update Xcode project to reflect file changes**

Remove deleted files from the Xcode project. Add new files. This may require regenerating the project via xcodegen if using project.yml.

- [ ] **Step 4: Build and test**

```bash
cd /Users/jessedev/Documents/Code/grub/GrubIOS
xcodebuild -project GrubIOS.xcodeproj -scheme GrubIOS -sdk iphonesimulator build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Run on simulator and verify identical behavior**

```bash
xcrun simctl boot "iPhone 16 Pro" 2>/dev/null
xcodebuild -project GrubIOS.xcodeproj -scheme GrubIOS -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -3
xcrun simctl install booted /path/to/GrubIOS.app
xcrun simctl launch booted com.jessedev.GrubIOS
```

Manually verify:
- Splash screen looks identical
- Game loads, stats display correctly
- Feeding, playing, digging, packing all work
- Events trigger and display correctly
- Minigames work
- Settings work
- Audio plays

- [ ] **Step 6: Commit**

```bash
cd /Users/jessedev/Documents/Code/grub/GrubIOS
git add . && git commit -m "refactor: GrubIOS now uses PetEngine — all gameplay unchanged"
```

---

## Chunk 5: Verification & Cleanup

### Task 16: Run existing tests

**Files:**
- Existing: `/Users/jessedev/Documents/Code/grub/GrubIOS/GrubIOSTests/GameStateTests.swift`

- [ ] **Step 1: Update test imports**

```swift
import XCTest
@testable import PetEngine
@testable import GrubIOS
```

Tests may need to create `GameState(content: GrubContent())` instead of `GameState()`.

- [ ] **Step 2: Run tests**

```bash
xcodebuild test -project GrubIOS.xcodeproj -scheme GrubIOS \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16 Pro' 2>&1 | tail -20
```
Expected: All tests pass

- [ ] **Step 3: Fix any test failures**

If tests reference old global constants, update to use `GrubContent()`.

- [ ] **Step 4: Commit**

```bash
git add . && git commit -m "test: update tests for PetEngine extraction"
```

---

### Task 17: Clean up SpriteRenderer.swift in GrubIOS

**Files:**
- Modify or Delete: `/Users/jessedev/Documents/Code/grub/GrubIOS/GrubIOS/SpriteRenderer.swift`

- [ ] **Step 1: Remove code that moved to PetEngine**

Delete from SpriteRenderer.swift:
- `GrubFont` struct (font name now in ThemeProvider)
- `GrubPalette` struct (colors now in ThemeProvider)
- `Color(hex:)` extension (now in PetEngine)
- `drawSprite()` generic renderer (now in PetEngine PixelRenderer)
- `ScanlineOverlay` (now in PetEngine)
- `PixelIcon` (now in PetEngine)

What remains should only be the `makeGrubSprite` logic — which is now in `GrubSprite.swift`. If nothing remains, delete the file entirely.

- [ ] **Step 2: Verify build**

```bash
xcodebuild -project GrubIOS.xcodeproj -scheme GrubIOS -sdk iphonesimulator build 2>&1 | tail -3
```

- [ ] **Step 3: Commit**

```bash
git add . && git commit -m "cleanup: remove code that moved to PetEngine"
```

---

### Task 18: Final verification

- [ ] **Step 1: Verify PetEngine builds standalone**

```bash
cd /Users/jessedev/Documents/Code/PetEngine && swift build
```

- [ ] **Step 2: Verify GrubIOS builds with PetEngine**

```bash
cd /Users/jessedev/Documents/Code/grub/GrubIOS
xcodebuild -project GrubIOS.xcodeproj -scheme GrubIOS -sdk iphonesimulator build 2>&1 | tail -3
```

- [ ] **Step 3: Run full test suite**

```bash
xcodebuild test -project GrubIOS.xcodeproj -scheme GrubIOS \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16 Pro' 2>&1 | tail -20
```

- [ ] **Step 4: Verify adding a new skin is ~6 files**

Check that creating a new skin only requires:
1. `XxxApp.swift` — entry point
2. `XxxTheme.swift` — ThemeProvider
3. `XxxContent.swift` — ContentProvider
4. `XxxSprite.swift` — SpriteProvider
5. `AdConfig.swift` — ad unit IDs
6. `AdManager.swift` — ad integration (can be copied)
7. `Assets.xcassets/` — app icon

- [ ] **Step 5: Push PetEngine and GrubIOS**

```bash
cd /Users/jessedev/Documents/Code/PetEngine
gh repo create bartonjc2-max/PetEngine --private --source=. --push

cd /Users/jessedev/Documents/Code/grub/GrubIOS
git push
```

- [ ] **Step 6: Final commit message**

```bash
cd /Users/jessedev/Documents/Code/grub/GrubIOS
git add . && git commit -m "Phase 1 complete: PetEngine extracted, GrubIOS is now a skin"
```
