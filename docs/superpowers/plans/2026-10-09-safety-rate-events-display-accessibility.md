# Safety Rate, Events, Display Rules, and Accessibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add passive five-hour safety-rate guidance, private quota events, task summaries, refined display behavior, and accessible visual feedback to Quota Rings.

**Architecture:** Add focused Foundation models for safety pace, task summaries, quota events, and display rules. `QuotaApp` owns their lifecycle and publishes derived state to the three existing AppKit surfaces; views render state without persisting it. History and event stores share the same two-option retention policy but use separate local files to keep schemas and privacy boundaries simple.

**Tech Stack:** Swift 5, AppKit, Foundation, UserDefaults, JSON files in Application Support, existing deterministic Swift executable tests.

**Spec:** `docs/superpowers/specs/2026-10-09-safety-rate-events-display-accessibility-design.md`

## Global Constraints

- Keep the app native AppKit and offline except for its existing local Codex app-server connection.
- Send no macOS notifications; safety feedback is visible only in the widget.
- Persist only quota samples and fixed quota-event kinds; never persist task titles, task IDs, account data, raw protocol messages, or Codex free text.
- Expose exactly two history choices: session 30 minutes and local 5 hours.
- Map previous `local24Hours` and `local7Days` preferences to `local5Hours` and prune persisted records to five hours.
- Safety guidance uses the five-hour quota only, is reset-aware, and includes text plus symbol in addition to color.
- Keep task navigation and the existing no-refresh workflow unchanged.

## Review Focus

- Clock changes, future-dated samples, and duplicate timestamps must not produce a misleading safety rate; covered in Task 2.
- A quota reset must clear the prior safety-rate window and create only one reset event; covered in Tasks 2 and 3.
- Switching from local history to session mode must delete both persisted files, including deletion failures; covered in Task 1.
- A lock-display choice must override scope hiding but not prevent explicit quit or full app termination; covered in Task 4.
- VoiceOver must communicate danger and task summary when colors are unavailable; covered in Task 5.

---

## File Structure

| File | Responsibility |
| --- | --- |
| `Sources/QuotaHistory.swift` | Two-option retention, preference migration, sample pruning. |
| `Sources/QuotaSafetyRate.swift` | Reset-aware five-hour pace calculation and state. |
| `Sources/TaskSummary.swift` | In-memory counts and localized summary text derived from task statuses. |
| `Sources/QuotaEvent.swift` | Fixed quota event model, deduplicated store, and retention-aware persistence. |
| `Sources/WidgetDisplayRules.swift` | Saved visibility-rule values and deterministic precedence helper. |
| `Sources/WidgetPreferences.swift` / `Sources/WidgetMenu.swift` | Preference ownership and menu choices. |
| `Sources/App.swift` | Model lifecycle, publication, Option-click, lock display, and visibility decisions. |
| `Sources/QuotaView.swift`, `Sources/LargeQuotaView.swift`, `Sources/QuotaDetailsView.swift` | Safety, summary, event, accessibility, and contrast rendering. |
| `Sources/TaskRowView.swift` | Preserve accessible title/state/duration while fitting summaries around rows. |
| `Tests/*Tests.swift` | Deterministic model, preference, menu, visibility, interaction, layout, and appearance coverage. |

### Task 1: Retention migration and display-rule preferences

**Files:**
- Modify: `Sources/QuotaHistory.swift`, `Sources/WidgetPreferences.swift`, `Sources/WidgetMenu.swift`
- Create: `Sources/WidgetDisplayRules.swift`, `Tests/WidgetDisplayRulesTests.swift`
- Modify: `Tests/QuotaHistoryTests.swift`, `Tests/WidgetPreferencesTests.swift`, `Tests/MenuTests.swift`, `Scripts/test.sh`

**Interfaces:**
- Produces `HistoryRetention.session30Minutes` and `HistoryRetention.local5Hours`.
- Produces `WidgetDisplayRules(hideInFullScreen: Bool = true, lockDisplay: Bool = false)` with `load(from:)` and `save(to:)`.
- Produces `WidgetDisplayRules.shouldShow(scopeVisible:isFullScreen:) -> Bool`.

- [ ] **Step 1: Write failing migration and preference tests**

  Assert old raw values load as `.local5Hours`, samples beyond five hours are pruned, session mode removes persisted history, defaults enable full-screen hiding and disable lock display, and invalid values recover to defaults.

