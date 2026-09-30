# Codex Quota Rings Open-source Design

## Purpose

Publish Codex Quota Rings as a small, welcoming MIT-licensed macOS project. It gives people a transparent way to build, inspect, and extend a native floating display for the current Codex usage windows.

## What exists today

The prototype is a native Swift/AppKit application. It starts a read-only local `codex app-server` session, requests the current usage limits, and renders compact 5-hour and weekly rings. It uses system colors for quota state and provides a passive detail card.

## Project boundary

The public repository includes only source, deterministic tests, documentation, build configuration, public screenshots, and GitHub collaboration files. It does not include locally built `.app` bundles, account data, app-server tokens, macOS preferences, temporary work products, machine-specific metadata, or live quota captures.

The project is for macOS. It requires a locally installed, already authenticated Codex CLI. It never transmits credentials, starts a model turn, consumes a reset credit, or writes to a Codex account.

## Repository layout

```text
CodexQuotaRings/
  Sources/                 AppKit application source
  Tests/                   Model, protocol, visibility, and rendering checks
  Scripts/                 Reproducible build and verification entry points
  assets/                  Sanitized product screenshots
  .github/                 CI, issue forms, pull-request template
  README.md                Setup, behavior, privacy, and troubleshooting
  CONTRIBUTING.md          Local workflow and change expectations
  CODE_OF_CONDUCT.md       Contributor conduct policy
  SECURITY.md              Private vulnerability-reporting guidance
  LICENSE                  MIT text
```

The top-level build entry point builds the app into a temporary directory, runs deterministic checks first, and leaves release artifacts out of Git. A release workflow may later produce downloadable builds, but versioned binary distribution is not in the first public release.

## Product behavior

- Display the remaining percentage for the 5-hour and weekly Codex windows. Values above 50% are green, 20–50% are yellow, and values below 20% are red.
- Poll every 30 seconds and consume usage-limit update notifications when available.
- Persist a user-selected display scope. The default is **Focus Codex**, which shows the widget only while the desktop Codex application (`com.openai.codex`) is foreground and has a visible app window. **Always show** keeps it visible above other applications. **Focus desktop** follows the macOS desktop-widget convention: show it only after the desktop is revealed, then hide it when an ordinary application becomes foreground.
- Persist a user-selected size and layout. **Large** is a horizontal two-ring card. **Small vertical** stacks the two compact rings. **Small horizontal** places the compact rings side by side. Large has no separate orientation option.
- The large card begins collapsed with its title, the two rings, a data-status label, and an expand indicator. Clicking it expands the lower half of that same card to show the reset countdown, reset timestamp, and last-update timestamp. It has no manual refresh button or detached detail window.
- Small layouts open a compact native detail surface on click. It contains the same read-only timing details and no manual refresh button.
- Make the active size, small-layout orientation, display scope, and card expansion state clear in the controls. Save size, orientation, display scope, and position separately so changing one never overwrites the others.
- Treat absent, invalid, stale, or disconnected data as unknown; never present it as available quota.

## Interaction and visual design

The controls follow macOS visual conventions: system semantic colors, rounded type for compact percentage values, translucent material for expanded information, and a quiet hover response. The large card uses a 16-point rounded rectangle, a restrained separator, and a chevron that changes direction with expanded state. Both ring tracks remain neutral; only the filled arc uses the quota color. A small status dot appears only for stale or disconnected data.

The contextual menu includes a size submenu, a small-layout submenu enabled only for small size, and a display-scope submenu. Their selected choices use the standard checkmark state. The display-scope submenu contains exactly `Focus Codex`, `Always show`, and `Focus desktop` in that order.

Focus desktop must use the macOS workspace/frontmost-application signal and visible-window state; it must not capture keystrokes, simulate desktop clicks, hide other applications, alter the Dock, or use Accessibility permissions. If the desktop state cannot be resolved, the widget hides rather than appearing in the wrong context.

## Privacy and safety contract

The app reads the local app-server's `account/rateLimits/read` response and update event only. It keeps the live values in process memory. It does not log full responses, persist quota history, access the login store, call account mutation methods, or make network calls of its own.

Documentation must state that this app is independent from OpenAI and depends on the local CLI's supported app-server contract. The project name and copy must not imply endorsement.

## Collaboration model

MIT permits commercial and derivative use while requiring preservation of the copyright and license notice. GitHub issues use structured bug and feature forms. Pull requests state the behavior changed, validation run, and privacy implications. CI runs the deterministic macOS checks for every pull request; live-account checks remain local-only.

## First release acceptance criteria

- A clean macOS checkout can build the app and run all non-live tests with the documented command.
- Deterministic tests cover every size/layout combination, each display scope, compact-card detail opening, large-card in-place expansion and collapse, menu checkmark persistence, stale/unknown coloring, and independent preference updates.
- `git status --ignored` shows no local app bundle, preview, `.DS_Store`, compiled executable, cache, or test output tracked.
- README covers requirements, running, building, automatic visibility behavior, color semantics, privacy, limitations, and contribution entry points.
- Legal and community files are present and internally consistent with MIT licensing.
- GitHub Actions runs the deterministic suite on macOS without account credentials.
- The initial public repository has a clean `main` branch, a descriptive first commit history, and no remote until the user approves the final public repository creation.

## Explicit non-goals

- Windows, Linux, menu-bar-only mode, historic usage graphs, quota reset, account login, telemetry, automatic updates, and a distributable notarized binary.
- Reading undocumented application internals or bundling the Codex CLI.
