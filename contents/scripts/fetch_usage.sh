#!/bin/sh
# Fetch Claude usage with a fresh curl process each poll.
# plasmashell's in-process QML network stack (XMLHttpRequest) goes stale
# after suspend/resume and every request dies with status 0; a subprocess
# never inherits that state.
#
# Output: response body, then a final line "<http_code> <retry_after>".
# Prints "NOCREDS" if no access token is available.

CREDS="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.credentials.json"

TOKEN=$(grep -o '"accessToken"[[:space:]]*:[[:space:]]*"[^"]*"' "$CREDS" 2>/dev/null | sed 's/.*"accessToken"[[:space:]]*:[[:space:]]*"//;s/"$//')
if [ -z "$TOKEN" ]; then
    echo "NOCREDS"
    exit 0
fi

# Token passed via stdin (-H @-) so it never appears in process arguments.
printf 'Authorization: Bearer %s\n' "$TOKEN" | curl -sS \
    --max-time 15 \
    -H @- \
    -H "anthropic-beta: oauth-2025-04-20" \
    -H "Content-Type: application/json" \
    -w '\n%{http_code} %header{retry-after}' \
    "https://api.anthropic.com/api/oauth/usage" 2>/dev/null
