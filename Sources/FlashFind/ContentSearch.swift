import Foundation

/// 内容搜索：优先用系统 Spotlight（mdfind），不自建全文索引，保持内存极低
enum ContentSearch {
    /// 单次 mdfind 最长等待（本机实测全文检索常需 3–8 秒）
    private static let defaultTimeout: TimeInterval = 12
    /// 最多合并多少条内容命中，避免 UI 被海量结果淹没
    private static let maxResults = 500

    /// 在指定目录下搜索正文含 keyword 的文件路径
    static func paths(
        keyword: String,
        onlyIn: [String],
        timeoutSeconds: TimeInterval = defaultTimeout
    ) -> [String] {
        let q = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }

        let roots = optimizedRoots(onlyIn)
        guard !roots.isEmpty else { return [] }

        let escaped = escapeSpotlight(q)
        // cd = case / diacritic insensitive；中文姓名用通配即可
        let predicates = [
            "kMDItemTextContent == \"*\(escaped)*\"cd",
            // 兜底：Spotlight 通用查询（含部分未写入 TextContent 但仍被索引的文档）
            escaped
        ]

        var found = Set<String>()
        found.reserveCapacity(256)

        for root in roots {
            for (idx, predicate) in predicates.enumerated() {
                // 主查询已有足够结果时跳过兜底查询，避免多等一轮 mdfind
                if idx > 0, found.count >= 40 { break }
                let batch = runMdfind(predicate: predicate, onlyIn: root, timeout: timeoutSeconds)
                for p in batch { found.insert(p) }
                if found.count >= maxResults { break }
            }
            if found.count >= maxResults { break }
        }

        if found.count <= maxResults {
            return Array(found)
        }
        return Array(found.prefix(maxResults))
    }

    /// 合并/收敛搜索根目录：多路径若都在用户主目录下，改为只搜一次 $HOME，避免超时累加
    private static func optimizedRoots(_ onlyIn: [String]) -> [String] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        var roots = onlyIn
            .map { ($0 as NSString).standardizingPath }
            .filter { !$0.isEmpty && $0 != "/" && fm.fileExists(atPath: $0) }

        if roots.isEmpty {
            return [home]
        }

        // 全部落在 Home 下（含 Home 自身）→ 一次 -onlyin Home
        let allUnderHome = roots.allSatisfy { $0 == home || $0.hasPrefix(home + "/") }
        if allUnderHome {
            return [home]
        }

        // 去重嵌套：若 A 是 B 的前缀，只保留较浅的 A
        roots.sort { $0.count < $1.count }
        var compact: [String] = []
        for r in roots {
            if compact.contains(where: { r == $0 || r.hasPrefix($0 + "/") }) { continue }
            compact.append(r)
        }
        // 最多 4 个独立根，防止串行过久
        return Array(compact.prefix(4))
    }

    private static func runMdfind(predicate: String, onlyIn: String, timeout: TimeInterval) -> [String] {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        proc.arguments = ["-onlyin", onlyIn, predicate]

        let out = Pipe()
        let err = Pipe()
        proc.standardOutput = out
        proc.standardError = err

        // 后台持续读 stdout，避免管道缓冲填满导致 mdfind 阻塞 + 超时后 0 结果
        let dataLock = NSLock()
        var collected = Data()
        let readGroup = DispatchGroup()
        readGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            defer { readGroup.leave() }
            while true {
                let chunk = out.fileHandleForReading.availableData
                if chunk.isEmpty { break }
                dataLock.lock()
                collected.append(chunk)
                dataLock.unlock()
                // 粗略上限 ~8MB 路径列表
                if collected.count > 8 * 1024 * 1024 { break }
            }
        }
        // 丢弃 stderr，防止偶发填满
        DispatchQueue.global(qos: .utility).async {
            while true {
                let chunk = err.fileHandleForReading.availableData
                if chunk.isEmpty { break }
            }
        }

        do {
            try proc.run()
        } catch {
            return []
        }

        let deadline = Date().addingTimeInterval(timeout)
        while proc.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if proc.isRunning {
            proc.terminate()
            // 给一点时间冲刷管道
            Thread.sleep(forTimeInterval: 0.1)
            if proc.isRunning { proc.interrupt() }
        }
        proc.waitUntilExit()
        _ = readGroup.wait(timeout: .now() + 1.0)

        dataLock.lock()
        let data = collected
        dataLock.unlock()

        if data.isEmpty { return [] }
        let text = String(decoding: data, as: UTF8.self)
        return parsePaths(text)
    }

    private static func parsePaths(_ text: String) -> [String] {
        let fm = FileManager.default
        var out: [String] = []
        out.reserveCapacity(64)
        for line in text.split(whereSeparator: \.isNewline) {
            let p = String(line)
            guard !p.isEmpty else { continue }
            // 不强制 exists 检查每一行（网络盘/临时消失会误杀）；只做基本过滤
            if p.hasPrefix("/") {
                out.append(p)
            }
            if out.count >= maxResults { break }
        }
        // 轻量存在性过滤
        return out.filter { fm.fileExists(atPath: $0) }
    }

    private static func escapeSpotlight(_ s: String) -> String {
        s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "*", with: "\\*")
            .replacingOccurrences(of: "?", with: "\\?")
    }
}
