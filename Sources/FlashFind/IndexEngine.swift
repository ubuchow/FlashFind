import Foundation

/// 紧凑文件名索引：目录字典 + 文件名数组，搜索时并行扫文件名（百万级通常 <10ms）
final class IndexEngine: @unchecked Sendable {
    static let shared = IndexEngine()

    struct Hit: Sendable {
        let name: String
        let path: String
        let isDirectory: Bool
        /// 扩展名（小写，无点）；目录为 ""
        var fileExtension: String = ""
        var fileSize: Int64 = -1
        var createdAt: Date?
        var modifiedAt: Date?
        /// 相关度排序用：是否前缀匹配
        var isPrefixMatch: Bool = false

        var parentPath: String {
            (path as NSString).deletingLastPathComponent
        }

        var typeKey: String {
            if isDirectory { return "文件夹" }
            let ext = fileExtension
            return ext.isEmpty ? "文件" : ext
        }
    }

    enum SortKey: String, CaseIterable, Sendable {
        case relevance = "相关度"
        case nameAsc = "名称 A→Z"
        case nameDesc = "名称 Z→A"
        case type = "类型"
        case sizeDesc = "大小 大→小"
        case sizeAsc = "大小 小→大"
        case createdDesc = "添加时间 新→旧"
        case createdAsc = "添加时间 旧→新"
        case modifiedDesc = "修改时间 新→旧"
        case modifiedAsc = "修改时间 旧→新"
        case path = "路径"
    }

    /// 跳过的目录名（小写比较）
    private static let skipDirNames: Set<String> = [
        "node_modules", ".git", ".svn", ".hg",
        "deriveddata", "caches", "cache", ".cache",
        "pods", ".build", "build", "dist",
        "__pycache__", ".venv", "venv",
        "library/caches", "library/logs",
        ".trash", ".localized",
        "photos library.photoslibrary",
        "mail", "messages",
    ]

    private let queue = DispatchQueue(label: "com.local.FlashFind.index", qos: .userInitiated)
    private let searchQueue = DispatchQueue(label: "com.local.FlashFind.search", qos: .userInteractive, attributes: .concurrent)

    // MARK: - Compact store
    // dirs[id] = absolute directory path
    // names[i] / lowerNames[i] / dirIds[i] / isDirs[i] 对齐

    private var dirs: [String] = []
    private var dirIndex: [String: UInt32] = [:]
    private var names: [String] = []
    private var lowerNames: [String] = []
    private var dirIds: [UInt32] = []
    private var isDirs: [Bool] = []

    private(set) var isIndexing = false
    private(set) var lastIndexedAt: Date?
    private(set) var fileCount: Int = 0

    var onStatus: ((String) -> Void)?
    var onIndexFinished: (() -> Void)?

    private var roots: [URL] = []
    private var watcher: FSWatcher?

    private init() {}

    // MARK: - Public

