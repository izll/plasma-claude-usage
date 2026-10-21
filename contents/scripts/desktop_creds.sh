#!/bin/sh
# Read-only reader for the OAuth login cached by Claude Desktop.
#
# The widget normally reads ~/.claude/.credentials.json, which only exists
# once the Claude Code CLI has been logged in. Claude Desktop keeps its own
# login in <config dir>/config.json under "oauth:tokenCacheV2" (older builds:
# "oauth:tokenCache"), encrypted with Electron's safeStorage. This script
# decrypts that value and prints it in the same shape as the CLI file, so the
# rest of the widget does not need to know where the token came from:
#
#   {"source":"desktop","claudeAiOauth":{"accessToken":"...","expiresAt":<ms>}}
#
# Prints nothing (and exits 0) when there is no usable Desktop login.
#
# It never touches the refresh token and never writes to Desktop's files:
# refresh tokens rotate, so using one here would sign Desktop out. When the
# access token has expired the widget asks the user to open Claude Desktop,
# which refreshes it itself.
#
# Linux only. Needs openssl >= 3.0 (for `openssl kdf`) and, if Desktop keeps
# its key in the system keyring ("v11" values), secret-tool (libsecret) or
# kwallet-query. Without a keyring Desktop falls back to Chromium's fixed
# password ("v10" values), which needs nothing extra.
#
# Usage: desktop_creds.sh [--diagnose]
#   --diagnose  explain on stderr why no token was found. Prints key names
#               and counts only, never token values.
#
# Environment:
#   CLAUDE_DESKTOP_DIR  Claude Desktop config folder
#                       (default: ${XDG_CONFIG_HOME:-$HOME/.config}/Claude)

DIAG=""
[ "$1" = "--diagnose" ] && DIAG=1

log() {
    [ -n "$DIAG" ] && printf 'desktop_creds: %s\n' "$*" >&2
    return 0
}

DIR="${CLAUDE_DESKTOP_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/Claude}"
CFG="$DIR/config.json"
if [ ! -r "$CFG" ]; then
    log "no readable $CFG (Claude Desktop not installed or never signed in)"
    exit 0
fi

CONTENT=$(tr -d '\n\r' < "$CFG" 2>/dev/null)

B64=""
for k in "oauth:tokenCacheV2" "oauth:tokenCache"; do
    B64=$(printf '%s' "$CONTENT" \
        | grep -o "\"$k\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
        | head -n 1 | sed 's/.*:[[:space:]]*"//;s/"$//')
    if [ -n "$B64" ]; then
        log "found $k (${#B64} base64 chars)"
        break
    fi
done
if [ -z "$B64" ]; then
    log "config.json has no oauth:tokenCache(V2) entry; keys present:"
    [ -n "$DIAG" ] && printf '%s' "$CONTENT" | grep -o '"[A-Za-z0-9_:.-]*"[[:space:]]*:' \
        | sort -u | sed 's/^/    /' >&2
    exit 0
fi

TMPD=$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/claude-usage-desktop.XXXXXX" 2>/dev/null) || {
    log "cannot create a temporary directory"
    exit 0
}
trap 'rm -rf "$TMPD"' EXIT

# Electron safeStorage on Linux prefixes the ciphertext with "v10" (fixed
# Chromium password, no keyring available) or "v11" (password from keyring).
PREFIX=$(printf '%s' "$B64" | base64 -d 2>/dev/null | head -c 3)
printf '%s' "$B64" | base64 -d 2>/dev/null | tail -c +4 > "$TMPD/ct"
CTLEN=$(wc -c < "$TMPD/ct" | tr -d ' ')
log "ciphertext prefix '$PREFIX', $CTLEN bytes after it (multiple of 16: $([ $((CTLEN % 16)) -eq 0 ] && echo yes || echo NO))"

hexof() { printf '%s' "$1" | od -An -tx1 | tr -d ' \n'; }

