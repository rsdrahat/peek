import XCTest

/// Guards the Info.plist document-type declarations that govern how
/// Launch Services routes CLI args (`open -a peek <path>`) into the app.
/// Removing `public.folder` broke `peek .` in v0.3.3 — if that entry
/// disappears, this test should catch it before it ships.
final class InfoPlistTests: XCTestCase {
    func testDeclaresMarkdownAndFolderDocumentTypes() throws {
        let types = try loadContentTypes()
        XCTAssertTrue(types.contains("net.daringfireball.markdown"),
                      "markdown UTI missing — file args won't route through openFile:")
        XCTAssertTrue(types.contains("public.folder"),
                      "public.folder UTI missing — `open -a peek <dir>` will drop the arg (see v0.3.3 regression)")
    }

    private func loadContentTypes(file: StaticString = #filePath) throws -> Set<String> {
        let url = URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent()  // Tests/peekTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root
            .appendingPathComponent("Info.plist")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        guard
            let dict = plist as? [String: Any],
            let docTypes = dict["CFBundleDocumentTypes"] as? [[String: Any]]
        else {
            XCTFail("Info.plist at \(url.path) is missing CFBundleDocumentTypes")
            return []
        }
        return Set(docTypes.flatMap { ($0["LSItemContentTypes"] as? [String]) ?? [] })
    }
}
