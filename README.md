# Claude Usage Widget

A KDE Plasma 6 widget that displays your Claude Code usage statistics in the taskbar.

![Popup](screenshots/popup.png)

## Features

- **Compact Panel Display**: Shows session and weekly usage percentages right in your taskbar
  ![Panel](screenshots/panel.png)
- **Color-coded Indicators**: Green (<50%), Yellow (<80%), Red (≥80%)
- **Detailed Popup**: Click to see full statistics
  - Session and weekly usage with progress bars
  - Reset times for both limits
  - Per-model breakdown (Sonnet/Opus)
  - Your subscription plan badge
- **Configurable Refresh**: Default 5 min polling (adjustable in settings)
- **Smart Rate Limit Handling**: Uses `retry-after` header, exponential backoff, and token watcher for automatic recovery
- **Local Cache**: Remembers last data on restart (up to 24h)
- **Stale Detection**: Widget dims when data is outdated
- **Error Handling**: Clear messages when not logged in, token expired, or rate limited
- **Custom API Support**: Optional proxy/gateway with custom base URL and API key
- **15 Languages**: EN, HU, DE, FR, ES, IT, PT, RU, PL, NL, TR, JA, KO, ZH-CN, ZH-TW
- **No Dependencies**: Pure QML, no Python or external tools required

## Requirements

- KDE Plasma 6.0 or later
- Claude Code CLI installed and logged in

## Installation

### From KDE Store

1. Right-click on your panel
2. Select "Add Widgets..."
3. Click "Get New Widgets..." > "Download New Plasma Widgets..."
4. Search for "Claude Usage"
5. Click Install

### Manual Installation

```bash
kpackagetool6 -t Plasma/Applet -i claude-usage-widget.plasmoid
```

### From Source

```bash
git clone https://github.com/izll/plasma-claude-usage.git
cd claude-usage-widget
kpackagetool6 -t Plasma/Applet -i .
```

## Usage

1. Make sure you're logged in to Claude Code (run `claude` in terminal)
2. Add the widget to your panel
3. Click the widget to see detailed usage statistics

## Configuration

Right-click the widget and select **Configure...** to open the settings.

### Custom API Base URL (optional)

By default the widget reads your OAuth credentials from `~/.claude/.credentials.json` and calls `https://api.anthropic.com` directly — no configuration needed.

If you use a custom API proxy or gateway, you can override this:

| Setting | Description |
|---|---|
| **Base URL** | Your proxy URL, e.g. `https://your-proxy.example.com` |
| **API key** | Your `ANTHROPIC_API_KEY` |

> **Note:** The widget calls `/api/oauth/usage`, not the standard `/v1/messages` endpoint. Use the root URL without any path suffix — e.g. `https://api.anthropic.com`, not `https://api.anthropic.com/v1`.

When a base URL is configured, the widget authenticates with `x-api-key` instead of the OAuth token. Leave the Base URL field empty to go back to the default credentials file method.

## How It Works

The widget calls the Anthropic usage API directly from QML. No data is stored or sent anywhere else.

### API Endpoint

```
GET https://api.anthropic.com/api/oauth/usage
Headers:
  Authorization: Bearer <oauth-token>   (default mode)
  x-api-key: <api-key>                  (custom base URL mode)
  anthropic-beta: oauth-2025-04-20
```

## Troubleshooting

### "Not logged in" error

Make sure you're logged in to Claude Code:
```bash
claude
```

### "Token expired" error

Your OAuth token has expired. Run Claude Code again to refresh it:
```bash
claude
```
The widget also has an "Open Claude" button for this.

### "Rate limited" error

The API allows ~4 requests per 5-minute window. The widget handles this automatically:
- Reads the `retry-after` header and waits the specified time
- Falls back to exponential backoff (5/10/15 min)
- Monitors for token refresh and recovers instantly

To avoid rate limiting, keep the refresh interval at 5 minutes or higher.

### "Invalid API key" error

The API key in the widget settings is wrong or revoked. Open **Configure...** and update it.

### "Endpoint not found — check base URL" error

The base URL in the widget settings doesn't point to a valid API. Make sure you're using the root URL without `/v1`, e.g. `https://api.anthropic.com`.

### Widget shows 0%

- Click the refresh button in the popup
- Check logs: `journalctl --user -f | grep -i claude`

## File Structure

```
claude-usage-widget/
├── metadata.json           # Widget metadata
├── install.sh              # Installation script
├── contents/
│   ├── config/
│   │   └── main.xml        # Configuration schema
│   ├── ui/
│   │   ├── main.qml        # Widget implementation
│   │   ├── configGeneral.qml # Settings UI
│   │   └── Translations.qml # i18n (15 languages)
│   └── icons/
│       └── claude.svg      # Claude logo (orange)
└── screenshots/            # Preview images
```

## License

GPL-3.0-or-later

## Author

izll

## Version History

### 1.2.5 (2026)
- Configurable panel display: choose which metrics to show (Session, Weekly, Sonnet)
- Sonnet weekly usage can now be displayed in the panel (off by default)

### 1.2.1 (2026)
- Remove false decimal precision from percentage displays (thanks @robinpie)

### 1.2.0 (2026)
- Smart rate limit handling with `retry-after` header support
- Exponential backoff with automatic recovery
- Token watcher: instantly recovers when Claude Code refreshes the token
- Local data cache: shows last known values on restart (up to 24h)
- Stale detection: widget dims when data is outdated
- Default refresh interval changed to 5 min to prevent rate limiting
- Rate limit warning in popup and settings for intervals under 5 min

### 1.1.0 (2026)
- Custom API base URL and API key support for proxy/gateway users
- 429 rate limit handling with auto-retry
- Token expired state with "Open Claude" button
- Dynamic Claude Code version detection for User-Agent
- All strings translated across 15 languages
- Install script added

### 1.0.0 (2025)
- Initial release
- Session and weekly usage display
- Per-model breakdown (Sonnet/Opus)
- Configurable refresh interval
- Error handling for login issues
