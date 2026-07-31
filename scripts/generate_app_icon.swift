#!/usr/bin/env swift
import AppKit
import Foundation

// 生成 AppIcon.icns（纯代码绘制，无外部资源）

func drawMagnifier(in rect: NSRect, lineWidth: CGFloat, color: NSColor) {
    let side = min(rect.width, rect.height)
    let origin = NSPoint(x: rect.midX - side / 2, y: rect.midY - side / 2)
    let box = NSRect(x: origin.x, y: origin.y, width: side, height: side)
    let d = side * 0.58
    let glass = NSRect(x: box.minX + side * 0.10, y: box.maxY - side * 0.12 - d, width: d, height: d)
    color.setStroke()
    let circle = NSBezierPath(ovalIn: glass)
    circle.lineWidth = lineWidth
    circle.stroke()
    let handle = NSBezierPath()
    handle.move(to: NSPoint(x: glass.midX + d * 0.32, y: glass.midY - d * 0.32))
    handle.line(to: NSPoint(x: box.maxX - side * 0.10, y: box.minY + side * 0.12))
    handle.lineWidth = lineWidth * 1.15
    handle.lineCapStyle = .round
    handle.stroke()
}

func makeIcon(pixel: CGFloat) -> NSImage {
    NSImage(size: NSSize(width: pixel, height: pixel), flipped: false) { rect in
        let radius = pixel * 0.2237
        let path = NSBezierPath(roundedRect: rect.insetBy(dx: pixel * 0.02, dy: pixel * 0.02),
                                xRadius: radius, yRadius: radius)
        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.16, green: 0.26, blue: 0.70, alpha: 1),
            NSColor(calibratedRed: 0.30, green: 0.58, blue: 0.96, alpha: 1),
            NSColor(calibratedRed: 0.50, green: 0.84, blue: 0.98, alpha: 1),
        ])
        gradient?.draw(in: path, angle: 135)
        let gloss = NSBezierPath(roundedRect: NSRect(
            x: rect.minX + pixel * 0.08, y: rect.midY,
            width: rect.width - pixel * 0.16, height: rect.height * 0.42
        ), xRadius: radius * 0.5, yRadius: radius * 0.5)
        NSColor.white.withAlphaComponent(0.14).setFill()
        gloss.fill()
        let inset = rect.insetBy(dx: pixel * 0.22, dy: pixel * 0.22)
        drawMagnifier(in: inset, lineWidth: max(2, pixel * 0.055), color: .white)
        let spark = pixel * 0.035
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: rect.maxX - pixel * 0.30, y: rect.maxY - pixel * 0.32,
                                    width: spark * 2, height: spark * 2)).fill()
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
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: url)
}

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "./AppIcon.iconset"
let fm = FileManager.default
try? fm.removeItem(atPath: outDir)
try! fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)

// iconutil 需要的命名
let map: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("diana.k@example.org", 32),
    ("icon_32x32.png", 32),
    ("ivan.p@example.net", 64),
    ("icon_128x128.png", 128),
    ("wendy.h@example.net", 256),
    ("icon_256x256.png", 256),
    ("wendy.h@example.net", 512),
    ("icon_512x512.png", 512),
    ("walt.e@example.net", 1024),
]

for (name, px) in map {
    let img = makeIcon(pixel: CGFloat(px))
    writePNG(img, to: URL(fileURLWithPath: outDir).appendingPathComponent(name), pixel: px)
}

print("iconset ready: \(outDir)")
