# Burrow Phase 1 (Save + Time) Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the pixel-burrow home screen a persistent, real-time game: the save survives relaunches, digs regrow, finds get buried while you're away, Belly/Joy decay, and FEED/DIG/pet run through pure, unit-tested rules.

**Architecture:** Three layers, one direction of dependency: `BurrowHomeView` → `BurrowHomeModel` (view model: FX, toasts, persistence) → `BurrowRules` (pure static functions, injected clock + RNG) → `BurrowSave` (Codable state) persisted by `BurrowStore` as JSON. Spec: `docs/superpowers/specs/2026-11-10-burrow-mechanics-design.md` (read "Stat roles", "Architecture", "Rules API", "Rules §1–§3").

**Tech Stack:** Swift 5.9, SwiftUI, iOS 17, XCTest, XcodeGen (`project.yml` globs `GrubIOS/` and `GrubIOSTests/`, so **run `xcodegen generate` after adding any file**).

---

## Ground rules for this phase

- **Phase 1 only has the 4 existing finds** (berry, amber, bone, crystal). Root, mushroom, honeydew and shell arrive in phase 2 with their sprites. So in phase 1: the only food is berry, bury weights are berry 30 / crystal 8 / amber 7 / bone 7, and `fresh` buries berry, amber, crystal (phase 2 changes the amber to root, per spec).
- **Phase 1 starts at `.larva`** named `"GRUB"`. The egg/hatch flow is phase 4.
- **The save holds every spec field from day one** (stage, eggCracks, placed, eaten, lineage, tint, adult, specimens…) so later phases never need a save migration. Unused fields just keep their defaults.
- **Joy from meals:** with one food kind, only the first berry after a non-berry (or the very first meal) gives Joy. That's correct per the rules; real variety arrives in phase 2.
- **Deferred to phase 2:** the spec's pacing-regression test (a port of `docs/burrow/stat-sim.py`). It needs multiple foods and decor placement to mean anything.
- **Saving every minute is intended:** each 60 s tick moves `lastTick`, so the save changes and is written. The file is tiny.
- **Commits:** this repo's branch `the-deep` has unrelated uncommitted work (`GrubDeepHomeView.swift`, asset catalogs, `GrubIOSApp.swift`). The **Commit** steps below are checkpoints: run them **only if Jesse has said to commit**, and stage **only the files listed in that step** (never `git add -A`). Otherwise skip them.
- **Commands** run from `/Users/jessedev/Documents/Code/grub/GrubIOS`. Simulator: iPhone 13, id `8AABF67E-2193-4949-8A0E-0954E9789898` (booted). Shorthand used below:

```bash
# TEST (one class):  replace <Class>
xcodebuild test -project GrubIOS.xcodeproj -scheme GrubIOS -destination 'id=8AABF67E-2193-4949-8A0E-0954E9789898' -derivedDataPath build/dd -only-testing:GrubIOSTests/<Class> 2>&1 | grep -E "error:|Test Case.*(passed|failed)|Executed|TEST (SUCCEEDED|FAILED)" | tail -40
```

```bash
# BUILD
xcodebuild -project GrubIOS.xcodeproj -scheme GrubIOS -configuration Debug -destination 'id=8AABF67E-2193-4949-8A0E-0954E9789898' -derivedDataPath build/dd build 2>&1 | grep -E "error:|BUILD" | head -20
```

## File map

| File | Status | Responsibility |
|---|---|---|
| `GrubIOS/Burrow/BurrowTypes.swift` | create | `Species`, `GrubStage`, `FindKind` (data only), `BuriedFind`, `Specimen` |
| `GrubIOS/Burrow/BurrowSave.swift` | create | `BurrowSave` (all state + `fresh`) and `BurrowStore` (JSON file I/O) |
| `GrubIOS/Burrow/BurrowRules.swift` | create | `BurrowEvent`, `Refusal`, `BurrowResult`, `BurrowRules` (advance, dig, feed, pet) |
| `GrubIOS/Burrow/BurrowSpots.swift` | create | the 8 dig-spot `CellAnchor`s |
| `GrubIOS/Burrow/BurrowArt.swift` | modify | `FindKind` enum → `extension FindKind { var sprite }`; add sulk frame to `GrubArt` |
| `GrubIOS/Burrow/BurrowHomeModel.swift` | rewrite | view model over `BurrowSave`; events → FX; persistence; DEBUG launch args |
| `GrubIOS/Burrow/BurrowHomeView.swift` | modify | markers by spot, HAPPY tag, sulk pose, 60 s tick, scene phase, demo script |
| `GrubIOSTests/BurrowStoreTests.swift` | create | save round-trip, missing/corrupt/future files |
| `GrubIOSTests/BurrowRulesTests.swift` | create | timers, catch-up, dig/bonus, feed, pet |

---

## Chunk 1: Types, save, store

### Task 1: Core types

**Files:**
- Create: `GrubIOS/Burrow/BurrowTypes.swift`
- Modify: `GrubIOS/Burrow/BurrowArt.swift` (the `enum FindKind` block, currently ~lines 208–250)
- Modify: `GrubIOS/Burrow/BurrowHomeModel.swift:50` (`edible` → `isFood`)

- [ ] **Step 1: Create `BurrowTypes.swift`**

```swift
import Foundation

/// The six adults from the species contact sheet (docs/burrow/species-contact-sheet.html).
enum Species: String, Codable, CaseIterable, CodingKeyRepresentable {
    case grub, horn, fuzz, shell, claws, stalk

    var label: String { rawValue.uppercased() }

    var blurb: String {
        switch self {
        case .grub:  return "THE ORIGINAL"
        case .horn:  return "STUBBORN DIGGER"
        case .fuzz:  return "SOFT, SHEDS TUFTS"
        case .shell: return "ROLLS UP TIGHT"
        case .claws: return "BORN TO DIG"
        case .stalk: return "SEES ROUND CORNERS"
        }
    }

    /// Body colour, 0xRRGGBB.
    var color: UInt32 {
        switch self {
        case .grub:  return 0x4ecca3
        case .horn:  return 0x8f6fe0
        case .fuzz:  return 0xf5a623
        case .shell: return 0x6f8fb0
        case .claws: return 0xc97b3a
        case .stalk: return 0xed93b1
        }
    }
}

enum GrubStage: String, Codable { case egg, larva, adult }

/// Something you can dig up. Phase 1 has the four finds that already have sprites;
/// phase 2 adds root, mushroom, honeydew and shell.
enum FindKind: String, Codable, CaseIterable, Identifiable, CodingKeyRepresentable {
    case berry, amber, bone, crystal

    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
    var isFood: Bool { self == .berry }

    /// The species this find nudges the molt odds toward.
    var leansTo: Species {
        switch self {
        case .berry:   return .grub
        case .amber:   return .fuzz
        case .bone:    return .claws
        case .crystal: return .horn
        }
    }

    /// Relative chance of being buried (spec "Finds and digging").
    var buryWeight: Int {
        switch self {
        case .berry:   return 30
        case .amber:   return 7
        case .bone:    return 7
        case .crystal: return 8
        }
    }

    /// Auto-feed tries foods in this order.
    static let feedOrder: [FindKind] = allCases.filter(\.isFood)
}

struct BuriedFind: Codable, Equatable {
    var spot: Int        // index into BurrowSpots.anchors
    var kind: FindKind
}

struct Specimen: Codable, Equatable {
    var name: String
    var species: Species
    var pinnedAt: Date
}
```

- [ ] **Step 2: Turn the old `FindKind` enum in `BurrowArt.swift` into a sprite extension**

Replace the header of the block (the `enum FindKind…` line through `var edible…`) so only the sprite remains:

