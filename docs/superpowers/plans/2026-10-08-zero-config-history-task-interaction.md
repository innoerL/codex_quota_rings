# Zero-configuration History and Task Interaction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a zero-configuration Universal 2 Quota Rings app with guided Codex recovery, optional local quota trends, task elapsed time, and task-row navigation.

**Architecture:** Add focused locator, history, navigation, and task-row units around the existing `QuotaClient` and `QuotaApp`. Keep live quota and task data local, make persistence opt-in, and let the existing controller distribute state to native AppKit views.

**Tech Stack:** Swift 5, AppKit, Foundation Codable/UserDefaults, macOS Launch Services through `NSWorkspace`, zsh build scripts, `swiftc`, `lipo`, ad-hoc `codesign`.

**Spec:** `docs/superpowers/specs/2026-10-08-zero-config-history-task-interaction-design.md`

## Global Constraints

- Minimum runtime remains macOS 12 when a compatible Codex CLI is available.
- Use exact Codex bundle ID `com.openai.codex`; never fuzzy-match an application name.
- Do not bundle or redistribute Codex.
- Do not add third-party dependencies, a database, analytics, or network requests outside the existing local Codex app-server child process.
- Trend persistence defaults to disabled: `session30Minutes` stores nothing on disk.
- Persistent history stores only timestamp, five-hour used percent, and weekly used percent under `~/Library/Application Support/Quota Rings/quota-history.json`.
- Never persist task IDs, titles, durations, account data, raw protocol payloads, or credentials.
- Keep Running `#B48A4A`, Completed `#8FA990`, and the existing five-minute completed-task retention.
- Task duration means time since Quota Rings first observed the current active run; app restart resets it.
- Task navigation falls back to activating Codex when a precise thread link cannot be handled.
- Do not add the removed “start Quota Rings when Codex starts” feature.
- Build and package locally only; do not push, upload, create a GitHub Release, or publish source.

## Review Focus

- A registered Codex app may live in a path with spaces while its expected CLI is a broken symlink: skip the invalid executable and continue through later candidates.
- History input may be out of order, duplicated, non-finite, or dated in the future: keep a sorted, finite, deduplicated series without extending retention incorrectly.
- A task may disappear in one valid poll and return active in the next: treat that as a new run only after it was actually marked Completed, and never infer completion from a malformed response.
- A thread ID may contain URL-reserved characters and the URL handler may claim support but fail to open: percent-encode the path component, then activate Codex.
- One architecture compile or `lipo` verification may fail while an older release exists: fail without replacing the existing `outputs/QuotaRings` app or ZIP.

---

### Task 1: Zero-configuration Codex discovery and structured connection state

**Files:**
- Create: `Sources/CodexLocator.swift`
- Create: `Tests/CodexLocatorTests.swift`
- Modify: `Sources/QuotaClient.swift`
- Modify: `Sources/App.swift`
- Modify: `Tests/ProtocolTests.swift`
- Modify: `Tests/fake-codex.py`
- Create: `Tests/fake-codex-no-auth.py`
- Modify: `Scripts/test.sh`

**Interfaces:**
- Consumes: existing `QuotaClient(executableURL:)` test injection and `com.openai.codex` from `WidgetVisibility.hostBundleID`.
- Produces: `CodexLocation`, `CodexLocating.locate()`, `QuotaConnectionState`, `QuotaClient.onConnectionState`, and `QuotaClient.codexApplicationURL` for Tasks 3 and 4.

- [ ] **Step 1: Write failing locator tests**

Add `CodexLocatorTests` with injected application lookup, environment, candidate paths, and executable validation. Assert exact search order, registered/moved apps, user Applications, CLI-only discovery, missing installation, a path containing spaces, a broken registered-app CLI followed by a valid Homebrew CLI, and rejection of non-executable files.

- [ ] **Step 2: Run locator tests and verify RED**

Run:

```bash
swiftc -swift-version 5 -module-cache-path "${TMPDIR:-/tmp}/codex-quota-rings/module-cache" Sources/WidgetVisibility.swift Sources/CodexLocator.swift Tests/CodexLocatorTests.swift -o /tmp/quota-locator-tests
```

