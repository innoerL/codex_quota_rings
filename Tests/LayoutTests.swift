import AppKit

@main struct LayoutTests {
    static func main() throws {
        _ = NSApplication.shared
        let now = Date()
        let sample = QuotaSnapshot(fiveHour: QuotaWindow(usedPercent: 32, windowDurationMins: 300, resetsAt: now.timeIntervalSince1970 + 8760), week: QuotaWindow(usedPercent: 53, windowDurationMins: 10080, resetsAt: now.timeIntervalSince1970 + 295200), fetchedAt: now)
        let compact = QuotaView(frame: NSRect(origin: .zero, size: QuotaView.preferredSize))
        compact.smallLayout = .horizontal
        precondition(compact.preferredContentSize.width > compact.preferredContentSize.height)
        compact.smallLayout = .vertical
        precondition(compact.preferredContentSize.width < compact.preferredContentSize.height)
        let large = LargeQuotaView(frame: NSRect(origin: .zero, size: LargeQuotaView.collapsedSize))
        large.snapshot = sample
        let forecasts = QuotaForecasts(fiveHour: .depletedAt(now.addingTimeInterval(3_600)), week: .withinCurrentWindow)
        let tasks = [
            WidgetTaskStatus(id: "first", title: "迁移目录编写", state: .running),
            WidgetTaskStatus(id: "second", title: "新增礼物赠送记录表", state: .completed)
        ]
        large.forecasts = forecasts
        let staleCompact = QuotaView(frame: .zero)
        staleCompact.snapshot = QuotaSnapshot(fiveHour: sample.fiveHour, week: sample.week, fetchedAt: now.addingTimeInterval(-91))
        staleCompact.forecasts = forecasts
        precondition(staleCompact.forecastText(forecasts.fiveHour, at: now) == "收集中，稍后预测",
                     "stale quota data must suppress a confident depletion forecast")
        var clicks = 0
        large.onClick = { large.isExpanded.toggle(); clicks += 1 }
        precondition(large.accessibilityPerformPress())
        precondition(clicks == 1 && large.preferredContentSize.height > LargeQuotaView.collapsedSize.height)
        let expandedWithoutTasks = large.preferredContentSize.height
        large.taskStatuses = tasks
        precondition(large.preferredContentSize.height > expandedWithoutTasks,
                     "large detail card must add one visible row for each background task")
        precondition(large.accessibilityPerformPress())
        precondition(clicks == 2 && large.preferredContentSize.height > LargeQuotaView.collapsedSize.height
                     && large.preferredContentSize.height < expandedWithoutTasks,
                     "collapsed large card must retain task rows while remaining shorter than details")
        precondition(large.subviews.isEmpty, "large details must be drawn in the same card")

        let root = NSView(frame: NSRect(x: 0, y: 0, width: 620, height: 470))
        root.wantsLayer = true; root.layer?.backgroundColor = NSColor(white: 0.10, alpha: 1).cgColor
        for (index, orientation) in SmallLayout.allCases.enumerated() {
            let view = QuotaView(frame: .zero)
            view.smallLayout = orientation; view.snapshot = sample
            view.frame = NSRect(origin: NSPoint(x: 25 + index * 90, y: 20), size: view.preferredContentSize)
            root.addSubview(view)
        }
        large.frame = NSRect(origin: NSPoint(x: 20, y: 240), size: large.preferredContentSize)
        root.addSubview(large)
        let expanded = LargeQuotaView(frame: .zero)
        expanded.isExpanded = true; expanded.snapshot = sample; expanded.forecasts = forecasts; expanded.taskStatuses = tasks
        expanded.frame = NSRect(origin: NSPoint(x: 320, y: 70), size: expanded.preferredContentSize)
        root.addSubview(expanded)
        let detail = QuotaDetailsView(frame: .zero)
        detail.snapshot = sample; detail.forecasts = forecasts
        let detailWithoutTasks = detail.preferredContentSize.height
        detail.taskStatuses = tasks
        precondition(detail.preferredContentSize.height > detailWithoutTasks,
                     "compact detail card must grow for background task rows")
        let bitmap = root.bitmapImageRepForCachingDisplay(in: root.bounds)!
        root.cacheDisplay(in: root.bounds, to: bitmap)
        if CommandLine.arguments.count > 1 {
            try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
        }
        print("PASS: all layouts, forecast/task expansion, accessibility click and sample rendering")
    }
}
