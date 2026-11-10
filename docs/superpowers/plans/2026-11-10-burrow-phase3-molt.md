# Burrow Phase 3 (Molt) Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When MOLT is full the grub glows; tapping it wraps it in a cocoon and reveals one of six adults, rolled from odds that the grub's diet, the placed decor and its lineage shift. A molt panel shows the live odds.

**Architecture:** Same layers as phases 1–2. Pure rules gain `odds`, `roll`, `isMoltReady`, `startMolt` (the roll and the stage change happen in one rule call, so the save never holds a half-finished molt). Adult sprites are generated from the contact sheet's exact rectangles by a fixed 1.5× rule. The cocoon and reveal are view-only animations driven by the `.molted` event. Spec: `docs/superpowers/specs/2026-11-10-burrow-mechanics-design.md` §4 "Molt", "HUD by stage", "Art needed".

**Tech Stack:** Swift 5.9, SwiftUI, iOS 17, XCTest, XcodeGen.

---

## Ground rules

- Phases 1–2 are committed on `the-deep` (HEAD `55ff6e8`); 41 burrow tests pass.
- Commit after each task, staging only that task's files; `git add -f GrubIOS.xcodeproj/project.pbxproj` only when a task adds files. Never stage `GrubIOS/GrubIOSApp.swift` or `grub_canon.png`. Messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Phase 3 ends at the revealed adult.** Pinning it and the next egg are phase 4. In phase 3 the adult stays in the chamber; tapping it re-opens its reveal card. The game can't progress past the adult yet. That is expected; `-burrowReset` starts over.
- **GRUB's adult reuses the larva sprite** (`GrubArt.idle`). Auto-scaling the contact sheet's GRUB gives a 22×28 version that differs slightly from the hand-drawn 21×26 larva; using one sprite avoids two near-identical grubs.
- **CLAWS is 36 cells wide**, the full chamber width, so in `.adult` it overlaps the chamber-corner decor (drawn behind it). Accepted for phase 3; the adult only sits there until phase 4's pin.
- Commands from `/Users/jessedev/Documents/Code/grub/GrubIOS`:

```bash
# TEST: replace <Class>
xcodebuild test -project GrubIOS.xcodeproj -scheme GrubIOS -destination 'id=8AABF67E-2193-4949-8A0E-0954E9789898' -derivedDataPath build/dd -only-testing:GrubIOSTests/<Class> 2>&1 | grep -E "error:|Test Case.*failed|XCTAssert|Executed .* tests|TEST (SUCCEEDED|FAILED)" | tail -12
```

```bash
# BUILD
xcodebuild -project GrubIOS.xcodeproj -scheme GrubIOS -configuration Debug -destination 'id=8AABF67E-2193-4949-8A0E-0954E9789898' -derivedDataPath build/dd build 2>&1 | grep -E "error:|BUILD" | head -20
```

## File map

| File | Status | Change |
|---|---|---|
| `GrubIOS/Burrow/BurrowRules.swift` | modify | `odds`, `roll`, `isMoltReady`, `startMolt` |
| `GrubIOS/Burrow/SpeciesArt.swift` | create | adult sprites (contact-sheet rects × 1.5), cocoon, grub glow |
| `GrubIOS/Burrow/BurrowHomeModel.swift` | modify | molt state, `tapGrub`, reveal timing, `.molted` FX, DEBUG args |
| `GrubIOS/Burrow/BurrowHomeView.swift` | modify | glow / cocoon / adult in the chamber, molt panel, reveal card, HUD by stage, demo |
| `GrubIOSTests/BurrowRulesTests.swift` | modify | odds, roll, startMolt, adult-stage tests |
| `GrubIOSTests/BurrowLayoutTests.swift` | modify | every adult fits the chamber |

---

## Chunk 1: Rules and art

### Task 1: Odds, roll, startMolt

**Files:** Modify `GrubIOS/Burrow/BurrowRules.swift`; Test `GrubIOSTests/BurrowRulesTests.swift`

- [ ] **Step 1: Write the failing tests** (append to `BurrowRulesTests`)

