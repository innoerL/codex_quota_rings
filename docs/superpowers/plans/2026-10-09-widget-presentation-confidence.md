# Widget Presentation and Forecast Confidence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add drag-end Codex snapping and window avoidance, visual presets, transient hover details, and trustworthy five-hour forecast confidence to Quota Rings.

**Architecture:** Keep placement, hover state, presentation metrics, and forecast confidence as independent testable models. `QuotaApp` supplies live AppKit window geometry and applies resolved frames; views consume metrics and derived forecast state without reading other applications or Codex task data.

**Tech Stack:** Swift 5, AppKit, CoreGraphics, Foundation, UserDefaults, existing executable Swift tests.

**Spec:** `docs/superpowers/specs/2026-10-09-widget-presentation-confidence-design.md`

## Global Constraints

- Support macOS 12 and preserve the native AppKit architecture.
- Snap only after a user drag ends; never continuously follow a Codex window.
- Keep an 8-point snap gap and a 28-point drag-end eligibility threshold.
- Use opacity values 0.97, 0.82, and 0.68; density scales 1.00, 0.88, and 0.76.
- Hover delay is 350 ms; transient-detail exit delay is 250 ms.
- Do not add accessibility work, task/session reading, task navigation, notifications, additional Codex methods, or weekly depletion forecasts.
- Keep English and Simplified Chinese documentation synchronized.

## Review Focus

- A drag ending near two Codex edges must choose the valid candidate requiring the least movement; Task 2 covers the tie-breaker.
- A candidate that fits before clamping but intersects the Dock-safe visible-frame boundary after clamping must not overlap the unsafe area; Task 2 covers this.
- Changing density while a card is pinned must preserve its top-left placement anchor and keep the panel on-screen; Task 3 covers this.
- Moving the pointer from a compact widget into its transient detail during the exit delay must keep the detail open; Task 4 covers this.
- A forecast with enough samples but a sudden final consumption jump must report Unstable rather than a low-confidence time; Task 5 covers this.

---

## File Structure

| File | Responsibility |
| --- | --- |
| `Sources/WidgetPresentation.swift` | Opacity/density enums and scaled layout metrics. |
| `Sources/WidgetPlacementResolver.swift` | Pure drag-end snap, collision avoidance, and screen clamping. |
| `Sources/HoverDetailController.swift` | Timer-independent transient/pinned hover state machine. |
| `Sources/WidgetPreferences.swift` | Persisted opacity and density selections. |
| `Sources/WidgetMenu.swift` | Appearance submenus and checkmarks. |
| `Sources/App.swift` | Window snapshots, resolver/hover integration, frame application, and presentation propagation. |
| `Sources/QuotaView.swift`, `Sources/LargeQuotaView.swift`, `Sources/QuotaDetailsView.swift` | Scaled metrics, opacity and confidence rendering. |
| `Sources/QuotaForecast.swift` | Forecast outcome plus confidence classification for the five-hour window only. |
| `Tests/*` | Focused model, menu, layout, appearance, forecast, controller, and documentation checks. |

### Task 1: Presentation Preferences and Metrics

**Files:**
- Create: `Sources/WidgetPresentation.swift`, `Tests/WidgetPresentationTests.swift`
- Modify: `Sources/WidgetPreferences.swift`, `Tests/WidgetPreferencesTests.swift`, `Scripts/test.sh`

**Interfaces:**
- Produces `WidgetOpacityPreset` (`opaque`, `translucent`, `light`) with `alpha: CGFloat`.
- Produces `WidgetDensityPreset` (`standard`, `compact`, `minimal`) with `scale: CGFloat`.
- Produces `WidgetLayoutMetrics.init(density:)` with scaled panel dimensions, ring radii, typography and gaps.
- Extends `WidgetPreferences` with `opacityPreset` and `densityPreset` plus `load(from:)` / `save(to:)` support.

- [ ] **Step 1: Write failing preference and metric tests**

Assert default presets, UserDefaults round trips, invalid-value fallback, exact alpha/scale values, and that all scaled dimensions remain positive.

- [ ] **Step 2: Run the focused tests to verify failure**

Run: `swiftc ... Sources/WidgetPresentation.swift Sources/WidgetPreferences.swift Tests/WidgetPresentationTests.swift`

Expected: compilation failure because the new presets and metrics do not exist.

- [ ] **Step 3: Implement presentation enums, metrics, and preference persistence**

Use raw string values compatible with `UserDefaults`; retain existing defaults for size, orientation, display scope, and history.

- [ ] **Step 4: Run focused preference and metric tests**

Expected: PASS for defaults, recovery, persistence, and exact preset values.

- [ ] **Step 5: Commit**

```bash
git add Sources/WidgetPresentation.swift Sources/WidgetPreferences.swift Tests/WidgetPresentationTests.swift Tests/WidgetPreferencesTests.swift Scripts/test.sh
git commit -m "feat: add widget presentation presets"
```