```swift
// Before:
enum FindKind: String, CaseIterable, Identifiable {
    case berry, amber, bone, crystal
    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
    var edible: Bool { self == .berry }

    var sprite: PixelBuffer {
// After:
extension FindKind {
    var sprite: PixelBuffer {
```

(The `switch self { … }` body and closing braces stay exactly as they are.)

- [ ] **Step 3: Keep the old model compiling until Task 8 rewrites it**
  - `BurrowHomeModel.swift` already declares its own `struct BuriedFind` (line 5), which would clash with the new one. Rename the **old** struct to `HomeFind` everywhere it's used: `BurrowHomeModel.swift` line 5 (declaration), lines 34–38 (`@Published var finds: [BuriedFind]` and its five `BuriedFind(...)` initialisers), line 57 (`func dig(_ find: BuriedFind, …)`), and `BurrowHomeView.swift` line 99 (`private func marker(_ f: BuriedFind, …)`).
  - Replace `edible` with `isFood`: `$0.key.edible` → `$0.key.isFood` (line 50) and `$0.edible` → `$0.isFood` in `feed()`.

  `HomeFind` is deleted in Task 8.

- [ ] **Step 4: Regenerate and build**

Run: `xcodegen generate && ` + BUILD
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit** (only if Jesse has said to commit)

```bash
git add GrubIOS/Burrow/BurrowTypes.swift GrubIOS/Burrow/BurrowArt.swift GrubIOS/Burrow/BurrowHomeModel.swift GrubIOS.xcodeproj/project.pbxproj
git commit -m "feat(burrow): core types for the burrow loop"
```

### Task 2: `BurrowSave`

**Files:**
- Create: `GrubIOS/Burrow/BurrowSave.swift`
- Test: `GrubIOSTests/BurrowStoreTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import GrubIOS

final class BurrowStoreTests: XCTestCase {
    let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func test_fresh_save_matches_phase1_spec() {
        let s = BurrowSave.fresh(now: t0)
        XCTAssertEqual(s.version, BurrowSave.currentVersion)
        XCTAssertEqual(s.stage, .larva)
        XCTAssertEqual(s.name, "GRUB")
        XCTAssertEqual([s.belly, s.joy, s.molt, s.digs], [6, 6, 0, 3])
        XCTAssertEqual(s.bag, [.berry: 1])
        XCTAssertEqual(s.buried, [BuriedFind(spot: 0, kind: .berry),
                                  BuriedFind(spot: 1, kind: .amber),
                                  BuriedFind(spot: 2, kind: .crystal)])
        XCTAssertTrue(s.holes.isEmpty && s.placed.isEmpty && s.eaten.isEmpty && s.specimens.isEmpty)
        XCTAssertEqual(s.lastTick, t0)
        XCTAssertEqual(s.lastPetAt, t0.addingTimeInterval(-86_400))
    }

    func test_save_json_round_trip() throws {
        var s = BurrowSave.fresh(now: t0)
        s.placed = [1: .amber]
        s.eaten = [.berry: 2]
        s.lastMeal = .berry
        s.lineage = .horn
        s.specimens = [Specimen(name: "BOB", species: .stalk, pinnedAt: t0)]
        let data = try JSONEncoder().encode(s)
        XCTAssertEqual(try JSONDecoder().decode(BurrowSave.self, from: data), s)
        // Enum-keyed dictionaries must encode as readable objects, not arrays.
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(json.contains("\"berry\":1"), json)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodegen generate && ` + TEST with `<Class>` = `BurrowStoreTests`
Expected: build error — `cannot find 'BurrowSave' in scope`.

- [ ] **Step 3: Create `BurrowSave.swift` (the struct only; the store is Task 3)**

```swift
import Foundation

/// All burrow game state. Pure data — the rules live in `BurrowRules`.
/// Every spec field exists from version 1 so later phases need no migration.
struct BurrowSave: Codable, Equatable {
    static let currentVersion = 1

    var version = BurrowSave.currentVersion
    var stage: GrubStage
    var name: String
    var eggCracks = 0
    var belly: Int
    var joy: Int
    var molt: Int
    var digs: Int
    var buried: [BuriedFind]
    var holes: [Int] = []
    var bag: [FindKind: Int]
    var placed: [Int: FindKind] = [:]
    var eaten: [FindKind: Int] = [:]
    var lastMeal: FindKind?
    var lineage: Species?
    var tint: Species?
    var adult: Species?
    var specimens: [Specimen] = []
    var lastTick: Date
    var digTimer: TimeInterval = 0
    var buryTimer: TimeInterval = 0
    var bellyTimer: TimeInterval = 0
    var joyTimer: TimeInterval = 0
    var lastPetAt: Date

    /// A brand-new game. Phase 1 starts at `.larva` named GRUB (phase 4 switches to `.egg`).
    static func fresh(now: Date) -> BurrowSave {
        BurrowSave(stage: .larva, name: "GRUB",
                   belly: 6, joy: 6, molt: 0, digs: 3,
                   buried: [BuriedFind(spot: 0, kind: .berry),
                            BuriedFind(spot: 1, kind: .amber),
                            BuriedFind(spot: 2, kind: .crystal)],
                   bag: [.berry: 1],
                   lastTick: now,
                   lastPetAt: now.addingTimeInterval(-86_400))
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: TEST with `BurrowStoreTests`
Expected: 2 tests passed. (If `"berry":1` fails because the JSON shows `["berry",1]`, `CodingKeyRepresentable` is missing from `FindKind`.)

- [ ] **Step 5: Commit** (only if approved)

```bash
git add GrubIOS/Burrow/BurrowSave.swift GrubIOSTests/BurrowStoreTests.swift GrubIOS.xcodeproj/project.pbxproj
git commit -m "feat(burrow): BurrowSave state + fresh game"
```

### Task 3: `BurrowStore`

**Files:**
- Modify: `GrubIOS/Burrow/BurrowSave.swift` (append)
- Test: `GrubIOSTests/BurrowStoreTests.swift` (append)

- [ ] **Step 1: Write the failing tests** (add inside `BurrowStoreTests`)

```swift
    private func tempDir() -> URL {
        let d = FileManager.default.temporaryDirectory.appendingPathComponent("burrow-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: d) }
        return d
    }

    func test_store_missing_file_gives_fresh() {
        let store = BurrowStore(directory: tempDir())
        XCTAssertEqual(store.load(now: t0), .fresh(now: t0))
    }

    func test_store_round_trip() throws {
        let store = BurrowStore(directory: tempDir())
        var s = BurrowSave.fresh(now: t0)
        s.digs = 1
        try store.save(s)
        XCTAssertEqual(store.load(now: t0.addingTimeInterval(99)), s)
    }

    func test_store_corrupt_file_is_moved_aside() throws {
        let dir = tempDir()
        let store = BurrowStore(directory: dir)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: store.fileURL)
        XCTAssertEqual(store.load(now: t0), .fresh(now: t0))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.corruptURL.path))
    }

    func test_store_future_version_is_moved_aside() throws {
        let dir = tempDir()
        let store = BurrowStore(directory: dir)
        var s = BurrowSave.fresh(now: t0)
        s.version = BurrowSave.currentVersion + 1
        try store.save(s)
        XCTAssertEqual(store.load(now: t0), .fresh(now: t0))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.corruptURL.path))
    }
```

- [ ] **Step 2: Run to verify it fails** — TEST `BurrowStoreTests`. Expected: `cannot find 'BurrowStore' in scope`.

- [ ] **Step 3: Append `BurrowStore` to `BurrowSave.swift`**

```swift
/// Reads and writes `burrow.json`. Unreadable or newer-version files are renamed
/// `burrow.corrupt.json` (never deleted) and a fresh game starts.
struct BurrowStore {
    let directory: URL
    var fileURL: URL { directory.appendingPathComponent("burrow.json") }
    var corruptURL: URL { directory.appendingPathComponent("burrow.corrupt.json") }

