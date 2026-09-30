# Codex Quota Rings Open-source Design

## Purpose

Publish Codex Quota Rings as a small, welcoming MIT-licensed macOS project. It gives people a transparent way to build, inspect, and extend a native floating display for the current Codex usage windows.

## What exists today

The prototype is a native Swift/AppKit application. It starts a read-only local `codex app-server` session, requests the current usage limits, and renders compact 5-hour and weekly rings. It runs only while the ChatGPT/Codex desktop app is foreground, uses system colors for quota state, and provides a passive detail card.

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
- Show the compact rings only when the desktop Codex application (`com.openai.codex`) is foreground and has a visible app window. Hide the compact and detail surfaces elsewhere.
- Expand on click to show the reset countdown, reset timestamp, and last-update timestamp. The detail card has no manual refresh button.
- Treat absent, invalid, stale, or disconnected data as unknown; never present it as available quota.

## Privacy and safety contract

The app reads the local app-server's `account/rateLimits/read` response and update event only. It keeps the live values in process memory. It does not log full responses, persist quota history, access the login store, call account mutation methods, or make network calls of its own.

Documentation must state that this app is independent from OpenAI and depends on the local CLI's supported app-server contract. The project name and copy must not imply endorsement.

## Collaboration model

MIT permits commercial and derivative use while requiring preservation of the copyright and license notice. GitHub issues use structured bug and feature forms. Pull requests state the behavior changed, validation run, and privacy implications. CI runs the deterministic macOS checks for every pull request; live-account checks remain local-only.

## First release acceptance criteria

- A clean macOS checkout can build the app and run all non-live tests with the documented command.
- `git status --ignored` shows no local app bundle, preview, `.DS_Store`, compiled executable, cache, or test output tracked.
- README covers requirements, running, building, automatic visibility behavior, color semantics, privacy, limitations, and contribution entry points.
- Legal and community files are present and internally consistent with MIT licensing.
- GitHub Actions runs the deterministic suite on macOS without account credentials.
- The initial public repository has a clean `main` branch, a descriptive first commit history, and no remote until the user approves the final public repository creation.

## Explicit non-goals

- Windows, Linux, menu-bar-only mode, historic usage graphs, quota reset, account login, telemetry, automatic updates, and a distributable notarized binary.
- Reading undocumented application internals or bundling the Codex CLI.
