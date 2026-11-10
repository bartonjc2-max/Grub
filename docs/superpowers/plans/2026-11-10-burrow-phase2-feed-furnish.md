# Burrow Phase 2 (Feed + Furnish) Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the four new finds (root, mushroom, honeydew, shell), let the player eat a specific food or place decor into four slots in the burrow, and lock the stat balance in with a pacing regression test.

**Architecture:** Same layers as phase 1 (`docs/superpowers/plans/2026-11-10-burrow-phase1-save-time.md`): pure `BurrowRules` (+ `place`, `remove`) → `BurrowHomeModel` (placing/selection UI state, events → FX) → `BurrowHomeView` (decor layer, place/remove bars, new Finds panel). Spec: `docs/superpowers/specs/2026-11-10-burrow-mechanics-design.md` §2 "Finds and digging", §3 "Feeding, petting, furnishing", "Stat roles".

**Tech Stack:** Swift 5.9, SwiftUI, iOS 17, XCTest, XcodeGen (`xcodegen generate` after adding files).

---

## Ground rules

- Phase 1 is done and committed on `the-deep` (HEAD `516e728`). All 28 burrow tests pass.
- **Commit after each task**, staging only that task's files. `GrubIOS.xcodeproj/` is git-ignored but tracked: stage it with `git add -f GrubIOS.xcodeproj/project.pbxproj` only when a task adds files. Never stage `GrubIOS/GrubIOSApp.swift` or `grub_canon.png` (Jesse's uncommitted work). Every commit message ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Still phase-scoped: stage stays `.larva` (egg is phase 4); molt-ready does nothing yet beyond the toast (phase 3).
- New `FindKind` cases are **appended** after `crystal` (raw values are strings, so order doesn't affect saves, but appending keeps diffs and `allCases`-based UI stable).
- Commands run from `/Users/jessedev/Documents/Code/grub/GrubIOS`. Shorthand:

```bash
# TEST (one or more classes): replace <Class>
xcodebuild test -project GrubIOS.xcodeproj -scheme GrubIOS -destination 'id=8AABF67E-2193-4949-8A0E-0954E9789898' -derivedDataPath build/dd -only-testing:GrubIOSTests/<Class> 2>&1 | grep -E "error:|Test Case.*failed|XCTAssert|Executed .* tests|TEST (SUCCEEDED|FAILED)" | tail -12
```

```bash
# BUILD
xcodebuild -project GrubIOS.xcodeproj -scheme GrubIOS -configuration Debug -destination 'id=8AABF67E-2193-4949-8A0E-0954E9789898' -derivedDataPath build/dd build 2>&1 | grep -E "error:|BUILD" | head -20
```

## File map

| File | Status | Change |
|---|---|---|
| `GrubIOS/Burrow/BurrowTypes.swift` | modify | 4 new `FindKind` cases + data, `isDecor`, explicit `feedOrder` |
| `GrubIOS/Burrow/PixelBuffer.swift` | modify | 3 new `BurrowInk` colours (pink, steel, steelHi) |
| `GrubIOS/Burrow/BurrowArt.swift` | modify | 4 new find sprites; pedestal art; `BurrowLayout.decorSlot`; remove baked decor + pebbles from backdrop |
| `GrubIOS/Burrow/BurrowSave.swift` | modify | `fresh` buries root (not amber) at spot 1 |
| `GrubIOS/Burrow/BurrowRules.swift` | modify | `decorSlots`, `place`, `remove`, shared `take` helper |
| `GrubIOS/Burrow/BurrowHomeModel.swift` | modify | `feed(kind:)`, placing + selection state, slot taps, placed/removed FX |
| `GrubIOS/Burrow/BurrowHomeView.swift` | modify | decor layer, place/remove bars, new `FindsBagView`, demo script |
| `GrubIOSTests/BurrowRulesTests.swift` | modify | update 2 phase-1 tests; new finds, variety, place/remove tests |
| `GrubIOSTests/BurrowStoreTests.swift` | modify | fresh test → root |
| `GrubIOSTests/BurrowLayoutTests.swift` | create | decor slots sit inside their rooms and clear of the grub |
| `GrubIOSTests/BurrowPacingTests.swift` | create | port of `docs/burrow/stat-sim.py`; asserts the "Stat roles" table |

---

## Chunk 1: Rules

### Task 1: Four new finds

**Files:**
- Modify: `GrubIOS/Burrow/BurrowTypes.swift` (the `FindKind` enum)
- Modify: `GrubIOS/Burrow/BurrowSave.swift` (`fresh`)
- Modify: `GrubIOS/Burrow/PixelBuffer.swift` (`BurrowInk`)
- Modify: `GrubIOS/Burrow/BurrowArt.swift` (`extension FindKind { var sprite }`)
- Test: `GrubIOSTests/BurrowRulesTests.swift`, `GrubIOSTests/BurrowStoreTests.swift`

- [ ] **Step 1: Update the two phase-1 tests that assume amber at spot 1, and add new tests**

In `BurrowStoreTests.swift`, rename `test_fresh_save_matches_phase1_spec` → `test_fresh_save_matches_spec` and change its `buried` expectation:

```swift
        XCTAssertEqual(s.buried, [BuriedFind(spot: 0, kind: .berry),
                                  BuriedFind(spot: 1, kind: .root),
                                  BuriedFind(spot: 2, kind: .crystal)])
```

In `BurrowRulesTests.swift`, `test_dig_moves_find_to_bag_and_leaves_hole` becomes:

```swift
    func test_dig_moves_find_to_bag_and_leaves_hole() {
        let r = BurrowRules.dig(save { $0.joy = 0 }, spot: 1, now: t0, rng: &rng)
        XCTAssertEqual(r.events, [.dugUp(spot: 1, kind: .root)])
        XCTAssertEqual(r.save.digs, 2)
        XCTAssertEqual(r.save.bag, [.berry: 1, .root: 1])
        XCTAssertEqual(r.save.holes, [1])
        XCTAssertFalse(r.save.buried.contains { $0.spot == 1 })
    }
```

Add to `BurrowRulesTests`:

```swift
    // MARK: finds (phase 2)

    func test_find_table_matches_spec() {
        XCTAssertEqual(FindKind.allCases.count, 8)
        XCTAssertEqual(FindKind.feedOrder, [.berry, .root, .mushroom, .honeydew])
        XCTAssertEqual(Set(FindKind.allCases.filter(\.isDecor)), [.crystal, .shell, .amber, .bone])
        XCTAssertEqual(FindKind.allCases.reduce(0) { $0 + $1.buryWeight }, 100)
        let foodWeight = FindKind.allCases.filter(\.isFood).reduce(0) { $0 + $1.buryWeight }
        XCTAssertEqual(foodWeight, 70, "70 % of burials are food (Stat roles pacing)")
        XCTAssertEqual(FindKind.root.leansTo, .claws)
        XCTAssertEqual(FindKind.mushroom.leansTo, .stalk)
        XCTAssertEqual(FindKind.honeydew.leansTo, .fuzz)
        XCTAssertEqual(FindKind.shell.leansTo, .shell)
    }

    func test_auto_feed_prefers_a_different_food() {
        let s = save { $0.bag = [.berry: 1, .root: 1]; $0.lastMeal = .berry }
        let r = BurrowRules.feed(s, kind: nil, now: t0)
        XCTAssertEqual(r.events, [.ate(.root, joyGained: true)])
        XCTAssertEqual(r.save.joy, 7)
    }

    func test_auto_feed_falls_back_to_a_repeat() {
        let s = save { $0.bag = [.root: 1]; $0.lastMeal = .root }
        XCTAssertEqual(BurrowRules.feed(s, kind: nil, now: t0).events, [.ate(.root, joyGained: false)])
    }

    func test_feed_specific_food() {
        let s = save { $0.bag = [.berry: 1, .honeydew: 1] }
        let r = BurrowRules.feed(s, kind: .honeydew, now: t0)
        XCTAssertEqual(r.events, [.ate(.honeydew, joyGained: true)])
        XCTAssertEqual(r.save.bag, [.berry: 1])
        XCTAssertEqual(r.save.eaten, [.honeydew: 1])
    }
```

- [ ] **Step 2: Run to verify it fails** — TEST `BurrowRulesTests -only-testing:GrubIOSTests/BurrowStoreTests`. Expected: compile errors `type 'FindKind' has no member 'root'` / `'isDecor'`.

- [ ] **Step 3: Extend `FindKind`** — replace the whole enum in `BurrowTypes.swift`:

```swift
/// Something you can dig up (spec §2). Foods are eaten; decor is placed in the burrow.
enum FindKind: String, Codable, CaseIterable, Identifiable, CodingKeyRepresentable {
    case berry, amber, bone, crystal          // phase 1
    case root, mushroom, honeydew, shell      // phase 2 (append new cases, never reorder)

    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
    var isFood: Bool { Self.feedOrder.contains(self) }
    var isDecor: Bool { !isFood }

    /// The species this find nudges the molt odds toward.
    var leansTo: Species {
        switch self {
        case .berry:    return .grub
        case .root:     return .claws
        case .mushroom: return .stalk
        case .honeydew: return .fuzz
        case .crystal:  return .horn
        case .shell:    return .shell
        case .amber:    return .fuzz
        case .bone:     return .claws
        }
    }

    /// Relative chance of being buried (spec §2). Sums to 100; foods are 70.
    var buryWeight: Int {
        switch self {
        case .berry:    return 30
        case .root:     return 15
        case .mushroom: return 15
        case .honeydew: return 10
        case .crystal:  return 8
        case .shell:    return 8
        case .amber:    return 7
        case .bone:     return 7
        }
    }

    /// Foods, in the order auto-feed tries them.
    static let feedOrder: [FindKind] = [.berry, .root, .mushroom, .honeydew]
}
```

- [ ] **Step 4: `fresh` buries root at spot 1** — in `BurrowSave.swift` change `BuriedFind(spot: 1, kind: .amber)` to `BuriedFind(spot: 1, kind: .root)` and update the doc comment's "Phase 1" note to "Phase 1–3 start at `.larva`".

- [ ] **Step 5: Colours** — in `PixelBuffer.swift`, add to `enum BurrowInk` after `mutedText`:

```swift
    static let pink: UInt32         = 0xed93b1   // STALK; mushroom caps
    static let steel: UInt32        = 0x6f8fb0   // SHELL
    static let steelHi: UInt32      = 0xa9c0d8
```

- [ ] **Step 6: Sprites** — in `BurrowArt.swift`, add four cases to the `switch self` in `extension FindKind { var sprite }` (after `.crystal`):

```swift
        case .root:
            return PixelBuffer(art: [".L.L.",
                                     "..L..",
                                     ".CCD.",
                                     ".CCD.",
                                     "..CD.",
                                     "..C.."],
                               palette: ["C": I.copper, "D": I.amberLo, "L": I.leaf])
        case .mushroom:
            return PixelBuffer(art: [".PPP.",
                                     "PWPPP",
                                     "PPPWP",
                                     "..C..",
                                     "..C.."],
                               palette: ["P": I.pink, "W": I.white, "C": I.cream])
        case .honeydew:
            return PixelBuffer(art: ["..A..",
                                     ".AYA.",
                                     "AYWYA",
                                     "AYYYA",
                                     ".AAA."],
                               palette: ["A": I.amber, "Y": I.amberHi, "W": I.white])
        case .shell:
            return PixelBuffer(art: [".SSSS.",
                                     "SHHHSS",
                                     "SHSSHS",
                                     "SSHHSS",
                                     ".SSSS."],
                               palette: ["S": I.steel, "H": I.steelHi])
```

- [ ] **Step 7: Run to verify it passes** — TEST `BurrowRulesTests -only-testing:GrubIOSTests/BurrowStoreTests`. Expected: 32 tests passed (26 rules + 6 store: 4 new rules tests, 2 updated). Also BUILD the app — the Finds panel still iterates `FindKind.allCases` and must compile.

- [ ] **Step 8: Commit**

```bash
git add GrubIOS/Burrow/BurrowTypes.swift GrubIOS/Burrow/BurrowSave.swift GrubIOS/Burrow/PixelBuffer.swift GrubIOS/Burrow/BurrowArt.swift GrubIOSTests/BurrowRulesTests.swift GrubIOSTests/BurrowStoreTests.swift
git commit -m "feat(burrow): root, mushroom, honeydew and shell finds" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 2: `place` and `remove`

**Files:**
- Modify: `GrubIOS/Burrow/BurrowRules.swift`
- Test: `GrubIOSTests/BurrowRulesTests.swift`

- [ ] **Step 1: Write the failing tests** (add to `BurrowRulesTests`)

```swift
    // MARK: furnish

    func test_place_moves_decor_from_bag_to_slot() {
        let r = BurrowRules.place(save { $0.bag = [.crystal: 2] }, kind: .crystal, slot: 2, now: t0)
        XCTAssertEqual(r.events, [.placed(slot: 2, kind: .crystal)])
        XCTAssertEqual(r.save.placed, [2: .crystal])
        XCTAssertEqual(r.save.bag, [.crystal: 1])
    }

    func test_place_refusals() {
        let s = save { $0.bag = [.crystal: 1, .berry: 1]; $0.placed = [0: .bone] }
        XCTAssertEqual(BurrowRules.place(s, kind: .berry, slot: 1, now: t0).events, [.refused(.notDecor)])
        XCTAssertEqual(BurrowRules.place(s, kind: .shell, slot: 1, now: t0).events, [.refused(.notInBag)])
        XCTAssertEqual(BurrowRules.place(s, kind: .crystal, slot: 0, now: t0).events, [.refused(.slotTaken)])
        XCTAssertEqual(BurrowRules.place(s, kind: .crystal, slot: 4, now: t0).events, [.refused(.slotTaken)],
                       "out-of-range slots are refused, never crash")
        var egg = s
        egg.stage = .egg
        XCTAssertEqual(BurrowRules.place(egg, kind: .crystal, slot: 1, now: t0).events, [.refused(.wrongStage)])
    }

    func test_remove_returns_decor_to_bag() {
        let r = BurrowRules.remove(save { $0.bag = [:]; $0.placed = [3: .shell] }, slot: 3, now: t0)
        XCTAssertEqual(r.events, [.removed(slot: 3, kind: .shell)])
        XCTAssertTrue(r.save.placed.isEmpty)
        XCTAssertEqual(r.save.bag, [.shell: 1])
        XCTAssertEqual(BurrowRules.remove(save(), slot: 3, now: t0).events, [.refused(.emptySlot)])
    }

    func test_placed_decor_slows_the_joy_drain() {
        // 4 h base + 1 h per placed decor: with 4 placed, Joy drops once per 8 h.
        let s = save { $0.belly = 10; $0.joy = 10; $0.placed = [0: .amber, 1: .bone, 2: .crystal, 3: .shell] }
        XCTAssertEqual(advance(s, hours: 16).save.joy, 8)
    }
```

- [ ] **Step 2: Run to verify it fails** — TEST `BurrowRulesTests`. Expected: `type 'BurrowRules' has no member 'place'`.

- [ ] **Step 3: Implement** — in `BurrowRules.swift`:

  a. Add the constant next to `spotCount`: `static let decorSlots = 4`

  b. Add a shared bag helper and use it in `feed` (replace feed's two lines `s.bag[food, default: 0] -= 1` / `if s.bag[food] == 0 { s.bag[food] = nil }` with `take(&s, food)`):

```swift
    /// Remove one `kind` from the bag, dropping empty entries.
    static func take(_ s: inout BurrowSave, _ kind: FindKind) {
        s.bag[kind, default: 0] -= 1
        if s.bag[kind, default: 0] <= 0 { s.bag[kind] = nil }
    }
```

  c. Add before `refuse`:

```swift
    // MARK: Furnishing

    /// Put a decor find from the bag into an empty slot (0 left room, 1 right room,
    /// 2 chamber left corner, 3 chamber right corner). Out-of-range slots count as taken.
    static func place(_ s0: BurrowSave, kind: FindKind, slot: Int, now: Date) -> BurrowResult {
        guard s0.stage == .larva else { return refuse(s0, .wrongStage) }
        guard kind.isDecor else { return refuse(s0, .notDecor) }
        guard s0.bag[kind, default: 0] > 0 else { return refuse(s0, .notInBag) }
        guard (0..<decorSlots).contains(slot), s0.placed[slot] == nil else { return refuse(s0, .slotTaken) }
        var s = s0
        take(&s, kind)
        s.placed[slot] = kind
        return BurrowResult(save: s, events: [.placed(slot: slot, kind: kind)])
    }

    /// Take a placed decor back into the bag.
    static func remove(_ s0: BurrowSave, slot: Int, now: Date) -> BurrowResult {
        guard s0.stage == .larva else { return refuse(s0, .wrongStage) }
        guard let kind = s0.placed[slot] else { return refuse(s0, .emptySlot) }
        var s = s0
        s.placed[slot] = nil
        s.bag[kind, default: 0] += 1
        return BurrowResult(save: s, events: [.removed(slot: slot, kind: kind)])
    }
```

- [ ] **Step 4: Run to verify it passes** — TEST `BurrowRulesTests`. Expected: 30 rules tests passed.

- [ ] **Step 5: Commit**

```bash
git add GrubIOS/Burrow/BurrowRules.swift GrubIOSTests/BurrowRulesTests.swift
git commit -m "feat(burrow): place and remove decor" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 3: Pacing regression test

**Files:**
- Create: `GrubIOSTests/BurrowPacingTests.swift`

This ports the player model from `docs/burrow/stat-sim.py` onto the real rules, so a future change to any timer, weight or stat rule that breaks the balance fails a test. The Python numbers (30 seeds) are: 4 visits/day → 2.3 days to molt, 2/day → 2.4, 1/day → 4.5. The Swift port uses the same 30 seeds' worth of runs and a ±0.5-day tolerance.

- [ ] **Step 1: Write the test**

```swift
import XCTest
@testable import GrubIOS

/// Port of docs/burrow/stat-sim.py. Each visit: dig everything, place any decor into free
/// slots, feed while Belly ≤ 7 (auto-feed prefers variety), pet once. Asserts the
/// days-to-molt column of the spec's "Stat roles" table.
final class BurrowPacingTests: XCTestCase {
    let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func daysToMolt(visitMinutes: [Int], seed: UInt64, maxDays: Int = 12) -> Double? {
        var rng = SeededRNG(seed)
        var s = BurrowSave.fresh(now: t0)
        for day in 0..<maxDays {
            for m in visitMinutes {
                let now = t0.addingTimeInterval(TimeInterval(day * 86_400 + m * 60))
                s = BurrowRules.advance(s, to: now, rng: &rng).save
                while s.digs > 0, let f = s.buried.first {
                    s = BurrowRules.dig(s, spot: f.spot, now: now, rng: &rng).save
                }
                for k in FindKind.allCases where k.isDecor {
                    while s.bag[k, default: 0] > 0,
                          let slot = (0..<BurrowRules.decorSlots).first(where: { s.placed[$0] == nil }) {
                        s = BurrowRules.place(s, kind: k, slot: slot, now: now).save
                    }
                }
                while s.belly <= 7 {
                    let r = BurrowRules.feed(s, kind: nil, now: now)
                    if case .refused = r.events.first { break }
                    s = r.save
                }
                s = BurrowRules.pet(s, now: now).save
                if s.molt >= BurrowRules.moltGoal { return now.timeIntervalSince(t0) / 86_400 }
            }
        }
        return nil
    }

    func averageDays(_ visits: [Int]) -> Double {
        let runs = (1...30).map { daysToMolt(visitMinutes: visits, seed: UInt64($0)) ?? 99 }
        return runs.reduce(0, +) / Double(runs.count)
    }

    func test_four_visits_a_day_molts_in_about_2_3_days() {
        XCTAssertEqual(averageDays([8 * 60, 12 * 60, 17 * 60, 22 * 60]), 2.3, accuracy: 0.5)
    }

    func test_two_visits_a_day_molts_in_about_2_4_days() {
        XCTAssertEqual(averageDays([8 * 60, 20 * 60]), 2.4, accuracy: 0.5)
    }

    func test_one_visit_a_day_molts_in_about_4_5_days() {
        XCTAssertEqual(averageDays([19 * 60]), 4.5, accuracy: 0.5)
    }
}
```

- [ ] **Step 2: Run** — `xcodegen generate && ` + TEST `BurrowPacingTests`. Expected: 3 passed.
  **If one fails,** do not tune the test or the rules to make it pass. Print the per-seed days (`print(runs)` in `averageDays`), compare with `python3 docs/burrow/stat-sim.py`, and find which behaviour differs between the port and the Python model (visit order, feed condition, bury timing). Report the difference to Jesse before changing any rule.

- [ ] **Step 3: Commit**

```bash
git add GrubIOSTests/BurrowPacingTests.swift
git add -f GrubIOS.xcodeproj/project.pbxproj
git commit -m "test(burrow): pacing regression from the stat simulation" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Chunk 2: Decor in the burrow

### Task 4: Decor slots, pedestals, and a cleaner backdrop

**Files:**
- Modify: `GrubIOS/Burrow/BurrowArt.swift`
- Create: `GrubIOSTests/BurrowLayoutTests.swift`

Slot geometry (bottom-centre cell where the decor's pedestal sits). On iPhone 13 (390×844 pt @3x → cell 6 pt; chamber x14–49 rows 57–87; grub x22–42; sideL x3–14; sideR x46–59):

| Slot | Where | Pedestal cells |
|---|---|---|
| 0 | left side-room floor | `sideL.midX` (9) → x6–11 |
| 1 | right side-room floor | `sideR.midX` (53) → x50–55 |
| 2 | chamber, left corner | `chamber.x + 5` (19) → x16–21 |
| 3 | chamber, right corner | `chamber.maxX - 4` (46) → x43–48 |

- [ ] **Step 1: Write the failing test** (`GrubIOSTests/BurrowLayoutTests.swift`)

```swift
import XCTest
@testable import GrubIOS

final class BurrowLayoutTests: XCTestCase {
    /// iPhone 13 and iPhone SE-sized layouts.
    let layouts = [BurrowLayout(size: CGSize(width: 390, height: 844), displayScale: 3),
                   BurrowLayout(size: CGSize(width: 375, height: 667), displayScale: 2)]

    func test_decor_slots_sit_on_their_room_floors() {
        for L in layouts {
            let rooms = [L.sideL, L.sideR, L.chamber, L.chamber]
            for i in 0..<BurrowRules.decorSlots {
                guard let p = L.decorSlot(i) else { return XCTFail("slot \(i)") }
                let r = rooms[i]
                XCTAssertTrue(p.x - 3 >= r.x && p.x + 2 < r.maxX, "slot \(i) x inside its room")
                XCTAssertEqual(p.y, r.maxY - 2, "slot \(i) pedestal on the floor")
            }
            XCTAssertNil(L.decorSlot(BurrowRules.decorSlots))
        }
    }

    func test_chamber_slots_clear_the_grub() {
        for L in layouts {
            let grubX0 = L.chamber.midX - GrubArt.width / 2
            let grubX1 = grubX0 + GrubArt.width - 1
            for i in [2, 3] {
                let p = L.decorSlot(i)!
                XCTAssertTrue(p.x + 2 < grubX0 || p.x - 3 > grubX1, "slot \(i) pedestal x\(p.x - 3)–\(p.x + 2) vs grub x\(grubX0)–\(grubX1)")
            }
        }
    }
}
```

- [ ] **Step 2: Run to verify it fails** — `xcodegen generate && ` + TEST `BurrowLayoutTests`. Expected: `value of type 'BurrowLayout' has no member 'decorSlot'`.

- [ ] **Step 3: Implement in `BurrowArt.swift`**

  a. Add after the `BurrowLayout` struct (before `// MARK: - Backdrop`):

```swift
extension BurrowLayout {
    /// Bottom-centre cell of decor slot `i`: the 6×2 pedestal spans x-3…x+2, rows y…y+1,
    /// and the decor sprite stands on it (its bottom row at y-1).
    func decorSlot(_ i: Int) -> (x: Int, y: Int)? {
        switch i {
        case 0: return (sideL.midX, sideL.maxY - 2)
        case 1: return (sideR.midX, sideR.maxY - 2)
        case 2: return (chamber.x + 5, chamber.maxY - 2)
        case 3: return (chamber.maxX - 4, chamber.maxY - 2)
        default: return nil
        }
    }
}
```

  b. Add to `enum IconArt`:

```swift
    /// Decor-slot pedestal (6×2). `lit` is the glowing version shown while placing.
    static func pedestal(lit: Bool) -> PixelBuffer {
        PixelBuffer(art: ["TTTTTT",
                          ".BBBB."],
                    palette: ["T": lit ? BurrowInk.amber : BurrowInk.root,
                              "B": lit ? BurrowInk.amberLo : BurrowInk.soil1])
    }
    static let pedestalDim = pedestal(lit: false)
    static let pedestalLit = pedestal(lit: true)
```

  c. In `BurrowArt.backdrop`, delete the baked decor and the floor pebbles (they'd sit under the corner pedestals). Remove these blocks entirely:
  - `// Pebbles on the main chamber floor (grounds the grub).` and its `r(...)` line
  - `// Right side-chamber: glowing amber on a pedestal.` and the 5 lines after it (`let R = L.sideR, gy = …`, the pedestal `r(...)`, two amber `r(...)` lines, and the `amberHi` sparkle line `r(R.x + 2, gy, …)` — everything that uses `R` or `gy`)
  - `// Left side-chamber: mushroom lamp + little stool.` and the 6 lines after it (`let Lc = L.sideL` through the stool line — everything that uses `Lc`)

  Leave `// Pockets left by digging.` and everything after it. Check: `grep -n "let R = \|let Lc = \|R\.x\|Lc\.x\|mushroomGlint" GrubIOS/Burrow/BurrowArt.swift` prints nothing.

- [ ] **Step 4: Run to verify it passes** — TEST `BurrowLayoutTests`. Expected: 2 passed. Then BUILD.

- [ ] **Step 5: Commit**

```bash
git add GrubIOS/Burrow/BurrowArt.swift GrubIOSTests/BurrowLayoutTests.swift
git add -f GrubIOS.xcodeproj/project.pbxproj
git commit -m "feat(burrow): four decor slots with pedestals" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 5: Model — eat a specific food, place, remove

**Files:**
- Modify: `GrubIOS/Burrow/BurrowHomeModel.swift`

No unit tests (UI glue over tested rules); verified in the simulator in Task 7.

- [ ] **Step 1: Add state and read-outs** — after `@Published private(set) var digHintAt …` add:

```swift
    /// The decor the player is placing (picked in the Finds panel); free slots glow.
    @Published private(set) var placing: FindKind?
    /// A placed decor the player tapped; the HUD offers REMOVE / KEEP.
    @Published private(set) var selectedSlot: Int?
```

and after `var isSulking …`:

```swift
    var placed: [Int: FindKind] { save.placed }
    var freeSlots: [Int] { (0..<BurrowRules.decorSlots).filter { save.placed[$0] == nil } }
    var canAct: Bool { save.stage == .larva }
```

- [ ] **Step 2: Add actions** — after `func pet() …`:

```swift
    func feed(kind: FindKind) { apply(BurrowRules.feed(save, kind: kind, now: clock())) }

    func startPlacing(_ kind: FindKind) {
        selectedSlot = nil
        placing = kind
    }

    func cancelPlacing() { placing = nil }

    /// A tap on decor slot `slot`: places while placing, otherwise selects a placed item.
    func tapSlot(_ slot: Int) {
        if let kind = placing {
            guard save.placed[slot] == nil else { return }
            placing = nil
            apply(BurrowRules.place(save, kind: kind, slot: slot, now: clock()))
        } else if save.placed[slot] != nil {
            selectedSlot = selectedSlot == slot ? nil : slot
        }
    }

    func removeSelected() {
        guard let slot = selectedSlot else { return }
        selectedSlot = nil
        apply(BurrowRules.remove(save, slot: slot, now: clock()))
    }

    func clearSelection() { selectedSlot = nil }
```

- [ ] **Step 3: Handle the two new events** — in `handle(_:)`, add before `case .moltReady:`:

```swift
        case .placed(let slot, let kind):
            if let L = layout, let p = L.decorSlot(slot) {
                add(.init(kind: .dirt, x: Double(p.x), y: Double(p.y - 1), born: t, life: 0.6))
                add(.init(kind: .text(kind.label, BurrowInk.amberHi), x: Double(p.x), y: Double(p.y - 9), born: t + 0.1, life: 1.2))
            }
            Haptics.thud()
        case .removed(_, let kind):
            say("\(kind.label)\nBACK IN BAG")
            Haptics.soft()
```

- [ ] **Step 4: Refusal messages** — in `message(_:)` replace the catch-all case with specific ones:

```swift
        case .slotTaken:          return "SPOT TAKEN"
        case .notDecor:           return "THAT'S FOOD"
        case .emptySlot:          return "NOTHING THERE"
        case .notMoltReady, .badName:
            return "CAN'T DO THAT"
```

- [ ] **Step 5: BUILD** — expected `** BUILD SUCCEEDED **` (the view doesn't use the new API yet).

- [ ] **Step 6: Commit**

```bash
git add GrubIOS/Burrow/BurrowHomeModel.swift
git commit -m "feat(burrow): model actions for eating and furnishing" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 6: View — decor layer, place/remove bars, new Finds panel

**Files:**
- Modify: `GrubIOS/Burrow/BurrowHomeView.swift`

- [ ] **Step 1: Decor layer** — in `livingLayer`, draw decor before the markers (so markers and the grub stay on top):

```swift
        ZStack(alignment: .topLeading) {
            ForEach(0..<BurrowRules.decorSlots, id: \.self) { i in decorSlot(i, L, t) }
            ForEach(model.buried, id: \.spot) { f in
```

and add this function after `marker(...)`:

```swift
    @ViewBuilder
    private func decorSlot(_ i: Int, _ L: BurrowLayout, _ t: TimeInterval) -> some View {
        if let p = L.decorSlot(i) {
            let kind = model.placed[i]
            let lit = model.placing != nil && kind == nil && Int(t / 0.3) % 2 == 0
            let selected = model.selectedSlot == i
            let base = L.point(Double(p.x - 3), Double(p.y))
            PixelImage(buffer: lit ? IconArt.pedestalLit : IconArt.pedestalDim, cell: L.cell)
                .position(x: base.x + 3 * L.cell, y: base.y + L.cell)
            if let kind {
                let spr = kind.sprite
                let bob = selected && Int(t / 0.25) % 2 == 0 ? 1 : 0
                // Whole-cell top-left so 5-wide sprites stay on the pixel grid: centred on the
                // 6-wide pedestal (x-3…x+2), bottom row just above the pedestal top (row p.y).
                let left = p.x - 3 + (6 - spr.width) / 2
                let top = p.y - bob - spr.height
                let o = L.point(Double(left), Double(top))
                PixelImage(buffer: spr, cell: L.cell)
                    .position(x: o.x + CGFloat(spr.width) * L.cell / 2,
                              y: o.y + CGFloat(spr.height) * L.cell / 2)
            }
            let tappable = (model.placing != nil && kind == nil) || (model.placing == nil && kind != nil)
            if tappable {
                Color.clear
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
                    .position(L.point(Double(p.x), Double(p.y - 3)))
                    .onTapGesture { model.tapSlot(i) }
                    .accessibilityElement()
                    .accessibilityLabel(kind.map { "\($0.label.capitalized) decoration" } ?? "Empty spot")
                    .accessibilityHint(kind == nil ? "Place it here" : "Remove it")
                    .accessibilityAddTraits(.isButton)
            }
        }
    }
```

- [ ] **Step 2: Place/remove bars in the HUD** — in `bottomHUD`, replace the `if let msg = model.toast { … }` block with:

```swift
            if let msg = model.toast {      // toasts stay visible above a bar (e.g. TOO FULL! while placing)
                Text(msg)
                    .font(GrubFont.size(9)).lineSpacing(6).multilineTextAlignment(.center)
                    .foregroundColor(Color(ink: BurrowInk.cream))
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color(ink: BurrowInk.hollow))
                    .overlay(Rectangle().strokeBorder(Color(ink: BurrowInk.amber), lineWidth: 3))
                    .transition(.opacity)
            }
            if let kind = model.placing {
                hudBar("PLACE \(kind.label):\nTAP A GLOWING SPOT", button: "CANCEL",
                       action: { model.cancelPlacing() })
            } else if let slot = model.selectedSlot, let kind = model.placed[slot] {
                hudBar("REMOVE \(kind.label)?", button: "REMOVE", secondary: "KEEP",
                       action: { model.removeSelected() }, secondaryAction: { model.clearSelection() })
            }
```

and add the helper after `hudButton(...)`:

```swift
    private func hudBar(_ text: String, button: String, secondary: String? = nil,
                        action: @escaping () -> Void, secondaryAction: (() -> Void)? = nil) -> some View {
        HStack(spacing: 10) {
            Text(text)
                .font(GrubFont.size(8)).lineSpacing(5)
                .foregroundColor(Color(ink: BurrowInk.cream))
                .frame(maxWidth: .infinity, alignment: .leading)
            if let secondary, let secondaryAction {
                pixelButton(secondary, ink: BurrowInk.creamDim, action: secondaryAction)
            }
            pixelButton(button, ink: BurrowInk.amber, action: action)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Color(ink: BurrowInk.hollow))
        .overlay(Rectangle().strokeBorder(Color(ink: BurrowInk.teal), lineWidth: 3))
    }

    private func pixelButton(_ title: String, ink: UInt32, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(GrubFont.size(8)).foregroundColor(Color(ink: BurrowInk.hollow))
                .padding(.horizontal, 10).padding(.vertical, 9)
                .background(Color(ink: ink))
        }
        .buttonStyle(PixelPressStyle())
    }
```

  Also add `.animation(.easeOut(duration: 0.15), value: model.placing)` and `.animation(.easeOut(duration: 0.15), value: model.selectedSlot)` next to the existing `.animation(…, value: model.toast)`. Always pass the bar closures with their labels (`action:` / `secondaryAction:`), never as trailing closures — with two closure parameters a trailing closure is ambiguous to read.

- [ ] **Step 3: New Finds panel** — replace the whole `struct FindsBagView` with:

```swift
/// What the grub has dug up (spec §3). Pick a find, then EAT it (food) or PLACE it (decor).
struct FindsBagView: View {
    let bag: [FindKind: Int]
    let canAct: Bool
    let freeSlots: Int
    let onEat: (FindKind) -> Void
    let onPlace: (FindKind) -> Void
    let close: () -> Void
    @State private var picked: FindKind?

    private let columns = Array(repeating: GridItem(.fixed(64), spacing: 10), count: 4)

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea().onTapGesture(perform: close)
            VStack(spacing: 16) {
                Text("FINDS").font(GrubFont.size(14)).foregroundColor(Color(ink: BurrowInk.cream))
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(FindKind.allCases) { cell($0) }
                }
                actionRow
                Text("FOOD FEEDS YOUR GRUB.\nDECOR GOES IN THE ROOMS.")
                    .font(GrubFont.size(7)).lineSpacing(6).multilineTextAlignment(.center)
                    .foregroundColor(Color(ink: BurrowInk.mutedText))
                Button(action: close) {
                    Text("CLOSE").font(GrubFont.size(10)).foregroundColor(Color(ink: BurrowInk.hollow))
                        .padding(.horizontal, 22).padding(.vertical, 12)
                        .background(Color(ink: BurrowInk.amber))
                }
                .buttonStyle(PixelPressStyle())
            }
            .padding(20)
            .background(Color(ink: BurrowInk.hollow))
            .overlay(Rectangle().strokeBorder(Color(ink: BurrowInk.soil1), lineWidth: 4))
            .padding(20)
        }
        .onChange(of: bag) { _, newBag in
            if let k = picked, (newBag[k] ?? 0) == 0 { picked = nil }
        }
    }

    private func cell(_ k: FindKind) -> some View {
        let n = bag[k] ?? 0
        let isPicked = picked == k
        return Button { picked = isPicked ? nil : k } label: {
            VStack(spacing: 6) {
                PixelImage(buffer: n > 0 ? k.sprite : k.sprite.silhouette(BurrowInk.root), cell: 6)
                    .frame(width: 60, height: 60)
                    .background(Color(ink: n > 0 ? BurrowInk.cream : BurrowInk.soil4))
                    .overlay(Rectangle().strokeBorder(
                        Color(ink: isPicked ? BurrowInk.teal : (n > 0 ? BurrowInk.amberLo : BurrowInk.soil1)),
                        lineWidth: 3))
                Text(n > 0 ? k.label : "???").font(GrubFont.size(6))
                    .foregroundColor(Color(ink: BurrowInk.cream))
                Text(n > 0 ? "x\(n)" : " ").font(GrubFont.size(8))
                    .foregroundColor(Color(ink: BurrowInk.amber))
            }
        }
        .buttonStyle(PixelPressStyle())
        .disabled(n == 0)
        .accessibilityLabel(n > 0 ? "\(k.label.capitalized), \(n)" : "Not found yet")
    }

    @ViewBuilder
    private var actionRow: some View {
        if let k = picked, canAct {
            let full = k.isDecor && freeSlots == 0
            Button { k.isFood ? onEat(k) : onPlace(k) } label: {
                Text(k.isFood ? "EAT \(k.label)" : (full ? "ROOMS FULL" : "PLACE \(k.label)"))
                    .font(GrubFont.size(9)).foregroundColor(Color(ink: BurrowInk.hollow))
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    .background(Color(ink: full ? BurrowInk.creamDim : BurrowInk.teal))
            }
            .buttonStyle(PixelPressStyle())
            .disabled(full)
        } else {
            Text(canAct ? "TAP A FIND" : " ")
                .font(GrubFont.size(8)).foregroundColor(Color(ink: BurrowInk.mutedText))
                .frame(height: 34)
        }
    }
}
```

- [ ] **Step 4: Wire the panel** — replace the `FindsBagView(bag: model.bag) { … }` call in `body` with:

```swift
                FindsBagView(bag: model.bag, canAct: model.canAct, freeSlots: model.freeSlots.count,
                             onEat: { k in closeBag(); model.feed(kind: k) },
                             onPlace: { k in closeBag(); model.startPlacing(k) },
                             close: closeBag)
                    .transition(.opacity)
```

and add `private func closeBag() { withAnimation(.easeOut(duration: 0.15)) { showBag = false } }`. Replace the FINDS `hudButton`'s action so opening the panel also ends placing/selection:

```swift
                    hudButton(icon: IconArt.pouch, title: "FINDS", count: model.findCount) {
                        model.cancelPlacing()
                        model.clearSelection()
                        withAnimation(.easeOut(duration: 0.15)) { showBag = true }
                    }
```

- [ ] **Step 5: Demo script + `-burrowShowBag`** — replace `runDemoIfRequested` with the phase-2 script. Each state the screenshots need lasts ≥ 2.5 s so `simctl` latency can't miss it:

```swift
    #if DEBUG
    /// `-burrowDemo` (use with `-burrowReset`). Times are seconds after the view appears:
    ///  1.5/3.0/4.5 dig all three · 6.0 eat berry · 7.5 eat root (variety → +joy; fed state until 10.0)
    /// 10.0 start placing the crystal (slots glow until 12.5) · 12.5 place it in slot 2
    /// 15.0 pet · 16.0 select the crystal (REMOVE bar until 19.0) · 19.0 remove · 21.5 open Finds
    private func runDemoIfRequested() async {
        guard BurrowDebug.demo else { return }
        func wait(_ s: Double) async { try? await Task.sleep(nanoseconds: UInt64(s * 1_000_000_000)) }
        await wait(1.5)
        for _ in 0..<3 {
            if let f = model.buried.first { model.dig(spot: f.spot) }
            await wait(1.5)
        }
        model.feed(); await wait(1.5)                   //  6.0
        model.feed(); await wait(2.5)                   //  7.5
        model.startPlacing(.crystal); await wait(2.5)   // 10.0
        model.tapSlot(2); await wait(2.5)               // 12.5
        model.pet(); await wait(1.0)                    // 15.0
        model.tapSlot(2); await wait(3.0)               // 16.0
        model.removeSelected(); await wait(2.5)         // 19.0
        withAnimation { showBag = true }                // 21.5
    }
    #endif
```

Also add the panel-only debug flag used in Task 7. In `BurrowHomeModel.swift`'s `enum BurrowDebug` add:

```swift
    /// `-burrowShowBag`: open the Finds panel on launch.
    static var showBag: Bool { args.contains("-burrowShowBag") }
```

and in `BurrowHomeView` change the DEBUG task to:

```swift
        #if DEBUG
        .task {
            if BurrowDebug.showBag { showBag = true }
            await runDemoIfRequested()
        }
        #endif
```

- [ ] **Step 6: BUILD**, then run all burrow tests: TEST `BurrowRulesTests -only-testing:GrubIOSTests/BurrowStoreTests -only-testing:GrubIOSTests/BurrowLayoutTests -only-testing:GrubIOSTests/BurrowPacingTests`. Expected: build succeeds; all pass.

- [ ] **Step 7: Commit**

```bash
git add GrubIOS/Burrow/BurrowHomeView.swift GrubIOS/Burrow/BurrowHomeModel.swift
git commit -m "feat(burrow): decor in the burrow and an EAT/PLACE Finds panel" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 7: Simulator verification

**Files:** none (verification; may adjust sprite art or slot offsets)

Variables: `D=8AABF67E-2193-4949-8A0E-0954E9789898`, `B=com.jessedev.GrubIOS`, `APP=build/dd/Build/Products/Debug-iphonesimulator/GrubIOS.app`, `OUT=<scratchpad>/p2`.

- [ ] **Step 1: Run the demo and capture its key moments** — screenshots are taken at fixed times from launch, each ≥ 1.5 s into its state, because the demo's clock starts up to ~1 s after `simctl launch` returns:

```bash
mkdir -p $OUT; xcrun simctl install $D $APP
xcrun simctl terminate $D $B 2>/dev/null
python3 - "$D" "$B" "$OUT" <<'EOF'
import subprocess, sys, time
d, b, out = sys.argv[1:]
subprocess.run(["xcrun", "simctl", "launch", d, b, "-burrowReset", "-burrowDemo"], capture_output=True)
t0 = time.time()
for at, name in [(9.0, "p2_fed"), (11.5, "p2_placing"), (14.0, "p2_placed"), (17.5, "p2_remove"), (23.0, "p2_bag")]:
    time.sleep(max(0, t0 + at - time.time()))
    subprocess.run(["xcrun", "simctl", "io", d, "screenshot", f"{out}/{name}.png"], capture_output=True)
    print(name, round(time.time() - t0, 1))
EOF
```

Expected (no bonus finds: Joy is 6 while digging):
- `p2_fed`: Belly 10 (6+3+3, capped), Joy 8 (two different foods), MOLT 2, FEED 1 (the starting berry + the dug berry, one eaten), FINDS 2 (berry + crystal), three dug holes, no "!" markers.
- `p2_placing`: "PLACE CRYSTAL: TAP A GLOWING SPOT" bar with CANCEL; the four pedestals blink amber.
- `p2_placed`: the crystal stands on the chamber's left pedestal, not overlapping the grub; bar gone.
- `p2_remove`: "REMOVE CRYSTAL?" bar with KEEP / REMOVE; the crystal bobs. Joy 9 (pet).
- `p2_bag`: Finds panel in 2 rows of 4; BERRY x1 and CRYSTAL x1 (back in the bag); ROOT shows "???" (eaten); "TAP A FIND" under the grid.

- [ ] **Step 2: All four slots + the new sprites** — write a save with every decor placed and every find in the bag, then screenshot the burrow and the panel:

```bash
SAVE="$(xcrun simctl get_app_container $D $B data)/Library/Application Support/burrow.json"
xcrun simctl terminate $D $B
python3 - "$SAVE" <<'EOF'
import json, sys, time
p = sys.argv[1]; d = json.load(open(p))
d['placed'] = {'0': 'amber', '1': 'shell', '2': 'bone', '3': 'crystal'}
d['bag'] = {k: 1 for k in ['berry','root','mushroom','honeydew','amber','bone','crystal','shell']}
d['lastTick'] = time.time() - 978307200
json.dump(d, open(p, 'w'))
EOF
xcrun simctl launch $D $B >/dev/null; sleep 4; xcrun simctl io $D screenshot $OUT/p2_slots.png >/dev/null 2>&1
xcrun simctl terminate $D $B; xcrun simctl launch $D $B -burrowShowBag >/dev/null; sleep 3; xcrun simctl io $D screenshot $OUT/p2_allfinds.png >/dev/null 2>&1
```

(`-burrowShowBag` was added in Task 6, Step 5, and the app installed in Step 1 already has it.)

Expected: `p2_slots` — amber in the left room, shell in the right room, bone and crystal in the chamber's corners, none overlapping the grub, tunnels or each other; JOY drains slower is not visible (fine). `p2_allfinds` — all 8 sprites readable on the cream cells; root, mushroom, honeydew, shell are clearly distinct from berry, amber, bone, crystal.

- [ ] **Step 3: Fix and recheck** anything that fails Step 1 or 2 (sprite tweaks in `BurrowArt.swift`, slot offsets in `decorSlot` — then rerun `BurrowLayoutTests`).

- [ ] **Step 4: Report** — send Jesse a sheet of the seven screenshots with expected-vs-seen notes. Mention that placed decor reuses each find's sprite on a pedestal (the spec's "placed versions" art), so he can ask for dedicated placed art if he wants it.

- [ ] **Step 5: Commit** any fixes (skip if nothing changed):

```bash
git add GrubIOS/Burrow/BurrowHomeModel.swift GrubIOS/Burrow/BurrowHomeView.swift GrubIOS/Burrow/BurrowArt.swift
git commit -m "chore(burrow): phase 2 simulator checks" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Done when

- All burrow test classes pass (rules, store, layout, pacing).
- The demo and the all-slots save match the expected screenshots.
- Eating a chosen food, placing decor, and removing it all work from the Finds panel and the burrow.
