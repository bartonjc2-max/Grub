# Burrow Phase 4 (Collect + Hatch) Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the loop. Pin the revealed adult into a specimen box, which starts a new egg that inherits the adult's colour (tint) and a +2 odds lean (lineage). Name the egg, tap it three times to hatch, and a fresh game now starts at the egg.

**Architecture:** Same layers as phases 1–3. Pure rules gain `pin`, `name`, `crackEgg`, `validName`. `fresh` now starts at `.egg`. Larva frames are generated per tint. New views: `SpecimenBoxView`, `NamePromptView`, the egg in the chamber, and PIN IT on the reveal card. Spec: `docs/superpowers/specs/2026-11-10-burrow-mechanics-design.md` §5 "Collect and hatch", "HUD by stage", "Art needed".

**Tech Stack:** Swift 5.9, SwiftUI, iOS 17, XCTest, XcodeGen.

---

## Ground rules

- Phases 1–3 are committed on `the-deep` (HEAD `6c8c267`); 53 burrow tests pass.
- Commit after each task, staging only that task's files; `git add -f GrubIOS.xcodeproj/project.pbxproj` only when a task adds files. Never stage `GrubIOS/GrubIOSApp.swift` or `grub_canon.png`. Messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **`fresh` switches to `.egg` with an empty name.** Existing installs keep their stage (their saves say `.larva`/`.adult`); only new games start at the egg. Tests that assumed a fresh larva get a one-line setup change (Task 1).
- **Adults keep their plain species colours** (spec): tint only colours the larva and the egg's spots.
- **The pinned name falls back to "GRUB"** if the adult has no name. Saves from phases 1–3 were all named "GRUB", but a DEBUG `-burrowAdult` launch on a fresh egg save has an empty name.
- Do **not** extract code from this plan with a script. Phase 3's scripted extraction duplicated blocks; copy each block by hand into the place its step names.
- Commands from `/Users/jessedev/Documents/Code/grub/GrubIOS`:

```bash
# TEST: replace <Class> (repeat -only-testing for several)
xcodebuild test -project GrubIOS.xcodeproj -scheme GrubIOS -destination 'id=8AABF67E-2193-4949-8A0E-0954E9789898' -derivedDataPath build/dd -only-testing:GrubIOSTests/<Class> 2>&1 | grep -E "error:|Test Case.*failed|XCTAssert|Executed .* tests|TEST (SUCCEEDED|FAILED)" | tail -12
```

```bash
# BUILD
xcodebuild -project GrubIOS.xcodeproj -scheme GrubIOS -configuration Debug -destination 'id=8AABF67E-2193-4949-8A0E-0954E9789898' -derivedDataPath build/dd build 2>&1 | grep -E "error:|BUILD" | head -20
```

## File map

| File | Status | Change |
|---|---|---|
| `GrubIOS/Burrow/BurrowRules.swift` | modify | `validName`, `name`, `crackEgg`, `pin`, egg names |
| `GrubIOS/Burrow/BurrowSave.swift` | modify | `fresh` → `.egg`, empty name |
| `GrubIOS/Burrow/BurrowArt.swift` | modify | tinted larva frames (`GrubArt.frames(tint:)`), colour helpers, box icon |
| `GrubIOS/Burrow/SpeciesArt.swift` | modify | egg sprite + 3 crack stages |
| `GrubIOS/Burrow/BurrowHomeModel.swift` | modify | egg/pin/box state, actions, events, DEBUG args |
| `GrubIOS/Burrow/BurrowHomeView.swift` | modify | egg in chamber, tinted larva, HUD by stage, PIN IT, box button + box, name prompt, demo |
| `GrubIOSTests/BurrowRulesTests.swift` | modify | helper → larva; pin/name/crack/full-loop tests |
| `GrubIOSTests/BurrowStoreTests.swift` | modify | fresh → egg |
| `GrubIOSTests/BurrowPacingTests.swift` | modify | hatch before simulating |
| `GrubIOSTests/BurrowHomeModelTests.swift` | modify | helper → larva; egg naming/hatching tests |
| `GrubIOSTests/BurrowArtTests.swift` | create | tint colour maths |

---

## Chunk 1: Rules

### Task 1: Fresh games start as an egg

**Files:** `BurrowSave.swift`, `BurrowStoreTests.swift`, `BurrowRulesTests.swift`, `BurrowPacingTests.swift`, `BurrowHomeModelTests.swift`

- [ ] **Step 1: Update tests first.**
  - `BurrowStoreTests.test_fresh_save_matches_spec`: change `XCTAssertEqual(s.stage, .larva)` → `.egg` and `XCTAssertEqual(s.name, "GRUB")` → `""`; add `XCTAssertEqual(s.eggCracks, 0)`.
  - `BurrowRulesTests.save(_:)` helper — tests are written against a larva, so make that explicit:

```swift
    /// A fresh *hatched* larva named GRUB at t0, customised by `edit`.
    func save(_ edit: (inout BurrowSave) -> Void = { _ in }) -> BurrowSave {
        var s = BurrowSave.fresh(now: t0)
        s.stage = .larva
        s.name = "GRUB"
        edit(&s)
        return s
    }
```

  - `BurrowHomeModelTests.moltReadyModel()`: after `var s = BurrowSave.fresh(now: t0)` add `s.stage = .larva; s.name = "GRUB"`.
  - `BurrowPacingTests.daysToMolt`: after `var s = BurrowSave.fresh(now: t0)` hatch it the way a player would:

