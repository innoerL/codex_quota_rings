import AppKit

struct QuotaTrendPoint: Equatable {
    let x: Double
    let y: Double
}

struct QuotaTrendSeries: Equatable {
    let fiveHour: [[QuotaTrendPoint]]

    static func make(samples: [QuotaHistorySample]) -> QuotaTrendSeries {
        let ordered = samples.sorted { $0.timestamp < $1.timestamp }
        guard let first = ordered.first?.timestamp, let last = ordered.last?.timestamp else {
            return QuotaTrendSeries(fiveHour: [])
        }
        let span = max(0, last.timeIntervalSince(first))
        func segments(value: (QuotaHistorySample) -> Double?) -> [[QuotaTrendPoint]] {
            var result: [[QuotaTrendPoint]] = []
            var current: [QuotaTrendPoint] = []
            var previousUsed: Double?
            for sample in ordered {
                guard let used = value(sample), used.isFinite else {
                    if !current.isEmpty { result.append(current); current = [] }
                    previousUsed = nil
                    continue
                }
                let normalizedUsed = min(100, max(0, used))
                if let previousUsed, previousUsed - normalizedUsed > 25, !current.isEmpty {
                    result.append(current); current = []
                }
                let x = span > 0 ? sample.timestamp.timeIntervalSince(first) / span : 0
                current.append(QuotaTrendPoint(x: min(1, max(0, x)), y: 1 - normalizedUsed / 100))
                previousUsed = normalizedUsed
            }
            if !current.isEmpty { result.append(current) }
            return result
        }
        return QuotaTrendSeries(fiveHour: segments { $0.fiveHourUsedPercent })
    }
}

struct QuotaTrendHover: Equatable {
    let sample: QuotaHistorySample
    /// Percentage points of five-hour quota consumed per hour, when the prior
    /// point belongs to the same quota-reset segment.
    let hourlyConsumption: Double?
}

enum QuotaTrendInteraction {
    static func nearestSample(at normalizedX: Double, in samples: [QuotaHistorySample]) -> QuotaTrendHover? {
        let usable = samples.filter { $0.fiveHourUsedPercent?.isFinite == true }.sorted { $0.timestamp < $1.timestamp }
        guard let first = usable.first, let last = usable.last else { return nil }
        let span = last.timestamp.timeIntervalSince(first.timestamp)
        let target = first.timestamp.addingTimeInterval(max(0, min(1, normalizedX)) * max(0, span))
        guard let index = usable.indices.min(by: {
            abs(usable[$0].timestamp.timeIntervalSince(target)) < abs(usable[$1].timestamp.timeIntervalSince(target))
        }) else { return nil }
        let sample = usable[index]
        guard index > usable.startIndex,
              let previous = usable[usable.index(before: index)].fiveHourUsedPercent,
              let used = sample.fiveHourUsedPercent else {
            return QuotaTrendHover(sample: sample, hourlyConsumption: nil)
        }
        let previousSample = usable[usable.index(before: index)]
        let seconds = sample.timestamp.timeIntervalSince(previousSample.timestamp)
        let increase = used - previous
        let rate = seconds > 0 && increase >= 0 && previous - used <= 25 ? increase / seconds * 3_600 : nil
        return QuotaTrendHover(sample: sample, hourlyConsumption: rate)
    }
}

enum QuotaTrendRenderer {
    static let chartHeight: CGFloat = 72

    static func chartRect(in rect: CGRect) -> CGRect {
        NSRect(x: rect.minX + 29, y: rect.minY + 17,
               width: max(24, rect.width - 30), height: max(22, rect.height - 35))
    }

    static func draw(series: QuotaTrendSeries, retention: HistoryRetention, in rect: CGRect) {
        draw(series: series, retention: retention, timeRange: nil, in: rect)
    }

    static func draw(samples: [QuotaHistorySample], retention: HistoryRetention, in rect: CGRect) {
        draw(series: .make(samples: samples), retention: retention, timeRange: timeRange(for: samples), in: rect)
    }

    static func timeRange(for samples: [QuotaHistorySample]) -> (start: Date, end: Date)? {
        guard let start = samples.map(\.timestamp).min(), let end = samples.map(\.timestamp).max() else { return nil }
        return (start, end)
    }

