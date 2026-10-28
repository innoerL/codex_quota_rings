# Changelog

English · [简体中文](CHANGELOG.zh-CN.md)

This file records implemented changes in the repository. See [GitHub Releases](https://github.com/innoerL/codex_quota_rings/releases) for earlier published versions.

## 1.5.0 — 2026-10-28

### Added

- Added a 42 × 42 minimal single-ring mode. Its upper and lower arcs show the five-hour and weekly quotas, and their order can be swapped.
- Added weekly usage pace based on quota consumed versus time elapsed.
- Marked inferred quota resets on the five-hour trend.
- Smoothed quota refreshes across ring arcs, center values, and detail percentages.
- Made standard, minimal, and large cards follow macOS light or dark appearance.
- Showed the current plan, available reset-card count, and earliest expiry when Codex provides it. Count-only responses explicitly say that expiry is unavailable.

### Improved and fixed

- Removed compact mode and placed Standard and Minimal directly in the Mode menu. Quota details retain their text size in every mode.
- Replaced the usage-spike corner dot and moving highlight with a white expanding halo around the five-hour ring or minimal single ring. Each cycle lasts about 1.25 seconds, and details explain the spike.
- Removed reset celebration and star-trail mode.
- Removed the imminent-reset dot from the five-hour ring while keeping the text countdown.
- Fixed overlapping weekly reset, pace, forecast-basis, and trend content in the expanded large card.
- Added bilingual version history and a SHA-256 checksum file for the release archive.

### Verification

- Model, protocol, layout, appearance, and static checks passed. Universal 2, signing, and ZIP integrity are checked after packaging.
- The native panel controller test still requires a logged-in macOS graphical session and could not finish in this terminal environment.
