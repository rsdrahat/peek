import Foundation

/// Small wrapper around UserDefaults for app-wide preferences.
/// Keys are strongly typed; defaults defined here.
enum Pref {
    static let zoomKey = "peek.zoom"
    static let defaultZoom: Double = 1.0
    static let zoomMin: Double = 0.6
    static let zoomMax: Double = 2.5
    static let zoomStep: Double = 0.1

    static var zoom: Double {
        get {
            let raw = UserDefaults.standard.double(forKey: zoomKey)
            return raw == 0 ? defaultZoom : raw
        }
        set {
            let clamped = min(max(newValue, zoomMin), zoomMax)
            UserDefaults.standard.set(clamped, forKey: zoomKey)
        }
    }

    // MARK: - Sidebar

    static let sidebarCollapsedKey = "peek.sidebar.collapsed"
    static let sidebarWidthKey = "peek.sidebar.width"
    static let defaultSidebarWidth: Double = 240
    static let sidebarMinWidth: Double = 180
    static let sidebarMaxWidth: Double = 480

    static var sidebarCollapsed: Bool {
        get { UserDefaults.standard.bool(forKey: sidebarCollapsedKey) }
        set { UserDefaults.standard.set(newValue, forKey: sidebarCollapsedKey) }
    }

    static var sidebarWidth: Double {
        get {
            let raw = UserDefaults.standard.double(forKey: sidebarWidthKey)
            return raw == 0 ? defaultSidebarWidth : raw
        }
        set {
            let clamped = min(max(newValue, sidebarMinWidth), sidebarMaxWidth)
            UserDefaults.standard.set(clamped, forKey: sidebarWidthKey)
        }
    }

    // MARK: - Default-handler prompt

    static let askedDefaultHandlerKey = "peek.askedDefaultHandler"

    /// Whether the user has already answered the "make peek the default for
    /// Markdown?" question. We only ever ask once at launch. They can revisit
    /// the choice via the File menu.
    static var askedDefaultHandler: Bool {
        get { UserDefaults.standard.bool(forKey: askedDefaultHandlerKey) }
        set { UserDefaults.standard.set(newValue, forKey: askedDefaultHandlerKey) }
    }
}
