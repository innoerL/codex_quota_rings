# Codex Quota Rings Configuration and Open-source Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add configurable size, layout, display scope, and in-place large-card details before publishing Codex Quota Rings as a clean MIT-licensed GitHub project.

**Architecture:** Separate persisted presentation choices from live quota state. A `WidgetPreferences` value owns size, small layout, and display scope; a pure `WidgetVisibility` evaluator turns preference plus workspace state into visibility. Dedicated AppKit views render small and large cards while the app controller owns switching panels, menu bindings, and persistence. Once behavior is stable, lift the source into a public repository with deterministic CI.

**Tech Stack:** Swift/AppKit, Foundation `UserDefaults`, zsh, Python 3 protocol fixture, GitHub Actions macOS runner, Markdown, MIT License.

**Spec:** `docs/superpowers/specs/2026-09-30-codex-quota-rings-open-source-design.md`

## Global Constraints

- Default display scope is Focus Codex; the only scopes are Focus Codex, Always show, and Focus desktop.
- Large is horizontal only. Small can be vertical or horizontal. All choices persist independently.
- Large expands its own card and has no detached detail panel or manual refresh button.
- Small opens a read-only detail surface without a refresh button.
- Focus desktop uses workspace/frontmost-window state only; no Accessibility permission, simulated input, Dock changes, or app hiding.
- Preserve read-only app-server use, 30-second refresh, unknown/stale behavior, and 50%/20% remaining-quota colors.
- Do not publish built applications, local preferences, live values, credentials, `.DS_Store`, cache, or `work/` artifacts.

## Review Focus

- A change to size must not reset the selected display scope, orientation, or separately saved panel positions.
- Selecting Always show must not cause the nonactivating widget to steal focus or break the compact card click target.
- Focus desktop must hide when application state cannot be confidently identified.
- Large-card expand/collapse must not create a second detail window or leave an expanded height after switching to small.
- Public CI must run deterministic checks only and never query a contributor’s Codex account.

---

### Task 1: Model persistent presentation preferences

**Files:**
- Create: `outputs/QuotaRings/Sources/WidgetPreferences.swift`
- Create: `outputs/QuotaRings/Tests/WidgetPreferencesTests.swift`
- Modify: `outputs/QuotaRings/Sources/App.swift`

**Interfaces:**
- Produces `enum WidgetSize: String { case large, small }`, `enum SmallLayout: String { case vertical, horizontal }`, and `enum DisplayScope: String { case focusCodex, always, focusDesktop }`.
- Produces `struct WidgetPreferences` with `load(from: UserDefaults)`, `save(to:)`, and independent mutation methods for each choice.

- [ ] **Step 1: Write failing preference tests**

Assert defaults are `.small`, `.vertical`, and `.focusCodex`; each selected value round-trips; changing size does not alter layout or scope; changing scope does not alter size or layout.

- [ ] **Step 2: Run tests red**

Run `swiftc Sources/WidgetPreferences.swift Tests/WidgetPreferencesTests.swift`; expect failure because the types do not exist.

- [ ] **Step 3: Implement `WidgetPreferences` and replace direct presentation `UserDefaults` reads in `App.swift`**

Use namespaced keys. Retain the prior compact vertical layout as the migration default. Ignore the former `displayEnabled` value so first launch always uses the documented Focus Codex scope.

- [ ] **Step 4: Run preference and existing model checks**

Run the preference binary and the existing model test binary; expect every assertion to pass.

- [ ] **Step 5: Commit**

Commit message: `feat: persist widget presentation preferences`.

### Task 2: Render configurable compact and large cards

**Files:**
- Create: `outputs/QuotaRings/Sources/LargeQuotaView.swift`
- Modify: `outputs/QuotaRings/Sources/QuotaView.swift`
- Modify: `outputs/QuotaRings/Sources/QuotaDetailsView.swift`
- Modify: `outputs/QuotaRings/Sources/App.swift`
- Modify: `outputs/QuotaRings/Tests/AppearanceCheck.swift`