Expected: FAIL because `Sources/CodexLocator.swift` and its interfaces do not exist.

- [ ] **Step 3: Implement the locator interfaces**

In `Sources/CodexLocator.swift`, define:

```swift
struct CodexLocation: Equatable {
    let executableURL: URL
    let applicationURL: URL?
}

protocol CodexApplicationLocating {
    func applicationURL(bundleIdentifier: String) -> URL?
}

protocol CodexLocating {
    func locate() -> CodexLocation?
}

struct CodexLocator: CodexLocating {
    init()
    init(applicationLocator: CodexApplicationLocating,
         environment: [String: String],
         homeDirectory: URL,
         isExecutable: @escaping (String) -> Bool)
    func locate() -> CodexLocation?
}
```

Implement a production `WorkspaceCodexApplicationLocator` using `NSWorkspace`, plus `CodexLocator` with injected app lookup, environment, home directory, and executable predicate. Keep `QUOTA_CODEX_PATH` only as the first developer/test override and omit it from user-facing errors.

- [ ] **Step 4: Run locator tests and verify GREEN**

Run the compile command from Step 2, then `/tmp/quota-locator-tests`.

Expected: `PASS: zero-configuration Codex discovery and invalid-candidate fallback`.

- [ ] **Step 5: Write failing connection-state protocol tests**

Define:

```swift
enum QuotaConnectionState: Equatable {
    case locating
    case ready
    case codexNotInstalled
    case authenticationRequired
    case disconnected(String)
}
```

Extend protocol coverage to assert `.locating → .ready → .disconnected` for the existing fixture, `.authenticationRequired` for an initialize/account authorization error fixture, and `.codexNotInstalled` when an injected locator returns nil. Assert a later reconnect asks the locator again.

- [ ] **Step 6: Run protocol tests and verify RED**

Run the protocol compile command from `Scripts/test.sh` with `Sources/CodexLocator.swift` included.

Expected: FAIL because `QuotaClient` has no structured state callback or locator dependency.

- [ ] **Step 7: Integrate locator and connection state into `QuotaClient`**

Add these public-within-module interfaces:

```swift
var onConnectionState: ((QuotaConnectionState) -> Void)?
private(set) var codexApplicationURL: URL?
init(executableURL: URL? = nil, locator: CodexLocating = CodexLocator())
```

Resolve location on every `connect()`, publish exact states, retain the last snapshot on disconnect, and classify explicit initialization/account authorization failures as `.authenticationRequired`. Keep malformed data and transport failures as `.disconnected(message)`.

- [ ] **Step 8: Connect structured state to the controller**

Store connection state in `QuotaApp` and pass it to view models in Task 3. Until Task 3 adds buttons, preserve current `connectionError` rendering so this task remains usable.

- [ ] **Step 9: Run focused and existing protocol tests**

Run `CodexLocatorTests`, `ProtocolTests`, `ModelTests`, and `VisibilityTests` through the updated `Scripts/test.sh` commands.

Expected: all focused checks pass; malformed task responses still retain prior task rows.

- [ ] **Step 10: Commit Task 1**

```bash
git add Sources/CodexLocator.swift Sources/QuotaClient.swift Sources/App.swift Tests/CodexLocatorTests.swift Tests/ProtocolTests.swift Tests/fake-codex.py Tests/fake-codex-no-auth.py Scripts/test.sh
git commit -m "feat: auto-discover local Codex installations"
```

### Task 2: Privacy-controlled quota history and preference menu

**Files:**
- Create: `Sources/QuotaHistory.swift`
- Create: `Tests/QuotaHistoryTests.swift`
- Modify: `Sources/WidgetPreferences.swift`
- Modify: `Sources/WidgetMenu.swift`
- Modify: `Tests/WidgetPreferencesTests.swift`
- Modify: `Tests/MenuTests.swift`
- Modify: `Scripts/test.sh`

**Interfaces:**
- Consumes: `QuotaSnapshot.fetchedAt`, `QuotaWindow.clampedUsedPercent`, and existing preference/menu callback patterns.
- Produces: `HistoryRetention`, `QuotaHistorySample`, `QuotaHistoryStore.record(_:)`, `setRetention(_:at:)`, and `samples(at:)` for Task 3.

