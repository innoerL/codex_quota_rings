import AppKit

extension QuotaLevel {
    var color: NSColor {
        switch self {
        case .ample: return NSColor(srgbRed: 143/255, green: 169/255, blue: 144/255, alpha: 1)
        case .caution: return NSColor(srgbRed: 180/255, green: 138/255, blue: 74/255, alpha: 1)
        case .low: return NSColor(srgbRed: 189/255, green: 122/255, blue: 112/255, alpha: 1)
        case .unknown: return NSColor(white: 0.42, alpha: 1)
        }
    }
}

class QuotaView: NSView {
    static let preferredSize = NSSize(width: 42, height: 124)
    var smallLayout: SmallLayout = .vertical { didSet { needsDisplay = true } }
    var metrics = WidgetLayoutMetrics(density: .standard) { didSet { needsDisplay = true } }
    var contentOpacity: CGFloat = WidgetOpacityPreset.opaque.alpha { didSet { needsDisplay = true } }
    private var baseContentSize: NSSize {
        smallLayout == .vertical ? metrics.smallVertical : metrics.smallHorizontal
    }
    var preferredContentSize: NSSize { baseContentSize }
    var snapshot: QuotaSnapshot? { didSet { needsDisplay = true; updateTooltip() } }
    var forecasts = QuotaForecasts.collecting { didSet { needsDisplay = true; updateTooltip() } }
    var connectionError: String? { didSet { needsDisplay = true; updateTooltip() } }
    var connectionState: QuotaConnectionState = .locating { didSet { needsDisplay = true; updateTooltip(); connectionStateDidChange() } }
    func connectionStateDidChange() {}
    var showUsed = false { didSet { needsDisplay = true; updateTooltip() } }
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
    func ring(_ quota: QuotaWindow?, at center: CGPoint, title: String, radius: CGFloat = 15) {
        let scale = radius / 15
        let track = NSBezierPath(ovalIn: NSRect(x: center.x-radius, y: center.y-radius, width: radius*2, height: radius*2))
        NSColor.white.withAlphaComponent(0.10).setStroke(); track.lineWidth = 1.8 * scale; track.stroke()
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
            (outdated ? QuotaLevel.unknown : quota?.level ?? .unknown).color.setStroke()
            arc.lineWidth = 1.8 * scale; arc.lineCapStyle = .round; arc.stroke()
        } else if value == 0 && !showUsed && !outdated {
            // Keep exhausted quota visibly red even though its remaining arc is empty.
            QuotaLevel.low.color.withAlphaComponent(0.65).setStroke(); track.stroke()
        }
        let numeral = value.map { "\(Int($0.rounded()))" } ?? "—"
        let base = NSFont.monospacedDigitSystemFont(ofSize: 10.5 * scale, weight: .semibold)
        let rounded = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 10.5 * scale) } ?? base
        let ink = NSColor.labelColor.withAlphaComponent(outdated ? 0.45 : 0.94)
        let label = NSMutableAttributedString(string: numeral, attributes: [.font: rounded, .foregroundColor: ink])
        if value != nil {
            label.append(NSAttributedString(string: "%", attributes: [.font: NSFont.systemFont(ofSize: 6 * scale, weight: .medium), .foregroundColor: ink.withAlphaComponent(outdated ? 0.35 : 0.65), .baselineOffset: 0.5 * scale]))
        }
        let size = label.size()
        label.draw(at: NSPoint(x: center.x-size.width/2, y: center.y-size.height/2))
        text(title, center: CGPoint(x: center.x, y: center.y + radius + (scale > 1 ? 20 : 9)), size: scale > 1 ? 13 : 8, weight: .medium, color: NSColor.secondaryLabelColor)

    }
    override func draw(_ dirtyRect: NSRect) {
        // A quiet sidebar control at rest, with a subtle macOS-style hover surface.
        if hovered || isExpanded {
            let surface = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 6), xRadius: 13, yRadius: 13)
            NSColor.white.withAlphaComponent(isExpanded ? 0.075 : 0.045).setFill(); surface.fill()
            NSColor.white.withAlphaComponent(0.07).setStroke(); surface.lineWidth = 0.5; surface.stroke()
        }
        let scale = metrics.scale
        ring(snapshot?.fiveHour, at: CGPoint(x: smallLayout == .vertical ? bounds.midX : 26 * scale, y: 30 * scale), title: "5 小时", radius: metrics.compactRingRadius)
        ring(snapshot?.week, at: CGPoint(x: smallLayout == .vertical ? bounds.midX : 78 * scale, y: smallLayout == .vertical ? 86 * scale : 30 * scale), title: "一周", radius: metrics.compactRingRadius)
        if connectionError != nil || snapshot?.isStale() == true {
            QuotaLevel.caution.color.setFill()
            NSBezierPath(ovalIn: NSRect(x: bounds.midX-1.5, y: bounds.maxY-5, width: 3, height: 3)).fill()
        }
    }
    func updateTooltip() {
        var lines = ["Codex \(showUsed ? "已用" : "剩余")额度 · 每30秒刷新", "点击查看详情 · 拖动移动 · 右键菜单"]
        if let snapshot {
            let formatter = DateFormatter(); formatter.dateFormat = "MM-dd HH:mm:ss"
            lines.append("更新：\(formatter.string(from: snapshot.fetchedAt))")
        }
        switch connectionState {
        case .codexNotInstalled: lines.append("未找到 Codex · 打开详情可安装")
        case .authenticationRequired: lines.append("请先在 Codex 中登录")
        case .disconnected(let message): lines.append(message)
        case .locating: if snapshot == nil { lines.append("正在查找 Codex…") }
        case .ready: if let connectionError { lines.append(connectionError) }
        }
        toolTip = lines.joined(separator: "\n")
        setAccessibilityElement(true); setAccessibilityRole(.button)
        setAccessibilityLabel(lines.joined(separator: ", "))
        let values = [snapshot?.fiveHour, snapshot?.week].map { window -> String in
            let value = showUsed ? window?.clampedUsedPercent : window?.remainingPercent
            return value.map { "\(Int($0.rounded()))%" } ?? "暂无数据"
        }
        setAccessibilityValue("5小时 \(values[0])，一周 \(values[1])")
    }
    func forecastText(_ forecast: QuotaForecast, at now: Date = Date()) -> String {
        guard connectionError == nil, snapshot?.isStale(at: now) != true else { return "收集中，稍后预测" }
        switch forecast.outcome {
        case .collecting:
            return "收集中，稍后预测"
        case .unstable:
            return "● 消耗速率不稳定，暂不预测"
        case .willNotDeplete:
            return "本周期内不会用尽"
        case .depletedAt(let date):
            let format = DateFormatter()
            format.dateFormat = Calendar.current.isDate(date, inSameDayAs: now) ? "预计 HH:mm 用尽" : "预计 M/d HH:mm 用尽"
            let confidence = forecast.confidence.map { " · 可信度：\($0.chineseLabel)" } ?? ""
            return "● \(format.string(from: date))\(confidence)"
        }
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
