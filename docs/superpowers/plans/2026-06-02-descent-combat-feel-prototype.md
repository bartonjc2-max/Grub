# Descent Combat-Feel Prototype Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a standalone, playable combat-feel prototype of The Descent — one room, 8-direction grid movement, a fanged-slime chase enemy, Attack + Interact, 3 hearts, win/death — so the moment-to-moment feel can be judged before any floor content is built.

**Architecture:** A pure value-type `struct DescentEngine` (SwiftUI-free, unit-tested) owns all run state and logic (grid collision, enemy AI, combat, i-frames, win/death). Thin SwiftUI views render it (`Canvas` scene + joystick/button controls) and drive it from a `TimelineView(.animation)` loop. A DEBUG-only entry point routes the home screen's DIG button into the prototype; nothing is ever persisted.

**Tech Stack:** Swift 5.9 / SwiftUI (iOS 17), XcodeGen, XCTest. Simulator `id=B30DE184-06D2-4A74-8EC5-24DB2377A109` (iPhone 17 / iOS 26.2). Build/test via `xcodebuild`.

**Spec:** `docs/superpowers/specs/2026-06-01-descent-combat-feel-prototype-design.md`

**Branch:** `descent` (continue current branch — all Descent work lives here).

---

## Conventions used throughout this plan

- **Coordinates:** `GridPoint(x, y)` where `x` is column (0 = left) and `y` is row (0 = top). Screen-style, y increases **downward**.
- **Grid storage:** `tiles[y][x]` — outer array is rows.
- **Layouts must be rectangular** — every row the same width (`width` is taken from row 0). All test rooms and the prototype room satisfy this; keep it true for any new layout.
- **Test target:** `GrubIOSTests`. New engine tests live in `GrubIOSTests/DescentEngineTests.swift`.
- **Run a single test:**
  ```bash
  cd ~/Documents/Code/grub/GrubIOS
  xcodebuild test -scheme GrubIOS \
    -destination 'id=B30DE184-06D2-4A74-8EC5-24DB2377A109' \
    -only-testing:GrubIOSTests/DescentEngineTests/<test_name> 2>&1 | tail -20
  ```
- **Run the whole suite:**
  ```bash
  xcodebuild test -scheme GrubIOS \
    -destination 'id=B30DE184-06D2-4A74-8EC5-24DB2377A109' 2>&1 \
    | grep -E "Executed|TEST SUCCEEDED|TEST FAILED|error:"
  ```
- **After creating any new `.swift` file:** run `/opt/homebrew/bin/xcodegen generate` before building so the file joins the target (XcodeGen folder references pick up new files in `GrubIOS/`).
- **Baseline:** 28 existing tests are green. Every chunk must keep them green.

---

## File structure (decomposition locked here)

All new code under `GrubIOS/Descent/`:

| File | Responsibility | SwiftUI |
|---|---|---|
| `GrubIOS/Descent/DescentTuning.swift` | All feel constants in one struct. | No |
| `GrubIOS/Descent/DescentEngine.swift` | Runtime types (`GridPoint`, `Direction8`, `Tile`, `RunStatus`, `EnemyInstance`) + the pure-`struct` engine: parsing, movement, collision, enemy AI, combat, i-frames, win/death, static-path invariant. Also the prototype room literal. | No |
| `GrubIOS/Descent/DescentSceneView.swift` | `Canvas` that renders engine state pixel-perfect. | Yes |
| `GrubIOS/Descent/DescentControlsView.swift` | Virtual joystick (8-way) + Attack/Interact buttons. | Yes |
| `GrubIOS/Descent/DescentView.swift` | Container: owns `@State` engine, `TimelineView` loop, win/death overlays, Back-to-home. | Yes |

Modified:
| File | Change |
|---|---|
| `GrubIOS/ContentView.swift` | DEBUG-only: DIG action presents `DescentView` as a `fullScreenCover`; `GRUB_DESCENT=1` launch hook. |
| `GrubIOS/Assets.xcassets/descent_slime.imageset/` | New — the generated slime PNG (added in Chunk 3). |

Tests:
| File | Change |
|---|---|
| `GrubIOSTests/DescentEngineTests.swift` | New — all engine unit tests. |

---

## Chunk 1: Engine foundation — types, tuning, movement, collision, static path

Goal of this chunk: a parseable engine with deterministic movement, wall collision, 8-way quantization, and the floor-1-passable invariant. No combat yet.

### Task 1: `DescentTuning` constants struct

**Files:**
- Create: `GrubIOS/Descent/DescentTuning.swift`

- [ ] **Step 1: Create the tuning struct**

```swift
import Foundation

/// Single source of truth for Descent feel/balance. Snappy/arcade starting
/// values — tune on-device. Mirrors the existing DecayConstants pattern.
struct DescentTuning {
    // Movement
    var grubStepDuration: Double = 0.13      // seconds per tile (~7 tiles/s)
    // Attack
    var attackCooldown: Double = 0.25        // seconds between attacks
    var attackFlashDuration: Double = 0.12   // attack/hit flash visual window
    // Enemy
    var enemyHP: Int = 2                      // dies in 1-2 hits
    var enemyStepDuration: Double = 0.22      // seconds per tile (~4.5 tiles/s)
    var enemyTouchDamage: Int = 1            // hearts lost on contact
    var enemyContactIFrames: Double = 0.8     // invuln after a hit
    // Run
    var startHearts: Int = 3                  // fixed for the prototype
    // Grid
    var gridWidth: Int = 11
    var gridHeight: Int = 15
}
```

- [ ] **Step 2: Generate project + build to confirm it compiles**

Run:
```bash
cd ~/Documents/Code/grub/GrubIOS && /opt/homebrew/bin/xcodegen generate >/dev/null && \
xcodebuild -scheme GrubIOS -destination 'id=B30DE184-06D2-4A74-8EC5-24DB2377A109' build 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add GrubIOS/Descent/DescentTuning.swift
git commit -m "feat(descent): add DescentTuning constants struct"
```

---

### Task 2: Runtime types + engine parsing/spawn

**Files:**
- Create: `GrubIOS/Descent/DescentEngine.swift`
- Test: `GrubIOSTests/DescentEngineTests.swift`

- [ ] **Step 1: Write the failing test**

