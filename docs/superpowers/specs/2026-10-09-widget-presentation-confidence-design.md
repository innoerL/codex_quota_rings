# Widget Presentation and Forecast Confidence Design

## Goal

Make Quota Rings easier to place and read without expanding its Codex integration. The widget will snap only when dragged, avoid occupied window space at that moment, offer saved visual presets, show a transient detail card on hover, and explain how much confidence to place in a five-hour forecast.

## Scope

- Drag-end snap to the nearest eligible edge of a visible Codex window.
- One-time collision avoidance against visible ordinary windows, the Dock-safe visible frame, and screen boundaries.
- Opacity presets: `opaque` (0.97), `translucent` (0.82), and `light` (0.68).
- Density presets: `standard` (100%), `compact` (88%), and `minimal` (76%). Each layout stores its own position while sharing the visual presets.
- A hover detail state: a 350 ms hover delay opens the full quota detail card; a 250 ms exit delay closes it after neither the widget nor its detail card contains the pointer. Clicking retains the existing pinned-detail behavior.
- A five-hour forecast confidence label with a color dot: High, Medium, Low, or Unstable. Insufficient samples remain “Collecting”.

## Explicitly out of scope

- No accessibility work in this milestone.
- No continuous tracking of Codex window movement.
- No task listing, session-log reading, task navigation, notifications, or additional Codex API methods.
- No weekly depletion forecast.

## Placement and avoidance

`WidgetPlacementResolver` receives the dragged panel frame, visible screen frames, the current visible Codex window frames, and ordinary on-screen window frames. It runs only after a drag ends.

1. Build four candidates around the closest Codex window: left, right, top, and bottom, each separated by an 8-point gap.
2. Consider a candidate only when the dragged panel ends within 28 points of that Codex edge.
3. Clamp candidates to the target screen’s visible frame, which excludes the Dock and menu-bar unsafe areas.
4. If another ordinary window overlaps a candidate, move along the selected Codex edge to the nearest free interval. A candidate is rejected if no interval fits the widget.
5. Select the eligible candidate with the least movement from the drag endpoint. If none is eligible, retain the dragged location after ordinary screen clamping.

The resolver never writes a global “attached” mode. It saves the resulting location through the existing layout-specific position preference, so later Codex moves do not move the widget.

## Presentation preferences

`WidgetPresentationPreferences` adds `opacityPreset` and `densityPreset` to persisted widget preferences. The panel and every detail surface use the selected opacity. Density scales the panel’s geometry, ring radii, typography, gaps, and detail-card dimensions from a single layout metrics value; it does not rely on an AppKit layer transform, so hit targets and avoidance frames match what is drawn.

Changing a preset recalculates the active panel frame while holding its saved top-left anchor, then applies normal screen clamping. It does not trigger snapping or inspect other apps.

## Hover detail state

`HoverDetailController` owns two timers and exposes `pointerEnteredWidget`, `pointerExitedWidget`, `pointerEnteredDetail`, and `pointerExitedDetail`. It has three states: `closed`, `transient`, and `pinned`.

- A pointer remaining over the widget for 350 ms opens `transient` detail without making the app key.
- Moving between widget and transient detail does not close it.
- When both areas are exited for 250 ms, transient detail closes.
- A normal click opens or closes `pinned` detail using the current behavior. Pointer exit never closes a pinned detail.
- Dragging cancels pending hover expansion. Hiding the widget, changing layout, or quitting closes all detail states.

For the large widget, transient detail uses the existing in-place expanded card. For compact widgets, it uses the existing adjacent detail panel. The visible card is therefore the same content in both interaction paths.

## Forecast confidence

Forecasting continues to use only the five-hour quota window and discards samples on reset. `QuotaForecastEngine` retains its capped rolling sample set and produces a `ForecastAssessment`: an outcome (`collecting`, `unstable`, `willNotDeplete`, or `depletedAt`) plus an optional confidence.

The engine derives three rates from used-percent samples: robust rolling rate, robust recent-ten-minute rate, and recent-ten-minute end-to-end rate. Positive forecasts require all rates to agree. Confidence is assigned from the available span and the largest relative difference among the three rates:

| Confidence | Minimum samples | Minimum span | Largest rate difference |
| --- | ---: | ---: | ---: |
| High | 12 | 20 minutes | 15% |
| Medium | 8 | 15 minutes | 25% |
| Low | 6 | 10 minutes | 35% |

If the sample set is too short, the outcome is `collecting`. If rates disagree, consumption is effectively flat, data is stale, or the window resets, the UI reports the applicable stable state instead of manufacturing a confidence score. The displayed depletion time uses the recent end-to-end rate only after its confidence gate passes.

Large and compact detail views show the label as “可信度：高 / 中 / 低” in Chinese and “Confidence: High / Medium / Low” in English builds where applicable. Unstable forecasts show “消耗速率不稳定，暂不预测” with a neutral warning dot. The existing “本周期内不会用尽” outcome remains separate from confidence.

## Testing

- Placement unit tests cover each snap edge, threshold rejection, screen clamping, occupied candidates, and fallback to unsnapped placement.
- Preference tests cover persistence, independent positions, and dimension/opacity frame changes.
- Hover controller tests cover delay, transit between widget and detail, pinning, drag cancellation, and hide cleanup without real timers.
- Forecast tests cover every confidence tier, each unstable condition, reset clearing, flat use, and the no-weekly-forecast rule.
- Layout and appearance checks cover all preset combinations, hover and pinned detail sizing, confidence labels, and absence of task-related UI.
- English and Chinese documentation describe the new behavior and the intentional exclusions.
