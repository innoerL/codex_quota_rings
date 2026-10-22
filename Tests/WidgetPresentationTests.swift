import AppKit

@main struct WidgetPresentationTests {
    static func main() {
        precondition(WidgetOpacityPreset.opaque.alpha == 0.97)
        precondition(WidgetOpacityPreset.translucent.alpha == 0.82)
        precondition(WidgetOpacityPreset.light.alpha == 0.68)
        precondition(WidgetDensityPreset.standard.scale == 1.00)
        precondition(WidgetDensityPreset.compact.scale == 0.88)
        precondition(WidgetDensityPreset.minimal.scale == 0.76)
        precondition(WidgetRingTheme.allCases == [.semantic, .graphite, .warm, .systemAccent])
        precondition(!WidgetRingTheme.graphite.color(for: .ample).isEqual(WidgetRingTheme.warm.color(for: .ample)),
                     "theme palettes must produce visibly distinct ring colors")
        let deepBerry = QuotaLevel.low.color.usingColorSpace(.deviceRGB)!
        precondition(abs(deepBerry.redComponent - 142 / 255) < 0.001
                     && abs(deepBerry.greenComponent - 75 / 255) < 0.001
                     && abs(deepBerry.blueComponent - 88 / 255) < 0.001,
                     "the emergency semantic color must remain deep berry #8E4B58")

        for density in WidgetDensityPreset.allCases {
            let metrics = WidgetLayoutMetrics(density: density)
            precondition(metrics.smallVertical.width > 0 && metrics.smallVertical.height > 0)
            precondition(metrics.smallHorizontal.width > 0 && metrics.smallHorizontal.height > 0)
            precondition(metrics.largeCollapsed.width > 0 && metrics.largeCollapsed.height > 0)
            precondition(metrics.detail.width > 0 && metrics.detail.height > 0)
            precondition(metrics.compactRingRadius > 0 && metrics.largeRingRadius > 0 && metrics.gap > 0)
        }
        print("PASS: presentation presets and layout metrics")
    }
}
