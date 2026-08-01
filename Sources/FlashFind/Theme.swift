import AppKit

/// 设计稿风格：浅色、蓝色强调，纯代码无资源
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

    /// UI 用系统字体更接近设计稿（数字/标签清晰）
    static func ui(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        NSFont.systemFont(ofSize: size, weight: weight)
    }

    static var accent: NSColor {
        NSColor(calibratedRed: 0.25, green: 0.47, blue: 0.98, alpha: 1) // #4078FA 附近
    }

    static var accentSoft: NSColor {
        accent.withAlphaComponent(0.12)
    }

    static var sidebarBg: NSColor {
        NSColor(name: nil) { a in
            a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(calibratedWhite: 0.14, alpha: 1)
                : NSColor(calibratedWhite: 0.965, alpha: 1)
        }
    }

    static var contentBg: NSColor {
        NSColor(name: nil) { a in
            a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(calibratedWhite: 0.11, alpha: 1)
                : NSColor.white
        }
    }

    static var subtleBorder: NSColor {
        NSColor(name: nil) { a in
            a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor.white.withAlphaComponent(0.08)
                : NSColor.black.withAlphaComponent(0.06)
        }
    }

    static var chipBg: NSColor {
        NSColor(name: nil) { a in
            a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor.white.withAlphaComponent(0.06)
                : NSColor(calibratedWhite: 0.96, alpha: 1)
        }
    }

    static var secondaryText: NSColor { .secondaryLabelColor }
    static var metaText: NSColor { .tertiaryLabelColor }
    static var titleText: NSColor { .labelColor }
}
