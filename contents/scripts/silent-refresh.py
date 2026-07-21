#!/usr/bin/env python3
"""
Silently opens the `claude` CLI attached to a real pseudo-terminal, gives it
enough time to load its interactive session (which refreshes the OAuth
session token as a side effect), then terminates it -- without ever sending
an actual chat message, so it costs no usage.

A real pty is required: piping/closing stdin makes `claude` fall back to
non-interactive --print mode, which exits immediately without touching
credentials at all.
"""
import os
import pty
import select
import signal
import sys
import time


def read_available(fd, duration):
    start = time.time()
    while time.time() - start < duration:
        ready, _, _ = select.select([fd], [], [], 0.3)
        if fd in ready:
            try:
                chunk = os.read(fd, 4096)
                if not chunk:
                    break
            except OSError:
                break


def main():
    env = os.environ.copy()
    env.pop("CLAUDECODE", None)

    try:
        pid, fd = pty.fork()
    except OSError:
        sys.exit(1)

    if pid == 0:
        try:
            os.execvpe("claude", ["claude"], env)
        except FileNotFoundError:
            os._exit(127)
        os._exit(127)

    # Parent: wait for the initial screen, send Enter to dismiss any
    # welcome/trust prompt, then wait for the session to settle.
    read_available(fd, 3)
    try:
        os.write(fd, b"\r")
    except OSError:
        pass
    read_available(fd, 10)

    try:
        os.kill(pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    time.sleep(1)
    try:
        os.kill(pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    try:
        os.waitpid(pid, 0)
    except ChildProcessError:
        pass


if __name__ == "__main__":
    main()
