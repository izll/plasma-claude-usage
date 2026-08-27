#!/bin/sh
# Silently opens the claude CLI on a real pseudo-terminal to refresh
# the OAuth session token, then exits. No message is sent, no usage
# is consumed. A real pty is required because piping/closing stdin
# makes claude fall back to non-interactive mode and skip token refresh.
#
# Uses `script` from util-linux (present on all Linux systems) to
# provide the pty, avoiding a Python dependency.

timeout 15 script -qc claude /dev/null </dev/null >/dev/null 2>&1
