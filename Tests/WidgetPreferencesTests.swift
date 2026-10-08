import Foundation

@main struct WidgetPreferencesTests {
    static func main() {
        let suite = "quota-rings-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var p = WidgetPreferences.load(from: defaults)
        precondition(p.size == .small && p.smallLayout == .vertical && p.displayScope == .focusCodex)
        p.smallLayout = .horizontal; p.displayScope = .focusDesktop; p.size = .large
        p.save(to: defaults)
        let restored = WidgetPreferences.load(from: defaults)
        precondition(restored == p)
        p.size = .small
        precondition(p.smallLayout == .horizontal && p.displayScope == .focusDesktop)
        for scope in DisplayScope.allCases {
            p.displayScope = scope; p.save(to: defaults)
            precondition(WidgetPreferences.load(from: defaults) == p)
        }
        defaults.set("invalid", forKey: "widget.size")
        defaults.set("invalid", forKey: "widget.displayScope")
        let repaired = WidgetPreferences.load(from: defaults)
        precondition(repaired.size == .small && repaired.displayScope == .focusCodex)
        precondition(repaired.smallLayout == .horizontal)
        print("PASS: preference defaults, round trips, independence and invalid-value recovery")
    }
}