### Task 2: Pure Drag-End Placement Resolver

**Files:**
- Create: `Sources/WidgetPlacementResolver.swift`, `Tests/WidgetPlacementResolverTests.swift`
- Modify: `Scripts/test.sh`

**Interfaces:**
- Consumes `WidgetLayoutMetrics` from Task 1.
- Produces `WidgetPlacementResolver.resolve(panelFrame:screenFrame:codexFrames:occupiedFrames:) -> CGRect`.

- [ ] **Step 1: Write failing placement tests**

Cover left/right/top/bottom 8-point candidates, the 28-point threshold, least-movement tie breaking, occupied-edge displacement, no-free-interval rejection, Dock-safe screen clamping, and unsnapped fallback.

- [ ] **Step 2: Run resolver tests to verify failure**

Run: `swiftc ... Sources/WidgetPlacementResolver.swift Tests/WidgetPlacementResolverTests.swift`

Expected: compilation failure because the resolver does not exist.

- [ ] **Step 3: Implement `WidgetPlacementResolver`**

Generate candidates from the nearest eligible Codex frame, slide a collision candidate along its selected edge to the closest fitting interval, then choose the smallest endpoint movement. Use CoreGraphics rectangles only; do not read global window APIs here.

- [ ] **Step 4: Run resolver tests**

Expected: PASS for every edge, occupied window, unsafe boundary, and fallback scenario.

- [ ] **Step 5: Commit**

```bash
git add Sources/WidgetPlacementResolver.swift Tests/WidgetPlacementResolverTests.swift Scripts/test.sh
git commit -m "feat: resolve drag-end widget placement"
```

### Task 3: Apply Appearance Presets and Placement in the App

**Files:**
- Modify: `Sources/App.swift`, `Sources/QuotaView.swift`, `Sources/LargeQuotaView.swift`, `Sources/QuotaDetailsView.swift`, `Sources/WidgetMenu.swift`
- Modify: `Tests/MenuTests.swift`, `Tests/LayoutTests.swift`, `Tests/AppearanceCheck.swift`, `Tests/ControllerTests.swift`

**Interfaces:**
- Consumes `WidgetLayoutMetrics` and `WidgetPlacementResolver` from Tasks 1–2.
- Adds `QuotaView.onDragFinished: (() -> Void)?`.
- Adds presentation properties to each view: `metrics: WidgetLayoutMetrics` and `contentOpacity: CGFloat`.

- [ ] **Step 1: Write failing menu, layout, and controller tests**

Assert appearance submenu labels and checkmarks, active frame changes for every density, alpha propagation to both panel types, anchor preservation during preset changes, and drag-end snap invocation without continuous movement.

- [ ] **Step 2: Run the affected tests to verify failure**

Run focused menu/layout/controller compilation targets.

Expected: failures for missing appearance actions, metrics propagation, and drag-finished callback.

- [ ] **Step 3: Integrate presets and placement**

Add two appearance submenus, apply metrics without layer transforms, snapshot only visible normal-level Codex/ordinary windows when `onDragFinished` fires, and resolve the panel’s final frame once. Preserve the saved top-left anchor while resizing and clamp it to the visible frame.

- [ ] **Step 4: Run presentation integration tests**

Expected: PASS for menus, geometry, opacity, placement and existing visibility behavior.

- [ ] **Step 5: Commit**

```bash
git add Sources/App.swift Sources/QuotaView.swift Sources/LargeQuotaView.swift Sources/QuotaDetailsView.swift Sources/WidgetMenu.swift Tests/MenuTests.swift Tests/LayoutTests.swift Tests/AppearanceCheck.swift Tests/ControllerTests.swift
git commit -m "feat: apply widget presentation and snap placement"
```

### Task 4: Transient Hover Detail State

**Files:**
- Create: `Sources/HoverDetailController.swift`, `Tests/HoverDetailControllerTests.swift`
- Modify: `Sources/App.swift`, `Sources/QuotaView.swift`, `Sources/QuotaDetailsView.swift`, `Tests/ControllerTests.swift`, `Scripts/test.sh`

**Interfaces:**
- Produces `HoverDetailState` (`closed`, `transient`, `pinned`).
- Produces `HoverDetailController` methods `pointerEnteredWidget()`, `pointerExitedWidget()`, `pointerEnteredDetail()`, `pointerExitedDetail()`, `dragStarted()`, `togglePinned()`, and `close()`.
- `QuotaApp` receives state transitions and opens the existing large inline card or compact adjacent detail panel accordingly.

- [ ] **Step 1: Write failing state-machine tests**

Use a controllable scheduler to assert the 350 ms open delay, 250 ms exit delay, widget-to-detail transit, pin persistence, drag cancellation, layout-change cleanup, and hide cleanup.

