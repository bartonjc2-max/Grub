import Foundation

// MARK: - Runtime types

struct GridPoint: Equatable {
    var x: Int
    var y: Int
    static func + (l: GridPoint, d: Direction8) -> GridPoint {
        GridPoint(x: l.x + d.dx, y: l.y + d.dy)
    }
}

/// 8 compass directions. y increases downward (screen coords).
enum Direction8: CaseIterable {
    case n, ne, e, se, s, sw, w, nw

    var dx: Int {
        switch self {
        case .ne, .e, .se: return 1
        case .nw, .w, .sw: return -1
        case .n, .s: return 0
        }
    }
    var dy: Int {
        switch self {
        case .se, .s, .sw: return 1
        case .ne, .n, .nw: return -1
        case .e, .w: return 0
        }
    }

    /// Quantize a joystick vector (y down) to the nearest of 8 directions.
    /// Returns nil inside a small dead zone.
    static func from(dx: Double, dy: Double) -> Direction8? {
        let mag = (dx * dx + dy * dy).squareRoot()
        guard mag > 0.2 else { return nil }
        // Sector index 0..7 starting at east, going clockwise (screen y down).
        let angle = atan2(dy, dx)                 // -pi..pi, +x=east, +y=south
        let twoPi = Double.pi * 2
        let normalized = (angle + twoPi).truncatingRemainder(dividingBy: twoPi) // 0..2pi
        let sector = Int((normalized / (twoPi / 8)).rounded()) % 8
        // sector 0=e,1=se,2=s,3=sw,4=w,5=nw,6=n,7=ne
        switch sector {
        case 0: return .e
        case 1: return .se
        case 2: return .s
        case 3: return .sw
        case 4: return .w
        case 5: return .nw
        case 6: return .n
        default: return .ne
        }
    }
}

enum Tile: Character {
    case wall = "#"
    case floor = "."
    case entry = "E"
    case stairs = ">"
    // 'S' (slime spawn) is parsed into an enemy and stored as floor.
}

enum RunStatus { case playing, won, dead }

struct EnemyInstance: Equatable {
    var tile: GridPoint
    var hp: Int
    var stepCooldown: Double   // seconds until next AI step
}

// MARK: - Engine

/// Pure value-type Descent engine. SwiftUI-free, unit-testable. All run state
/// and logic live here; views render it and feed it intents + dt.
struct DescentEngine {
    let tuning: DescentTuning
    let width: Int
    let height: Int

    private(set) var tiles: [[Tile]]      // tiles[y][x]
    let slimeSpawns: [GridPoint]          // original 'S' tiles (for the static-path invariant)

    private(set) var grub: GridPoint
    private(set) var facing: Direction8 = .s
    private(set) var hearts: Int
    private(set) var enemies: [EnemyInstance]
    private(set) var status: RunStatus = .playing

    // Input + timers (private)
    private var heldDirection: Direction8?
    private var moveCooldown: Double = 0          // time until Grub may step

    init(layout: [String], tuning: DescentTuning = DescentTuning()) {
        self.tuning = tuning
        self.height = layout.count
        self.width = layout.first?.count ?? 0
        self.hearts = tuning.startHearts

        var parsed: [[Tile]] = []
        var grubStart = GridPoint(x: 1, y: 1)
        var spawns: [GridPoint] = []
        var foundEntry = false

        for (y, line) in layout.enumerated() {
            var row: [Tile] = []
            for (x, ch) in line.enumerated() {
                switch ch {
                case "#": row.append(.wall)
                case "E":
                    row.append(.entry); grubStart = GridPoint(x: x, y: y); foundEntry = true
                case ">": row.append(.stairs)
                case "S":
                    row.append(.floor); spawns.append(GridPoint(x: x, y: y))
                case ".": row.append(.floor)
                default:
                    #if DEBUG
                    print("DescentEngine: unknown tile '\(ch)' at (\(x),\(y)) -> floor")
                    #endif
                    row.append(.floor)
                }
            }
            parsed.append(row)
        }
        #if DEBUG
        if !foundEntry { print("DescentEngine: no 'E' entry in layout, defaulting to (1,1)") }
        #endif

        self.tiles = parsed
        self.slimeSpawns = spawns
        self.grub = grubStart
        self.enemies = spawns.map { EnemyInstance(tile: $0, hp: tuning.enemyHP, stepCooldown: tuning.enemyStepDuration) }
    }

    func isPassable(_ p: GridPoint) -> Bool {
        guard p.y >= 0, p.y < height, p.x >= 0, p.x < width else { return false }
        return tiles[p.y][p.x] != .wall
    }

    func tile(at p: GridPoint) -> Tile? {
        guard p.y >= 0, p.y < height, p.x >= 0, p.x < width else { return nil }
        return tiles[p.y][p.x]
    }

    /// Joystick changed. nil = released. Facing updates immediately; a newly
    /// pressed direction resets the step cooldown so the first step is instant.
    mutating func setMove(_ dir: Direction8?) {
        guard status == .playing else { return }
        if let dir = dir {
            if heldDirection == nil { moveCooldown = 0 }   // instant first step
            facing = dir
        }
        heldDirection = dir
    }

    /// Advance the simulation by dt seconds.
    mutating func update(_ dt: Double) {
        guard status == .playing else { return }
        stepGrub(dt)
    }

    private mutating func stepGrub(_ dt: Double) {
        moveCooldown -= dt
        guard let dir = heldDirection, moveCooldown <= 0 else { return }
        let target = grub + dir
        if isPassable(target) { grub = target }
        moveCooldown = tuning.grubStepDuration
    }

    /// True iff a 4-connected path of passable tiles connects the entry to the
    /// stairs WITHOUT passing through any slime spawn tile. Validates the
    /// floor-1-passable invariant (combat is optional). Static layout only —
    /// it cannot account for the live, moving enemy.
    func hasStaticPathToStairs() -> Bool {
        guard let start = firstTile(.entry), let goal = firstTile(.stairs) else { return false }
        let blocked = Set(slimeSpawns.map { [$0.x, $0.y] })
        var visited = Set<[Int]>()
        var queue = [start]
        visited.insert([start.x, start.y])
        let steps = [GridPoint(x: 1, y: 0), GridPoint(x: -1, y: 0),
                     GridPoint(x: 0, y: 1), GridPoint(x: 0, y: -1)]
        while let cur = queue.first {
            queue.removeFirst()
            if cur == goal { return true }
            for d in steps {
                let nxt = GridPoint(x: cur.x + d.x, y: cur.y + d.y)
                let key = [nxt.x, nxt.y]
                if visited.contains(key) { continue }
                if blocked.contains(key) { continue }
                if !isPassable(nxt) { continue }
                visited.insert(key)
                queue.append(nxt)
            }
        }
        return false
    }

    private func firstTile(_ t: Tile) -> GridPoint? {
        for y in 0..<height {
            for x in 0..<width where tiles[y][x] == t {
                return GridPoint(x: x, y: y)
            }
        }
        return nil
    }
}
