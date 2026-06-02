import XCTest
import SwiftUI
@testable import GrubIOS

@MainActor
final class AtmosphereSplitTests: XCTestCase {
    // Compile-level guarantee that the split functions exist with the right
    // signature and run without trapping on a real GraphicsContext.
    func test_atmosphere_and_structure_render_without_crash() {
        let size = CGSize(width: 180, height: 388)
        let renderer = ImageRenderer(content: Canvas { ctx, sz in
            SpriteRenderer.drawStructure(context: &ctx, size: sz, tick: 0)
            SpriteRenderer.drawAtmosphere(context: &ctx, size: sz, tick: 0)
            SpriteRenderer.drawBackground(context: &ctx, size: sz, tick: 0)
        }.frame(width: size.width, height: size.height))
        XCTAssertNotNil(renderer.uiImage, "split renderers should produce an image")
    }
}