```swift
    // MARK: molt (phase 3)

    func test_base_odds_favour_grub() {
        let o = BurrowRules.odds(save())
        XCTAssertEqual(o[.grub]!, 2.0 / 7, accuracy: 1e-9)
        for sp in Species.allCases where sp != .grub { XCTAssertEqual(o[sp]!, 1.0 / 7, accuracy: 1e-9) }
        XCTAssertEqual(o.values.reduce(0, +), 1, accuracy: 1e-9)
    }

    func test_diet_shifts_odds() {
        let o = BurrowRules.odds(save { $0.eaten = [.root: 3] })       // claws 1+3 of 10
        XCTAssertEqual(o[.claws]!, 0.4, accuracy: 1e-9)
    }

    func test_placed_decor_counts_double_only_while_placed() {
        let placed = save { $0.placed = [0: .crystal] }                // horn 1+2 of 9
        XCTAssertEqual(BurrowRules.odds(placed)[.horn]!, 3.0 / 9, accuracy: 1e-9)
        let r = BurrowRules.remove(placed, slot: 0, now: t0).save
        XCTAssertEqual(BurrowRules.odds(r)[.horn]!, 1.0 / 7, accuracy: 1e-9)
    }

    func test_lineage_adds_two() {
        XCTAssertEqual(BurrowRules.odds(save { $0.lineage = .stalk })[.stalk]!, 3.0 / 9, accuracy: 1e-9)
    }

    func test_roll_matches_odds() {
        let o = BurrowRules.odds(save { $0.eaten = [.root: 3] })
        var counts: [Species: Int] = [:]
        for _ in 0..<20_000 { counts[BurrowRules.roll(o, rng: &rng), default: 0] += 1 }
        for sp in Species.allCases {
            XCTAssertEqual(Double(counts[sp] ?? 0) / 20_000, o[sp]!, accuracy: 0.015, "\(sp)")
        }
    }

    func test_start_molt_needs_a_full_molt_bar() {
        XCTAssertFalse(BurrowRules.isMoltReady(save { $0.molt = 9 }))
        XCTAssertEqual(BurrowRules.startMolt(save { $0.molt = 9 }, now: t0, rng: &rng).events, [.refused(.notMoltReady)])
        XCTAssertEqual(BurrowRules.startMolt(save { $0.molt = 10; $0.stage = .egg }, now: t0, rng: &rng).events,
                       [.refused(.wrongStage)])
    }

    func test_start_molt_rolls_and_becomes_adult_in_one_step() {
        let s = save { $0.molt = 10 }
        XCTAssertTrue(BurrowRules.isMoltReady(s))
        let r = BurrowRules.startMolt(s, now: t0, rng: &rng)
        guard case .molted(let sp) = r.events.first else { return XCTFail("\(r.events)") }
        XCTAssertEqual(r.events.count, 1)
        XCTAssertEqual(r.save.stage, .adult)
        XCTAssertEqual(r.save.adult, sp)
        XCTAssertFalse(BurrowRules.isMoltReady(r.save))
    }

    func test_adult_stage_freezes_care() {
        let adult = BurrowRules.startMolt(save { $0.molt = 10; $0.belly = 5 }, now: t0, rng: &rng).save
        XCTAssertEqual(BurrowRules.feed(adult, kind: nil, now: t0).events, [.refused(.wrongStage)])
        XCTAssertEqual(BurrowRules.pet(adult, now: t0).events, [.refused(.wrongStage)])
        XCTAssertEqual(advance(adult, hours: 10).save.belly, 5, "belly/joy only drain for a larva")
    }
```

- [ ] **Step 2: Run to verify it fails** — TEST `BurrowRulesTests`. Expected: `type 'BurrowRules' has no member 'odds'`.

- [ ] **Step 3: Implement** — add to `BurrowRules` before `// MARK: Furnishing`:

```swift
    // MARK: Molt

    static func isMoltReady(_ s: BurrowSave) -> Bool { s.stage == .larva && s.molt >= moltGoal }

    /// Spec §4: every species weighs 1 (GRUB 2); +1 per food eaten that leans to it,
    /// +2 per placed decor that leans to it (only while placed), +2 for the lineage species.
    static func odds(_ s: BurrowSave) -> [Species: Double] {
        var w: [Species: Double] = [:]
        for sp in Species.allCases { w[sp] = sp == .grub ? 2 : 1 }
        for (kind, n) in s.eaten where kind.isFood { w[kind.leansTo, default: 0] += Double(n) }
        for kind in s.placed.values { w[kind.leansTo, default: 0] += 2 }
        if let l = s.lineage { w[l, default: 0] += 2 }
        let total = w.values.reduce(0, +)
        return w.mapValues { $0 / total }
    }

    /// Weighted pick in `Species.allCases` order (deterministic for a seeded RNG).
    static func roll(_ odds: [Species: Double], rng: inout some RandomNumberGenerator) -> Species {
        var r = Double.random(in: 0..<1, using: &rng)
        for sp in Species.allCases {
            let p = odds[sp] ?? 0
            if r < p { return sp }
            r -= p
        }
        return .grub   // floating-point leftovers
    }

    /// Roll the adult and become it in one step, so a save never holds a half-finished molt.
    /// The cocoon and reveal are view-only animations played on `.molted`.
    static func startMolt(_ s0: BurrowSave, now: Date,
                          rng: inout some RandomNumberGenerator) -> BurrowResult {
        guard s0.stage == .larva else { return refuse(s0, .wrongStage) }
        guard s0.molt >= moltGoal else { return refuse(s0, .notMoltReady) }
        var s = s0
        let sp = roll(odds(s0), rng: &rng)
        s.adult = sp
        s.stage = .adult
        return BurrowResult(save: s, events: [.molted(sp)])
    }
```

