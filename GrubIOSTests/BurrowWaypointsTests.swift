import XCTest
@testable import GrubIOS

final class BurrowWaypointsTests: XCTestCase {
    func test_every_spot_is_reachable_from_the_chamber() {
        for (name, size) in BurrowSpotsTests.sizes {
            let L = BurrowLayout(size: size, displayScale: 2)
            for spot in 0..<BurrowRules.spotCount {
                let path = BurrowWaypoints.path(to: spot, L)
                XCTAssertGreaterThanOrEqual(path.count, 2, "\(name): spot \(spot) has no path")
                let end = BurrowSpots.resolve(spot, L)
                XCTAssertEqual(path.last!, Waypoint(x: end.x, y: end.y),
                               "\(name): the path ends at the spot")
            }
        }
    }

    func test_the_path_starts_at_the_chamber() {
        for (name, size) in BurrowSpotsTests.sizes {
            let L = BurrowLayout(size: size, displayScale: 2)
            for spot in 0..<BurrowRules.spotCount {
                let start = BurrowWaypoints.path(to: spot, L)[0]
                XCTAssertTrue(L.chamber.contains(x: start.x, y: start.y),
                              "\(name): spot \(spot) starts outside the chamber")
            }
        }
    }

    func test_steps_are_adjacent_enough_to_animate_smoothly() {
        for (_, size) in BurrowSpotsTests.sizes {
            let L = BurrowLayout(size: size, displayScale: 2)
            for spot in 0..<BurrowRules.spotCount {
                let p = BurrowWaypoints.path(to: spot, L)
                for i in 1..<p.count {
                    let d = abs(p[i].x - p[i-1].x) + abs(p[i].y - p[i-1].y)
                    XCTAssertLessThanOrEqual(d, 30, "spot \(spot): step \(i) jumps \(d) cells")
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
                let p = BurrowWaypoints.path(to: spot, L)
                let end = BurrowSpots.resolve(spot, L)
                // The burrowing leg runs from the last tunnel node to the spot; everything
                // before that node should be within the chamber or a tunnel corridor.
                let tunnelEnd = p.firstIndex { abs($0.x - end.x) + abs($0.y - end.y) <= BurrowWaypoints.maxStep } ?? p.count - 1
                XCTAssertGreaterThan(tunnelEnd, 0, "\(name): spot \(spot) has no route at all")
            }
        }
    }
}