- [ ] **Step 1: Write failing history tests**

Define exact assertions for:

```swift
enum HistoryRetention: String, CaseIterable {
    case session30Minutes, local24Hours, local7Days
}

struct QuotaHistorySample: Codable, Equatable {
    let timestamp: Date
    let fiveHourUsedPercent: Double?
    let weekUsedPercent: Double?
}
```

Cover default memory-only behavior, duplicate timestamps, 30-minute/24-hour/7-day pruning, mode changes, corrupt JSON recovery, atomic persistence reload, deletion when switching to session mode, missing percentages, non-finite values, out-of-order input, and future timestamps that must not extend the retention cutoff.

- [ ] **Step 2: Run history tests and verify RED**

Run:

```bash
swiftc -swift-version 5 -module-cache-path "${TMPDIR:-/tmp}/codex-quota-rings/module-cache" Sources/QuotaModel.swift Sources/QuotaHistory.swift Tests/QuotaHistoryTests.swift -o /tmp/quota-history-tests
```

Expected: FAIL because `Sources/QuotaHistory.swift` does not exist.

- [ ] **Step 3: Implement `QuotaHistoryStore`**

Use an injected file URL and clock for deterministic tests. Required interface:

```swift
final class QuotaHistoryStore {
    private(set) var retention: HistoryRetention
    private(set) var persistenceError: String?
    init(retention: HistoryRetention, fileURL: URL, now: @escaping () -> Date = Date.init)
    @discardableResult func record(_ snapshot: QuotaSnapshot) -> [QuotaHistorySample]
    @discardableResult func setRetention(_ retention: HistoryRetention, at now: Date) -> [QuotaHistorySample]
    func samples(at now: Date) -> [QuotaHistorySample]
}
```

Normalize samples before persistence: clamp finite percentages, skip records where both percentages are absent, reject non-finite dates and dates more than 60 seconds beyond the injected current time, deduplicate timestamps, sort ascending, and prune relative to the injected current time. Write Codable data with `.atomic`; corrupt files are removed without touching preferences.

- [ ] **Step 4: Run history tests and verify GREEN**

Expected: `PASS: private quota history retention, pruning, recovery, and deletion`.

- [ ] **Step 5: Write failing preference and menu tests**

Add `historyRetention` to `WidgetPreferences`, defaulting invalid or missing values to `.session30Minutes`. Extend the menu expectation to a fourth “趋势记录” group with `仅本次 · 30 分钟`, `保留 24 小时`, and `保留 7 天`, plus independent checkmark changes.

- [ ] **Step 6: Run preference/menu tests and verify RED**

Run their existing focused compile commands with `Sources/QuotaHistory.swift` added.

Expected: FAIL because preferences and menu do not expose retention.

- [ ] **Step 7: Implement retention preferences and menu choices**

Persist `widget.historyRetention`, extend `WidgetMenu.Choice`, and keep size/layout/scope selection independent from history changes.

- [ ] **Step 8: Run Task 2 tests**

Expected: history, preference, and menu checks pass.

- [ ] **Step 9: Commit Task 2**

```bash
git add Sources/QuotaHistory.swift Sources/WidgetPreferences.swift Sources/WidgetMenu.swift Tests/QuotaHistoryTests.swift Tests/WidgetPreferencesTests.swift Tests/MenuTests.swift Scripts/test.sh
git commit -m "feat: add private quota history retention"
```

### Task 3: Trend chart and missing-Codex guidance

**Files:**
- Create: `Sources/QuotaTrend.swift`
- Create: `Tests/QuotaTrendTests.swift`
- Modify: `Sources/QuotaView.swift`
- Modify: `Sources/LargeQuotaView.swift`
- Modify: `Sources/QuotaDetailsView.swift`
- Modify: `Sources/App.swift`
- Modify: `Tests/LayoutTests.swift`
- Modify: `Tests/AppearanceCheck.swift`
- Modify: `Tests/ControllerTests.swift`
- Modify: `Scripts/test.sh`

**Interfaces:**
- Consumes: Task 1 `QuotaConnectionState`/Codex application URL and Task 2 history store/sample/retention interfaces.
- Produces: `QuotaTrendSeries`, `QuotaTrendRenderer`, detail-surface guidance actions, and controller wiring used in the final app.

