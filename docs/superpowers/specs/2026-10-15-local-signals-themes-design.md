# Local Signals and Ring Themes Design

## Goal

Add quiet, local feedback for unusual five-hour quota consumption, imminent resets, and selectable ring palettes without adding network requests, notifications, or persisted usage-event data.

## Behavior

- The signal engine retains only the latest 30 minutes of five-hour samples in the active reset window.
- A spike appears when the latest five-minute consumption rate is at least 2.5 times the earlier observed rate and at least five percentage points per hour faster. It clears automatically when the condition no longer holds or the quota resets.
- A five-hour reset is imminent only when its reset time is more than zero and no more than 15 minutes away.
- Compact widgets show a small terracotta dot for a spike and a gold dot attached to the five-hour ring for an imminent reset. Larger views use short colored status text and emphasize the reset row.
- Ring palettes are: semantic quota status (default), graphite, warm, and the macOS system accent color. The selection is stored in the existing widget preferences.
- The semantic palette maps remaining quota to sage at 65% or more, warm gold at 30–64%, terracotta at 10–29%, and deep berry red (`#8E4B58`) below 10%.

## Safety and privacy

The signal engine operates only on already-received quota snapshots. It does not send notifications, read task data, make network calls, or write event history to disk.
