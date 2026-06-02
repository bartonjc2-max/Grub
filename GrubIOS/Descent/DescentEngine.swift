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
}
