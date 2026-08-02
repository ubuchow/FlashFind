import AppKit

/// 纯代码矢量图标：菜单栏黄色闪电 + App 彩色图标
enum MenuBarIcon {
    /// 菜单栏黄色闪电（非 template，固定着色）
    static func make(size: CGFloat = 12) -> NSImage {
        let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let inset = rect.insetBy(dx: size * 0.08, dy: size * 0.06)
            drawBolt(
                in: inset,
                fill: NSColor(calibratedRed: 1.0, green: 0.84, blue: 0.04, alpha: 1),
                stroke: NSColor(calibratedRed: 0.92, green: 0.58, blue: 0.0, alpha: 1)
            )
            return true
        }
        img.isTemplate = false
        return img
    }

    /// App 图标（彩色，指定像素边长）
    static func makeAppIcon(pixel: CGFloat) -> NSImage {
        let img = NSImage(size: NSSize(width: pixel, height: pixel), flipped: false) { rect in
            let radius = pixel * 0.2237
            let path = NSBezierPath(roundedRect: rect.insetBy(dx: pixel * 0.02, dy: pixel * 0.02),
                                    xRadius: radius, yRadius: radius)
            let gradient = NSGradient(colors: [
                NSColor(calibratedRed: 0.18, green: 0.28, blue: 0.72, alpha: 1),
                NSColor(calibratedRed: 0.28, green: 0.55, blue: 0.95, alpha: 1),
                NSColor(calibratedRed: 0.45, green: 0.82, blue: 0.98, alpha: 1),
            ])
            gradient?.draw(in: path, angle: 135)

            let gloss = NSBezierPath(roundedRect: NSRect(
                x: rect.minX + pixel * 0.08,
                y: rect.midY,
                width: rect.width - pixel * 0.16,
                height: rect.height * 0.42
            ), xRadius: radius * 0.6, yRadius: radius * 0.6)
            NSColor.white.withAlphaComponent(0.12).setFill()
            gloss.fill()

            let inset = rect.insetBy(dx: pixel * 0.24, dy: pixel * 0.20)
            drawBolt(in: inset, fill: .white, stroke: NSColor.white.withAlphaComponent(0.35))
            return true
        }
        img.isTemplate = false
        return img
    }

    private static func drawBolt(in rect: NSRect, fill: NSColor, stroke: NSColor) {
        let side = min(rect.width, rect.height)
        let ox = rect.midX - side / 2
        let oy = rect.midY - side / 2
        func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
            NSPoint(x: ox + x * side, y: oy + y * side)
        }

        let path = NSBezierPath()
        path.move(to: p(0.58, 0.98))
        path.line(to: p(0.20, 0.52))
        path.line(to: p(0.44, 0.52))
        path.line(to: p(0.30, 0.02))
        path.line(to: p(0.80, 0.50))
        path.line(to: p(0.54, 0.50))
        path.line(to: p(0.72, 0.98))
        path.close()
        path.lineJoinStyle = .round
        path.lineCapStyle = .round

        if NSGraphicsContext.current != nil {
            NSGraphicsContext.current?.saveGraphicsState()
            let sh = NSShadow()
            sh.shadowColor = NSColor.black.withAlphaComponent(0.22)
            sh.shadowOffset = NSSize(width: 0, height: -0.5)
            sh.shadowBlurRadius = max(0.6, side * 0.06)
            sh.set()
            fill.setFill()
            path.fill()
            NSGraphicsContext.current?.restoreGraphicsState()
        }

        fill.setFill()
        path.fill()
        stroke.setStroke()
        path.lineWidth = max(0.6, side * 0.045)
        path.stroke()
    }
}