    static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    init(directory: URL = BurrowStore.defaultDirectory) {
        self.directory = directory
    }

    func load(now: Date = Date()) -> BurrowSave {
        guard let data = try? Data(contentsOf: fileURL) else { return .fresh(now: now) }
        struct VersionOnly: Decodable { let version: Int }
        if let v = try? JSONDecoder().decode(VersionOnly.self, from: data),
           v.version <= BurrowSave.currentVersion,
           let save = try? JSONDecoder().decode(BurrowSave.self, from: data) {
            return save
        }
        moveAside()
        return .fresh(now: now)
    }

    func save(_ s: BurrowSave) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(s).write(to: fileURL, options: .atomic)
    }

    /// Delete the save (DEBUG `-burrowReset`).
    func reset() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func moveAside() {
        let fm = FileManager.default
        try? fm.removeItem(at: corruptURL)
        try? fm.moveItem(at: fileURL, to: corruptURL)
    }
}
```

- [ ] **Step 4: Run to verify it passes** — TEST `BurrowStoreTests`. Expected: 6 tests passed.

- [ ] **Step 5: Commit** (only if approved)

```bash
git add GrubIOS/Burrow/BurrowSave.swift GrubIOSTests/BurrowStoreTests.swift
git commit -m "feat(burrow): JSON save store with corrupt-file quarantine"
```

---

## Chunk 2: Rules

All rules tests share this file header and helpers.

### Task 4: `advance` — timers and catch-up

**Files:**
- Create: `GrubIOS/Burrow/BurrowRules.swift`
- Create: `GrubIOSTests/BurrowRulesTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import GrubIOS

