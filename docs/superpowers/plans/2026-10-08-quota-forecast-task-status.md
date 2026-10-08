# Quota Forecast and Task Status Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show per-window quota depletion forecasts and real active Codex task titles/statuses in Quota Rings when Codex is not focused.

**Architecture:** Add two pure local model units: `QuotaForecastEngine` turns recent quota snapshots into one forecast per quota window, and `TaskStatusStore` turns the current active thread set into running and expiring completed rows. Extend the existing read-only app-server client to poll `thread/list`, then pass forecasts and background-only task rows through the existing AppKit controller into the large card and compact detail panel.

**Tech Stack:** Swift 5, AppKit, Foundation, local Codex app-server JSON-RPC, zsh test/build scripts, Python protocol fixture.

**Spec:** `docs/superpowers/specs/2026-10-08-quota-forecast-task-status-design.md`

## Global Constraints

- Keep the existing read-only local app-server connection and 30-second quota refresh; add only a local, read-only `thread/list` poll every five seconds.
- Forecasts use a 30-minute in-memory window, require four samples spanning two minutes, and never survive a reset boundary.
- Task titles are memory-only. Show only active tasks observed in this app process, plus their `Completed` row for five minutes.
- `Running` is exactly `#B48A4A`; `Completed` is exactly `#8FA990`.
- Task rows appear only while Codex is not frontmost and the widget is otherwise eligible to display; Focus Codex behavior remains unchanged.
- Preserve all existing small/large layout, display-scope, nonactivation, stale-data, and position-restoration behavior.
- Build a double-clickable local `build/Quota Rings.app` and local zip. Do not push, release, or write to GitHub.

## Review Focus

- A quota reset or a lower used percentage must clear only that window’s forecast history; Task 1 pins this with a reset-boundary test.
- A brief or zero consumption rate must never claim a false depletion time; Task 1 pins collecting and no-depletion outcomes.
- A historical idle thread must never appear as `Completed`; Task 1 pins the observed-active-only transition.
- A malformed task response must retain known rows until expiry instead of replacing them with unrelated history; Task 2 pins this client failure path.
- Entering or leaving Codex focus must add/remove task rows without changing panel position, base layout, or focus behavior; Task 3 pins this through view and controller checks.

---

### Task 1: Add pure forecast and task-state models

**Files:**
- Create: `Sources/QuotaForecast.swift`
- Create: `Sources/TaskStatus.swift`
- Create: `Tests/ForecastTests.swift`
- Create: `Tests/TaskStatusTests.swift`
- Modify: `Scripts/test.sh:11-18`

**Interfaces:**
- Consumes: `QuotaSnapshot` and `QuotaWindow` from `Sources/QuotaModel.swift`.
- Produces: `enum QuotaForecast: Equatable { case collecting; case withinCurrentWindow; case depletedAt(Date) }`, `struct QuotaForecasts: Equatable`, and `struct QuotaForecastEngine` with `mutating func record(_ snapshot: QuotaSnapshot) -> QuotaForecasts`.
- Produces: `struct ActiveCodexThread: Equatable`, `enum WidgetTaskState: Equatable { case running, completed }`, `struct WidgetTaskStatus: Equatable`, and `final class TaskStatusStore` with `func update(active: [ActiveCodexThread], at: Date) -> [WidgetTaskStatus]`.

- [ ] **Step 1: Write failing forecast and task-state tests**

In `Tests/ForecastTests.swift`, build timestamped snapshots and assert: four samples across two minutes predict a same-day depletion time; a forecast landing after `resetsAt` is `.withinCurrentWindow`; no positive rate is `.collecting`; a changed `resetsAt` discards prior samples. In `Tests/TaskStatusTests.swift`, assert two active titles become two `.running` rows; only a previously running id changes to `.completed`; completion expires at five minutes; an idle/historical id never becomes a row.

- [ ] **Step 2: Run the new model binaries to verify they fail**

Run: `swiftc -swift-version 5 Sources/QuotaModel.swift Sources/QuotaForecast.swift Tests/ForecastTests.swift -o /tmp/quota-forecast-tests`

Expected: compilation fails because `QuotaForecast.swift` and its interfaces do not exist. Repeat for `TaskStatus.swift` and `TaskStatusTests.swift`.

- [ ] **Step 3: Implement the forecast and task-state interfaces**

In `QuotaForecastEngine`, retain samples per stable `resetsAt`, prune entries older than 30 minutes, require four samples over 120 seconds, compute positive consecutive usage slopes, and use their median rate. Format logic remains in the views. In `TaskStatusStore`, keep observed active ids in memory, sort running rows before completed rows, and remove completed rows at `completedAt + 300` seconds.

