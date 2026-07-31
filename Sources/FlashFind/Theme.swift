import AppKit

/// 极简主题：无资源文件、纯代码绘制，零额外内存占用
enum Theme {
    // 宋体加粗 — 系统 Songti SC Bold
    static func songBold(_ size: CGFloat) -> NSFont {
        if let f = NSFont(name: "STSongti-SC-Bold", size: size) { return f }
        if let f = NSFont(name: "Songti SC Bold", size: size) { return f }
        if let f = NSFont(name: "SongtiSC-Bold", size: size) { return f }
        return NSFont.systemFont(ofSize: size, weight: .semibold)
    }

    static func songRegular(_ size: CGFloat) -> NSFont {
        if let f = NSFont(name: "STSongti-SC-Regular", size: size) { return f }
        if let f = NSFont(name: "Songti SC", size: size) { return f }
        return NSFont.systemFont(ofSize: size)
    }

    /// 高级感暗色强调（适配浅色/深色）
    static var accent: NSColor {
        NSColor(name: nil) { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            if dark {
                return NSColor(calibratedRed: 0.72, green: 0.78, blue: 1.0, alpha: 1)
            }
            return NSColor(calibratedRed: 0.22, green: 0.28, blue: 0.55, alpha: 1)
        }
    }

    static var subtleBorder: NSColor {
        NSColor(name: nil) { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return dark
                ? NSColor.white.withAlphaComponent(0.10)
                : NSColor.black.withAlphaComponent(0.08)
        }
    }

    static var cardFill: NSColor {
        NSColor(name: nil) { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return dark
                ? NSColor.white.withAlphaComponent(0.04)
                : NSColor.white.withAlphaComponent(0.55)
        }
    }

    static var metaText: NSColor { .tertiaryLabelColor }
    static var secondaryText: NSColor { .secondaryLabelColor }
}
