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
