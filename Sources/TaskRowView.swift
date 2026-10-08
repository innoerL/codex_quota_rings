import AppKit

final class TaskRowView: NSView {
    var status: WidgetTaskStatus { didSet { updateLabels() } }
    var now: Date = Date() { didSet { updateLabels() } }
    var onClick: ((String) -> Void)?
    let titleField = NSTextField(labelWithString: "")
    let statusField = NSTextField(labelWithString: "")
    private(set) var isHovered = false
    let usesPointingHandCursor = true
    private var tracking: NSTrackingArea?
    private var pressed = false

    init(status: WidgetTaskStatus, frame: CGRect) {
        self.status = status
        super.init(frame: frame)
        wantsLayer = true
        titleField.font = .systemFont(ofSize: 10.5)
        titleField.textColor = .secondaryLabelColor
        titleField.lineBreakMode = .byTruncatingTail
        titleField.maximumNumberOfLines = 1
        titleField.isSelectable = false
        statusField.font = .systemFont(ofSize: 9.5, weight: .medium)
        statusField.alignment = .right
        statusField.lineBreakMode = .byClipping
        statusField.isSelectable = false
        addSubview(titleField); addSubview(statusField)
        setAccessibilityElement(true); setAccessibilityRole(.button)
        updateLabels()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func layout() {
        super.layout()
        let statusWidth = min(132, max(108, bounds.width * 0.54))
        titleField.frame = NSRect(x: 6, y: 5, width: max(20, bounds.width - statusWidth - 14), height: 17)
        statusField.frame = NSRect(x: bounds.width - statusWidth - 6, y: 5, width: statusWidth, height: 17)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area); tracking = area
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { isHovered = false; pressed = false; needsDisplay = true }
    override func mouseDown(with event: NSEvent) { pressed = true; needsDisplay = true }
    override func mouseUp(with event: NSEvent) {
        guard pressed else { return }
        pressed = false; needsDisplay = true; onClick?(status.id)
    }
    override func accessibilityPerformPress() -> Bool { onClick?(status.id); return true }

    override func draw(_ dirtyRect: NSRect) {
        if isHovered || pressed {
            NSColor.white.withAlphaComponent(pressed ? 0.10 : 0.065).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6).fill()
        }
    }

    private func updateLabels() {
        titleField.stringValue = status.title
        statusField.stringValue = TaskDurationFormatter.string(for: status, at: now)
        statusField.textColor = TaskStatusPalette.color(for: status.state)
        setAccessibilityLabel("\(status.title)，\(statusField.stringValue)")
    }
}
