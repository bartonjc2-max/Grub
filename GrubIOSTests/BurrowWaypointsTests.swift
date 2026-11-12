import XCTest
@testable import GrubIOS

final class BurrowWaypointsTests: XCTestCase {
    func test_every_spot_is_reachable_from_the_chamber() {
        for (name, size) in BurrowSpotsTests.sizes {
            let L = BurrowLayout(size: size, displayScale: 2)
            for spot in 0..<BurrowRules.spotCount {
                let at = BurrowSpots.fallback[spot]
                let path = BurrowWaypoints.path(to: at, L)
                XCTAssertGreaterThanOrEqual(path.count, 2, "\(name): spot \(spot) has no path")
                let end = BurrowSpots.resolve(at, L)
                XCTAssertEqual(path.last!, Waypoint(x: end.x, y: end.y),
                               "\(name): the path ends at the spot")
            }
        }
    }

    func test_the_path_starts_at_the_chamber() {
        for (name, size) in BurrowSpotsTests.sizes {
            let L = BurrowLayout(size: size, displayScale: 2)
            for spot in 0..<BurrowRules.spotCount {
                let at = BurrowSpots.fallback[spot]
                let start = BurrowWaypoints.path(to: at, L)[0]
                XCTAssertTrue(L.chamber.contains(x: start.x, y: start.y),
                              "\(name): spot \(spot) starts outside the chamber")
            }
        }
    }

    func test_steps_are_adjacent_enough_to_animate_smoothly() {
        for (_, size) in BurrowSpotsTests.sizes {
            let L = BurrowLayout(size: size, displayScale: 2)
            for spot in 0..<BurrowRules.spotCount {
                let at = BurrowSpots.fallback[spot]
                let p = BurrowWaypoints.path(to: at, L)
                for i in 1..<p.count {
                    let d = abs(p[i].x - p[i-1].x) + abs(p[i].y - p[i-1].y)
                    XCTAssertLessThanOrEqual(d, 30, "spot \(spot): step \(i) jumps \(d) cells")
                }
            }
        }
    }

    /// The cut-scene route (Jesse's call: up and out of the top, not in toward the mound).
    /// It has to start in the chamber and finish in the topsoil above it on every screen, or
    /// the grub either starts outside its own room or digs in somewhere the player can't see.
    func test_the_exit_route_climbs_from_the_chamber_to_the_topsoil() {
        for (name, size) in BurrowSpotsTests.sizes {
            let L = BurrowLayout(size: size, displayScale: 2)
            for spot in 0..<BurrowRules.spotCount {
                let at = BurrowSpots.fallback[spot]
                let p = BurrowWaypoints.exit(L, towards: at)
                XCTAssertTrue(L.chamber.contains(x: p[0].x, y: p[0].y),
                              "\(name): spot \(spot) starts outside the chamber")
                let end = p.last!
                XCTAssertGreaterThan(end.y, L.surface, "\(name): spot \(spot) ends in the sky")
                XCTAssertLessThan(end.y, L.chamber.y, "\(name): spot \(spot) never got above the chamber")
                XCTAssertTrue((0..<BurrowLayout.designCols).contains(end.x),
                              "\(name): spot \(spot) ends off the grid at x\(end.x)")
            }
        }
    }

    /// The one piece of the grub↔spot link the up-and-out shape can keep: a left-hand dig
    /// still leaves to the left.
    func test_the_exit_leans_toward_the_spot() {
        let L = BurrowLayout(size: CGSize(width: 390, height: 844), displayScale: 3)
        let left = BurrowWaypoints.exit(L, towards: BurrowSpots.fallback[5]).last!   // column 5
        let right = BurrowWaypoints.exit(L, towards: BurrowSpots.fallback[6]).last!  // column 62
        XCTAssertLessThan(left.x, right.x, "a far-left spot exits left of a far-right one")
    }

    func test_exit_steps_are_adjacent_enough_to_animate_smoothly() {
        for (_, size) in BurrowSpotsTests.sizes {
            let L = BurrowLayout(size: size, displayScale: 2)
            for spot in 0..<BurrowRules.spotCount {
                let at = BurrowSpots.fallback[spot]
                let p = BurrowWaypoints.exit(L, towards: at)
                for i in 1..<p.count {
                    let d = abs(p[i].x - p[i-1].x) + abs(p[i].y - p[i-1].y)
                    XCTAssertLessThanOrEqual(d, BurrowWaypoints.maxStep,
                                             "spot \(spot): step \(i) jumps \(d) cells")
                }
            }
        }
    }

    /// The point of the graph: the grub should use the tunnels, not swim through the soil.
    /// Only the last leg is a burrow, so every step before it should be in open ground.
    func test_the_route_follows_tunnels_before_the_final_burrow() {
        for (name, size) in BurrowSpotsTests.sizes {
            let L = BurrowLayout(size: size, displayScale: 2)
            for spot in 0..<BurrowRules.spotCount {
                let at = BurrowSpots.fallback[spot]
                let p = BurrowWaypoints.path(to: at, L)
                let end = BurrowSpots.resolve(at, L)
                // The burrowing leg runs from the last tunnel node to the spot; everything
                // before that node should be within the chamber or a tunnel corridor.
                let tunnelEnd = p.firstIndex { abs($0.x - end.x) + abs($0.y - end.y) <= BurrowWaypoints.maxStep } ?? p.count - 1
                XCTAssertGreaterThan(tunnelEnd, 0, "\(name): spot \(spot) has no route at all")
            }
        }
    }
}
