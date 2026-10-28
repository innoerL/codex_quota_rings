import AppKit

/// 大卡片在原窗口内展开详情，并调整窗口高度。
final class LargeQuotaView: QuotaView {
    static let collapsedSize = NSSize(width: 280, height: 174)
    struct ExpandedRegions {
        let weeklyReset: NSRect
        let weeklyPace: NSRect
        let forecastBasis: NSRect
        let trend: NSRect
        let accountPlan: NSRect
        let resetCredit: NSRect
        let footer: NSRect
    }
    static func expandedRegions(scale: CGFloat) -> ExpandedRegions {
        ExpandedRegions(
            weeklyReset: NSRect(x: 16 * scale, y: 280 * scale, width: 248 * scale, height: 19 * scale),
            weeklyPace: NSRect(x: 16 * scale, y: 305 * scale, width: 248 * scale, height: 19 * scale),
            forecastBasis: NSRect(x: 12 * scale, y: 336 * scale, width: 256 * scale, height: 42 * scale),
            trend: NSRect(x: 16 * scale, y: 390 * scale, width: 248 * scale, height: 96 * scale),
            accountPlan: NSRect(x: 16 * scale, y: 493 * scale, width: 248 * scale, height: 19 * scale),
            resetCredit: NSRect(x: 16 * scale, y: 513 * scale, width: 248 * scale, height: 19 * scale),
            footer: NSRect(x: 16 * scale, y: 536 * scale, width: 248 * scale, height: 19 * scale)
        )
    }
    private var guidanceHeight: CGFloat { isExpanded && guidanceTitle != nil ? 38 * metrics.scale : 0 }
    override var preferredContentSize: NSSize {
        return NSSize(width: metrics.largeCollapsed.width, height: isExpanded ? metrics.largeExpandedBaseHeight + guidanceHeight : metrics.largeCollapsed.height)
    }
    var historySamples: [QuotaHistorySample] = [] { didSet { needsDisplay = true } }
    var historyRetention: HistoryRetention = .session30Minutes { didSet { needsDisplay = true } }
    var forecastSampleCount = 0 { didSet { needsDisplay = true } }
    var onInstallCodex: (() -> Void)?
    private var guidanceButton: NSButton?
    private var trendHover: QuotaTrendHover? { didSet { needsDisplay = true } }
    private var trendTracking: NSTrackingArea?

