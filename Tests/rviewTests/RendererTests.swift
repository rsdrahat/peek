import XCTest
@testable import rview

/// Fixture-driven renderer tests. Each `Fixtures/*.md` has a sibling
/// `*.expected.html`. Set `RVIEW_UPDATE_FIXTURES=1` to regenerate expected files.
final class RendererTests: XCTestCase {
    func testAllFixtures() throws {
        let renderer = Renderer()
        let fixturesDir = Self.fixturesDirectory()
        let mdFiles = try FileManager.default
            .contentsOfDirectory(at: fixturesDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "md" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        XCTAssertGreaterThanOrEqual(mdFiles.count, 10,
            "Expected at least 10 fixtures, found \(mdFiles.count)")

        let update = ProcessInfo.processInfo.environment["RVIEW_UPDATE_FIXTURES"] == "1"

        for md in mdFiles {
            let source = try String(contentsOf: md, encoding: .utf8)
            let actual = renderer.html(from: source).trimmingCharacters(in: .whitespacesAndNewlines)
            let expectedURL = md.deletingPathExtension().appendingPathExtension("expected.html")

            if update || !FileManager.default.fileExists(atPath: expectedURL.path) {
                try (actual + "\n").write(to: expectedURL, atomically: true, encoding: .utf8)
                XCTFail("Wrote \(expectedURL.lastPathComponent). Re-run tests without RVIEW_UPDATE_FIXTURES.")
                continue
            }

            let expected = try String(contentsOf: expectedURL, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            XCTAssertEqual(actual, expected,
                "Fixture mismatch in \(md.lastPathComponent). " +
                "Set RVIEW_UPDATE_FIXTURES=1 if the change is intentional.")
        }
    }

    private static func fixturesDirectory(file: StaticString = #filePath) -> URL {
        URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
    }
}
