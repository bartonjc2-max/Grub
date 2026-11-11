import XCTest
@testable import GrubIOS

final class BurrowSpotsTests: XCTestCase {
    static let sizes: [(String, CGSize)] = [
        ("SE", CGSize(width: 375, height: 667)),
        ("15", CGSize(width: 393, height: 852)),
        ("15 Pro Max", CGSize(width: 430, height: 932)),
        ("iPad Pro 11", CGSize(width: 834, height: 1194)),
    ]

    func test_every_spot_sits_in_its_layers_band() {
        for (name, size) in Self.sizes {
            let L = BurrowLayout(size: size, displayScale: 2)
            for spot in 0..<BurrowRules.spotCount {
                let layer = BurrowSpots.layer(spot)
                let p = BurrowSpots.resolve(spot, L)
                XCTAssertTrue(L.rows(for: layer).contains(p.y),
                              "\(name): spot \(spot) (\(layer)) at row \(p.y), band \(L.rows(for: layer))")
            }
        }
    }

    func test_no_spot_lands_inside_a_room() {
        for (name, size) in Self.sizes {
            let L = BurrowLayout(size: size, displayScale: 2)
            for spot in 0..<BurrowRules.spotCount {
                let p = BurrowSpots.resolve(spot, L)
                for (room, label) in [(L.chamber, "chamber"), (L.sideL, "left room"), (L.sideR, "right room")] {
                    XCTAssertFalse(room.contains(x: p.x, y: p.y),
                                   "\(name): spot \(spot) is inside the \(label)")
                }
            }
        }
    }

    func test_spots_do_not_overlap_each_other() {
        for (name, size) in Self.sizes {
            let L = BurrowLayout(size: size, displayScale: 2)
            let points = (0..<BurrowRules.spotCount).map { BurrowSpots.resolve($0, L) }
            for i in points.indices {
                for j in points.indices where j > i {
                    let d = abs(points[i].x - points[j].x) + abs(points[i].y - points[j].y)
                    XCTAssertGreaterThan(d, 4, "\(name): spots \(i) and \(j) are on top of each other")
                }
            }
        }
    }

    /// Not in the plan, found while placing the deep spots: the soil bands run to the bottom of
    /// the screen, so the deep band's lower rows are behind the bottom panel. A spot there is
    /// invisible and untappable — on the SE that rules out roughly the bottom half of the band.
    func test_no_spot_hides_behind_the_bottom_panel() {
        for (name, size) in Self.sizes {
            let L = BurrowLayout(size: size, displayScale: 2)
            for spot in 0..<BurrowRules.spotCount {
                let p = BurrowSpots.resolve(spot, L)
                XCTAssertLessThan(p.y + 1, L.hudTopRow,
                                  "\(name): spot \(spot) at row \(p.y) is under the panel (from \(L.hudTopRow))")
            }
        }
    }

    func test_layer_assignment_matches_the_spec() {
        XCTAssertEqual((0..<8).map(BurrowSpots.layer),
                       [.clay, .loose, .loose, .deep, .loose, .clay, .clay, .deep])
    }
}