    override func expansionDidChange() { rebuildGuidance() }
    override func connectionStateDidChange() { rebuildGuidance() }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trendTracking { removeTrackingArea(trendTracking) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseMoved, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area)
        trendTracking = area
    }
    override func mouseMoved(with event: NSEvent) {
        guard isExpanded else { trendHover = nil; return }
        let scale = metrics.scale
        let trendRect = Self.expandedRegions(scale: scale).trend
        let chart = QuotaTrendRenderer.chartRect(in: trendRect)
        let location = convert(event.locationInWindow, from: nil)
        guard chart.contains(location) else { trendHover = nil; return }
        trendHover = QuotaTrendInteraction.nearestSample(at: (location.x - chart.minX) / max(chart.width, 1), in: historySamples)
    }
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        trendHover = nil
    }
    override func draw(_ dirtyRect: NSRect) {
        let scale = metrics.scale
        let card = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 16, yRadius: 16)
        (lowQuotaContrastMode ? palette.highContrastSurface : palette.surface).setFill(); card.fill()
        (lowQuotaContrastMode ? palette.highContrastBorder : palette.border).setStroke(); card.lineWidth = 1; card.stroke()
        label(showUsed ? localized("已用额度", "Used quota") : localized("剩余额度", "Remaining quota"), x: 16 * scale, y: 16 * scale, size: 12 * scale, weight: .semibold, color: .secondaryLabelColor)
        ring(snapshot?.fiveHour, at: CGPoint(x: 80 * scale, y: 77 * scale), title: localized("5 小时", "5 hours"), radius: metrics.largeRingRadius, isPrimary: true)
        ring(snapshot?.week, at: CGPoint(x: 200 * scale, y: 77 * scale), title: localized("一周", "Week"), radius: metrics.largeRingRadius)
        let stale = connectionError != nil || snapshot?.isStale() == true
        if stale {
            palette.color(for: .caution).withAlphaComponent(0.7).setFill()
            NSBezierPath(ovalIn: NSRect(x: 258 * scale, y: 21 * scale, width: 5 * scale, height: 5 * scale)).fill()
        }
        let status: String
        let statusColor: NSColor
        switch connectionState {
        case .codexNotInstalled: status = localized("未找到 Codex", "Codex was not found"); statusColor = .secondaryLabelColor
        case .authenticationRequired: status = localized("请先在 Codex 中登录", "Please sign in to Codex first"); statusColor = .secondaryLabelColor
        case .disconnected: status = localized("连接中断 · 自动重试", "Connection interrupted · retrying"); statusColor = .secondaryLabelColor
        case .locating where snapshot == nil: status = localized("正在查找 Codex…", "Looking for Codex…"); statusColor = .secondaryLabelColor
        default:
            if showsSpikeHalo {
                status = spikeEvidence?.localizedLabel ?? localized("用量突然升高", "Usage rose sharply"); statusColor = palette.color(for: .low)
            } else if let forecastChange {
                status = forecastChange.localizedLabel; statusColor = palette.color(for: forecastChange.level)
            } else if snapshot?.fiveHour?.isResetImminent() == true {
                status = localized("5 小时额度即将重置", "5-hour quota resets soon"); statusColor = palette.color(for: .caution)
            } else {
                status = snapshot == nil ? localized("正在读取额度…", "Reading quota…") : stale ? localized("数据可能已过期", "Data may be stale") : localized("每 30 秒自动更新", "Updates every 30 seconds")
                statusColor = .secondaryLabelColor
            }
        }
        label(status, x: 16 * scale, y: 148 * scale, size: 10.5 * scale, weight: usageAlert == .spike ? .medium : .regular, color: statusColor)
        let chevron = NSBezierPath()
        chevron.move(to: NSPoint(x: 254 * scale, y: (isExpanded ? 156 : 152) * scale))
        chevron.line(to: NSPoint(x: 258 * scale, y: (isExpanded ? 152 : 156) * scale))
        chevron.line(to: NSPoint(x: 262 * scale, y: (isExpanded ? 156 : 152) * scale))
        NSColor.secondaryLabelColor.setStroke(); chevron.lineWidth = 1.5 * scale; chevron.lineCapStyle = .round; chevron.lineJoinStyle = .round; chevron.stroke()
        if isExpanded {
            let regions = Self.expandedRegions(scale: scale)
            palette.foreground.withAlphaComponent(0.09).setFill()
            NSRect(x: 1, y: metrics.largeCollapsed.height - scale, width: bounds.width-2, height: 0.5 * scale).fill()
            for (index, item) in [(localized("5 小时", "5 hours"), snapshot?.fiveHour, forecasts.fiveHour), (localized("一周", "Week"), snapshot?.week, forecasts.week)].enumerated() {
                let y = CGFloat(191 + index * 66) * scale
                label(item.0, x: 16 * scale, y: y, size: 13 * scale, weight: .medium)
                let used = displayedUsedPercent(for: item.1, isPrimary: index == 0)
                let value = showUsed ? used : used.map { 100 - $0 }
                label(value.map { "\(Int($0.rounded()))%" } ?? "—", x: 212 * scale, y: y, size: 13 * scale, weight: .semibold, color: stale ? .tertiaryLabelColor : .labelColor)
                let resetImminent = index == 0 && item.1?.isResetImminent() == true
                let resetY = index == 0 ? y + 23 * scale : regions.weeklyReset.minY
                label(item.1?.resetDescription() ?? localized("重置时间暂不可用", "Reset time unavailable"), x: 16 * scale, y: resetY, size: 10.5 * scale, weight: resetImminent ? .medium : .regular, color: resetImminent ? palette.color(for: .caution) : .secondaryLabelColor)
                if index == 0 {
                    label(forecastText(item.2), x: 16 * scale, y: y + 41 * scale, size: 10.5 * scale, weight: .medium, color: forecastColor(item.2))
                } else if !stale, let pace = item.1?.weeklyPace(at: snapshot?.fetchedAt ?? Date()) {
                    label(pace.localizedLabel, x: regions.weeklyPace.minX, y: regions.weeklyPace.minY, size: 9.5 * scale,
                          weight: .medium, color: pace.state == .ahead ? palette.color(for: .caution) : .secondaryLabelColor)
                }
            }
            palette.foreground.withAlphaComponent(0.04).setFill()
            NSBezierPath(roundedRect: regions.forecastBasis,
                         xRadius: 7 * scale, yRadius: 7 * scale).fill()
            let basisStyle = NSMutableParagraphStyle()
            basisStyle.lineBreakMode = .byWordWrapping
            (forecasts.fiveHour.explanation as NSString).draw(
                in: regions.forecastBasis.insetBy(dx: 4 * scale, dy: 5 * scale),
                withAttributes: [.font: NSFont.systemFont(ofSize: 9.5 * scale),
                                 .foregroundColor: NSColor.secondaryLabelColor,
                                 .paragraphStyle: basisStyle]
            )
            let trendRect = regions.trend
            QuotaTrendRenderer.draw(samples: historySamples, retention: historyRetention, in: trendRect,
                                    appearance: effectiveAppearance)
            if let trendHover, let range = QuotaTrendRenderer.timeRange(for: historySamples) {
                let span = range.end.timeIntervalSince(range.start)
                let position = span > 0 ? trendHover.sample.timestamp.timeIntervalSince(range.start) / span : 0
                QuotaTrendRenderer.drawHover(trendHover, position: position, in: trendRect,
                                             appearance: effectiveAppearance)
            }
            if let snapshot {
                label(snapshot.planDescription, x: regions.accountPlan.minX, y: regions.accountPlan.minY, size: 10 * scale, color: .secondaryLabelColor)
                if let credit = snapshot.resetCreditCompactDescription {
                    label(credit, x: regions.resetCredit.minX, y: regions.resetCredit.minY, size: 10 * scale, color: .secondaryLabelColor)
                }
            }
            let format = DateFormatter(); format.dateFormat = "HH:mm:ss"
            let footer = snapshot.map {
                localized("最近更新 \(format.string(from: $0.fetchedAt)) · 预测采样 \(forecastSampleCount) 个", "Updated \(format.string(from: $0.fetchedAt)) · \(forecastSampleCount) forecast samples")
            } ?? localized("等待额度数据", "Waiting for quota data")
            label(footer, x: regions.footer.minX, y: regions.footer.minY, size: 10 * scale, color: .secondaryLabelColor)
        }
    }
    private var guidanceTitle: String? {
        switch connectionState {
        case .codexNotInstalled: return localized("安装 Codex", "Install Codex")
        default: return nil
        }
    }
    private func rebuildGuidance() {
        guidanceButton?.removeFromSuperview(); guidanceButton = nil
        guard isExpanded, let title = guidanceTitle else { return }
        let button = NSButton(title: title, target: self, action: #selector(installCodex))
        button.bezelStyle = .rounded; button.controlSize = .small
        let scale = metrics.scale
        button.frame = NSRect(x: 16 * scale, y: metrics.largeExpandedBaseHeight + 4 * scale, width: 104 * scale, height: 28 * scale)
        addSubview(button); guidanceButton = button
    }
    @objc private func installCodex() { onInstallCodex?() }
    private func label(_ value: String, x: CGFloat, y: CGFloat, width: CGFloat? = nil, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .labelColor, alignment: NSTextAlignment = .left) {
        let style = NSMutableParagraphStyle(); style.lineBreakMode = .byTruncatingTail
        style.alignment = alignment
        (value as NSString).draw(in: NSRect(x: x, y: y, width: width ?? bounds.width-x-14, height: 19), withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: style])
    }
}
