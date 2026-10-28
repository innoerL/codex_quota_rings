import AppKit

final class PreviewSurface: NSView {
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor(white: 0.9, alpha: 1).setFill(); bounds.fill()
        NSColor(white: 0.13, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 0, y: -20, width: 62, height: 320), xRadius: 16, yRadius: 16).fill()
    }
}

@main struct AppearanceCheck {
    static func main() throws {
        _ = NSApplication.shared
        let now = Date()
        let snapshot = QuotaSnapshot(fiveHour: QuotaWindow(usedPercent: 32, windowDurationMins: 300, resetsAt: now.timeIntervalSince1970 + 8760), week: QuotaWindow(usedPercent: 53, windowDurationMins: 10080, resetsAt: now.timeIntervalSince1970 + 295200), fetchedAt: now)
        let root = PreviewSurface(frame: NSRect(x: 0, y: 0, width: 324, height: 370))
        root.appearance = NSAppearance(named: .darkAqua)
        let compact = QuotaView(frame: NSRect(origin: NSPoint(x: 5, y: 44), size: QuotaView.preferredSize))
        compact.contentOpacity = WidgetOpacityPreset.light.alpha
        precondition(compact.contentOpacity == 0.68, "the compact surface must expose its effective opacity")
        compact.snapshot = snapshot
        let card = QuotaDetailsView(frame: NSRect(origin: NSPoint(x: 55, y: 8), size: QuotaDetailsView.preferredSize))
        card.contentOpacity = WidgetOpacityPreset.translucent.alpha
        precondition(card.contentOpacity == 0.82, "the detail surface must expose its effective opacity")
        card.snapshot = snapshot
        card.forecasts = QuotaForecasts(fiveHour: QuotaForecast(outcome: .depletedAt(now.addingTimeInterval(3_600)), confidence: .medium), week: .collecting)
        card.historySamples = [
            QuotaHistorySample(timestamp: now.addingTimeInterval(-600), fiveHourUsedPercent: 20, weekUsedPercent: 45),
            QuotaHistorySample(timestamp: now, fiveHourUsedPercent: 32, weekUsedPercent: 53)
        ]
        card.frame.size = card.preferredContentSize
        let minimal = QuotaView(frame: NSRect(x: 5, y: 230, width: 42, height: 42))
        minimal.metrics = WidgetLayoutMetrics(density: .minimal)
        minimal.snapshot = snapshot
        root.addSubview(compact); root.addSubview(minimal); root.addSubview(card)
        precondition(compact.palette.isDark && minimal.palette.isDark
                     && WidgetAppearancePalette(appearance: card.effectiveAppearance).isDark,
                     "深色系统外观应传递到所有组件")
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
        let output = URL(fileURLWithPath: CommandLine.arguments[1])
        try bitmap.representation(using: .png, properties: [:])!.write(to: output)
        root.appearance = NSAppearance(named: .aqua)
        precondition(!compact.palette.isDark && !minimal.palette.isDark
                     && !WidgetAppearancePalette(appearance: card.effectiveAppearance).isDark,
                     "系统切换浅色外观时组件应立即继承新外观")
        let lightBitmap = root.bitmapImageRepForCachingDisplay(in: root.bounds)!
        root.cacheDisplay(in: root.bounds, to: lightBitmap)
        let lightOutput = output.deletingLastPathComponent()
            .appendingPathComponent(output.deletingPathExtension().lastPathComponent + "-light.png")
        try lightBitmap.representation(using: .png, properties: [:])!.write(to: lightOutput)
        print("PASS: compact click, no refresh button, and dark/light appearance renders")
    }
}