```swift
        s = BurrowRules.name(s, "PIP", now: t0).save
        for _ in 0..<BurrowRules.crackTaps { s = BurrowRules.crackEgg(s, now: t0).save }
        precondition(s.stage == .larva)
```

- [ ] **Step 2: Run to verify it fails** — TEST `BurrowStoreTests`. Expected: compile error `type 'BurrowRules' has no member 'name'` (from the pacing test). That's fine; Task 2 adds it. **Don't commit yet** — Tasks 1 and 2 land together.

- [ ] **Step 3: Switch `fresh`** — in `BurrowSave.fresh`: `stage: .larva, name: "GRUB"` → `stage: .egg, name: ""`, and the doc comment becomes `/// A brand-new game: an unnamed egg (spec §5 "First launch").`

### Task 2: name, crackEgg, pin

**Files:** `BurrowRules.swift`; Test `BurrowRulesTests.swift`

- [ ] **Step 1: Write the failing tests** (append to `BurrowRulesTests`)

```swift
    // MARK: collect + hatch (phase 4)

    func egg(_ edit: (inout BurrowSave) -> Void = { _ in }) -> BurrowSave {
        var s = BurrowSave.fresh(now: t0)
        edit(&s)
        return s
    }

    func test_valid_names() {
        XCTAssertEqual(BurrowRules.validName("pip"), "PIP")
        XCTAssertEqual(BurrowRules.validName("  MR BEAN "), "MR BEAN")
        XCTAssertEqual(BurrowRules.validName("ABCDEFGHIJ"), "ABCDEFGHIJ")
        for bad in ["", "   ", "ABCDEFGHIJK", "R2D2", "ÉCLAIR", "HI!"] {
            XCTAssertNil(BurrowRules.validName(bad), bad)
        }
        XCTAssertTrue(BurrowRules.eggNames.allSatisfy { BurrowRules.validName($0) == $0 })
    }

    func test_name_the_egg() {
        let r = BurrowRules.name(egg(), "bean", now: t0)
        XCTAssertEqual(r.events, [.named("BEAN")])
        XCTAssertEqual(r.save.name, "BEAN")
        XCTAssertEqual(BurrowRules.name(egg(), "R2", now: t0).events, [.refused(.badName)])
        XCTAssertEqual(BurrowRules.name(save(), "BEAN", now: t0).events, [.refused(.wrongStage)])
    }

    func test_three_cracks_hatch_a_named_egg() {
        XCTAssertEqual(BurrowRules.crackEgg(egg(), now: t0).events, [.refused(.badName)], "name it first")
        var s = egg { $0.name = "PIP" }
        var r = BurrowRules.crackEgg(s, now: t0)
        XCTAssertEqual(r.events, [.eggCracked(stage: 1)]); s = r.save
        r = BurrowRules.crackEgg(s, now: t0)
        XCTAssertEqual(r.events, [.eggCracked(stage: 2)]); s = r.save
        r = BurrowRules.crackEgg(s, now: t0)
        XCTAssertEqual(r.events, [.eggCracked(stage: 3), .hatched])
        XCTAssertEqual(r.save.stage, .larva)
        XCTAssertEqual(r.save.eggCracks, 0)
        XCTAssertEqual(BurrowRules.crackEgg(r.save, now: t0).events, [.refused(.wrongStage)])
    }

    func test_pin_files_the_adult_and_starts_an_inheriting_egg() {
        let adult = save {
            $0.stage = .adult; $0.adult = .horn; $0.name = "PIP"
            $0.belly = 2; $0.joy = 9; $0.molt = 10; $0.eaten = [.root: 4]; $0.lastMeal = .root
            $0.bag = [.amber: 2]; $0.placed = [1: .shell]; $0.digs = 1; $0.holes = [3]
            $0.bellyTimer = 99; $0.joyTimer = 99
        }
        let r = BurrowRules.pin(adult, now: t0)
        XCTAssertEqual(r.events, [.pinned(Specimen(name: "PIP", species: .horn, pinnedAt: t0))])
        let s = r.save
        XCTAssertEqual(s.specimens, [Specimen(name: "PIP", species: .horn, pinnedAt: t0)])
        XCTAssertEqual(s.stage, .egg)
        XCTAssertEqual(s.lineage, .horn)
        XCTAssertEqual(s.tint, .horn)
        XCTAssertNil(s.adult)
        XCTAssertEqual(s.name, "")
        XCTAssertEqual([s.belly, s.joy, s.molt, s.eggCracks], [6, 6, 0, 0])
        XCTAssertTrue(s.eaten.isEmpty)
        XCTAssertNil(s.lastMeal)
        XCTAssertEqual([s.bellyTimer, s.joyTimer], [0, 0])
        // The burrow is the player's: bag, decor, digs and holes carry over.
        XCTAssertEqual(s.bag, [.amber: 2]); XCTAssertEqual(s.placed, [1: .shell])
        XCTAssertEqual(s.digs, 1); XCTAssertEqual(s.holes, [3])
        XCTAssertEqual(BurrowRules.pin(save(), now: t0).events, [.refused(.wrongStage)])
    }

    func test_pinned_name_falls_back_to_grub() {
        let r = BurrowRules.pin(save { $0.stage = .adult; $0.adult = .fuzz; $0.name = "" }, now: t0)
        XCTAssertEqual(r.save.specimens.first?.name, "GRUB")
    }

    func test_lineage_carries_into_the_next_molt_odds() {
        let next = BurrowRules.pin(save { $0.stage = .adult; $0.adult = .stalk }, now: t0).save
        XCTAssertEqual(BurrowRules.odds(next)[.stalk]!, 3.0 / 9, accuracy: 1e-9)
    }

    /// The whole loop on the rules: hatch → feed to molt → molt → pin → next egg.
    func test_full_loop() {
        var s = egg()
        s = BurrowRules.name(s, "PIP", now: t0).save
        for _ in 0..<3 { s = BurrowRules.crackEgg(s, now: t0).save }
        XCTAssertEqual(s.stage, .larva)
        s.bag = [.berry: 20]
        var clock = t0
        while !BurrowRules.isMoltReady(s) {
            clock = clock.addingTimeInterval(6 * 3600)            // let belly drop
            s = BurrowRules.advance(s, to: clock, rng: &rng).save
            s = BurrowRules.feed(s, kind: nil, now: clock).save
        }
        let molted = BurrowRules.startMolt(s, now: clock, rng: &rng)
        guard case .molted(let sp) = molted.events.first else { return XCTFail() }
        let pinned = BurrowRules.pin(molted.save, now: clock).save
        XCTAssertEqual(pinned.stage, .egg)
        XCTAssertEqual(pinned.specimens.map(\.species), [sp])
        XCTAssertEqual(pinned.specimens.map(\.name), ["PIP"])
        XCTAssertEqual(pinned.lineage, sp)
    }
```

