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

    static func refuse(_ s: BurrowSave, _ why: Refusal) -> BurrowResult {
        BurrowResult(save: s, events: [.refused(why)])
    }
}
