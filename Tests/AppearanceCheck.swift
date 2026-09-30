import AppKit

final class PreviewSurface: NSView {
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor(white: 0.9, alpha: 1).setFill(); bounds.fill()
        NSColor(white: 0.13, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 0, y: -20, width: 62, height: 240), xRadius: 16, yRadius: 16).fill()
    }
}

@main struct AppearanceCheck {
    static func main() throws {
        _ = NSApplication.shared
        let now = Date()
        let snapshot = QuotaSnapshot(fiveHour: QuotaWindow(usedPercent: 32, windowDurationMins: 300, resetsAt: now.timeIntervalSince1970 + 8760), week: QuotaWindow(usedPercent: 53, windowDurationMins: 10080, resetsAt: now.timeIntervalSince1970 + 295200), fetchedAt: now)
        let root = PreviewSurface(frame: NSRect(x: 0, y: 0, width: 324, height: 224))
        let compact = QuotaView(frame: NSRect(origin: NSPoint(x: 5, y: 44), size: QuotaView.preferredSize))
        compact.snapshot = snapshot
        let card = QuotaDetailsView(frame: NSRect(origin: NSPoint(x: 55, y: 8), size: QuotaDetailsView.preferredSize))
        card.snapshot = snapshot
        root.addSubview(compact); root.addSubview(card)
        var opened = 0
        compact.onClick = { opened += 1 }
        let down = NSEvent.mouseEvent(with: .leftMouseDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)!
        let up = NSEvent.mouseEvent(with: .leftMouseUp, location: .zero, modifierFlags: [], timestamp: 0.1, windowNumber: 0, context: nil, eventNumber: 2, clickCount: 1, pressure: 0)!
        compact.mouseDown(with: down); compact.mouseUp(with: up)
        guard opened == 1 else { fatalError("click must open detail once") }
        guard card.subviews.compactMap({ $0 as? NSButton }).isEmpty else {
            fputs("FAIL: detail card must not contain a refresh button\n", stderr); exit(1)
        }
        let bitmap = root.bitmapImageRepForCachingDisplay(in: root.bounds)!
        root.cacheDisplay(in: root.bounds, to: bitmap)
        guard (bitmap.colorAt(x: 7, y: 46)?.alphaComponent ?? 0) > 0.99 else {
            fputs("FAIL: transparent widget erased the sidebar background\n", stderr); exit(1)
        }
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
        print("PASS: compact click, no refresh button, transparent compositing and native appearance render (sample values)")
    }
}
