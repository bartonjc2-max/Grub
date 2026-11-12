import XCTest
@testable import GrubIOS

/// The dig sites used to be a frozen table and these tests checked its eight hand-placed
/// entries. They move now — re-rolled every time a site comes back into play — so there is no
/// table to check. What is left is the set of properties any generated map has to have, tested
/// over many seeds rather than over one layout.
final class BurrowSpotsTests: XCTestCase {
    static let sizes: [(String, CGSize)] = [
        ("SE", CGSize(width: 375, height: 667)),
        ("15", CGSize(width: 393, height: 852)),
        ("15 Pro Max", CGSize(width: 430, height: 932)),
        ("iPad Pro 11", CGSize(width: 834, height: 1194)),
    ]

    /// Every map the generator can produce, not just the one that ships.
    private func maps(_ count: Int = 40) -> [[SpotPlacement]] {
        (0..<count).map { seed in
            var rng = BurrowRNG(seed: UInt64(seed) &* 0x9E37_79B9 &+ 1)
            return BurrowSpots.generate(rng: &rng)
        }
    }

    func test_a_generated_map_has_the_right_shape() {
        for map in maps() {
            XCTAssertEqual(map.count, BurrowRules.spotCount)
            for (layer, want) in BurrowSpots.perLayer {
                XCTAssertEqual(map.filter { $0.layer == layer }.count, want,
                               "\(layer) count in \(map.map(\.x))")
            }
            for p in map {
                XCTAssertTrue(BurrowSpots.xRange.contains(p.x), "x \(p.x) outside the band")
                XCTAssertTrue((0.1...0.9).contains(p.t), "t \(p.t) at the very edge of its band")
            }
        }
    }

    func test_sites_in_the_same_band_never_touch() {
        for map in maps() {
            for (layer, _) in BurrowSpots.perLayer {
                let xs = map.filter { $0.layer == layer }.map(\.x).sorted()
                for (a, b) in zip(xs, xs.dropFirst()) {
                    XCTAssertGreaterThanOrEqual(b - a, BurrowSpots.minGap,
                                                "\(layer): \(a) and \(b) are \(b - a) apart")
                }
            }
        }
    }

    func test_every_site_sits_in_its_bands_rows_on_every_screen() {
        for (name, size) in Self.sizes {
            let L = BurrowLayout(size: size, displayScale: 2)
            for map in maps(12) {
                for p in map {
                    let y = BurrowSpots.resolve(p, L).y
                    XCTAssertTrue(L.rows(for: p.layer).contains(y),
                                  "\(name): \(p.layer) at row \(y), band \(L.rows(for: p.layer))")
                }
            }
        }
    }

    /// The soil bands run to the bottom of the screen, so the deep band's lower rows sit
    /// behind the HUD. A site there can be neither seen nor tapped — on the SE that rules out
    /// roughly the bottom half of the band, which is why `resolve` clamps rather than trusting
    /// the generator.
    func test_no_site_hides_behind_the_bottom_panel() {
        for (name, size) in Self.sizes {
            let L = BurrowLayout(size: size, displayScale: 2)
            for map in maps(12) {
                for p in map {
                    XCTAssertLessThan(BurrowSpots.resolve(p, L).y + 1, L.hudTopRow,
                                      "\(name): \(p) is under the panel (from \(L.hudTopRow))")
                }
            }
        }
    }

    func test_no_mound_is_sliced_by_the_bezel() {
        let w = MarkerArt.siteWidth, half = Double(w) / 2
        for (name, size) in Self.sizes {
            let L = BurrowLayout(size: size, displayScale: 2)
            for map in maps(12) {
                for p in map {
                    let c = BurrowSpots.markerCentre(p, L, width: w)
                    XCTAssertGreaterThanOrEqual(c - half, 0, "\(name): \(p) off the left")
                    XCTAssertLessThanOrEqual(c + half, Double(BurrowLayout.designCols),
                                             "\(name): \(p) off the right")
                }
            }
        }
    }

    // MARK: moving

    /// The point of the whole change: a site that comes back into play is somewhere else.
    func test_rerolling_actually_moves_a_site() {
        var rng = BurrowRNG(seed: 99)
        var map = BurrowSpots.generate(rng: &rng)
        var seen: Set<String> = []
        for _ in 0..<40 {
            BurrowSpots.reroll(0, in: &map, rng: &rng)
            seen.insert("\(map[0].x)/\(map[0].layer)/\(map[0].t)")
        }
        XCTAssertGreaterThan(seen.count, 20, "a re-rolled site barely moved: \(seen.count) of 40")
        // And it can change band, which is what keeps the soil face from settling into a shape.
        let bands = Set(seen.map { $0.split(separator: "/")[1] })
        XCTAssertGreaterThan(bands.count, 1, "it never left its own layer")
    }

    /// A re-rolled site still has to obey the screen, on every screen.
    func test_a_rerolled_site_still_fits_every_screen() {
        var rng = BurrowRNG(seed: 7)
        var map = BurrowSpots.generate(rng: &rng)
        for step in 0..<60 {
            let spot = step % BurrowRules.spotCount
            BurrowSpots.reroll(spot, in: &map, rng: &rng)
            let p = map[spot]
            XCTAssertTrue(BurrowSpots.xRange.contains(p.x), "step \(step): x \(p.x)")
            for (name, size) in Self.sizes {
                let L = BurrowLayout(size: size, displayScale: 2)
                let y = BurrowSpots.resolve(p, L).y
                XCTAssertTrue(L.rows(for: p.layer).contains(y), "\(name) step \(step): row \(y)")
                XCTAssertLessThan(y + 1, L.hudTopRow, "\(name) step \(step): under the panel")
            }
        }
    }

    /// The 3 / 3 / 2 mix is the food/decor balance and the difficulty curve — 67.5 % food
    /// overall, tuned against the stat pacing. Re-rolling a site's band freely let that
    /// random-walk (four clay and one deep, a few moves in), so a band is traded, never
    /// invented. This is the test that catches it coming back.
    func test_the_band_mix_survives_any_number_of_moves() {
        var rng = BurrowRNG(seed: 4242)
        var map = BurrowSpots.generate(rng: &rng)
        for step in 0..<400 {
            BurrowSpots.reroll(step % BurrowRules.spotCount, in: &map, rng: &rng)
            for (layer, want) in BurrowSpots.perLayer {
                XCTAssertEqual(map.filter { $0.layer == layer }.count, want,
                               "step \(step): \(layer) drifted to \(map.filter { $0.layer == layer }.count)")
            }
        }
    }

    /// The map that a save written before sites could move is treated as having. It is the
    /// table the game shipped with, so an existing burrow looks unchanged on the update.
    func test_the_fallback_map_is_the_old_shipped_table() {
        XCTAssertEqual(BurrowSpots.fallback.count, BurrowRules.spotCount)
        XCTAssertEqual(BurrowSpots.fallback.map(\.layer),
                       [.clay, .loose, .loose, .deep, .loose, .clay, .clay, .deep])
    }
}
