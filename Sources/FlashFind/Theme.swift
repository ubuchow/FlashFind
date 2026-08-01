import AppKit

/// 设计稿风格；颜色按 AppPrefs 外观显式解析（layer 不用动态 CGColor）
enum Theme {
    static func songBold(_ size: CGFloat) -> NSFont {
        if let f = NSFont(name: "STSongti-SC-Bold", size: size) { return f }
        if let f = NSFont(name: "Songti SC Bold", size: size) { return f }
        return NSFont.systemFont(ofSize: size, weight: .semibold)
    }

    static func songRegular(_ size: CGFloat) -> NSFont {
        if let f = NSFont(name: "STSongti-SC-Regular", size: size) { return f }
        return NSFont.systemFont(ofSize: size)
    }

    static func ui(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        songBold(size)
    }

    /// 当前是否应按深色绘制（设置项 + 系统）
    static var isDark: Bool {
        switch AppPrefs.appearance {
        case .dark: return true
        case .light: return false
        case .system:
            let match = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
            return match == .darkAqua
        }
    }

    static var accent: NSColor {
        isDark
            ? NSColor(calibratedRed: 0.45, green: 0.62, blue: 1.0, alpha: 1)
            : NSColor(calibratedRed: 0.25, green: 0.47, blue: 0.98, alpha: 1)
    }

    static var accentSoft: NSColor {
        accent.withAlphaComponent(isDark ? 0.22 : 0.12)
    }

    static var sidebarBg: NSColor {
        isDark
            ? NSColor(calibratedWhite: 0.13, alpha: 1)
            : NSColor(calibratedWhite: 0.965, alpha: 1)
    }

    static var contentBg: NSColor {
        isDark
            ? NSColor(calibratedWhite: 0.10, alpha: 1)
            : NSColor.white
    }

    static var subtleBorder: NSColor {
        isDark
            ? NSColor.white.withAlphaComponent(0.10)
            : NSColor.black.withAlphaComponent(0.06)
    }

    static var chipBg: NSColor {
        isDark
            ? NSColor.white.withAlphaComponent(0.08)
            : NSColor(calibratedWhite: 0.96, alpha: 1)
    }

    static var secondaryText: NSColor {
        isDark ? NSColor(calibratedWhite: 0.72, alpha: 1) : .secondaryLabelColor
    }

    static var metaText: NSColor {
        isDark ? NSColor(calibratedWhite: 0.55, alpha: 1) : .tertiaryLabelColor
    }

    static var titleText: NSColor {
        isDark ? NSColor(calibratedWhite: 0.95, alpha: 1) : .labelColor
    }

    static var searchBorder: NSColor {
        accent.withAlphaComponent(isDark ? 0.65 : 0.55)
    }
}
