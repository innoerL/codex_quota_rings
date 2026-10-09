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
        let chart = rect.insetBy(dx: 1, dy: 15)
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
        drawLegendDot(at: NSPoint(x: rect.minX + 2, y: rect.maxY - 7), color: NSColor(srgbRed: 180/255, green: 138/255, blue: 74/255, alpha: 1))
        drawText("5 小时用量", at: NSPoint(x: rect.minX + 10, y: rect.maxY - 13), color: .secondaryLabelColor)
        let range: String
        switch retention {
        case .session30Minutes: range = "近 30 分钟"
        case .local24Hours: range = "近 24 小时"
        case .local7Days: range = "近 7 天"
        }
        let width = (range as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 8.5)]).width
        drawText(range, at: NSPoint(x: rect.maxX - width, y: rect.maxY - 13), color: .tertiaryLabelColor)
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
}

final class QuotaTrendView: NSView {
    var samples: [QuotaHistorySample] = [] { didSet { needsDisplay = true } }
    var retention: HistoryRetention = .session30Minutes { didSet { needsDisplay = true } }
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        QuotaTrendRenderer.draw(series: .make(samples: samples), retention: retention, in: bounds)
    }
}
