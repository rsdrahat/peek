import XCTest
@testable import rview

final class ScrollStoreTests: XCTestCase {
    func testKeyIsStableForSamePath() {
        let a = URL(fileURLWithPath: "/tmp/doc.md")
        let b = URL(fileURLWithPath: "/tmp/doc.md")
        XCTAssertEqual(ScrollStore.key(a), ScrollStore.key(b))
    }

    func testKeyDiffersForDifferentPaths() {
        let a = URL(fileURLWithPath: "/tmp/a.md")
        let b = URL(fileURLWithPath: "/tmp/b.md")
        XCTAssertNotEqual(ScrollStore.key(a), ScrollStore.key(b))
    }

    func testKeyNormalizesStandardizedPaths() {
        let a = URL(fileURLWithPath: "/tmp/./doc.md")
        let b = URL(fileURLWithPath: "/tmp/doc.md")
        XCTAssertEqual(ScrollStore.key(a), ScrollStore.key(b))
    }

    func testRoundtripInMemory() async {
        let store = ScrollStore.shared
        let url = URL(fileURLWithPath: "/tmp/rview-scroll-test-\(UUID().uuidString).md")
        await store.setScrollY(1234.5, for: url)
        let y = await store.scrollY(for: url)
        XCTAssertEqual(y, 1234.5, accuracy: 0.0001)
    }
}
