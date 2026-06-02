import XCTest
import SwiftUI
@testable import GrubIOS

@MainActor
final class DescentSceneSmokeTests: XCTestCase {
    func test_scene_renders_without_crash() {
        let engine = DescentEngine(layout: DescentEngine.prototypeRoom)
        let renderer = ImageRenderer(content:
            DescentSceneView(engine: engine)
                .frame(width: 330, height: 450)
        )
        XCTAssertNotNil(renderer.uiImage, "scene should render to an image")
    }

    // The shipped room is hand-authored — guard the floor-1-passable invariant
    // so a future edit can't accidentally wall off the stairs.
    func test_prototype_room_is_passable_without_combat() {
        let engine = DescentEngine(layout: DescentEngine.prototypeRoom)
        XCTAssertTrue(engine.hasStaticPathToStairs())
    }
}
