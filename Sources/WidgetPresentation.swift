import AppKit

extension QuotaLevel {
    var color: NSColor {
        switch self {
        case .ample: return NSColor(srgbRed: 143/255, green: 169/255, blue: 144/255, alpha: 1)
        case .steady: return NSColor(srgbRed: 180/255, green: 138/255, blue: 74/255, alpha: 1)
        case .caution: return NSColor(srgbRed: 189/255, green: 122/255, blue: 112/255, alpha: 1)
        // 使用比陶土红更深、更冷的红色，突出紧急状态并避免纯警报红。
        case .low: return NSColor(srgbRed: 142/255, green: 75/255, blue: 88/255, alpha: 1)
        case .unknown: return NSColor(white: 0.42, alpha: 1)
        }
    }
}

enum WidgetRingTheme: String, CaseIterable {
    case semantic
    case graphite
    case warm
    case systemAccent

    func color(for level: QuotaLevel) -> NSColor {
        switch self {
        case .semantic:
            return level.color
        case .graphite:
            switch level {
            case .ample: return NSColor(white: 0.78, alpha: 1)
            case .steady: return NSColor(white: 0.70, alpha: 1)
            case .caution: return NSColor(white: 0.62, alpha: 1)
            case .low: return NSColor(white: 0.46, alpha: 1)
            case .unknown: return NSColor(white: 0.42, alpha: 1)
            }
        case .warm:
            switch level {
            case .ample: return NSColor(srgbRed: 216/255, green: 163/255, blue: 92/255, alpha: 1)
            case .steady: return NSColor(srgbRed: 207/255, green: 151/255, blue: 82/255, alpha: 1)
            case .caution: return NSColor(srgbRed: 197/255, green: 132/255, blue: 71/255, alpha: 1)
            case .low: return NSColor(srgbRed: 177/255, green: 91/255, blue: 79/255, alpha: 1)
            case .unknown: return NSColor(white: 0.42, alpha: 1)
            }
        case .systemAccent:
            return level == .unknown ? NSColor(white: 0.42, alpha: 1) : NSColor.controlAccentColor
        }
    }
}

struct WidgetAppearancePalette {
    let isDark: Bool

    init(appearance: NSAppearance) {
        isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    var surface: NSColor { NSColor(white: isDark ? 0.14 : 0.94, alpha: 0.97) }
    var highContrastSurface: NSColor { NSColor(white: isDark ? 0.09 : 0.99, alpha: 1) }
    var border: NSColor { (isDark ? NSColor.white : .black).withAlphaComponent(isDark ? 0.11 : 0.14) }
    var highContrastBorder: NSColor { (isDark ? NSColor.white : .black).withAlphaComponent(0.20) }
    var track: NSColor { (isDark ? NSColor.white : .black).withAlphaComponent(isDark ? 0.10 : 0.17) }
    var minimalTrack: NSColor { (isDark ? NSColor.white : .black).withAlphaComponent(isDark ? 0.16 : 0.22) }
    var foreground: NSColor { isDark ? .white : .black }
    var hoverFill: NSColor { foreground.withAlphaComponent(isDark ? 0.035 : 0.045) }

    func color(for level: QuotaLevel, theme: WidgetRingTheme = .semantic) -> NSColor {
        if isDark { return theme.color(for: level) }
        switch theme {
        case .semantic:
            switch level {
            case .ample: return NSColor(srgbRed: 83/255, green: 116/255, blue: 88/255, alpha: 1)
            case .steady: return NSColor(srgbRed: 149/255, green: 104/255, blue: 31/255, alpha: 1)
            case .caution: return NSColor(srgbRed: 160/255, green: 79/255, blue: 67/255, alpha: 1)
            case .low: return NSColor(srgbRed: 136/255, green: 59/255, blue: 80/255, alpha: 1)
            case .unknown: return NSColor(white: 0.46, alpha: 1)
            }
        case .graphite:
            switch level {
            case .ample: return NSColor(white: 0.27, alpha: 1)
            case .steady: return NSColor(white: 0.34, alpha: 1)
            case .caution: return NSColor(white: 0.41, alpha: 1)
            case .low: return NSColor(white: 0.48, alpha: 1)
            case .unknown: return NSColor(white: 0.52, alpha: 1)
            }
        case .warm:
            switch level {
            case .ample: return NSColor(srgbRed: 154/255, green: 95/255, blue: 35/255, alpha: 1)
            case .steady: return NSColor(srgbRed: 169/255, green: 97/255, blue: 38/255, alpha: 1)
            case .caution: return NSColor(srgbRed: 160/255, green: 78/255, blue: 40/255, alpha: 1)
            case .low: return NSColor(srgbRed: 139/255, green: 57/255, blue: 63/255, alpha: 1)
            case .unknown: return NSColor(white: 0.46, alpha: 1)
            }
        case .systemAccent:
            return level == .unknown ? NSColor(white: 0.46, alpha: 1) : .controlAccentColor
        }
    }
}

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
    case minimal

    var scale: CGFloat {
        1
    }
}

struct WidgetLayoutMetrics: Equatable {
    let scale: CGFloat
    let isMinimal: Bool
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
        isMinimal = density == .minimal
        func size(_ width: CGFloat, _ height: CGFloat) -> CGSize { CGSize(width: width * factor, height: height * factor) }
        // 极简模式将两个额度窗口合并为同一个小型方块。
        smallVertical = density == .minimal ? CGSize(width: 42, height: 42) : size(42, 124)
        smallHorizontal = size(104, 68)
        largeCollapsed = size(280, 174)
        largeExpandedBaseHeight = 568 * scale
        detail = size(246, 324)
        compactRingRadius = 15 * scale
        largeRingRadius = 28 * scale
        gap = 8 * scale
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        func equal(_ first: CGSize, _ second: CGSize) -> Bool {
            first.width == second.width && first.height == second.height
        }
        return lhs.scale == rhs.scale
            && lhs.isMinimal == rhs.isMinimal
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
