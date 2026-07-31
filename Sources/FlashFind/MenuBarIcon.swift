import AppKit

/// 纯代码矢量图标：菜单栏 template + App 彩色图标，无外部图片依赖
enum MenuBarIcon {
    /// 菜单栏 18pt template（黑白）
    static func make(size: CGFloat = 18) -> NSImage {
        let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            drawMagnifier(in: rect, lineWidth: max(1.35, size * 0.09), color: .black, filledLens: false)
            return true
        }
        img.isTemplate = true
        return img
    }

    /// App 图标（彩色，指定像素边长）
    static func makeAppIcon(pixel: CGFloat) -> NSImage {
        let img = NSImage(size: NSSize(width: pixel, height: pixel), flipped: false) { rect in
            // 圆角矩形底
            let radius = pixel * 0.2237 // macOS 风格
            let path = NSBezierPath(roundedRect: rect.insetBy(dx: pixel * 0.02, dy: pixel * 0.02),
                                    xRadius: radius, yRadius: radius)
            // 渐变：靛蓝 → 青蓝
            let gradient = NSGradient(colors: [
                NSColor(calibratedRed: 0.18, green: 0.28, blue: 0.72, alpha: 1),
                NSColor(calibratedRed: 0.28, green: 0.55, blue: 0.95, alpha: 1),
                NSColor(calibratedRed: 0.45, green: 0.82, blue: 0.98, alpha: 1),
            ])
            gradient?.draw(in: path, angle: 135)

            // 轻微高光
            let gloss = NSBezierPath(roundedRect: NSRect(
                x: rect.minX + pixel * 0.08,
                y: rect.midY,
                width: rect.width - pixel * 0.16,
                height: rect.height * 0.42
            ), xRadius: radius * 0.6, yRadius: radius * 0.6)
            NSColor.white.withAlphaComponent(0.12).setFill()
            gloss.fill()

            // 白色放大镜
            let inset = rect.insetBy(dx: pixel * 0.22, dy: pixel * 0.22)
            drawMagnifier(in: inset, lineWidth: max(2, pixel * 0.055), color: .white, filledLens: false)

            // 小闪光点
            let spark = pixel * 0.035
            let srect = NSRect(
                x: rect.maxX - pixel * 0.30,
                y: rect.maxY - pixel * 0.32,
                width: spark * 2,
                height: spark * 2
            )
            NSColor.white.withAlphaComponent(0.95).setFill()
            NSBezierPath(ovalIn: srect).fill()

            return true
        }
        img.isTemplate = false
        return img
    }

    /// 在 rect 内绘制居中、比例正确的放大镜
    private static func drawMagnifier(in rect: NSRect, lineWidth: CGFloat, color: NSColor, filledLens: Bool) {
        // 统一坐标系：以正方形内容区居中
        let side = min(rect.width, rect.height)
        let origin = NSPoint(
            x: rect.midX - side / 2,
            y: rect.midY - side / 2
        )
        let box = NSRect(x: origin.x, y: origin.y, width: side, height: side)

        // 镜面：左上偏，直径约 58%
        let d = side * 0.58
        let glass = NSRect(
            x: box.minX + side * 0.10,
            y: box.maxY - side * 0.12 - d,
            width: d,
            height: d
        )

        color.setStroke()
        color.setFill()

        let circle = NSBezierPath(ovalIn: glass)
        circle.lineWidth = lineWidth
        if filledLens {
            color.withAlphaComponent(0.15).setFill()
            circle.fill()
            color.setStroke()
        }
        circle.stroke()

        // 手柄：从镜面右下沿 45° 伸出
        let handle = NSBezierPath()
        let start = NSPoint(x: glass.midX + d * 0.32, y: glass.midY - d * 0.32)
        let end = NSPoint(x: box.maxX - side * 0.10, y: box.minY + side * 0.12)
        handle.move(to: start)
        handle.line(to: end)
        handle.lineWidth = lineWidth * 1.15
        handle.lineCapStyle = .round
        handle.stroke()
    }
}
