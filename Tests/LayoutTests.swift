import AppKit

@main struct LayoutTests {
    static func main() throws {
        _ = NSApplication.shared
        NSApp.appearance = NSAppearance(named: .darkAqua)
        let now = Date()
        let sample = QuotaSnapshot(fiveHour: QuotaWindow(usedPercent: 32, windowDurationMins: 300, resetsAt: now.timeIntervalSince1970 + 8760), week: QuotaWindow(usedPercent: 53, windowDurationMins: 10080, resetsAt: now.timeIntervalSince1970 + 295200), resetCreditCount: 2, earliestResetCreditExpiration: now.addingTimeInterval(2 * 86_400), planName: "Plus", fetchedAt: now)
        let metadataDetail = QuotaDetailsView(frame: NSRect(origin: .zero, size: QuotaDetailsView.preferredSize))
        metadataDetail.snapshot = sample
        let detailText = metadataDetail.subviews.compactMap { ($0 as? NSTextField)?.stringValue }
        precondition(detailText.contains("当前套餐：Plus")
                     && detailText.contains(where: { $0.contains("重置卡 × 2 · 最近到期") }),
                     "小型额度详情应显示套餐和最早到期的重置卡")
        let creditField = metadataDetail.subviews.compactMap { $0 as? NSTextField }
            .first { $0.stringValue.contains("最近到期") }!
        precondition((creditField.stringValue as NSString).size(withAttributes: [.font: creditField.font!]).width <= creditField.frame.width,
                     "小型额度详情应完整显示重置卡到期时间")
        let compact = QuotaView(frame: NSRect(origin: .zero, size: QuotaView.preferredSize))
        compact.smallLayout = .horizontal
        precondition(compact.preferredContentSize.width > compact.preferredContentSize.height)
        compact.smallLayout = .vertical
        precondition(compact.preferredContentSize.width < compact.preferredContentSize.height)
        precondition(QuotaView.preferredSize == NSSize(width: 42, height: 124), "compact rings must not grow")
        compact.metrics = WidgetLayoutMetrics(density: .minimal)
        precondition(QuotaView.minimalTopArc.upperBound - QuotaView.minimalTopArc.lowerBound == 108
                     && QuotaView.minimalBottomArc.upperBound - QuotaView.minimalBottomArc.lowerBound == 192,
                     "上弧应明显短于下弧")
        precondition(compact.preferredContentSize == NSSize(width: 42, height: 42),
                     "minimal density must use the single-ring tile size")
        compact.smallLayout = .horizontal
        precondition(compact.preferredContentSize == NSSize(width: 42, height: 42),
                     "minimal density must keep one ring regardless of the saved orientation")
        compact.snapshot = sample
        precondition(compact.minimalFiveHourArc == QuotaView.minimalTopArc)
        compact.minimalArcOrder = .weekTop
        precondition(compact.minimalFiveHourArc == QuotaView.minimalBottomArc
                     && compact.minimalCenterText() == "68%"
                     && compact.toolTip?.contains("上方：一周") == true,
                     "调换弧线后，5 小时数据应移至下弧且圆心仍显示 5 小时百分比")
        compact.minimalArcOrder = .fiveHourTop
        precondition(!compact.showsSpikeHalo)
        compact.usageAlert = .spike
        compact.spikeEvidence = QuotaSpikeEvidence(recentIncrease: 4, speedMultiplier: 10)
        compact.ringFeedback = .surgeHalo
        compact.ringFeedbackPhase = 0.5
        precondition(compact.showsSpikeHalo,
                     "极简模式应在用量突增时显示扩散光环")
        precondition(compact.toolTip?.contains("近 5 分钟 +4.0%") == true,
                     "极简模式的悬停说明应解释扩散光环原因")
        compact.usageAlert = .none
        precondition(!compact.showsSpikeHalo && compact.toolTip?.contains("用量突增：") != true,
                     "用量恢复平稳后应停止光环及原因提示")
        let standardSpike = QuotaView(frame: NSRect(origin: .zero, size: QuotaView.preferredSize))
        standardSpike.snapshot = sample
        standardSpike.usageAlert = .spike
        standardSpike.ringFeedback = .surgeHalo
        standardSpike.ringFeedbackPhase = 0.5
        precondition(standardSpike.showsSpikeHalo,
                     "标准模式应在用量突增时显示扩散光环")
        precondition(compact.minimalCenterText() == "68%",
                     "the minimal center must show five-hour remaining quota")
        compact.showUsed = true
        precondition(compact.minimalCenterText() == "32%",
                     "the minimal center must respect the used-quota setting")
        compact.showUsed = false
        compact.snapshot = nil
        precondition(compact.minimalCenterText() == "—",
                     "the minimal center must not invent a percentage when quota is unavailable")
        compact.contentOpacity = WidgetOpacityPreset.light.alpha
        precondition(compact.contentOpacity == 0.68, "compact widget must retain the selected opacity")
        AppLanguageManager.current = .english
        compact.snapshot = sample; compact.updateTooltip()
        precondition(compact.toolTip?.contains("remaining quota") == true,
                     "English language setting must refresh compact widget copy")
        AppLanguageManager.current = .chinese
        compact.lowQuotaContrastMode = true
        precondition(compact.toolTip?.contains("低额度高对比模式") == true,
                     "low quota mode must expose its high-contrast state to assistive text")
        let large = LargeQuotaView(frame: NSRect(origin: .zero, size: LargeQuotaView.collapsedSize))
        large.metrics = WidgetLayoutMetrics(density: .minimal)
        precondition(large.preferredContentSize == LargeQuotaView.collapsedSize,
                     "大卡片在极简模式下不应缩小")
        large.contentOpacity = WidgetOpacityPreset.translucent.alpha
        precondition(large.contentOpacity == 0.82, "large widget must retain the selected opacity")
        large.snapshot = sample
        let forecasts = QuotaForecasts(fiveHour: QuotaForecast(
            outcome: .depletedAt(now.addingTimeInterval(3_600)),
            confidence: .medium,
            depletionRange: DateInterval(start: now.addingTimeInterval(3_000), end: now.addingTimeInterval(4_500))
        ), week: .collecting)
        large.forecasts = forecasts
        large.forecastSampleCount = 6
        large.usageAlert = .spike
        large.ringFeedback = .surgeHalo
        large.ringFeedbackPhase = 0.5
        precondition(large.showsSpikeHalo,
                     "大卡片的 5 小时圆环也应支持扩散光环")
        let regions = LargeQuotaView.expandedRegions(scale: 1)
        precondition(regions.weeklyReset.maxY + 4 <= regions.weeklyPace.minY
                     && regions.weeklyPace.maxY + 8 <= regions.forecastBasis.minY
                     && regions.forecastBasis.maxY + 8 <= regions.trend.minY
                     && regions.trend.maxY + 4 <= regions.accountPlan.minY
                     && regions.accountPlan.maxY <= regions.resetCredit.minY
                     && regions.resetCredit.maxY + 4 <= regions.footer.minY
                     && regions.footer.maxY + 8 <= large.metrics.largeExpandedBaseHeight,
                     "大卡片展开后的一周文字、预测依据、趋势图和页脚不得重叠")
        func fiveHourRingImage(resetAfter seconds: TimeInterval) -> NSBitmapImageRep {
            let view = LargeQuotaView(frame: NSRect(origin: .zero, size: LargeQuotaView.collapsedSize))
            view.appearance = NSAppearance(named: .darkAqua)
            view.snapshot = QuotaSnapshot(
                fiveHour: QuotaWindow(usedPercent: 84, windowDurationMins: 300,
                                      resetsAt: now.addingTimeInterval(seconds).timeIntervalSince1970),
                week: sample.week, fetchedAt: now
            )
            let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
            view.cacheDisplay(in: view.bounds, to: bitmap)
            return bitmap
        }
        let imminentRing = fiveHourRingImage(resetAfter: 10 * 60)
        let ordinaryRing = fiveHourRingImage(resetAfter: 60 * 60)
        let pixelScale = CGFloat(imminentRing.pixelsWide) / LargeQuotaView.collapsedSize.width
        for x in Int(48 * pixelScale)..<Int(113 * pixelScale) {
            for y in Int(44 * pixelScale)..<Int(110 * pixelScale) {
                precondition(imminentRing.colorAt(x: x, y: y)?.isEqual(ordinaryRing.colorAt(x: x, y: y)!) == true,
                             "临近重置时，5 小时圆环上不应再额外绘制提示点")
            }
        }
        let staleCompact = QuotaView(frame: .zero)
        staleCompact.snapshot = QuotaSnapshot(fiveHour: sample.fiveHour, week: sample.week, fetchedAt: now.addingTimeInterval(-91))
        staleCompact.forecasts = forecasts
        staleCompact.hasForecastSampleData = true
        precondition(staleCompact.forecastText(forecasts.fiveHour, at: now).isEmpty,
                     "stale quota data must suppress a confident depletion forecast without showing collection text")
        let collectingCompact = QuotaView(frame: .zero)
        precondition(collectingCompact.forecastText(.collecting, at: now) == "收集中，稍后开始预测",
                     "missing forecast sampling must show collection text")
        collectingCompact.snapshot = sample
        precondition(collectingCompact.forecastText(.collecting, at: now) == "收集中，稍后开始预测",
                     "a quota snapshot alone must not hide the collection state")
        collectingCompact.hasForecastSampleData = true
        precondition(collectingCompact.forecastText(.collecting, at: now).isEmpty,
                     "existing forecast samples must collect silently in the background")
        let confidenceView = QuotaView(frame: .zero)
        confidenceView.snapshot = sample
        confidenceView.hasForecastSampleData = true
        for (confidence, label, color) in [(ForecastConfidence.high, "高", QuotaLevel.ample.color),
                                           (.medium, "中", QuotaLevel.caution.color),
                                           (.low, "低", QuotaLevel.low.color)] {
            let forecast = QuotaForecast(
                outcome: .depletedAt(now.addingTimeInterval(3_600)),
                confidence: confidence,
                depletionRange: DateInterval(start: now.addingTimeInterval(3_000), end: now.addingTimeInterval(4_500))
            )
            precondition(confidenceView.forecastText(forecast, at: now).contains("●")
                         && confidenceView.forecastText(forecast, at: now).contains("约")
                         && confidenceView.forecastText(forecast, at: now).contains("可信度：\(label)"),
                         "every confidence tier must render a text label and dot")
            precondition(confidenceView.forecastColor(forecast).isEqual(color),
                         "every confidence tier must have a distinct semantic color")
        }
        precondition(confidenceView.forecastText(.unstable, at: now) == "● 消耗速率不稳定，暂不预测",
                     "unstable usage must remain separate from low confidence")
        let imminentSnapshot = QuotaSnapshot(fiveHour: QuotaWindow(usedPercent: 32, windowDurationMins: 300,
                                                                     resetsAt: now.addingTimeInterval(10 * 60).timeIntervalSince1970),
                                            week: sample.week, fetchedAt: now)
        confidenceView.snapshot = imminentSnapshot; confidenceView.usageAlert = .spike
        precondition(confidenceView.toolTip?.contains("用量突然升高") == true
                     && confidenceView.toolTip?.contains("5 小时额度即将重置") == true,
                     "compact widget accessibility text must expose both local signals")
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

        let transitionView = QuotaView(frame: .zero)
        transitionView.metrics = WidgetLayoutMetrics(density: .minimal)
        transitionView.snapshot = sample
        let refreshedAt = Date()
        transitionView.snapshot = QuotaSnapshot(
            fiveHour: QuotaWindow(usedPercent: 48, windowDurationMins: 300, resetsAt: sample.fiveHour?.resetsAt),
            week: QuotaWindow(usedPercent: 60, windowDurationMins: 10_080, resetsAt: sample.week?.resetsAt),
            fetchedAt: refreshedAt.addingTimeInterval(1)
        )
        precondition(transitionView.isQuotaTransitionActive, "两段弧线应在额度刷新后开始动画")
        precondition(transitionView.displayedUsedPercent(for: transitionView.snapshot?.fiveHour,
                                                          isPrimary: true) ?? 100 < 48,
                     "极简模式的 5 小时额度应从旧读数开始过渡")
        precondition(transitionView.displayedUsedPercent(for: transitionView.snapshot?.week,
                                                          isPrimary: false) ?? 100 < 60,
                     "极简模式的一周额度应独立过渡")
        _ = transitionView.advanceQuotaTransition(at: refreshedAt.addingTimeInterval(2))
        precondition(!transitionView.isQuotaTransitionActive
                     && transitionView.minimalCenterText() == "52%",
                     "动画结束后圆心和弧线应显示完整新读数")
        transitionView.snapshot = QuotaSnapshot(
            fiveHour: QuotaWindow(usedPercent: 5, windowDurationMins: 300,
                                  resetsAt: refreshedAt.addingTimeInterval(20_000).timeIntervalSince1970),
            week: transitionView.snapshot?.week, fetchedAt: refreshedAt.addingTimeInterval(3)
        )
        precondition(!transitionView.isQuotaTransitionActive && transitionView.minimalCenterText() == "95%",
                     "额度重置直接切换到新读数")

        let root = NSView(frame: NSRect(x: 0, y: 0, width: 620, height: 650))
        root.appearance = NSAppearance(named: .darkAqua)
        root.wantsLayer = true; root.layer?.backgroundColor = NSColor(white: 0.10, alpha: 1).cgColor
        for (index, orientation) in SmallLayout.allCases.enumerated() {
            let view = QuotaView(frame: .zero)
            view.smallLayout = orientation; view.snapshot = sample
            view.usageAlert = .spike; view.ringFeedback = .surgeHalo; view.ringFeedbackPhase = 0.5
            view.frame = NSRect(origin: NSPoint(x: 25 + index * 90, y: 20), size: view.preferredContentSize)
            root.addSubview(view)
        }
        let minimal = QuotaView(frame: .zero)
        minimal.metrics = WidgetLayoutMetrics(density: .minimal)
        minimal.snapshot = sample
        minimal.frame = NSRect(origin: NSPoint(x: 230, y: 20), size: minimal.preferredContentSize)
        root.addSubview(minimal)
        large.frame = NSRect(origin: NSPoint(x: 20, y: 380), size: large.preferredContentSize)
        root.addSubview(large)
        let expanded = LargeQuotaView(frame: .zero)
        let previewSnapshot = QuotaSnapshot(
            fiveHour: QuotaWindow(usedPercent: 84, windowDurationMins: 300,
                                  resetsAt: now.addingTimeInterval(10 * 60).timeIntervalSince1970),
            week: QuotaWindow(usedPercent: 47, windowDurationMins: 10_080,
                              resetsAt: now.addingTimeInterval(5 * 24 * 3_600).timeIntervalSince1970),
            resetCreditCount: 2, earliestResetCreditExpiration: now.addingTimeInterval(2 * 86_400),
            planName: "Plus",
            fetchedAt: now
        )
        expanded.isExpanded = true; expanded.snapshot = previewSnapshot
        expanded.forecasts = QuotaForecasts(
            fiveHour: QuotaForecast(outcome: .willNotDeplete, confidence: .high,
                                    sampleCount: 60, observedSpan: 29 * 60, hourlyConsumption: 50.8),
            week: .collecting
        )
        expanded.hasForecastSampleData = true
        expanded.forecastSampleCount = 60
        expanded.historySamples = [
            QuotaHistorySample(timestamp: now.addingTimeInterval(-300), fiveHourUsedPercent: 80, weekUsedPercent: 45),
            QuotaHistorySample(timestamp: now, fiveHourUsedPercent: 84, weekUsedPercent: 47)
        ]
        expanded.frame = NSRect(origin: NSPoint(x: 320, y: 60), size: expanded.preferredContentSize)
        root.addSubview(expanded)
        let detail = QuotaDetailsView(frame: .zero)
        detail.metrics = WidgetLayoutMetrics(density: .minimal)
        detail.contentOpacity = WidgetOpacityPreset.translucent.alpha
        precondition(detail.preferredContentSize == QuotaDetailsView.preferredSize && detail.contentOpacity == 0.82,
                     "额度详情在极简模式下仍保持标准尺寸")
        detail.snapshot = sample; detail.forecasts = forecasts; detail.hasForecastSampleData = true; detail.forecastSampleCount = 6
        AppLanguageManager.current = .english; detail.refreshLanguage()
        precondition(detail.subviews.compactMap { $0 as? NSTextField }.contains(where: { $0.stringValue == "5 hours" }),
                     "English language setting must refresh detail headings")
        AppLanguageManager.current = .chinese; detail.refreshLanguage()
        let forecastFields = detail.subviews.compactMap { $0 as? NSTextField }
            .filter { $0.stringValue.contains("约") && $0.stringValue.contains("用尽") }
        precondition(forecastFields.count == 1, "only the five-hour quota should show a depletion forecast")
        precondition(forecastFields[0].stringValue.contains("●")
                     && forecastFields[0].stringValue.contains("–")
                     && forecastFields[0].stringValue.contains("可信度：中"),
                     "a five-hour depletion forecast must include an interval, confidence label, and color dot")
        precondition(forecastFields[0].textColor?.isEqual(QuotaLevel.caution.color) == true,
                     "a medium-confidence forecast must use the caution color")
        precondition(detail.subviews.compactMap { $0 as? NSTextField }
            .contains(where: { $0.stringValue == "采样 6" }),
                     "detail card must show the active forecast sample count")
        precondition(!detail.subviews.compactMap { $0 as? NSTextField }
            .contains(where: { $0.stringValue == "本周期内不会用尽" }),
                     "weekly quota must not claim a depletion forecast")
        precondition(detail.subviews.compactMap { $0 as? NSTextField }
            .contains(where: { $0.stringValue.contains("周节奏：已用 53%") }),
                     "一周额度详情应显示已用与已过时间的节奏比较")
        detail.snapshot = QuotaSnapshot(
            fiveHour: QuotaWindow(usedPercent: 48, windowDurationMins: 300, resetsAt: sample.fiveHour?.resetsAt),
            week: QuotaWindow(usedPercent: 60, windowDurationMins: 10_080, resetsAt: sample.week?.resetsAt),
            fetchedAt: Date().addingTimeInterval(1)
        )
        precondition(detail.isQuotaTransitionActive, "额度详情百分比应与圆环同步过渡")
        _ = detail.advanceQuotaTransition(at: Date().addingTimeInterval(1))
        precondition(!detail.isQuotaTransitionActive
                     && detail.subviews.compactMap { $0 as? NSTextField }.contains(where: { $0.stringValue == "52%" })
                     && detail.subviews.compactMap { $0 as? NSTextField }.contains(where: { $0.stringValue == "40%" }),
                     "额度详情动画结束后应显示两项新读数")
        detail.snapshot = imminentSnapshot; detail.usageAlert = .spike
        detail.spikeEvidence = QuotaSpikeEvidence(recentIncrease: 4, speedMultiplier: 10)
        precondition(detail.subviews.compactMap { $0 as? NSTextField }
            .contains(where: { $0.stringValue.contains("近 5 分钟 +4.0%") && $0.textColor?.isEqual(QuotaLevel.low.color) == true }),
                     "详情卡片应以状态色解释扩散光环原因")
        precondition(detail.subviews.compactMap { $0 as? NSTextField }
            .contains(where: { $0.stringValue.contains("后重置") && $0.textColor?.isEqual(QuotaLevel.caution.color) == true }),
                     "detail card must emphasize an imminent five-hour reset")
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
            let output = URL(fileURLWithPath: CommandLine.arguments[1])
            try bitmap.representation(using: .png, properties: [:])!.write(to: output)
            let expandedBitmap = expanded.bitmapImageRepForCachingDisplay(in: expanded.bounds)!
            expanded.cacheDisplay(in: expanded.bounds, to: expandedBitmap)
            let expandedOutput = output.deletingLastPathComponent().appendingPathComponent("expanded-preview.png")
            try expandedBitmap.representation(using: .png, properties: [:])!.write(to: expandedOutput)
            root.appearance = NSAppearance(named: .aqua)
            precondition(!large.palette.isDark && !expanded.palette.isDark && !minimal.palette.isDark,
                         "大卡片、标准和极简布局应跟随系统切换为浅色外观")
            let lightBitmap = root.bitmapImageRepForCachingDisplay(in: root.bounds)!
            root.cacheDisplay(in: root.bounds, to: lightBitmap)
            let lightOutput = output.deletingLastPathComponent()
                .appendingPathComponent(output.deletingPathExtension().lastPathComponent + "-light.png")
            try lightBitmap.representation(using: .png, properties: [:])!.write(to: lightOutput)
        }
        print("PASS: all layouts, reserved trends, recovery guidance, and sample rendering")
    }
}
