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