**Interfaces:**
- `QuotaView` consumes `SmallLayout` and exposes a layout-specific preferred size.
- `LargeQuotaView` consumes a `QuotaSnapshot`, expanded state, and `onToggleExpanded`; it exposes collapsed and expanded preferred heights.
- The app controller switches one panel’s content view and frame between selected view modes; it creates no separate details panel for large size.

- [ ] **Step 1: Write failing layout and interaction checks**

Extend the appearance test with assertions for vertical and horizontal small bounds, large collapsed height, large expanded height, and a single in-place expand/collapse callback. Assert the large tree contains no `NSButton` titled `刷新额度` and no detached `QuotaDetailsView`.

- [ ] **Step 2: Run tests red**

Run the appearance binary; expect missing `LargeQuotaView` and layout configuration failures.

- [ ] **Step 3: Implement view layouts and in-place expansion**

Use a horizontal large card with title, status dot, two rings, data-status line, separator, chevron, and detail rows matching the supplied references. Use macOS semantic colors, neutral tracks, a 16-point rounded card, and a quiet hover surface. Preserve green/yellow/red arcs and show gray for stale or unknown data.

- [ ] **Step 4: Render and inspect all four states**

Run the appearance check to create labeled sample-only PNGs for small vertical, small horizontal, large collapsed, and large expanded. Inspect each at normal display size and verify no overlap, clipping, or readable account data.

- [ ] **Step 5: Commit**

Commit message: `feat: add configurable widget layouts`.

### Task 3: Add display-scope behavior and controls

**Files:**
- Modify: `outputs/QuotaRings/Sources/WidgetVisibility.swift`
- Modify: `outputs/QuotaRings/Sources/App.swift`
- Modify: `outputs/QuotaRings/Tests/VisibilityTests.swift`
- Modify: `outputs/QuotaRings/Tests/ForegroundCheck.swift`

**Interfaces:**
- `WidgetVisibility.shouldShow(scope:frontmostBundleID:hasCodexWindow:isDesktopVisible:) -> Bool` is pure and covers all three scopes.
- The contextual menu supplies `Size`, `Small layout`, and `Display when` submenus, all with checkmarks; Small layout is disabled when size is large.

- [ ] **Step 1: Write failing visibility and menu-state tests**

Add a full truth table: Focus Codex requires a visible Codex window, Always show succeeds regardless of foreground app, and Focus desktop requires confirmed desktop visibility. Assert unknown desktop state is false. Assert each menu selection updates only its own preference and that large disables Small layout.

- [ ] **Step 2: Run tests red**

Run visibility tests; expect the former single-scope signature and menu construction to fail the new cases.

- [ ] **Step 3: Implement scope evaluation, workspace detection, and menu submenus**

Identify desktop using Finder/frontmost workspace and the absence of an ordinary application window. Apply a conservative false result when that state is ambiguous. On scope or size change, hide small details, collapse large cards, rebuild the panel frame, and reevaluate visibility without activating the panel.

- [ ] **Step 4: Verify real foreground behavior**

Run the foreground check across Codex, Finder desktop, and a non-Finder application. Assert Focus Codex, Always show, and Focus desktop each hide/show as specified, then restore Focus Codex and Codex foreground.

- [ ] **Step 5: Commit**

Commit message: `feat: add display scope controls`.

### Task 4: Add a reproducible public repository boundary

**Files:**
- Create: `.gitignore`, `Makefile`, `Scripts/check-public-tree.sh`, `Scripts/test.sh`, `Tests/PublicTreeCheck.sh`, `Tests/MakefileCheck.sh`
- Move: public sources and deterministic tests from `outputs/QuotaRings/` to root `Sources/` and `Tests/`
- Move: `outputs/QuotaRings/build.command` to `Scripts/build.command`

**Interfaces:**
- `make test` runs all deterministic model, protocol, layout, visibility, and tree checks without starting the real CLI.
- `make build` runs `make test` then writes `build/Quota Rings.app`; `make live-check` alone uses the authenticated CLI.
- `Scripts/check-public-tree.sh` rejects tracked `.app/`, `.DS_Store`, `work/`, previews, compiler caches, and test binaries.

