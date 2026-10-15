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
        precondition(QuotaView.preferredSize == NSSize(width: 42, height: 124), "compact rings must not grow")
        compact.metrics = WidgetLayoutMetrics(density: .minimal)
        precondition(compact.preferredContentSize.width == 42 * 0.76 && compact.preferredContentSize.height == 124 * 0.76,
                     "minimal density must resize the compact widget without a transform")
        compact.contentOpacity = WidgetOpacityPreset.light.alpha
        precondition(compact.contentOpacity == 0.68, "compact widget must retain the selected opacity")
        let large = LargeQuotaView(frame: NSRect(origin: .zero, size: LargeQuotaView.collapsedSize))
        large.metrics = WidgetLayoutMetrics(density: .compact)
        precondition(large.preferredContentSize.width == 280 * 0.88 && large.preferredContentSize.height == 174 * 0.88,
                     "compact density must resize the large widget")
        large.contentOpacity = WidgetOpacityPreset.translucent.alpha
        precondition(large.contentOpacity == 0.82, "large widget must retain the selected opacity")
        large.snapshot = sample
        let forecasts = QuotaForecasts(fiveHour: QuotaForecast(outcome: .depletedAt(now.addingTimeInterval(3_600)), confidence: .medium), week: .collecting)
        large.forecasts = forecasts
        let staleCompact = QuotaView(frame: .zero)
        staleCompact.snapshot = QuotaSnapshot(fiveHour: sample.fiveHour, week: sample.week, fetchedAt: now.addingTimeInterval(-91))
        staleCompact.forecasts = forecasts
        precondition(staleCompact.forecastText(forecasts.fiveHour, at: now) == "收集中，稍后预测",
                     "stale quota data must suppress a confident depletion forecast")
        let confidenceView = QuotaView(frame: .zero)
        confidenceView.snapshot = sample
        for (confidence, label, color) in [(ForecastConfidence.high, "高", QuotaLevel.ample.color),
                                           (.medium, "中", QuotaLevel.caution.color),
                                           (.low, "低", QuotaLevel.low.color)] {
            let forecast = QuotaForecast(outcome: .depletedAt(now.addingTimeInterval(3_600)), confidence: confidence)
            precondition(confidenceView.forecastText(forecast, at: now).contains("●")
                         && confidenceView.forecastText(forecast, at: now).contains("可信度：\(label)"),
                         "every confidence tier must render a text label and dot")
            precondition(confidenceView.forecastColor(forecast).isEqual(color),
                         "every confidence tier must have a distinct semantic color")
        }
        precondition(confidenceView.forecastText(.unstable, at: now) == "● 消耗速率不稳定，暂不预测",
                     "unstable usage must remain separate from low confidence")
        var clicks = 0
        large.onClick = { large.isExpanded.toggle(); clicks += 1 }
        precondition(large.accessibilityPerformPress())
        precondition(clicks == 1 && large.preferredContentSize.height > LargeQuotaView.collapsedSize.height)
        let expandedHeight = large.preferredContentSize.height
        large.historySamples = [QuotaHistorySample(timestamp: now, fiveHourUsedPercent: 32, weekUsedPercent: 53)]
        large.historyRetention = .session30Minutes
        precondition(large.preferredContentSize.height == expandedHeight,
                     "expanded large card must reserve chart space before samples arrive")
        precondition(large.accessibilityPerformPress())
        precondition(clicks == 2 && large.preferredContentSize.height == large.metrics.largeCollapsed.height,
                     "collapsed large card must return to its fixed compact height")
        large.isExpanded = true
        large.connectionState = .codexNotInstalled
        precondition(large.subviews.compactMap { $0 as? NSButton }.map(\.title) == ["安装 Codex"])
        large.connectionState = .authenticationRequired
        precondition(large.subviews.compactMap { $0 as? NSButton }.isEmpty)
        large.connectionState = .ready
        precondition(large.subviews.compactMap { $0 as? NSButton }.isEmpty)
        large.isExpanded = false

        let root = NSView(frame: NSRect(x: 0, y: 0, width: 620, height: 650))
        root.wantsLayer = true; root.layer?.backgroundColor = NSColor(white: 0.10, alpha: 1).cgColor
        for (index, orientation) in SmallLayout.allCases.enumerated() {
            let view = QuotaView(frame: .zero)
            view.smallLayout = orientation; view.snapshot = sample
            view.frame = NSRect(origin: NSPoint(x: 25 + index * 90, y: 20), size: view.preferredContentSize)
            root.addSubview(view)
        }
        large.frame = NSRect(origin: NSPoint(x: 20, y: 380), size: large.preferredContentSize)
        root.addSubview(large)
        let expanded = LargeQuotaView(frame: .zero)
        expanded.isExpanded = true; expanded.snapshot = sample; expanded.forecasts = forecasts
        expanded.frame = NSRect(origin: NSPoint(x: 320, y: 60), size: expanded.preferredContentSize)
        root.addSubview(expanded)
        let detail = QuotaDetailsView(frame: .zero)
        detail.metrics = WidgetLayoutMetrics(density: .compact)
        detail.contentOpacity = WidgetOpacityPreset.translucent.alpha
        precondition(detail.preferredContentSize.width == 246 * 0.88 && detail.contentOpacity == 0.82,
                     "detail panel must share presentation metrics and opacity")
        detail.snapshot = sample; detail.forecasts = forecasts
        let forecastFields = detail.subviews.compactMap { $0 as? NSTextField }
            .filter { $0.stringValue.contains("预计") }
        precondition(forecastFields.count == 1, "only the five-hour quota should show a depletion forecast")
        precondition(forecastFields[0].stringValue.contains("●") && forecastFields[0].stringValue.contains("可信度：中"),
                     "a five-hour depletion forecast must include a confidence label and color dot")
        precondition(forecastFields[0].textColor?.isEqual(QuotaLevel.caution.color) == true,
                     "a medium-confidence forecast must use the caution color")
        precondition(!detail.subviews.compactMap { $0 as? NSTextField }
            .contains(where: { $0.stringValue == "本周期内不会用尽" }),
                     "weekly quota must not claim a depletion forecast")
        detail.historySamples = []
        let emptyHistoryHeight = detail.preferredContentSize.height
        detail.historySamples = [QuotaHistorySample(timestamp: now, fiveHourUsedPercent: 32, weekUsedPercent: 53)]
        precondition(detail.preferredContentSize.height == emptyHistoryHeight,
                     "compact detail card must reserve chart space for empty and sparse history")
        detail.connectionState = .codexNotInstalled
        precondition(detail.subviews.compactMap { $0 as? NSButton }.map(\.title) == ["安装 Codex"])
        detail.connectionState = .authenticationRequired
        precondition(detail.subviews.compactMap { $0 as? NSButton }.isEmpty)
        detail.connectionState = .ready
        precondition(detail.subviews.compactMap { $0 as? NSButton }.isEmpty)
        let bitmap = root.bitmapImageRepForCachingDisplay(in: root.bounds)!
        root.cacheDisplay(in: root.bounds, to: bitmap)
        if CommandLine.arguments.count > 1 {
            try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
        }
        print("PASS: all layouts, reserved trends, recovery guidance, and sample rendering")
    }
}
