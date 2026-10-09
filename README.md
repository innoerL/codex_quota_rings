# Codex Quota Rings

**English** · [简体中文](README.zh-CN.md)

A small native macOS widget for the remaining Codex quota in the 5-hour and weekly windows. It offers compact rings, an expandable desktop-style card, private quota trends, and the status of active Codex tasks.

![Large card, expanded details, and compact vertical and horizontal layouts using sample data](assets/layouts.png)

## Install and use

The packaged app is zero-configuration. Download or receive `Quota-Rings.app.zip`, unzip it, move **Quota Rings.app** to Applications, and open it. Quota Rings automatically discovers the registered Codex app, standard application folders, Homebrew locations, and the executable path. No Terminal command or path setting is needed.

Open Codex and sign in normally. If Codex is absent, the expanded widget shows **Install Codex**. If authentication is required, it shows **Open Codex**. Discovery and connection retry automatically.

The release is a **Universal 2** app for Apple Silicon and Intel Macs, with macOS 12 as the minimum app target when a compatible Codex installation is available. This community build is ad-hoc signed rather than notarized. If Gatekeeper blocks it, use System Settings → Privacy & Security → Open Anyway after confirming where you obtained the archive.

## Features

- Large card, compact vertical rings, and compact horizontal rings.
- Show when Codex is focused by default, always show, or show on a clear Finder desktop.
- Native AppKit UI, 30-second quota updates, reset countdowns, and no manual refresh button.
- Five-hour forecasts after four samples across two minutes. While collecting, the UI says a forecast is coming; estimates after reset are shown as “Will not run out this window”.
- A reset-aware trend chart for the five-hour quota window.
- Real task titles for every currently running local Codex task. `Running` uses warm gold `#B48A4A`; `Completed` uses sage `#8FA990` and remains for five minutes.
- Task elapsed duration starts when Quota Rings first observes a run, freezes on completion, and resets when Quota Rings restarts. Click a task to try its Codex thread; if the thread link is unsupported or fails, Codex is activated in the foreground.
- Remaining quota colors: sage above 50%, warm gold at 20–50%, and terracotta below 20%.

## Controls

Right-click the widget or use its menu bar ring to choose size, compact orientation, visibility, whether to show used quota, and trend retention. Drag the widget to move it. Each layout keeps its own position.

The Simplified Chinese menu offers:

| Group | Choices |
| --- | --- |
| 大小 | 大 / 小 |
| 小组件布局 | 竖向 / 横向 |
| 显示范围 | 聚焦 Codex 时显示 / 一直显示 / 聚焦桌面时显示 |
| 趋势记录 | 仅本次 · 30 分钟 / 保留 24 小时 / 保留 7 天 |

## Privacy

The default mode keeps only the latest **30 minutes** in memory and writes no trend file. Choosing **24 hours** or **7 days** explicitly stores timestamp and the two used percentages at:

`~/Library/Application Support/Quota Rings/quota-history.json`

Switching back to the 30-minute session mode immediately deletes that file. Task IDs, titles, task duration, account data, credentials, and raw protocol messages are never written into quota history. Task information stays in memory and is cleared on restart.

Quota Rings communicates only with the local Codex app-server child process over stdio. It makes no separate network requests. Codex may use its existing authentication and network connection to retrieve account limits.

## Build from source

Developers need Xcode Command Line Tools and Python 3 for the protocol fixture.

```sh
git clone https://github.com/innoerL/codex_quota_rings.git
cd codex_quota_rings
make test
make build
```

The build compiles arm64 and x86_64 separately, combines them as Universal 2, verifies the ad-hoc signature and ZIP, then writes:

- `build/Quota Rings.app`
- `outputs/QuotaRings/Quota Rings.app`
- `outputs/QuotaRings/Quota-Rings.app.zip`

`make live-check` is an optional read-only account check. Native panel tests require a logged-in graphical macOS session. Every build stays local: it does not perform a GitHub push or upload, create a GitHub Release, or send source code elsewhere.

## Troubleshooting

- **Widget is hidden:** use the menu bar ring and select Always Show.
- **Codex is missing:** open the widget details and choose Install Codex; Quota Rings keeps rediscovering it.
- **No quota or gray rings:** open Codex, sign in, and leave it online while automatic retry reconnects.
- **A task click only brings Codex forward:** the current Codex installation does not expose or accept that thread deep link; foreground activation is the intended fallback.
- **History disappeared:** session-only data intentionally clears when the app quits, and selecting the 30-minute mode deletes persisted history.

## Contributing and license

Issues and pull requests are welcome at [innoerL/codex_quota_rings](https://github.com/innoerL/codex_quota_rings). Use synthetic values in public screenshots. The project uses the [MIT License](LICENSE) and is not affiliated with or endorsed by OpenAI.