- [ ] **Step 1: Write failing tree and target checks**

Create fixtures that stage a forbidden preview in a temporary index and run `make test`; require rejection of the fixture and absence of live-account output.

- [ ] **Step 2: Run checks red**

Run `zsh Tests/PublicTreeCheck.sh && zsh Tests/MakefileCheck.sh`; expect missing root scripts and Makefile failures.

- [ ] **Step 3: Move files and implement public build targets**

Use root `build/` for generated app output and `${TMPDIR:-/tmp}/codex-quota-rings` for compiler cache. `make clean` removes only root `build/`.

- [ ] **Step 4: Verify a public checkout shape**

Run `make test && make build && Scripts/check-public-tree.sh && git status --ignored --short`; expect a passing deterministic suite and ignored local outputs only.

- [ ] **Step 5: Commit**

Commit message: `chore: establish reproducible source repository`.

### Task 5: Prepare public collaboration and CI

**Files:**
- Create: `README.md`, `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, `LICENSE`, `.github/ISSUE_TEMPLATE/bug_report.yml`, `.github/ISSUE_TEMPLATE/feature_request.yml`, `.github/pull_request_template.md`, `.github/workflows/ci.yml`
- Create: `Tests/DocumentationCheck.sh`, `Tests/CommunityFilesCheck.sh`, `Tests/CIWorkflowCheck.sh`, `assets/`

**Interfaces:**
- README documents all size/layout/scope options, default Focus Codex, requirements, privacy, limitations, and local commands.
- CI runs `make test` on `macos-latest` for pushes and pull requests, without credentials or a live CLI call.

- [ ] **Step 1: Write failing documentation, community-file, and CI checks**

Require README sections for requirements, build/run, display options, privacy, and limitations. Require MIT text; prohibit credential requests in forms; require behavior, validation, and privacy-impact PR headings. Require `macos`, `pull_request`, `push`, and `make test` in CI, and reject live-check, app-server, and credentials.

- [ ] **Step 2: Run checks red**

Run all three shell checks; expect missing public-file failures.

- [ ] **Step 3: Add documentation, MIT, templates, assets, and CI**

Use `Copyright (c) 2026 Codex Quota Rings contributors` unless the user provides another public copyright name. The README must state that the project is not affiliated with or endorsed by OpenAI and that app-server compatibility can vary by installed Codex version. Use sanitized sample visuals only.

- [ ] **Step 4: Run release-readiness verification**

Run `make test && Scripts/check-public-tree.sh && git diff --check && git status --ignored --short`; expect complete success and no public-boundary violations.

- [ ] **Step 5: Commit**

Commit message: `ci: prepare public collaboration workflow`.

### Task 6: Create and publish the GitHub repository

**Files:**
- Modify: `README.md` only when the final GitHub URL is known.

**Interfaces:**
- Consumes the user-approved GitHub owner and public visibility, then produces one public `codex-quota-rings` repository with `main` pushed to `origin`.

- [ ] **Step 1: Inspect GitHub account and repository name availability**

Run `gh auth status` and `gh repo view <owner>/codex-quota-rings`; do not write externally.

- [ ] **Step 2: Present the exact publish preview**

Show owner, repository name, public visibility, description, MIT license, and commits. Obtain explicit approval for public creation and push.

- [ ] **Step 3: Create and push**

Run `gh repo create <owner>/codex-quota-rings --public --source=. --remote=origin --push --description "A native macOS Codex quota display"`.

- [ ] **Step 4: Verify publication**

Run `gh repo view <owner>/codex-quota-rings --json url,visibility,defaultBranchRef,licenseInfo` and `gh run list --limit 1`; expect a public URL, `main`, MIT metadata after processing, and an initial CI state.

## Self-review

- Tasks 1–3 implement every new preference, layout, scope, and safety requirement before public restructuring.
- Tasks 4–5 cover source hygiene, reproducibility, documentation, MIT, and credential-free CI.
- Task 6 is the only external write, is previewed first, and remains explicitly approval-gated.
- Each review-focus risk has a test in Tasks 1–5.
