# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- **plasmashell crash after a token refresh while rate limited**: the token watcher cleared the rate limit state inside its own data handler, which disconnected its source while `plasma5support` was still delivering that data. `plasma5support` then wrote into the relay it had just deleted, and plasmashell later died with SIGSEGV in `QV4::ExecutableAllocator::allocate`. The reset now runs after the delivery

## [2.5.3] - 2026-10-25

### Changed

- The usage cache moved from the widget's settings to LocalStorage (SQLite): Plasma's layout file (`plasma-org.kde.plasma.desktop-appletsrc`) is no longer rewritten every 5 minutes, and instances showing the same account share one cache and trend history again. Without the LocalStorage module (a separate package on Debian and Ubuntu) the widget keeps using its settings ([#28](https://github.com/izll/plasma-claude-usage/pull/28), thanks @gdevenyi, who also tracked down the 2.5.2 memory leak independently)

### Fixed

- **Bogus "Breakdown" model row**: the usage API now returns `seven_day_breakdown`, a per-surface summary rather than a limit, and the popup showed it as "Breakdown 0%" in place of the real model limits (e.g. Fable from the `limits` array). Only `seven_day_*` entries with a numeric `utilization` count as model limits now

## [2.5.2] - 2026-10-22

### Fixed

- **plasmashell memory leak**: every cache save ran a new shell command named after the whole cached JSON, and Plasma keeps every such command name in memory, so plasmashell grew by megabytes per save (~5.6 MB/min with both usage widgets). The cache now lives in the widget's own settings and is saved without running a command; the old cache file is read once to carry the data over
- The process and token watchers poll one persistent source instead of starting a new command each time, and the Claude Code version recheck runs every 30 minutes and when the popup opens instead of every minute
- The "Show in panel" model checkboxes in the settings appear again (the page read the wrong field of the cached model list)

## [2.5.1] - 2026-10-19

### Added

- **Widget update notice**: the widget checks the KDE Store (the same data Discover uses) once a day for a newer version of itself. A green "Widget update X.Y.Z" badge in the popup footer opens "Get New Widgets"; the General settings tab shows the installed version with "Up to date" or an Update button. Can be turned off with "Check for widget updates"

## [2.5.0] - 2026-10-17

### Added

- **Ring logo size** setting (50–100%, default 85% of the ring's inner diameter) for the Logo and Logo + % ring modes

### Changed

- Settings are grouped into **General**, **Panel**, **Popup** and **Account** tabs instead of one long page; the tab names follow the widget's language
- Ring options are only enabled for the ring style, the ring logo size only in the logo modes
- The popup's update badge now says "Claude Code 2.1.x available", so it no longer looks like a widget update ([#27](https://github.com/izll/plasma-claude-usage/issues/27), thanks @rj-au)

## [2.4.2] - 2026-10-10

### Fixed

- plasmashell no longer hangs at 100% CPU with the "Bar" panel style in the vertical layout — the bars' height fed back into the widget's own height ([#26](https://github.com/izll/plasma-claude-usage/issues/26), thanks @grzebo)

## [2.4.1] - 2026-09-25

### Fixed

- 7-day trend now plots weekly usage instead of the 5-hour session, which reset every 5 hours and made the chart a sawtooth

## [2.4.0] - 2026-09-23

### Added

- **Metrics size** setting (100–300%) — scales the panel rings, bars, dots and text as well as the popup rings and bars; metrics are capped at the panel thickness so nothing gets clipped ([#23](https://github.com/izll/plasma-claude-usage/pull/23), thanks @noctuum)
- **Credentials path** setting — point the widget at another `.credentials.json`, or at the folder containing it, so several widget instances can show different accounts; empty keeps the previous behaviour ([#25](https://github.com/izll/plasma-claude-usage/pull/25), thanks @mpetruska)
- The configured folder also drives the account file, the token-stats scan and the `claude` process started by "Open Claude" and the silent session refresh; each configured instance keeps its own cache
- **Ring center** setting: percent, Claude logo, or logo with the percent on top
- **Window labels** option: small "5h" / "7d" in the corner of the panel rings
- **Panel margin** setting (default 4px, previously a fixed ~12px on each side)

### Fixed

- Popup keeps the right size after switching between card and classic style; the "resize after switching styles" hint is gone ([#24](https://github.com/izll/plasma-claude-usage/pull/24), thanks @noctuum)
- A manually resized (scrollable) popup no longer snaps back to full height when new content arrives
- Token Stats (Today) was always empty: the scan referenced a file that never existed, and the date filter never saw the timestamp
- A second account no longer shows the first account's e-mail and plan; usage, plan and trend are reset when the credentials path changes
- Panel icon selector stays available when the logo is shown inside the rings

## [2.3.6] - 2026-09-10

### Fixed

- Card popup no longer renders clipped on the right when the footer status line is long ("Updated 3m ago · Next update in 2m"); the status label now elides instead of forcing the card column past the popup edge

## [2.3.5] - 2026-08-30

### Fixed

- "Colors" section label translated in all 15 languages (was English-only outside EN/HU)
- "Token Stats (Today)" section title translated in all 15 languages (was untranslated everywhere)

## [2.3.4] - 2026-08-30

### Fixed

- "Show in panel" options are back in the main panel settings — the new Colors section had pushed them under the wrong heading; Colors (with background opacity) now follows them, matching the Codex widget layout

## [2.3.3] - 2026-08-30

### Added

- Time-proportional marker on the classic popup's session and weekly progress bars (shown when time-proportional warnings are enabled)

### Changed

- "Colors" is now its own section in settings, matching the Codex Usage widget layout

## [2.3.2] - 2026-08-30

### Added

- Icon size setting for the panel icon (Auto or 2–64 px) in General settings

### Changed

- Panel icon is rendered from SVG at the exact display size (device-pixel-ratio aware) — crisper icon, especially at larger sizes

## [2.3.1] - 2026-08-30

### Fixed

- "Rate limited" error when `.credentials.json` also contains an `mcpOAuth` section (OAuth MCP servers) — token parsing is now scoped to the `claudeAiOauth` object ([#21](https://github.com/izll/plasma-claude-usage/pull/21), thanks @OndraM)

## [2.3.0] - 2026-08-27

### Added

- Classic popup now includes all sections from card view: extra usage, token stats, 7-day trend, installations, quick links
- Section ordering and visibility settings now apply to both card and classic popup styles
- Style switch hint in settings — reminds users to resize the widget after changing styles

### Changed

- "Popup style" renamed to "Widget style" in settings (applies to desktop widgets too, not just panel popups)
- "Popup cards" section renamed to "Sections" and made visible in all styles

### Fixed

- Update check now uses curl subprocess — survives suspend/resume like the usage fetch
- Update indicator clears within 1 minute after upgrading (was only checked at startup)
- Toggling update check on/off immediately runs a version check and shows/hides the indicator
- Classic popup spacing — hidden sections (extra usage, tokens, etc.) no longer leave empty gaps
- Classic popup footer (Updated/Refresh) now always visible outside the scrollable area

## [2.2.1] - 2026-08-27

### Added

- Remaining time in panel tooltip — hovering now shows reset countdown (e.g. `3h 12m`) alongside usage percentages (#9)
- `$CLAUDE_CONFIG_DIR` environment variable support for users who moved their Claude config from `~/.claude/` (#19)

### Fixed

- Account email and plan tier now refresh on every credentials cycle, no longer goes stale after switching accounts (#20)

## [2.2.0] - 2026-08-26

### Added

- API fetch via curl subprocess instead of QML XMLHttpRequest — immune to plasmashell's stale network state after suspend/resume (thanks @lockshore, PR #17)
- Silent session refresh — opt-in setting to automatically refresh expired OAuth token in the background using a pty (thanks @bartekmp, PR #18)
- Credentials retry — retries credential reads up to 4 times on boot when file is empty or fails to parse
- Refresh button bypasses the 55s fetch throttle
- Red dot on panel icon for network errors
- Scrollable content now available for both card and classic popups

### Changed

- Network error (status 0) treated as transient — cached data stays visible with neutral notice instead of "Not logged in"
- "Run 'claude' to log in" only shown when actually logged out
- Footer scrolls with content instead of being fixed

### Removed

- Unused User-Agent header and version detection dependency

## [2.1.1] - 2026-08-10

### Added

- Scrollable content option for smaller desktop widgets (with scrollbar)

### Changed

- Desktop widget uses Plasma's native background at 100% opacity (thanks @Hody, PR #16)
- Custom background border and matching margins when opacity < 100%
- Opacity slider shows "Theme" label at 100%
- Card ordering moved to settings dialog

### Fixed

- Desktop card visibility fix

## [2.1.0] - 2026-07-15

### Added

- V2 UI redesign — card-based popup with configurable card order
- Ring panel style (default) with anti-aliased UsageRing component
- Time-proportional color warnings with configurable toggle (vs fixed thresholds)
- Bar style time-marker line showing elapsed period
- Desktop notifications for usage thresholds and quota resets
- Update checker with orange indicator dot on panel icon
- Process-dependent visibility (hide when Claude not running)
- Per-model dynamic breakdown from API limits array
- Extra usage (paid overage) tracking
- 7-day trend chart, token stats, IDE installations detection
- Account email and plan tier from credentials
- Quick links card with customizable buttons

### Changed

- Separated panel code into CompactView.qml
- Bar style text outline for readability

### Removed

- Circular style (replaced by Ring)

## [1.3.6] - 2026-06-20

### Added

- Vertical layout option for taller panels (thanks @nahall, issue #5)
- Panel metrics can now be stacked vertically to save horizontal space

## [1.3.5] - 2026-06-15

### Added

- Widget picker now shows proper preview image (progress ring + Claude logo + USAGE)
- About page shows correct icon via auto-install to system icon theme
- New `contents/screenshot.png` for KPackage widget picker preview

## [1.3.2] - 2026-06-10

### Fixed

- Widget icon not showing in panel widget picker dialog

## [1.3.1] - 2026-06-05

### Added

- Configurable background opacity for desktop mode (thanks @Endle)

### Changed

- Background opacity only applies on desktop, panel keeps default Plasma theme
- Default opacity set to 100% for consistent upgrade experience

## [1.3.0] - 2026-05-25

### Added

- Three panel display styles: Text (classic), Circular (ring charts), Bar (vertical bars)
- Claude icon can be hidden in panel
- Tooltip shows all enabled metrics

## [1.2.5] - 2026-05-20

### Added

- Configurable panel metrics: choose Session, Weekly, Sonnet independently
- Sonnet weekly usage can now be displayed in the panel (off by default)

## [1.2.1] - 2026-05-15

### Fixed

- Remove false decimal precision from percentage displays (thanks @robinpie)

## [1.2.0] - 2026-05-10

### Added

- Smart rate limit handling with `retry-after` header support
- Exponential backoff with automatic recovery
- Token watcher: instantly recovers when Claude Code refreshes the token
- Local data cache: shows last known values on restart (up to 24h)
- Stale detection: widget dims when data is outdated
- Rate limit warning in popup and settings for intervals under 5 min

### Changed

- Default refresh interval changed to 5 min to prevent rate limiting

## [1.1.0] - 2026-04-15

### Added

- Custom API base URL and API key support for proxy/gateway users
- 429 rate limit handling with auto-retry
- Token expired state with "Open Claude" button
- Dynamic Claude Code version detection for User-Agent
- All strings translated across 15 languages
- Install script

## [1.0.0] - 2025-12-01

### Added

- Initial release
- Session and weekly usage display
- Per-model breakdown (Sonnet/Opus)
- Configurable refresh interval
- Error handling for login issues

[2.5.3]: https://github.com/izll/plasma-claude-usage/compare/v2.5.2...v2.5.3
[2.5.2]: https://github.com/izll/plasma-claude-usage/compare/v2.5.1...v2.5.2
[2.5.1]: https://github.com/izll/plasma-claude-usage/compare/v2.5.0...v2.5.1
[2.5.0]: https://github.com/izll/plasma-claude-usage/compare/v2.4.2...v2.5.0
[2.4.2]: https://github.com/izll/plasma-claude-usage/compare/v2.4.1...v2.4.2
[2.4.1]: https://github.com/izll/plasma-claude-usage/compare/v2.4.0...v2.4.1
[2.4.0]: https://github.com/izll/plasma-claude-usage/compare/v2.3.5...v2.4.0
[2.3.6]: https://github.com/izll/plasma-claude-usage/pull/22
[2.3.5]: https://github.com/izll/plasma-claude-usage/compare/v2.3.4...v2.3.5
[2.3.4]: https://github.com/izll/plasma-claude-usage/compare/v2.3.3...v2.3.4
[2.3.3]: https://github.com/izll/plasma-claude-usage/compare/v2.3.2...v2.3.3
[2.3.2]: https://github.com/izll/plasma-claude-usage/compare/v2.3.1...v2.3.2
[2.3.1]: https://github.com/izll/plasma-claude-usage/compare/v2.3.0...v2.3.1
[2.3.0]: https://github.com/izll/plasma-claude-usage/compare/v2.2.1...v2.3.0
[2.2.1]: https://github.com/izll/plasma-claude-usage/compare/v2.2.0...v2.2.1
[2.2.0]: https://github.com/izll/plasma-claude-usage/compare/v2.1.1...v2.2.0
[2.1.1]: https://github.com/izll/plasma-claude-usage/compare/v2.1.0...v2.1.1
[2.1.0]: https://github.com/izll/plasma-claude-usage/compare/v1.3.6...v2.1.0
[1.3.6]: https://github.com/izll/plasma-claude-usage/compare/v1.3.5...v1.3.6
[1.3.5]: https://github.com/izll/plasma-claude-usage/compare/v1.3.2...v1.3.5
[1.3.2]: https://github.com/izll/plasma-claude-usage/compare/v1.3.1...v1.3.2
[1.3.1]: https://github.com/izll/plasma-claude-usage/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/izll/plasma-claude-usage/compare/v1.2.5...v1.3.0
[1.2.5]: https://github.com/izll/plasma-claude-usage/compare/v1.2.1...v1.2.5
[1.2.1]: https://github.com/izll/plasma-claude-usage/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/izll/plasma-claude-usage/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/izll/plasma-claude-usage/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/izll/plasma-claude-usage/releases/tag/v1.0.0
