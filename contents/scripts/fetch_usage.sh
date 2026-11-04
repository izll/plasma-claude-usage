#!/bin/sh
# Fetch Claude usage with a fresh curl process each poll.
# plasmashell's in-process QML network stack (XMLHttpRequest) goes stale
# after suspend/resume and every request dies with status 0; a subprocess
# never inherits that state.
#
# Usage: fetch_usage.sh [credentials-file]
# Falls back to $CLAUDE_CONFIG_DIR/.credentials.json, then ~/.claude, so the
# script still works when run by hand with no argument.
#
# Optional: CLAUDE_USAGE_PROXY (the widget's "Proxy" setting, e.g.
# socks5h://127.0.0.1:1080). Without it curl still honours HTTPS_PROXY and
# ALL_PROXY from the environment.
#
# Output: response body, then a final line "<http_code> <retry_after>".
# Prints "NOCREDS" if no access token is available.

CREDS="${1:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.credentials.json}"

# The credentials file also holds an mcpOAuth section, and every MCP server
# entry there carries its own "accessToken". Scope the match to the
# claudeAiOauth object so an MCP token is never picked up instead.
JSON=$(tr -d '\n\r' < "$CREDS" 2>/dev/null)

strip_key() {
    sed 's/.*"accessToken"[[:space:]]*:[[:space:]]*"//;s/"$//'
}

TOKEN=$(printf '%s' "$JSON" \
    | grep -o '"claudeAiOauth"[[:space:]]*:[[:space:]]*{[^{}]*}' \
    | grep -o '"accessToken"[[:space:]]*:[[:space:]]*"[^"]*"' \
    | head -n 1 | strip_key)

# Fallback for a claudeAiOauth object we could not isolate (nested objects):
# match on the OAuth token prefix, which MCP tokens do not use.
if [ -z "$TOKEN" ]; then
    TOKEN=$(printf '%s' "$JSON" \
        | grep -o '"accessToken"[[:space:]]*:[[:space:]]*"sk-ant-[^"]*"' \
        | head -n 1 | strip_key)
fi

# A token is a single opaque word. Anything else means extraction went wrong,
# and passing it on would inject extra lines into the curl header block.
case "$TOKEN" in
    "" | *[!A-Za-z0-9_.=-]*)
        echo "NOCREDS"
        exit 0
        ;;
esac

# Token passed via stdin (-H @-) so it never appears in process arguments.
printf 'Authorization: Bearer %s\n' "$TOKEN" | curl -sS \
    --max-time 15 \
    -H @- \
    -H "anthropic-beta: oauth-2025-04-20" \
    -H "Content-Type: application/json" \
    -w '\n%{http_code} %header{retry-after}' \
    ${CLAUDE_USAGE_PROXY:+--proxy "$CLAUDE_USAGE_PROXY"} \
    "https://api.anthropic.com/api/oauth/usage" 2>/dev/null