- [ ] **Step 2: Run controller tests to verify failure**

Expected: compilation failure because the state machine and scheduler seam do not exist.

- [ ] **Step 3: Implement the pure hover controller and AppKit adapters**

Keep timer ownership in the controller through an injected scheduling closure; views only forward tracking-area events. Do not make the app key for transient details.

- [ ] **Step 4: Run hover and controller tests**

Expected: PASS for every transition, with click-pinned behavior unchanged.

- [ ] **Step 5: Commit**

```bash
git add Sources/HoverDetailController.swift Sources/App.swift Sources/QuotaView.swift Sources/QuotaDetailsView.swift Tests/HoverDetailControllerTests.swift Tests/ControllerTests.swift Scripts/test.sh
git commit -m "feat: show transient quota details on hover"
```

### Task 5: Forecast Confidence Model and Rendering

**Files:**
- Modify: `Sources/QuotaForecast.swift`, `Sources/QuotaView.swift`, `Sources/LargeQuotaView.swift`, `Sources/QuotaDetailsView.swift`
- Modify: `Tests/ForecastTests.swift`, `Tests/LayoutTests.swift`, `Tests/AppearanceCheck.swift`

**Interfaces:**
- Produces `ForecastConfidence` (`high`, `medium`, `low`).
- Refactors `QuotaForecast` to carry `outcome` (`collecting`, `unstable`, `willNotDeplete`, `depletedAt(Date)`) and optional `confidence`.
- Keeps `QuotaForecasts.fiveHour`; `QuotaForecasts.week` is always collecting and is never rendered as a depletion prediction.

- [ ] **Step 1: Write failing forecast and rendering tests**

Assert High at 12 samples/20 minutes/15% maximum difference, Medium at 8/15/25%, Low at 6/10/35%, Unstable for a sudden final jump, Collecting for insufficient/flat data, reset clearing, no weekly forecast, and text-plus-dot labels for all confidence states.

- [ ] **Step 2: Run forecast/layout tests to verify failure**

Expected: missing confidence model and UI labels.

- [ ] **Step 3: Implement confidence classification**

Calculate the rolling robust, recent robust, and recent end-to-end rates already defined by the spec. Classify the strongest tier whose sample/span/difference thresholds pass; otherwise return Unstable or Collecting. Use the recent end-to-end rate only after classification passes.

- [ ] **Step 4: Render confidence on large and compact detail cards**

Use a textual label plus a color dot. Keep “消耗速率不稳定，暂不预测” separate and preserve “本周期内不会用尽”.

- [ ] **Step 5: Run forecast, layout, and appearance tests**

Expected: PASS for all confidence tiers and no task-related UI regression.

- [ ] **Step 6: Commit**

```bash
git add Sources/QuotaForecast.swift Sources/QuotaView.swift Sources/LargeQuotaView.swift Sources/QuotaDetailsView.swift Tests/ForecastTests.swift Tests/LayoutTests.swift Tests/AppearanceCheck.swift
git commit -m "feat: show forecast confidence"
```

### Task 6: Documentation, Full Verification, and Local Package

**Files:**
- Modify: `README.md`, `README.zh-CN.md`, `Tests/DocumentationCheck.sh`
- Verify: `Scripts/test.sh`, `Scripts/build.command`, public-tree checks

- [ ] **Step 1: Update both README files and the documentation check**

Document drag-end-only snapping, avoidance scope, exact preset choices, hover timing, confidence meanings, and deliberate exclusions. Preserve the existing no-task-monitoring guarantee.

- [ ] **Step 2: Run documentation checks**

Run: `zsh Tests/DocumentationCheck.sh`

Expected: PASS for English and Chinese coverage.

- [ ] **Step 3: Run full verification**

Run: `zsh Scripts/test.sh`, `zsh Tests/PublicTreeCheck.sh`, and `zsh Scripts/check-public-tree.sh`.

Expected: every non-graphical target passes; record a graphical-session limitation if the panel test cannot run.

- [ ] **Step 4: Build and verify the installable app**

Run: `zsh Scripts/build.command`, then `lipo -archs`, `codesign --verify --deep --strict`, and `unzip -tq` against `outputs/QuotaRings`.

Expected: arm64 and x86_64, valid ad-hoc signature, and valid ZIP.

- [ ] **Step 5: Commit**

```bash
git add README.md README.zh-CN.md Tests/DocumentationCheck.sh
git commit -m "docs: explain widget presentation controls"
```

## Self-Review

- Tasks 1–3 cover saved visual presets and drag-end-only snapping/avoidance.
- Task 4 covers transient versus pinned details and lifecycle cleanup.
- Task 5 covers all confidence thresholds and preserves the five-hour-only forecast limit.
- Task 6 covers both documentation languages, public-source boundaries, verification, and packaging.
- Every Review Focus entry is assigned to the listed task’s failing test before implementation.
