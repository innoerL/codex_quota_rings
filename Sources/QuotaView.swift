import AppKit

class QuotaView: NSView {
    static let preferredSize = NSSize(width: 42, height: 124)
    static let minimalTopArc: ClosedRange<CGFloat> = 36...144
    static let minimalBottomArc: ClosedRange<CGFloat> = 174...366
    var smallLayout: SmallLayout = .vertical { didSet { needsDisplay = true } }
    var metrics = WidgetLayoutMetrics(density: .standard) { didSet { needsDisplay = true } }
    var minimalArcOrder: MinimalArcOrder = .fiveHourTop { didSet { needsDisplay = true; updateTooltip() } }
    var minimalFiveHourArc: ClosedRange<CGFloat> {
        minimalArcOrder == .fiveHourTop ? Self.minimalTopArc : Self.minimalBottomArc
    }
    var contentOpacity: CGFloat = WidgetOpacityPreset.opaque.alpha { didSet { needsDisplay = true } }
    var ringTheme: WidgetRingTheme = .semantic { didSet { needsDisplay = true } }
    private var baseContentSize: NSSize {
        (metrics.isMinimal || smallLayout == .vertical) ? metrics.smallVertical : metrics.smallHorizontal
    }
    var preferredContentSize: NSSize { baseContentSize }
    private var fiveHourTransition: QuotaDisplayTransition?
    private var weekTransition: QuotaDisplayTransition?
    var snapshot: QuotaSnapshot? {
        didSet {
            let date = Date()
            if connectionError == nil, oldValue?.isStale(at: date) == false,
               let next = snapshot, !next.isStale(at: date),
               let previous = oldValue, next.fetchedAt > previous.fetchedAt {
                let oldFive = displayedUsedPercent(for: previous.fiveHour, isPrimary: true, at: date)
                let oldWeek = displayedUsedPercent(for: previous.week, isPrimary: false, at: date)
                fiveHourTransition = QuotaDisplayTransition.make(from: previous.fiveHour, to: next.fiveHour,
                                                                 displayedUsedPercent: oldFive, at: date)
                weekTransition = QuotaDisplayTransition.make(from: previous.week, to: next.week,
                                                             displayedUsedPercent: oldWeek, at: date)
            } else {
                fiveHourTransition = nil
                weekTransition = nil
            }
            needsDisplay = true
            updateTooltip()
        }
    }
    var forecasts = QuotaForecasts.collecting { didSet { needsDisplay = true; updateTooltip() } }
    var forecastChange: ForecastChange? { didSet { needsDisplay = true; updateTooltip() } }
    var hasForecastSampleData = false { didSet { needsDisplay = true; updateTooltip() } }
    var connectionError: String? {
        didSet {
            if connectionError != nil { cancelQuotaTransition() }
            needsDisplay = true
            updateTooltip()
        }
    }
    var connectionState: QuotaConnectionState = .locating { didSet { needsDisplay = true; updateTooltip(); connectionStateDidChange() } }
    func connectionStateDidChange() {}
    var showUsed = false { didSet { needsDisplay = true; updateTooltip() } }
    var usageAlert: QuotaUsageAlert = .none { didSet { needsDisplay = true; updateTooltip() } }
    var spikeEvidence: QuotaSpikeEvidence? { didSet { needsDisplay = true; updateTooltip() } }
    var lowQuotaContrastMode = false { didSet { needsDisplay = true; updateTooltip() } }
    var ringFeedback: RingFeedback = .rest { didSet { needsDisplay = true } }
    var ringFeedbackPhase: CGFloat = 0 { didSet { needsDisplay = true } }
    var showsSpikeHalo: Bool {
        usageAlert == .spike && connectionError == nil && snapshot?.isStale() == false
    }
    var isQuotaTransitionActive: Bool {
        let date = Date()
        return fiveHourTransition?.isActive(at: date) == true || weekTransition?.isActive(at: date) == true
    }
    @discardableResult func advanceQuotaTransition(at date: Date = Date()) -> Bool {
        let wasAnimating = fiveHourTransition != nil || weekTransition != nil
        if fiveHourTransition?.isActive(at: date) == false { fiveHourTransition = nil }
        if weekTransition?.isActive(at: date) == false { weekTransition = nil }
        if wasAnimating { needsDisplay = true }
        return fiveHourTransition != nil || weekTransition != nil
    }
    private func cancelQuotaTransition() {
        fiveHourTransition = nil
        weekTransition = nil
    }
    func displayedUsedPercent(for quota: QuotaWindow?, isPrimary: Bool, at date: Date = Date()) -> Double? {
        guard let used = quota?.clampedUsedPercent else { return nil }
        let transition = isPrimary ? fiveHourTransition : weekTransition
        return transition?.usedPercent(at: date) ?? used
    }
    var onMenu: (() -> NSMenu)?
    var onClick: (() -> Void)?
    var onDrag: (() -> Void)?
    var onDragFinished: (() -> Void)?
    var onPointerEntered: (() -> Void)?
    var onPointerExited: (() -> Void)?
    private var dragStart: NSPoint?
    private var windowStart: NSPoint?
    private var dragged = false
    private var hovered = false
    var isExpanded = false { didSet { needsDisplay = true; expansionDidChange() } }
    func expansionDidChange() {}
    private var hoverTracking: NSTrackingArea?
    override init(frame: NSRect) {
        super.init(frame: frame)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    var palette: WidgetAppearancePalette { WidgetAppearancePalette(appearance: effectiveAppearance) }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTracking { removeTrackingArea(hoverTracking) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area); hoverTracking = area
    }
    override func mouseEntered(with event: NSEvent) { hovered = true; needsDisplay = true; onPointerEntered?() }
    override func mouseExited(with event: NSEvent) { hovered = false; needsDisplay = true; onPointerExited?() }
    override var isFlipped: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func menu(for event: NSEvent) -> NSMenu? { onMenu?() }
    override func mouseDown(with event: NSEvent) {
        dragStart = NSEvent.mouseLocation; windowStart = window?.frame.origin; dragged = false
    }
    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart, let origin = windowStart else { return }
        let pointer = NSEvent.mouseLocation
        let dx = pointer.x - start.x, dy = pointer.y - start.y
        guard dragged || dx * dx + dy * dy > 9 else { return }
        if !dragged { dragged = true; onDrag?() }
        window?.setFrameOrigin(NSPoint(x: origin.x + dx, y: origin.y + dy))
    }
    override func mouseUp(with event: NSEvent) {
        let finishedDragging = dragStart != nil && dragged
        if dragStart != nil && !dragged { onClick?() }
        dragStart = nil; windowStart = nil
        if finishedDragging { onDragFinished?() }
    }
    func text(_ string: String, center: CGPoint, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color]
        let measured = (string as NSString).size(withAttributes: attributes)
        (string as NSString).draw(at: CGPoint(x: center.x - measured.width / 2, y: center.y - measured.height / 2), withAttributes: attributes)
    }
    func ring(_ quota: QuotaWindow?, at center: CGPoint, title: String, radius: CGFloat = 15,
              isPrimary: Bool = false, showValue: Bool = true, showTitle: Bool = true) {
        let scale = radius / 15
        if isPrimary && showsSpikeHalo {
            drawSurgeHalo(center: center, radius: radius, scale: scale)
        }
        let track = NSBezierPath(ovalIn: NSRect(x: center.x-radius, y: center.y-radius, width: radius*2, height: radius*2))
        palette.foreground.withAlphaComponent(lowQuotaContrastMode ? 0.19 : palette.track.alphaComponent).setStroke()
        track.lineWidth = 1.8 * scale; track.stroke()
        let used = displayedUsedPercent(for: quota, isPrimary: isPrimary)
        let value = showUsed ? used : used.map { 100 - $0 }
        let outdated = connectionError != nil || snapshot?.isStale() == true
        if let value, value > 0 {
            let arc = NSBezierPath()
            let steps = max(1, Int(value * 2))
            for step in 0...steps {
                let angle = -.pi / 2 + 2 * .pi * (value / 100) * Double(step) / Double(steps)
                let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
                if step == 0 { arc.move(to: point) } else { arc.line(to: point) }
            }
            palette.color(for: outdated ? .unknown : quota?.level ?? .unknown, theme: ringTheme).setStroke()
            arc.lineWidth = 1.8 * scale; arc.lineCapStyle = .round; arc.stroke()
        } else if value == 0 && !showUsed && !outdated {
            // 剩余额度耗尽时，即使进度弧为空，也保留可见的红色提示。
            palette.color(for: .low, theme: ringTheme).withAlphaComponent(0.65).setStroke(); track.stroke()
        }
        drawRingFeedback(quota: quota, center: center, radius: radius, scale: scale, outdated: outdated)
        guard showValue || showTitle else { return }
        let numeral = value.map { "\(Int($0.rounded()))" } ?? "—"
        let base = NSFont.monospacedDigitSystemFont(ofSize: 10.5 * scale, weight: .semibold)
        let rounded = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 10.5 * scale) } ?? base
        let ink = NSColor.labelColor.withAlphaComponent(outdated ? 0.55 : (lowQuotaContrastMode ? 1 : 0.94))
        let label = NSMutableAttributedString(string: showValue ? numeral : "", attributes: [.font: rounded, .foregroundColor: ink])
        if showValue, value != nil {
            label.append(NSAttributedString(string: "%", attributes: [.font: NSFont.systemFont(ofSize: 6 * scale, weight: .medium), .foregroundColor: ink.withAlphaComponent(outdated ? 0.35 : 0.65), .baselineOffset: 0.5 * scale]))
        }
        let size = label.size()
        label.draw(at: NSPoint(x: center.x-size.width/2, y: center.y-size.height/2))
        if showTitle { text(title, center: CGPoint(x: center.x, y: center.y + radius + (scale > 1 ? 20 : 9)), size: scale > 1 ? 13 : 8, weight: .medium, color: NSColor.secondaryLabelColor) }
    }
    private func drawSurgeHalo(center: CGPoint, radius: CGFloat, scale: CGFloat) {
        let progress = min(1, max(0, ringFeedbackPhase))
        let clearance = min(center.x - bounds.minX, bounds.maxX - center.x,
                            center.y - bounds.minY, bounds.maxY - center.y)
        let maxExpansion = max(0, min(7 * scale, clearance - radius - 1.5 * scale))
        guard maxExpansion > 0 else { return }
        let startExpansion = min(1.5 * scale, maxExpansion)
        let expansion = startExpansion + (maxExpansion - startExpansion) * progress
        let outerRadius = radius + expansion
        let halo = NSBezierPath(ovalIn: NSRect(x: center.x - outerRadius, y: center.y - outerRadius,
                                                width: outerRadius * 2, height: outerRadius * 2))
        if !palette.isDark {
            NSColor.black.withAlphaComponent(0.25 * sin(progress * .pi)).setStroke()
            halo.lineWidth = 2.3 * scale
            halo.stroke()
        }
        NSColor.white.withAlphaComponent((palette.isDark ? 0.48 : 0.92) * sin(progress * .pi)).setStroke()
        halo.lineWidth = 1.1 * scale
        halo.stroke()
    }
    private func drawRingFeedback(quota: QuotaWindow?, center: CGPoint, radius: CGFloat,
                                  scale: CGFloat, outdated: Bool) {
        guard !outdated else { return }
        switch ringFeedback {
        case .rest:
            break
        case .surgeHalo:
            break
        case .breathing:
            guard quota?.level == .low else { return }
            let pulse = 0.5 + 0.5 * sin(ringFeedbackPhase)
            let halo = NSBezierPath(ovalIn: NSRect(x: center.x - radius - 2.5 * scale,
                                                    y: center.y - radius - 2.5 * scale,
                                                    width: (radius + 2.5 * scale) * 2,
                                                    height: (radius + 2.5 * scale) * 2))
            palette.color(for: .low).withAlphaComponent(0.10 + 0.18 * pulse).setStroke()
            halo.lineWidth = (0.9 + 0.8 * pulse) * scale; halo.stroke()
        }
    }
    func minimalCenterText() -> String {
        let used = displayedUsedPercent(for: snapshot?.fiveHour, isPrimary: true)
        let value = showUsed ? used : used.map { 100 - $0 }
        return value.map { "\(Int($0.rounded()))%" } ?? "—"
    }
    private func minimalArc(center: CGPoint, radius: CGFloat, start: CGFloat, end: CGFloat,
                            color: NSColor, lineWidth: CGFloat) {
        let path = NSBezierPath()
        for step in 0...64 {
            let angle = (start + (end - start) * CGFloat(step) / 64) * .pi / 180
            let point = CGPoint(x: center.x + radius * cos(angle), y: center.y - radius * sin(angle))
            if step == 0 { path.move(to: point) } else { path.line(to: point) }
        }
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.lineWidth = lineWidth
        color.setStroke()
        path.stroke()
    }
    private func drawMinimalQuotaArc(_ quota: QuotaWindow?, isPrimary: Bool, center: CGPoint, radius: CGFloat,
                                     start: CGFloat, end: CGFloat, stale: Bool) {
        minimalArc(center: center, radius: radius, start: start, end: end,
                   color: palette.foreground.withAlphaComponent(lowQuotaContrastMode ? 0.23 : palette.minimalTrack.alphaComponent), lineWidth: 2.0)
        let used = displayedUsedPercent(for: quota, isPrimary: isPrimary)
        let value = showUsed ? used : used.map { 100 - $0 }
        guard let value else { return }
        let color = palette.color(for: stale ? .unknown : quota?.level ?? .unknown, theme: ringTheme)
        if value > 0 {
            minimalArc(center: center, radius: radius, start: start,
                       end: start + (end - start) * CGFloat(min(100, value) / 100),
                       color: color, lineWidth: 2.0)
        } else if !showUsed && !stale {
            minimalArc(center: center, radius: radius, start: start, end: end,
                       color: palette.color(for: .low, theme: ringTheme).withAlphaComponent(0.55), lineWidth: 2.0)
        }
    }
    private func drawMinimalRing() {
        let tile = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 11, yRadius: 11)
        (lowQuotaContrastMode ? palette.highContrastSurface : palette.surface).setFill()
        tile.fill()
        (lowQuotaContrastMode ? palette.highContrastBorder : palette.border).setStroke()
        tile.lineWidth = 1
        tile.stroke()
        if hovered || isExpanded {
            palette.hoverFill.setFill()
            tile.fill()
        }

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius: CGFloat = 14.5
        let stale = connectionError != nil || snapshot?.isStale() == true
        let fiveHourColor = palette.color(for: stale ? .unknown : snapshot?.fiveHour?.level ?? .unknown, theme: ringTheme)
        let fiveHourArc = minimalFiveHourArc
        if showsSpikeHalo {
            drawSurgeHalo(center: center, radius: radius, scale: radius / 15)
        }
        if ringFeedback == .breathing && !stale && snapshot?.fiveHour?.level == .low {
            let pulse = 0.5 + 0.5 * sin(ringFeedbackPhase)
            minimalArc(center: center, radius: radius,
                       start: fiveHourArc.lowerBound, end: fiveHourArc.upperBound,
                       color: fiveHourColor.withAlphaComponent(0.10 + 0.18 * pulse), lineWidth: 4.0)
        }
        // 上下轨道分别占可见弧长的 36% 和 64%，左右各留 30 度间隔。
        let upperQuota = minimalArcOrder == .fiveHourTop ? snapshot?.fiveHour : snapshot?.week
        let lowerQuota = minimalArcOrder == .fiveHourTop ? snapshot?.week : snapshot?.fiveHour
        drawMinimalQuotaArc(upperQuota, isPrimary: minimalArcOrder == .fiveHourTop, center: center, radius: radius,
                            start: Self.minimalTopArc.lowerBound, end: Self.minimalTopArc.upperBound, stale: stale)
        drawMinimalQuotaArc(lowerQuota, isPrimary: minimalArcOrder == .weekTop, center: center, radius: radius,
                            start: Self.minimalBottomArc.lowerBound, end: Self.minimalBottomArc.upperBound, stale: stale)

        let number = minimalCenterText() as NSString
        let base = NSFont.monospacedDigitSystemFont(ofSize: 9.5, weight: .semibold)
        let font = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 9.5) } ?? base
        let ink = NSColor.labelColor.withAlphaComponent(stale ? 0.58 : 0.94)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: ink]
        let size = number.size(withAttributes: attributes)
        number.draw(at: CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2),
                    withAttributes: attributes)
    }
    override func draw(_ dirtyRect: NSRect) {
        if metrics.isMinimal {
            drawMinimalRing()
            if connectionError != nil || snapshot?.isStale() == true {
                palette.color(for: .caution).setFill()
                NSBezierPath(ovalIn: NSRect(x: bounds.midX - 1.5, y: bounds.maxY - 5,
                                            width: 3, height: 3)).fill()
            }
            return
        }
        // 静止时保持低干扰，仅在悬停时显示轻微的 macOS 风格表面。
        if hovered || isExpanded || !palette.isDark {
            let surface = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 6), xRadius: 13, yRadius: 13)
            if palette.isDark {
                palette.foreground.withAlphaComponent(lowQuotaContrastMode ? 0.10 : (isExpanded ? 0.075 : 0.045)).setFill()
                surface.fill()
                palette.foreground.withAlphaComponent(lowQuotaContrastMode ? 0.16 : 0.07).setStroke()
            } else {
                (lowQuotaContrastMode ? palette.highContrastSurface : palette.surface).setFill()
                surface.fill()
                if hovered || isExpanded { palette.hoverFill.setFill(); surface.fill() }
                (lowQuotaContrastMode ? palette.highContrastBorder : palette.border).setStroke()
            }
            surface.lineWidth = 0.5; surface.stroke()
        }
        let scale = metrics.scale
        let vertical = metrics.isMinimal || smallLayout == .vertical
        let radius: CGFloat = metrics.isMinimal ? 13 : metrics.compactRingRadius
        let fiveHourCenter = CGPoint(x: vertical ? bounds.midX : 26 * scale, y: metrics.isMinimal ? 24 : 30 * scale)
        let weekCenter = CGPoint(x: vertical ? bounds.midX : 78 * scale, y: metrics.isMinimal ? 75 : (vertical ? 86 * scale : 30 * scale))
        ring(snapshot?.fiveHour, at: fiveHourCenter, title: localized("5 小时", "5 hours"), radius: radius, isPrimary: true)
        ring(snapshot?.week, at: weekCenter, title: localized("一周", "Week"), radius: radius)
        if connectionError != nil || snapshot?.isStale() == true {
            palette.color(for: .caution).setFill()
            NSBezierPath(ovalIn: NSRect(x: bounds.midX-1.5, y: bounds.maxY-5, width: 3, height: 3)).fill()
        }
    }
    func updateTooltip() {
        var lines = [localized("Codex \(showUsed ? "已用" : "剩余")额度 · 每30秒刷新", "Codex \(showUsed ? "used" : "remaining") quota · refreshes every 30 seconds"),
                     localized("点击查看详情 · 拖动移动 · 右键菜单", "Click for details · drag to move · right-click for menu")]
        if metrics.isMinimal {
            lines.append(minimalArcOrder == .fiveHourTop
                ? localized("上方：5 小时 · 下方：一周", "Top: 5 hours · Bottom: week")
                : localized("上方：一周 · 下方：5 小时", "Top: week · Bottom: 5 hours"))
        }
        if let snapshot {
            let formatter = DateFormatter(); formatter.dateFormat = "MM-dd HH:mm:ss"
            lines.append("更新：\(formatter.string(from: snapshot.fetchedAt))")
        }
        if showsSpikeHalo { lines.append(spikeEvidence?.localizedLabel ?? localized("用量突然升高", "Usage rose sharply")) }
        if let forecastChange { lines.append(forecastChange.localizedLabel) }
        if snapshot?.fiveHour?.isResetImminent() == true { lines.append(localized("5 小时额度即将重置", "5-hour quota resets soon")) }
        if lowQuotaContrastMode { lines.append(localized("低额度高对比模式已开启", "Low-quota high-contrast mode is on")) }
        switch connectionState {
        case .codexNotInstalled: lines.append(localized("未找到 Codex · 打开详情可安装", "Codex was not found · open details to install"))
        case .authenticationRequired: lines.append(localized("请先在 Codex 中登录", "Please sign in to Codex first"))
        case .disconnected(let message): lines.append(message)
        case .locating: if snapshot == nil { lines.append(localized("正在查找 Codex…", "Looking for Codex…")) }
        case .ready: if let connectionError { lines.append(connectionError) }
        }
        toolTip = lines.joined(separator: "\n")
        setAccessibilityElement(true); setAccessibilityRole(.button)
        setAccessibilityLabel(lines.joined(separator: ", "))
        let values = [snapshot?.fiveHour, snapshot?.week].map { window -> String in
            let value = showUsed ? window?.clampedUsedPercent : window?.remainingPercent
            return value.map { "\(Int($0.rounded()))%" } ?? localized("暂无数据", "No data")
        }
        setAccessibilityValue(localized("5小时 \(values[0])，一周 \(values[1])", "5 hours \(values[0]), week \(values[1])"))
    }
    func forecastText(_ forecast: QuotaForecast, at now: Date = Date()) -> String {
        guard connectionError == nil, snapshot?.isStale(at: now) != true else {
            return hasForecastSampleData ? "" : localized("收集中，稍后开始预测", "Collecting; forecast will start shortly")
        }
        guard hasForecastSampleData else { return localized("收集中，稍后开始预测", "Collecting; forecast will start shortly") }
        switch forecast.outcome {
        case .collecting: return ""
        case .unstable:
            return localized("● 消耗速率不稳定，暂不预测", "● Consumption rate is unstable; no forecast yet")
        case .willNotDeplete:
            return localized("本周期内不会用尽", "Will not run out this window")
        case .depletedAt(let date):
            let confidence = forecast.confidence.map { localized(" · 可信度：\($0.chineseLabel)", " · confidence: \($0.englishLabel)") } ?? ""
            if let range = forecast.depletionRange {
                return "● \(depletionRangeText(range, at: now)) 用尽\(confidence)"
            }
            let format = DateFormatter()
            format.dateFormat = Calendar.current.isDate(date, inSameDayAs: now) ? "HH:mm" : "M/d HH:mm"
            let time = format.string(from: date)
            return "● \(localized("预计 \(time) 用尽", "Expected to run out at \(time)"))\(confidence)"
        }
    }
    private func depletionRangeText(_ range: DateInterval, at now: Date) -> String {
        let format = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDate(range.start, inSameDayAs: now), calendar.isDate(range.end, inSameDayAs: now) {
            format.dateFormat = "HH:mm"
            return localized("约 \(format.string(from: range.start))–\(format.string(from: range.end))", "Around \(format.string(from: range.start))–\(format.string(from: range.end))")
        }
        format.dateFormat = "M/d HH:mm"
        return localized("约 \(format.string(from: range.start))–\(format.string(from: range.end))", "Around \(format.string(from: range.start))–\(format.string(from: range.end))")
    }
    func forecastColor(_ forecast: QuotaForecast) -> NSColor {
        switch forecast.outcome {
        case .unstable: return .secondaryLabelColor
        case .depletedAt:
            switch forecast.confidence {
            case .high: return palette.color(for: .ample)
            case .medium: return palette.color(for: .caution)
            case .low: return palette.color(for: .low)
            case nil: return .secondaryLabelColor
            }
        case .collecting, .willNotDeplete: return .secondaryLabelColor
        }
    }
    override func accessibilityPerformPress() -> Bool { onClick?(); return true }
}
