import AppKit

class QuotaView: NSView {
    static let preferredSize = NSSize(width: 42, height: 124)
    var smallLayout: SmallLayout = .vertical { didSet { needsDisplay = true } }
    var metrics = WidgetLayoutMetrics(density: .standard) { didSet { needsDisplay = true } }
    var contentOpacity: CGFloat = WidgetOpacityPreset.opaque.alpha { didSet { needsDisplay = true } }
    var ringTheme: WidgetRingTheme = .semantic { didSet { needsDisplay = true } }
    private var baseContentSize: NSSize {
        smallLayout == .vertical ? metrics.smallVertical : metrics.smallHorizontal
    }
    var preferredContentSize: NSSize { baseContentSize }
    var snapshot: QuotaSnapshot? { didSet { needsDisplay = true; updateTooltip() } }
    var forecasts = QuotaForecasts.collecting { didSet { needsDisplay = true; updateTooltip() } }
    var forecastChange: ForecastChange? { didSet { needsDisplay = true; updateTooltip() } }
    var hasForecastSampleData = false { didSet { needsDisplay = true; updateTooltip() } }
    var connectionError: String? { didSet { needsDisplay = true; updateTooltip() } }
    var connectionState: QuotaConnectionState = .locating { didSet { needsDisplay = true; updateTooltip(); connectionStateDidChange() } }
    func connectionStateDidChange() {}
    var showUsed = false { didSet { needsDisplay = true; updateTooltip() } }
    var usageAlert: QuotaUsageAlert = .none { didSet { needsDisplay = true; updateTooltip() } }
    var lowQuotaContrastMode = false { didSet { needsDisplay = true; updateTooltip() } }
    var ringFeedback: RingFeedback = .rest { didSet { needsDisplay = true } }
    var ringFeedbackPhase: CGFloat = 0 { didSet { needsDisplay = true } }
    var starTrailEnabled = true { didSet { needsDisplay = true } }
    var resetCelebrationProgress: CGFloat? { didSet { needsDisplay = true } }
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
        appearance = NSAppearance(named: .darkAqua)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
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
              resetEmphasis: Bool = false, isPrimary: Bool = false, showValue: Bool = true, showTitle: Bool = true) {
        let scale = radius / 15
        if starTrailEnabled { drawStarTrail(center: center, radius: radius, scale: scale, isPrimary: isPrimary) }
        let track = NSBezierPath(ovalIn: NSRect(x: center.x-radius, y: center.y-radius, width: radius*2, height: radius*2))
        NSColor.white.withAlphaComponent(lowQuotaContrastMode ? 0.19 : 0.10).setStroke(); track.lineWidth = 1.8 * scale; track.stroke()
        let value = showUsed ? quota?.clampedUsedPercent : quota?.remainingPercent
        let outdated = connectionError != nil || snapshot?.isStale() == true
        if let value, value > 0 {
            let arc = NSBezierPath()
            let steps = max(1, Int(value * 2))
            for step in 0...steps {
                let angle = -.pi / 2 + 2 * .pi * (value / 100) * Double(step) / Double(steps)
                let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
                if step == 0 { arc.move(to: point) } else { arc.line(to: point) }
            }
            ringTheme.color(for: outdated ? .unknown : quota?.level ?? .unknown).setStroke()
            arc.lineWidth = 1.8 * scale; arc.lineCapStyle = .round; arc.stroke()
        } else if value == 0 && !showUsed && !outdated {
            // Keep exhausted quota visibly red even though its remaining arc is empty.
            ringTheme.color(for: .low).withAlphaComponent(0.65).setStroke(); track.stroke()
        }
        drawRingFeedback(quota: quota, value: value, center: center, radius: radius, scale: scale,
                         isPrimary: isPrimary, outdated: outdated)
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
        if resetEmphasis {
            QuotaLevel.caution.color.setFill()
            let dot = max(3, 3.8 * scale)
            NSBezierPath(ovalIn: NSRect(x: center.x + radius * 0.58, y: center.y - radius * 0.82, width: dot, height: dot)).fill()
        }
    }
    private func drawStarTrail(center: CGPoint, radius: CGFloat, scale: CGFloat, isPrimary: Bool) {
        let orbitRadius = radius + 3.2 * scale
        let orbit = NSBezierPath(ovalIn: NSRect(x: center.x - orbitRadius, y: center.y - orbitRadius, width: orbitRadius * 2, height: orbitRadius * 2))
        let tint = isPrimary ? ringTheme.color(for: snapshot?.fiveHour?.level ?? .unknown) : ringTheme.color(for: snapshot?.week?.level ?? .unknown)
        tint.withAlphaComponent(0.17).setStroke(); orbit.lineWidth = 0.55 * scale; orbit.setLineDash([1, 3], count: 2, phase: 0); orbit.stroke()
        for index in 0..<4 {
            let angle = CGFloat(-Double.pi / 2 + Double(index) * 1.64 + (isPrimary ? 0.18 : 0.76))
            let point = NSPoint(x: center.x + orbitRadius * cos(angle), y: center.y + orbitRadius * sin(angle))
            let size = (index == 0 ? 1.7 : 1.1) * scale
            tint.withAlphaComponent(index == 0 ? 0.50 : 0.28).setFill()
            NSBezierPath(ovalIn: NSRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size)).fill()
        }
    }
    private func drawRingFeedback(quota: QuotaWindow?, value: Double?, center: CGPoint, radius: CGFloat,
                                  scale: CGFloat, isPrimary: Bool, outdated: Bool) {
        guard !outdated else { return }
        switch ringFeedback {
        case .rest:
            break
        case .flowing:
            guard isPrimary, let value, value > 0 else { return }
            let amount = min(1, max(0, value / 100))
            let startFraction = Double(ringFeedbackPhase.truncatingRemainder(dividingBy: 1)) * amount
            let highlightFraction = min(amount * 0.18, 0.12)
            guard highlightFraction > 0 else { return }
            let path = NSBezierPath()
            let steps = 12
            for step in 0...steps {
                let fraction = startFraction + highlightFraction * Double(step) / Double(steps)
                let angle = -.pi / 2 + 2 * .pi * fraction
                let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
                if step == 0 { path.move(to: point) } else { path.line(to: point) }
            }
            NSColor.white.withAlphaComponent(0.42).setStroke()
            path.lineWidth = 2.5 * scale; path.lineCapStyle = .round; path.stroke()
        case .breathing:
            guard quota?.level == .low else { return }
            let pulse = 0.5 + 0.5 * sin(ringFeedbackPhase)
            let halo = NSBezierPath(ovalIn: NSRect(x: center.x - radius - 2.5 * scale,
                                                    y: center.y - radius - 2.5 * scale,
                                                    width: (radius + 2.5 * scale) * 2,
                                                    height: (radius + 2.5 * scale) * 2))
            QuotaLevel.low.color.withAlphaComponent(0.10 + 0.18 * pulse).setStroke()
            halo.lineWidth = (0.9 + 0.8 * pulse) * scale; halo.stroke()
        }
        if isPrimary, let progress = resetCelebrationProgress {
            let pulse = sin(min(1, max(0, progress)) * .pi)
            let expansion = (2 + 7 * progress) * scale
            let halo = NSBezierPath(ovalIn: NSRect(x: center.x - radius - expansion, y: center.y - radius - expansion,
                                                    width: (radius + expansion) * 2, height: (radius + expansion) * 2))
            NSColor.white.withAlphaComponent(0.42 * pulse).setStroke()
            halo.lineWidth = (1.1 + pulse) * scale; halo.stroke()
        }
    }
    override func draw(_ dirtyRect: NSRect) {
        // A quiet sidebar control at rest, with a subtle macOS-style hover surface.
        if hovered || isExpanded {
            let surface = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 6), xRadius: 13, yRadius: 13)
            NSColor.white.withAlphaComponent(lowQuotaContrastMode ? 0.10 : (isExpanded ? 0.075 : 0.045)).setFill(); surface.fill()
            NSColor.white.withAlphaComponent(lowQuotaContrastMode ? 0.16 : 0.07).setStroke(); surface.lineWidth = 0.5; surface.stroke()
        }
        let scale = metrics.scale
        ring(snapshot?.fiveHour, at: CGPoint(x: smallLayout == .vertical ? bounds.midX : 26 * scale, y: 30 * scale), title: localized("5 小时", "5 hours"), radius: metrics.compactRingRadius, resetEmphasis: snapshot?.fiveHour?.isResetImminent() == true, isPrimary: true)
        ring(snapshot?.week, at: CGPoint(x: smallLayout == .vertical ? bounds.midX : 78 * scale, y: smallLayout == .vertical ? 86 * scale : 30 * scale), title: localized("一周", "Week"), radius: metrics.compactRingRadius)
        if connectionError != nil || snapshot?.isStale() == true {
            QuotaLevel.caution.color.setFill()
            NSBezierPath(ovalIn: NSRect(x: bounds.midX-1.5, y: bounds.maxY-5, width: 3, height: 3)).fill()
        }
        if usageAlert == .spike {
            QuotaLevel.low.color.setFill()
            NSBezierPath(ovalIn: NSRect(x: bounds.maxX-5, y: bounds.minY+2, width: 3, height: 3)).fill()
        }
    }
    func updateTooltip() {
        var lines = [localized("Codex \(showUsed ? "已用" : "剩余")额度 · 每30秒刷新", "Codex \(showUsed ? "used" : "remaining") quota · refreshes every 30 seconds"),
                     localized("点击查看详情 · 拖动移动 · 右键菜单", "Click for details · drag to move · right-click for menu")]
        if let snapshot {
            let formatter = DateFormatter(); formatter.dateFormat = "MM-dd HH:mm:ss"
            lines.append("更新：\(formatter.string(from: snapshot.fetchedAt))")
        }
        if let alert = usageAlert.localizedLabel { lines.append(alert) }
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
            case .high: return QuotaLevel.ample.color
            case .medium: return QuotaLevel.caution.color
            case .low: return QuotaLevel.low.color
            case nil: return .secondaryLabelColor
            }
        case .collecting, .willNotDeplete: return .secondaryLabelColor
        }
    }
    override func accessibilityPerformPress() -> Bool { onClick?(); return true }
}
