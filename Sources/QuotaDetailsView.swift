import AppKit

/// Native popover material and labels; all data updates are automatic.
final class QuotaDetailsView: NSView {
    static let preferredSize = NSSize(width: 246, height: 284)
    private var guidanceHeight: CGFloat { guidanceTitle == nil ? 0 : 38 * metrics.scale }
    var preferredContentSize: NSSize { NSSize(width: metrics.detail.width, height: metrics.detail.height + guidanceHeight) }
    var metrics = WidgetLayoutMetrics(density: .standard) { didSet { applyPresentation() } }
    var contentOpacity: CGFloat = WidgetOpacityPreset.opaque.alpha { didSet { applyPresentation() } }
    var snapshot: QuotaSnapshot? { didSet { updateLabels() } }
    var forecasts = QuotaForecasts.collecting { didSet { updateLabels() } }
    var hasForecastSampleData = false { didSet { updateLabels() } }
    var forecastSampleCount = 0 { didSet { updateLabels() } }
    var connectionError: String? { didSet { updateLabels() } }
    var connectionState: QuotaConnectionState = .locating { didSet { updateLabels(); rebuildGuidance() } }
    var historySamples: [QuotaHistorySample] = [] { didSet { trend.samples = historySamples } }
    var historyRetention: HistoryRetention = .session30Minutes { didSet { trend.retention = historyRetention } }
    var onInstallCodex: (() -> Void)?
    var onPointerEntered: (() -> Void)?
    var onPointerExited: (() -> Void)?
    var showUsed = false { didSet { updateLabels() } }
    var usageAlert: QuotaUsageAlert = .none { didSet { updateLabels() } }
    var lowQuotaContrastMode = false { didSet { applyPresentation() } }
    private let material = NSVisualEffectView()
    private var values: [NSTextField] = []
    private var resets: [NSTextField] = []
    private var forecastLabels: [NSTextField] = []
    private var updated: NSTextField!
    private var automatic: NSTextField!
    private let trend = QuotaTrendView()
    private var guidanceButton: NSButton?
    private var baseFrames: [ObjectIdentifier: NSRect] = [:]
    private var hoverTracking: NSTrackingArea?
    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        appearance = NSAppearance(named: .darkAqua)
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.masksToBounds = true
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor.white.withAlphaComponent(lowQuotaContrastMode ? 0.20 : 0.12).cgColor
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
            forecastLabels.append(label("", frame: NSRect(x: 16, y: top+40, width: 214, height: 14), font: .systemFont(ofSize: 9.5, weight: .medium), color: .secondaryLabelColor))
        }
        trend.frame = NSRect(x: 16, y: 148, width: 214, height: 96)
        trend.autoresizingMask = [.width]
        addSubview(trend)
        let separator = NSBox(frame: NSRect(x: 16, y: 246, width: 214, height: 1))
        separator.boxType = .separator; addSubview(separator)
        updated = label("", frame: NSRect(x: 16, y: 257, width: 160, height: 14), font: .systemFont(ofSize: 9), color: .secondaryLabelColor)
        automatic = label("自动刷新", frame: NSRect(x: 177, y: 257, width: 53, height: 14), font: .systemFont(ofSize: 9), color: .tertiaryLabelColor)
        automatic.alignment = .right
        captureBaseFrames()
        applyPresentation()
        updateLabels()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTracking { removeTrackingArea(hoverTracking) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area); hoverTracking = area
    }
    override func mouseEntered(with event: NSEvent) { onPointerEntered?() }
    override func mouseExited(with event: NSEvent) { onPointerExited?() }
    private func label(_ title: String, frame: NSRect, font: NSFont, color: NSColor) -> NSTextField {
        let field = NSTextField(labelWithString: title)
        field.frame = frame; field.font = font; field.textColor = color
        field.lineBreakMode = .byTruncatingTail
        field.isSelectable = false
        addSubview(field)
        return field
    }
    private func captureBaseFrames() {
        for subview in subviews where subview !== material { baseFrames[ObjectIdentifier(subview)] = subview.frame }
    }
    private func applyPresentation() {
        let scale = metrics.scale
        layer?.cornerRadius = 14 * scale
        layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
        material.alphaValue = 1
        material.material = lowQuotaContrastMode ? .sidebar : .popover
        material.frame = bounds
        for subview in subviews where subview !== material {
            guard let frame = baseFrames[ObjectIdentifier(subview)] else { continue }
            subview.frame = NSRect(x: frame.minX * scale, y: frame.minY * scale, width: frame.width * scale, height: frame.height * scale)
        }
        needsDisplay = true
    }
    func updateLabels() {
        guard values.count == 2, updated != nil else { return }
        let outdated = connectionError != nil || snapshot?.isStale() == true
        for (index, quota) in [snapshot?.fiveHour, snapshot?.week].enumerated() {
            let value = showUsed ? quota?.clampedUsedPercent : quota?.remainingPercent
            values[index].stringValue = value.map { "\(Int($0.rounded()))%" } ?? "—"
            values[index].textColor = outdated ? .tertiaryLabelColor : .labelColor
            resets[index].stringValue = quota?.resetDescription() ?? "重置时间暂不可用"
            resets[index].textColor = index == 0 && quota?.isResetImminent() == true ? QuotaLevel.caution.color : .secondaryLabelColor
            if index == 0 {
                forecastLabels[index].stringValue = forecastText(forecasts.fiveHour)
                forecastLabels[index].textColor = forecastColor(forecasts.fiveHour)
            } else {
                forecastLabels[index].stringValue = ""
            }
        }
        switch connectionState {
        case .codexNotInstalled: updated.stringValue = "未找到 Codex"
        case .authenticationRequired: updated.stringValue = "请先在 Codex 中登录"
        case .disconnected: updated.stringValue = "连接中断 · 自动重试"
        case .locating where snapshot == nil: updated.stringValue = "正在查找 Codex…"
        default: if let snapshot {
            let format = DateFormatter(); format.dateFormat = "HH:mm:ss"
            let signal = usageAlert.chineseLabel ?? (snapshot.fiveHour?.isResetImminent() == true ? "5 小时额度即将重置" : nil)
            updated.stringValue = signal ?? ("最近更新 \(format.string(from: snapshot.fetchedAt))" + (outdated ? " · 已过期" : ""))
            updated.textColor = signal == nil ? .secondaryLabelColor : (usageAlert == .spike ? QuotaLevel.low.color : QuotaLevel.caution.color)
        } else { updated.stringValue = "正在读取额度…"; updated.textColor = .secondaryLabelColor }
        }
        automatic.stringValue = showUsed ? "已用额度" : "采样 \(forecastSampleCount)"
    }
    private func forecastText(_ forecast: QuotaForecast) -> String {
        guard connectionError == nil, snapshot?.isStale() != true else {
            return hasForecastSampleData ? "" : "收集中，稍后开始预测"
        }
        guard hasForecastSampleData else { return "收集中，稍后开始预测" }
        switch forecast.outcome {
        case .collecting: return ""
        case .unstable: return "● 消耗速率不稳定，暂不预测"
        case .willNotDeplete: return "本周期内不会用尽"
        case .depletedAt(let date):
            let confidence = forecast.confidence.map { " · 可信度：\($0.chineseLabel)" } ?? ""
            if let range = forecast.depletionRange {
                return "● \(depletionRangeText(range)) 用尽\(confidence)"
            }
            let format = DateFormatter()
            format.dateFormat = Calendar.current.isDateInToday(date) ? "预计 HH:mm 用尽" : "预计 M/d HH:mm 用尽"
            return "● \(format.string(from: date))\(confidence)"
        }
    }
    private func depletionRangeText(_ range: DateInterval) -> String {
        let format = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDateInToday(range.start), calendar.isDateInToday(range.end) {
            format.dateFormat = "HH:mm"
            return "约 \(format.string(from: range.start))–\(format.string(from: range.end))"
        }
        format.dateFormat = "M/d HH:mm"
        return "约 \(format.string(from: range.start))–\(format.string(from: range.end))"
    }
    private func forecastColor(_ forecast: QuotaForecast) -> NSColor {
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
    private var guidanceTitle: String? {
        switch connectionState {
        case .codexNotInstalled: return "安装 Codex"
        default: return nil
        }
    }
    private func rebuildGuidance() {
        guidanceButton?.removeFromSuperview(); guidanceButton = nil
        guard let title = guidanceTitle else { return }
        let button = NSButton(title: title, target: self, action: #selector(installCodex))
        button.bezelStyle = .rounded
        button.controlSize = .small
        let scale = metrics.scale
        button.frame = NSRect(x: 16 * scale, y: metrics.detail.height + 4 * scale, width: 104 * scale, height: 28 * scale)
        addSubview(button); guidanceButton = button
    }
    @objc private func installCodex() { onInstallCodex?() }
}
