import AppKit

@main struct WidgetPresentationTests {
    static func main() {
        precondition(WidgetOpacityPreset.opaque.alpha == 0.97)
        precondition(WidgetOpacityPreset.translucent.alpha == 0.82)
        precondition(WidgetOpacityPreset.light.alpha == 0.68)
        precondition(WidgetDensityPreset.standard.scale == 1.00)
        precondition(WidgetDensityPreset.allCases == [.standard, .minimal])
        precondition(WidgetDensityPreset.minimal.scale == 1.00)
        precondition(WidgetRingTheme.allCases == [.semantic, .graphite, .warm, .systemAccent])
        precondition(!WidgetRingTheme.graphite.color(for: .ample).isEqual(WidgetRingTheme.warm.color(for: .ample)),
                     "theme palettes must produce visibly distinct ring colors")
        let deepBerry = QuotaLevel.low.color.usingColorSpace(.deviceRGB)!
        precondition(abs(deepBerry.redComponent - 142 / 255) < 0.001
                     && abs(deepBerry.greenComponent - 75 / 255) < 0.001
                     && abs(deepBerry.blueComponent - 88 / 255) < 0.001,
                     "the emergency semantic color must remain deep berry #8E4B58")
        let dark = WidgetAppearancePalette(appearance: NSAppearance(named: .darkAqua)!)
        let light = WidgetAppearancePalette(appearance: NSAppearance(named: .aqua)!)
        precondition(dark.isDark && !light.isDark, "外观调色板应区分系统浅色和深色")
        precondition(dark.surface.whiteComponent < light.surface.whiteComponent,
                     "浅色背景应明显亮于深色背景")
        precondition(dark.color(for: .low).isEqual(QuotaLevel.low.color),
                     "深色外观应保留原有深莓红")
        precondition(!light.color(for: .low).isEqual(dark.color(for: .low)),
                     "浅色外观应使用对比更清楚的状态色")
        precondition(!light.color(for: .ample, theme: .graphite).isEqual(dark.color(for: .ample, theme: .graphite)),
                     "石墨配色应随系统外观切换")

        for density in WidgetDensityPreset.allCases {
            let metrics = WidgetLayoutMetrics(density: density)
            precondition(metrics.smallVertical.width > 0 && metrics.smallVertical.height > 0)
            precondition(metrics.smallHorizontal.width > 0 && metrics.smallHorizontal.height > 0)
            precondition(metrics.largeCollapsed.width > 0 && metrics.largeCollapsed.height > 0)
            precondition(metrics.detail.width > 0 && metrics.detail.height > 0)
            precondition(metrics.compactRingRadius > 0 && metrics.largeRingRadius > 0 && metrics.gap > 0)
            precondition(metrics.detail == CGSize(width: 246, height: 324)
                         && metrics.largeCollapsed == CGSize(width: 280, height: 174)
                         && metrics.largeExpandedBaseHeight == 568,
                         "额度详情和大卡片在所有模式中保持标准尺寸")
        }
        print("PASS: presentation presets and layout metrics")
    }
}
