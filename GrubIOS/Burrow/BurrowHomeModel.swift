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

/// A dig in progress: which spot, and how many strikes are left in it.
struct DigTrip: Equatable {
    let spot: Int
    var strikesLeft: Int
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
    /// The decor the player is placing (picked in the Finds panel); free slots glow.
    @Published private(set) var placing: FindKind?
    /// A placed decor the player tapped; the HUD offers REMOVE / KEEP.
    @Published private(set) var selectedSlot: Int?
    /// Animation-clock time the cocoon started (`.molted`); the view plays ~3 s of cocoon.
    @Published private(set) var moltAt: TimeInterval = -100
    /// The adult whose reveal card is showing.
    @Published private(set) var revealing: Species?
    /// "MOLT NOW?" is showing. Reasoner review (board #287): a habitual pet-tap must never
    /// trigger the irreversible molt by itself.
    @Published private(set) var confirmingMolt = false
    /// The name prompt for a fresh egg is showing.
    @Published private(set) var namingEgg = false
    /// The specimen box is open.
    @Published var showBox = false
    /// The finds bag and molt panels. These live on the model rather than in the view so
    /// `canStartTrip` can see them — it has to refuse a trip while any panel is open.
    @Published var showBag = false
    @Published var showMolt = false
    /// The dig in progress, if any. Set by `startTrip`, cleared when the find turns up,
    /// the strikes run out, or the player leaves.
    @Published private(set) var trip: DigTrip?
    /// Animation-clock time of the last egg crack (the egg shakes for 0.3 s).
    @Published private(set) var crackAt: TimeInterval = -10

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
        if BurrowDebug.moltReady {
            loaded.molt = BurrowRules.moltGoal
            loaded.eaten = [.root: 3, .berry: 2]     // odds: GRUB 4/12, CLAWS 4/12, others 1/12
        }
        if let sp = BurrowDebug.adult {
            loaded.stage = .adult; loaded.adult = sp
            if loaded.name.isEmpty { loaded.name = "GRUB" }
        }
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
    var holes: [Int] { save.holes }
    var foodCount: Int { save.bag.filter { $0.key.isFood }.values.reduce(0, +) }
    var findCount: Int { save.bag.values.reduce(0, +) }
    var isHappy: Bool { BurrowRules.isHappy(save) }
    var isSulking: Bool { BurrowRules.isSulking(save) }
    var placed: [Int: FindKind] { save.placed }
    var freeSlots: [Int] { (0..<BurrowRules.decorSlots).filter { save.placed[$0] == nil } }
    var canAct: Bool { save.stage == .larva }
    var stage: GrubStage { save.stage }
    var adult: Species? { save.adult }
    var isMoltReady: Bool { BurrowRules.isMoltReady(save) }
    var odds: [Species: Double] { BurrowRules.odds(save) }
    static let cocoonSeconds: TimeInterval = 3
    var name: String { save.name }
    var eggCracks: Int { save.eggCracks }
    var tint: Species? { save.tint }
    var specimens: [Specimen] { save.specimens }
    func randomEggName() -> String { BurrowRules.eggNames.randomElement() ?? "PIP" }

    private var now: TimeInterval { Date().timeIntervalSinceReferenceDate }   // animation clock

    // MARK: Actions

    func tick() { apply(BurrowRules.advance(save, to: clock(), rng: &rng)) }
    func dig(spot: Int) { apply(BurrowRules.dig(save, spot: spot, now: clock(), rng: &rng)) }
    func feed() { apply(BurrowRules.feed(save, kind: nil, now: clock())) }
    func pet() { apply(BurrowRules.pet(save, now: clock())) }
    func feed(kind: FindKind) { apply(BurrowRules.feed(save, kind: kind, now: clock())) }

    func startPlacing(_ kind: FindKind) {
        selectedSlot = nil
        placing = kind
    }

    func cancelPlacing() { placing = nil }

