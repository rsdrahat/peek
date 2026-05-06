import XCTest
@testable import peek

final class DefaultHandlerTests: XCTestCase {
    func testMarkdownUTIsIncludeDaringfireball() {
        XCTAssertTrue(DefaultHandler.markdownUTIs.contains("net.daringfireball.markdown"))
    }

    func testMarkdownUTIsDoesNotClaimPlainText() {
        // Claiming public.plain-text would steal default for every .txt and
        // unknown text file too — too aggressive. Keep it markdown-only.
        XCTAssertFalse(DefaultHandler.markdownUTIs.contains("public.plain-text"))
    }

    func testBundleIdentifierIsKnown() {
        // In tests, Bundle.main is the test runner; the fallback kicks in.
        // Either way, we always have *some* identifier to hand to LSSet…
        XCTAssertFalse(DefaultHandler.bundleIdentifier.isEmpty)
    }

    func testPrefAskedDefaultHandlerRoundtrips() {
        let original = Pref.askedDefaultHandler
        defer { Pref.askedDefaultHandler = original }

        Pref.askedDefaultHandler = false
        XCTAssertFalse(Pref.askedDefaultHandler)
        Pref.askedDefaultHandler = true
        XCTAssertTrue(Pref.askedDefaultHandler)
    }
}
