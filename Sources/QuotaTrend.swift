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

enum QuotaTrendRenderer {
    static let chartHeight: CGFloat = 72

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
        let chart = NSRect(x: rect.minX + 29, y: rect.minY + 17,
                           width: max(24, rect.width - 30), height: max(22, rect.height - 35))
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
            drawText("正在收集趋势数据", at: NSPoint(x: chart.midX, y: chart.midY - 6), centered: true,
                     color: .tertiaryLabelColor)
        }
        let tickColor = NSColor.tertiaryLabelColor
        drawRightText("100%", at: NSPoint(x: chart.minX - 5, y: chart.minY - 4), color: tickColor)
        drawRightText("50%", at: NSPoint(x: chart.minX - 5, y: chart.midY - 4), color: tickColor)
        drawRightText("0%", at: NSPoint(x: chart.minX - 5, y: chart.maxY - 10), color: tickColor)
        drawLegendDot(at: NSPoint(x: rect.minX + 2, y: rect.minY + 3), color: NSColor(srgbRed: 180/255, green: 138/255, blue: 74/255, alpha: 1))
        drawText("5 小时用量", at: NSPoint(x: rect.minX + 10, y: rect.minY), color: .secondaryLabelColor)
        let range: String
        switch retention {
        case .session30Minutes: range = "近 30 分钟"
        case .local24Hours: range = "近 24 小时"
        case .local7Days: range = "近 7 天"
        }
        drawRightText(range, at: NSPoint(x: rect.maxX, y: rect.minY), color: .tertiaryLabelColor)
        if let timeRange {
            let formatter = DateFormatter(); formatter.dateFormat = "HH:mm"
            drawText(formatter.string(from: timeRange.start), at: NSPoint(x: chart.minX, y: rect.maxY - 12), color: tickColor)
            drawRightText("现在 \(formatter.string(from: timeRange.end))", at: NSPoint(x: chart.maxX, y: rect.maxY - 12), color: tickColor)
        } else {
            drawText("开始", at: NSPoint(x: chart.minX, y: rect.maxY - 12), color: tickColor)
            drawRightText("现在", at: NSPoint(x: chart.maxX, y: rect.maxY - 12), color: tickColor)
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
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        QuotaTrendRenderer.draw(samples: samples, retention: retention, in: bounds)
    }
}