- [ ] **Step 1: Write failing trend-series tests**

Define a pure `QuotaTrendSeries.make(samples:)` result containing independent five-hour and weekly path segments normalized to a 0–1 x/y space. Assert empty, single-point, normal two-line, missing-value, and reset behavior. A drop in used percentage larger than 0.25 starts a new segment instead of drawing across the reset.

- [ ] **Step 2: Run trend tests and verify RED**

Run the new pure Swift test target.

Expected: FAIL because `QuotaTrendSeries` does not exist.

- [ ] **Step 3: Implement trend geometry and renderer**

Create `Sources/QuotaTrend.swift` with these interfaces:

```swift
struct QuotaTrendPoint: Equatable { let x: Double; let y: Double }
struct QuotaTrendSeries: Equatable {
    let fiveHour: [[QuotaTrendPoint]]
    let week: [[QuotaTrendPoint]]
    static func make(samples: [QuotaHistorySample]) -> QuotaTrendSeries
}
enum QuotaTrendRenderer {
    static func draw(series: QuotaTrendSeries, retention: HistoryRetention, in rect: CGRect)
}
```

Series construction is pure. The AppKit renderer draws a 72-point chart, fixed 0–100% scale, two native paths, legend, retention label, and an empty/single-point collection state.

- [ ] **Step 4: Run trend tests and verify GREEN**

Expected: `PASS: reset-aware quota trend geometry and sparse states`.

- [ ] **Step 5: Write failing layout and guidance tests**

Update layout/appearance/controller checks to assert:

- Compact rings do not grow.
- Expanded large and compact detail surfaces reserve chart space before task rows.
- Empty, one-point, and multi-point histories render without clipping.
- `.codexNotInstalled` exposes “安装 Codex”; `.authenticationRequired` exposes “打开 Codex”; `.ready` exposes neither.
- Guidance actions do not trigger card expansion.
- Changing history retention updates the menu, prunes/deletes data through the store, and resizes open panels without moving their logical anchor.

- [ ] **Step 6: Run UI tests and verify RED**

Run `LayoutTests`, `AppearanceCheck`, and the graphical `ControllerTests` when an interactive session is available.

Expected: deterministic layout/appearance tests fail on missing chart/guidance behavior.

- [ ] **Step 7: Integrate history and structured state in `QuotaApp`**

Create the production history file URL under Application Support, instantiate `QuotaHistoryStore` from preferences, record only successful fresh snapshots, and publish samples/retention/state to both detail surfaces. Surface a non-blocking persistence error in the status menu. Add controller actions for installation (`https://chatgpt.com/download/`) and opening the discovered Codex app.

- [ ] **Step 8: Update native detail surfaces**

Increase expanded heights by the chart section, draw it before task rows, add native guidance buttons only in recovery states, and expose equivalent guidance in the tooltip and status menu. Keep compact-ring drawing unchanged. Preserve top-edge anchoring and nonactivating-panel behavior.

- [ ] **Step 9: Run Task 3 tests**

Expected: trend, layout, appearance, and available controller checks pass; regenerated previews show chart and guidance states.

- [ ] **Step 10: Commit Task 3**

```bash
git add Sources/QuotaTrend.swift Sources/QuotaView.swift Sources/LargeQuotaView.swift Sources/QuotaDetailsView.swift Sources/App.swift Tests/QuotaTrendTests.swift Tests/LayoutTests.swift Tests/AppearanceCheck.swift Tests/ControllerTests.swift Scripts/test.sh
git commit -m "feat: display local quota trends and recovery guidance"
```

### Task 4: Task duration, reusable clickable rows, and Codex navigation

**Files:**
- Create: `Sources/CodexNavigator.swift`
- Create: `Sources/TaskRowView.swift`
- Create: `Tests/CodexNavigatorTests.swift`
- Modify: `Sources/TaskStatus.swift`
- Modify: `Sources/QuotaView.swift`
- Modify: `Sources/LargeQuotaView.swift`
- Modify: `Sources/QuotaDetailsView.swift`
- Modify: `Sources/App.swift`
- Modify: `Tests/TaskStatusTests.swift`
- Modify: `Tests/LayoutTests.swift`
- Modify: `Tests/AppearanceCheck.swift`
- Modify: `Tests/ControllerTests.swift`
- Modify: `Scripts/test.sh`

