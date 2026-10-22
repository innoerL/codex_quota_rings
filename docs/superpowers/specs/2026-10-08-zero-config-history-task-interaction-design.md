# Zero-configuration discovery, quota history, and task interaction design

Date: 2026-10-08

## Purpose

Quota Rings should be usable by a normal macOS user immediately after the app is installed. The user must not need Terminal commands, environment variables, path configuration, or developer tools. The same release also adds an optional local quota trend, task elapsed time, and task-row navigation back to Codex.

This release does not add “start Quota Rings when Codex starts.” Implementing that reliably requires a login helper that is always resident, and the user removed it from scope.

## User-visible outcomes

- A user can unzip the release, move `Quota Rings.app` to Applications, and open it.
- Quota Rings automatically discovers an installed Codex app or Codex CLI.
- If Codex is installed and signed in, quota and task data appear without configuration.
- If Codex is missing, signed out, disconnected, or still loading, the UI explains that state and provides the relevant action.
- Trend retention defaults to private, in-memory data for the current launch only.
- Users may explicitly retain quota history for 24 hours or 7 days on the local Mac.
- Running tasks show elapsed time. Completed tasks show their final elapsed time during the existing five-minute retention period.
- Clicking a task attempts to open its Codex thread. If a thread link cannot be handled, Quota Rings brings Codex to the foreground.
- The local release contains both Apple Silicon and Intel code.

## Scope exclusions

- No login item, launch agent, or helper that starts Quota Rings when Codex starts.
- No cloud storage, synchronization, analytics, or account identifiers.
- No persistence of task titles, task IDs, task timings, or conversation content.
- No bundling or redistribution of the Codex executable.
- No GitHub upload, release creation, or source push for this version.
- No automatic updater or notification system in this release.
- No promise that a private or future Codex URL scheme will always navigate to the requested thread.

## Architecture

The implementation stays within the native AppKit application and adds four small units with explicit responsibilities.

### Codex locator

`CodexLocator` returns either a validated executable plus an installed application URL, or a structured absence result. It searches in this order:

1. A test or developer-only injected executable.
2. A running or Launch Services-registered application with the exact Codex bundle identifier `com.openai.codex`.
3. The registered app bundle’s known executable locations, including `Contents/Resources/codex`.
4. `/Applications/Codex.app` and `~/Applications/Codex.app`.
5. Common CLI paths such as `/opt/homebrew/bin/codex` and `/usr/local/bin/codex`.
6. An executable named `codex` found in the app’s explicit safe PATH.

Every candidate must be a regular executable file. The locator never selects an application through a fuzzy display-name match. `QUOTA_CODEX_PATH` may remain as an undocumented developer override, but it is not part of the user installation flow or troubleshooting instructions.

`QuotaClient` asks the locator again on each reconnect. Installing or moving Codex while Quota Rings is open therefore recovers without restarting Quota Rings.

### Connection state and guidance

The client reports a structured state in addition to its last snapshot:

- `locating`
- `ready`
- `codexNotInstalled`
- `authenticationRequired`
- `disconnected(message)`

The existing retry behavior remains. User-facing copy and actions are derived from the state rather than parsing error strings.

- `codexNotInstalled`: show “未找到 Codex” and an “安装 Codex” action that opens `https://chatgpt.com/download/`.
- `authenticationRequired`: show “请先在 Codex 中登录” and an “打开 Codex” action.
- `disconnected`: keep the stale-value treatment, say that automatic retry is active, and offer “打开 Codex” when an app URL is available.
- `locating`: show the existing loading state without an action.

The compact rings remain visually quiet. Guidance appears in the expanded large card, compact detail card, tooltip, and status menu.

### Quota history store

`QuotaHistoryStore` accepts deduplicated quota snapshots and returns chart samples for the selected retention mode:

- `session30Minutes` — default. Samples live only in memory and are pruned after 30 minutes.
- `local24Hours` — samples are persisted locally and pruned after 24 hours.
- `local7Days` — samples are persisted locally and pruned after 7 days.

The selected mode is stored in `UserDefaults`. Persistent samples use an atomic Codable file under:

`~/Library/Application Support/Quota Rings/quota-history.json`

Each record contains only a timestamp, five-hour used percentage, and weekly used percentage. It contains no task data, account data, raw protocol payloads, or credentials. Invalid or partially written files are discarded and collection restarts without blocking live quota display.

Changing from session-only to a persistent mode starts persistence from that moment; it does not invent past samples. Shortening the period immediately prunes older samples. Switching to `session30Minutes` immediately deletes the persistent history file and retains only the last 30 minutes in memory.

The store rejects duplicate `fetchedAt` timestamps and reset-boundary discontinuities remain visible as a new segment rather than a misleading line across the reset.

### Task timing and navigation

`TaskStatusStore` tracks `activeSince` for each task in memory. The first observation of an active ID starts its timer. Repeated active observations preserve the start. Disappearance marks the task completed, freezes its elapsed duration, and retains it for five minutes. If the same ID becomes active again after completion, it starts a new timing interval.

Application restart intentionally resets all task timing.

`WidgetTaskStatus` exposes the thread ID, title, state, active or completed duration, and the values needed for display. A shared duration formatter produces compact Chinese labels:

- `Running · 12 分钟`
- `Completed · 用时 18 分钟`
- Durations under one minute display `不到 1 分钟`.

Task rows become clickable. The controller asks `CodexNavigator` to open `codex://threads/<percent-encoded-thread-id>` only when Launch Services reports a handler. When no handler is present or opening fails, the navigator activates a running app with bundle ID `com.openai.codex`, or opens its located application URL. If Codex is absent, the click has no side effect and the missing-Codex guidance remains visible.

