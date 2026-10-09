import AppKit

/// Native popover material and labels; all data updates are automatic.
final class QuotaDetailsView: NSView {
    static let preferredSize = NSSize(width: 246, height: 284)
    private var guidanceHeight: CGFloat { guidanceTitle == nil ? 0 : 38 }
    var preferredContentSize: NSSize { NSSize(width: Self.preferredSize.width, height: Self.preferredSize.height + guidanceHeight + CGFloat(taskStatuses.count) * 30) }
    var snapshot: QuotaSnapshot? { didSet { updateLabels() } }
    var forecasts = QuotaForecasts.collecting { didSet { updateLabels() } }
    var taskStatuses: [WidgetTaskStatus] = [] { didSet { rebuildTaskRows() } }
    var connectionError: String? { didSet { updateLabels() } }
    var connectionState: QuotaConnectionState = .locating { didSet { updateLabels(); rebuildGuidance(); rebuildTaskRows() } }
    var canOpenCodex = false { didSet { rebuildGuidance(); rebuildTaskRows() } }
    var historySamples: [QuotaHistorySample] = [] { didSet { trend.samples = historySamples } }
    var historyRetention: HistoryRetention = .session30Minutes { didSet { trend.retention = historyRetention } }
    var onInstallCodex: (() -> Void)?
    var onOpenCodex: (() -> Void)?
    var onTaskClick: ((String) -> Void)?
    var showUsed = false { didSet { updateLabels() } }
    private let material = NSVisualEffectView()
    private var values: [NSTextField] = []
    private var resets: [NSTextField] = []
    private var forecastLabels: [NSTextField] = []
    private var taskRows: [TaskRowView] = []
    private var updated: NSTextField!
    private var automatic: NSTextField!
    private let trend = QuotaTrendView()
    private var guidanceButton: NSButton?
    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        appearance = NSAppearance(named: .darkAqua)
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.masksToBounds = true
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
        material.frame = bounds
        material.autoresizingMask = [.width, .height]
        material.material = .popover
        material.blendingMode = .behindWindow
        material.state = .active
        addSubview(material)
        for (index, title) in ["5 小时", "一周"].enumerated() {
            let top = CGFloat(17 + index * 66)
            _ = label(title, frame: NSRect(x: 16, y: top, width: 100, height: 17), font: .systemFont(ofSize: 11, weight: .medium), color: .labelColor)
            let value = label("—", frame: NSRect(x: 147, y: top-1, width: 83, height: 19), font: .monospacedDigitSystemFont(ofSize: 13, weight: .semibold), color: .labelColor)
            value.alignment = .right; values.append(value)
            resets.append(label("", frame: NSRect(x: 16, y: top+22, width: 214, height: 15), font: .systemFont(ofSize: 9.5), color: .secondaryLabelColor))
            forecastLabels.append(label("", frame: NSRect(x: 16, y: top+40, width: 214, height: 14), font: .systemFont(ofSize: 9), color: .tertiaryLabelColor))
        }
        trend.frame = NSRect(x: 16, y: 148, width: 214, height: 96)
        trend.autoresizingMask = [.width]
        addSubview(trend)
        let separator = NSBox(frame: NSRect(x: 16, y: 246, width: 214, height: 1))
        separator.boxType = .separator; addSubview(separator)
        updated = label("", frame: NSRect(x: 16, y: 257, width: 160, height: 14), font: .systemFont(ofSize: 9), color: .secondaryLabelColor)
        automatic = label("自动刷新", frame: NSRect(x: 177, y: 257, width: 53, height: 14), font: .systemFont(ofSize: 9), color: .tertiaryLabelColor)
        automatic.alignment = .right
        updateLabels()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private func label(_ title: String, frame: NSRect, font: NSFont, color: NSColor) -> NSTextField {
        let field = NSTextField(labelWithString: title)
        field.frame = frame; field.font = font; field.textColor = color
        field.lineBreakMode = .byTruncatingTail
        field.isSelectable = false
        addSubview(field)
        return field
    }
    func updateLabels() {
        guard values.count == 2, updated != nil else { return }
        let outdated = connectionError != nil || snapshot?.isStale() == true
        for (index, quota) in [snapshot?.fiveHour, snapshot?.week].enumerated() {
            let value = showUsed ? quota?.clampedUsedPercent : quota?.remainingPercent
            values[index].stringValue = value.map { "\(Int($0.rounded()))%" } ?? "—"
            values[index].textColor = outdated ? .tertiaryLabelColor : .labelColor
            resets[index].stringValue = quota?.resetDescription() ?? "重置时间暂不可用"
            forecastLabels[index].stringValue = forecastText(index == 0 ? forecasts.fiveHour : forecasts.week)
        }
        switch connectionState {
        case .codexNotInstalled: updated.stringValue = "未找到 Codex"
        case .authenticationRequired: updated.stringValue = "请先在 Codex 中登录"
        case .disconnected: updated.stringValue = "连接中断 · 自动重试"
        case .locating where snapshot == nil: updated.stringValue = "正在查找 Codex…"
        default: if let snapshot {
            let format = DateFormatter(); format.dateFormat = "HH:mm:ss"
            updated.stringValue = "最近更新 \(format.string(from: snapshot.fetchedAt))" + (outdated ? " · 已过期" : "")
        } else { updated.stringValue = "正在读取额度…" }
        }
        automatic.stringValue = showUsed ? "已用额度" : "自动刷新"
    }
    private func forecastText(_ forecast: QuotaForecast) -> String {
        guard connectionError == nil, snapshot?.isStale() != true else { return "收集中，稍后预测" }
        switch forecast {
        case .collecting: return "收集中，稍后预测"
        case .withinCurrentWindow: return "本周期内不会用尽"
        case .depletedAt(let date):
            let format = DateFormatter()
            format.dateFormat = Calendar.current.isDateInToday(date) ? "预计 HH:mm 用尽" : "预计 M/d HH:mm 用尽"
            return format.string(from: date)
        }
    }
    private func rebuildTaskRows() {
        taskRows.forEach { $0.removeFromSuperview() }
        taskRows.removeAll()
        for (index, task) in taskStatuses.enumerated() {
            let y = Self.preferredSize.height + guidanceHeight + CGFloat(index) * 30
            let row = TaskRowView(status: task, frame: NSRect(x: 10, y: y, width: 226, height: 28))
            row.onClick = { [weak self] id in self?.onTaskClick?(id) }
            addSubview(row); taskRows.append(row)
        }
    }
    func refreshTaskDurations(at now: Date = Date()) { taskRows.forEach { $0.now = now } }
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
        guard let title = guidanceTitle else { return }
        let button = NSButton(title: title, target: self,
                              action: title == "安装 Codex" ? #selector(installCodex) : #selector(openCodex))
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.frame = NSRect(x: 16, y: Self.preferredSize.height + 4, width: 104, height: 28)
        addSubview(button); guidanceButton = button
    }
    @objc private func installCodex() { onInstallCodex?() }
    @objc private func openCodex() { onOpenCodex?() }
}