- [ ] **Step 2: Run to verify it fails** — TEST `BurrowRulesTests`. Expected: `no member 'validName'`.

- [ ] **Step 3: Implement** — add to `BurrowRules` before `// MARK: Furnishing`:

```swift
    // MARK: Collect + hatch

    static let maxNameLength = 10
    static let crackTaps = 3
    /// Prefills for the name prompt (all valid names, ≤ 10 letters).
    static let eggNames = ["BEAN", "PIP", "MOSS", "TOFU", "BUTTON", "NUB", "PEBBLE", "SPROUT", "MOCHI", "DOT",
                           "WIGGLE", "CRUMB", "NOODLE", "PUDDLE", "TATER", "BISCUIT", "GUMDROP", "PICKLE",
                           "DUMPLING", "SOOT"]

    /// Upper-cased, trimmed name if it is 1–10 characters of A–Z and inner spaces; otherwise nil.
    static func validName(_ raw: String) -> String? {
        let n = raw.uppercased().trimmingCharacters(in: .whitespaces)
        guard (1...maxNameLength).contains(n.count),
              n.allSatisfy({ ("A"..."Z").contains($0) || $0 == " " }) else { return nil }
        return n
    }

    static func name(_ s0: BurrowSave, _ raw: String, now: Date) -> BurrowResult {
        guard s0.stage == .egg else { return refuse(s0, .wrongStage) }
        guard let n = validName(raw) else { return refuse(s0, .badName) }
        var s = s0
        s.name = n
        return BurrowResult(save: s, events: [.named(n)])
    }

    /// One tap on a named egg; the third hatches it.
    static func crackEgg(_ s0: BurrowSave, now: Date) -> BurrowResult {
        guard s0.stage == .egg else { return refuse(s0, .wrongStage) }
        guard !s0.name.isEmpty else { return refuse(s0, .badName) }
        var s = s0
        s.eggCracks += 1
        var events: [BurrowEvent] = [.eggCracked(stage: s.eggCracks)]
        if s.eggCracks >= crackTaps {
            s.stage = .larva
            s.eggCracks = 0
            events.append(.hatched)
        }
        return BurrowResult(save: s, events: events)
    }

    /// File the revealed adult in the specimen box and start the next egg, which inherits
    /// its colour (tint) and a +2 odds lean (lineage). The burrow (bag, decor, digs, holes,
    /// buried finds) carries over.
    static func pin(_ s0: BurrowSave, now: Date) -> BurrowResult {
        guard s0.stage == .adult, let sp = s0.adult else { return refuse(s0, .wrongStage) }
        let specimen = Specimen(name: s0.name.isEmpty ? "GRUB" : s0.name, species: sp, pinnedAt: now)
        var s = s0
        s.specimens.append(specimen)
        s.stage = .egg
        s.lineage = sp
        s.tint = sp
        s.adult = nil
        s.name = ""
        s.eggCracks = 0
        s.belly = 6; s.joy = 6; s.molt = 0
        s.eaten = [:]
        s.lastMeal = nil
        s.bellyTimer = 0; s.joyTimer = 0
        return BurrowResult(save: s, events: [.pinned(specimen)])
    }
```

- [ ] **Step 4: Run** — TEST `BurrowRulesTests` + `BurrowStoreTests` + `BurrowPacingTests` + `BurrowHomeModelTests`. Expected: rules 45 (38 + 7), store 6, pacing 3 (days to molt unchanged — hatching is instant at t0), model 3. Then BUILD (the app must still compile; `fresh` now yields an egg that the phase-3 view simply draws as a larva until Task 5).

- [ ] **Step 5: Commit Tasks 1+2**

