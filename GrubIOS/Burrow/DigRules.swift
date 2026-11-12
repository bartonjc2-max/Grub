import Foundation

/// The dig mini-game's rules. Pure functions over the save, like the rest of `BurrowRules`.
/// Spec: docs/superpowers/specs/2026-11-10-dig-minigame-design.md
extension BurrowRules {

    /// Strikes a trip to `spot` would grant right now.
    static func tripStrikes(_ s: BurrowSave, spot: Int) -> Int {
        let layer = BurrowSpots.layer(spot)
        let condition = s.buried.first { $0.spot == spot }?.condition
        // Rooty costs tiles, not strikes. It used to also take a strike, which made deep
        // rooty spots a 3-strike search of 25 tiles — winnable about half the time. Measured
        // 2026-11-10 (DigBalanceTests); Jesse chose dropping the penalty over loosening deep.
        let fromCondition = condition == .wet ? 2 : 0
        // `isHappy` / `isSulking` are both larva-only, so an egg gets 0. Sulking wins when
        // both hold — a starving grub digs badly however cheerful it is.
        let fromMood = isSulking(s) ? -1 : isHappy(s) ? 2 : 0
        return max(2, layer.strikes + fromCondition + fromMood)
    }

    /// Spend a dig charge and walk to the spot. Mood is read once, here.
    static func startTrip(_ s0: BurrowSave, spot: Int) -> BurrowResult {
        guard s0.stage == .egg || s0.stage == .larva else { return refuse(s0, .wrongStage) }
        guard let i = s0.buried.firstIndex(where: { $0.spot == spot })
        else { return refuse(s0, .nothingBuriedThere) }
        guard s0.digs > 0 else { return refuse(s0, .noDigs) }

        var s = s0
        s.digs -= 1
        s.buried[i].visited = true
        return BurrowResult(save: s, events: [.tripStarted(spot: spot, strikes: tripStrikes(s, spot: spot))])
    }

    /// What a clean dig turns up alongside the find, drawn from the spot's own soil — so deep
    /// pockets pay better, which is some consolation for how rarely a 5-strike dig comes in
    /// three under.
    ///
    /// Derived rather than stored: seeded from the spot *and* the find's position, so it is
    /// stable for a given burial, different the next time that spot is filled, and needs no
    /// new save field (which migrated v1 finds would not have had).
    /// What condition a find comes out of the ground in — 1 chipped, 2 fine, 3 pristine.
    ///
    /// Deeper soil, a glinting spot and a clean dig each push it up, which is the point:
    /// before tiers, decor was four objects you owned by about day six, after which roughly a
    /// third of everything dug could not be eaten or placed and sat in the bag for good.
    /// Making the *quality* the reward ties the shelves back to digging deep and digging well,
    /// and unlike a longer list of kinds it does not run out.
    ///
    /// Measured over 200 runs (docs/burrow): 74 / 20 / 4 % chipped / fine / pristine, every
    /// kind pristine around day 37 at three digs a day (90th percentile day 50), day 111 once
    /// a day. Deterministic per find, so the same pocket always holds the same thing.
    static func tier(for find: BuriedFind, cleanDig: Bool) -> Int {
        var rng = BurrowRNG(seed: BuriedFind.seed(for: find.spot)
                            &+ UInt64(find.findTile) &* 1_099_511_628_211
                            &+ (cleanDig ? 7 : 0))
        let score = BurrowSpots.layer(find.spot).depth
            + (find.condition == .glinting ? 1 : 0)
            + (cleanDig ? 1 : 0)
        if score >= 3, Int.random(in: 0..<100, using: &rng) < 18 { return FindKind.maxTier }
        if score >= 2, Int.random(in: 0..<100, using: &rng) < 35 { return 2 }
        return 1
    }

    static func bonusKind(for find: BuriedFind) -> FindKind {
        var rng = BurrowRNG(seed: BuriedFind.seed(for: find.spot)
                            &+ UInt64(find.findTile) &* 2_654_435_761)
        return DigGen.rollKind(layer: BurrowSpots.layer(find.spot), rng: &rng)
    }

    /// One shovel strike at `tile`. `strikesLeft` is passed in only so the rules can refuse;
    /// the caller decrements it whenever the result is not a refusal.
    static func strike(_ s0: BurrowSave, spot: Int, tile: Int, strikesLeft: Int) -> BurrowResult {
        guard (0..<DigGrid.tileCount).contains(tile) else { return refuse(s0, .badTile) }
        guard let i = s0.buried.firstIndex(where: { $0.spot == spot })
        else { return refuse(s0, .nothingBuriedThere) }
        guard strikesLeft > 0 else { return refuse(s0, .noStrikes) }

        let find = s0.buried[i]
        switch find.tiles[tile] {
        case .root:   return refuse(s0, .rootTile)
        case .broken: return refuse(s0, .alreadyBroken)
        case .rock(let hp) where hp > 1:
            var s = s0
            s.buried[i].tiles[tile] = .rock(hp: hp - 1)
            return BurrowResult(save: s, events: [.rockChipped(tile: tile)])
        case .soil, .rock:
            var s = s0
            s.buried[i].tiles[tile] = .broken
            let d = DigGrid.distance(tile, find.findTile)
            var events: [BurrowEvent] = [
                .tileBroken(tile: tile, heat: DigGrid.heat(distance: d, wet: find.condition == .wet))
            ]
            if tile == find.findTile {
                s.buried.remove(at: i)
                s.holes.append(spot)
                let clean = strikesLeft - 1 >= cleanDigStrikes
                events.append(.dugUp(spot: spot, kind: find.kind))
                if let up = BurrowRules.collect(&s, kind: find.kind,
                                                tier: tier(for: find, cleanDig: clean)) {
                    events.append(up)
                }
                // Finding it with strikes to spare pays out whatever else was in the pocket.
                // This is the whole reason to read the grid rather than tap it flat: the win
                // itself is nearly certain, the margin is not.
                if clean {
                    let extra = bonusKind(for: find)
                    events.append(.cleanDig(spot: spot, kind: extra))
                    if let up = BurrowRules.collect(&s, kind: extra,
                                                    tier: tier(for: find, cleanDig: true)) {
                        events.append(up)
                    }
                }
            }
            return BurrowResult(save: s, events: events)
        }
    }
}