- [ ] **Step 2: Run the focused tests to verify they fail**

  Run: `zsh Scripts/test.sh` after temporarily limiting execution to the history, preference, display-rule, and menu targets.

  Expected: failures for missing `local5Hours`, display rules, and menu choices.

- [ ] **Step 3: Implement the two-option retention and display-rule interfaces**

  Use a five-hour duration for local mode. Map legacy preference strings during load, then write only `local5Hours`. Add menu controls for `仅本次 · 30 分钟`, `保留 5 小时`, full-screen hiding, and lock display.

- [ ] **Step 4: Run the focused tests to verify they pass**

  Run the same focused targets. Expected: all pass.

- [ ] **Step 5: Commit**

  `git commit -m "feat: add five-hour retention and display rules"`

### Task 2: Safety-rate and task-summary models

**Files:**
- Create: `Sources/QuotaSafetyRate.swift`, `Sources/TaskSummary.swift`, `Tests/QuotaSafetyRateTests.swift`, `Tests/TaskSummaryTests.swift`
- Modify: `Scripts/test.sh`

**Interfaces:**
- Produces `enum QuotaSafetyState { case collecting, safe, caution, danger }` and `struct QuotaSafetyRate` with current, sustainable, state, and symbol/text accessors.
- Produces `struct QuotaSafetyRateEngine { mutating func record(_ snapshot: QuotaSnapshot, forecast: QuotaForecast) -> QuotaSafetyRate }`.
- Produces `TaskSummary(statuses: [WidgetTaskStatus])` with running count, completed count, and localized label.

- [ ] **Step 1: Write failing safety-rate tests**

  Cover insufficient data, safe at 110% of sustainable pace, caution at 111–140%, danger above 140%, forecasted pre-reset depletion, duplicate timestamps, future samples, and reset clearing earlier samples.

- [ ] **Step 2: Write failing task-summary tests**

  Assert empty, only-running, only-completed, and mixed rows produce the specified counts and fixed Chinese summary copy.

- [ ] **Step 3: Run both new tests to verify they fail**

  Run the new compiled executables via `swiftc` using the same module cache pattern as `Scripts/test.sh`.

- [ ] **Step 4: Implement reset-aware calculation and summary derivation**

  Use the newest valid samples within 15 minutes after the current reset, require three samples spanning two minutes, calculate used-percent/hour from first to last, and compare to remaining-percent/hour until reset.

- [ ] **Step 5: Run model tests to verify they pass**

  Expected: safety and summary executables report PASS.

- [ ] **Step 6: Commit**

  `git commit -m "feat: add safety rate and task summary models"`

### Task 3: Private quota event store

**Files:**
- Create: `Sources/QuotaEvent.swift`, `Tests/QuotaEventTests.swift`
- Modify: `Scripts/test.sh`

**Interfaces:**
- Produces `enum QuotaEventKind` for reset, safety transition, threshold, and recovered connection.
- Produces `struct QuotaEvent: Codable, Equatable` containing timestamp, kind, and optional remaining percent.
- Produces `final class QuotaEventStore` with `record(kind:remainingPercent:at:)`, `events(at:)`, and `setRetention(_:at:)`.

- [ ] **Step 1: Write failing event-store tests**

  Assert fixed event encoding contains no task fields, repeated equal transitions deduplicate, only the newest four remain for display, five-hour pruning works, and session mode deletes the persisted event file.

- [ ] **Step 2: Run the event test to verify it fails**

  Expected: missing event model/store compile failure.

- [ ] **Step 3: Implement the event model and retention-aware store**

  Persist a JSON array in `quota-events.json` next to quota history. Deduplicate consecutive equivalent kinds and normalize timestamps using the same future-date guard as history samples.

- [ ] **Step 4: Run event and history tests to verify they pass**

- [ ] **Step 5: Commit**

  `git commit -m "feat: record private quota events"`

### Task 4: Integrate derived state and refined display behavior

**Files:**
- Modify: `Sources/App.swift`, `Sources/WidgetVisibility.swift`, `Tests/VisibilityTests.swift`, `Tests/ControllerTests.swift`, `Scripts/test.sh`

**Interfaces:**
- Consumes `QuotaSafetyRateEngine`, `TaskSummary`, `QuotaEventStore`, and `WidgetDisplayRules`.
- Publishes `safetyRate`, `taskSummary`, `quotaEvents`, and `displayRules` to all three views.