OpenAI documents app-server thread identifiers and resume operations, but does not document a stable desktop deep-link contract. The activation fallback is therefore part of the required behavior.

## Interface design

### Trend chart

The small rings keep their current size. The chart appears only in detail surfaces:

- Expanded large card: after the two quota detail rows and before background task rows.
- Compact detail card: after quota details and before task rows.

The chart is approximately 72 points high with a fixed 0–100% scale. It draws two native AppKit paths: five-hour and weekly remaining quota. A compact legend identifies both lines and shows the selected range. Empty and single-point histories show a restrained collection state rather than fabricating a curve. Reset boundaries break the path.

The right-click and status-item menu gains a “趋势记录” submenu with checkmarks for:

- `仅本次 · 30 分钟`
- `保留 24 小时`
- `保留 7 天`

Changing the mode updates open panels immediately.

### Task rows

Task rows grow enough to fit duration without truncating the status. Titles retain truncation behavior. Running remains gold brown `#B48A4A`; Completed remains sage green `#8FA990`. Hovering a row adds a subtle macOS-style highlight and a pointing-hand cursor. Clicking anywhere in the row invokes navigation and must not trigger the card’s expand/collapse action.

The freshness timer already used by the app also redraws task durations, so elapsed labels advance without additional per-row timers.

### Missing-state actions

Expanded/detail surfaces use native `NSButton` actions for “安装 Codex” and “打开 Codex.” The status menu exposes the same action so users can recover even when the widget is compact. Buttons do not appear in normal ready state.

## Universal packaging

`Scripts/build.command` builds the executable twice using architecture-specific module caches and deployment targets:

- `arm64-apple-macosx12.0`
- `x86_64-apple-macosx12.0`

`lipo -create` combines the binaries into one Universal 2 executable. The script fails if either architecture cannot compile. It then copies the plist, signs the completed bundle, copies the app into `outputs/QuotaRings`, and creates the ZIP as it does today.

The build verifies that `lipo -archs` contains both `arm64` and `x86_64`, verifies the code signature, and tests the archive. The local build remains ad-hoc signed. Warning-free distribution to other Macs still requires a user-owned Apple Developer ID and notarization, which is outside this version.

The bundle version becomes 1.4 with a new build number.

## Compatibility and migration

- Existing size, orientation, display scope, show-used preference, and per-layout positions remain unchanged.
- Trend retention defaults to `session30Minutes` for existing and new users, so upgrading never begins persistence without an explicit choice.
- The runtime remains compatible with macOS 12 when a compatible Codex CLI exists. The currently distributed Codex desktop app may impose a newer macOS requirement independently.
- Locator and navigator platform calls are behind protocols so tests do not depend on the developer machine’s installed applications.

## Failure handling

- No Codex installation: guide the user; retry discovery periodically.
- Installed but signed out: open Codex on request; keep retrying without clearing preferences.
- App-server malformed response or disconnect: preserve the last quota snapshot, mark it stale, suppress confident forecasts, and retry.
- Corrupt history: delete only the history file, retain preferences, and continue with an empty chart.
- Persistent-history write failure: continue in memory and show a non-blocking status-menu message; never interrupt live quota updates.
- Unhandled deep link: activate Codex.
- Universal build failure for either architecture: fail the build and do not overwrite the previous release output.

## Testing

Automated tests cover:

- Locator ordering, exact bundle matching, path validation, moved applications, CLI-only installation, and absence.
- Structured connection-state transitions and recovery after Codex becomes available.
- History deduplication, 30-minute/24-hour/7-day pruning, atomic decode recovery, reset path breaks, mode migration, and persistent-file deletion.
- Task first observation, continuous activity, completion duration, five-minute expiry, restart semantics, and reactivation.
- Navigation URL construction, handler success, failed link fallback, activation fallback, and absent-Codex behavior.
- Menu checkmarks and persistence-mode changes.
- Large and compact detail sizing for empty, single-point, full trend, multiple tasks, and long titles.
- Source boundary checks to ensure generated history and release artifacts cannot enter the public tree.
- Universal binary architecture verification, bundle signing verification, and ZIP integrity.

Native controller tests continue to verify nonactivation, card expansion, placement preservation, and click routing in a logged-in graphical macOS session.

## Documentation

English and Chinese README files separate ordinary installation from source development:

- Ordinary users download, unzip, move the app to Applications, and open it. No Terminal or path configuration is documented.
- Developers retain build, test, and optional diagnostic instructions.
- Privacy documentation explains the default memory-only mode, explicit 24-hour/7-day retention, file location, deletion behavior, and fields stored.
- Troubleshooting explains missing Codex, sign-in, Gatekeeper for ad-hoc builds, and deep-link fallback.

## Acceptance criteria

The work is complete when:

1. A clean user profile with Codex installed in a supported location can launch Quota Rings and receive data without configuration.
2. Missing-install and signed-out states provide working guidance and recover automatically.
3. Trend retention follows the selected privacy mode and deletes persisted data when disabled.
4. Both detail surfaces render correct, reset-aware trends.
5. Task elapsed labels update, freeze at completion, and reset after restart.
6. Task clicks navigate to the thread when supported and otherwise activate Codex.
7. The release executable reports both `arm64` and `x86_64`.
8. All deterministic tests pass; graphical integration tests pass when run from an interactive macOS session.
9. The app and ZIP are generated locally and nothing is uploaded to GitHub.
