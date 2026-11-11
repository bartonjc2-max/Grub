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
                s.bag[find.kind, default: 0] += 1
                events.append(.dugUp(spot: spot, kind: find.kind))
            }
            return BurrowResult(save: s, events: events)
        }
    }
}
