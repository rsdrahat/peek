import XCTest
@testable import peek

@MainActor
final class RecentFilesStoreTests: XCTestCase {
    private func makeStore() -> RecentFilesStore {
        let suite = "peek.recents.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return RecentFilesStore(defaults: defaults)
    }

    func testStartsEmpty() {
        XCTAssertTrue(makeStore().all().isEmpty)
    }

    func testAddPutsMostRecentFirst() {
        let store = makeStore()
        store.add(URL(fileURLWithPath: "/tmp/a.md"))
        store.add(URL(fileURLWithPath: "/tmp/b.md"))
        XCTAssertEqual(store.all().map(\.lastPathComponent), ["b.md", "a.md"])
    }

    func testAddDedupesAndMovesToFront() {
        let store = makeStore()
        store.add(URL(fileURLWithPath: "/tmp/a.md"))
        store.add(URL(fileURLWithPath: "/tmp/b.md"))
        store.add(URL(fileURLWithPath: "/tmp/a.md"))
        XCTAssertEqual(store.all().map(\.lastPathComponent), ["a.md", "b.md"])
        XCTAssertEqual(store.all().count, 2)
    }

    func testCapsAtTen() {
        let store = makeStore()
        for i in 0..<15 {
            store.add(URL(fileURLWithPath: "/tmp/file\(i).md"))
        }
        let all = store.all()
        XCTAssertEqual(all.count, 10)
        XCTAssertEqual(all.first?.lastPathComponent, "file14.md")
        XCTAssertEqual(all.last?.lastPathComponent, "file5.md")
    }

    func testClearEmptiesAndPersists() {
        let store = makeStore()
        store.add(URL(fileURLWithPath: "/tmp/a.md"))
        store.clear()
        XCTAssertTrue(store.all().isEmpty)
    }

    func testPersistsAcrossInstances() {
        let suite = "peek.recents.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let s1 = RecentFilesStore(defaults: defaults)
        s1.add(URL(fileURLWithPath: "/tmp/persist.md"))

        let s2 = RecentFilesStore(defaults: defaults)
        XCTAssertEqual(s2.all().map(\.lastPathComponent), ["persist.md"])
    }

    func testExistingPrunesMissingFiles() {
        let store = makeStore()
        let real = FileManager.default.temporaryDirectory.appendingPathComponent("recent-real-\(UUID().uuidString).md")
        try? "x".write(to: real, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: real) }

        store.add(URL(fileURLWithPath: "/tmp/definitely-missing-\(UUID().uuidString).md"))
        store.add(real)

        let alive = store.existing()
        XCTAssertEqual(alive.map(\.lastPathComponent), [real.lastPathComponent])
        XCTAssertEqual(store.all().count, 1)
    }
}