/// Deterministic RNG for tests (SplitMix64).
struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(_ seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

final class BurrowRulesTests: XCTestCase {
    let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let h: TimeInterval = 3600
    var rng = SeededRNG(42)

    /// A fresh larva at t0, customised by `edit`.
    func save(_ edit: (inout BurrowSave) -> Void = { _ in }) -> BurrowSave {
        var s = BurrowSave.fresh(now: t0)
        edit(&s)
        return s
    }

    func advance(_ s: BurrowSave, hours: Double) -> BurrowResult {
        BurrowRules.advance(s, to: t0.addingTimeInterval(hours * h), rng: &rng)
    }

    // MARK: digs

    func test_digs_regrow_one_per_3h_and_cap_at_3() {
        let s = save { $0.digs = 0 }
        XCTAssertEqual(advance(s, hours: 2.9).save.digs, 0)
        XCTAssertEqual(advance(s, hours: 3).save.digs, 1)
        XCTAssertEqual(advance(s, hours: 9).save.digs, 3)
        XCTAssertEqual(advance(s, hours: 30).save.digs, 3)
    }

    func test_dig_timer_carries_partial_time_below_cap() {
        let a = advance(save { $0.digs = 0 }, hours: 2).save          // 2 h banked
        let b = BurrowRules.advance(a, to: t0.addingTimeInterval(3 * h), rng: &rng).save
        XCTAssertEqual(b.digs, 1)
    }

    func test_dig_timer_does_not_bank_at_cap() {
        let a = advance(save { $0.digs = 3 }, hours: 2.9).save
        XCTAssertEqual(a.digTimer, 0)
    }

    // MARK: burying

    func test_buries_every_2h_up_to_4_in_distinct_spots() {
        let s = save { $0.buried = []; $0.holes = [0, 1, 2, 3, 4, 5, 6, 7] }
        XCTAssertEqual(advance(s, hours: 1.9).save.buried.count, 0)
        let one = advance(s, hours: 2)
        XCTAssertEqual(one.save.buried.count, 1)
        XCTAssertEqual(one.events.count, 1)
        guard case .buried(let spot, _) = one.events[0] else { return XCTFail("\(one.events)") }
        XCTAssertFalse(one.save.holes.contains(spot), "reburying a spot clears its hole")
        let full = advance(s, hours: 30).save
        XCTAssertEqual(full.buried.count, 4)
        XCTAssertEqual(Set(full.buried.map(\.spot)).count, 4)
        XCTAssertEqual(full.buryTimer, 0)
    }

    func test_bury_weights() {
        var counts: [FindKind: Int] = [:]
        for _ in 0..<10_000 { counts[BurrowRules.weightedKind(rng: &rng), default: 0] += 1 }
        let total = FindKind.allCases.reduce(0) { $0 + $1.buryWeight }
        for k in FindKind.allCases {
            let expected = Double(k.buryWeight) / Double(total)
            XCTAssertEqual(Double(counts[k] ?? 0) / 10_000, expected, accuracy: 0.02, "\(k)")
        }
    }

    // MARK: belly + joy

    func test_belly_drops_one_per_2h_to_zero() {
        let s = save { $0.belly = 3 }
        XCTAssertEqual(advance(s, hours: 4).save.belly, 1)
        XCTAssertEqual(advance(s, hours: 40).save.belly, 0)
    }

    func test_joy_drops_one_per_4h_plus_1h_per_decor() {
        XCTAssertEqual(advance(save { $0.belly = 10; $0.joy = 10 }, hours: 8).save.joy, 8)
        let decor = save { $0.belly = 10; $0.joy = 10; $0.placed = [0: .amber, 1: .bone] }   // 6 h period
        XCTAssertEqual(advance(decor, hours: 12).save.joy, 8)
    }

    func test_joy_drains_hourly_once_belly_hits_zero_mid_gap() {
        // Belly 1 → 0 at 2 h. Joy timer has 2 h banked, which pays at once on the 1 h period
        // (joy 9), then hourly at 3 h, 4 h, 5 h → 6. Without the switch it would be 9.
        let s = save { $0.belly = 1; $0.joy = 10 }
        XCTAssertEqual(advance(s, hours: 5).save.joy, 6)
    }

    func test_only_larva_runs_belly_and_joy() {
        let s = save { $0.stage = .egg; $0.digs = 0 }
        let r = advance(s, hours: 10).save
        XCTAssertEqual([r.belly, r.joy], [6, 6])
        XCTAssertEqual(r.digs, 3, "digs still regrow in every stage")
    }

    // MARK: clock edge cases

    func test_catch_up_is_capped_at_72h() {
        let long = save { $0.digs = 0; $0.lastTick = self.t0.addingTimeInterval(-30 * 86_400) }
        let capped = save { $0.digs = 0; $0.lastTick = self.t0.addingTimeInterval(-72 * self.h) }
        var r1 = SeededRNG(7), r2 = SeededRNG(7)
        XCTAssertEqual(BurrowRules.advance(long, to: t0, rng: &r1).save,
                       BurrowRules.advance(capped, to: t0, rng: &r2).save)
    }

    func test_clock_moving_backwards_only_resets_lastTick() {
        let s = save { $0.lastTick = self.t0.addingTimeInterval(self.h) }
        let r = BurrowRules.advance(s, to: t0, rng: &rng)
        var expected = s
        expected.lastTick = t0
        XCTAssertEqual(r.save, expected)
        XCTAssertTrue(r.events.isEmpty)
    }
}
```

- [ ] **Step 2: Run to verify it fails** — `xcodegen generate && ` + TEST `BurrowRulesTests`. Expected: `cannot find 'BurrowRules' in scope`.

- [ ] **Step 3: Create `BurrowRules.swift`**

```swift
import Foundation

enum Refusal: Equatable {
    case noDigs, nothingBuriedThere, noFood, notFood, tooFull, slotTaken,
         notDecor, notInBag, emptySlot, notMoltReady, wrongStage, badName
}

enum BurrowEvent: Equatable {
    case buried(spot: Int, kind: FindKind)
    case dugUp(spot: Int, kind: FindKind), bonusFind(spot: Int, kind: FindKind)
    case ate(FindKind, joyGained: Bool), petted(joyGained: Bool)
    case placed(slot: Int, kind: FindKind), removed(slot: Int, kind: FindKind)
    case moltReady
    case molted(Species), pinned(Specimen), named(String), eggCracked(stage: Int), hatched
    case refused(Refusal)
}

struct BurrowResult {
    var save: BurrowSave
    var events: [BurrowEvent] = []
}

/// The burrow game rules: pure functions of (save, now, rng). No UI, no timers.
/// Spec: docs/superpowers/specs/2026-11-10-burrow-mechanics-design.md
enum BurrowRules {
    static let maxStat = 10
    static let maxDigs = 3
    static let maxBuried = 4
    static let spotCount = 8
    static let moltGoal = 10
    static let happyJoy = 7
    static let bonusFindChance = 0.35

    static let digPeriod: TimeInterval = 3 * 3600
    static let buryPeriod: TimeInterval = 2 * 3600
    static let bellyPeriod: TimeInterval = 2 * 3600
    static let petCooldown: TimeInterval = 15 * 60
    static let maxCatchUp: TimeInterval = 72 * 3600
    static let step: TimeInterval = 60

    static func isHappy(_ s: BurrowSave) -> Bool { s.stage == .larva && s.joy >= happyJoy }
    static func isSulking(_ s: BurrowSave) -> Bool { s.stage == .larva && s.belly == 0 }

    /// 4 h + 1 h per placed decor (max 8 h); 1 h while sulking.
    static func joyPeriod(_ s: BurrowSave) -> TimeInterval {
        s.belly == 0 ? 3600 : TimeInterval(min(8, 4 + s.placed.count)) * 3600
    }

    // MARK: Time

    /// Apply the time since `lastTick` in 1-minute steps (capped at 72 h) so linked
    /// timers — e.g. belly hitting 0 mid-gap switching Joy to the hourly drain — are exact.
    static func advance(_ s0: BurrowSave, to now: Date,
                        rng: inout some RandomNumberGenerator) -> BurrowResult {
        var s = s0
        var events: [BurrowEvent] = []
        let elapsed = now.timeIntervalSince(s.lastTick)
        guard elapsed > 0 else {
            s.lastTick = now
            return BurrowResult(save: s)
        }
        var left = min(elapsed, maxCatchUp)
        while left > 0 {
            let dt = min(step, left)
            left -= dt

            if s.digs < maxDigs {
                s.digTimer += dt
                if s.digTimer >= digPeriod { s.digTimer -= digPeriod; s.digs += 1 }
            }
            if s.digs >= maxDigs { s.digTimer = 0 }

            if s.buried.count < maxBuried {
                s.buryTimer += dt
                if s.buryTimer >= buryPeriod {
                    s.buryTimer -= buryPeriod
                    if let f = bury(&s, rng: &rng) { events.append(.buried(spot: f.spot, kind: f.kind)) }
                }
            }
            if s.buried.count >= maxBuried { s.buryTimer = 0 }

            guard s.stage == .larva else { continue }

            if s.belly > 0 {
                s.bellyTimer += dt
                if s.bellyTimer >= bellyPeriod { s.bellyTimer -= bellyPeriod; s.belly -= 1 }
            } else {
                s.bellyTimer = 0
            }

            if s.joy > 0 {
                s.joyTimer += dt
                // A payout resets to 0 (not `-= period`): when the period shrinks to 1 h
                // (belly hits 0), banked time pays once, then the hourly drain starts clean.
                // test_joy_drains_hourly_once_belly_hits_zero_mid_gap pins this behaviour.
                if s.joyTimer >= joyPeriod(s) { s.joyTimer = 0; s.joy -= 1 }
            } else {
                s.joyTimer = 0
            }
        }
        s.lastTick = now
        return BurrowResult(save: s, events: events)
    }

    /// Bury one weighted-random find in a random free spot; clears that spot's hole.
    static func bury(_ s: inout BurrowSave, rng: inout some RandomNumberGenerator) -> BuriedFind? {
        let taken = Set(s.buried.map(\.spot))
        guard let spot = (0..<spotCount).filter({ !taken.contains($0) }).randomElement(using: &rng) else { return nil }
        let f = BuriedFind(spot: spot, kind: weightedKind(rng: &rng))
        s.buried.append(f)
        s.holes.removeAll { $0 == spot }
        return f
    }

    static func weightedKind(rng: inout some RandomNumberGenerator) -> FindKind {
        let total = FindKind.allCases.reduce(0) { $0 + $1.buryWeight }
        var r = Int.random(in: 0..<total, using: &rng)
        for k in FindKind.allCases {
            if r < k.buryWeight { return k }
            r -= k.buryWeight
        }
        return .berry
    }

    static func refuse(_ s: BurrowSave, _ why: Refusal) -> BurrowResult {
        BurrowResult(save: s, events: [.refused(why)])
    }
}
```

- [ ] **Step 4: Run to verify it passes** — TEST `BurrowRulesTests`. Expected: 11 tests passed.
  If `test_joy_drains_hourly_once_belly_hits_zero_mid_gap` gives 7, check that belly is processed **before** joy inside the step loop and that a joy payout resets `joyTimer` to 0.

- [ ] **Step 5: Commit** (only if approved)

```bash
git add GrubIOS/Burrow/BurrowRules.swift GrubIOSTests/BurrowRulesTests.swift GrubIOS.xcodeproj/project.pbxproj
git commit -m "feat(burrow): real-time rules with minute-step catch-up"
```

### Task 5: `dig` + bonus finds

**Files:**
- Modify: `GrubIOS/Burrow/BurrowRules.swift` (add to `enum BurrowRules`)
- Test: `GrubIOSTests/BurrowRulesTests.swift` (add to the class)

- [ ] **Step 1: Write the failing tests**

```swift
    // MARK: dig

    func test_dig_moves_find_to_bag_and_leaves_hole() {
        let r = BurrowRules.dig(save { $0.joy = 0 }, spot: 1, now: t0, rng: &rng)
        XCTAssertEqual(r.events, [.dugUp(spot: 1, kind: .amber)])
        XCTAssertEqual(r.save.digs, 2)
        XCTAssertEqual(r.save.bag, [.berry: 1, .amber: 1])
        XCTAssertEqual(r.save.holes, [1])
        XCTAssertFalse(r.save.buried.contains { $0.spot == 1 })
    }

    func test_dig_refusals() {
        XCTAssertEqual(BurrowRules.dig(save(), spot: 7, now: t0, rng: &rng).events, [.refused(.nothingBuriedThere)])
        let none = save { $0.digs = 0 }
        let r = BurrowRules.dig(none, spot: 0, now: t0, rng: &rng)
        XCTAssertEqual(r.events, [.refused(.noDigs)])
        XCTAssertEqual(r.save, none)
    }

    func test_bonus_find_only_when_happy_at_about_35_percent() {
        func bonusRate(joy: Int) -> Double {
            var hits = 0
            for _ in 0..<4000 {
                let s = save { $0.joy = joy; $0.buried = [BuriedFind(spot: 0, kind: .berry)] }
                let r = BurrowRules.dig(s, spot: 0, now: t0, rng: &rng)
                if r.events.contains(where: { if case .bonusFind = $0 { return true } else { return false } }) { hits += 1 }
            }
            return Double(hits) / 4000
        }
        XCTAssertEqual(bonusRate(joy: 7), 0.35, accuracy: 0.03)
        XCTAssertEqual(bonusRate(joy: 6), 0)
    }

    func test_bonus_find_lands_in_bag() {
        var r: BurrowResult
        repeat {
            r = BurrowRules.dig(save { $0.joy = 10; $0.bag = [:] }, spot: 0, now: t0, rng: &rng)
        } while r.events.count < 2
        guard case .bonusFind(0, let extra) = r.events[1] else { return XCTFail("\(r.events)") }
        XCTAssertEqual(r.save.bag.values.reduce(0, +), 2)
        XCTAssertGreaterThanOrEqual(r.save.bag[extra] ?? 0, 1)
    }
```

- [ ] **Step 2: Run to verify it fails** — TEST `BurrowRulesTests`. Expected: `type 'BurrowRules' has no member 'dig'`.

- [ ] **Step 3: Add `dig` to `BurrowRules`**

```swift
    // MARK: Digging

    /// Dig up the find at `spot`. Works in every stage. A happy grub (Joy ≥ 7) has a
    /// 35 % chance to turn up a bonus find.
    static func dig(_ s0: BurrowSave, spot: Int, now: Date,
                    rng: inout some RandomNumberGenerator) -> BurrowResult {
        guard let i = s0.buried.firstIndex(where: { $0.spot == spot }) else { return refuse(s0, .nothingBuriedThere) }
        guard s0.digs > 0 else { return refuse(s0, .noDigs) }
        var s = s0
        let f = s.buried.remove(at: i)
        s.digs -= 1
        s.holes.append(spot)
        s.bag[f.kind, default: 0] += 1
        var events: [BurrowEvent] = [.dugUp(spot: spot, kind: f.kind)]
        if isHappy(s), Double.random(in: 0..<1, using: &rng) < bonusFindChance {
            let extra = weightedKind(rng: &rng)
            s.bag[extra, default: 0] += 1
            events.append(.bonusFind(spot: spot, kind: extra))
        }
        return BurrowResult(save: s, events: events)
    }
```

- [ ] **Step 4: Run to verify it passes** — TEST `BurrowRulesTests`. Expected: 15 tests passed.

- [ ] **Step 5: Commit** (only if approved)

```bash
git add GrubIOS/Burrow/BurrowRules.swift GrubIOSTests/BurrowRulesTests.swift
git commit -m "feat(burrow): dig rule with happy bonus finds"
```

### Task 6: `feed` + `pet`

**Files:**
- Modify: `GrubIOS/Burrow/BurrowRules.swift`
- Test: `GrubIOSTests/BurrowRulesTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
    // MARK: feed

    func test_feed_auto_eats_berry() {
        let r = BurrowRules.feed(save(), kind: nil, now: t0)
        XCTAssertEqual(r.events, [.ate(.berry, joyGained: true)])
        XCTAssertEqual([r.save.belly, r.save.joy, r.save.molt], [9, 7, 1])
        XCTAssertNil(r.save.bag[.berry], "empty bag entries are removed")
        XCTAssertEqual(r.save.eaten, [.berry: 1])
        XCTAssertEqual(r.save.lastMeal, .berry)
    }

    func test_repeat_meal_gives_no_joy() {
        let s = save { $0.bag = [.berry: 2]; $0.lastMeal = .berry; $0.belly = 2 }
        let r = BurrowRules.feed(s, kind: nil, now: t0)
        XCTAssertEqual(r.events, [.ate(.berry, joyGained: false)])
        XCTAssertEqual(r.save.joy, 6)
    }

    func test_feed_works_while_sulking() {
        let r = BurrowRules.feed(save { $0.belly = 0 }, kind: .berry, now: t0)
        XCTAssertEqual(r.save.molt, 1)
        XCTAssertFalse(BurrowRules.isSulking(r.save))
    }

    func test_feed_refusals() {
        XCTAssertEqual(BurrowRules.feed(save { $0.bag = [:] }, kind: nil, now: t0).events, [.refused(.noFood)])
        XCTAssertEqual(BurrowRules.feed(save { $0.bag = [.crystal: 1] }, kind: .crystal, now: t0).events, [.refused(.notFood)])
        XCTAssertEqual(BurrowRules.feed(save { $0.bag = [:] }, kind: .berry, now: t0).events, [.refused(.notInBag)])
        let full = save { $0.belly = 10 }
        let r = BurrowRules.feed(full, kind: nil, now: t0)
        XCTAssertEqual(r.events, [.refused(.tooFull)])
        XCTAssertEqual(r.save, full, "nothing is used when too full")
        XCTAssertEqual(BurrowRules.feed(save { $0.stage = .egg }, kind: nil, now: t0).events, [.refused(.wrongStage)])
    }

    func test_molt_ready_fires_only_on_the_crossing() {
        let r = BurrowRules.feed(save { $0.molt = 9; $0.bag = [.berry: 2] }, kind: nil, now: t0)
        XCTAssertEqual(r.events.last, .moltReady)
        XCTAssertEqual(r.save.molt, 10)
        var again = r.save
        again.belly = 0
        XCTAssertFalse(BurrowRules.feed(again, kind: nil, now: t0).events.contains(.moltReady))
    }

    // MARK: pet

    func test_pet_gives_joy_at_most_once_per_15_min() {
        let a = BurrowRules.pet(save(), now: t0)
        XCTAssertEqual(a.events, [.petted(joyGained: true)])
        XCTAssertEqual(a.save.joy, 7)
        let b = BurrowRules.pet(a.save, now: t0.addingTimeInterval(14 * 60))
        XCTAssertEqual(b.events, [.petted(joyGained: false)])
        XCTAssertEqual(b.save.joy, 7)
        XCTAssertEqual(BurrowRules.pet(b.save, now: t0.addingTimeInterval(15 * 60)).save.joy, 8)
    }
```

- [ ] **Step 2: Run to verify it fails** — TEST `BurrowRulesTests`. Expected: `type 'BurrowRules' has no member 'feed'`.

- [ ] **Step 3: Add `feed` and `pet` to `BurrowRules`**

```swift
    // MARK: Care

    /// Eat a food (`kind == nil`: first food in feed order, preferring one different from
    /// the last meal). +3 Belly, +1 Molt, +1 Joy only for a change of food.
    static func feed(_ s0: BurrowSave, kind: FindKind?, now: Date) -> BurrowResult {
        guard s0.stage == .larva else { return refuse(s0, .wrongStage) }
        let food: FindKind
        if let k = kind {
            guard k.isFood else { return refuse(s0, .notFood) }
            guard s0.bag[k, default: 0] > 0 else { return refuse(s0, .notInBag) }
            food = k
        } else {
            let have = FindKind.feedOrder.filter { s0.bag[$0, default: 0] > 0 }
            guard let pick = have.first(where: { $0 != s0.lastMeal }) ?? have.first else { return refuse(s0, .noFood) }
            food = pick
        }
        guard s0.belly < maxStat else { return refuse(s0, .tooFull) }

        var s = s0
        s.bag[food, default: 0] -= 1
        if s.bag[food] == 0 { s.bag[food] = nil }
        s.belly = min(maxStat, s.belly + 3)
        let wasReady = s.molt >= moltGoal
        s.molt = min(moltGoal, s.molt + 1)
        s.eaten[food, default: 0] += 1
        let joyGained = food != s.lastMeal
        if joyGained { s.joy = min(maxStat, s.joy + 1) }
        s.lastMeal = food

        var events: [BurrowEvent] = [.ate(food, joyGained: joyGained)]
        if !wasReady && s.molt >= moltGoal { events.append(.moltReady) }
        return BurrowResult(save: s, events: events)
    }

    /// Hearts every time; +1 Joy at most once per 15 minutes.
    static func pet(_ s0: BurrowSave, now: Date) -> BurrowResult {
        guard s0.stage == .larva else { return refuse(s0, .wrongStage) }
        var s = s0
        let gained = now.timeIntervalSince(s.lastPetAt) >= petCooldown
        if gained {
            s.joy = min(maxStat, s.joy + 1)
            s.lastPetAt = now
        }
        return BurrowResult(save: s, events: [.petted(joyGained: gained)])
    }
```

- [ ] **Step 4: Run to verify it passes** — TEST `BurrowRulesTests`. Expected: 21 tests passed.

- [ ] **Step 5: Commit** (only if approved)

```bash
git add GrubIOS/Burrow/BurrowRules.swift GrubIOSTests/BurrowRulesTests.swift
git commit -m "feat(burrow): feed (variety joy) and pet (cooldown) rules"
```

---

## Chunk 3: Wire it into the app

### Task 7: Dig spots

**Files:**
- Create: `GrubIOS/Burrow/BurrowSpots.swift`
- Test: `GrubIOSTests/BurrowRulesTests.swift`

- [ ] **Step 1: Write the failing test** (add to `BurrowRulesTests`; it keeps the spot table and the rules from drifting apart)

```swift
    func test_spot_table_matches_rules() {
        XCTAssertEqual(BurrowSpots.anchors.count, BurrowRules.spotCount)
        XCTAssertNil(BurrowSpots.anchor(BurrowRules.spotCount))
    }
```

Run: TEST `BurrowRulesTests`. Expected: `cannot find 'BurrowSpots' in scope`.

- [ ] **Step 2: Create `BurrowSpots.swift`**

The first four are today's hand-placed finds (spot 0–3). Spots 4–7 are new. On iPhone 13 (cell 6 pt, surface row 40, chamber rows 57–88, right connector x56–59 rows 69–92, side rooms from row ~93) they land at (20,46), (5,85), (62,79) and (42,106): one per open soil pocket, at least 15 rows or 8 columns from any other spot, so the 48×64 pt tap targets don't overlap each other or the grub (x22–42, rows 62–88). Task 10 checks this visually.

```swift
/// The fixed places where finds get buried (spec: 8 spots in open soil).
/// Index = `BuriedFind.spot` = `BurrowSave.holes` entry. Order is part of the save format:
/// append new spots, never reorder.
enum BurrowSpots {
    static let anchors: [CellAnchor] = [
        CellAnchor(ref: .chamberTop, x: 6, dy: 13),     // 0  left of the chamber
        CellAnchor(ref: .surface, x: 39, dy: 9),        // 1  upper soil, middle
        CellAnchor(ref: .surface, x: 59, dy: 15),       // 2  upper soil, right edge
        CellAnchor(ref: .chamberBottom, x: 34, dy: 11), // 3  below the chamber
        CellAnchor(ref: .surface, x: 20, dy: 6),        // 4  upper soil, above the crawl tunnel
        CellAnchor(ref: .chamberTop, x: 5, dy: 28),     // 5  far left, above the left side-room
        CellAnchor(ref: .chamberTop, x: 62, dy: 22),    // 6  far right, beside the right connector
        CellAnchor(ref: .chamberBottom, x: 42, dy: 18), // 7  deep soil, left of the right side-room
    ]

    static func anchor(_ spot: Int) -> CellAnchor? {
        anchors.indices.contains(spot) ? anchors[spot] : nil
    }
}
```

- [ ] **Step 3: Run** — `xcodegen generate && ` + TEST `BurrowRulesTests`. Expected: 22 tests passed.

- [ ] **Step 4: Commit** (only if approved) — `git add GrubIOS/Burrow/BurrowSpots.swift GrubIOSTests/BurrowRulesTests.swift GrubIOS.xcodeproj/project.pbxproj && git commit -m "feat(burrow): eight dig spots"`

### Task 8: Rewrite `BurrowHomeModel` over the rules

**Files:**
- Rewrite: `GrubIOS/Burrow/BurrowHomeModel.swift`

No unit tests here (it's FX/IO glue over tested rules); it's verified in the simulator in Task 10.

- [ ] **Step 1: Replace the whole file**

```swift
import SwiftUI
import UIKit

/// Short-lived visual effects, animated off the TimelineView clock.
struct BurrowFX: Identifiable {
    enum Kind { case dirt, reveal(FindKind), text(String, UInt32), heart }
    let id = UUID()
    let kind: Kind
    let x: Double      // design-space cell
    let y: Double
    let born: TimeInterval
    let life: TimeInterval
}

/// View model for the burrow home: owns the save, runs `BurrowRules`, turns events
/// into effects/toasts/haptics, and persists after every change.
@MainActor
final class BurrowHomeModel: ObservableObject {
    @Published private(set) var save: BurrowSave
    @Published private(set) var fx: [BurrowFX] = []
    @Published private(set) var toast: String?
    @Published private(set) var hopAt: TimeInterval = -10
    @Published private(set) var chompAt: TimeInterval = -10
    @Published private(set) var digHintAt: TimeInterval = -10

    /// Top-centre of the grub sprite in design cells; set by the view from its layout.
    var grubTop: (x: Int, y: Int) = (32, 60)
    /// Last layout the view drew, so events (e.g. a dig) can place their effects.
    var layout: BurrowLayout?

    private let store: BurrowStore
    private let clock: () -> Date
    private var rng = SystemRandomNumberGenerator()
    private var loggedWriteFailure = false

    init(store: BurrowStore = BurrowStore(), clock: @escaping () -> Date = Date.init) {
        self.store = store
        self.clock = clock
        #if DEBUG
        if BurrowDebug.reset { store.reset() }
        #endif
        var loaded = store.load(now: clock())
        #if DEBUG
        if let hrs = BurrowDebug.skipHours { loaded.lastTick.addTimeInterval(-hrs * 3600) }
        #endif
        save = loaded
        tick()
    }

    // MARK: Read-outs for the view

    var belly: Int { save.belly }
    var joy: Int { save.joy }
    var molt: Int { save.molt }
    var digsLeft: Int { save.digs }
    var bag: [FindKind: Int] { save.bag }
    var buried: [BuriedFind] { save.buried }
    var holes: [CellAnchor] { save.holes.compactMap(BurrowSpots.anchor) }
    var foodCount: Int { save.bag.filter { $0.key.isFood }.values.reduce(0, +) }
    var findCount: Int { save.bag.values.reduce(0, +) }
    var isHappy: Bool { BurrowRules.isHappy(save) }
    var isSulking: Bool { BurrowRules.isSulking(save) }

    private var now: TimeInterval { Date().timeIntervalSinceReferenceDate }   // animation clock

    // MARK: Actions

    func tick() { apply(BurrowRules.advance(save, to: clock(), rng: &rng)) }
    func dig(spot: Int) { apply(BurrowRules.dig(save, spot: spot, now: clock(), rng: &rng)) }
    func feed() { apply(BurrowRules.feed(save, kind: nil, now: clock())) }
    func pet() { apply(BurrowRules.pet(save, now: clock())) }

    func digHint() {
        if save.digs == 0 { say(Self.message(.noDigs)); return }
        if save.buried.isEmpty { say("NOTHING BURIED\nCHECK BACK SOON"); return }
        digHintAt = now
        say("TAP A ! TO DIG")
    }

    func persist() {
        do {
            try store.save(save)
        } catch {
            if !loggedWriteFailure { print("Burrow save failed: \(error)"); loggedWriteFailure = true }
        }
    }

    // MARK: Events → effects

    private func apply(_ r: BurrowResult) {
        let changed = r.save != save
        save = r.save
        r.events.forEach(handle)
        if changed { persist() }
    }

    private func handle(_ e: BurrowEvent) {
        let t = now
        switch e {
        case .dugUp(let spot, let kind):
            guard let L = layout, let a = BurrowSpots.anchor(spot) else { break }
            let p = L.resolve(a)
            add(.init(kind: .dirt, x: Double(p.x), y: Double(p.y), born: t, life: 0.7))
            add(.init(kind: .reveal(kind), x: Double(p.x), y: Double(p.y), born: t, life: 1.2))
            add(.init(kind: .text("+" + kind.label, BurrowInk.amberHi), x: Double(p.x), y: Double(p.y - 6), born: t + 0.15, life: 1.3))
            Haptics.thud()
            if save.digs == 0 { say("THAT'S ALL\nFOR NOW") }
        case .bonusFind(let spot, let kind):
            guard let L = layout, let a = BurrowSpots.anchor(spot) else { break }
            let p = L.resolve(a)
            add(.init(kind: .reveal(kind), x: Double(p.x + 6), y: Double(p.y), born: t + 0.45, life: 1.2))
            add(.init(kind: .text("BONUS! +" + kind.label, BurrowInk.teal), x: Double(p.x), y: Double(p.y - 11), born: t + 0.5, life: 1.4))
            Haptics.soft()
        case .ate(_, let joyGained):
            chompAt = t
            add(.init(kind: .text("+BELLY", BurrowInk.berry), x: Double(grubTop.x), y: Double(grubTop.y - 2), born: t, life: 1.2))
            if joyGained {
                add(.init(kind: .text("+JOY", BurrowInk.teal), x: Double(grubTop.x), y: Double(grubTop.y - 6), born: t + 0.3, life: 1.2))
            }
            Haptics.thud()
        case .petted(let joyGained):
            hopAt = t
            add(.init(kind: .heart, x: Double(grubTop.x), y: Double(grubTop.y), born: t, life: 1.0))
            if joyGained {
                add(.init(kind: .text("+JOY", BurrowInk.teal), x: Double(grubTop.x), y: Double(grubTop.y - 6), born: t + 0.2, life: 1.0))
            }
            Haptics.soft()
        case .moltReady:
            say("READY TO MOLT!")
        case .refused(let why):
            say(Self.message(why))
            Haptics.soft()
        case .buried:
            break   // the new "!" marker appears from `save.buried`
        default:
            break   // later phases
        }
    }

    static func message(_ r: Refusal) -> String {
        switch r {
        case .noDigs:             return "NO DIGS LEFT\nBACK SOON"
        case .nothingBuriedThere: return "NOTHING THERE"
        case .noFood:             return "NO FOOD\nDIG FOR SOME"
        case .notFood:            return "THAT'S NOT FOOD"
        case .tooFull:            return "TOO FULL!"
        case .notInBag:           return "NONE LEFT"
        case .wrongStage:         return "NOT NOW"
        case .slotTaken, .notDecor, .emptySlot, .notMoltReady, .badName:
            return "CAN'T DO THAT"
        }
    }

    // MARK: Plumbing

    private func add(_ e: BurrowFX) {
        fx.append(e)
        let id = e.id, wait = e.born - now + e.life
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(max(0, wait) * 1_000_000_000))
            self?.fx.removeAll { $0.id == id }
        }
    }

    private func say(_ message: String) {
        toast = message
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            if self?.toast == message { self?.toast = nil }
        }
    }
}

