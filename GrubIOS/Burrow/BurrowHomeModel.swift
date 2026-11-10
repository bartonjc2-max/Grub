import SwiftUI
import UIKit

/// Something buried in the soil, shown with an amber "!" marker (gameplay-flow step 2: RETURN).
struct BuriedFind: Identifiable, Equatable {
    let id = UUID()
    let kind: FindKind
    let anchor: CellAnchor
    var dug = false
}

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

/// Home-screen state for the pixel-burrow prototype: DIG → FEED → (MOLT) loop.
/// Local and in-memory for now — not yet wired to GameState persistence.
@MainActor
final class BurrowHomeModel: ObservableObject {
    static let maxStat = 10

    @Published var belly = 5
    @Published var joy = 6
    @Published var molt = 3
    @Published var digsLeft = 3
    @Published var bag: [FindKind: Int] = [.berry: 1]
    @Published var finds: [BuriedFind] = [
        BuriedFind(kind: .berry,   anchor: CellAnchor(ref: .chamberTop, x: 6, dy: 13)),
        BuriedFind(kind: .amber,   anchor: CellAnchor(ref: .surface, x: 39, dy: 9)),
        BuriedFind(kind: .crystal, anchor: CellAnchor(ref: .surface, x: 59, dy: 15)),
        BuriedFind(kind: .bone,    anchor: CellAnchor(ref: .chamberBottom, x: 34, dy: 11)),
    ]
    @Published private(set) var fx: [BurrowFX] = []
    @Published private(set) var toast: String?
    @Published private(set) var hopAt: TimeInterval = -10
    @Published private(set) var chompAt: TimeInterval = -10
    @Published private(set) var digHintAt: TimeInterval = -10

    /// Top-centre of the grub sprite in design cells; set by the view from its layout.
    var grubTop: (x: Int, y: Int) = (32, 60)

    var holes: [CellAnchor] { finds.filter(\.dug).map(\.anchor) }
    var foodCount: Int { bag.filter { $0.key.edible }.values.reduce(0, +) }
    var findCount: Int { bag.values.reduce(0, +) }

    private var now: TimeInterval { Date().timeIntervalSinceReferenceDate }

    // MARK: Actions

    func dig(_ find: BuriedFind, in layout: BurrowLayout) {
        guard let i = finds.firstIndex(where: { $0.id == find.id }), !finds[i].dug else { return }
        guard digsLeft > 0 else {
            say("NO DIGS LEFT\nBACK TOMORROW")
            Haptics.soft()
            return
        }
        digsLeft -= 1
        finds[i].dug = true
        bag[find.kind, default: 0] += 1
        let p = layout.resolve(find.anchor)
        let t = now
        add(.init(kind: .dirt, x: Double(p.x), y: Double(p.y), born: t, life: 0.7))
        add(.init(kind: .reveal(find.kind), x: Double(p.x), y: Double(p.y), born: t, life: 1.2))
        add(.init(kind: .text("+" + find.kind.label, BurrowInk.amberHi), x: Double(p.x), y: Double(p.y - 6), born: t + 0.15, life: 1.3))
        Haptics.thud()
        if digsLeft == 0 { say("THAT'S ALL\nFOR TODAY") }
    }

    func feed() {
        guard let food = bag.keys.first(where: { $0.edible && (bag[$0] ?? 0) > 0 }) else {
            say("NO FOOD\nDIG FOR SOME")
            Haptics.soft()
            return
        }
        bag[food, default: 0] -= 1
        if bag[food] == 0 { bag[food] = nil }
        belly = min(Self.maxStat, belly + 3)
        molt = min(Self.maxStat, molt + 2)
        chompAt = now
        add(.init(kind: .text("+BELLY", BurrowInk.berry), x: Double(grubTop.x), y: Double(grubTop.y - 2), born: now, life: 1.2))
        Haptics.thud()
        if molt >= Self.maxStat { say("READY TO MOLT!") }
    }

    func pet() {
        hopAt = now
        joy = min(Self.maxStat, joy + 1)
        add(.init(kind: .heart, x: Double(grubTop.x), y: Double(grubTop.y), born: now, life: 1.0))
        Haptics.soft()
    }

    func digHint() {
        if digsLeft == 0 { say("NO DIGS LEFT\nBACK TOMORROW"); return }
        if finds.allSatisfy(\.dug) { say("NOTHING LEFT\nTO DIG UP"); return }
        digHintAt = now
        say("TAP A ! TO DIG")
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