    /// A tap on decor slot `slot`: places while placing, otherwise selects a placed item.
    func tapSlot(_ slot: Int) {
        guard canAct else { return }
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

    /// Tap on the grub: when molt-ready, ask "MOLT NOW?"; otherwise pet. In `.adult`, re-open the card.
    func tapGrub() {
        switch save.stage {
        case .larva:
            if isMoltReady { confirmingMolt = true } else { pet() }
        case .adult:
            revealing = save.adult
        case .egg:
            if save.name.isEmpty { namingEgg = true } else { apply(BurrowRules.crackEgg(save, now: clock())) }
        }
    }

    /// MOLT on the confirm: the only path to `startMolt`.
    func confirmMolt() {
        confirmingMolt = false
        apply(BurrowRules.startMolt(save, now: clock(), rng: &rng))
    }

    /// NOT YET on the confirm: back to caring (the grub stays molt-ready).
    func cancelMolt() { confirmingMolt = false }

    func dismissReveal() { revealing = nil }

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

    // MARK: The dig

    /// Spec §2 "Stage gating". `canAct` is only `stage == .larva`, so it can't be reused here —
    /// digging is allowed during the egg stage too.
    ///
    /// There's no `!inCocoon` clause because there's no cocoon state to check: `startMolt` sets
    /// `stage = .adult` synchronously, so the stage test below already excludes it.
    var canStartTrip: Bool {
        (save.stage == .egg || save.stage == .larva)
            && trip == nil && revealing == nil && placing == nil
            && !namingEgg && !confirmingMolt && !showBox && !showBag && !showMolt
    }

    func startTrip(spot: Int) {
        guard canStartTrip else { return }
        let r = BurrowRules.startTrip(save, spot: spot)
        apply(r)
        for case .tripStarted(let s, let n) in r.events { trip = DigTrip(spot: s, strikesLeft: n) }
    }

    func strike(tile: Int) {
        guard var t = trip else { return }
        let r = BurrowRules.strike(save, spot: t.spot, tile: tile, strikesLeft: t.strikesLeft)
        apply(r)                 // `apply` already persists when the save changed
        if r.events.contains(where: { if case .refused = $0 { return true }; return false }) { return }
        t.strikesLeft -= 1
        trip = t
        if r.events.contains(where: { if case .dugUp = $0 { return true }; return false }) {
            trip = nil
        } else if t.strikesLeft == 0 {
            say(Self.message(.noStrikes))
            trip = nil
        }
    }

    /// Leaving early is the same as running out: the save already holds every broken tile.
    func leaveTrip() { trip = nil }

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
            guard let L = layout, BurrowSpots.spots.indices.contains(spot) else { break }
            let p = BurrowSpots.resolve(spot, L)
            add(.init(kind: .dirt, x: Double(p.x), y: Double(p.y), born: t, life: 0.7))
            add(.init(kind: .reveal(kind), x: Double(p.x), y: Double(p.y), born: t, life: 1.2))
            add(.init(kind: .text("+" + kind.label, BurrowInk.amberHi), x: Double(p.x), y: Double(p.y - 6), born: t + 0.15, life: 1.3))
            Haptics.thud()
            if save.digs == 0 { say("THAT'S ALL\nFOR NOW") }
        case .bonusFind(let spot, let kind):
            guard let L = layout, BurrowSpots.spots.indices.contains(spot) else { break }
            let p = BurrowSpots.resolve(spot, L)
            add(.init(kind: .reveal(kind), x: Double(p.x + 6), y: Double(p.y), born: t + 0.45, life: 1.2))
            add(.init(kind: .text("BONUS! +" + kind.label, BurrowInk.teal), x: Double(p.x), y: Double(p.y - 11), born: t + 0.5, life: 1.4))
            Haptics.soft()
        case .tileBroken(_, let heat):
            // No particle here: the burrow FX layer draws under the grid overlay, so anything
            // added would be invisible. The tile art changing is the feedback; this is the feel.
            if heat == .hot { Haptics.thud() } else { Haptics.soft() }
        case .rockChipped:
            Haptics.thud()
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
        case .placed(let slot, let kind):
            if let L = layout, let p = L.decorSlot(slot) {
                add(.init(kind: .dirt, x: Double(p.x), y: Double(p.y - 1), born: t, life: 0.6))
                add(.init(kind: .text(kind.label, BurrowInk.amberHi), x: Double(p.x), y: Double(p.y - 9), born: t + 0.1, life: 1.2))
            }
            Haptics.thud()
        case .removed(_, let kind):
            say("\(kind.label)\nBACK IN BAG")
            Haptics.soft()
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
        case .slotTaken:          return "SPOT TAKEN"
        case .notDecor:           return "THAT'S FOOD"
        case .emptySlot:          return "NOTHING THERE"
        case .notMoltReady:       return "NOT READY\nTO MOLT YET"
        case .badName:            return "USE 1-10 LETTERS"
        case .noStrikes:          return "OUT OF STRIKES"
        case .rootTile:           return "A ROOT.\nDIG ELSEWHERE"
        case .alreadyBroken:      return "ALREADY DUG"
        case .badTile:            return "CAN'T DIG THERE"
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
    /// `-burrowShowBag`: open the Finds panel on launch.
    static var showBag: Bool { args.contains("-burrowShowBag") }
    /// `-burrowMoltReady`: start with a full MOLT bar and a root-heavy diet (odds visibly shifted).
    static var moltReady: Bool { args.contains("-burrowMoltReady") }
    /// `-burrowAdult <species>`: start as that revealed adult (e.g. `-burrowAdult horn`).
    static var adult: Species? {
        guard let i = args.firstIndex(of: "-burrowAdult"), i + 1 < args.count else { return nil }
        return Species(rawValue: args[i + 1])
    }
    /// `-burrowMoltDemo`: script the molt (see BurrowHomeView).
    static var moltDemo: Bool { args.contains("-burrowMoltDemo") }
    /// `-burrowLoopDemo` (use with `-burrowReset -burrowAdult horn`): pin → box → name → hatch.
    static var loopDemo: Bool { args.contains("-burrowLoopDemo") }
}
#endif
