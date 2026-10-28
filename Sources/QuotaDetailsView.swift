import AppKit

/// 原生弹出卡片材质与文字，所有数据均自动更新。
final class QuotaDetailsView: NSView {
    static let preferredSize = NSSize(width: 246, height: 324)
    private var guidanceHeight: CGFloat { guidanceTitle == nil ? 0 : 38 * metrics.scale }
    var preferredContentSize: NSSize { NSSize(width: metrics.detail.width, height: metrics.detail.height + guidanceHeight) }
    var metrics = WidgetLayoutMetrics(density: .standard) { didSet { applyPresentation() } }
    var contentOpacity: CGFloat = WidgetOpacityPreset.opaque.alpha { didSet { applyPresentation() } }
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
            updateLabels()
        }
    }
    var forecasts = QuotaForecasts.collecting { didSet { updateLabels() } }
    var forecastChange: ForecastChange? { didSet { updateLabels() } }
    var hasForecastSampleData = false { didSet { updateLabels() } }
    var forecastSampleCount = 0 { didSet { updateLabels() } }
    var connectionError: String? {
        didSet {
            if connectionError != nil { fiveHourTransition = nil; weekTransition = nil }
            updateLabels()
        }
    }
    var connectionState: QuotaConnectionState = .locating { didSet { updateLabels(); rebuildGuidance() } }
    var historySamples: [QuotaHistorySample] = [] { didSet { trend.samples = historySamples } }
    var historyRetention: HistoryRetention = .session30Minutes { didSet { trend.retention = historyRetention } }
    var onInstallCodex: (() -> Void)?
    var onPointerEntered: (() -> Void)?
    var onPointerExited: (() -> Void)?
    var showUsed = false { didSet { updateLabels() } }
    var usageAlert: QuotaUsageAlert = .none { didSet { updateLabels() } }
    var spikeEvidence: QuotaSpikeEvidence? { didSet { updateLabels() } }
    var lowQuotaContrastMode = false { didSet { applyPresentation() } }
    private let material = NSVisualEffectView()
    private var titles: [NSTextField] = []
    private var values: [NSTextField] = []
    private var resets: [NSTextField] = []
    private var forecastLabels: [NSTextField] = []
    private var planLabel: NSTextField!
    private var resetCreditLabel: NSTextField!
    private var updated: NSTextField!
    private var automatic: NSTextField!
    private let trend = QuotaTrendView()
    private var guidanceButton: NSButton?
    private var baseFrames: [ObjectIdentifier: NSRect] = [:]
    private var hoverTracking: NSTrackingArea?
    var isQuotaTransitionActive: Bool {
        let date = Date()
        return fiveHourTransition?.isActive(at: date) == true || weekTransition?.isActive(at: date) == true
    }
    @discardableResult func advanceQuotaTransition(at date: Date = Date()) -> Bool {
        let wasAnimating = fiveHourTransition != nil || weekTransition != nil
        if fiveHourTransition?.isActive(at: date) == false { fiveHourTransition = nil }
        if weekTransition?.isActive(at: date) == false { weekTransition = nil }
        if wasAnimating { updateLabels() }
        return fiveHourTransition != nil || weekTransition != nil
    }
    private func displayedUsedPercent(for quota: QuotaWindow?, isPrimary: Bool, at date: Date) -> Double? {
        guard let used = quota?.clampedUsedPercent else { return nil }
        let transition = isPrimary ? fiveHourTransition : weekTransition
        return transition?.usedPercent(at: date) ?? used
    }
    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.masksToBounds = true
        layer?.borderWidth = 0.5
        layer?.borderColor = palette.border.cgColor
        material.frame = bounds
        material.autoresizingMask = [.width, .height]
        material.material = .popover
        material.blendingMode = .behindWindow
        material.state = .active
        addSubview(material)
        for index in 0..<2 {
            let top = CGFloat(17 + index * 66)
            let title = index == 0 ? localized("5 小时", "5 hours") : localized("一周", "Week")
            titles.append(label(title, frame: NSRect(x: 16, y: top, width: 100, height: 17), font: .systemFont(ofSize: 11, weight: .medium), color: .labelColor))
            let value = label("—", frame: NSRect(x: 147, y: top-1, width: 83, height: 19), font: .monospacedDigitSystemFont(ofSize: 13, weight: .semibold), color: .labelColor)
            value.alignment = .right; values.append(value)
            resets.append(label("", frame: NSRect(x: 16, y: top+22, width: 214, height: 15), font: .systemFont(ofSize: 9.5), color: .secondaryLabelColor))
            forecastLabels.append(label("", frame: NSRect(x: 16, y: top+40, width: 214, height: 14), font: .systemFont(ofSize: 9.5, weight: .medium), color: .secondaryLabelColor))
        }
        trend.frame = NSRect(x: 16, y: 148, width: 214, height: 96)
        trend.autoresizingMask = [.width]
        addSubview(trend)
        planLabel = label("", frame: NSRect(x: 16, y: 251, width: 214, height: 15), font: .systemFont(ofSize: 9.5), color: .secondaryLabelColor)
        resetCreditLabel = label("", frame: NSRect(x: 16, y: 269, width: 214, height: 15), font: .systemFont(ofSize: 9.5), color: .secondaryLabelColor)
        let separator = NSBox(frame: NSRect(x: 16, y: 288, width: 214, height: 1))
        separator.boxType = .separator; addSubview(separator)
        updated = label("", frame: NSRect(x: 16, y: 301, width: 160, height: 14), font: .systemFont(ofSize: 9), color: .secondaryLabelColor)
        automatic = label(localized("自动刷新", "Auto refresh"), frame: NSRect(x: 177, y: 301, width: 53, height: 14), font: .systemFont(ofSize: 9), color: .tertiaryLabelColor)
        automatic.alignment = .right
        captureBaseFrames()
        applyPresentation()
        updateLabels()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private var palette: WidgetAppearancePalette { WidgetAppearancePalette(appearance: effectiveAppearance) }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyPresentation()
        trend.needsDisplay = true
    }
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
        layer?.borderColor = (lowQuotaContrastMode ? palette.highContrastBorder : palette.border).cgColor
        material.alphaValue = 1
        material.material = lowQuotaContrastMode ? .sidebar : .popover
        material.frame = bounds
        for subview in subviews where subview !== material {
            guard let frame = baseFrames[ObjectIdentifier(subview)] else { continue }
            subview.frame = NSRect(x: frame.minX * scale, y: frame.minY * scale, width: frame.width * scale, height: frame.height * scale)
        }
        needsDisplay = true
        updateLabels()
    }
    func updateLabels() {
        guard values.count == 2, updated != nil else { return }
        let outdated = connectionError != nil || snapshot?.isStale() == true
        for (index, quota) in [snapshot?.fiveHour, snapshot?.week].enumerated() {
            let used = displayedUsedPercent(for: quota, isPrimary: index == 0, at: Date())
            let value = showUsed ? used : used.map { 100 - $0 }
            values[index].stringValue = value.map { "\(Int($0.rounded()))%" } ?? "—"
            values[index].textColor = outdated ? .tertiaryLabelColor : .labelColor
            resets[index].stringValue = quota?.resetDescription() ?? localized("重置时间暂不可用", "Reset time unavailable")
            resets[index].textColor = index == 0 && quota?.isResetImminent() == true ? palette.color(for: .caution) : .secondaryLabelColor
            if index == 0 {
                forecastLabels[index].stringValue = forecastText(forecasts.fiveHour)
                forecastLabels[index].textColor = forecastColor(forecasts.fiveHour)
            } else {
                let pace = outdated ? nil : quota?.weeklyPace(at: snapshot?.fetchedAt ?? Date())
                forecastLabels[index].stringValue = pace?.localizedLabel ?? ""
                forecastLabels[index].textColor = pace?.state == .ahead ? palette.color(for: .caution) : .secondaryLabelColor
            }
        }
        planLabel.stringValue = snapshot?.planDescription ?? ""
        resetCreditLabel.stringValue = snapshot?.resetCreditCompactDescription ?? ""
        switch connectionState {
        case .codexNotInstalled: updated.stringValue = localized("未找到 Codex", "Codex was not found")
        case .authenticationRequired: updated.stringValue = localized("请先在 Codex 中登录", "Please sign in to Codex first")
        case .disconnected: updated.stringValue = localized("连接中断 · 自动重试", "Connection interrupted · retrying")
        case .locating where snapshot == nil: updated.stringValue = localized("正在查找 Codex…", "Looking for Codex…")
        default: if let snapshot {
            let format = DateFormatter(); format.dateFormat = "HH:mm:ss"
            let spike = usageAlert == .spike && !outdated
            let signal = (spike ? spikeEvidence?.localizedLabel ?? usageAlert.localizedLabel : nil) ?? forecastChange?.localizedLabel
                ?? (snapshot.fiveHour?.isResetImminent() == true ? localized("5 小时额度即将重置", "5-hour quota resets soon") : nil)
            updated.stringValue = signal ?? (localized("最近更新 \(format.string(from: snapshot.fetchedAt))", "Updated \(format.string(from: snapshot.fetchedAt))") + (outdated ? localized(" · 已过期", " · stale") : ""))
            updated.textColor = signal == nil ? .secondaryLabelColor
                : (spike ? palette.color(for: .low) : forecastChange.map { palette.color(for: $0.level) } ?? palette.color(for: .caution))
        } else { updated.stringValue = localized("正在读取额度…", "Reading quota…"); updated.textColor = .secondaryLabelColor }
        }
        let spike = usageAlert == .spike && spikeEvidence != nil && !outdated
        updated.frame.size.width = (spike ? 214 : 160) * metrics.scale
        automatic.stringValue = spike ? "" : showUsed ? localized("已用额度", "Used quota") : localized("采样 \(forecastSampleCount)", "\(forecastSampleCount) samples")
    }
    private func forecastText(_ forecast: QuotaForecast) -> String {
        guard connectionError == nil, snapshot?.isStale() != true else {
            return hasForecastSampleData ? "" : localized("收集中，稍后开始预测", "Collecting; forecast will start shortly")
        }
        guard hasForecastSampleData else { return localized("收集中，稍后开始预测", "Collecting; forecast will start shortly") }
        switch forecast.outcome {
        case .collecting: return ""
        case .unstable: return localized("● 消耗速率不稳定，暂不预测", "● Consumption rate is unstable; no forecast yet")
        case .willNotDeplete: return localized("本周期内不会用尽", "Will not run out this window")
        case .depletedAt(let date):
            let confidence = forecast.confidence.map { localized(" · 可信度：\($0.chineseLabel)", " · confidence: \($0.englishLabel)") } ?? ""
            if let range = forecast.depletionRange {
                return "● \(localized("\(depletionRangeText(range)) 用尽", "\(depletionRangeText(range)) to run out"))\(confidence)"
            }
            let format = DateFormatter()
            format.dateFormat = Calendar.current.isDateInToday(date) ? "HH:mm" : "M/d HH:mm"
            return "● \(localized("预计 \(format.string(from: date)) 用尽", "Expected to run out at \(format.string(from: date))"))\(confidence)"
        }
    }
    private func depletionRangeText(_ range: DateInterval) -> String {
        let format = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDateInToday(range.start), calendar.isDateInToday(range.end) {
            format.dateFormat = "HH:mm"
            return localized("约 \(format.string(from: range.start))–\(format.string(from: range.end))", "Around \(format.string(from: range.start))–\(format.string(from: range.end))")
        }
        format.dateFormat = "M/d HH:mm"
        return localized("约 \(format.string(from: range.start))–\(format.string(from: range.end))", "Around \(format.string(from: range.start))–\(format.string(from: range.end))")
    }
    private func forecastColor(_ forecast: QuotaForecast) -> NSColor {
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
    private var guidanceTitle: String? {
        switch connectionState {
        case .codexNotInstalled: return localized("安装 Codex", "Install Codex")
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
    func refreshLanguage() {
        guard titles.count == 2 else { return }
        titles[0].stringValue = localized("5 小时", "5 hours")
        titles[1].stringValue = localized("一周", "Week")
        updateLabels(); rebuildGuidance()
    }
}
