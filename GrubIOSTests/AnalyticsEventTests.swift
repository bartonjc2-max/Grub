import XCTest
@testable import GrubIOS

final class AnalyticsEventTests: XCTestCase {
    func test_appOpen_name_and_props() {
        let e = AnalyticsEvent.appOpen(isFirstOpen: true)
        XCTAssertEqual(e.name, "app_open")
        XCTAssertEqual(e.properties["is_first_open"] as? Bool, true)
    }

    func test_homeAction_carries_type() {
        let e = AnalyticsEvent.homeAction(type: "feed")
        XCTAssertEqual(e.name, "home_action")
        XCTAssertEqual(e.properties["type"] as? String, "feed")
    }

    func test_adShown_props() {
        let e = AnalyticsEvent.adShown(placement: "second_wind", optedIn: true, completed: false)
        XCTAssertEqual(e.name, "ad_shown")
        XCTAssertEqual(e.properties["placement"] as? String, "second_wind")
        XCTAssertEqual(e.properties["opted_in"] as? Bool, true)
        XCTAssertEqual(e.properties["completed"] as? Bool, false)
    }
}
