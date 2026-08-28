# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