    private static func draw(series: QuotaTrendSeries, retention: HistoryRetention,
                             timeRange: (start: Date, end: Date)?, in rect: CGRect) {
        let chart = chartRect(in: rect)
        NSColor.white.withAlphaComponent(0.045).setFill()
        NSBezierPath(roundedRect: chart, xRadius: 7, yRadius: 7).fill()
        for fraction in [0.25, 0.5, 0.75] as [CGFloat] {
            NSColor.white.withAlphaComponent(0.04).setStroke()
            let grid = NSBezierPath()
            grid.move(to: NSPoint(x: chart.minX, y: chart.minY + chart.height * fraction))
            grid.line(to: NSPoint(x: chart.maxX, y: chart.minY + chart.height * fraction))
            grid.lineWidth = 0.5; grid.stroke()
        }

        draw(series.fiveHour, color: NSColor(srgbRed: 180/255, green: 138/255, blue: 74/255, alpha: 1), in: chart)
        let hasAny = !series.fiveHour.isEmpty
        if !hasAny {
            drawText(localized("正在收集趋势数据", "Collecting trend data"), at: NSPoint(x: chart.midX, y: chart.midY - 6), centered: true,
                     color: .tertiaryLabelColor)
        }
        let tickColor = NSColor.tertiaryLabelColor
        drawRightText("100%", at: NSPoint(x: chart.minX - 5, y: chart.minY - 4), color: tickColor)
        drawRightText("50%", at: NSPoint(x: chart.minX - 5, y: chart.midY - 4), color: tickColor)
        drawRightText("0%", at: NSPoint(x: chart.minX - 5, y: chart.maxY - 10), color: tickColor)
        drawLegendDot(at: NSPoint(x: rect.minX + 2, y: rect.minY + 3), color: NSColor(srgbRed: 180/255, green: 138/255, blue: 74/255, alpha: 1))
        drawText(localized("5 小时用量", "5-hour usage"), at: NSPoint(x: rect.minX + 10, y: rect.minY), color: .secondaryLabelColor)
        let range: String
        switch retention {
        case .session30Minutes: range = localized("近 30 分钟", "Last 30 min")
        case .local5Hours: range = localized("近 5 小时", "Last 5 hours")
        }
        drawRightText(range, at: NSPoint(x: rect.maxX, y: rect.minY), color: .tertiaryLabelColor)
        if let timeRange {
            let formatter = DateFormatter(); formatter.dateFormat = "HH:mm"
            drawText(formatter.string(from: timeRange.start), at: NSPoint(x: chart.minX, y: rect.maxY - 12), color: tickColor)
            drawRightText(localized("现在 \(formatter.string(from: timeRange.end))", "Now \(formatter.string(from: timeRange.end))"), at: NSPoint(x: chart.maxX, y: rect.maxY - 12), color: tickColor)
        } else {
            drawText(localized("开始", "Start"), at: NSPoint(x: chart.minX, y: rect.maxY - 12), color: tickColor)
            drawRightText(localized("现在", "Now"), at: NSPoint(x: chart.maxX, y: rect.maxY - 12), color: tickColor)
        }
    }

    private static func draw(_ segments: [[QuotaTrendPoint]], color: NSColor, in rect: CGRect) {
        for segment in segments {
            let path = NSBezierPath()
            for (index, point) in segment.enumerated() {
                let location = NSPoint(x: rect.minX + rect.width * CGFloat(point.x),
                                       y: rect.maxY - rect.height * CGFloat(point.y))
                if index == 0 { path.move(to: location) } else { path.line(to: location) }
                if segment.count == 1 {
                    color.setFill(); NSBezierPath(ovalIn: NSRect(x: location.x - 1.5, y: location.y - 1.5, width: 3, height: 3)).fill()
                }
            }
            color.withAlphaComponent(0.9).setStroke(); path.lineWidth = 1.6; path.lineCapStyle = .round; path.lineJoinStyle = .round; path.stroke()
        }
    }

