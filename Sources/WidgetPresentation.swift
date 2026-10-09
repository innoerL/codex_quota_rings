import Foundation

enum WidgetOpacityPreset: String, CaseIterable {
    case opaque
    case translucent
    case light

    var alpha: CGFloat {
        switch self {
        case .opaque: return 0.97
        case .translucent: return 0.82
        case .light: return 0.68
        }
    }
}

enum WidgetDensityPreset: String, CaseIterable {
    case standard
    case compact
    case minimal

    var scale: CGFloat {
        switch self {
        case .standard: return 1.00
        case .compact: return 0.88
        case .minimal: return 0.76
        }
    }
}

struct WidgetLayoutMetrics: Equatable {
    let scale: CGFloat
    let smallVertical: CGSize
    let smallHorizontal: CGSize
    let largeCollapsed: CGSize
    let largeExpandedBaseHeight: CGFloat
    let detail: CGSize
    let compactRingRadius: CGFloat
    let largeRingRadius: CGFloat
    let gap: CGFloat

    init(density: WidgetDensityPreset) {
        let factor = density.scale
        scale = factor
        func size(_ width: CGFloat, _ height: CGFloat) -> CGSize { CGSize(width: width * factor, height: height * factor) }
        smallVertical = size(42, 124)
        smallHorizontal = size(104, 68)
        largeCollapsed = size(280, 174)
        largeExpandedBaseHeight = 456 * scale
        detail = size(246, 284)
        compactRingRadius = 15 * scale
        largeRingRadius = 28 * scale
        gap = 8 * scale
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        func equal(_ first: CGSize, _ second: CGSize) -> Bool {
            first.width == second.width && first.height == second.height
        }
        return lhs.scale == rhs.scale
            && equal(lhs.smallVertical, rhs.smallVertical)
            && equal(lhs.smallHorizontal, rhs.smallHorizontal)
            && equal(lhs.largeCollapsed, rhs.largeCollapsed)
            && lhs.largeExpandedBaseHeight == rhs.largeExpandedBaseHeight
            && equal(lhs.detail, rhs.detail)
            && lhs.compactRingRadius == rhs.compactRingRadius
            && lhs.largeRingRadius == rhs.largeRingRadius
            && lhs.gap == rhs.gap
    }
}
