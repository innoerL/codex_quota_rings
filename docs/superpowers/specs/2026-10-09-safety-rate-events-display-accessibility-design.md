# Quota Rings safety rate, events, display rules, and accessibility

## Goal

Turn Quota Rings into a private, passive decision aid. It should explain whether the current five-hour quota consumption is sustainable, summarize local Codex work, preserve a short local account of relevant quota events, respect focused-work display conditions, and communicate the same information without relying on color alone.

The app remains a native AppKit accessory app. It does not send macOS notifications, contact a server other than local Codex, or persist account details, task titles, task IDs, or protocol messages.

## Retention and migration

`HistoryRetention` has exactly two choices:

| Choice | Stored history and events |
| --- | --- |
| Session — 30 minutes | Keep samples and events in memory only; remove any persisted local history or events. |
| Local — 5 hours | Store samples and quota events in Application Support; prune both to five hours. |

Existing raw preference values `local24Hours` and `local7Days` migrate to `local5Hours`. Existing persisted samples are retained only if their timestamps are within the last five hours. The widget menu, documentation, and user-facing labels expose only the new two choices.

## Safety rate

`QuotaSafetyRateEngine` consumes five-hour quota samples only. It ignores samples before the most recent detected reset and waits until it has three samples spanning at least two minutes. It calculates:

- **Current rate:** the used-percent change per hour over the most recent 15-minute sample window.
- **Sustainable rate:** remaining percent divided by hours until the five-hour reset.
- **Forecast:** the existing forecast engine remains the source of the estimated depletion time; the safety engine only classifies the pace.

The resulting state is one of:

| State | Rule | Meaning |
| --- | --- | --- |
| Collecting | Insufficient post-reset samples | Still learning the current pace. |
| Safe | Current rate ≤ 110% of sustainable rate | On track to reach reset. |
| Caution | Current rate is 110–140% of sustainable rate | Consumption is ahead of budget. |
| Danger | Current rate > 140% of sustainable rate or the forecast depletes before reset | Likely to run out before reset. |

The UI exposes a text label, current and sustainable rate in percent per hour, and a non-color symbol. Sage, warm gold, and terracotta reinforce the state but never carry the meaning alone. No state creates a system notification.

## Task summary

`TaskStatusStore` remains the source of live task rows and retains completed rows for five minutes in memory. `TaskSummary` derives from those rows and contains active-count, retained-completed-count, and a concise label such as `2 个运行中 · 1 个刚完成`.

The compact double-ring card shows the summary above its task rows. The large card and detail card place the summary at the start of their task sections. Task rows keep their existing title, state, duration, and click-to-open-Codex behavior. No task data is added to local history or events.

## Quota event history

`QuotaEventStore` is independent from task status and records only quota events:

- five-hour quota reset detected;
- safety-rate state entered or returned to safe;
- remaining quota crossing 50%, 20%, or 10%;
- quota connection recovered after a disconnected state.

Each event stores a timestamp, event kind, and an optional numeric remaining percentage. It never stores raw responses, account identifiers, task information, or free text from Codex.

The details card has a compact chronological “recent activity” section below the trend chart. It lists the last four events with an icon, a local time, and a fixed localized description. Events are deduplicated by kind and state transition; repeated polling does not create duplicates.

## Display rules and interactions

`WidgetDisplayRules` is stored separately from `DisplayScope` and defaults to:

- hide while a full-screen app occupies the active screen: enabled;
- hide on a covered desktop: enabled when display scope is `focusDesktop`;
- temporary detail: Option-click the ring card;
- lock display: disabled.

The menu adds controls for full-screen hiding and lock display. Lock display overrides scope-based hiding until the user unlocks it, while quit and app termination always hide the panels. Option-click opens the applicable large-card expansion or compact detail panel without changing the saved lock preference. Task-row clicks keep their existing navigation behavior and do not toggle the card.

## Accessibility and visual behavior

- Ring cards expose five-hour value, weekly value, safety state, task summary, and display-lock state in their VoiceOver label and value.
- Trend accessibility text includes the time range, the remaining-percent range, and the safety state.
- Task rows expose title, state, and duration as before; task summary provides counts before individual rows.
- Every safety state has a symbol and a localized text label in addition to its color.
- The interface checks macOS increase-contrast and reduce-motion preferences. Higher contrast increases ring/grid/text contrast; reduced motion suppresses nonessential hover and transition animation.

## UI placement

- **Small card:** safety state appears below the rings; task summary appears before task rows when present.
- **Large collapsed card:** safety state and task summary replace no existing quota values.
- **Expanded/detail card:** safety state appears after the five-hour forecast, task summary begins the task section, and recent activity appears below the trend chart before task rows.
- **Menu:** adds display-rule controls and replaces 24-hour/7-day history choices with the two retention choices.

## Validation

Add deterministic tests for retention migration and pruning, reset-aware safety-rate thresholds, task-summary counts, event deduplication and retention, display rule precedence, Option-click behavior, and accessibility labels. Extend layout and appearance tests for symbols, labels, increased contrast, reduced motion, compact task summaries, and recent-activity placement. Run the complete non-graphical suite, compile controller tests, build Universal 2, validate signature and ZIP integrity, and manually inspect generated previews.
