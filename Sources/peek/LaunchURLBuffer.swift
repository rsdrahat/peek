import Foundation
import Combine

/// Observable buffer for URLs delivered by Launch Services on cold start
/// and by warm-start `application(_:openFile:)` calls. MainWindow watches
/// this and opens whatever lands here, instead of relying on a
/// NotificationCenter post that races SwiftUI subscriber attachment on
/// macOS 26.x.
///
/// A single shared instance is enough — there's only ever one main window.
final class LaunchURLBuffer: ObservableObject {
    static let shared = LaunchURLBuffer()

    @Published var pendingURL: URL?

    private init() {}
}
