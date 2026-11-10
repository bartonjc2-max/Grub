import XCTest
@testable import GrubIOS

final class BurrowArtTests: XCTestCase {
    func test_mix_and_scale() {
        XCTAssertEqual(GrubArt.mix(0x000000, 0xffffff, 0.25), 0x404040)
        XCTAssertEqual(GrubArt.scale(0x646464, 0.5), 0x323232)
    }

    func test_tint_is_a_quarter_of_the_parent_colour() {
        XCTAssertEqual(GrubArt.bodyColor(tint: nil), BurrowInk.teal)
        XCTAssertEqual(GrubArt.bodyColor(tint: .grub), BurrowInk.teal)
        // teal 4e cc a3 → horn 8f 6f e0 at 25 %: 5e b5 b2
        XCTAssertEqual(GrubArt.bodyColor(tint: .horn), 0x5eb5b2)
    }

    func test_tinted_frames_keep_the_larva_shape() {
        let plain = GrubArt.frames(tint: nil), horn = GrubArt.frames(tint: .horn)
        XCTAssertEqual(horn.idle.width, plain.idle.width)
        XCTAssertEqual(horn.idle.height, plain.idle.height)
        XCTAssertNotEqual(horn.idle.data, plain.idle.data)
        XCTAssertEqual(plain.idle.data, GrubArt.idle.data, "untinted frames are the original art")
    }

    func test_egg_cracks_add_pixels() {
        let e0 = SpeciesArt.egg(cracks: 0, tint: nil), e3 = SpeciesArt.egg(cracks: 3, tint: nil)
        XCTAssertEqual(e0.width, 15); XCTAssertEqual(e0.height, 18)
        XCTAssertNotEqual(e0.data, e3.data)
    }
}