    func configureDefaultRoots() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let fm = FileManager.default
        // 不扫整个 ~（含 Library / 云盘，会极慢且占内存）
        // 默认覆盖高频目录，接近 Everything 日常用法
        let candidates = [
            home.appendingPathComponent("Desktop"),
            home.appendingPathComponent("Documents"),
            home.appendingPathComponent("Downloads"),
            home.appendingPathComponent("Movies"),
            home.appendingPathComponent("Music"),
            home.appendingPathComponent("Pictures"),
            home.appendingPathComponent("Applications"),
            URL(fileURLWithPath: "/Applications"),
        ]
        roots = candidates.filter { fm.fileExists(atPath: $0.path) }
        // 若关键目录都不存在，退回 home 但会在遍历时跳过 Library
        if roots.isEmpty {
            roots = [home]
        }
    }

    func start() {
        configureDefaultRoots()
        // 先尝试磁盘缓存秒开，再后台增量/全量刷新
        if loadCache() {
            postStatus("已加载索引 \(fileCount) 项")
            onIndexFinished?()
            // 后台轻量校验：有缓存也再扫一次保证新鲜
            rebuildAsync(reason: "后台刷新")
        } else {
            rebuildAsync(reason: "首次建索引")
        }
        startWatcher()
    }

    func rebuildAsync(reason: String = "重建索引") {
        queue.async { [weak self] in
            self?.rebuildSync(reason: reason)
        }
    }

    /// 毫秒级搜索：只匹配文件名（Everything 风格）
    /// - Parameters:
    ///   - sort: 排序维度；非相关度时会对结果补全大小/时间元数据
    ///   - limit: 返回条数上限
    func search(
        query: String,
        sort: SortKey = .relevance,
        limit: Int = 200
    ) -> (hits: [Hit], elapsedMs: Double) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return ([], 0) }

        let t0 = CFAbsoluteTimeGetCurrent()
        let needle = q.lowercased()

        // 快照（Array CoW，queue 内拷贝引用）
        var snapshotNames: [String] = []
        var snapshotLower: [String] = []
        var snapshotDirIds: [UInt32] = []
        var snapshotIsDirs: [Bool] = []
        var snapshotDirs: [String] = []
        queue.sync {
            snapshotNames = self.names
            snapshotLower = self.lowerNames
            snapshotDirIds = self.dirIds
            snapshotIsDirs = self.isDirs
            snapshotDirs = self.dirs
        }
        let count = snapshotLower.count
        if count == 0 { return ([], 0) }

        // 并行分片；多取一些候选再排序截断
        let candidateCap = max(limit * 4, 400)
        let chunks = ProcessInfo.processInfo.activeProcessorCount
        let slice = max(1, (count + chunks - 1) / chunks)
        var partial: [[Int]] = Array(repeating: [], count: chunks)
        let lock = NSLock()

        DispatchQueue.concurrentPerform(iterations: chunks) { c in
            let start = c * slice
            guard start < count else { return }
            let end = min(count, start + slice)
            var local: [Int] = []
            local.reserveCapacity(64)
            for i in start..<end {
                if snapshotLower[i].contains(needle) {
                    local.append(i)
                    if local.count >= candidateCap / max(chunks, 1) + 32 { break }
                }
            }
            lock.lock()
            partial[c] = local
            lock.unlock()
        }

        var indices: [Int] = []
        indices.reserveCapacity(candidateCap)
        for p in partial {
            indices.append(contentsOf: p)
            if indices.count >= candidateCap { break }
        }
        if indices.count > candidateCap {
            indices = Array(indices.prefix(candidateCap))
        }

        // 相关度预排序（无论最终 sort 为何，先收窄）
        indices.sort { a, b in
            let la = snapshotLower[a]
            let lb = snapshotLower[b]
            let pa = la.hasPrefix(needle)
            let pb = lb.hasPrefix(needle)
            if pa != pb { return pa && !pb }
            if la.count != lb.count { return la.count < lb.count }
            return la < lb
        }
        if indices.count > limit {
            indices = Array(indices.prefix(limit))
        }

        var hits: [Hit] = []
        hits.reserveCapacity(indices.count)
        for i in indices {
            let dirId = Int(snapshotDirIds[i])
            guard dirId < snapshotDirs.count else { continue }
            let dir = snapshotDirs[dirId]
            let name = snapshotNames[i]
            let path = dir == "/" ? "/\(name)" : "\(dir)/\(name)"
            let isDir = snapshotIsDirs[i]
            let ext: String
            if isDir {
                ext = ""
            } else {
                ext = (name as NSString).pathExtension.lowercased()
            }
            let hit = Hit(
                name: name,
                path: path,
                isDirectory: isDir,
                fileExtension: ext,
                isPrefixMatch: snapshotLower[i].hasPrefix(needle)
            )
            hits.append(hit)
        }

        // 按需补全元数据（仅结果集，通常 <200 条，很快）
        if sort.needsMetadata {
            enrichMetadata(&hits)
        }

        hits = Self.sortHits(hits, by: sort, needle: needle)

        let ms = (CFAbsoluteTimeGetCurrent() - t0) * 1000
        return (hits, ms)
    }

    /// 为结果集填充大小 / 创建 / 修改时间
    func enrichMetadata(_ hits: inout [Hit]) {
        let fm = FileManager.default
        for i in hits.indices {
            let path = hits[i].path
            guard let attrs = try? fm.attributesOfItem(atPath: path) else { continue }
            if let size = attrs[.size] as? NSNumber {
                hits[i].fileSize = size.int64Value
            }
            hits[i].createdAt = attrs[.creationDate] as? Date
            hits[i].modifiedAt = attrs[.modificationDate] as? Date
        }
    }

    static func sortHits(_ hits: [Hit], by sort: SortKey, needle: String) -> [Hit] {
        var list = hits
        switch sort {
        case .relevance:
            list.sort { a, b in
                if a.isPrefixMatch != b.isPrefixMatch { return a.isPrefixMatch && !b.isPrefixMatch }
                if a.name.count != b.name.count { return a.name.count < b.name.count }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
        case .nameAsc:
            list.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .nameDesc:
            list.sort { $0.name.localizedStandardCompare($1.name) == .orderedDescending }
        case .type:
            list.sort {
                let c = $0.typeKey.localizedStandardCompare($1.typeKey)
                if c != .orderedSame { return c == .orderedAscending }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        case .sizeDesc:
            list.sort {
                if $0.fileSize != $1.fileSize { return $0.fileSize > $1.fileSize }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        case .sizeAsc:
            list.sort {
                if $0.fileSize != $1.fileSize { return $0.fileSize < $1.fileSize }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        case .createdDesc:
            list.sort {
                let da = $0.createdAt ?? .distantPast
                let db = $1.createdAt ?? .distantPast
                if da != db { return da > db }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        case .createdAsc:
            list.sort {
                let da = $0.createdAt ?? .distantFuture
                let db = $1.createdAt ?? .distantFuture
                if da != db { return da < db }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        case .modifiedDesc:
            list.sort {
                let da = $0.modifiedAt ?? .distantPast
                let db = $1.modifiedAt ?? .distantPast
                if da != db { return da > db }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        case .modifiedAsc:
            list.sort {
                let da = $0.modifiedAt ?? .distantFuture
                let db = $1.modifiedAt ?? .distantFuture
                if da != db { return da < db }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        case .path:
            list.sort { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        }
        return list
    }

    // MARK: - Rebuild

    private func rebuildSync(reason: String) {
        isIndexing = true
        postStatus("\(reason)…")
        log("rebuild start: \(reason) roots=\(roots.map(\.path))")
        let t0 = CFAbsoluteTimeGetCurrent()

        var newDirs: [String] = []
        var newDirIndex: [String: UInt32] = [:]
        var newNames: [String] = []
        var newLower: [String] = []
        var newDirIds: [UInt32] = []
        var newIsDirs: [Bool] = []

        newNames.reserveCapacity(100_000)
        newLower.reserveCapacity(100_000)
        newDirIds.reserveCapacity(100_000)
        newIsDirs.reserveCapacity(100_000)

        let fm = FileManager.default
        var visited = 0

        func dirId(for path: String) -> UInt32 {
            if let id = newDirIndex[path] { return id }
            let id = UInt32(newDirs.count)
            newDirs.append(path)
            newDirIndex[path] = id
            return id
        }

        func shouldSkipDir(_ name: String) -> Bool {
            let lower = name.lowercased()
            if lower.hasPrefix(".") { return true }
            return Self.skipDirNames.contains(lower)
        }

        func shouldSkipPath(_ path: String) -> Bool {
            let p = path.lowercased()
            return p.contains("/node_modules/")
                || p.contains("/.git/")
                || p.contains("/deriveddata/")
                || p.contains("/caches/")
                || p.contains("/library/")
                || p.contains("/.trash")
                || p.contains("google drive")
                || p.contains("cloudstorage")
                || p.contains(".photoslibrary")
                || p.contains("photos library")
                || p.contains("/.swiftpm/")
                || p.contains("/.build/")
                || p.contains("/site-packages/")
        }

        for root in roots {
            let rootPath = root.path
            guard let attrs = try? fm.attributesOfItem(atPath: rootPath) else { continue }
            // 跳过网络卷
            if let fsType = attrs[.type] as? FileAttributeType, fsType == .typeSymbolicLink {
                // 允许符号链接根，但不深追远端
            }
            log("scan root: \(rootPath)")
            postStatus("扫描 \(root.lastPathComponent)…")

            let rootName = root.lastPathComponent
            let parent = root.deletingLastPathComponent().path
            let rid = dirId(for: parent.isEmpty ? "/" : parent)
            newNames.append(rootName)
            newLower.append(rootName.lowercased())
            newDirIds.append(rid)
            newIsDirs.append(true)

            // 用 resourceValues 预取，skipsPackageDescendants 避免进 .app
            guard let enumerator = fm.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isRegularFileKey],
                options: [.skipsPackageDescendants, .skipsHiddenFiles],
                errorHandler: { url, err in
                    self.log("skip \(url.path): \(err.localizedDescription)")
                    return true // 继续
                }
            ) else { continue }

            while let item = enumerator.nextObject() as? URL {
                visited += 1
                if visited & 0x1FFF == 0 {
                    postStatus("索引中… \(newNames.count) 项")
                    log("progress visited=\(visited) indexed=\(newNames.count)")
                }

                let name = item.lastPathComponent
                // 资源值失败则当文件处理，避免阻塞
                let vals = try? item.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                let directory = vals?.isDirectory == true
                let symlink = vals?.isSymbolicLink == true

                if directory && symlink {
                    enumerator.skipDescendants()
                    continue
                }
                if directory && shouldSkipDir(name) {
                    enumerator.skipDescendants()
                    continue
                }
                if shouldSkipPath(item.path) {
                    if directory { enumerator.skipDescendants() }
                    continue
                }

                let parentPath = item.deletingLastPathComponent().path
                let did = dirId(for: parentPath)
                newNames.append(name)
                newLower.append(name.lowercased())
                newDirIds.append(did)
                newIsDirs.append(directory)
            }
            log("done root \(rootPath) total=\(newNames.count)")
        }

        dirs = newDirs
        dirIndex = newDirIndex
        names = newNames
        lowerNames = newLower
        dirIds = newDirIds
        isDirs = newIsDirs
        fileCount = newNames.count
        lastIndexedAt = Date()
        isIndexing = false

        let sec = CFAbsoluteTimeGetCurrent() - t0
        postStatus(String(format: "索引完成 %d 项 · %.1fs", fileCount, sec))
        log(String(format: "rebuild done count=%d sec=%.2f", fileCount, sec))
        saveCache()
        DispatchQueue.main.async { self.onIndexFinished?() }
    }

    private func log(_ msg: String) {
        let line = "\(Date()): \(msg)\n"
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("FlashFind/debug.log")
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: url.path) {
                if let h = try? FileHandle(forWritingTo: url) {
                    defer { try? h.close() }
                    try? h.seekToEnd()
                    try? h.write(contentsOf: data)
                }
            } else {
                try? data.write(to: url)
            }
        }
    }

    // MARK: - Incremental via FSEvents

    private func startWatcher() {
        let paths = roots.map(\.path)
        watcher = FSWatcher(paths: paths) { [weak self] events in
            self?.queue.async {
                self?.applyFSEvents(events)
            }
        }
        watcher?.start()
    }

    private func applyFSEvents(_ paths: [String]) {
        // 简化：变更较多时触发节流全量刷新，保证正确且实现轻量
        // 真正 Everything 级增量可按路径增删；此处用 debounce 全量足够实用
        struct Holder {
            static var work: DispatchWorkItem?
        }
        Holder.work?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.rebuildSync(reason: "增量刷新")
        }
        Holder.work = work
        queue.asyncAfter(deadline: .now() + 2.0, execute: work)
    }

    // MARK: - Cache

    private var cacheURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("FlashFind", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("index-v1.json")
    }

    private func saveCache() {
        // 紧凑 JSON：dirs + names + dirIds + isDirs
        // 为控制体积，超过 80 万条不写盘（仍驻内存）
        guard names.count <= 800_000 else { return }
        let payload: [String: Any] = [
            "dirs": dirs,
            "names": names,
            "dirIds": dirIds.map { Int($0) },
            "isDirs": isDirs,
            "ts": Date().timeIntervalSince1970,
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: []) {
            try? data.write(to: cacheURL, options: .atomic)
        }
    }

    @discardableResult
    private func loadCache() -> Bool {
        guard let data = try? Data(contentsOf: cacheURL),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cDirs = obj["dirs"] as? [String],
              let cNames = obj["names"] as? [String],
              let cDirIds = obj["dirIds"] as? [Int],
              let cIsDirs = obj["isDirs"] as? [Bool],
              cNames.count == cDirIds.count, cNames.count == cIsDirs.count
        else { return false }

        // 缓存超过 7 天则忽略
        if let ts = obj["ts"] as? TimeInterval {
            if Date().timeIntervalSince1970 - ts > 7 * 24 * 3600 { return false }
        }

        dirs = cDirs
        names = cNames
        lowerNames = cNames.map { $0.lowercased() }
        dirIds = cDirIds.map { UInt32(truncatingIfNeeded: $0) }
        isDirs = cIsDirs
        var map: [String: UInt32] = [:]
        map.reserveCapacity(cDirs.count)
        for (i, d) in cDirs.enumerated() {
            map[d] = UInt32(i)
        }
        dirIndex = map
        fileCount = cNames.count
        lastIndexedAt = Date()
        return fileCount > 0
    }

    private func postStatus(_ s: String) {
        DispatchQueue.main.async { self.onStatus?(s) }
    }
}

extension IndexEngine.SortKey {
    var needsMetadata: Bool {
        switch self {
        case .sizeAsc, .sizeDesc, .createdAsc, .createdDesc, .modifiedAsc, .modifiedDesc:
            return true
        default:
            return false
        }
    }
}
