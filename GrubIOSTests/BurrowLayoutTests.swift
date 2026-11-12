import XCTest
@testable import GrubIOS

final class BurrowLayoutTests: XCTestCase {
    /// iPhone 13 and iPhone SE-sized layouts.
    let layouts = [BurrowLayout(size: CGSize(width: 390, height: 844), displayScale: 3),
                   BurrowLayout(size: CGSize(width: 375, height: 667), displayScale: 2)]

    /// All four decor slots live in the chamber now — 0 and 1 standing on the floor either
    /// side of the grub, 2 and 3 on the walls above them. The side rooms hold the specimen
    /// shelf instead, so nothing here looks at them any more.
    func test_decor_slots_sit_in_the_chamber() {
        for L in layouts {
            let c = L.chamber
            for i in 0..<BurrowRules.decorSlots {
                guard let p = L.decorSlot(i) else { return XCTFail("slot \(i)") }
                XCTAssertTrue(p.x - 3 >= c.x && p.x + 2 < c.maxX, "slot \(i) plinth inside the chamber")
                XCTAssertTrue(p.y > c.y && p.y < c.maxY, "slot \(i) y inside the chamber")
            }
            for i in [0, 1] {
                XCTAssertFalse(L.decorIsShelf(i), "slot \(i) stands on the floor")
                XCTAssertEqual(L.decorSlot(i)!.y + IconArt.pedestalDim.height - 1, c.maxY - 1,
                               "slot \(i) plinth stands on the chamber floor")
            }
            for i in [2, 3] {
                XCTAssertTrue(L.decorIsShelf(i), "slot \(i) hangs on the wall")
                // The niche behind a slot is 9 rows tall; the wall pair must clear the floor
                // pair's niche or the two read as one smear up the chamber wall.
                XCTAssertLessThan(L.decorSlot(i)!.y + 9, L.decorSlot(0)!.y - 9,
                                  "slot \(i) clears the floor pair")
            }
            XCTAssertNil(L.decorSlot(BurrowRules.decorSlots))
        }
    }

    /// Now that every slot is in the chamber, every slot has to miss the larva — not just the
    /// two that used to be there.
    func test_chamber_slots_clear_the_grub() {
        for L in layouts {
            let grubX0 = L.chamber.midX - GrubArt.width / 2
            let grubX1 = grubX0 + GrubArt.width - 1
            for i in 0..<BurrowRules.decorSlots {
                let p = L.decorSlot(i)!
                XCTAssertTrue(p.x + 2 < grubX0 || p.x - 3 > grubX1, "slot \(i) plinth x\(p.x - 3)–\(p.x + 2) vs grub x\(grubX0)–\(grubX1)")
            }
        }
    }

    /// The specimen shelf replaced the two side-room decor slots. A ledge that runs off the
    /// end of its room, or a bust that pokes through the ceiling, would put the collection
    /// half inside solid soil.
    func test_the_specimen_shelf_fits_its_side_rooms() {
        for L in layouts {
            for (name, room) in [("sideL", L.sideL), ("sideR", L.sideR)] {
                let s = L.shelf(room)
                XCTAssertTrue(s.x0 >= room.x && s.x0 + s.width <= room.maxX, "\(name): ledge inside the room")
                XCTAssertTrue(s.y > room.y && s.y < room.maxY, "\(name): ledge inside the room vertically")
                let n = L.shelfSlots(room)
                XCTAssertGreaterThanOrEqual(n, 1, "\(name): shows at least one specimen")
                let bust = IconArt.specimen(.grub)
                XCTAssertLessThanOrEqual(s.x0 + (n - 1) * 6 + bust.width, room.maxX,
                                         "\(name): the last bust fits the room")
                XCTAssertGreaterThanOrEqual(s.y - bust.height, room.y,
                                            "\(name): a bust on the ledge stays under the ceiling")
            }
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
