import XCTest
@testable import rview

final class PreferencesTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: Pref.zoomKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: Pref.zoomKey)
        super.tearDown()
    }

    func testDefaultZoomWhenUnset() {
        XCTAssertEqual(Pref.zoom, Pref.defaultZoom)
    }

    func testZoomRoundtrips() {
        Pref.zoom = 1.4
        XCTAssertEqual(Pref.zoom, 1.4, accuracy: 0.0001)
    }

    func testZoomClampsAboveMax() {
        Pref.zoom = 10.0
        XCTAssertEqual(Pref.zoom, Pref.zoomMax, accuracy: 0.0001)
    }

    func testZoomClampsBelowMin() {
        Pref.zoom = 0.1
        XCTAssertEqual(Pref.zoom, Pref.zoomMin, accuracy: 0.0001)
    }
}