Create `GrubIOSTests/DescentEngineTests.swift`:
```swift
import XCTest
@testable import GrubIOS

final class DescentEngineTests: XCTestCase {

    // A tiny 5x4 test room: border walls, entry top-left interior,
    // stairs bottom-right interior, slime in the middle.
    //   row0: #####
    //   row1: #E..#
    //   row2: #.S>#
    //   row3: #####
    static let room: [String] = [
        "#####",
        "#E..#",
        "#.S>#",
        "#####",
    ]

    func makeEngine() -> DescentEngine {
        DescentEngine(layout: room, tuning: DescentTuning())
    }

    func test_parsing_places_grub_at_entry_and_slime_at_spawn() {
        let e = makeEngine()
        XCTAssertEqual(e.grub, GridPoint(x: 1, y: 1))           // 'E'
        XCTAssertEqual(e.hearts, 3)
        XCTAssertEqual(e.status, .playing)
        XCTAssertEqual(e.enemies.count, 1)
        XCTAssertEqual(e.enemies.first?.tile, GridPoint(x: 2, y: 2)) // 'S'
        XCTAssertEqual(e.enemies.first?.hp, 2)
    }

    func test_passability() {
        let e = makeEngine()
        XCTAssertFalse(e.isPassable(GridPoint(x: 0, y: 0)))     // wall
        XCTAssertTrue(e.isPassable(GridPoint(x: 1, y: 1)))      // entry/floor
        XCTAssertTrue(e.isPassable(GridPoint(x: 3, y: 2)))      // stairs
        XCTAssertFalse(e.isPassable(GridPoint(x: -1, y: 1)))    // out of bounds
        XCTAssertFalse(e.isPassable(GridPoint(x: 99, y: 1)))    // out of bounds
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run the single-test command for `test_parsing_places_grub_at_entry_and_slime_at_spawn`.
Expected: FAIL — `DescentEngine` / `GridPoint` undefined (compile error).

- [ ] **Step 3: Write minimal implementation**

Create `GrubIOS/Descent/DescentEngine.swift`:
```swift
import Foundation

// MARK: - Runtime types

struct GridPoint: Equatable {
    var x: Int
    var y: Int
    static func + (l: GridPoint, d: Direction8) -> GridPoint {
        GridPoint(x: l.x + d.dx, y: l.y + d.dy)
    }
}

/// 8 compass directions. y increases downward (screen coords).
enum Direction8: CaseIterable {
    case n, ne, e, se, s, sw, w, nw

    var dx: Int {
        switch self {
        case .ne, .e, .se: return 1
        case .nw, .w, .sw: return -1
        case .n, .s: return 0
        }
    }
    var dy: Int {
        switch self {
        case .se, .s, .sw: return 1
        case .ne, .n, .nw: return -1
        case .e, .w: return 0
        }
    }
}

enum Tile: Character {
    case wall = "#"
    case floor = "."
    case entry = "E"
    case stairs = ">"
    // 'S' (slime spawn) is parsed into an enemy and stored as floor.
}

enum RunStatus { case playing, won, dead }

struct EnemyInstance: Equatable {
    var tile: GridPoint
    var hp: Int
    var stepCooldown: Double   // seconds until next AI step
}

// MARK: - Engine

/// Pure value-type Descent engine. SwiftUI-free, unit-testable. All run state
/// and logic live here; views render it and feed it intents + dt.
struct DescentEngine {
    let tuning: DescentTuning
    let width: Int
    let height: Int

    private(set) var tiles: [[Tile]]      // tiles[y][x]
    let slimeSpawns: [GridPoint]          // original 'S' tiles (for the static-path invariant)

    private(set) var grub: GridPoint
    private(set) var facing: Direction8 = .s
    private(set) var hearts: Int
    private(set) var enemies: [EnemyInstance]
    private(set) var status: RunStatus = .playing

    init(layout: [String], tuning: DescentTuning = DescentTuning()) {
        self.tuning = tuning
        self.height = layout.count
        self.width = layout.first?.count ?? 0
        self.hearts = tuning.startHearts

        var parsed: [[Tile]] = []
        var grubStart = GridPoint(x: 1, y: 1)
        var spawns: [GridPoint] = []
        var foundEntry = false

        for (y, line) in layout.enumerated() {
            var row: [Tile] = []
            for (x, ch) in line.enumerated() {
                switch ch {
                case "#": row.append(.wall)
                case "E":
                    row.append(.entry); grubStart = GridPoint(x: x, y: y); foundEntry = true
                case ">": row.append(.stairs)
                case "S":
                    row.append(.floor); spawns.append(GridPoint(x: x, y: y))
                case ".": row.append(.floor)
                default:
                    #if DEBUG
                    print("DescentEngine: unknown tile '\(ch)' at (\(x),\(y)) -> floor")
                    #endif
                    row.append(.floor)
                }
            }
            parsed.append(row)
        }
        #if DEBUG
        if !foundEntry { print("DescentEngine: no 'E' entry in layout, defaulting to (1,1)") }
        #endif

        self.tiles = parsed
        self.slimeSpawns = spawns
        self.grub = grubStart
        self.enemies = spawns.map { EnemyInstance(tile: $0, hp: tuning.enemyHP, stepCooldown: tuning.enemyStepDuration) }
    }

    func isPassable(_ p: GridPoint) -> Bool {
        guard p.y >= 0, p.y < height, p.x >= 0, p.x < width else { return false }
        return tiles[p.y][p.x] != .wall
    }

    func tile(at p: GridPoint) -> Tile? {
        guard p.y >= 0, p.y < height, p.x >= 0, p.x < width else { return nil }
        return tiles[p.y][p.x]
    }
}
```

- [ ] **Step 4: Run both tests to verify they pass**

Run the single-test command for each of `test_parsing_places_grub_at_entry_and_slime_at_spawn` and `test_passability`.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add GrubIOS/Descent/DescentEngine.swift GrubIOSTests/DescentEngineTests.swift
git commit -m "feat(descent): engine runtime types + layout parsing"
```

---

### Task 3: Movement, collision, and 8-way quantization

**Files:**
- Modify: `GrubIOS/Descent/DescentEngine.swift`
- Test: `GrubIOSTests/DescentEngineTests.swift`

- [ ] **Step 1: Write the failing tests**

Append to `DescentEngineTests`:
```swift
func test_held_move_steps_one_tile_per_step_duration() {
    var e = makeEngine()
    e.setMove(.e)
    e.update(e.tuning.grubStepDuration)
    XCTAssertEqual(e.grub, GridPoint(x: 2, y: 1))   // moved east one tile
    XCTAssertEqual(e.facing, .e)
}

func test_move_into_wall_is_blocked() {
    var e = makeEngine()
    e.setMove(.n)                                    // wall directly above entry (row 0)
    e.update(e.tuning.grubStepDuration)
    XCTAssertEqual(e.grub, GridPoint(x: 1, y: 1))   // unchanged
    XCTAssertEqual(e.facing, .n)                    // facing still updates
}

func test_release_move_stops_stepping() {
    var e = makeEngine()
    e.setMove(.e)
    e.update(e.tuning.grubStepDuration)             // -> (2,1)
    e.setMove(nil)
    e.update(e.tuning.grubStepDuration * 5)
    XCTAssertEqual(e.grub, GridPoint(x: 2, y: 1))   // no further movement
}

func test_direction8_quantization() {
    XCTAssertEqual(Direction8.from(dx: 1.0, dy: 0.0), .e)
    XCTAssertEqual(Direction8.from(dx: 0.0, dy: 1.0), .s)    // y down
    XCTAssertEqual(Direction8.from(dx: 0.0, dy: -1.0), .n)
    XCTAssertEqual(Direction8.from(dx: 0.8, dy: 0.8), .se)
    XCTAssertEqual(Direction8.from(dx: -0.9, dy: -0.1), .w)
    XCTAssertNil(Direction8.from(dx: 0.0, dy: 0.0))         // dead zone
}
```