- [ ] **Step 4: Run model checks and wire them into the suite**

Run: `zsh Scripts/test.sh`

Expected: existing model checks plus new `PASS:` lines for forecasts and task transitions; no AppKit regression.

- [ ] **Step 5: Commit**

```bash
git add Sources/QuotaForecast.swift Sources/TaskStatus.swift Tests/ForecastTests.swift Tests/TaskStatusTests.swift Scripts/test.sh
git commit -m "feat: model quota forecasts and task status"
```

### Task 2: Read active Codex threads through app-server

**Files:**
- Modify: `Sources/QuotaClient.swift:4-157`
- Modify: `Tests/ProtocolTests.swift:3-27`
- Modify: `Tests/fake-codex.py:1-35`

**Interfaces:**
- Consumes: `ActiveCodexThread` and `TaskStatusStore` from Task 1.
- Produces: `QuotaClient.onTasksChange: (([WidgetTaskStatus]) -> Void)?` and a `QuotaClient` that sends `thread/list` after initialization and every five seconds.
- Produces: a task-list decoder that maps only app-server threads with `status.type == "active"`, uses `name`, falls back to `preview`, and finally uses `未命名任务`.

- [ ] **Step 1: Extend the protocol fixture and write failing protocol assertions**

Change `Tests/fake-codex.py` to respond by JSON-RPC method rather than a fixed request order: return quota snapshots for `account/rateLimits/read` and a thread list with two active named threads plus one idle historical thread for `thread/list`. In `ProtocolTests.swift`, capture `onTasksChange` and assert both active titles arrive, the idle entry is absent, and quota polling/push behavior remains unchanged.

- [ ] **Step 2: Run the protocol test to verify it fails**

Run: `swiftc -swift-version 5 Sources/QuotaModel.swift Sources/TaskStatus.swift Sources/QuotaClient.swift Tests/ProtocolTests.swift -o /tmp/quota-protocol-tests && /tmp/quota-protocol-tests Tests/fake-codex.py`

Expected: failure because `QuotaClient` has no task callback or `thread/list` handling.

- [ ] **Step 3: Implement read-only task polling and decoding in `QuotaClient`**

Add a separate five-second timer and independent pending request id so a slow task-list response cannot suppress quota refreshes. On a valid task-list response, decode active threads and pass them through one `TaskStatusStore`; on malformed/error responses, keep the current task-store rows and let their normal expiry apply. Invalidate the timer and reset request bookkeeping on stop/disconnect.

- [ ] **Step 4: Run protocol and full deterministic checks**

Run: `make test`

Expected: protocol output confirms fragmented quota JSON, active thread decoding, idle filtering, multiple running rows, and existing push-update handling.

- [ ] **Step 5: Commit**

```bash
git add Sources/QuotaClient.swift Tests/ProtocolTests.swift Tests/fake-codex.py
git commit -m "feat: observe active Codex tasks locally"
```

### Task 3: Render forecasts and background task rows

**Files:**
- Modify: `Sources/QuotaView.swift:14-135`
- Modify: `Sources/LargeQuotaView.swift:4-45`
- Modify: `Sources/QuotaDetailsView.swift:4-69`
- Modify: `Sources/App.swift:4-278`
- Modify: `Tests/LayoutTests.swift:3-43`
- Modify: `Tests/AppearanceCheck.swift:12-40`
- Modify: `Tests/ControllerTests.swift:3-43`

**Interfaces:**
- Consumes: `QuotaForecasts`, `WidgetTaskStatus`, and `WidgetTaskState` from Task 1; `QuotaClient.onTasksChange` from Task 2.
- Produces: forecast/task properties on `QuotaView` inherited by `LargeQuotaView`, and matching properties plus a dynamic `preferredContentSize` on `QuotaDetailsView`.
- Produces: `TaskStatusPalette.runningColor` and `TaskStatusPalette.completedColor`, the AppKit values for `#B48A4A` and `#8FA990`.
- Produces: a `QuotaApp` update path that assigns forecasts after every snapshot and assigns task rows only when `frontmostBundleID != WidgetVisibility.hostBundleID`.

- [ ] **Step 1: Write failing layout, appearance, and controller assertions**

In `LayoutTests.swift`, assign two forecasts and two task rows to an expanded large card; assert both forecast strings fit beneath reset descriptions and its preferred height grows by one row per task. Assert a compact detail panel with the same data grows to include forecasts and task rows. In `AppearanceCheck.swift`, assert `TaskStatusPalette.runningColor` equals `NSColor(calibratedRed: 180/255, green: 138/255, blue: 74/255, alpha: 1)` and `TaskStatusPalette.completedColor` equals `NSColor(calibratedRed: 143/255, green: 169/255, blue: 144/255, alpha: 1)`, then render both rows into the preview. In `ControllerTests.swift`, verify background task rows disappear when the simulated frontmost bundle is `WidgetVisibility.hostBundleID` without changing the panel anchor.