**Interfaces:**
- Consumes: Task 1 `CodexLocation`/exact bundle ID and existing task IDs from `thread/list`.
- Produces: timed `WidgetTaskStatus`, `TaskDurationFormatter`, `CodexNavigating.openTask(id:)`, and shared `TaskRowView` callbacks.

- [ ] **Step 1: Write failing task-timing tests**

Change the status model to expose timing:

```swift
struct WidgetTaskStatus: Equatable {
    let id: String
    let title: String
    let state: WidgetTaskState
    let activeSince: Date
    let completedAt: Date?
    func elapsed(at now: Date) -> TimeInterval
}
```

Assert first observation, continuous active polling, completion freeze, five-minute expiry, a completed ID becoming active again with a new start, malformed-response non-update, and a new store simulating restart. Assert formatter output for under one minute, minutes, and hours.

- [ ] **Step 2: Run task-status tests and verify RED**

Run the existing focused task-status compile command.

Expected: compile failure on the new timing fields.

- [ ] **Step 3: Implement task timing and formatting**

Preserve `activeSince` for continuously running records, set `completedAt` only on a valid active-list disappearance, and keep all timing in memory.

- [ ] **Step 4: Run task-status tests and verify GREEN**

Expected: `PASS: task status tracks duration, completion, expiry, reactivation, and restart semantics`.

- [ ] **Step 5: Write failing navigation tests**

Define:

```swift
protocol CodexWorkspaceOpening {
    func applicationURL(for url: URL) -> URL?
    func open(_ url: URL) -> Bool
    func activateCodex(applicationURL: URL?) -> Bool
}

protocol CodexNavigating {
    @discardableResult func openTask(id: String) -> Bool
}

struct CodexNavigator: CodexNavigating {
    init(workspace: CodexWorkspaceOpening, codexApplicationURL: () -> URL?)
    @discardableResult func openTask(id: String) -> Bool
}
```

Test percent-encoding of `/`, spaces, `?`, and Unicode in a thread ID; successful URL opening; a missing handler; a handler whose `open` returns false; activation fallback; and absent-Codex no-op.

- [ ] **Step 6: Run navigator tests and verify RED**

Expected: FAIL because `Sources/CodexNavigator.swift` does not exist.

- [ ] **Step 7: Implement navigator and workspace adapter**

Build the URL with `URLComponents`/path-safe percent encoding, consult Launch Services before opening, and call the exact-bundle activation fallback whenever handling is unavailable or fails.

- [ ] **Step 8: Write failing reusable task-row UI tests**

Replace raw task labels/drawing with `TaskRowView`. Assert exact status colors, duration text, title truncation, hover highlight state, pointing-hand cursor region, one callback per click, and no propagation to card expand/collapse. Verify large and compact detail layout with multiple and long-title rows.

- [ ] **Step 9: Implement and integrate `TaskRowView`**

Implement the shared row with this module interface:

```swift
final class TaskRowView: NSView {
    var status: WidgetTaskStatus
    var now: Date
    var onClick: ((String) -> Void)?
    init(status: WidgetTaskStatus, frame: CGRect)
}
```

Use it in both detail surfaces, set `onTaskClick`, and let the existing five-second freshness timer refresh `now` and duration labels. Controller wiring calls the injected navigator.

- [ ] **Step 10: Run Task 4 tests**

Expected: task, navigator, protocol, layout, appearance, and available controller checks pass.

- [ ] **Step 11: Commit Task 4**

```bash
git add Sources/CodexNavigator.swift Sources/TaskRowView.swift Sources/TaskStatus.swift Sources/QuotaView.swift Sources/LargeQuotaView.swift Sources/QuotaDetailsView.swift Sources/App.swift Tests/CodexNavigatorTests.swift Tests/TaskStatusTests.swift Tests/LayoutTests.swift Tests/AppearanceCheck.swift Tests/ControllerTests.swift Scripts/test.sh
git commit -m "feat: add task timing and Codex navigation"
```

