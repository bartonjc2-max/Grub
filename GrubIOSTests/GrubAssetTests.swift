import XCTest
import UIKit
@testable import GrubIOS

/// Confirms the 8-direction hero PNGs + canonical asset all resolve from the
/// app bundle. If any asset is missing, `Image("grub_S")` etc. would render
/// blank in production — these tests fail loudly instead.
final class GrubAssetTests: XCTestCase {
    func test_all_eight_directional_sprites_resolve() {
        let bundle = Bundle(for: GrubAssetTests.self)
        // Tests run in the test bundle; assets live in the host app bundle.
        let appBundle = Bundle(identifier: "com.jessedev.GrubIOS") ?? bundle
        for dir in SpriteRenderer.Direction8.allCases {
            let name = dir.assetName
            let img = UIImage(named: name, in: appBundle, with: nil)
                  ?? UIImage(named: name)
            XCTAssertNotNil(img, "asset \(name) not found in bundle")
        }
    }

    func test_canonical_sprite_resolves() {
        let appBundle = Bundle(identifier: "com.jessedev.GrubIOS") ?? Bundle(for: GrubAssetTests.self)
        let img = UIImage(named: SpriteRenderer.canonicalAssetName, in: appBundle, with: nil)
              ?? UIImage(named: SpriteRenderer.canonicalAssetName)
        XCTAssertNotNil(img, "grub_canon not found in bundle")
    }

    func test_blink_frame_resolves() {
        let appBundle = Bundle(identifier: "com.jessedev.GrubIOS") ?? Bundle(for: GrubAssetTests.self)
        let img = UIImage(named: "grub_S_blink", in: appBundle, with: nil)
              ?? UIImage(named: "grub_S_blink")
        XCTAssertNotNil(img, "grub_S_blink not found in bundle — the blink animation will silently fall back to nothing")
    }

    func test_eat_frame_resolves() {
        let appBundle = Bundle(identifier: "com.jessedev.GrubIOS") ?? Bundle(for: GrubAssetTests.self)
        let img = UIImage(named: "grub_S_eat", in: appBundle, with: nil)
              ?? UIImage(named: "grub_S_eat")
        XCTAssertNotNil(img, "grub_S_eat not found in bundle — eating animation will fall back to procedural")
    }

    func test_cave_home_resolves() {
        let appBundle = Bundle(identifier: "com.jessedev.GrubIOS") ?? Bundle(for: GrubAssetTests.self)
        let img = UIImage(named: "cave_home", in: appBundle, with: nil) ?? UIImage(named: "cave_home")
        XCTAssertNotNil(img, "cave_home backdrop not found in bundle")
    }

    func test_ui_stat_icons_resolve() {
        // PixelLab-generated stat icons (heart/drumstick/star) for HP/HNG/HAP.
        let appBundle = Bundle(identifier: "com.jessedev.GrubIOS") ?? Bundle(for: GrubAssetTests.self)
        let icons = ["ui_icon_heart", "ui_icon_drumstick", "ui_icon_star"]
        var missing: [String] = []
        for name in icons {
            let img = UIImage(named: name, in: appBundle, with: nil) ?? UIImage(named: name)
            if img == nil { missing.append(name) }
        }
        XCTAssertTrue(missing.isEmpty,
                      "missing UI stat icons (stat rows fall back to text labels): \(missing)")
    }

    func test_all_pet_state_pngs_resolve() {
        // 6 state variants from PixelLab (sad/sick/starving/angry/dying/dead),
        // all derived from canonical 1e12a98f via create_character_state.
        let appBundle = Bundle(identifier: "com.jessedev.GrubIOS") ?? Bundle(for: GrubAssetTests.self)
        let states = ["sad", "sick", "starving", "angry", "dying", "dead"]
        var missing: [String] = []
        for s in states {
            let name = "grub_S_\(s)"
            let img = UIImage(named: name, in: appBundle, with: nil) ?? UIImage(named: name)
            if img == nil { missing.append(name) }
        }
        XCTAssertTrue(missing.isEmpty,
                      "missing pet-state PNGs (will fall back to procedural): \(missing)")
    }

    func test_all_walk_frames_resolve() {
        // 8 directions × 4 frames each = 32 walk frames for Descent walking.
        let appBundle = Bundle(identifier: "com.jessedev.GrubIOS") ?? Bundle(for: GrubAssetTests.self)
        let dirs = SpriteRenderer.Direction8.allCases
        var missing: [String] = []
        for d in dirs {
            for f in 0..<4 {
                let name = "grub_\(d.rawValue)_walk_\(f)"
                let img = UIImage(named: name, in: appBundle, with: nil) ?? UIImage(named: name)
                if img == nil { missing.append(name) }
            }
        }
        XCTAssertTrue(missing.isEmpty, "missing walk frames: \(missing)")
    }
}
