import AppKit

/// Native popover material and labels; all data updates are automatic.
final class QuotaDetailsView: NSView {
    static let preferredSize = NSSize(width: 246, height: 154)
    var snapshot: QuotaSnapshot? { didSet { updateLabels() } }
    var connectionError: String? { didSet { updateLabels() } }
    var showUsed = false { didSet { updateLabels() } }
    private let material = NSVisualEffectView()
    private var values: [NSTextField] = []
    private var resets: [NSTextField] = []
    private var updated: NSTextField!
    private var automatic: NSTextField!
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
            let top = CGFloat(17 + index * 52)
            _ = label(title, frame: NSRect(x: 16, y: top, width: 100, height: 17), font: .systemFont(ofSize: 11, weight: .medium), color: .labelColor)
            let value = label("—", frame: NSRect(x: 147, y: top-1, width: 83, height: 19), font: .monospacedDigitSystemFont(ofSize: 13, weight: .semibold), color: .labelColor)
            value.alignment = .right; values.append(value)
            resets.append(label("", frame: NSRect(x: 16, y: top+22, width: 214, height: 15), font: .systemFont(ofSize: 9.5), color: .secondaryLabelColor))
        }
        let separator = NSBox(frame: NSRect(x: 16, y: 118, width: 214, height: 1))
        separator.boxType = .separator; addSubview(separator)
        updated = label("", frame: NSRect(x: 16, y: 129, width: 160, height: 14), font: .systemFont(ofSize: 9), color: .secondaryLabelColor)
        automatic = label("自动刷新", frame: NSRect(x: 177, y: 129, width: 53, height: 14), font: .systemFont(ofSize: 9), color: .tertiaryLabelColor)
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
        }
        if connectionError != nil { updated.stringValue = "连接中断 · 自动重试" }
        else if let snapshot {
            let format = DateFormatter(); format.dateFormat = "HH:mm:ss"
            updated.stringValue = "最近更新 \(format.string(from: snapshot.fetchedAt))" + (outdated ? " · 已过期" : "")
        } else { updated.stringValue = "正在读取额度…" }
        automatic.stringValue = showUsed ? "已用额度" : "自动刷新"
    }
}