enum Haptics {
    static func thud() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
}

#if DEBUG
/// DEBUG-only launch arguments for headless simulator checks.
enum BurrowDebug {
    static let args = ProcessInfo.processInfo.arguments
    /// `-burrowReset`: delete the save and start fresh.
    static var reset: Bool { args.contains("-burrowReset") }
    /// `-burrowSkipHours N`: pretend the player was away N hours.
    static var skipHours: Double? {
        guard let i = args.firstIndex(of: "-burrowSkipHours"), i + 1 < args.count else { return nil }
        return Double(args[i + 1])
    }
    /// `-burrowDemo`: script a few taps (see BurrowHomeView).
    static var demo: Bool { args.contains("-burrowDemo") }
}
#endif
```

- [ ] **Step 2: Build** — BUILD. Expected: errors **only** in `BurrowHomeView.swift` (old `model.finds`, `model.dig(_:in:)`, `HomeFind`, `BurrowHomeModel.maxStat`). Any error in another file is a real problem — fix it now. **Do not commit**; Tasks 8 and 9 land together, and Task 9 turns the build green.

### Task 9: Update `BurrowHomeView` and the grub art

**Files:**
- Modify: `GrubIOS/Burrow/BurrowHomeView.swift`
- Modify: `GrubIOS/Burrow/BurrowArt.swift` (`GrubArt`)

- [ ] **Step 1: Add a sulk frame to `GrubArt`** (in `BurrowArt.swift`)

Add a `sulk: Bool = false` parameter to `frame(...)` and draw half-closed eyes and a frown when set. Replace only the signature, the `// eyes` and `// mouth` sections, and the statics; keep the existing body, antennae, highlight and shade code **exactly as it is** (the `// …` line below stands for it):