- [ ] **Step 4: Run to verify it passes** — TEST `BurrowRulesTests`. Expected: 38 tests passed (30 + 8).

- [ ] **Step 5: Commit**

```bash
git add GrubIOS/Burrow/BurrowRules.swift GrubIOSTests/BurrowRulesTests.swift
git commit -m "feat(burrow): molt odds, roll and startMolt" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 2: Adult sprites, cocoon, glow

**Files:** Create `GrubIOS/Burrow/SpeciesArt.swift`; Modify `GrubIOSTests/BurrowLayoutTests.swift`

The contact sheet (`docs/burrow/species-contact-sheet.html`) draws each species on a 24×24 grid. The rects below are copied exactly from its SVGs. They're scaled to the world grid by **edge scaling**: left/top edges `floor(e × 1.5)`, right/bottom edges `ceil(e × 1.5)`, then cropped to the bounding box. Edge scaling keeps every species left-right symmetric and makes equal source features (eyes, glints) come out the same size. Resulting sizes: HORN 22×28, FUZZ 28×26, SHELL 24×23, CLAWS 36×23, STALK 29×26; GRUB reuses the 21×26 larva.

- [ ] **Step 1: Write the failing test** (append to `BurrowLayoutTests`)

```swift
    func test_every_adult_fits_the_chamber() {
        for L in layouts {
            for sp in Species.allCases {
                let spr = SpeciesArt.adult(sp)
                XCTAssertLessThanOrEqual(spr.width, L.chamber.w, "\(sp) width")
                XCTAssertLessThanOrEqual(spr.height, L.chamber.h, "\(sp) height")
            }
        }
        XCTAssertEqual(SpeciesArt.adult(.grub).width, GrubArt.width, "GRUB's adult is the larva sprite")
        XCTAssertEqual(SpeciesArt.adult(.claws).width, 36)
        XCTAssertEqual(SpeciesArt.adult(.horn).height, 28)
    }
```

- [ ] **Step 2: Run to verify it fails** — `xcodegen generate && ` + TEST `BurrowLayoutTests`. Expected: `cannot find 'SpeciesArt' in scope`.

- [ ] **Step 3: Create `SpeciesArt.swift`**

```swift
import Foundation

/// Adult sprites from the species contact sheet, plus the cocoon and the molt-ready glow.
enum SpeciesArt {
    /// A rect on the contact sheet's 24×24 grid.
    struct R { let x, y, w, h: Int; let c: UInt32
        init(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ c: UInt32) { self.x = x; self.y = y; self.w = w; self.h = h; self.c = c }
    }

    /// The adult as it stands in the chamber and on the reveal card.
    static func adult(_ sp: Species) -> PixelBuffer { cache[sp] ?? GrubArt.idle }

    private static let cache: [Species: PixelBuffer] = {
        var out: [Species: PixelBuffer] = [.grub: GrubArt.idle]
        for sp in Species.allCases where sp != .grub { out[sp] = scaled(rects(sp)) }
        return out
    }()

    /// Edge scaling ×1.5: left/top floor, right/bottom ceil, cropped to the bounding box.
    static func scaled(_ rs: [R]) -> PixelBuffer {
        let s = rs.map { r -> (Int, Int, Int, Int, UInt32) in
            let x0 = Int((Double(r.x) * 1.5).rounded(.down)), y0 = Int((Double(r.y) * 1.5).rounded(.down))
            let x1 = Int((Double(r.x + r.w) * 1.5).rounded(.up)), y1 = Int((Double(r.y + r.h) * 1.5).rounded(.up))
            return (x0, y0, x1 - x0, y1 - y0, r.c)
        }
        let minX = s.map(\.0).min() ?? 0, minY = s.map(\.1).min() ?? 0
        let maxX = s.map { $0.0 + $0.2 }.max() ?? 1, maxY = s.map { $0.1 + $0.3 }.max() ?? 1
        var b = PixelBuffer(width: maxX - minX, height: maxY - minY)
        for (x, y, w, h, c) in s { b.fill(x - minX, y - minY, w, h, c) }
        return b
    }