```bash
git add GrubIOS/Burrow/BurrowSave.swift GrubIOS/Burrow/BurrowRules.swift GrubIOSTests/BurrowRulesTests.swift GrubIOSTests/BurrowStoreTests.swift GrubIOSTests/BurrowPacingTests.swift GrubIOSTests/BurrowHomeModelTests.swift
git commit -m "feat(burrow): name, hatch and pin rules; new games start as an egg" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 3: Art — tinted larva, egg, box icon

**Files:** `BurrowArt.swift`, `SpeciesArt.swift`; Test create `GrubIOSTests/BurrowArtTests.swift`

- [ ] **Step 1: Failing tests** (`BurrowArtTests.swift`)

```swift
import XCTest
@testable import GrubIOS

final class BurrowArtTests: XCTestCase {
    func test_mix_and_scale() {
        XCTAssertEqual(GrubArt.mix(0x000000, 0xffffff, 0.25), 0x404040)
        XCTAssertEqual(GrubArt.scale(0x646464, 0.5), 0x323232)
    }

    func test_tint_is_a_quarter_of_the_parent_colour() {
        XCTAssertEqual(GrubArt.bodyColor(tint: nil), BurrowInk.teal)
        XCTAssertEqual(GrubArt.bodyColor(tint: .grub), BurrowInk.teal)
        // teal 4e cc a3 → horn 8f 6f e0 at 25 %: 5e b5 b2
        XCTAssertEqual(GrubArt.bodyColor(tint: .horn), 0x5eb5b2)
    }

    func test_tinted_frames_keep_the_larva_shape() {
        let plain = GrubArt.frames(tint: nil), horn = GrubArt.frames(tint: .horn)
        XCTAssertEqual(horn.idle.width, plain.idle.width)
        XCTAssertEqual(horn.idle.height, plain.idle.height)
        XCTAssertNotEqual(horn.idle.data, plain.idle.data)
        XCTAssertEqual(plain.idle.data, GrubArt.idle.data, "untinted frames are the original art")
    }

    func test_egg_cracks_add_pixels() {
        let e0 = SpeciesArt.egg(cracks: 0, tint: nil), e3 = SpeciesArt.egg(cracks: 3, tint: nil)
        XCTAssertEqual(e0.width, 15); XCTAssertEqual(e0.height, 18)
        XCTAssertNotEqual(e0.data, e3.data)
    }
}
```

- [ ] **Step 2: Run** — `xcodegen generate && ` + TEST `BurrowArtTests`. Expected: `type 'GrubArt' has no member 'mix'`.

- [ ] **Step 3: Implement**

  a. `BurrowArt.swift`, after `enum GrubArt { … }` (after `static let chomp = …` and its closing brace):

```swift
extension GrubArt {
    struct Frames { let idle, blink, chomp, sulk: PixelBuffer }

    /// Per-channel blend of two 0xRRGGBB colours (`f` = share of `b`), rounded.
    static func mix(_ a: UInt32, _ b: UInt32, _ f: Double) -> UInt32 {
        func ch(_ c: UInt32, _ s: UInt32) -> Double { Double((c >> s) & 0xFF) }
        func out(_ s: UInt32) -> UInt32 { UInt32((ch(a, s) + (ch(b, s) - ch(a, s)) * f).rounded()) << s }
        return out(16) | out(8) | out(0)
    }

    /// Per-channel multiply, rounded.
    static func scale(_ c: UInt32, _ k: Double) -> UInt32 { mix(0x000000, c, k) }

    /// Spec §5: larva body = teal mixed 25 % toward the parent species' colour.
    static func bodyColor(tint: Species?) -> UInt32 {
        guard let t = tint, t != .grub else { return BurrowInk.teal }
        return mix(BurrowInk.teal, t.color, 0.25)
    }

    /// Larva frames for a tint. Untinted (or GRUB) is the original art; otherwise the body
    /// is `bodyColor` and the side shade is the body × 0.82.
    static func frames(tint: Species?) -> Frames { frameCache[tint?.rawValue ?? ""]! }

    private static let frameCache: [String: Frames] = {
        var out: [String: Frames] = ["": Frames(idle: idle, blink: blink, chomp: chomp, sulk: sulk)]
        for sp in Species.allCases {
            if sp == .grub { out[sp.rawValue] = out[""]; continue }
            let body = bodyColor(tint: sp), shade = scale(body, 0.82)
            out[sp.rawValue] = Frames(idle: frame(body: body, shade: shade),
                                      blink: frame(blink: true, body: body, shade: shade),
                                      chomp: frame(chomp: true, body: body, shade: shade),
                                      sulk: frame(sulk: true, body: body, shade: shade))
        }
        return out
    }()
}
```

  Check `scale`: `mix(0, c, k)` = `0 + (c − 0)·k` per channel ✓.

  b. `IconArt` (in `BurrowArt.swift`), add the specimen-box icon:

```swift
    static let box = PixelBuffer(art: ["CCCCCCC",
                                       "C.....C",
                                       "C.TTT.C",
                                       "C..T..C",
                                       "C.....C",
                                       "CCCCCCC"],
                                 palette: ["C": BurrowInk.copper, "T": BurrowInk.teal])
