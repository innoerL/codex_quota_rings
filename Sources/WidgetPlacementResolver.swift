import CoreGraphics

enum WidgetPlacementResolver {
    private enum Edge: CaseIterable {
        case left
        case right
        case above
        case below

        var slidesVertically: Bool {
            switch self {
            case .left, .right: true
            case .above, .below: false
            }
        }
    }

    private static let gap: CGFloat = 8
    private static let snapThreshold: CGFloat = 28

    static func resolve(panelFrame: CGRect, screenFrame: CGRect, codexFrames: [CGRect], occupiedFrames: [CGRect]) -> CGRect {
        let fallback = clamped(panelFrame, to: screenFrame)
        guard !codexFrames.isEmpty, screenFrame.width > 0, screenFrame.height > 0 else { return fallback }

        let codexFrame = codexFrames.min { squaredDistance(from: panelFrame.center, to: $0.center) < squaredDistance(from: panelFrame.center, to: $1.center) }
        guard let codexFrame else { return fallback }

        let candidates = Edge.allCases.compactMap { edge -> CGRect? in
            guard isNear(edge, panelFrame: panelFrame, codexFrame: codexFrame) else { return nil }
            return fittedCandidate(for: edge, panelFrame: fallback, codexFrame: codexFrame, screenFrame: screenFrame, occupiedFrames: occupiedFrames)
        }

        return candidates.min { squaredDistance(from: $0.origin, to: fallback.origin) < squaredDistance(from: $1.origin, to: fallback.origin) } ?? fallback
    }

    private static func isNear(_ edge: Edge, panelFrame: CGRect, codexFrame: CGRect) -> Bool {
        let distance: CGFloat
        switch edge {
        case .left: distance = abs(panelFrame.maxX - codexFrame.minX)
        case .right: distance = abs(panelFrame.minX - codexFrame.maxX)
        case .above: distance = abs(panelFrame.minY - codexFrame.maxY)
        case .below: distance = abs(panelFrame.maxY - codexFrame.minY)
        }
        return distance <= snapThreshold
    }

    private static func fittedCandidate(for edge: Edge, panelFrame: CGRect, codexFrame: CGRect, screenFrame: CGRect, occupiedFrames: [CGRect]) -> CGRect? {
        var candidate = panelFrame
        switch edge {
        case .left: candidate.origin.x = codexFrame.minX - gap - candidate.width
        case .right: candidate.origin.x = codexFrame.maxX + gap
        case .above: candidate.origin.y = codexFrame.maxY + gap
        case .below: candidate.origin.y = codexFrame.minY - gap - candidate.height
        }
        candidate = clamped(candidate, to: screenFrame)

        let axisRange: ClosedRange<CGFloat>
        let desiredAxis: CGFloat
        let blockedRanges: [ClosedRange<CGFloat>]
        if edge.slidesVertically {
            axisRange = screenFrame.minY...(screenFrame.maxY - candidate.height)
            desiredAxis = candidate.minY
            blockedRanges = occupiedFrames.compactMap { occupied in
                guard overlaps(candidate.minX, candidate.maxX, occupied.minX, occupied.maxX) else { return nil }
                return (occupied.minY - candidate.height)...occupied.maxY
            }
        } else {
            axisRange = screenFrame.minX...(screenFrame.maxX - candidate.width)
            desiredAxis = candidate.minX
            blockedRanges = occupiedFrames.compactMap { occupied in
                guard overlaps(candidate.minY, candidate.maxY, occupied.minY, occupied.maxY) else { return nil }
                return (occupied.minX - candidate.width)...occupied.maxX
            }
        }

        guard let resolvedAxis = closestFreeCoordinate(to: desiredAxis, in: axisRange, blockedBy: blockedRanges) else { return nil }
        if edge.slidesVertically {
            candidate.origin.y = resolvedAxis
        } else {
            candidate.origin.x = resolvedAxis
        }
        return candidate
    }

    private static func closestFreeCoordinate(to desired: CGFloat, in domain: ClosedRange<CGFloat>, blockedBy blockedRanges: [ClosedRange<CGFloat>]) -> CGFloat? {
        let sorted = blockedRanges.compactMap { range -> ClosedRange<CGFloat>? in
            let lower = max(range.lowerBound, domain.lowerBound)
            let upper = min(range.upperBound, domain.upperBound)
            return lower <= upper ? lower...upper : nil
        }.sorted { $0.lowerBound < $1.lowerBound }

        var freeRanges: [ClosedRange<CGFloat>] = []
        var cursor = domain.lowerBound
        for blocked in sorted {
            if cursor < blocked.lowerBound { freeRanges.append(cursor...blocked.lowerBound) }
            cursor = max(cursor, blocked.upperBound)
        }
        if cursor < domain.upperBound { freeRanges.append(cursor...domain.upperBound) }

        return freeRanges.min { left, right in
            let leftDistance = abs(clamp(desired, to: left) - desired)
            let rightDistance = abs(clamp(desired, to: right) - desired)
            return leftDistance < rightDistance
        }.map { clamp(desired, to: $0) }
    }

    private static func clamped(_ frame: CGRect, to screenFrame: CGRect) -> CGRect {
        let width = min(frame.width, screenFrame.width)
        let height = min(frame.height, screenFrame.height)
        return CGRect(
            x: clamp(frame.minX, to: screenFrame.minX...(screenFrame.maxX - width)),
            y: clamp(frame.minY, to: screenFrame.minY...(screenFrame.maxY - height)),
            width: width,
            height: height
        )
    }

    private static func clamp(_ value: CGFloat, to range: ClosedRange<CGFloat>) -> CGFloat {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private static func overlaps(_ firstMin: CGFloat, _ firstMax: CGFloat, _ secondMin: CGFloat, _ secondMax: CGFloat) -> Bool {
        firstMin < secondMax && firstMax > secondMin
    }

    private static func squaredDistance(from left: CGPoint, to right: CGPoint) -> CGFloat {
        let x = left.x - right.x
        let y = left.y - right.y
        return x * x + y * y
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}
