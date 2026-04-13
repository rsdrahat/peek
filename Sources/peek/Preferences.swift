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
}