```

  c. `SpeciesArt.swift`, add:

```swift
    /// The egg (15×18): cream shell with spots in the parent's colour (teal for a first egg),
    /// plus 0–3 cracks drawn in hollow.
    static func egg(cracks: Int, tint: Species?) -> PixelBuffer {
        var b = PixelBuffer(art: [
            ".....CCCCC.....",
            "...CCCCCCCCC...",
            "..CCCCCCCCCCC..",
            ".CCCSSCCCCCCCC.",
            ".CCSSSCCCCCSCC.",
            "CCCCSCCCCCSSSCC",
            "CCCCCCCCCCCSCCC",
            "CCCCCCCCCCCCCCC",
            "CCSCCCCCCCCCCCC",
            "CSSSCCCCCSSCCCC",
            "CCSCCCCCSSSSCCC",
            "CCCCCCCCCSSCCCC",
            "CCCCCCCCCCCCCCC",
            ".CCCCCCCCCCCCD.",
            ".CCCCCCCCCCCDD.",
            "..CCCCCCCCCDD..",
            "...DDCCCCDDD...",
            ".....DDDDD....."],
            palette: ["C": BurrowInk.cream, "D": BurrowInk.creamDim, "S": tint?.color ?? BurrowInk.teal])
        let stages: [[(Int, Int)]] = [
            [(7, 1), (8, 2), (7, 3)],
            [(6, 4), (7, 5), (8, 6), (9, 5)],
            [(5, 6), (4, 7), (10, 6), (11, 7), (8, 7), (9, 8)],
        ]
        for stage in stages.prefix(max(0, min(3, cracks))) {
            for (x, y) in stage { b.fill(x, y, 1, 1, BurrowInk.hollow) }
        }
        return b
    }
```

- [ ] **Step 4: Run** — TEST `BurrowArtTests`. Expected: 4 passed. (If `0x5eb5b2` is off by one in a channel, recompute by hand: 4e+(8f−4e)·0.25 = 78+16.25 = 94.25 → 94 = 0x5e; cc+(6f−cc)·0.25 = 204−23.25 = 180.75 → 181 = 0xb5; a3+(e0−a3)·0.25 = 163+15.25 = 178.25 → 178 = 0xb2.)

- [ ] **Step 5: Commit**

```bash
git add GrubIOS/Burrow/BurrowArt.swift GrubIOS/Burrow/SpeciesArt.swift GrubIOSTests/BurrowArtTests.swift
git add -f GrubIOS.xcodeproj/project.pbxproj
git commit -m "feat(burrow): tinted larva frames, egg with cracks, box icon" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Chunk 2: Model, view, verification

### Task 4: Model

**Files:** `BurrowHomeModel.swift`; Test `BurrowHomeModelTests.swift`

- [ ] **Step 1: Failing tests** (append to `BurrowHomeModelTests`)

```swift
    func eggModel() throws -> BurrowHomeModel {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("burrow-egg-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let store = BurrowStore(directory: dir)
        try store.save(BurrowSave.fresh(now: t0))
        let t0 = self.t0
        return BurrowHomeModel(store: store, clock: { t0 })
    }

    func test_first_tap_on_an_unnamed_egg_asks_for_a_name() throws {
        let m = try eggModel()
        XCTAssertEqual(m.stage, .egg)
        m.tapGrub()
        XCTAssertTrue(m.namingEgg)
        XCTAssertEqual(m.eggCracks, 0)
    }

    func test_bad_name_keeps_the_prompt_good_name_closes_it() throws {
        let m = try eggModel()
        m.tapGrub()
        XCTAssertFalse(m.nameEgg("R2D2"))
        XCTAssertTrue(m.namingEgg)
        XCTAssertTrue(m.nameEgg("pip"))
        XCTAssertFalse(m.namingEgg)
        XCTAssertEqual(m.name, "PIP")
    }

    func test_three_taps_hatch_the_named_egg() throws {
        let m = try eggModel()
        m.tapGrub(); _ = m.nameEgg("PIP")
        m.tapGrub(); m.tapGrub()
        XCTAssertEqual(m.eggCracks, 2)
        m.tapGrub()
        XCTAssertEqual(m.stage, .larva)
        XCTAssertFalse(m.showBox)
    }
```

- [ ] **Step 2: Run** — TEST `BurrowHomeModelTests`. Expected: `no member 'namingEgg'`.

- [ ] **Step 3: State + read-outs** — after `@Published private(set) var confirmingMolt = false`:

```swift
    /// The name prompt for a fresh egg is showing.
    @Published private(set) var namingEgg = false
    /// The specimen box is open.
    @Published var showBox = false
    /// Animation-clock time of the last egg crack (the egg shakes for 0.3 s).
    @Published private(set) var crackAt: TimeInterval = -10
```

and after `static let cocoonSeconds …`:

```swift
    var name: String { save.name }
    var eggCracks: Int { save.eggCracks }
    var tint: Species? { save.tint }
    var specimens: [Specimen] { save.specimens }
    func randomEggName() -> String { BurrowRules.eggNames.randomElement() ?? "PIP" }
```

- [ ] **Step 4: Actions** — replace the `case .egg: break   // phase 4` arm of `tapGrub()` with:

```swift
        case .egg:
            if save.name.isEmpty { namingEgg = true } else { apply(BurrowRules.crackEgg(save, now: clock())) }
```

and add after `func dismissReveal() …`:

```swift
    /// OK on the name prompt. Returns false (and keeps the prompt) for an invalid name.
    @discardableResult
    func nameEgg(_ raw: String) -> Bool {
        let r = BurrowRules.name(save, raw, now: clock())
        if r.events.first == .refused(.badName) { say(Self.message(.badName)); return false }
        namingEgg = false
        apply(r)
        return true
    }

    func cancelNaming() { namingEgg = false }

    /// PIN IT on the reveal card.
    func pin() {
        revealing = nil
        apply(BurrowRules.pin(save, now: clock()))
    }
```

- [ ] **Step 5: Events** — in `handle(_:)`, before `case .moltReady:`:

```swift
        case .named(let n):
            say("HELLO, \(n)!")
            Haptics.soft()
        case .eggCracked:
            crackAt = t
            Haptics.thud()
        case .hatched:
            hopAt = t
            say("\(save.name) HATCHED!")
            Haptics.thud()
        case .pinned:
            showBox = true
            Haptics.thud()
```

and change the `.badName` message to `case .badName: return "USE 1-10 LETTERS"`.

- [ ] **Step 6: DEBUG** — in `init`'s DEBUG block, replace the `-burrowAdult` line with:

```swift
        if let sp = BurrowDebug.adult {
            loaded.stage = .adult; loaded.adult = sp
            if loaded.name.isEmpty { loaded.name = "GRUB" }
        }
```

and add to `enum BurrowDebug`:

```swift
    /// `-burrowLoopDemo` (use with `-burrowReset -burrowAdult horn`): pin → box → name → hatch.
    static var loopDemo: Bool { args.contains("-burrowLoopDemo") }
```

- [ ] **Step 7: Run** — TEST `BurrowHomeModelTests`. Expected: 6 passed. BUILD. **Commit**

```bash
git add GrubIOS/Burrow/BurrowHomeModel.swift GrubIOSTests/BurrowHomeModelTests.swift
git commit -m "feat(burrow): model naming, hatching and pinning" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 5: View

**Files:** `BurrowHomeView.swift`

- [ ] **Step 1: Egg and tinted larva in the chamber.** In `grub(_:_:)`:
  - Add `let F = GrubArt.frames(tint: model.tint)` at the top, and replace `GrubArt.chomp`, `GrubArt.idle` (both uses), `GrubArt.blink`, `GrubArt.sulk` in the larva branch with `F.chomp`, `F.idle`, `F.blink`, `F.sulk`.
  - Add an egg branch between the cocoon and adult branches:

```swift
        } else if model.stage == .egg {
            sprite = SpeciesArt.egg(cracks: model.eggCracks, tint: model.tint)
```

  - The egg shakes after a crack: change the `wobble` line to

```swift
        let shaking = model.stage == .egg && t - model.crackAt < 0.3
        let wobble = inCocoon ? Int((sin(t * 9) * 1.4).rounded()) : (shaking ? (Int(t / 0.05) % 2 == 0 ? 1 : -1) : 0)
```

  and make the egg sit still otherwise: in `gy`, use `(inCocoon || model.stage == .egg) ? 0 : bounce + hop`.
  - In `grubLabel`, add `if model.stage == .egg { return model.name.isEmpty ? "Egg" : "Egg named \(model.name)" }` as the first line, and in the hint use `model.stage == .egg ? (model.name.isEmpty ? "Name your egg" : "Tap to hatch")` before the existing choices.

- [ ] **Step 2: HUD by stage.** Replace the adult banner branch `if model.stage == .adult, let sp = model.adult { VStack … }` with:

```swift
                if model.stage == .adult, let sp = model.adult {
                    stageBanner("MOLTED INTO \(sp.label)!", "TAP IT TO PIN IT", ink: sp.color)
                } else if model.stage == .egg {
                    stageBanner("A NEW EGG!",
                                model.name.isEmpty ? "TAP IT TO NAME IT" : "TAP TO HATCH \(model.eggCracks)/\(BurrowRules.crackTaps)",
                                ink: GrubArt.bodyColor(tint: model.tint))
                } else {
```

(the `else` keeps the existing stat bars), and add the helper next to `hudBar`:

```swift
    private func stageBanner(_ title: String, _ sub: String, ink: UInt32) -> some View {
        VStack(spacing: 6) {
            Text(title).font(GrubFont.size(9)).foregroundColor(Color(ink: ink))
            Text(sub).font(GrubFont.size(7)).foregroundColor(Color(ink: BurrowInk.mutedText))
        }
        .frame(maxWidth: .infinity, minHeight: 34)
    }
```

- [ ] **Step 3: PIN IT on the reveal card.** Change `RevealCardView` to take `let pin: () -> Void` and `let later: () -> Void` instead of `close`, and replace its NICE! button with:

```swift
                HStack(spacing: 12) {
                    Button(action: later) {
                        Text("LATER").font(GrubFont.size(9)).foregroundColor(Color(ink: BurrowInk.hollow))
                            .padding(.horizontal, 14).padding(.vertical, 11)
                            .background(Color(ink: BurrowInk.creamDim))
                    }
                    .buttonStyle(PixelPressStyle())
                    Button(action: pin) {
                        Text("PIN IT").font(GrubFont.size(9)).foregroundColor(Color(ink: BurrowInk.hollow))
                            .padding(.horizontal, 18).padding(.vertical, 11)
                            .background(Color(ink: BurrowInk.amber))
                    }
                    .buttonStyle(PixelPressStyle())
                }
```

Update its doc comment to "Shown after the cocoon: the adult, its name and blurb; PIN IT files it in the box." and the call site:

```swift
                RevealCardView(species: sp,
                               pin: { withAnimation(.easeOut(duration: 0.15)) { model.pin() } },
                               later: { withAnimation(.easeOut(duration: 0.15)) { model.dismissReveal() } })
```

- [ ] **Step 4: Specimen box.** Add the button and overlay in `body`:

```swift
        .overlay(alignment: .topLeading) {
            Button { model.showBox = true } label: {
                PixelImage(buffer: IconArt.box, cell: 4)
                    .padding(8)
                    .background(Color(ink: BurrowInk.hollow))
                    .overlay(Rectangle().strokeBorder(Color(ink: BurrowInk.soil1), lineWidth: 3))
                    .overlay(alignment: .topTrailing) {
                        if !model.specimens.isEmpty {
                            Text("\(model.specimens.count)").font(GrubFont.size(7))
                                .foregroundColor(Color(ink: BurrowInk.hollow))
                                .padding(3).background(Color(ink: BurrowInk.amber))
                                .offset(x: 5, y: -5)
                        }
                    }
            }
            .buttonStyle(PixelPressStyle())
            .padding(.leading, 14).padding(.top, 54)
            .accessibilityLabel("Specimen box, \(model.specimens.count)")
        }
```

(place it before the existing `.overlay(alignment: .top) { modeBar }` so the mode bar draws over it), and after the reveal overlay:

```swift
        .overlay {
            if model.showBox {
                SpecimenBoxView(specimens: model.specimens) { withAnimation(.easeOut(duration: 0.15)) { model.showBox = false } }
                    .transition(.opacity)
            }
        }
```

and add before `#Preview`:

```swift
/// Every pinned adult (spec §5). Adults use their plain species colours.
struct SpecimenBoxView: View {
    let specimens: [Specimen]
    let close: () -> Void
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)
    private static let date: DateFormatter = { let f = DateFormatter(); f.dateFormat = "MMM d"; return f }()

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea().onTapGesture(perform: close)
            VStack(spacing: 14) {
                Text("SPECIMENS").font(GrubFont.size(14)).foregroundColor(Color(ink: BurrowInk.cream))
                if specimens.isEmpty {
                    Text("NO SPECIMENS YET.\nMOLT A GRUB AND PIN IT.")
                        .font(GrubFont.size(8)).lineSpacing(6).multilineTextAlignment(.center)
                        .foregroundColor(Color(ink: BurrowInk.mutedText))
                        .padding(.vertical, 30)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(Array(specimens.enumerated()), id: \.offset) { _, s in cell(s) }
                        }
                    }
                    .frame(maxHeight: 420)
                }
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

    private func cell(_ s: Specimen) -> some View {
        VStack(spacing: 6) {
            PixelImage(buffer: SpeciesArt.adult(s.species), cell: 3)
                .frame(width: 120, height: 92)
                .background(Color(ink: BurrowInk.soil2))
                .overlay(Rectangle().strokeBorder(Color(ink: s.species.color), lineWidth: 3))
            Text(s.name).font(GrubFont.size(8)).foregroundColor(Color(ink: BurrowInk.cream))
            Text(s.species.label).font(GrubFont.size(7)).foregroundColor(Color(ink: s.species.color))
            Text(Self.date.string(from: s.pinnedAt).uppercased()).font(GrubFont.size(6))
                .foregroundColor(Color(ink: BurrowInk.mutedText))
        }
        .accessibilityElement(children: .combine)
    }
}
```

  (`cell: 3` × the widest adult, CLAWS at 36 cells = 108 pt, fits the 120 pt frame.)

- [ ] **Step 5: Name prompt.** Overlay after the confirm overlay:

```swift
        .overlay {
            if model.namingEgg {
                NamePromptView(initial: model.randomEggName(),
                               random: { model.randomEggName() },
                               submit: { model.nameEgg($0) },
                               cancel: { model.cancelNaming() })
                    .transition(.opacity)
            }
        }
```

and the view (before `#Preview`):

```swift
/// Name a new egg: A–Z and spaces, 1–10 letters (spec §5).
struct NamePromptView: View {
    let random: () -> String
    let submit: (String) -> Bool
    let cancel: () -> Void
    @State private var text: String
    @FocusState private var focused: Bool

    init(initial: String, random: @escaping () -> String,
         submit: @escaping (String) -> Bool, cancel: @escaping () -> Void) {
        self.random = random; self.submit = submit; self.cancel = cancel
        _text = State(initialValue: initial)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea().onTapGesture(perform: cancel)
            VStack(spacing: 16) {
                Text("NAME YOUR EGG").font(GrubFont.size(12)).foregroundColor(Color(ink: BurrowInk.cream))
                TextField("", text: $text)
                    .font(GrubFont.size(14)).multilineTextAlignment(.center)
                    .foregroundColor(Color(ink: BurrowInk.amber))
                    .textInputAutocapitalization(.characters).autocorrectionDisabled()
                    .focused($focused)
                    .padding(12)
                    .background(Color(ink: BurrowInk.soil4))
                    .overlay(Rectangle().strokeBorder(Color(ink: BurrowInk.soil1), lineWidth: 3))
                    .onChange(of: text) { _, new in
                        if new.count > BurrowRules.maxNameLength { text = String(new.prefix(BurrowRules.maxNameLength)) }
                    }
                    .onSubmit { _ = submit(text) }
                Text("A-Z, UP TO 10").font(GrubFont.size(6)).foregroundColor(Color(ink: BurrowInk.mutedText))
                HStack(spacing: 12) {
                    Button { text = random() } label: {
                        Text("RANDOM").font(GrubFont.size(9)).foregroundColor(Color(ink: BurrowInk.hollow))
                            .padding(.horizontal, 14).padding(.vertical, 11)
                            .background(Color(ink: BurrowInk.creamDim))
                    }
                    .buttonStyle(PixelPressStyle())
                    Button { _ = submit(text) } label: {
                        Text("OK").font(GrubFont.size(9)).foregroundColor(Color(ink: BurrowInk.hollow))
                            .padding(.horizontal, 22).padding(.vertical, 11)
                            .background(Color(ink: BurrowInk.amber))
                    }
                    .buttonStyle(PixelPressStyle())
                }
            }
            .padding(24)
            .background(Color(ink: BurrowInk.hollow))
            .overlay(Rectangle().strokeBorder(Color(ink: BurrowInk.amber), lineWidth: 4))
            .padding(32)
        }
    }
}
```

  An invalid name shows the model's "USE 1-10 LETTERS" toast. The toast draws under this overlay, so also show it inline: add `@State private var invalid = false`, set `invalid = !submit(text)` in both submit paths, and show `Text("USE 1-10 LETTERS").font(GrubFont.size(7)).foregroundColor(Color(ink: BurrowInk.berry))` under the field when `invalid`. (Write the OK action as `{ invalid = !submit(text) }`, and the same for `.onSubmit`.)

- [ ] **Step 6: Loop demo.** Add to the DEBUG section and call it from the DEBUG `.task` after `runMoltDemoIfRequested()`:

```swift
    /// `-burrowLoopDemo` (use with `-burrowReset -burrowAdult horn`). Seconds after the view appears:
    /// 2.0 tap the adult → reveal with PIN IT (until 4.5) · 4.5 pin → box opens (until 7.5)
    /// 7.5 close → horn-spotted egg · 9.5 tap → name prompt (until 12.0) · 12.0 name PIP
    /// 13.0 / 14.5 crack, crack (2/3 until 16.0) · 16.0 crack → violet-tinted larva hatches.
    private func runLoopDemoIfRequested() async {
        guard BurrowDebug.loopDemo else { return }
        func wait(_ s: Double) async { try? await Task.sleep(nanoseconds: UInt64(s * 1_000_000_000)) }
        await wait(2.0); model.tapGrub()
        await wait(2.5); withAnimation { model.pin() }
        await wait(3.0); withAnimation { model.showBox = false }
        await wait(2.0); model.tapGrub()
        await wait(2.5); _ = model.nameEgg("PIP")
        await wait(1.0); model.tapGrub()
        await wait(1.5); model.tapGrub()
        await wait(1.5); model.tapGrub()
    }
```

- [ ] **Step 7: BUILD**, then all burrow tests: Rules 45, Store 6, Layout 3, Pacing 3, Model 6, Art 4 = **67**. **Commit**

```bash
git add GrubIOS/Burrow/BurrowHomeView.swift
git commit -m "feat(burrow): specimen box, PIN IT, egg naming and hatching" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 6: Simulator verification

`D=8AABF67E-2193-4949-8A0E-0954E9789898`, `B=com.jessedev.GrubIOS`, `OUT=<scratchpad>/p4`. Screenshots at fixed times from launch, ≥ 1 s into each state.

- [ ] **Step 1: First launch is an egg.** `-burrowReset` → screenshot at 3 s. Expected: teal-spotted egg in the chamber, banner "A NEW EGG! / TAP IT TO NAME IT", FEED dimmed, box button top-left with no badge.

- [ ] **Step 2: Loop demo.**

```bash
python3 - "$D" "$B" "$OUT" <<'EOF'
import subprocess, sys, time
d, b, out = sys.argv[1:]
subprocess.run(["xcrun","simctl","launch",d,b,"-burrowReset","-burrowAdult","horn","-burrowLoopDemo"], capture_output=True)
t0 = time.time()
for at, name in [(4.0,"p4_reveal"),(6.8,"p4_box"),(9.2,"p4_egg"),(11.5,"p4_name"),(15.5,"p4_cracked"),(18.5,"p4_hatched")]:
    time.sleep(max(0, t0 + at - time.time()))
    subprocess.run(["xcrun","simctl","io",d,"screenshot",f"{out}/{name}.png"], capture_output=True)
EOF
python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(d['stage'],d['name'],d['lineage'],d['tint'],[ (s['name'],s['species']) for s in d['specimens']])" "$(xcrun simctl get_app_container $D $B data)/Library/Application Support/burrow.json"
```

Expected:
- `p4_reveal`: HORN card with LATER / PIN IT.
- `p4_box`: SPECIMENS box with one cell: HORN, named GRUB, today's date.
- `p4_egg`: violet-spotted egg; banner "A NEW EGG! / TAP IT TO NAME IT"; the box button shows badge 1.
- `p4_name`: "NAME YOUR EGG" prompt with a prefilled name.
- `p4_cracked`: banner "TAP TO HATCH 2/3"; egg with two crack stages.
- `p4_hatched`: violet-tinted larva (body 0x5eb5b2), stat bars back, "PIP HATCHED!" toast.
- Save line: `larva PIP horn horn [('GRUB', 'horn')]`.

- [ ] **Step 3: Odds carry the lineage.** No screenshot: the save line in Step 2 shows `lineage: horn`, and `test_lineage_carries_into_the_next_molt_odds` proves that gives HORN 3/9 in the next molt.

- [ ] **Step 4: Fix and recheck** anything off; **Step 5: Report** a sheet to Jesse; **Step 6: Commit** fixes (skip if none).

---

## Done when

- 67 burrow tests pass.
- First launch shows an egg. The loop demo goes reveal → PIN IT → box → egg → name → 3 cracks → tinted larva. The save holds the specimen and the lineage/tint.