    // Exact rects from docs/burrow/species-contact-sheet.html, in SVG paint order.
    private static func rects(_ sp: Species) -> [R] {
        switch sp {
        case .grub:
            return []
        case .horn:
            return [
            R(8,10,8,1,0x8f6fe0), R(6,11,12,1,0x8f6fe0), R(5,12,14,7,0x8f6fe0), R(6,19,12,1,0x8f6fe0),
            R(8,20,8,1,0x8f6fe0), R(5,20,2,1,0x8f6fe0), R(17,20,2,1,0x8f6fe0), R(16,12,3,7,0x6a4fc0),
            R(11,7,2,3,0xe8e0c0), R(11,5,1,2,0xe8e0c0), R(10,3,1,2,0xe8e0c0), R(12,4,1,1,0xe8e0c0),
            R(7,13,3,3,0x0d0814), R(14,13,3,3,0x0d0814), R(7,13,1,1,0xffffff), R(14,13,1,1,0xffffff),
            R(11,17,2,1,0x0d0814)
            ]
        case .fuzz:
            return [
            R(8,8,8,1,0xf5a623), R(6,9,12,1,0xf5a623), R(5,10,14,9,0xf5a623), R(6,19,12,1,0xf5a623),
            R(8,20,8,1,0xf5a623), R(5,16,14,1,0x854f0b), R(6,19,12,1,0x854f0b), R(4,9,1,1,0xffe2a8),
            R(3,12,2,1,0xffe2a8), R(4,15,1,1,0xffe2a8), R(3,18,2,1,0xffe2a8), R(19,9,1,1,0xffe2a8),
            R(19,12,2,1,0xffe2a8), R(19,15,1,1,0xffe2a8), R(19,18,2,1,0xffe2a8), R(7,6,1,2,0xffe2a8),
            R(11,5,1,3,0xffe2a8), R(15,6,1,2,0xffe2a8), R(9,21,1,1,0xffe2a8), R(14,21,1,1,0xffe2a8),
            R(7,11,3,3,0x0d0814), R(14,11,3,3,0x0d0814), R(7,11,1,1,0xffffff), R(14,11,1,1,0xffffff),
            R(11,14,2,1,0x0d0814)
            ]
        case .shell:
            return [
            R(5,14,14,5,0xc9c0a0), R(6,19,12,1,0xc9c0a0), R(8,20,8,1,0xc9c0a0), R(9,7,6,1,0x6f8fb0),
            R(7,8,10,1,0x6f8fb0), R(6,9,12,1,0x6f8fb0), R(5,10,14,4,0x6f8fb0), R(5,11,14,1,0x4f6f90),
            R(5,13,14,1,0x4f6f90), R(6,21,1,1,0x4f6f90), R(9,21,1,1,0x4f6f90), R(14,21,1,1,0x4f6f90),
            R(17,21,1,1,0x4f6f90), R(4,14,16,1,0x9fb8d0), R(8,8,3,1,0x9fb8d0), R(7,15,3,3,0x0d0814),
            R(14,15,3,3,0x0d0814), R(7,15,1,1,0xffffff), R(14,15,1,1,0xffffff), R(11,18,2,1,0x0d0814)
            ]
        case .claws:
            return [
            R(8,8,8,1,0xc97b3a), R(6,9,12,1,0xc97b3a), R(5,10,14,9,0xc97b3a), R(6,19,12,1,0xc97b3a),
            R(8,20,8,1,0xc97b3a), R(4,13,1,2,0xc97b3a), R(19,13,1,2,0xc97b3a), R(9,6,1,2,0xc97b3a),
            R(14,6,1,2,0xc97b3a), R(16,10,3,9,0xa05f28), R(1,11,3,1,0xe8e0c0), R(0,12,4,4,0xe8e0c0),
            R(1,16,3,1,0xe8e0c0), R(20,11,3,1,0xe8e0c0), R(20,12,4,4,0xe8e0c0), R(20,16,3,1,0xe8e0c0),
            R(1,13,1,3,0xc9c0a0), R(22,13,1,3,0xc9c0a0), R(7,11,3,3,0x0d0814), R(14,11,3,3,0x0d0814),
            R(7,11,1,1,0xffffff), R(14,11,1,1,0xffffff), R(11,16,2,1,0x0d0814)
            ]
        case .stalk:
            return [
            R(7,13,10,1,0xed93b1), R(5,14,14,1,0xed93b1), R(4,15,16,5,0xed93b1), R(5,20,14,1,0xed93b1),
            R(8,7,1,6,0xed93b1), R(15,7,1,6,0xed93b1), R(18,15,2,5,0xd4537e), R(6,17,2,1,0xd4537e),
            R(15,17,2,1,0xd4537e), R(7,4,3,3,0xffffff), R(14,4,3,3,0xffffff), R(8,5,1,1,0x0d0814),
            R(15,5,1,1,0x0d0814), R(11,17,2,1,0x0d0814), R(21,20,2,1,0xf4c0d1)
            ]
        }
    }