- [ ] **Step 1: Write failing visibility and controller tests**

  Assert full-screen hiding wins when enabled, lock display wins over normal scope rules, Option-click opens details without persisting a lock, and quota reset/safety/threshold/recovery transitions produce one event each.

- [ ] **Step 2: Run the affected targets to verify they fail**

- [ ] **Step 3: Wire models into `QuotaApp`**

  Instantiate the event store at Application Support, record snapshots before publishing views, update events on connection transitions, apply display-rule precedence in `shouldDisplayNow()`, and distinguish Option-click in `QuotaView.mouseUp`.

- [ ] **Step 4: Add menu actions for lock display and full-screen hiding**

  Use the existing `WidgetMenu.onChange` flow; resizing remains tied only to content changes.

- [ ] **Step 5: Run visibility, controller compilation, and protocol targets**

  Expected: all deterministic tests pass; controller source compiles even when the graphical run is unavailable.

- [ ] **Step 6: Commit**

  `git commit -m "feat: integrate pace events and display controls"`

### Task 5: Render guidance, events, and accessible state

**Files:**
- Modify: `Sources/QuotaView.swift`, `Sources/LargeQuotaView.swift`, `Sources/QuotaDetailsView.swift`, `Sources/QuotaTrend.swift`, `Sources/TaskRowView.swift`
- Modify: `Tests/LayoutTests.swift`, `Tests/AppearanceCheck.swift`, `Tests/TaskRowTests.swift`

**Interfaces:**
- Consumes view properties `safetyRate: QuotaSafetyRate`, `taskSummary: TaskSummary`, `quotaEvents: [QuotaEvent]`, and `displayRules: WidgetDisplayRules`.

- [ ] **Step 1: Write failing layout and appearance tests**

  Assert every card shows a safety symbol/text, task summary precedes task rows, the detail event section has no more than four fixed-copy rows, colors are not the only state carrier, and increased-contrast/reduced-motion views retain readable labels without animation.

- [ ] **Step 2: Run layout and appearance tests to verify they fail**

- [ ] **Step 3: Add AppKit rendering and accessibility labels**

  Keep compact cards readable by showing concise safety copy; show rates and events in expanded/detail cards. Use `NSWorkspace` accessibility display settings to increase contrast and suppress nonessential hover/transition effects. Extend VoiceOver labels with quota values, safety text, task summary, event range, and lock state.

- [ ] **Step 4: Run layout, appearance, and task-row tests to verify they pass**

- [ ] **Step 5: Manually inspect preview PNGs**

  Confirm labels do not overlap in compact vertical, compact horizontal, large collapsed, large expanded, and detail card modes.

- [ ] **Step 6: Commit**

  `git commit -m "feat: render accessible quota guidance"`

### Task 6: Documentation, full verification, and local package

**Files:**
- Modify: `README.md`, `README.zh-CN.md`, `Tests/DocumentationCheck.sh`
- Verify: `Scripts/test.sh`, `Scripts/build.command`, `Tests/PublicTreeCheck.sh`, `Scripts/check-public-tree.sh`

- [ ] **Step 1: Update English and Chinese documentation**

  Document passive safety guidance, private events, two retention choices, display rules, and accessibility behavior. Do not claim notifications or remote analytics.

- [ ] **Step 2: Update documentation assertions and run them**

- [ ] **Step 3: Run the complete suite and record the graphical-session limitation if it recurs**

  Run: `zsh Scripts/test.sh`.

- [ ] **Step 4: Build and validate the local Universal 2 release**

  Run `zsh Scripts/build.command`, `lipo -archs`, `codesign --verify --deep --strict`, and `unzip -tq` on the generated outputs.

- [ ] **Step 5: Commit**

  `git commit -m "docs: describe safety guidance and privacy"`

## Self-Review

- Retention migration, local privacy boundaries, safety thresholds, task summaries, event recording, display rules, Option-click, locking, VoiceOver, contrast, and reduced motion each map to Tasks 1–5.
- Every public type named by a later task is defined by an earlier task.
- Review-focus conditions are explicitly included in Tasks 1, 2, 3, 4, and 5.
- The implementation is staged so each commit leaves working, testable behavior and no task persists prohibited task data.
