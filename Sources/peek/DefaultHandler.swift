import Foundation
import AppKit
import UniformTypeIdentifiers

/// Default-handler management: read and (request to) write the system's
/// preferred app for Markdown UTIs.
///
/// macOS Launch Services owns the user's preference. `LSSetDefaultRoleHandler...`
/// returns OSStatus 0 on success but on macOS 12+ the system *also* shows a
/// confirmation sheet ("Use peek to open all 'Markdown Document' files?") —
/// that's the OS, not us. We don't try to bypass it; the prompt is a feature.
enum DefaultHandler {
    /// UTIs we want to claim. `net.daringfireball.markdown` is the canonical
    /// markdown UTI exported by peek's Info.plist; `public.plain-text` we
    /// leave alone — too aggressive to claim by default.
    static let markdownUTIs: [String] = ["net.daringfireball.markdown"]

    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "dev.peek.app"
    }

    /// True when peek is the user's current default for every markdown UTI
    /// we care about. False if any UTI has a different handler or no handler.
    static func isPeekDefault() -> Bool {
        for uti in markdownUTIs {
            let current = LSCopyDefaultRoleHandlerForContentType(uti as CFString, .all)?
                .takeRetainedValue() as String?
            guard current?.lowercased() == bundleIdentifier.lowercased() else {
                return false
            }
        }
        return true
    }

    /// Ask Launch Services to set peek as the default for the markdown UTIs.
    /// Returns true on success for *all* UTIs. The system may show its own
    /// confirmation sheet — that's expected.
    @discardableResult
    static func setPeekAsDefault() -> Bool {
        var allOK = true
        for uti in markdownUTIs {
            let status = LSSetDefaultRoleHandlerForContentType(
                uti as CFString,
                .all,
                bundleIdentifier as CFString
            )
            if status != 0 { allOK = false }
        }
        return allOK
    }
}
