#!/bin/sh
# Fetch Claude usage with a fresh curl process each poll.
# plasmashell's in-process QML network stack (XMLHttpRequest) goes stale
# after suspend/resume and every request dies with status 0; a subprocess
# never inherits that state.
#
# Usage: fetch_usage.sh [credentials-file] [--desktop-fallback]
# Falls back to $CLAUDE_CONFIG_DIR/.credentials.json, then ~/.claude, so the
# script still works when run by hand with no argument.
# With --desktop-fallback, a credentials file without a usable token is
# followed by Claude Desktop's cached login (see desktop_creds.sh), so the
# widget also works when only Claude Desktop is installed.
#
# Output: response body, then a final line "<http_code> <retry_after>".
# Prints "NOCREDS" if no access token is available.

CREDS="${1:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.credentials.json}"

# The credentials file also holds an mcpOAuth section, and every MCP server
# entry there carries its own "accessToken". Scope the match to the
# claudeAiOauth object so an MCP token is never picked up instead.
strip_key() {
    sed 's/.*"accessToken"[[:space:]]*:[[:space:]]*"//;s/"$//'
}

# Reads credentials JSON (newlines already removed) on stdin, prints the token.
extract_token() {
    JSON=$(cat)
    TOK=$(printf '%s' "$JSON" \
        | grep -o '"claudeAiOauth"[[:space:]]*:[[:space:]]*{[^{}]*}' \
        | grep -o '"accessToken"[[:space:]]*:[[:space:]]*"[^"]*"' \
        | head -n 1 | strip_key)

    # Fallback for a claudeAiOauth object we could not isolate (nested objects):
    # match on the OAuth token prefix, which MCP tokens do not use.
    if [ -z "$TOK" ]; then
        TOK=$(printf '%s' "$JSON" \
            | grep -o '"accessToken"[[:space:]]*:[[:space:]]*"sk-ant-[^"]*"' \
            | head -n 1 | strip_key)
    fi
    printf '%s' "$TOK"
}

TOKEN=$(tr -d '\n\r' 2>/dev/null < "$CREDS" | extract_token)

# No Claude Code login: try Claude Desktop's cached login. The helper prints
# the same JSON shape as the credentials file.
if [ -z "$TOKEN" ] && [ "$2" = "--desktop-fallback" ]; then
    TOKEN=$(sh "$(dirname "$0")/desktop_creds.sh" 2>/dev/null | tr -d '\n\r' | extract_token)
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
    "https://api.anthropic.com/api/oauth/usage" 2>/dev/null