- [ ] **Step 2: Run to verify they fail**

Run each new test. Expected: FAIL (compile — `setMove`, `update`, `Direction8.from` undefined).

- [ ] **Step 3: Implement movement + quantization**

Add to `Direction8`:
```swift
    /// Quantize a joystick vector (y down) to the nearest of 8 directions.
    /// Returns nil inside a small dead zone.
    static func from(dx: Double, dy: Double) -> Direction8? {
        let mag = (dx * dx + dy * dy).squareRoot()
        guard mag > 0.2 else { return nil }
        // Sector index 0..7 starting at east, going clockwise (screen y down).
        let angle = atan2(dy, dx)                 // -pi..pi, +x=east, +y=south
        let twoPi = Double.pi * 2
        let normalized = (angle + twoPi).truncatingRemainder(dividingBy: twoPi) // 0..2pi
        let sector = Int((normalized / (twoPi / 8)).rounded()) % 8
        // sector 0=e,1=se,2=s,3=sw,4=w,5=nw,6=n,7=ne
        switch sector {
        case 0: return .e
        case 1: return .se
        case 2: return .s
        case 3: return .sw
        case 4: return .w
        case 5: return .nw
        case 6: return .n
        default: return .ne
        }
    }
```

Add stored properties to `DescentEngine` (after `status`):
```swift
    // Input + timers (private)
    private var heldDirection: Direction8?
    private var moveCooldown: Double = 0          // time until Grub may step
```

Add intent + update methods to `DescentEngine`:
```swift
    /// Joystick changed. nil = released. Facing updates immediately; a newly
    /// pressed direction resets the step cooldown so the first step is instant.
    mutating func setMove(_ dir: Direction8?) {
        guard status == .playing else { return }
        if let dir = dir {
            if heldDirection == nil { moveCooldown = 0 }   // instant first step
            facing = dir
        }
        heldDirection = dir
    }

    /// Advance the simulation by dt seconds.
    mutating func update(_ dt: Double) {
        guard status == .playing else { return }
        stepGrub(dt)
    }

    private mutating func stepGrub(_ dt: Double) {
        moveCooldown -= dt
        guard let dir = heldDirection, moveCooldown <= 0 else { return }
        let target = grub + dir
        if isPassable(target) { grub = target }
        moveCooldown = tuning.grubStepDuration
    }
```

- [ ] **Step 4: Run to verify they pass**

Run the 4 new tests. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add GrubIOS/Descent/DescentEngine.swift GrubIOSTests/DescentEngineTests.swift
git commit -m "feat(descent): grid movement, wall collision, 8-way quantization"
```

---

### Task 4: Floor-1-passable static-path invariant

**Files:**
- Modify: `GrubIOS/Descent/DescentEngine.swift`
- Test: `GrubIOSTests/DescentEngineTests.swift`

- [ ] **Step 1: Write the failing tests**

Append:
```swift
func test_static_path_exists_from_entry_to_stairs_avoiding_slime_spawn() {
    let e = makeEngine()
    XCTAssertTrue(e.hasStaticPathToStairs())
}

func test_static_path_false_when_only_route_is_through_slime_spawn() {
    // A 1-wide corridor where the slime spawn blocks the sole path.
    //   ###
    //   #E#
    //   #S#
    //   #>#
    //   ###
    let blocked = DescentEngine(layout: [
        "###",
        "#E#",
        "#S#",
        "#>#",
        "###",
    ])
    XCTAssertFalse(blocked.hasStaticPathToStairs())
}
```

- [ ] **Step 2: Run to verify they fail**

Expected: FAIL (`hasStaticPathToStairs` undefined).

- [ ] **Step 3: Implement BFS over the static layout**

Add to `DescentEngine`:
```swift
    /// True iff a 4-connected path of passable tiles connects the entry to the
    /// stairs WITHOUT passing through any slime spawn tile. Validates the
    /// floor-1-passable invariant (combat is optional). Static layout only —
    /// it cannot account for the live, moving enemy.
    func hasStaticPathToStairs() -> Bool {
        guard let start = firstTile(.entry), let goal = firstTile(.stairs) else { return false }
        let blocked = Set(slimeSpawns.map { [$0.x, $0.y] })
        var visited = Set<[Int]>()
        var queue = [start]
        visited.insert([start.x, start.y])
        let steps = [GridPoint(x: 1, y: 0), GridPoint(x: -1, y: 0),
                     GridPoint(x: 0, y: 1), GridPoint(x: 0, y: -1)]
        while let cur = queue.first {
            queue.removeFirst()
            if cur == goal { return true }
            for d in steps {
                let nxt = GridPoint(x: cur.x + d.x, y: cur.y + d.y)
                let key = [nxt.x, nxt.y]
                if visited.contains(key) { continue }
                if blocked.contains(key) { continue }
                if !isPassable(nxt) { continue }
                visited.insert(key)
                queue.append(nxt)
            }
        }
        return false
    }

    private func firstTile(_ t: Tile) -> GridPoint? {
        for y in 0..<height {
            for x in 0..<width where tiles[y][x] == t {
                return GridPoint(x: x, y: y)
            }
        }
        return nil
    }
```

- [ ] **Step 4: Run to verify they pass**

Run both new tests. Expected: PASS.

- [ ] **Step 5: Run the full suite (regression gate)**

Run the whole-suite command. Expected: `** TEST SUCCEEDED **`, `Executed 3X tests, with 0 failures` (28 prior + new).

- [ ] **Step 6: Commit**

```bash
git add GrubIOS/Descent/DescentEngine.swift GrubIOSTests/DescentEngineTests.swift
git commit -m "feat(descent): floor-1-passable static-path invariant"
```

---

## Chunk 2: Combat — attack, enemy AI, contact damage/i-frames, win/death

Goal: the engine becomes a complete, testable combat simulation.

### Task 5: Attack the faced tile (with cooldown)

**Files:**
- Modify: `GrubIOS/Descent/DescentEngine.swift`
- Test: `GrubIOSTests/DescentEngineTests.swift`

- [ ] **Step 1: Write the failing tests**

Append. **These tests isolate attack mechanics from chase AI** by freezing the enemy (a huge `enemyStepDuration` so the slime never steps during the short test window). This keeps the attack assertions independent of enemy movement and of the `grubStepDuration`/`enemyStepDuration` ratio — the chase AI is tested separately in Task 6:
```swift
// Frozen-enemy engine: the slime never moves, so attack behavior is tested
// in isolation. Default room has grub (1,1), slime (2,2).
func makeFrozenEnemyEngine() -> DescentEngine {
    var t = DescentTuning()
    t.enemyStepDuration = 9999    // slime effectively never steps during a test
    return DescentEngine(layout: Self.room, tuning: t)
}