```swift
    static func frame(blink: Bool = false, chomp: Bool = false, sulk: Bool = false,
                      body: UInt32 = BurrowInk.teal, shade: UInt32 = 0x37a886) -> PixelBuffer {
        // … body, antennae, highlight and shade unchanged …
        // eyes
        if blink {
            r(3, o + 9, 4, 1, I.hollow); r(14, o + 9, 4, 1, I.hollow)
        } else if sulk {
            r(3, o + 8, 4, 2, I.hollow); r(14, o + 8, 4, 2, I.hollow)      // heavy-lidded, no glint
        } else {
            r(3, o + 6, 4, 4, I.hollow); r(14, o + 6, 4, 4, I.hollow)
            r(3, o + 6, 2, 2, I.white); r(14, o + 6, 2, 2, I.white)
        }
        // mouth
        if chomp {
            r(8, o + 12, 5, 3, I.hollow); r(9, o + 14, 3, 1, I.berry)
        } else if sulk {
            r(9, o + 13, 3, 1, I.hollow); r(8, o + 14, 1, 1, I.hollow); r(12, o + 14, 1, 1, I.hollow)  // frown
        } else {
            r(9, o + 13, 3, 1, I.hollow)
        }
        return b
    }

    static let idle = frame()
    static let blink = frame(blink: true)
    static let chomp = frame(chomp: true)
    static let sulk = frame(sulk: true)
```

