import AppKit

/// A single window surface: opening details changes its height, never opens a popover.
final class LargeQuotaView: QuotaView {
    static let collapsedSize = NSSize(width: 280, height: 174)
    private static let expandedBaseHeight: CGFloat = 456
    private var guidanceHeight: CGFloat { isExpanded && guidanceTitle != nil ? 38 * metrics.scale : 0 }
    override var preferredContentSize: NSSize {
        NSSize(width: metrics.largeCollapsed.width, height: isExpanded ? metrics.largeExpandedBaseHeight + guidanceHeight : metrics.largeCollapsed.height)
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
        let trendRect = NSRect(x: 16 * scale, y: 322 * scale, width: 248 * scale, height: 96 * scale)
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
        NSColor(white: lowQuotaContrastMode ? 0.09 : 0.14, alpha: lowQuotaContrastMode ? 1 : 0.97).setFill(); card.fill()
        NSColor.white.withAlphaComponent(lowQuotaContrastMode ? 0.20 : 0.11).setStroke(); card.lineWidth = 1; card.stroke()
        label(showUsed ? "已用额度" : "剩余额度", x: 16 * scale, y: 16 * scale, size: 12 * scale, weight: .semibold, color: .secondaryLabelColor)
        ring(snapshot?.fiveHour, at: CGPoint(x: 80 * scale, y: 77 * scale), title: "5 小时", radius: metrics.largeRingRadius, resetEmphasis: snapshot?.fiveHour?.isResetImminent() == true)
        ring(snapshot?.week, at: CGPoint(x: 200 * scale, y: 77 * scale), title: "一周", radius: metrics.largeRingRadius)
        let stale = connectionError != nil || snapshot?.isStale() == true
        if stale {
            QuotaLevel.caution.color.withAlphaComponent(0.7).setFill()
            NSBezierPath(ovalIn: NSRect(x: 258 * scale, y: 21 * scale, width: 5 * scale, height: 5 * scale)).fill()
        }
        let status: String
        let statusColor: NSColor
        switch connectionState {
        case .codexNotInstalled: status = "未找到 Codex"; statusColor = .secondaryLabelColor
        case .authenticationRequired: status = "请先在 Codex 中登录"; statusColor = .secondaryLabelColor
        case .disconnected: status = "连接中断 · 自动重试"; statusColor = .secondaryLabelColor
        case .locating where snapshot == nil: status = "正在查找 Codex…"; statusColor = .secondaryLabelColor
        default:
            if usageAlert == .spike {
                status = "用量突然升高"; statusColor = QuotaLevel.low.color
            } else if snapshot?.fiveHour?.isResetImminent() == true {
                status = "5 小时额度即将重置"; statusColor = QuotaLevel.caution.color
            } else {
                status = snapshot == nil ? "正在读取额度…" : stale ? "数据可能已过期" : "每 30 秒自动更新"
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
            NSColor.white.withAlphaComponent(0.09).setFill()
            NSRect(x: 1, y: metrics.largeCollapsed.height - scale, width: bounds.width-2, height: 0.5 * scale).fill()
            for (index, item) in [("5 小时", snapshot?.fiveHour, forecasts.fiveHour), ("一周", snapshot?.week, forecasts.week)].enumerated() {
                let y = CGFloat(191 + index * 66) * scale
                label(item.0, x: 16 * scale, y: y, size: 13 * scale, weight: .medium)
                let value = showUsed ? item.1?.clampedUsedPercent : item.1?.remainingPercent
                label(value.map { "\(Int($0.rounded()))%" } ?? "—", x: 212 * scale, y: y, size: 13 * scale, weight: .semibold, color: stale ? .tertiaryLabelColor : .labelColor)
                let resetImminent = index == 0 && item.1?.isResetImminent() == true
                label(item.1?.resetDescription() ?? "重置时间暂不可用", x: 16 * scale, y: y + 23 * scale, size: 10.5 * scale, weight: resetImminent ? .medium : .regular, color: resetImminent ? QuotaLevel.caution.color : .secondaryLabelColor)
                if index == 0 {
                    label(forecastText(item.2), x: 16 * scale, y: y + 41 * scale, size: 10.5 * scale, weight: .medium, color: forecastColor(item.2))
                }
            }
            if let resetCreditCount = snapshot?.resetCreditCount {
                let hasCredits = resetCreditCount > 0
                label("可用重置卡 × \(resetCreditCount)", x: 16 * scale, y: 294 * scale, size: 10.5 * scale,
                      weight: hasCredits ? .semibold : .regular,
                      color: hasCredits ? QuotaLevel.caution.color : .secondaryLabelColor)
            }
            let trendRect = NSRect(x: 16 * scale, y: 322 * scale, width: 248 * scale, height: 96 * scale)
            QuotaTrendRenderer.draw(samples: historySamples, retention: historyRetention, in: trendRect)
            if let trendHover, let range = QuotaTrendRenderer.timeRange(for: historySamples) {
                let span = range.end.timeIntervalSince(range.start)
                let position = span > 0 ? trendHover.sample.timestamp.timeIntervalSince(range.start) / span : 0
                QuotaTrendRenderer.drawHover(trendHover, position: position, in: trendRect)
            }
            let format = DateFormatter(); format.dateFormat = "HH:mm:ss"
            let footer = snapshot.map { "最近更新 \(format.string(from: $0.fetchedAt)) · 预测采样 \(forecastSampleCount) 个" } ?? "等待额度数据"
            label(footer, x: 16 * scale, y: 432 * scale, size: 10 * scale, color: .secondaryLabelColor)
        }
    }
    private var guidanceTitle: String? {
        switch connectionState {
        case .codexNotInstalled: return "安装 Codex"
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
