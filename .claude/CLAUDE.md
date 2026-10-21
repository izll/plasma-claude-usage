# Claude Usage Widget - Development Guide

## Project Overview

This is a KDE Plasma 6 widget that displays Claude Code usage statistics (session and weekly limits) in the taskbar.

## Architecture

The widget is **pure QML** with no external dependencies:

1. **Credentials reading**: Uses `Plasma5Support.DataSource` with "executable" engine to `cat` the credentials file. Never hardcode that path — build it with the helpers in `main.qml` (`credentialsFileExpr()`, `claudeDirExpr()`, `claudeDirEnvPrefix()`, `readCredentialsCmd()`, `readAccountCmd()`), which resolve the `credentialsPath` setting and fall back to `${CLAUDE_CONFIG_DIR:-$HOME/.claude}`. User-supplied paths must go through `shQuotePath()`.
2. **API calls**: Uses QML's built-in `XMLHttpRequest` to call Anthropic's OAuth usage API
3. **UI**: Standard Plasma/Kirigami components

## Key Files

- `contents/ui/main.qml` - All widget logic and UI
- `contents/icons/claude.svg` - Claude logo (orange #D97757)
- `metadata.json` - Plasma widget metadata
- `install.sh` - Installation script

## API Endpoint

```
GET https://api.anthropic.com/api/oauth/usage
Headers:
  Authorization: Bearer <oauth-token>
  Content-Type: application/json
  anthropic-beta: oauth-2025-04-20
```

The `anthropic-beta: oauth-2025-04-20` header is **required** - without it the API returns 401.

## Response Structure

```json
{
  "five_hour": {
    "utilization": 14.0,
    "resets_at": "2025-11-29T19:00:00+00:00"
  },
  "seven_day": {
    "utilization": 89.0,
    "resets_at": "2025-12-01T19:00:00+00:00"
  },
  "seven_day_sonnet": {
    "utilization": 31.0,
    "resets_at": "..."
  },
  "seven_day_opus": null
}
```

## Credentials Location

Claude Code stores OAuth credentials in `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.credentials.json`. The `credentialsPath` setting overrides this: a value ending in `.json` is the file, anything else is the config folder. The resolved folder also drives the account file, the `projects/` token-stats scan, and the `CLAUDE_CONFIG_DIR` handed to the `claude` process the widget launches.

Note the asymmetry in Claude Code's own layout: by default `.claude.json` (account info) is a **sibling** of the config folder (`~/.claude.json`), but with `CLAUDE_CONFIG_DIR` set it lives **inside** it — `readAccountCmd()` tries the folder first and falls back to `$HOME`.

The file looks like:

```json
{
  "claudeAiOauth": {
    "accessToken": "sk-ant-oat01-...",
    "refreshToken": "sk-ant-ort01-...",
    "expiresAt": 1764462495036,
    "subscriptionType": "max",
    "rateLimitTier": "default_claude_max_20x"
  }
}
```

### Claude Desktop fallback

Without a Claude Code login the widget falls back to Claude Desktop's cached login. `contents/scripts/desktop_creds.sh` reads `oauth:tokenCacheV2` (legacy `oauth:tokenCache`) from `${CLAUDE_DESKTOP_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/Claude}/config.json`, decrypts it (Chromium os_crypt on Linux: `v10` = fixed password `peanuts`, `v11` = key from libsecret/KWallet, where Electron names the entry after its product name: `Chromium Keys/Chromium Safe Storage` on Electron 44 + KWallet 6, possibly `Claude Keys/...` elsewhere, so both are tried and the padding check rejects a wrong one; AES-128-CBC, IV of 16 spaces, PBKDF2-HMAC-SHA1 with salt `saltysalt` and 1 iteration) and prints the same JSON shape as `.credentials.json` plus `"source":"desktop"`. That keeps `fileReader`, `tokenWatcher`, `fetch_usage.sh` and the plan logic unchanged; `root.credsSource` records which source was used.

- `readCredentialsCmd()` and `fetch_usage.sh --desktop-fallback` apply the fallback only when no `credentialsPath` is configured, and the CLI file always wins.
- Never use Desktop's refresh token (refresh tokens rotate; using it would sign Desktop out). Never write to Desktop's files.
- Silent refresh runs the `claude` CLI, so it is skipped when `credsSource === "desktop"`; `launchClaude()` starts the Desktop app instead of the CLI.
- Debug with `sh contents/scripts/desktop_creds.sh --diagnose` (prints key names and counts, never token values).

## Plan Tiers

- `default_claude_pro` → "Pro"
- `default_claude_max_5x` → "Max 5x"
- `default_claude_max_20x` → "Max 20x"

## Testing

1. Install: `./install.sh`
2. Restart Plasma: `kquitapp6 plasmashell && kstart plasmashell`
3. Check logs: `journalctl --user -f | grep -i claude`

## Common Issues

- **StandardPaths not working**: Use `$HOME` environment variable instead
- **API returns 401**: Make sure `anthropic-beta` header is included
- **Widget not updating**: Check if credentials file exists and is readable
- **Token stats empty**: `refreshTokenStats()` passes `-newer /tmp/.claude-token-stats-marker` to `find`, but nothing ever creates that marker, so `find` aborts and prints nothing

## Publishing

To publish to KDE Store:
1. Create a `.plasmoid` package: `zip -r claude-usage-widget.plasmoid metadata.json contents/`
2. Upload to https://store.kde.org/
