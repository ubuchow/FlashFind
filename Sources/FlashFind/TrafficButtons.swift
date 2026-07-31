import AppKit

/// 窗口内自绘关闭 / 缩小按钮（避免 fullSizeContentView 下系统红绿灯错位）
final class TrafficButtonsView: NSView {
    var onClose: (() -> Void)?
    var onMinimize: (() -> Void)?

    private let closeBtn = TrafficDotButton(kind: .close)
    private let miniBtn = TrafficDotButton(kind: .minimize)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        closeBtn.target = self
        closeBtn.action = #selector(closeTapped)
        miniBtn.target = self
        miniBtn.action = #selector(miniTapped)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        miniBtn.translatesAutoresizingMaskIntoConstraints = false
        addSubview(closeBtn)
        addSubview(miniBtn)
        NSLayoutConstraint.activate([
            closeBtn.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            closeBtn.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeBtn.widthAnchor.constraint(equalToConstant: 12),
            closeBtn.heightAnchor.constraint(equalToConstant: 12),

            miniBtn.leadingAnchor.constraint(equalTo: closeBtn.trailingAnchor, constant: 8),
            miniBtn.centerYAnchor.constraint(equalTo: centerYAnchor),
            miniBtn.widthAnchor.constraint(equalToConstant: 12),
            miniBtn.heightAnchor.constraint(equalToConstant: 12),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func closeTapped() { onClose?() }
    @objc private func miniTapped() { onMinimize?() }

    override func mouseEntered(with event: NSEvent) { setHover(true) }
    override func mouseExited(with event: NSEvent) { setHover(false) }

    private var tracking: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let t = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(t)
        tracking = t
    }

    private func setHover(_ on: Bool) {
        closeBtn.showGlyph = on
        miniBtn.showGlyph = on
        closeBtn.needsDisplay = true
        miniBtn.needsDisplay = true
    }
}

private final class TrafficDotButton: NSControl {
    enum Kind { case close, minimize }
    let kind: Kind
    var showGlyph = false

    init(kind: Kind) {
        self.kind = kind
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let r = bounds.insetBy(dx: 0.5, dy: 0.5)
        let fill: NSColor
        let stroke: NSColor
        switch kind {
        case .close:
            fill = NSColor(calibratedRed: 1.0, green: 0.38, blue: 0.35, alpha: 1)
            stroke = NSColor(calibratedRed: 0.85, green: 0.22, blue: 0.20, alpha: 1)
        case .minimize:
            fill = NSColor(calibratedRed: 1.0, green: 0.75, blue: 0.20, alpha: 1)
            stroke = NSColor(calibratedRed: 0.88, green: 0.58, blue: 0.05, alpha: 1)
        }
        let path = NSBezierPath(ovalIn: r)
        fill.setFill()
        path.fill()
        stroke.withAlphaComponent(0.45).setStroke()
        path.lineWidth = 0.5
        path.stroke()

        if showGlyph {
            let ink = NSColor.black.withAlphaComponent(0.55)
            ink.setStroke()
            let g = NSBezierPath()
            g.lineWidth = 1.1
            g.lineCapStyle = .round
            switch kind {
            case .close:
                let i = r.insetBy(dx: 3.2, dy: 3.2)
                g.move(to: NSPoint(x: i.minX, y: i.minY))
                g.line(to: NSPoint(x: i.maxX, y: i.maxY))
                g.move(to: NSPoint(x: i.minX, y: i.maxY))
                g.line(to: NSPoint(x: i.maxX, y: i.minY))
            case .minimize:
                let y = r.midY
                g.move(to: NSPoint(x: r.minX + 3, y: y))
                g.line(to: NSPoint(x: r.maxX - 3, y: y))
            }
            g.stroke()
        }
    }

    override func mouseDown(with event: NSEvent) {
        // 按下反馈
        alphaValue = 0.75
    }

    override func mouseUp(with event: NSEvent) {
        alphaValue = 1
        let p = convert(event.locationInWindow, from: nil)
        if bounds.contains(p) {
            sendAction(action, to: target)
        }
    }
}
