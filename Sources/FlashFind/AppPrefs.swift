import AppKit

/// 语言 / 外观偏好（UserDefaults，无额外依赖）
enum AppPrefs {
    enum Language: String, CaseIterable {
        case zh = "zh"
        case en = "en"

        var label: String {
            switch self {
            case .zh: return "中文"
            case .en: return "English"
            }
        }
    }

    enum Appearance: String, CaseIterable {
        case system = "system"
        case light = "light"
        case dark = "dark"

        var labelZH: String {
            switch self {
            case .system: return "跟随系统"
            case .light: return "浅色"
            case .dark: return "深色"
            }
        }

        var labelEN: String {
            switch self {
            case .system: return "System"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }

        func label(lang: Language) -> String {
            lang == .en ? labelEN : labelZH
        }
    }

    static var language: Language {
        get {
            if let raw = UserDefaults.standard.string(forKey: "ff.language"),
               let v = Language(rawValue: raw) { return v }
            return .zh
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "ff.language")
            NotificationCenter.default.post(name: .ffPrefsChanged, object: nil)
        }
    }

    static var appearance: Appearance {
        get {
            if let raw = UserDefaults.standard.string(forKey: "ff.appearance"),
               let v = Appearance(rawValue: raw) { return v }
            return .system
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "ff.appearance")
            applyAppearance()
            NotificationCenter.default.post(name: .ffPrefsChanged, object: nil)
        }
    }

    /// 是否搜索文件内容（默认关，保证毫秒级文件名搜索）
    static var contentSearchEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: "ff.contentSearch") == nil { return false }
            return UserDefaults.standard.bool(forKey: "ff.contentSearch")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "ff.contentSearch")
            NotificationCenter.default.post(name: .ffPrefsChanged, object: nil)
        }
    }

    static func applyAppearance() {
        let named: NSAppearance.Name?
        switch appearance {
        case .system:
            NSApp.appearance = nil
            named = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
            named = .aqua
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
            named = .darkAqua
        }
        // 同步所有窗口（含已打开的面板），layer 颜色由各 WC 在通知里刷新
        for w in NSApp.windows {
            if let named {
                w.appearance = NSAppearance(named: named)
            } else {
                w.appearance = nil
            }
        }
    }
}

extension Notification.Name {
    static let ffPrefsChanged = Notification.Name("ff.prefsChanged")
}

/// 极简中英文字典
enum L10n {
    static var isEN: Bool { AppPrefs.language == .en }

    static func t(_ zh: String, _ en: String) -> String { isEN ? en : zh }

    // Common
    static var settings: String { t("设置", "Settings") }
    static var done: String { t("完成", "Done") }
    static var locations: String { t("位置", "Locations") }
    static var allLocations: String { t("全部位置", "All Locations") }
    static var addLocation: String { t("添加位置…", "Add Location…") }
    static var searchHeadline: String { t("搜索文件，快如闪电", "Search files, lightning fast") }
    static var searchSubhead: String { t("输入关键词，立即找到你需要的文件", "Type a keyword to find files instantly") }
    static var searchPlaceholder: String { t("输入关键词搜索…", "Search by file name…") }
    static var type: String { t("类型", "Type") }
    static var modified: String { t("修改时间", "Modified") }
    static var size: String { t("大小", "Size") }
    static var location: String { t("位置", "Location") }
    static var relevance: String { t("相关性", "Relevance") }
    static var footerHints: String { t("↑↓ 选择    ↩ 打开    ⌘↩ 在访达中显示", "↑↓ Select    ↩ Open    ⌘↩ Show in Finder") }
    static var foundFormat: String { t("共找到 %d 个结果 · %.1f ms", "Found %d results · %.1f ms") }
    static var indexFormat: String { t("索引 %d 项 · 输入关键词开始搜索", "Indexed %d items · type to search") }
    static var indexingFormat: String { t("索引中… %d 项", "Indexing… %d items") }
    static var language: String { t("语言", "Language") }
    static var appearance: String { t("外观", "Appearance") }
    static var hotkey: String { t("唤起快捷键", "Hotkey") }
    static var defaultSort: String { t("默认排序", "Default sort") }
    static var launchAtLogin: String { t("登录时自动启动", "Launch at login") }
    static var rebuildIndex: String { t("立即重建索引", "Rebuild index now") }
    static var resetDefault: String { t("恢复默认", "Reset") }
    static var settingsTitle: String { t("FlashFind 设置", "FlashFind Settings") }
    static var hotkeyHint: String { t("点击按钮后按下组合键（需含 ⌘ / ⌥ / ⌃ / ⇧）", "Click then press a shortcut (needs ⌘/⌥/⌃/⇧)") }
    static var open: String { t("打开", "Open") }
    static var showInFinder: String { t("在访达中显示", "Show in Finder") }
    static var revealFolder: String { t("定位到所在文件夹", "Reveal folder") }
    static var copyPath: String { t("复制路径", "Copy path") }
    static var contentSearch: String { t("搜索范围", "Search scope") }
    static var contentSearchOn: String { t("可根据正文内容搜索", "Search in file contents") }
    static var contentSearchOff: String { t("仅搜文件名", "Filename only") }
    static var contentSearchAlertTitle: String { t("已开启「可根据正文内容搜索」", "Content search enabled") }
    static var contentSearchAlertMessage: String {
        t(
            "开启后会同时查找文件内部的文字（如 Word、Excel、PDF 正文），不再只匹配文件名。\n\n这依赖系统 Spotlight 索引，速度会比只搜文件名慢一些，通常需要数秒，请稍候。",
            "FlashFind will also search text inside files (Word, Excel, PDF, etc.), not just filenames.\n\nThis uses Spotlight and is slower than filename-only search — often a few seconds."
        )
    }
    static var contentSearchAlertOK: String { t("知道了", "Got it") }
    static var searching: String { t("搜索中…", "Searching…") }
    static var searchingContent: String { t("正在搜索正文内容…", "Searching file contents…") }
    static var searchingContentHint: String {
        t("正在搜索正文内容（依赖 Spotlight，请稍候）…", "Searching file contents via Spotlight…")
    }
    static var matchName: String { t("文件名", "Name") }
    static var matchContent: String { t("正文", "Text") }
    static var matchBoth: String { t("文件名+正文", "Name+Text") }

    static func category(_ c: IndexEngine.Category) -> String {
        switch c {
        case .all: return t("全部结果", "All Results")
        case .file: return t("文件", "Files")
        case .folder: return t("文件夹", "Folders")
        case .app: return t("应用", "Apps")
        case .other: return t("其他", "Other")
        }
    }

    static func locationTitle(_ path: String, fallback: String) -> String {
        if path == "/" { return "Macintosh HD" }
        if path == "/Applications" { return t("系统应用", "System Apps") }
        if path.hasSuffix("/Applications") { return t("用户应用", "User Apps") }
        switch (path as NSString).lastPathComponent {
        case "Desktop": return t("桌面", "Desktop")
        case "Documents": return t("文档", "Documents")
        case "Downloads": return t("下载", "Downloads")
        case "Movies": return t("影片", "Movies")
        case "Music": return t("音乐", "Music")
        case "Pictures": return t("图片", "Pictures")
        default: return fallback
        }
    }
}
