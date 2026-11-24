import AppKit

final class SelectionPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    var onCancel: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onCancel?() } else { super.keyDown(with: event) }
    }
}

final class SelectionView: NSView {
    private var first: CGPoint?
    private var last: CGPoint?
    var onSelect: ((CGRect) -> Void)?

    override var isFlipped: Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }

    override func mouseDown(with event: NSEvent) {
        first = convert(event.locationInWindow, from: nil)
        last = first
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        last = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        mouseDragged(with: event)
        if let selected, selected.width >= 80, selected.height >= 100 { onSelect?(selected) }
    }

    private var selected: CGRect? {
        guard let first, let last else { return nil }
        return CGRect(x: min(first.x, last.x), y: min(first.y, last.y),
                      width: abs(first.x - last.x), height: abs(first.y - last.y)).intersection(bounds)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.33).setFill()
        bounds.fill()
        if let selected {
            NSColor.controlAccentColor.withAlphaComponent(0.22).setFill()
            selected.fill()
            NSColor.white.setStroke()
            let outline = NSBezierPath(rect: selected)
            outline.lineWidth = 2
            outline.stroke()
        }
        let text = "Drag around the iPhone screen  ·  Esc to cancel" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let size = text.size(withAttributes: attributes)
        let origin = CGPoint(x: max(6, (bounds.width - size.width) / 2), y: 12)
        NSColor.black.withAlphaComponent(0.82).setFill()
        NSBezierPath(roundedRect: CGRect(x: origin.x - 7, y: 6, width: size.width + 14, height: size.height + 12),
                     xRadius: 8, yRadius: 8).fill()
        text.draw(at: origin, withAttributes: attributes)
    }
}