func test_attack_damages_enemy_on_faced_tile() {
    var e = makeFrozenEnemyEngine()                    // grub (1,1), slime (2,2)
    // Face the slime: move grub to (1,2) then face east toward (2,2).
    e.setMove(.s); e.update(e.tuning.grubStepDuration) // (1,2)
    e.setMove(.e)                                      // face east toward slime
    XCTAssertEqual(e.facing, .e)
    e.attack()
    XCTAssertEqual(e.enemies.first?.hp, 1)            // 2 -> 1
}

func test_two_attacks_kill_two_hp_slime() {
    var e = makeFrozenEnemyEngine()
    e.setMove(.s); e.update(e.tuning.grubStepDuration) // (1,2)
    e.setMove(.e)                                      // face east toward slime (2,2)
    e.attack()                                         // hp 2 -> 1
    e.setMove(nil)                                     // release stick so the cooldown-clearing
                                                       // update doesn't step grub onto the slime
    e.update(e.tuning.attackCooldown)                  // clear attack cooldown (slime frozen)
    e.attack()                                         // hp 1 -> 0 -> removed
    XCTAssertTrue(e.enemies.isEmpty)
}

func test_attack_on_empty_faced_tile_does_nothing() {
    var e = makeFrozenEnemyEngine()                    // faces .s by default toward (1,2) floor
    e.attack()
    XCTAssertEqual(e.enemies.first?.hp, 2)
}

func test_attack_respects_cooldown() {
    var e = makeFrozenEnemyEngine()
    e.setMove(.s); e.update(e.tuning.grubStepDuration)
    e.setMove(.e)
    e.attack()                                         // hp -> 1
    e.attack()                                         // still cooling down, no effect
    XCTAssertEqual(e.enemies.first?.hp, 1)
}
```

- [ ] **Step 2: Run to verify they fail**

Expected: FAIL (`attack` undefined).

- [ ] **Step 3: Implement attack + cooldown timer**

Add stored properties:
```swift
    private var attackCooldownRemaining: Double = 0
    private(set) var attackFlashRemaining: Double = 0   // for render
```

Decrement timers inside `update(_:)` — change the body to:
```swift
    mutating func update(_ dt: Double) {
        guard status == .playing else { return }
        attackCooldownRemaining = max(0, attackCooldownRemaining - dt)
        attackFlashRemaining = max(0, attackFlashRemaining - dt)
        stepGrub(dt)
    }
```

Add the intent:
```swift
    mutating func attack() {
        guard status == .playing, attackCooldownRemaining <= 0 else { return }
        attackCooldownRemaining = tuning.attackCooldown
        attackFlashRemaining = tuning.attackFlashDuration
        let target = grub + facing
        if let idx = enemies.firstIndex(where: { $0.tile == target }) {
            enemies[idx].hp -= 1
            if enemies[idx].hp <= 0 { enemies.remove(at: idx) }
        }
    }
```

- [ ] **Step 4: Run to verify they pass**

Run the 4 new tests. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add GrubIOS/Descent/DescentEngine.swift GrubIOSTests/DescentEngineTests.swift
git commit -m "feat(descent): attack faced tile with cooldown"
```

---

### Task 6: Enemy chase AI

**Files:**
- Modify: `GrubIOS/Descent/DescentEngine.swift`
- Test: `GrubIOSTests/DescentEngineTests.swift`

- [ ] **Step 1: Write the failing tests**