    /// Silk cocoon, 15×20, shown while the molt plays.
    static let cocoon = PixelBuffer(art: [
        ".....CCCCC.....",
        "...CCCCCCCCC...",
        "..CCDCCCCCCCC..",
        ".CCCCCCCCCDCCC.",
        ".CDDDDDDDDDDDC.",
        ".CCCCCCCCCCCCC.",
        "CCCCCCCCCCCCCCC",
        "CCCDCCCCCCCCCCC",
        "CDDDDDDDDDDDDDC",
        "CCCCCCCCCCCCCCC",
        "CCCCCCCCCCCDCCC",
        "CCCCCCCCCCCCCCC",
        "CDDDDDDDDDDDDDC",
        ".CCCCCCCCCCCCC.",
        ".CCCCCCCDCCCCC.",
        ".CDDDDDDDDDDDC.",
        "..CCCCCCCCCCC..",
        "...CCCCCCCCC...",
        ".....CCCCC.....",
        "......DDD......"],
        palette: ["C": BurrowInk.cream, "D": BurrowInk.creamDim])

    /// The larva's outline colour for the molt-ready glow (drawn at ±1 cell behind the grub).
    static let glow = GrubArt.idle.silhouette(BurrowInk.amberHi)
}
```

- [ ] **Step 4: Run to verify it passes** — `xcodegen generate && ` + TEST `BurrowLayoutTests`. Expected: 3 tests passed. BUILD too.

- [ ] **Step 5: Commit**

```bash
git add GrubIOS/Burrow/SpeciesArt.swift GrubIOSTests/BurrowLayoutTests.swift
git add -f GrubIOS.xcodeproj/project.pbxproj
git commit -m "feat(burrow): six adult sprites, cocoon and molt glow" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Chunk 2: Model, view, verification

### Task 3: Model

**Files:** Modify `GrubIOS/Burrow/BurrowHomeModel.swift`

- [ ] **Step 1: State and read-outs** — after `@Published private(set) var selectedSlot: Int?` add:

```swift
    /// Animation-clock time the cocoon started (`.molted`); the view plays ~3 s of cocoon.
    @Published private(set) var moltAt: TimeInterval = -100
    /// The adult whose reveal card is showing.
    @Published private(set) var revealing: Species?
```

and after `var canAct …`:

```swift
    var stage: GrubStage { save.stage }
    var adult: Species? { save.adult }
    var isMoltReady: Bool { BurrowRules.isMoltReady(save) }
    var odds: [Species: Double] { BurrowRules.odds(save) }
    static let cocoonSeconds: TimeInterval = 3
```

- [ ] **Step 2: Actions** — after `func clearSelection() …`:

```swift
    /// Tap on the grub: start the molt when ready, otherwise pet. In `.adult`, re-open the card.
    func tapGrub() {
        switch save.stage {
        case .larva:
            if isMoltReady { apply(BurrowRules.startMolt(save, now: clock(), rng: &rng)) } else { pet() }
        case .adult:
            revealing = save.adult
        case .egg:
            break   // phase 4
        }
    }

    func dismissReveal() { revealing = nil }
```

and guard `tapSlot` so decor can't be selected outside `.larva` — make its first line `guard canAct else { return }`.

- [ ] **Step 3: Events** — in `handle(_:)`, add before `case .moltReady:`:

```swift
        case .molted(let sp):
            moltAt = t
            placing = nil
            selectedSlot = nil
            Haptics.thud()
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(Self.cocoonSeconds * 1_000_000_000))
                self?.revealing = sp
                Haptics.thud()
            }
```

Update the `.notMoltReady` message: in `message(_:)` replace `case .notMoltReady, .badName: return "CAN'T DO THAT"` with:

```swift
        case .notMoltReady:       return "NOT READY\nTO MOLT YET"
        case .badName:            return "CAN'T DO THAT"
```

- [ ] **Step 4: DEBUG launch args** — in `enum BurrowDebug` add:

```swift
    /// `-burrowMoltReady`: start with a full MOLT bar and a root-heavy diet (odds visibly shifted).
    static var moltReady: Bool { args.contains("-burrowMoltReady") }
    /// `-burrowAdult <species>`: start as that revealed adult (e.g. `-burrowAdult horn`).
    static var adult: Species? {
        guard let i = args.firstIndex(of: "-burrowAdult"), i + 1 < args.count else { return nil }
        return Species(rawValue: args[i + 1])
    }
    /// `-burrowMoltDemo`: script the molt (see BurrowHomeView).
    static var moltDemo: Bool { args.contains("-burrowMoltDemo") }
```

and in `init`, inside the second `#if DEBUG` block after the `skipHours` line:

```swift
        if BurrowDebug.moltReady {
            loaded.molt = BurrowRules.moltGoal
            loaded.eaten = [.root: 3, .berry: 2]     // odds: GRUB 4/12, CLAWS 4/12, others 1/12
        }
        if let sp = BurrowDebug.adult { loaded.stage = .adult; loaded.adult = sp }
```

- [ ] **Step 5: BUILD**, expected success. **Commit**

```bash
git add GrubIOS/Burrow/BurrowHomeModel.swift
git commit -m "feat(burrow): model molt flow and reveal timing" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 4: View

**Files:** Modify `GrubIOS/Burrow/BurrowHomeView.swift`

- [ ] **Step 1: State** — after `@State private var showBag = false` add `@State private var showMolt = false`.

- [ ] **Step 2: The chamber's occupant by stage** — replace the whole `grub(_:_:)` function with:

```swift
    private func grub(_ L: BurrowLayout, _ t: TimeInterval) -> some View {
        let sulking = model.isSulking
        let bounce = !sulking && Int(t / 0.4) % 3 == 1 ? 1 : 0
        let hopP = (t - model.hopAt) / 0.42
        let hop = (hopP >= 0 && hopP < 1) ? Int((sin(hopP * .pi) * 5).rounded()) : 0
        let inCocoon = t - model.moltAt < BurrowHomeModel.cocoonSeconds
        let sprite: PixelBuffer
        if inCocoon {
            sprite = SpeciesArt.cocoon
        } else if model.stage == .adult, let sp = model.adult {
            sprite = SpeciesArt.adult(sp)
        } else {
            let chomping = t - model.chompAt < 0.9
            let blinking = t.truncatingRemainder(dividingBy: 3.7) < 0.14 || hop > 0
            sprite = chomping ? (Int(t / 0.15) % 2 == 0 ? GrubArt.chomp : GrubArt.idle)
                              : (blinking ? GrubArt.blink : (sulking ? GrubArt.sulk : GrubArt.idle))
        }
        // Cocoon wobbles ±1 cell; everything else bounces/hops.
        let wobble = inCocoon ? Int((sin(t * 9) * 1.4).rounded()) : 0
        let gx = L.chamber.midX - sprite.width / 2 + wobble
        let gy = L.chamber.maxY - sprite.height - (inCocoon ? 0 : bounce + hop)
        let origin = L.point(Double(gx), Double(gy))
        let glowing = model.isMoltReady && !inCocoon && Int(t / 0.4) % 2 == 0

        return ZStack(alignment: .topLeading) {
            if glowing {
                ForEach(0..<4, id: \.self) { k in
                    let d = [(-1, 0), (1, 0), (0, -1), (0, 1)][k]
                    PixelImage(buffer: SpeciesArt.glow, cell: L.cell)
                        .offset(x: CGFloat(d.0) * L.cell, y: CGFloat(d.1) * L.cell)
                }
            }
            PixelImage(buffer: sprite, cell: L.cell)
        }
        .contentShape(Rectangle())
        .onTapGesture { if !inCocoon { model.tapGrub() } }
        .position(x: origin.x + CGFloat(sprite.width) * L.cell / 2,
                  y: origin.y + CGFloat(sprite.height) * L.cell / 2)
        .accessibilityLabel(grubLabel(sulking: sulking, inCocoon: inCocoon))
        .accessibilityHint(model.isMoltReady ? "Start the molt" : (model.stage == .adult ? "See your adult" : "Pet your grub"))
        .accessibilityAddTraits(.isButton)
    }

    private func grubLabel(sulking: Bool, inCocoon: Bool) -> String {
        if inCocoon { return "Cocoon" }
        if model.stage == .adult, let sp = model.adult { return "Adult \(sp.label.capitalized)" }
        if model.isMoltReady { return "Grub, ready to molt" }
        return sulking ? "Grub, hungry and sulking" : "Grub"
    }
```

The glow silhouette is the larva's, so it only shows while `isMoltReady` (stage `.larva`).

- [ ] **Step 3: HUD by stage** — in `bottomHUD`, replace the stat `HStack(spacing: 12) { statBar(…) ×3 }` with:

```swift
                if model.stage == .adult, let sp = model.adult {
                    VStack(spacing: 6) {
                        Text("MOLTED INTO \(sp.label)!").font(GrubFont.size(9))
                            .foregroundColor(Color(ink: sp.color))
                        Text(sp.blurb).font(GrubFont.size(7))
                            .foregroundColor(Color(ink: BurrowInk.mutedText))
                    }
                    .frame(maxWidth: .infinity, minHeight: 34)
                } else {
                    HStack(spacing: 12) {
                        statBar("BELLY", model.belly, BurrowInk.berry)
                        statBar("JOY", model.joy, BurrowInk.teal, tag: model.isHappy ? "HAPPY" : nil)
                        Button { showMolt = true } label: {
                            statBar("MOLT", model.molt, BurrowInk.amber, tag: model.isMoltReady ? "READY" : nil)
                        }
                        .buttonStyle(PixelPressStyle())
                        .accessibilityHint("Show molt odds")
                    }
                }
