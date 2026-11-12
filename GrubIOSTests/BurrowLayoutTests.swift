import XCTest
@testable import GrubIOS

final class BurrowLayoutTests: XCTestCase {
    /// iPhone 13 and iPhone SE-sized layouts.
    let layouts = [BurrowLayout(size: CGSize(width: 390, height: 844), displayScale: 3),
                   BurrowLayout(size: CGSize(width: 375, height: 667), displayScale: 2)]

    /// Decor and the collection moved off the burrow onto their own page. Both now live in
    /// the gallery — a room built for them — rather than scattered round the chamber floor
    /// and two side rooms that between them could show three specimens.
    func test_decor_niches_sit_in_the_gallery() {
        for L in layouts {
            let g = L.gallery
            for i in 0..<BurrowRules.decorSlots {
                guard let p = L.decorSlot(i) else { return XCTFail("slot \(i)") }
                XCTAssertTrue(L.decorIsShelf(i), "slot \(i) hangs on the gallery wall")
                // The alcove behind a niche is 11 wide and 12 tall, cut into the back wall.
                XCTAssertTrue(p.x - 5 >= g.x && p.x + 5 < g.maxX, "slot \(i) alcove inside the gallery")
                XCTAssertTrue(p.y - 10 > g.y && p.y + 2 < g.maxY, "slot \(i) alcove inside vertically")
            }
            // Evenly spaced and in order, or the row reads as four accidents.
            let xs = (0..<BurrowRules.decorSlots).map { L.decorSlot($0)!.x }
            XCTAssertEqual(xs, xs.sorted(), "niches run left to right")
            let gaps = Set(zip(xs, xs.dropFirst()).map { $1 - $0 })
            XCTAssertEqual(gaps.count, 1, "evenly spaced, got gaps \(gaps)")
            XCTAssertNil(L.decorSlot(BurrowRules.decorSlots))
        }
    }

    /// The gallery ledge has to hold its busts inside the room, and show more of them than
    /// the side rooms it replaced — three between the two of them was the whole problem.
    func test_the_specimen_ledge_fits_the_gallery() {
        for size in [CGSize(width: 375, height: 667), CGSize(width: 390, height: 844),
                     CGSize(width: 430, height: 932), CGSize(width: 834, height: 1194)] {
            let L = BurrowLayout(size: size, displayScale: 2)
            let g = L.gallery, s = L.shelf, n = L.shelfSlots
            XCTAssertTrue(s.x0 >= g.x && s.x0 + s.width <= g.maxX, "\(size): ledge inside the gallery")
            XCTAssertTrue(s.y > g.y && s.y < g.maxY, "\(size): ledge inside vertically")
            XCTAssertGreaterThanOrEqual(n, 6, "\(size): the gallery shows a collection, not a shelf")
            let bust = IconArt.specimen(.grub)
            XCTAssertLessThanOrEqual(s.x0 + (n - 1) * 6 + bust.width, g.maxX,
                                     "\(size): the last bust fits")
            XCTAssertGreaterThanOrEqual(s.y - bust.height, g.y, "\(size): busts stay under the ceiling")
            // And the ledge must clear the alcoves above it, or busts stand inside the decor.
            let niche = L.decorSlot(0)!
            XCTAssertGreaterThan(s.y - bust.height, niche.y + 2, "\(size): ledge clears the alcoves")
        }
    }

    /// The gallery is a room, not a stretched panel: it stays clear of the HUD and keeps a
    /// fixed height rather than filling whatever is left, which left a dead middle.
    func test_the_gallery_is_a_room_not_a_panel() {
        for size in [CGSize(width: 375, height: 667), CGSize(width: 430, height: 932),
                     CGSize(width: 834, height: 1194)] {
            let L = BurrowLayout(size: size, displayScale: 2)
            XCTAssertLessThanOrEqual(L.gallery.maxY, L.hudTopRow, "\(size): gallery runs under the HUD")
            XCTAssertGreaterThan(L.gallery.y, 0, "\(size): gallery starts off-screen")
            XCTAssertLessThanOrEqual(L.gallery.h, 44, "\(size): gallery stretched")
        }
    }

    /// Two spots sit within half a mound of the screen edge. The mound clamps so it is never
    /// sliced by the bezel — the dome and its cast shadow are the whole affordance.
    func test_dig_mounds_stay_whole_on_screen() {
        for size in [CGSize(width: 375, height: 667),
                     CGSize(width: 393, height: 852),
                     CGSize(width: 430, height: 932),
                     CGSize(width: 834, height: 1194)] {
            let L = BurrowLayout(size: size, displayScale: 2)
            let w = MarkerArt.mound.width
            for spot in 0..<BurrowRules.spotCount {
                let c = BurrowSpots.markerCentre(spot, L, width: w)
                XCTAssertGreaterThanOrEqual(c - Double(w) / 2, 0, "\(size) spot \(spot): mound off the left")
                XCTAssertLessThanOrEqual(c + Double(w) / 2, Double(BurrowLayout.designCols),
                                         "\(size) spot \(spot): mound off the right")
                // The clamp is art-only: it never drags a mound off its own spot by more than
                // half its width, or the marker would stop pointing at the thing it digs.
                let dx = abs(c - (Double(BurrowSpots.resolve(spot, L).x) + 0.5))
                XCTAssertLessThanOrEqual(dx, Double(w) / 2, "\(size) spot \(spot): mound drifted off its spot")
            }
        }
    }

    func test_every_adult_fits_the_chamber() {
        for L in layouts {
            for sp in Species.allCases {
                let spr = SpeciesArt.adult(sp)
                XCTAssertLessThanOrEqual(spr.width, L.chamber.w, "\(sp) width")
                XCTAssertLessThanOrEqual(spr.height, L.chamber.h, "\(sp) height")
            }
        }
        XCTAssertEqual(SpeciesArt.adult(.grub).width, GrubArt.width, "GRUB's adult is the larva sprite")
        XCTAssertEqual(SpeciesArt.adult(.claws).width, 36)
        XCTAssertEqual(SpeciesArt.adult(.horn).height, 28)
    }

    func test_soil_bands_split_the_soil_and_stay_ordered() {
        for size in [CGSize(width: 375, height: 667),    // SE
                     CGSize(width: 393, height: 852),    // 15
                     CGSize(width: 430, height: 932),    // 15 Pro Max
                     CGSize(width: 834, height: 1194)] { // iPad Pro 11"
            let L = BurrowLayout(size: size, displayScale: 2)
            let b = L.soilBands
            XCTAssertGreaterThan(b.b1, L.surface, "\(size): band 1 starts below the surface")
            XCTAssertLessThan(b.b1, b.b2, "\(size)")
            XCTAssertLessThan(b.b2, b.b3, "\(size)")
            XCTAssertLessThan(b.b3, L.rows, "\(size): band 4 has room")
        }
    }
}