### Task 5: Universal 2 packaging, documentation, and release verification

**Files:**
- Modify: `Scripts/build.command`
- Modify: `Scripts/Info.plist`
- Create: `Tests/BuildScriptCheck.sh`
- Modify: `Tests/DocumentationCheck.sh`
- Modify: `Scripts/test.sh`
- Modify: `Makefile`
- Modify: `README.md`
- Modify: `README.zh-CN.md`

**Interfaces:**
- Consumes: all production sources and settings delivered by Tasks 1–4.
- Produces: version 1.4 Universal 2 `outputs/QuotaRings/Quota Rings.app` and `Quota-Rings.app.zip`, plus ordinary-user and developer documentation.

- [ ] **Step 1: Write failing packaging and documentation checks**

`BuildScriptCheck.sh` must inspect a copied build fixture and assert two architecture compiles, separate module caches, `lipo -create`, explicit architecture verification, staging before replacement, signature verification, and archive integrity. Add a failure fixture proving an architecture error leaves a sentinel previous release untouched.

Extend bilingual documentation checks for zero configuration, 30-minute/24-hour/7-day privacy modes, history deletion, task durations, navigation fallback, Universal 2, ordinary-user installation, and no GitHub upload.

- [ ] **Step 2: Run new checks and verify RED**

Run:

```bash
zsh Tests/BuildScriptCheck.sh
zsh Tests/DocumentationCheck.sh
```

Expected: FAIL because the build is single-architecture and docs still require manual CLI configuration.

- [ ] **Step 3: Implement staged Universal 2 packaging**

Build both targets into a `mktemp -d` staging directory with architecture-specific module caches, combine using `lipo`, verify both architecture names, assemble and sign the staged bundle, create and test the staged ZIP, then replace `build/` and `outputs/QuotaRings` artifacts only after all checks pass. Preserve an older release on every prior failure path.

- [ ] **Step 4: Update bundle metadata and build targets**

Set `CFBundleShortVersionString` to `1.4` and `CFBundleVersion` to `5`. Update `make live-check` source dependencies and keep the actual account read optional.

- [ ] **Step 5: Rewrite installation, privacy, and troubleshooting documentation**

Remove `QUOTA_CODEX_PATH` from ordinary-user instructions. Separate download/install from source build; document automatic discovery, recovery buttons, history file and deletion behavior, task timing reset, navigation fallback, Universal 2, ad-hoc Gatekeeper limitation, and local-only packaging.

- [ ] **Step 6: Run the complete deterministic suite**

Run `zsh Scripts/test.sh` in an interactive graphical macOS session when available. Otherwise run every non-controller target separately and record the graphical limitation rather than treating a headless early exit as a pass.

Expected: all deterministic targets pass; controller emits `PASS: real panels...` in a graphical session.

- [ ] **Step 7: Build and verify release artifacts**

Run:

```bash
zsh Scripts/build.command
lipo -archs 'outputs/QuotaRings/Quota Rings.app/Contents/MacOS/QuotaRings'
codesign --verify --deep --strict 'outputs/QuotaRings/Quota Rings.app'
unzip -t 'outputs/QuotaRings/Quota-Rings.app.zip'
git status --short
```

Expected: `arm64 x86_64`, valid ad-hoc signature, archive integrity success, and no generated release artifacts in Git status.

- [ ] **Step 8: Commit Task 5**

```bash
git add Scripts/build.command Scripts/Info.plist Tests/BuildScriptCheck.sh Tests/DocumentationCheck.sh Scripts/test.sh Makefile README.md README.zh-CN.md
git commit -m "build: ship zero-config universal quota rings"
```

## Final verification

- [ ] Re-read the spec acceptance criteria and map each one to fresh evidence.
- [ ] Run the full deterministic suite or its exact headless-safe component commands.
- [ ] Run the Universal 2 build, signature, ZIP, public-tree, and documentation checks.
- [ ] Inspect both regenerated preview images for clipping, task-row click affordance, and macOS visual consistency.
- [ ] Request one fresh whole-branch code review, fix every Critical/Important finding in one TDD pass, and rerun verification.
- [ ] Preserve `feature/widget-options` locally and do not push or upload this version.