- [ ] **Step 2: Run view/controller checks to verify they fail**

Run: `zsh Scripts/test.sh`

Expected: compilation or assertions fail because views do not accept forecast/task data or dynamically size their content.

- [ ] **Step 3: Implement the card and detail layouts**

Render `预计 HH:mm 用尽`, `预计 M/d HH:mm 用尽`, `本周期内不会用尽`, or `收集中，稍后预测` under each reset description. Keep compact rings unchanged. In the large card, reserve task rows below the quota section whenever supplied, use a trailing `Running`/`Completed` label, truncate long titles, and calculate height from base content plus row count. In compact details, apply the same rows with dynamic panel size. Use exactly `#B48A4A` and `#8FA990` for the two states.

- [ ] **Step 4: Integrate view data and background-only visibility in `QuotaApp`**

Own one `QuotaForecastEngine` in `QuotaApp`; record every accepted snapshot and assign its result to all views. Store task rows received from the client, recompute the rows passed to views in `refreshVisibility()`, and rebuild panel frames only when their dynamic preferred size changes. Derive Codex focus from `WidgetVisibility.hostBundleID`; do not alter the selected scope or force activation.

- [ ] **Step 5: Render and verify native behavior**

Run: `make test && make build`

Expected: all tests pass, generated layout previews have no clipping or overlap, panel expansion preserves placement, compact click still opens details, and `build/Quota Rings.app` is produced.

- [ ] **Step 6: Commit**

```bash
git add Sources/QuotaView.swift Sources/LargeQuotaView.swift Sources/QuotaDetailsView.swift Sources/App.swift Tests/LayoutTests.swift Tests/AppearanceCheck.swift Tests/ControllerTests.swift
git commit -m "feat: display forecasts and background task status"
```

### Task 4: Package the local application and document the new behavior

**Files:**
- Modify: `README.md`
- Modify: `README.zh-CN.md`
- Modify: `Scripts/build.command`
- Modify: `Scripts/test.sh`
- Create: `Tests/DocumentationCheck.sh`
- Create: `outputs/QuotaRings/Quota Rings.app` (generated, ignored)
- Create: `outputs/QuotaRings/Quota-Rings.app.zip` (generated, ignored)

**Interfaces:**
- Consumes: the built `build/Quota Rings.app` from Task 3.
- Produces: a copied double-clickable app and zip under `outputs/QuotaRings/`, plus current English and Chinese local documentation.

- [ ] **Step 1: Write failing package/documentation checks**

Create `Tests/DocumentationCheck.sh` with deterministic assertions that require both readmes to describe forecast warming/no-depletion text, real active task titles, five-minute completion retention, the two status colors, and the local-only/no-GitHub constraint for this release. Add it to `Scripts/test.sh`.

- [ ] **Step 2: Run the check to verify it fails**

Run: `zsh Tests/DocumentationCheck.sh`

Expected: failure because the current readmes and package step do not describe or produce this release.

- [ ] **Step 3: Update documentation and package without an external write**

Document the local-only behavior and prediction limitations in both readmes. Update `Scripts/build.command` or add a small packaging step so `make build` creates the signed ad-hoc app, then copy it to `outputs/QuotaRings/Quota Rings.app` and zip it while preserving the bundle structure. Do not invoke `git push`, `gh`, browser publishing, releases, or tags.

- [ ] **Step 4: Perform release verification**

Run: `make build && test -x 'outputs/QuotaRings/Quota Rings.app/Contents/MacOS/QuotaRings' && unzip -t outputs/QuotaRings/Quota-Rings.app.zip && git status --short`

Expected: the app executable and archive are valid; only source, test, script, documentation, and ignored local artifacts are changed; no remote is modified.

- [ ] **Step 5: Commit tracked work only**

```bash
git add README.md README.zh-CN.md Scripts/build.command Scripts/test.sh Tests/DocumentationCheck.sh
git commit -m "docs: describe quota forecasts and task status"
```

## Self-review

- Task 1 implements and tests every forecast boundary and task lifecycle rule in the spec.
- Task 2 adds only the documented local, read-only app-server thread query and proves real-title/multiple-active behavior through the protocol fixture.
- Task 3 implements every required presentation rule, preserves background-only visibility, and pins colors and dynamic sizing.
- Task 4 creates the requested local click-ready app and zip, updates both languages, and explicitly prohibits a GitHub write.
- Each Review Focus item maps to a named test in Tasks 1–3; package integrity and no-remote behavior are verified in Task 4.