Append (use a wider room so the slime has room to step and won't touch grub immediately):
```swift
// Room with grub far from slime so we can observe approach without contact.
//   row0: #######
//   row1: #E....#
//   row2: #.....#
//   row3: #....S#
//   row4: #....>#
//   row5: #######
static let wideRoom: [String] = [
    "#######",
    "#E....#",
    "#.....#",
    "#....S#",
    "#....>#",
    "#######",
]

func test_enemy_chases_toward_grub() {
    var e = DescentEngine(layout: Self.wideRoom)
    let before = e.enemies.first!.tile               // (5,3)
    e.update(e.tuning.enemyStepDuration)             // one enemy step
    let after = e.enemies.first!.tile
    let distBefore = abs(before.x - e.grub.x) + abs(before.y - e.grub.y)
    let distAfter  = abs(after.x  - e.grub.x) + abs(after.y  - e.grub.y)
    XCTAssertLessThan(distAfter, distBefore)         // got closer
}

func test_enemy_does_not_step_into_wall() {
    // Slime boxed against the right wall; chasing left toward grub must stay in bounds.
    var e = DescentEngine(layout: Self.wideRoom)
    for _ in 0..<20 { e.update(e.tuning.enemyStepDuration) }
    let t = e.enemies.first?.tile
    if let t = t { XCTAssertTrue(e.isPassable(t)) }  // never on a wall / OOB
}
```

- [ ] **Step 2: Run to verify they fail**

Expected: FAIL — `test_enemy_chases_toward_grub` fails (enemy never moves; distAfter == distBefore).

- [ ] **Step 3: Implement chase stepping**

Add to `update(_:)`, after `stepGrub(dt)`:
```swift
        stepEnemies(dt)
```

Add the method:
```swift
    private mutating func stepEnemies(_ dt: Double) {
        for i in enemies.indices {
            enemies[i].stepCooldown -= dt
            guard enemies[i].stepCooldown <= 0 else { continue }
            enemies[i].stepCooldown = tuning.enemyStepDuration
            enemies[i].tile = chaseStep(from: enemies[i].tile)
        }
    }

    /// One greedy step toward Grub: reduce the larger-magnitude axis first;
    /// if that tile is blocked, try the other axis; else stay put.
    private func chaseStep(from p: GridPoint) -> GridPoint {
        let dx = grub.x - p.x
        let dy = grub.y - p.y
        let stepX = GridPoint(x: p.x + (dx == 0 ? 0 : (dx > 0 ? 1 : -1)), y: p.y)
        let stepY = GridPoint(x: p.x, y: p.y + (dy == 0 ? 0 : (dy > 0 ? 1 : -1)))
        let preferX = abs(dx) >= abs(dy)
        let first = preferX ? stepX : stepY
        let second = preferX ? stepY : stepX
        if first != p, isPassable(first) { return first }
        if second != p, isPassable(second) { return second }
        return p
    }
```

- [ ] **Step 4: Run to verify they pass**

Run both new tests. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add GrubIOS/Descent/DescentEngine.swift GrubIOSTests/DescentEngineTests.swift
git commit -m "feat(descent): enemy chase AI with wall avoidance"
```

---

### Task 7: Contact damage + i-frames

**Files:**
- Modify: `GrubIOS/Descent/DescentEngine.swift`
- Test: `GrubIOSTests/DescentEngineTests.swift`

- [ ] **Step 1: Write the failing tests**

Append. Use the small `room` where the slime reaches grub quickly:
```swift
func test_contact_removes_a_heart_and_starts_iframes() {
    var e = makeEngine()                              // grub (1,1), slime (2,2)
    // Let the slime reach grub. Don't move grub.
    var guardCount = 0
    while e.hearts == e.tuning.startHearts && guardCount < 50 {
        e.update(e.tuning.enemyStepDuration)
        guardCount += 1
    }
    XCTAssertEqual(e.hearts, e.tuning.startHearts - 1)
    XCTAssertTrue(e.isInIFrames)
}

func test_no_second_hit_during_iframes() {
    var e = makeEngine()
    var guardCount = 0
    while e.hearts == e.tuning.startHearts && guardCount < 50 {
        e.update(e.tuning.enemyStepDuration); guardCount += 1
    }
    let afterFirst = e.hearts
    // Advance a small amount, still within the 0.8s i-frame window.
    e.update(0.1)
    XCTAssertEqual(e.hearts, afterFirst)             // no extra damage
}

func test_contact_removes_again_after_iframes_expire() {
    // Spec §10: after i-frames expire, a subsequent contact removes another heart.
    var t = DescentTuning(); t.startHearts = 3
    var e = DescentEngine(layout: Self.room, tuning: t)   // grub (1,1), slime (2,2)
    var guardCount = 0
    while e.hearts == t.startHearts && guardCount < 50 {  // take the first hit
        e.update(e.tuning.enemyStepDuration); guardCount += 1
    }
    XCTAssertEqual(e.hearts, 2)
    XCTAssertTrue(e.isInIFrames)
    // One update past the i-frame window (0.8s): the slime is still on grub's
    // tile (chase from grub's own tile is a no-op), so in this same tick the
    // i-frames lapse and resolveContact lands a fresh hit (which re-arms them).
    e.update(e.tuning.enemyContactIFrames + 0.05)
    XCTAssertEqual(e.hearts, 1)                           // re-hit landed once i-frames lapsed
}
```

- [ ] **Step 2: Run to verify they fail**

Expected: FAIL (`isInIFrames` undefined; hearts never drop).

- [ ] **Step 3: Implement contact resolution + i-frame timer**

Add stored properties:
```swift
    private var iframesRemaining: Double = 0
    private(set) var hurtFlashRemaining: Double = 0   // for render
    var isInIFrames: Bool { iframesRemaining > 0 }
```

In `update(_:)`, decrement the new timers (add near the other timer decrements):
```swift
        iframesRemaining = max(0, iframesRemaining - dt)
        hurtFlashRemaining = max(0, hurtFlashRemaining - dt)
```

After `stepEnemies(dt)` in `update(_:)`, add:
```swift
        resolveContact()
```

Add the method:
```swift
    private mutating func resolveContact() {
        guard iframesRemaining <= 0 else { return }
        if enemies.contains(where: { $0.tile == grub }) {
            hearts -= tuning.enemyTouchDamage
            iframesRemaining = tuning.enemyContactIFrames
            hurtFlashRemaining = tuning.enemyContactIFrames
            if hearts <= 0 {
                hearts = 0
                status = .dead
            }
        }
    }
```

- [ ] **Step 4: Run to verify they pass**

Run both new tests. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add GrubIOS/Descent/DescentEngine.swift GrubIOSTests/DescentEngineTests.swift
git commit -m "feat(descent): contact damage with i-frames"
```

---

### Task 8: Win, death, and terminal-state freeze

**Files:**
- Modify: `GrubIOS/Descent/DescentEngine.swift`
- Test: `GrubIOSTests/DescentEngineTests.swift`

- [ ] **Step 1: Write the failing tests**

Append:
```swift
func test_interact_on_stairs_wins() {
    // Use a slime-free room so we can reach the stairs safely.
    //   #####
    //   #E.>#
    //   #####
    var e = DescentEngine(layout: ["#####", "#E.>#", "#####"])
    e.setMove(.e); e.update(e.tuning.grubStepDuration)   // (2,1)
    e.setMove(.e); e.update(e.tuning.grubStepDuration)   // (3,1) stairs
    XCTAssertEqual(e.tile(at: e.grub), .stairs)
    e.interact()
    XCTAssertEqual(e.status, .won)
}

func test_interact_off_stairs_does_nothing() {
    var e = DescentEngine(layout: ["#####", "#E.>#", "#####"])
    e.interact()
    XCTAssertEqual(e.status, .playing)
}

func test_death_when_hearts_reach_zero() {
    // 1-heart tuning + slime adjacent: dies on first contact.
    var t = DescentTuning(); t.startHearts = 1
    var e = DescentEngine(layout: ["#####", "#ES.#", "#####"], tuning: t)
    var guardCount = 0
    while e.status == .playing && guardCount < 50 {
        e.update(e.tuning.enemyStepDuration); guardCount += 1
    }
    XCTAssertEqual(e.status, .dead)
    XCTAssertEqual(e.hearts, 0)
}

func test_inputs_are_noops_once_terminal() {
    var e = DescentEngine(layout: ["#####", "#E.>#", "#####"])
    e.setMove(.e); e.update(e.tuning.grubStepDuration)
    e.setMove(.e); e.update(e.tuning.grubStepDuration)   // on stairs
    e.interact()                                          // -> .won
    let frozen = e.grub
    e.setMove(.w); e.update(e.tuning.grubStepDuration)    // ignored
    e.attack()                                            // ignored
    XCTAssertEqual(e.grub, frozen)
    XCTAssertEqual(e.status, .won)
}
```

- [ ] **Step 2: Run to verify they fail**

Expected: FAIL (`interact` undefined).

- [ ] **Step 3: Implement interact (terminal freeze already covered by guards)**

Add the intent:
```swift
    mutating func interact() {
        guard status == .playing else { return }
        if tile(at: grub) == .stairs {
            status = .won
        }
    }
```

Note: `setMove`, `update`, and `attack` already early-return on `status != .playing`, so the terminal-freeze test passes without further change.

- [ ] **Step 4: Run to verify they pass**

Run the 4 new tests. Expected: PASS.

- [ ] **Step 5: Run the full suite (regression gate)**

Run the whole-suite command. Expected: `** TEST SUCCEEDED **`. Confirm the engine test count is ~18 and the 28 prior tests still pass.

- [ ] **Step 6: Commit**

```bash
git add GrubIOS/Descent/DescentEngine.swift GrubIOSTests/DescentEngineTests.swift
git commit -m "feat(descent): win/death + terminal-state freeze"
```

---

## Chunk 3: Views, entry point, art, and on-device verification

Goal: make the engine playable on the simulator and judge the feel. SwiftUI views are verified by compile + an `ImageRenderer` smoke test (the existing `AtmosphereSplitTests` pattern) + manual play.

### Task 9: `DescentSceneView` (Canvas renderer)

**Files:**
- Create: `GrubIOS/Descent/DescentSceneView.swift`
- Test: `GrubIOSTests/DescentSceneSmokeTests.swift`

- [ ] **Step 1: Write the failing smoke test**

Create `GrubIOSTests/DescentSceneSmokeTests.swift`:
```swift
import XCTest
import SwiftUI
@testable import GrubIOS

@MainActor
final class DescentSceneSmokeTests: XCTestCase {
    func test_scene_renders_without_crash() {
        let engine = DescentEngine(layout: DescentEngine.prototypeRoom)
        let renderer = ImageRenderer(content:
            DescentSceneView(engine: engine)
                .frame(width: 330, height: 450)
        )
        XCTAssertNotNil(renderer.uiImage, "scene should render to an image")
    }

    // The shipped room is hand-authored — guard the floor-1-passable invariant
    // so a future edit can't accidentally wall off the stairs.
    func test_prototype_room_is_passable_without_combat() {
        let engine = DescentEngine(layout: DescentEngine.prototypeRoom)
        XCTAssertTrue(engine.hasStaticPathToStairs())
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Expected: FAIL (`DescentSceneView` and `DescentEngine.prototypeRoom` undefined).

- [ ] **Step 3: Add the prototype room + implement the scene**

Add to `DescentEngine.swift` (the prototype's authored room, 11×15 per spec, with an `E`→`>` route around the slime):
```swift
extension DescentEngine {
    /// The single hand-authored prototype room (11 wide x 15 tall).
    /// Border walls, a couple of interior wall clumps, one slime, a clear
    /// non-combat path from entry to stairs (floor-1-passable invariant).
    static let prototypeRoom: [String] = [
        "###########",
        "#E........#",
        "#.........#",
        "#..####...#",
        "#.....#...#",
        "#.....#...#",
        "#...S.#...#",
        "#.....#...#",
        "#.....#...#",
        "#...###...#",
        "#.........#",
        "#.........#",
        "#........>#",
        "#.........#",
        "###########",
    ]
}
```

Create `GrubIOS/Descent/DescentSceneView.swift`:
```swift
import SwiftUI

/// Renders a DescentEngine frame pixel-perfect. Pure presentation — no logic.
struct DescentSceneView: View {
    let engine: DescentEngine

    var body: some View {
        Canvas { ctx, size in
            let cols = engine.width, rows = engine.height
            guard cols > 0, rows > 0 else { return }
            let tile = (size.width / CGFloat(cols)).rounded(.down)
            let originX = ((size.width - tile * CGFloat(cols)) / 2).rounded()
            let originY = ((size.height - tile * CGFloat(rows)) / 2).rounded()
            func rect(_ x: Int, _ y: Int) -> CGRect {
                CGRect(x: originX + CGFloat(x) * tile, y: originY + CGFloat(y) * tile,
                       width: tile, height: tile)
            }

            // Tiles
            for y in 0..<rows {
                for x in 0..<cols {
                    let t = engine.tiles[y][x]
                    let color: Color
                    switch t {
                    case .wall:   color = GrubPalette.deepMoss
                    case .stairs: color = GrubPalette.yellow.opacity(0.85)
                    default:      color = GrubPalette.moss.opacity(0.35)
                    }
                    ctx.fill(Path(rect(x, y)), with: .color(color))
                }
            }

            // Enemies (slime): PNG if present else procedural spiky red blob.
            for enemy in engine.enemies {
                let r = rect(enemy.tile.x, enemy.tile.y).insetBy(dx: tile * 0.1, dy: tile * 0.1)
                if let _ = UIImage(named: "descent_slime") {
                    ctx.draw(Image("descent_slime").interpolation(.none).resizable(),
                             in: r)
                } else {
                    ctx.fill(Path(ellipseIn: r), with: .color(GrubPalette.red))
                    ctx.fill(Path(ellipseIn: r.insetBy(dx: tile*0.28, dy: tile*0.28)),
                             with: .color(.black.opacity(0.8)))   // angry core
                }
            }

            // Grub: directional PNG, dimmed/blinking during i-frames.
            let gr = rect(engine.grub.x, engine.grub.y)
            let blink = engine.isInIFrames ? 0.45 : 1.0
            let assetName = grubAsset(for: engine.facing)
            if let _ = UIImage(named: assetName) {
                ctx.opacity = blink
                ctx.draw(Image(assetName).interpolation(.none).resizable(), in: gr)
                ctx.opacity = 1.0
            } else {
                ctx.fill(Path(ellipseIn: gr.insetBy(dx: tile*0.1, dy: tile*0.1)),
                         with: .color(GrubPalette.green.opacity(blink)))
            }

            // Attack flash on the faced tile.
            if engine.attackFlashRemaining > 0 {
                let f = engine.grub + engine.facing
                ctx.fill(Path(rect(f.x, f.y)), with: .color(.white.opacity(0.5)))
            }
        }
        .background(GrubPalette.void_color)
    }

    /// Map a Direction8 to the existing 8-dir Grub asset names.
    private func grubAsset(for dir: Direction8) -> String {
        switch dir {
        case .n: return "grub_N"
        case .ne: return "grub_NE"
        case .e: return "grub_E"
        case .se: return "grub_SE"
        case .s: return "grub_S"
        case .sw: return "grub_SW"
        case .w: return "grub_W"
        case .nw: return "grub_NW"
        }
    }
}
```

Note: before relying on `grub_N`…`grub_NW` names, the implementer must confirm the actual asset names in `Assets.xcassets` (Step 3a).

- [ ] **Step 3a: Verify the directional Grub asset names**

Run:
```bash
ls ~/Documents/Code/grub/GrubIOS/GrubIOS/Assets.xcassets | grep -i grub
```
Expected: imageset names for the 8 directions. If they differ from `grub_N`…`grub_NW`, update `grubAsset(for:)` to match. (The PNG fallback ellipse renders regardless, so the scene still works if a name is wrong — but fix it for real sprites.)

- [ ] **Step 4: Generate project, run the smoke test**

```bash
cd ~/Documents/Code/grub/GrubIOS && /opt/homebrew/bin/xcodegen generate >/dev/null
```
Run `test_scene_renders_without_crash`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add GrubIOS/Descent/DescentSceneView.swift GrubIOS/Descent/DescentEngine.swift GrubIOSTests/DescentSceneSmokeTests.swift
git commit -m "feat(descent): scene Canvas renderer + prototype room"
```

---

### Task 10: `DescentControlsView` (joystick + buttons)

**Files:**
- Create: `GrubIOS/Descent/DescentControlsView.swift`

- [ ] **Step 1: Implement the controls view**

Create `GrubIOS/Descent/DescentControlsView.swift`:
```swift
import SwiftUI

/// Left thumb: drag joystick (8-way quantized). Right thumb: Attack / Interact.
/// Emits intents via closures — holds no game state.
struct DescentControlsView: View {
    var onMove: (Direction8?) -> Void
    var onAttack: () -> Void
    var onInteract: () -> Void
    var interactEnabled: Bool

    @State private var knob: CGSize = .zero
    private let radius: CGFloat = 55

    var body: some View {
        HStack(alignment: .bottom) {
            joystick
            Spacer()
            buttons
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 36)
    }

    private var joystick: some View {
        ZStack {
            Circle().fill(GrubPalette.moss.opacity(0.30)).frame(width: radius * 2, height: radius * 2)
            Circle().fill(GrubPalette.pale.opacity(0.7)).frame(width: 46, height: 46)
                .offset(knob)
        }
        .frame(width: radius * 2, height: radius * 2)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    let clamped = clamp(v.translation, to: radius)
                    knob = clamped
                    onMove(Direction8.from(dx: Double(clamped.width), dy: Double(clamped.height)))
                }
                .onEnded { _ in knob = .zero; onMove(nil) }
        )
    }

    private var buttons: some View {
        VStack(spacing: 16) {
            actionButton("DIG IN", color: GrubPalette.green, enabled: interactEnabled, action: onInteract)
            actionButton("HIT", color: GrubPalette.red, enabled: true, action: onAttack)
        }
    }

    private func actionButton(_ label: String, color: Color, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(GrubFont.size(12))
                .foregroundColor(GrubPalette.void_color)
                .frame(width: 84, height: 64)
                .background(color.opacity(enabled ? 0.9 : 0.3))
        }
        .disabled(!enabled)
        .buttonStyle(PixelButtonStyle())
    }

    private func clamp(_ t: CGSize, to r: CGFloat) -> CGSize {
        let mag = (t.width * t.width + t.height * t.height).squareRoot()
        guard mag > r, mag > 0 else { return t }
        return CGSize(width: t.width / mag * r, height: t.height / mag * r)
    }
}
```

Note: `PixelButtonStyle` and `GrubFont`/`GrubPalette` already exist in the app (used by `ContentView`). No new style needed.

- [ ] **Step 2: Generate + build**

```bash
cd ~/Documents/Code/grub/GrubIOS && /opt/homebrew/bin/xcodegen generate >/dev/null && \
xcodebuild -scheme GrubIOS -destination 'id=B30DE184-06D2-4A74-8EC5-24DB2377A109' build 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add GrubIOS/Descent/DescentControlsView.swift
git commit -m "feat(descent): joystick + action button controls"
```

---

### Task 11: `DescentView` container + `TimelineView` loop

**Files:**
- Create: `GrubIOS/Descent/DescentView.swift`

- [ ] **Step 1: Implement the container**

Create `GrubIOS/Descent/DescentView.swift`:
```swift
import SwiftUI

/// Hosts the scene + controls, drives the engine from a TimelineView loop,
/// and shows the win/death result card. Self-contained; takes a dismiss closure.
struct DescentView: View {
    var onExit: () -> Void

    @State private var engine = DescentEngine(layout: DescentEngine.prototypeRoom)
    @State private var lastTick: TimeInterval? = nil

    var body: some View {
        ZStack {
            GrubPalette.void_color.ignoresSafeArea()

            TimelineView(.animation) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                // Render the scene; advance the engine as a side-effect of the tick.
                DescentSceneView(engine: engine)
                    .ignoresSafeArea()
                    .onChange(of: now) { _, t in step(to: t) }
            }

            // Hearts HUD (top-left)
            VStack {
                HStack(spacing: 4) {
                    ForEach(0..<engine.tuning.startHearts, id: \.self) { i in
                        Image(systemName: i < engine.hearts ? "heart.fill" : "heart")
                            .foregroundColor(GrubPalette.red)
                    }
                    Spacer()
                }
                .padding(.horizontal, 18).padding(.top, 12)
                Spacer()
            }

            // Controls
            VStack {
                Spacer()
                DescentControlsView(
                    onMove: { engine.setMove($0) },
                    onAttack: { engine.attack() },
                    onInteract: { engine.interact() },
                    interactEnabled: engine.tile(at: engine.grub) == .stairs
                )
            }

            if engine.status != .playing { resultCard }
        }
        .statusBarHidden()
    }

    private func step(to t: TimeInterval) {
        defer { lastTick = t }
        guard let last = lastTick else { return }
        let dt = min(t - last, 1.0 / 20.0)        // clamp to avoid huge jumps
        guard dt > 0 else { return }
        engine.update(dt)
    }

    private var resultCard: some View {
        VStack(spacing: 20) {
            Text(engine.status == .won ? "YOU MADE IT" : "YOU DIED")
                .font(GrubFont.size(20))
                .foregroundColor(engine.status == .won ? GrubPalette.green : GrubPalette.red)
            Button(action: onExit) {
                Text("BACK")
                    .font(GrubFont.size(14))
                    .foregroundColor(GrubPalette.void_color)
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background(GrubPalette.pale)
            }
            .buttonStyle(PixelButtonStyle())
        }
        .padding(36)
        .background(GrubPalette.void_color.opacity(0.92))
    }
}
```

Note on the loop: `TimelineView(.animation)` re-evaluates each frame; `onChange(of: now)` calls `step(to:)` which advances the engine by the real delta (clamped). This keeps the engine pure (it never reads the clock) while the view owns timing.

- [ ] **Step 2: Generate + build**

```bash
cd ~/Documents/Code/grub/GrubIOS && /opt/homebrew/bin/xcodegen generate >/dev/null && \
xcodebuild -scheme GrubIOS -destination 'id=B30DE184-06D2-4A74-8EC5-24DB2377A109' build 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add GrubIOS/Descent/DescentView.swift
git commit -m "feat(descent): container view with TimelineView update loop"
```

---

### Task 12: DEBUG entry point (DIG routing + headless launch hook)

**Files:**
- Modify: `GrubIOS/ContentView.swift`

- [ ] **Step 1: Find the DIG action and the ContentView body root**

Run:
```bash
grep -n "ui_btn_dig\|showForageOverlay\|GRUB_AUTOSTART\|struct ContentView" ~/Documents/Code/grub/GrubIOS/GrubIOS/ContentView.swift
```
Note the DIG action closure (currently `game.audio.play(.dig); game.showForageOverlay = true`) and the `ContentView` `body`'s root container.

- [ ] **Step 2: Add a DEBUG state flag + fullScreenCover to `ContentView`**

In `struct ContentView`, add near its other `@State`/`@ObservedObject` properties:
```swift
    #if DEBUG
    @State private var showDescentPrototype = false
    #endif
```

Attach a `fullScreenCover` to the outermost view in `ContentView.body` (alongside the existing modifiers like `.statusBarHidden()`):
```swift
        #if DEBUG
        .fullScreenCover(isPresented: $showDescentPrototype) {
            DescentView(onExit: { showDescentPrototype = false })
        }
        .onAppear {
            if ProcessInfo.processInfo.environment["GRUB_DESCENT"] == "1" {
                showDescentPrototype = true
            }
        }
        #endif
```

- [ ] **Step 3: Route DIG → prototype in DEBUG only**

The DIG action lives in `ActionButtonsView`, which has its own `game` reference but not the `ContentView` flag. Pass a DEBUG callback down. In `ActionButtonsView`, add a property:
```swift
    #if DEBUG
    var onDebugDescent: () -> Void = {}
    #endif
```
Change the DIG `ActionButton` action to:
```swift
            ActionButton(icon: { navIcon("ui_btn_dig", fallback: PixelIcon.shovel(size: 30)) }, label: "DIG") {
                #if DEBUG
                onDebugDescent()
                #else
                game.audio.play(.dig)
                game.showForageOverlay = true
                #endif
            }
```
And where `ContentView` instantiates `ActionButtonsView(game: game)`, pass the callback in DEBUG:
```swift
            #if DEBUG
            ActionButtonsView(game: game, onDebugDescent: { showDescentPrototype = true })
            #else
            ActionButtonsView(game: game)
            #endif
```

- [ ] **Step 4: Generate + build**

```bash
cd ~/Documents/Code/grub/GrubIOS && /opt/homebrew/bin/xcodegen generate >/dev/null && \
xcodebuild -scheme GrubIOS -destination 'id=B30DE184-06D2-4A74-8EC5-24DB2377A109' build 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Run the full suite (regression gate)**

Run the whole-suite command. Expected: `** TEST SUCCEEDED **` (all engine + smoke + 28 prior tests).

- [ ] **Step 6: Commit**

```bash
git add GrubIOS/ContentView.swift
git commit -m "feat(descent): DEBUG-only DIG entry point + GRUB_DESCENT launch hook"
```

---

### Task 13: Generate + wire the fanged-slime art

**Files:**
- Create: `GrubIOS/Assets.xcassets/descent_slime.imageset/` (PNG + Contents.json)

- [ ] **Step 1: Generate the slime via PixelLab**

Use the PixelLab MCP to create a **top-down** fanged slime: dark/red palette, spikes, fangs, angry red eyes — clearly distinct from Grub's soft green round blob. Single top-down view is sufficient (review pack of candidates). Launch the notify-on-ready poller so completion pings automatically:
```bash
~/Documents/Code/grub/GrubIOS/scripts/pixellab_wait.sh object <object_id> 12
```
(run with the Bash tool's `run_in_background: true`).

- [ ] **Step 2: Pick the best candidate + post-process**

Download candidates, build a contact sheet with PIL, Read the composite (never Read tiny single sprites — CLAUDE.md Rule 0.6), pick the best, clean transparency. Save the final PNG to a temp path.

- [ ] **Step 3: Create the imageset (same pattern as ui_btn_*)**

```bash
cd ~/Documents/Code/grub/GrubIOS/GrubIOS/Assets.xcassets
mkdir -p descent_slime.imageset
cp <final_slime_png> descent_slime.imageset/descent_slime.png
cat > descent_slime.imageset/Contents.json <<'JSON'
{
  "images" : [
    { "filename" : "descent_slime.png", "idiom" : "universal", "scale" : "1x" },
    { "idiom" : "universal", "scale" : "2x" },
    { "idiom" : "universal", "scale" : "3x" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON
```
(The scene already prefers `descent_slime` when present — Task 9.)

- [ ] **Step 4: Build to confirm the asset resolves**

```bash
cd ~/Documents/Code/grub/GrubIOS && /opt/homebrew/bin/xcodegen generate >/dev/null && \
xcodebuild -scheme GrubIOS -destination 'id=B30DE184-06D2-4A74-8EC5-24DB2377A109' build 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add GrubIOS/Assets.xcassets/descent_slime.imageset
git commit -m "feat(descent): fanged-slime enemy art"
```

---

### Task 14: On-device verification (the actual feel gate)

**Files:** none (verification only)

- [ ] **Step 1: Boot, install, launch straight into the Descent**

```bash
SIM=B30DE184-06D2-4A74-8EC5-24DB2377A109
DD=~/Library/Developer/Xcode/DerivedData/GrubIOS-gtphglkdlvycrrdddhaiuyxtcdaj/Build/Products/Debug-iphonesimulator
APP="$DD/GrubIOS.app"
xcrun simctl boot $SIM 2>/dev/null; sleep 2
xcrun simctl install $SIM "$APP"
BID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP/Info.plist")
xcrun simctl terminate $SIM "$BID" 2>/dev/null
SIMCTL_CHILD_GRUB_DESCENT=1 xcrun simctl launch $SIM "$BID"
sleep 4
xcrun simctl io $SIM screenshot /tmp/descent_scene.png
```

- [ ] **Step 2: Inspect the screenshot**

Crop/downscale with PIL and Read the result (safe size). Confirm: room renders, Grub at entry, slime visible, hearts HUD, joystick + HIT/DIG IN buttons. Fix any layout issues.

- [ ] **Step 3: Hand off to Jesse for the feel judgment (SC2 gate)**

This is the whole point of the prototype. Present the build to Jesse to play and judge the snappy feel: movement responsiveness, attack timing, slime threat. Capture his verdict:
- **Feel approved** → proceed to Phase 2 (floors/loot/HUD/share) — a new spec+plan.
- **Feel rejected** → record specific tuning or model feedback (e.g. grid-stepping vs free movement) and iterate `DescentTuning` / the engine; the direction spec's movement decision may be revisited.

- [ ] **Step 4: Update memory**

Append the prototype outcome to `~/.claude/projects/-Users-jessedev-Documents-Code-grub/memory/descent-direction.md` (files created, tuning values, feel verdict, next step).

---

## Done criteria for this plan

- All engine logic unit-tested; full suite green (`** TEST SUCCEEDED **`).
- The prototype launches (DEBUG DIG or `GRUB_DESCENT=1`) into a playable room.
- Grub moves 8-way on a grid, attacks the slime, takes contact damage with i-frames, wins on stairs, dies at 0 hearts.
- Real slime art renders.
- Release builds unaffected; nothing persisted.
- Jesse has played it and rendered a feel verdict.