- [ ] **Step 2: Update `BurrowHomeView.swift`** — make these edits:

  a. Add scene-phase and the minute tick. After `@State private var showBag = false` add:

```swift
    @Environment(\.scenePhase) private var scenePhase
    private let minuteTick = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
```

and after `.overlay { if showBag … }` (before `#if DEBUG`) add:

```swift
        .onReceive(minuteTick) { _ in model.tick() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: model.tick()
            case .background: model.persist()
            default: break
            }
        }
```

  b. `place(_:)` hands the layout to the model instead of keeping it in view state. Delete `@State private var lastLayout: BurrowLayout?` and replace `place`:

```swift
    private func place(_ L: BurrowLayout) {
        model.grubTop = (L.chamber.midX, L.chamber.maxY - GrubArt.height)
        model.layout = L
    }
```

  c. Markers come from buried spots. In `livingLayer` replace
  `ForEach(model.finds.filter { !$0.dug }) { f in marker(f, L, t) }` with

```swift
            ForEach(model.buried, id: \.spot) { f in
                if let a = BurrowSpots.anchor(f.spot) { marker(spot: f.spot, anchor: a, L, t) }
            }
```

  and change the marker signature and its first and last lines:

```swift
    @ViewBuilder
    private func marker(spot: Int, anchor: CellAnchor, _ L: BurrowLayout, _ t: TimeInterval) -> some View {
        let p = L.resolve(anchor)
        let phase = Double((anchor.x * 7 + anchor.dy) % 10) / 10
        // … unchanged …
            .onTapGesture { model.dig(spot: spot) }
```

  d. Grub: sulking pose, no bounce while sulking. In `grub(_:_:)` replace the `bounce` and `sprite` lines:

