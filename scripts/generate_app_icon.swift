#!/usr/bin/env swift
import AppKit
import Foundation

// FlashFind AppIcon：蓝渐变底 + 白色闪电

func drawBolt(in rect: NSRect, fill: NSColor, stroke: NSColor) {
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
    fill.setFill()
    path.fill()
    stroke.setStroke()
    path.lineWidth = max(1, side * 0.04)
    path.stroke()
}

func makeIcon(pixel: CGFloat) -> NSImage {
    NSImage(size: NSSize(width: pixel, height: pixel), flipped: false) { rect in
        let radius = pixel * 0.2237
        let path = NSBezierPath(roundedRect: rect.insetBy(dx: pixel * 0.02, dy: pixel * 0.02),
                                xRadius: radius, yRadius: radius)
        NSGradient(colors: [
            NSColor(calibratedRed: 0.16, green: 0.26, blue: 0.70, alpha: 1),
            NSColor(calibratedRed: 0.30, green: 0.58, blue: 0.96, alpha: 1),
            NSColor(calibratedRed: 0.50, green: 0.84, blue: 0.98, alpha: 1),
        ])?.draw(in: path, angle: 135)
        let gloss = NSBezierPath(roundedRect: NSRect(
            x: rect.minX + pixel * 0.08, y: rect.midY,
            width: rect.width - pixel * 0.16, height: rect.height * 0.42
        ), xRadius: radius * 0.5, yRadius: radius * 0.5)
        NSColor.white.withAlphaComponent(0.14).setFill()
        gloss.fill()
        let inset = rect.insetBy(dx: pixel * 0.24, dy: pixel * 0.20)
        drawBolt(in: inset, fill: .white, stroke: NSColor.white.withAlphaComponent(0.3))
        return true
    }
}

func writePNG(_ image: NSImage, to url: URL, pixel: Int) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixel, pixelsHigh: pixel,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: pixel, height: pixel)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSColor.clear.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: pixel, height: pixel)).fill()
    image.draw(in: NSRect(x: 0, y: 0, width: pixel, height: pixel),
               from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "./AppIcon.iconset"
let fm = FileManager.default
try? fm.removeItem(atPath: outDir)
try! fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)
for (name, px) in [
    ("icon_16x16.png", 16), ("diana.k@example.org", 32),
    ("icon_32x32.png", 32), ("ivan.p@example.net", 64),
    ("icon_128x128.png", 128), ("wendy.h@example.net", 256),
    ("icon_256x256.png", 256), ("wendy.h@example.net", 512),
    ("icon_512x512.png", 512), ("walt.e@example.net", 1024),
] as [(String, Int)] {
    writePNG(makeIcon(pixel: CGFloat(px)), to: URL(fileURLWithPath: outDir).appendingPathComponent(name), pixel: px)
}
print("iconset ready: \(outDir)")
