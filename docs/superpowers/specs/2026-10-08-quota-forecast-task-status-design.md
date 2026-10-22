# Quota forecast and background task status design

## Purpose

Extend Quota Rings so its large detail surface shows when each Codex quota
window is likely to run out at the user's current consumption rate. When the
widget is visible while Codex is not the frontmost app, show the real titles
and states of active local Codex tasks. This keeps the widget useful as a
desktop component without turning it into a history view.

The feature remains local-only. It does not write task titles to disk, call a
remote service, or change the existing display-scope choices. This iteration
is packaged locally and is not pushed to GitHub.

## Scope

### Quota forecast

`QuotaForecastEngine` is a pure model component. It receives timestamped
quota snapshots from the existing `QuotaClient` and maintains a separate
rolling, 30-minute history for the five-hour and weekly windows.

A forecast becomes available after at least four samples spanning two minutes
within a single reset window. The engine derives an hourly consumption rate
from positive usage deltas and uses a median rate so a single delayed polling
response does not skew the result. It discards samples whenever the reset time
changes or the used percentage moves backwards by more than a small tolerance.

For a positive, measurable rate, the forecast is `remainingPercent / rate`.
It renders as `预计 HH:mm 用尽` when the time is today and `预计 M/d HH:mm 用尽`
otherwise. If the predicted time is at or after the quota reset, the result is
`本周期内不会用尽`. If observation is still warming up or the rate is too low,
the result is `收集中，稍后预测`.

The large widget shows this line directly below each reset description. Small
vertical and horizontal widgets remain uncluttered; their existing click-open
details show the same forecast.

### Codex task status

`QuotaClient` adds a read-only `thread/list` request on the same local Codex
app-server connection after initialization and every five seconds. It maps each
thread whose current status is `active` to a `WidgetTaskStatus`:

- title: the thread's real `name`, falling back to `preview` when unnamed;
- state: `running` while the thread is active;
- identity: the thread id, used to preserve state across polls.

`TaskStatusStore` remembers only task ids and titles that were observed as
active during the current app process. When an observed active task disappears
from the active set, it becomes `completed` and expires after five minutes.
Idle, archived, or historical threads that were never observed running are
never inserted. The store is memory-only, so a relaunch begins with currently
active tasks and no completed entries.

The status list is supplied to views only while Codex is not focused and the
widget is otherwise eligible to display under the user's chosen display scope.
The large widget appends one row for each running or retained completed task,
expanding its card height as needed. Small layouts show the list in their
click-open details panel. On return to Codex, the status rows disappear and the
large card returns to its normal height.

Each status row truncates an overlong title, shows `Running` or `Completed` at
the trailing edge, and uses these exact colors:

- `Running`: warm gold `#B48A4A`.
- `Completed`: sage green `#8FA990`.

## Data flow

1. `QuotaClient` receives a quota response or quota update notification.
2. `QuotaForecastEngine` records the two current windows and produces a
   forecast result for each.
3. `QuotaApp` assigns snapshots and forecasts to the compact, details, and
   large views on the main thread.
4. Every five seconds, `QuotaClient` requests `thread/list`; it publishes the
   active-thread set.
5. `TaskStatusStore` turns the active set into running and expiring completed
   rows, then `QuotaApp` exposes those rows to views only while Codex is not
   frontmost.
6. Visibility changes immediately recompute both the panel's visibility and
   whether task rows are visible.

## Failure handling

- A failed or malformed thread-list response leaves the last known rows in
  place until their normal expiry; it does not replace them with historical
  threads.
- A quota polling failure leaves the last forecast visible only while the
  existing snapshot is fresh. Once stale, views use their existing stale
  appearance and do not present a confident prediction.
- A reset boundary clears the corresponding forecast history before recording
  the new sample.
- Missing thread names use the supplied preview; missing title data becomes
  `未命名任务`.

## Validation

Add deterministic tests for:

- forecasts after sufficient samples, slow/no use, prediction after reset, and
  history reset on a new quota window;
- decoding active thread title, preview fallback, and multiple active tasks;
- running-to-completed transition, five-minute expiry, and exclusion of idle
  historical threads;
- gold and sage task-status rendering and task-list visibility only outside
  focused Codex;
- large-card resizing and compact-details forecast/task presentation.

The complete existing `make build` suite must pass, then the output app is
rebuilt at `build/Quota Rings.app` and copied into the local release folder for
double-click launch. No GitHub push, release, or repository write occurs.
