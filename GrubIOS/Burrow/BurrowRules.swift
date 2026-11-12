import Foundation

enum Refusal: Equatable {
    case noDigs, nothingBuriedThere, noFood, notFood, tooFull, slotTaken,
         notDecor, notInBag, emptySlot, notMoltReady, wrongStage, badName,
         noStrikes, rootTile, alreadyBroken, badTile
}

enum BurrowEvent: Equatable {
    case buried(spot: Int, kind: FindKind)
    case dugUp(spot: Int, kind: FindKind)
    case ate(FindKind, joyGained: Bool), petted(joyGained: Bool)
    case placed(slot: Int, kind: FindKind), removed(slot: Int, kind: FindKind)
    case moltReady
    case molted(Species), pinned(Specimen), named(String), eggCracked(stage: Int), hatched
    case tripStarted(spot: Int, strikes: Int)
    case cleanDig(spot: Int, kind: FindKind)
    case upgraded(kind: FindKind, tier: Int)
    case tileBroken(tile: Int, heat: Heat)
    case rockChipped(tile: Int)
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
    static let decorSlots = 4
    static let moltGoal = 10
    static let happyJoy = 7
    /// Strikes that must still be in hand *after* the winning one for a dig to count as clean.
    /// Measured over 6,000 seeded trips: 3 spare happens on 34 % of them, against 65 % for 2
    /// and 12 % for 4. It replaces the old hidden 35 % bonus-find roll with the same rate,
    /// earned rather than rolled.
    static let cleanDigStrikes = 3

    /// Duplicate decor finds that bank into the next tier of something. 12 is tuned, not
    /// guessed: it puts every kind pristine around day 37 at three digs a day and day 111 at
    /// one, which is the long tail the four-kinds-four-slots design never had.
    static let bankPerTier = 12

    /// Put a dug-up find in the bag, and for decor decide what it *does*.
    ///
    /// Before tiers, a decor find past the fourth was dead on arrival — it could not be eaten
    /// and PLACE was disabled with the slots full, so it sat in the bag forever. Measured, that
    /// was about 30 % of everything dug from week one. Now a better one upgrades the kind
    /// outright (and because `placed` stores only the kind, the furnished slot improves the
    /// moment you get home), and anything else banks toward the next tier — of that kind, or
    /// once that kind is pristine, of whichever kind is furthest behind. Nothing is wasted
    /// until the whole set is pristine, which is months away.
    static func collect(_ s: inout BurrowSave, kind: FindKind, tier: Int) -> BurrowEvent? {
        s.bag[kind, default: 0] += 1
        guard kind.isDecor else { return nil }
        if tier > s.tier(kind) {
            s.bestTier[kind] = tier
            return .upgraded(kind: kind, tier: tier)
        }
        let behind = FindKind.allCases
            .filter { $0.isDecor && s.tier($0) < FindKind.maxTier }
            .min { (s.tier($0), s.bank[$0, default: 0]) < (s.tier($1), s.bank[$1, default: 0]) }
        guard let target = s.tier(kind) < FindKind.maxTier ? kind : behind else { return nil }
        let next = s.bank[target, default: 0] + 1
        guard next >= bankPerTier else { s.bank[target] = next; return nil }
        s.bank[target] = 0
        s.bestTier[target] = s.tier(target) + 1
        return .upgraded(kind: target, tier: s.tier(target))
    }

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
        // Draw order is part of the contract: spot -> kind -> condition -> grid.
        let layer = BurrowSpots.layer(spot)
        let kind = DigGen.rollKind(layer: layer, rng: &rng)
        let condition = DigGen.rollCondition(rng: &rng)
        let g = DigGen.make(layer: layer, condition: condition, rng: &rng)
        let f = BuriedFind(spot: spot, kind: kind, condition: condition,
                           findTile: g.findTile, tiles: g.tiles)
        s.buried.append(f)
        s.holes.removeAll { $0 == spot }
        return f
    }

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
        take(&s, food)
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

    /// Remove one `kind` from the bag, dropping empty entries.
    static func take(_ s: inout BurrowSave, _ kind: FindKind) {
        s.bag[kind, default: 0] -= 1
        if s.bag[kind, default: 0] <= 0 { s.bag[kind] = nil }
    }

    static func refuse(_ s: BurrowSave, _ why: Refusal) -> BurrowResult {
        BurrowResult(save: s, events: [.refused(why)])
    }
}