```swift
        let sulking = model.isSulking
        let bounce = !sulking && Int(t / 0.4) % 3 == 1 ? 1 : 0
        // … hopP, hop, chomping, blinking unchanged …
        let sprite = chomping ? (Int(t / 0.15) % 2 == 0 ? GrubArt.chomp : GrubArt.idle)
                              : (blinking ? GrubArt.blink : (sulking ? GrubArt.sulk : GrubArt.idle))
```

  and its accessibility label: `.accessibilityLabel(sulking ? "Grub, hungry and sulking" : "Grub")`.

  e. HUD: stat max comes from the rules, Joy shows HAPPY, DIG is "hot" when there is something to dig:

```swift
                HStack(spacing: 12) {
                    statBar("BELLY", model.belly, BurrowInk.berry)
                    statBar("JOY", model.joy, BurrowInk.teal, tag: model.isHappy ? "HAPPY" : nil)
                    statBar("MOLT", model.molt, BurrowInk.amber)
                }
                HStack(spacing: 10) {
                    hudButton(icon: FindKind.berry.sprite, title: "FEED", count: model.foodCount) { model.feed() }
                    hudButton(icon: IconArt.shovel, title: "DIG", count: model.digsLeft,
                              hot: model.digsLeft > 0 && !model.buried.isEmpty) { model.digHint() }
                    // FINDS button unchanged
```

```swift
    private func statBar(_ label: String, _ value: Int, _ ink: UInt32, tag: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Text(label).font(GrubFont.size(7)).foregroundColor(Color(ink: BurrowInk.cream))
                if let tag {
                    Text(tag).font(GrubFont.size(6)).foregroundColor(Color(ink: ink))
                }
            }
            HStack(spacing: 2) {
                ForEach(0..<BurrowRules.maxStat, id: \.self) { i in
                    Rectangle().fill(Color(ink: i < value ? ink : BurrowInk.soil1)).frame(height: 9)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label.capitalized) \(value) of \(BurrowRules.maxStat)" + (tag.map { ", \($0.lowercased())" } ?? ""))
    }
```

  f. DEBUG demo script uses spots and the new debug flag:

```swift
    #if DEBUG
    /// `-burrowDemo`: scripts dig → dig → feed → pet → Finds for headless screenshots.
    private func runDemoIfRequested() async {
        guard BurrowDebug.demo else { return }
        func wait(_ s: Double) async { try? await Task.sleep(nanoseconds: UInt64(s * 1_000_000_000)) }
        await wait(1.5)
        if let f = model.buried.first { model.dig(spot: f.spot) }
        await wait(1.5); if let f = model.buried.first { model.dig(spot: f.spot) }
        await wait(1.5); model.feed()
        await wait(1.5); model.pet()
        await wait(2.0); withAnimation { showBag = true }
    }
    #endif
```

  g. Delete the old `HomeFind` struct from wherever it still exists (Task 8's rewrite already dropped it from the model; make sure no reference remains: `grep -rn HomeFind GrubIOS/` prints nothing).

- [ ] **Step 3: Build** — BUILD. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Run all burrow tests** — TEST with `<Class>` = `BurrowRulesTests` then `BurrowStoreTests`. Expected: all pass.

- [ ] **Step 5: Commit** (only if approved)

```bash
git add GrubIOS/Burrow/BurrowHomeModel.swift GrubIOS/Burrow/BurrowHomeView.swift GrubIOS/Burrow/BurrowArt.swift
git commit -m "feat(burrow): home screen runs on saved real-time rules"
```

### Task 10: Simulator verification

**Files:** none (verification only; may nudge `BurrowSpots.swift` anchors 4–7)

Use shell variables: `D=8AABF67E-2193-4949-8A0E-0954E9789898`, `APP=build/dd/Build/Products/Debug-iphonesimulator/GrubIOS.app`, `OUT=<scratchpad dir>`. Inspect screenshots with a browser/PIL or the `Read` tool on the full-size PNG (they are ~80 KB, 1170×2532 — safe per CLAUDE.md Rule 0.6).

- [ ] **Step 1: Fresh start persists across relaunch**

```bash
xcrun simctl install $D $APP
xcrun simctl terminate $D com.jessedev.GrubIOS; xcrun simctl launch $D com.jessedev.GrubIOS -burrowReset -burrowDemo >/dev/null
sleep 11; xcrun simctl terminate $D com.jessedev.GrubIOS
xcrun simctl launch $D com.jessedev.GrubIOS >/dev/null; sleep 4; xcrun simctl io $D screenshot $OUT/p1_relaunch.png
```

Expected in `p1_relaunch.png`: DIG 1, FINDS 2 (berry + amber; the demo ate one berry), Belly 9, Joy 8, MOLT 1, two dug holes, one "!" marker (the crystal) — i.e. the demo's progress survived the relaunch.

- [ ] **Step 2: Time away**

```bash
xcrun simctl terminate $D com.jessedev.GrubIOS; xcrun simctl launch $D com.jessedev.GrubIOS -burrowReset -burrowSkipHours 9 >/dev/null; sleep 4; xcrun simctl io $D screenshot $OUT/p1_skip9.png
```

Expected: 4 "!" markers (3 + one per 2 h, capped at 4), DIG 3, Belly 2 (6 − 4), Joy 4 (6 − 2).

- [ ] **Step 3: Sulking**

```bash
xcrun simctl terminate $D com.jessedev.GrubIOS; xcrun simctl launch $D com.jessedev.GrubIOS -burrowReset -burrowSkipHours 20 >/dev/null; sleep 4; xcrun simctl io $D screenshot $OUT/p1_sulk.png
```

Expected: Belly 0 (empty at 12 h), Joy 0 (3 drops by 12 h, then hourly), heavy-lidded frowning grub that doesn't bounce.

- [ ] **Step 4: Spot placement** — in `p1_skip9.png` (and a couple more `-burrowReset -burrowSkipHours 9` launches, since spots are random), check that no "!" marker or dig hole overlaps a tunnel, chamber, side room, the title, or the HUD; that no two markers' tap areas (≈ 8 cells wide × 11 tall, centred 3 cells above the hole) overlap; and that none sits under the grub sprite. (A toast briefly covers spot 7 and part of spot 3 for 1.8 s; that's accepted.) If one does, nudge that anchor in `BurrowSpots.swift` (spots 4–7 only), rebuild, and recheck.

- [ ] **Step 5: HAPPY tag** — there's no launch arg for joy, so run the demo and screenshot after the pet but before the Finds panel opens (~8 s):

```bash
xcrun simctl terminate $D com.jessedev.GrubIOS; xcrun simctl launch $D com.jessedev.GrubIOS -burrowReset -burrowDemo >/dev/null; sleep 7.5; xcrun simctl io $D screenshot $OUT/p1_happy.png
```

The first meal is a change of food (Joy 6 → 7) and the pet adds 1 (→ 8). Expect "JOY HAPPY" on the stat bar with Joy at 7 or 8 (8 if the pet has landed).

- [ ] **Step 6: Report** — send Jesse a sheet of the screenshots (relaunch, skip 9 h, sulk, happy) with the observed values next to the expected ones. Note anything that didn't match.

- [ ] **Step 7: Commit** any anchor nudges (only if approved): `git add GrubIOS/Burrow/BurrowSpots.swift && git commit -m "fix(burrow): adjust dig spots"`

---

## Done when

- `BurrowRulesTests` and `BurrowStoreTests` pass.
- The app builds, and the four simulator checks in Task 10 match their expected values.
- Relaunching keeps progress; time away regrows digs, buries finds, and drains Belly/Joy.
