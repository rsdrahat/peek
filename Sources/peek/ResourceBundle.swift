import Foundation

/// Locates the SwiftPM-generated `peek_peek.bundle` across the three layouts
/// we ship in: raw `swift run` output, an assembled `.app`, and the xctest
/// bundle used during `swift test`.
///
/// SwiftPM's generated `Bundle.module` only probes `Bundle.main.bundleURL +
/// peek_peek.bundle`. When we install into `/Applications/peek.app` the
/// bundle actually lives at `Contents/Resources/peek_peek.bundle`, so we
/// fall through a wider set of candidates before giving up.
enum PeekResources {
    static let bundle: Bundle = {
        let name = "peek_peek.bundle"
        let main = Bundle.main
        var candidates: [URL] = []
        if let r = main.resourceURL { candidates.append(r.appendingPathComponent(name)) }
        candidates.append(main.bundleURL.appendingPathComponent(name))
        candidates.append(main.bundleURL.appendingPathComponent("Contents/Resources/\(name)"))
        // Test host: peekPackageTests.xctest/Contents/Resources/peek_peek.bundle
        let testHost = Bundle(for: BundleFinder.self)
        if let r = testHost.resourceURL { candidates.append(r.appendingPathComponent(name)) }
        candidates.append(testHost.bundleURL.appendingPathComponent(name))

        for url in candidates {
            if let b = Bundle(url: url) { return b }
        }
        // Last resort — let SwiftPM's own accessor raise a descriptive error.
        return Bundle.module
    }()

    private final class BundleFinder {}
}
