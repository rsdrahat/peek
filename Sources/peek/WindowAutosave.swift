import SwiftUI
import AppKit

/// Turns on NSWindow frame autosave on the hosting window.
/// Dropped into the hierarchy as a near-invisible background view.
struct WindowAutosaveAccessor: NSViewRepresentable {
    let name: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            view?.window?.setFrameAutosaveName(name)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { [weak view] in
            guard let window = view?.window else { return }
            if window.frameAutosaveName != name {
                window.setFrameAutosaveName(name)
            }
        }
    }
}
