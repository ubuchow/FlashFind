import AppKit

/// 文本与 placeholder 在控件高度内垂直居中
final class CenteredTextFieldCell: NSTextFieldCell {
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        let ideal = cellSize(forBounds: rect)
        var r = super.drawingRect(forBounds: rect)
        if ideal.height < r.height {
            let dy = (r.height - ideal.height) / 2
            r.origin.y += dy
            r.size.height = ideal.height
        }
        return r
    }

    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        super.edit(withFrame: drawingRect(forBounds: rect), in: controlView, editor: textObj, delegate: delegate, event: event)
    }

    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        super.select(withFrame: drawingRect(forBounds: rect), in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
    }

    override func hitTest(for event: NSEvent, in cellFrame: NSRect, of controlView: NSView) -> NSCell.HitResult {
        .contentArea
    }
}

final class CenteredTextField: NSTextField {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let c = CenteredTextFieldCell(textCell: "")
        c.isEditable = true
        c.isSelectable = true
        c.isScrollable = true
        c.wraps = false
        c.usesSingleLineMode = true
        c.isBordered = false
        c.isBezeled = false
        c.drawsBackground = false
        c.focusRingType = .none
        self.cell = c
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        let c = CenteredTextFieldCell(textCell: stringValue)
        c.isEditable = true
        c.isSelectable = true
        self.cell = c
    }
}
