import XCTest
@testable import GrubIOS

final class BurrowLayoutTests: XCTestCase {
    /// iPhone 13 and iPhone SE-sized layouts.
    let layouts = [BurrowLayout(size: CGSize(width: 390, height: 844), displayScale: 3),
                   BurrowLayout(size: CGSize(width: 375, height: 667), displayScale: 2)]

    func test_decor_slots_sit_on_their_room_floors() {
        for L in layouts {
            let rooms = [L.sideL, L.sideR, L.chamber, L.chamber]
            for i in 0..<BurrowRules.decorSlots {
                guard let p = L.decorSlot(i) else { return XCTFail("slot \(i)") }
                let r = rooms[i]
                XCTAssertTrue(p.x - 3 >= r.x && p.x + 2 < r.maxX, "slot \(i) x inside its room")
                XCTAssertEqual(p.y, r.maxY - 2, "slot \(i) pedestal on the floor")
            }
            XCTAssertNil(L.decorSlot(BurrowRules.decorSlots))
        }
    }

    func test_chamber_slots_clear_the_grub() {
        for L in layouts {
            let grubX0 = L.chamber.midX - GrubArt.width / 2
            let grubX1 = grubX0 + GrubArt.width - 1
            for i in [2, 3] {
                let p = L.decorSlot(i)!
                XCTAssertTrue(p.x + 2 < grubX0 || p.x - 3 > grubX1, "slot \(i) pedestal x\(p.x - 3)–\(p.x + 2) vs grub x\(grubX0)–\(grubX1)")
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
