import Foundation

/// The dig mini-game's rules. Pure functions over the save, like the rest of `BurrowRules`.
/// Spec: docs/superpowers/specs/2026-11-10-dig-minigame-design.md
extension BurrowRules {

    /// Strikes a trip to `spot` would grant right now.
    static func tripStrikes(_ s: BurrowSave, spot: Int) -> Int {
        let layer = BurrowSpots.layer(spot)
        let condition = s.buried.first { $0.spot == spot }?.condition
        let fromCondition: Int
        switch condition {
        case .wet:   fromCondition = 2
        case .rooty: fromCondition = -1
        default:     fromCondition = 0
        }
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
}