# try_key <hex password> <label>
# Chromium os_crypt (Linux): AES-128-CBC, IV = 16 spaces, key = PBKDF2-HMAC-SHA1
# (password, salt "saltysalt", 1 iteration, 16 bytes). A wrong key almost
# always fails the PKCS#7 padding check; the rare chance pass is caught by
# requiring the result to be (almost) all printable text. On success the
# plaintext is left in $PLAIN.
try_key() {
    _k=$(openssl kdf -keylen 16 -kdfopt digest:SHA1 -kdfopt hexpass:"$1" \
            -kdfopt salt:saltysalt -kdfopt iter:1 PBKDF2 2>/dev/null | tr -d ':\n ')
    if [ -z "$_k" ]; then
        log "$2: openssl kdf failed (openssl >= 3.0 required)"
        return 1
    fi
    _p=$(openssl enc -d -aes-128-cbc -K "$_k" -iv 20202020202020202020202020202020 \
            -in "$TMPD/ct" 2>"$TMPD/err")
    if [ $? -ne 0 ]; then
        log "$2: wrong key (bad padding)"
        return 1
    fi
    _len=${#_p}
    _np=$(printf '%s' "$_p" | tr -d '[:print:]\n\r\t' | wc -c | tr -d ' ')
    if [ "$_len" -eq 0 ] || [ $((_np * 10)) -gt "$_len" ]; then
        log "$2: padding ok but the result is not text (wrong key)"
        return 1
    fi
    PLAIN=$(printf '%s' "$_p" | tr -d '\n\r')
    log "$2: decrypted ${#PLAIN} bytes, padding valid"
    return 0
}

# try_password <password string> <label>: the keyring value as stored, then,
# if it is base64 for something else, the decoded bytes.
try_password() {
    try_key "$(hexof "$1")" "$2 (as stored)" && return 0
    _dec=$(printf '%s' "$1" | base64 -d 2>/dev/null | od -An -tx1 | tr -d ' \n')
    if [ -n "$_dec" ] && [ "$_dec" != "$(hexof "$1")" ]; then
        try_key "$_dec" "$2 (base64-decoded)" && return 0
    fi
    return 1
}

# read_kwallet <folder> <entry>: value in $KEYRING_PW. Only the exit status
# decides success, so an error message on stdout is never mistaken for a key.
read_kwallet() {
    _out=$(timeout 20 kwallet-query -f "$1" -r "$2" kdewallet 2>"$TMPD/kwerr")
    _rc=$?
    log "kwallet-query folder='$1' entry='$2': exit $_rc, ${#_out} chars, $(printf '%s' "$_out" | tr -d 'A-Za-z0-9+/=' | wc -c | tr -d ' ') of them outside [A-Za-z0-9+/=]"
    if [ -n "$DIAG" ]; then
        [ -s "$TMPD/kwerr" ] && log "  stderr: $(head -c 300 "$TMPD/kwerr" | tr '\n' ' ')"
        [ $_rc -ne 0 ] && [ -n "$_out" ] && log "  stdout (not a key, exit status was non-zero): $(printf '%s' "$_out" | head -c 200 | tr '\n' ' ')"
    fi
    [ $_rc -eq 0 ] && [ -n "$_out" ] || return 1
    KEYRING_PW=$_out
}

# Names only, never values: what the keyring offers for Claude.
keyring_diag() {
    if command -v kwallet-query >/dev/null 2>&1; then
        log "kwallet-query: entries in folders 'Chromium Keys' / 'Claude Keys' of wallet 'kdewallet':"
        for _f in "Chromium Keys" "Claude Keys"; do
            timeout 20 kwallet-query -f "$_f" -l kdewallet 2>&1 | head -n 20 | sed 's/^/    /' >&2
        done
    fi
    LOGF="$DIR/logs/main.log"
    if [ -r "$LOGF" ]; then
        log "last log lines mentioning the key store ($LOGF):"
        grep -i -E 'safestorage|safe storage|keyring|kwallet|libsecret|password.store' "$LOGF" 2>/dev/null \
            | tail -n 5 | cut -c1-200 | sed -E 's/[^ ]*@[^ ]*/<email>/g;s/^/    /' >&2
    fi
}

OK=""
case "$PREFIX" in
    v10)
        try_key "$(hexof peanuts)" "v10 fixed Chromium password" && OK=1
        ;;
    v11)
        # A keyring lookup can raise a permission prompt (KWallet). If it
        # failed or was refused recently, don't ask again on every poll.
        MARK="${XDG_RUNTIME_DIR:-/tmp}/claude-usage-desktop-keyring-miss-$(id -u)"
        if [ -z "$DIAG" ] && [ -n "$(find "$MARK" -mmin -30 2>/dev/null)" ] && [ ! "$CFG" -nt "$MARK" ]; then
            exit 0
        fi
        [ -n "$DIAG" ] && keyring_diag
        if command -v secret-tool >/dev/null 2>&1; then
            for app in Claude claude chromium Chromium; do
                KEYRING_PW=$(timeout 10 secret-tool lookup application "$app" 2>/dev/null)
                if [ $? -eq 0 ] && [ -n "$KEYRING_PW" ]; then
                    try_password "$KEYRING_PW" "secret-tool application=$app" && { OK=1; break; }
                else
                    log "secret-tool application=$app: nothing found"
                fi
            done
        else
            log "secret-tool not installed"
        fi
        if [ -z "$OK" ]; then
            if command -v kwallet-query >/dev/null 2>&1; then
                # Electron registers the key under the product name, which is
                # "Chromium" on current Linux builds (seen on Electron 44 /
                # KWallet 6) and may be "Claude" on others. try_password
                # validates the padding, so a wrong entry is simply skipped.
                for name in Chromium Claude; do
                    read_kwallet "$name Keys" "$name Safe Storage" \
                        && try_password "$KEYRING_PW" "kwallet $name Keys/$name Safe Storage" && { OK=1; break; }
                done
            else
                log "kwallet-query not installed"
            fi
        fi
        [ -z "$OK" ] && : > "$MARK" 2>/dev/null
        ;;
    *)
        log "unsupported ciphertext prefix (expected v10 or v11)"
        exit 0
        ;;
