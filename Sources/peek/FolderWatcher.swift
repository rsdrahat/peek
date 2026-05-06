import Foundation
import CoreServices

/// Watches a folder tree recursively using FSEvents and fires `onChange`
/// (on the main queue) when anything below the root changes. FSEvents
/// already coalesces bursts within `latency` seconds, so callers can
/// drive a full tree rebuild on each fire without piling up work.
final class FolderWatcher {
    private var stream: FSEventStreamRef?
    private let onChange: () -> Void
    private let queue = DispatchQueue(label: "peek.folderwatcher", qos: .userInitiated)

    init?(url: URL, onChange: @escaping () -> Void) {
        self.onChange = onChange

        var context = FSEventStreamContext(
            version: 0,
            info: nil,
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        // Stash an unretained pointer to self so the C callback can hop back.
        // FolderBrowser owns the watcher's lifetime, so unretained is safe.
        context.info = Unmanaged.passUnretained(self).toOpaque()

        let paths = [url.path] as CFArray
        let flags = UInt32(
            kFSEventStreamCreateFlagNoDefer
            | kFSEventStreamCreateFlagWatchRoot
        )

        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let me = Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue()
            DispatchQueue.main.async { me.onChange() }
        }

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.3,
            flags
        ) else { return nil }

        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    deinit {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
    }
}