```

and disable FEED outside `.larva`: after the FEED `hudButton(...)` call add `.disabled(!model.canAct).opacity(model.canAct ? 1 : 0.4)`.

- [ ] **Step 4: Molt panel and reveal card** — add two overlays after the Finds overlay in `body`:

```swift
        .overlay {
            if showMolt {
                MoltPanelView(molt: model.molt, odds: model.odds) { withAnimation(.easeOut(duration: 0.15)) { showMolt = false } }
                    .transition(.opacity)
            }
        }
        .overlay {
            if let sp = model.revealing {
                RevealCardView(species: sp) { withAnimation(.easeOut(duration: 0.15)) { model.dismissReveal() } }
                    .transition(.opacity)
            }
        }
```

and add these two views at the end of the file (before `#Preview`):

```swift
/// Live molt odds (spec §4): six bars, one per species.
struct MoltPanelView: View {
    let molt: Int
    let odds: [Species: Double]
    let close: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea().onTapGesture(perform: close)
            VStack(spacing: 14) {
                Text("MOLT").font(GrubFont.size(14)).foregroundColor(Color(ink: BurrowInk.cream))
                Text("\(molt)/\(BurrowRules.moltGoal)").font(GrubFont.size(9))
                    .foregroundColor(Color(ink: BurrowInk.amber))
                VStack(spacing: 10) {
                    ForEach(Species.allCases, id: \.self) { sp in row(sp) }
                }
                Text("FOOD AND DECOR SHIFT THE ODDS.\nEVERY MEAL IS +1 MOLT.")
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
    }

    private func row(_ sp: Species) -> some View {
        let p = odds[sp] ?? 0
        let filled = Int((p * 20).rounded())
        return HStack(spacing: 8) {
            PixelImage(buffer: SpeciesArt.adult(sp), cell: 1)
                .frame(width: 36, height: 28)
            Text(sp.label).font(GrubFont.size(7)).foregroundColor(Color(ink: BurrowInk.cream))
                .frame(width: 52, alignment: .leading)
            HStack(spacing: 1) {
                ForEach(0..<20, id: \.self) { i in
                    Rectangle().fill(Color(ink: i < filled ? sp.color : BurrowInk.soil1)).frame(width: 5, height: 9)
                }
            }
            Text("\(Int((p * 100).rounded()))%").font(GrubFont.size(7))
                .foregroundColor(Color(ink: BurrowInk.cream))
                .frame(width: 36, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(sp.label.capitalized) \(Int((p * 100).rounded())) percent")
    }
}

/// Shown after the cocoon: the adult, its name and blurb. Phase 4 adds PIN IT.
struct RevealCardView: View {
    let species: Species
    let close: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("IT MOLTED!").font(GrubFont.size(12)).foregroundColor(Color(ink: BurrowInk.cream))
                PixelImage(buffer: SpeciesArt.adult(species), cell: 6)
                    .padding(14)
                    .background(Color(ink: BurrowInk.soil2))
                    .overlay(Rectangle().strokeBorder(Color(ink: species.color), lineWidth: 3))
                Text(species.label).font(GrubFont.size(16)).foregroundColor(Color(ink: species.color))
                Text(species.blurb).font(GrubFont.size(8)).foregroundColor(Color(ink: BurrowInk.mutedText))
                Button(action: close) {
                    Text("NICE!").font(GrubFont.size(10)).foregroundColor(Color(ink: BurrowInk.hollow))
                        .padding(.horizontal, 22).padding(.vertical, 12)
                        .background(Color(ink: BurrowInk.amber))
                }
                .buttonStyle(PixelPressStyle())
            }
            .padding(24)
            .background(Color(ink: BurrowInk.hollow))
            .overlay(Rectangle().strokeBorder(Color(ink: BurrowInk.soil1), lineWidth: 4))
            .padding(20)
            .accessibilityElement(children: .combine)
        }
    }
}
```

The panel's row sprite is drawn at `cell: 1` inside a 36×28 frame — a thumbnail (`PixelImage` sizes itself to `width × cell`, so a 36-wide adult is 36 pt and smaller ones are centred). Pixel-exact, just small.

- [ ] **Step 5: Molt demo** — add to the DEBUG section, and call it from the DEBUG `.task` after `runDemoIfRequested()`:

```swift
    /// `-burrowMoltDemo` (use with `-burrowReset -burrowMoltReady`). Seconds after the view appears:
    /// 2.0 open the molt panel (until 5.0) · 5.0 close; grub glows · 7.0 tap → cocoon (until 10.0)
    /// 10.0 reveal card (until 13.0) · 13.0 dismiss; adult stands in the chamber.
    private func runMoltDemoIfRequested() async {
        guard BurrowDebug.moltDemo else { return }
        func wait(_ s: Double) async { try? await Task.sleep(nanoseconds: UInt64(s * 1_000_000_000)) }
        await wait(2.0); withAnimation { showMolt = true }
        await wait(3.0); withAnimation { showMolt = false }
        await wait(2.0); model.tapGrub()
        await wait(6.0); withAnimation { model.dismissReveal() }
    }
```

- [ ] **Step 6: BUILD**, then run all burrow test classes (Rules, Store, Layout, Pacing). Expected: build succeeds; 38 + 6 + 3 + 3 = 50 tests pass.

- [ ] **Step 7: Commit**

```bash
git add GrubIOS/Burrow/BurrowHomeView.swift
git commit -m "feat(burrow): molt panel, glow, cocoon and reveal card" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 5: Simulator verification

**Files:** none (may tweak art/layout)

`D=8AABF67E-2193-4949-8A0E-0954E9789898`, `B=com.jessedev.GrubIOS`, `OUT=<scratchpad>/p3`. Screenshots are taken at fixed times from launch (the demo's clock starts up to ~1 s later), each ≥ 1 s into its state.

- [ ] **Step 1: Molt demo**

```bash
mkdir -p $OUT; xcrun simctl install $D build/dd/Build/Products/Debug-iphonesimulator/GrubIOS.app
xcrun simctl terminate $D $B 2>/dev/null
python3 - "$D" "$B" "$OUT" <<'EOF'
import subprocess, sys, time
d, b, out = sys.argv[1:]
subprocess.run(["xcrun","simctl","launch",d,b,"-burrowReset","-burrowMoltReady","-burrowMoltDemo"], capture_output=True)
t0 = time.time()
for at, name in [(4.0,"p3_panel"),(6.3,"p3_glow_a"),(6.5,"p3_glow_b"),(6.7,"p3_glow_c"),(9.0,"p3_cocoon"),(12.0,"p3_reveal"),(15.0,"p3_adult")]:
    time.sleep(max(0, t0 + at - time.time()))
    subprocess.run(["xcrun","simctl","io",d,"screenshot",f"{out}/{name}.png"], capture_output=True)
EOF
```

Expected:
- `p3_panel`: MOLT 10/10; GRUB 33 %, CLAWS 33 %, HORN/FUZZ/SHELL/STALK 8 % each (weights 4/4/1/1/1/1 of 12); the MOLT stat shows READY.
- `p3_glow_*`: at least one of the three shows the amber outline around the grub (it blinks every 0.4 s).
- `p3_cocoon`: the cream cocoon in the chamber; HUD shows "MOLTED INTO …!".
- `p3_reveal`: reveal card with the rolled adult, its name in its colour and its blurb.
- `p3_adult`: card gone; the adult stands on the chamber floor; FEED dimmed.

Verify the rolled species matches across the reveal card, the HUD banner and the chamber, and read the save's `adult` field to confirm it persisted:

```bash
python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(d['stage'],d['adult'])" "$(xcrun simctl get_app_container $D $B data)/Library/Application Support/burrow.json"
```

- [ ] **Step 2: Every adult in the chamber**

```bash
for sp in grub horn fuzz shell claws stalk; do
  xcrun simctl terminate $D $B 2>/dev/null
  xcrun simctl launch $D $B -burrowReset -burrowAdult $sp >/dev/null; sleep 3
  xcrun simctl io $D screenshot $OUT/p3_adult_$sp.png >/dev/null 2>&1
done
```

Expected: each adult stands on the chamber floor, inside the chamber, eyes and features matching the contact sheet; nothing clipped. (CLAWS spans the full chamber width — expected.)

- [ ] **Step 3: Relaunch keeps the adult** — `xcrun simctl terminate $D $B; xcrun simctl launch $D $B >/dev/null; sleep 3; xcrun simctl io $D screenshot $OUT/p3_relaunch.png`. Expected: the last adult (STALK) is still there, no cocoon replay.

- [ ] **Step 4: Fix and recheck** anything off. **Step 5: Report** a sheet (panel, glow, cocoon, reveal, adult, the six adults) to Jesse; note that CLAWS overlaps corner decor and that the game stops at the adult until phase 4. **Step 6: Commit** any fixes (skip if none).

---

## Done when

- 50 burrow tests pass (rules 38, store 6, layout 3, pacing 3).
- The molt demo and the six-adult sweep match the expected screenshots, and the save persists `stage: adult` with the rolled species.