esac
[ -n "$OK" ] && rm -f "${XDG_RUNTIME_DIR:-/tmp}/claude-usage-desktop-keyring-miss-$(id -u)" 2>/dev/null
if [ -z "$OK" ]; then
    log "no key decrypts the token cache"
    exit 0
fi

if [ -n "$DIAG" ]; then
    # Shape of the decrypted data with everything secret-looking removed:
    # non-printable bytes become "?", e-mail addresses, UUIDs, "sk-ant-..."
    # tokens and every run of 24+ token-like characters are replaced by
    # placeholders. What is left is punctuation, short key names and numbers.
    log "structure of the decrypted cache (long values, e-mails and UUIDs masked, first 2000 chars):"
    printf '%s' "$PLAIN" | tr -c '[:print:]' '?' \
        | sed -E 's/[^ "?,:{}]*@[^ "?,:{}]*/<email>/g' \
        | sed -E 's/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/<uuid>/g' \
        | sed -E 's/(sk-ant-[a-z]+[0-9]*-)[A-Za-z0-9_-]+/\1<redacted>/g' \
        | sed -E 's#[A-Za-z0-9_+/=.:-]{24,}#<long>#g' \
        | head -c 2000 | sed 's/^/    /' >&2
    printf '\n' >&2
fi

# The decrypted JSON may hold several entries (one per client/scope). Split on
# "}" so every access token ends up in a chunk together with its own expiry,
# then prefer entries carrying the user:profile scope (the usage endpoint
# needs it), and among those the one that expires last.
# Output: "<token> <expiresAt ms> <subscriptionType|empty>".
PICK=$(printf '%s' "$PLAIN" | tr '}' '\n' | awk -v DIAGN="$DIAG" '
{
    if (!match($0, /sk-ant-oat[0-9]*-[A-Za-z0-9_-]+/)) next
    tok = substr($0, RSTART, RLENGTH)
    ex = 0
    if (match($0, /\\?"expir[A-Za-z_]*\\?"[ ]*:[ ]*[0-9]+/)) {
        s = substr($0, RSTART, RLENGTH); sub(/.*:[ ]*/, "", s); ex = s + 0
        if (ex > 0 && ex < 100000000000) ex = ex * 1000
    }
    st = ""
    if (match($0, /\\?"subscriptionType\\?"[ ]*:[ ]*\\?"[A-Za-z_]+\\?"/)) {
        s = substr($0, RSTART, RLENGTH); sub(/.*:[ ]*\\?"/, "", s); sub(/\\?"$/, "", s); st = s
    }
    pref = (index($0, "user:profile") > 0) ? 1 : 0
    n++
    if (!found || pref > bestpref || (pref == bestpref && ex > bestex)) {
        found = 1; bestpref = pref; bestex = ex; btok = tok; bst = st
    }
}
END { if (found) printf "%s %.0f %s\n", btok, bestex, bst; if (DIAGN) print n+0 " access token(s) found" > "/dev/stderr" }
')

TOKEN=${PICK%% *}
REST=${PICK#* }
EXPIRES=${REST%% *}
SUB=${REST#* }
[ "$SUB" = "$REST" ] && SUB=""

# A token is a single opaque word; anything else means extraction went wrong.
case "$TOKEN" in
    "" | *[!A-Za-z0-9_.=-]*)
        log "no access token (sk-ant-oat...) in the decrypted cache"
        exit 0
        ;;
esac
case "$EXPIRES" in
    "" | *[!0-9]*) EXPIRES=0 ;;
esac

SUBJSON=""
case "$SUB" in
    "" | *[!A-Za-z_]*) ;;
    *) SUBJSON=",\"subscriptionType\":\"$SUB\"" ;;
esac

log "ok: access token found, expiresAt=$EXPIRES"
printf '{"source":"desktop","claudeAiOauth":{"accessToken":"%s","expiresAt":%s%s}}\n' \
    "$TOKEN" "$EXPIRES" "$SUBJSON"