    static func drawHover(_ hover: QuotaTrendHover, position: CGFloat, in rect: CGRect) {
        guard let used = hover.sample.fiveHourUsedPercent else { return }
        let chart = chartRect(in: rect)
        let normalized = min(100, max(0, used)) / 100
        let point = NSPoint(x: chart.minX + chart.width * min(1, max(0, position)),
                            y: chart.minY + chart.height * normalized)
        NSColor.white.withAlphaComponent(0.36).setStroke()
        let guide = NSBezierPath()
        guide.move(to: NSPoint(x: point.x, y: chart.minY)); guide.line(to: NSPoint(x: point.x, y: chart.maxY))
        guide.lineWidth = 0.5; guide.stroke()
        NSColor(srgbRed: 180/255, green: 138/255, blue: 74/255, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)).fill()

        let formatter = DateFormatter(); formatter.dateFormat = "HH:mm:ss"
        let rate = hover.hourlyConsumption.map { localized(String(format: "%.1f%%/小时", $0), String(format: "%.1f%%/hour", $0)) } ?? localized("速率收集中", "Collecting rate")
        let text = localized("\(formatter.string(from: hover.sample.timestamp)) · 已用 \(Int(used.rounded()))% · \(rate)", "\(formatter.string(from: hover.sample.timestamp)) · \(Int(used.rounded()))% used · \(rate)")
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 8.5, weight: .medium), .foregroundColor: NSColor.labelColor]
        let size = (text as NSString).size(withAttributes: attributes)
        let width = min(max(118, size.width + 12), rect.width - 4)
        let bubble = NSRect(x: min(max(rect.minX + 2, point.x - width / 2), rect.maxX - width - 2),
                            y: rect.minY + 15, width: width, height: 17)
        NSColor(white: 0.12, alpha: 0.96).setFill()
        NSBezierPath(roundedRect: bubble, xRadius: 5, yRadius: 5).fill()
        NSColor.white.withAlphaComponent(0.18).setStroke()
        NSBezierPath(roundedRect: bubble, xRadius: 5, yRadius: 5).stroke()
        let textPoint = NSPoint(x: bubble.minX + 6, y: bubble.minY + (bubble.height - size.height) / 2)
        (text as NSString).draw(at: textPoint, withAttributes: attributes)
    }

    private static func drawLegendDot(at point: NSPoint, color: NSColor) {
        color.setFill(); NSBezierPath(ovalIn: NSRect(x: point.x, y: point.y, width: 5, height: 5)).fill()
    }

    private static func drawText(_ text: String, at point: NSPoint, centered: Bool = false, color: NSColor) {
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 8.5), .foregroundColor: color]
        let size = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(at: NSPoint(x: centered ? point.x - size.width / 2 : point.x, y: point.y), withAttributes: attributes)
    }

    private static func drawRightText(_ text: String, at point: NSPoint, color: NSColor) {
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 8.5), .foregroundColor: color]
        let width = (text as NSString).size(withAttributes: attributes).width
        (text as NSString).draw(at: NSPoint(x: point.x - width, y: point.y), withAttributes: attributes)
    }
}

final class QuotaTrendView: NSView {
    var samples: [QuotaHistorySample] = [] { didSet { needsDisplay = true } }
    var retention: HistoryRetention = .session30Minutes { didSet { needsDisplay = true } }
    private var hover: QuotaTrendHover? { didSet { needsDisplay = true } }
    private var tracking: NSTrackingArea?
    override var isFlipped: Bool { true }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area)
        tracking = area
    }
    override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let chart = QuotaTrendRenderer.chartRect(in: bounds)
        guard chart.contains(location) else { hover = nil; return }
        let normalizedX = (location.x - chart.minX) / max(chart.width, 1)
        hover = QuotaTrendInteraction.nearestSample(at: normalizedX, in: samples)
    }
    override func mouseExited(with event: NSEvent) { hover = nil }
    override func draw(_ dirtyRect: NSRect) {
        QuotaTrendRenderer.draw(samples: samples, retention: retention, in: bounds)
        guard let hover,
              let range = QuotaTrendRenderer.timeRange(for: samples) else { return }
        let span = range.end.timeIntervalSince(range.start)
        let position = span > 0 ? hover.sample.timestamp.timeIntervalSince(range.start) / span : 0
        QuotaTrendRenderer.drawHover(hover, position: position, in: bounds)
    }
}
