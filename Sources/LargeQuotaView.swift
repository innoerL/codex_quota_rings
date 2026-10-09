import AppKit

/// A single window surface: opening details changes its height, never opens a popover.
final class LargeQuotaView: QuotaView {
    static let collapsedSize = NSSize(width: 280, height: 174)
    private static let expandedBaseHeight: CGFloat = 456
    private var guidanceHeight: CGFloat { isExpanded && guidanceTitle != nil ? 38 : 0 }
    private var taskSectionHeight: CGFloat { taskStatuses.isEmpty ? 0 : 8 + CGFloat(taskStatuses.count) * 30 }
    override var preferredContentSize: NSSize {
        NSSize(width: Self.collapsedSize.width, height: (isExpanded ? Self.expandedBaseHeight + guidanceHeight : Self.collapsedSize.height) + taskSectionHeight)
    }
    var historySamples: [QuotaHistorySample] = [] { didSet { needsDisplay = true } }
    var historyRetention: HistoryRetention = .session30Minutes { didSet { needsDisplay = true } }
    var canOpenCodex = false { didSet { rebuildGuidance(); rebuildTaskRows() } }
    var onInstallCodex: (() -> Void)?
    var onOpenCodex: (() -> Void)?
    private var guidanceButton: NSButton?
    private var taskRows: [TaskRowView] = []

    override func expansionDidChange() { rebuildGuidance(); rebuildTaskRows() }
    override func connectionStateDidChange() { rebuildGuidance(); rebuildTaskRows() }
    override func taskStatusesDidChange() { rebuildTaskRows() }
    override func draw(_ dirtyRect: NSRect) {
        let card = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 16, yRadius: 16)
        NSColor(white: 0.14, alpha: 0.97).setFill(); card.fill()
        NSColor.white.withAlphaComponent(0.11).setStroke(); card.lineWidth = 1; card.stroke()
        label(showUsed ? "已用额度" : "剩余额度", x: 16, y: 16, size: 12, weight: .semibold, color: .secondaryLabelColor)
        ring(snapshot?.fiveHour, at: CGPoint(x: 80, y: 77), title: "5 小时", radius: 28)
        ring(snapshot?.week, at: CGPoint(x: 200, y: 77), title: "一周", radius: 28)
        let stale = connectionError != nil || snapshot?.isStale() == true
        if stale {
            QuotaLevel.caution.color.withAlphaComponent(0.7).setFill()
            NSBezierPath(ovalIn: NSRect(x: 258, y: 21, width: 5, height: 5)).fill()
        }
        let status: String
        switch connectionState {
        case .codexNotInstalled: status = "未找到 Codex"
        case .authenticationRequired: status = "请先在 Codex 中登录"
        case .disconnected: status = "连接中断 · 自动重试"
        case .locating where snapshot == nil: status = "正在查找 Codex…"
        default: status = snapshot == nil ? "正在读取额度…" : stale ? "数据可能已过期" : "每 30 秒自动更新"
        }
        label(status, x: 16, y: 148, size: 10.5, color: .secondaryLabelColor)
        let chevron = NSBezierPath()
        chevron.move(to: NSPoint(x: 254, y: isExpanded ? 156 : 152))
        chevron.line(to: NSPoint(x: 258, y: isExpanded ? 152 : 156))
        chevron.line(to: NSPoint(x: 262, y: isExpanded ? 156 : 152))
        NSColor.secondaryLabelColor.setStroke(); chevron.lineWidth = 1.5; chevron.lineCapStyle = .round; chevron.lineJoinStyle = .round; chevron.stroke()
        if isExpanded {
            NSColor.white.withAlphaComponent(0.09).setFill()
            NSRect(x: 1, y: 173, width: bounds.width-2, height: 0.5).fill()
            for (index, item) in [("5 小时", snapshot?.fiveHour, forecasts.fiveHour), ("一周", snapshot?.week, forecasts.week)].enumerated() {
                let y = CGFloat(191 + index * 66)
                label(item.0, x: 16, y: y, size: 13, weight: .medium)
                let value = showUsed ? item.1?.clampedUsedPercent : item.1?.remainingPercent
                label(value.map { "\(Int($0.rounded()))%" } ?? "—", x: 212, y: y, size: 13, weight: .semibold, color: stale ? .tertiaryLabelColor : .labelColor)
                label(item.1?.resetDescription() ?? "重置时间暂不可用", x: 16, y: y + 23, size: 10.5, color: .secondaryLabelColor)
                if index == 0 {
                    label(forecastText(item.2), x: 16, y: y + 41, size: 10.5, weight: .medium, color: .secondaryLabelColor)
                }
            }
            let taskOffset = taskSectionHeight
            QuotaTrendRenderer.draw(samples: historySamples, retention: historyRetention,
                                    in: NSRect(x: 16, y: 322 + taskOffset, width: 248, height: 96))
            let format = DateFormatter(); format.dateFormat = "HH:mm:ss"
            label(snapshot.map { "最近更新 \(format.string(from: $0.fetchedAt))" } ?? "等待额度数据", x: 16, y: 432 + taskOffset, size: 10, color: .secondaryLabelColor)
        }
        drawTaskRows(startY: isExpanded ? 286 : Self.collapsedSize.height)
    }
    private var guidanceTitle: String? {
        switch connectionState {
        case .codexNotInstalled: return "安装 Codex"
        case .authenticationRequired where canOpenCodex,
             .disconnected where canOpenCodex: return "打开 Codex"
        default: return nil
        }
    }
    private func rebuildGuidance() {
        guidanceButton?.removeFromSuperview(); guidanceButton = nil
        guard isExpanded, let title = guidanceTitle else { return }
        let button = NSButton(title: title, target: self,
                              action: title == "安装 Codex" ? #selector(installCodex) : #selector(openCodex))
        button.bezelStyle = .rounded; button.controlSize = .small
        button.frame = NSRect(x: 16, y: Self.expandedBaseHeight + 4, width: 104, height: 28)
        addSubview(button); guidanceButton = button
    }
    override func rebuildTaskRows() {
        taskRows.forEach { $0.removeFromSuperview() }; taskRows.removeAll()
        let startY = isExpanded ? 286 : Self.collapsedSize.height
        for (index, task) in taskStatuses.enumerated() {
            let row = TaskRowView(status: task,
                                  frame: NSRect(x: 10, y: startY + 4 + CGFloat(index) * 30,
                                                width: 260, height: 28))
            row.onClick = { [weak self] id in self?.onTaskClick?(id) }
            addSubview(row); taskRows.append(row)
        }
    }
    override func refreshTaskDurations(at now: Date = Date()) { taskRows.forEach { $0.now = now } }
    @objc private func installCodex() { onInstallCodex?() }
    @objc private func openCodex() { onOpenCodex?() }
    private func drawTaskRows(startY: CGFloat) {
        guard !taskStatuses.isEmpty else { return }
        NSColor.white.withAlphaComponent(0.09).setFill()
        NSRect(x: 1, y: startY, width: bounds.width-2, height: 0.5).fill()
    }
    private func label(_ value: String, x: CGFloat, y: CGFloat, width: CGFloat? = nil, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .labelColor, alignment: NSTextAlignment = .left) {
        let style = NSMutableParagraphStyle(); style.lineBreakMode = .byTruncatingTail
        style.alignment = alignment
        (value as NSString).draw(in: NSRect(x: x, y: y, width: width ?? bounds.width-x-14, height: 19), withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: style])
    }
}
