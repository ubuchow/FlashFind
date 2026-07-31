import CoreServices
import Foundation

/// 轻量 FSEvents 监视，路径变更回调（去抖由上层处理）
final class FSWatcher {
    private var stream: FSEventStreamRef?
    private let paths: [String]
    private let callback: ([String]) -> Void

    init(paths: [String], callback: @escaping ([String]) -> Void) {
        self.paths = paths
        self.callback = callback
    }

    func start() {
        guard stream == nil, !paths.isEmpty else { return }

        var ctx = FSEventStreamContext(
            version: 0,
            info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let cb: FSEventStreamCallback = { _, info, numEvents, eventPaths, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<FSWatcher>.fromOpaque(info).takeUnretainedValue()
            // UseCFTypes → CFArray of CFString
            let cfArr = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue()
            let nsArr = cfArr as NSArray
            var list: [String] = []
            list.reserveCapacity(Int(numEvents))
            for i in 0..<Int(numEvents) {
                if i < nsArr.count, let s = nsArr[i] as? String {
                    list.append(s)
                }
            }
            if !list.isEmpty {
                watcher.callback(list)
            }
        }

        stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            cb,
            &ctx,
            paths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.5,
            FSEventStreamCreateFlags(
                kFSEventStreamCreateFlagFileEvents
                    | kFSEventStreamCreateFlagUseCFTypes
                    | kFSEventStreamCreateFlagNoDefer
            )
        )
        guard let stream else { return }
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.global(qos: .utility))
        FSEventStreamStart(stream)
    }

    func stop() {
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
    }

    deinit { stop() }
}
