#!/usr/bin/env sh
# One word down a pipe the shell already has open — no process to start beyond
# this one, so the switcher is up in a few milliseconds rather than fifty.
f="${XDG_RUNTIME_DIR:-/tmp}/quickshell-switcher"
[ -p "$f" ] || exit 0
# Opened read-write so it never blocks if the shell is not running.
echo next 1<>"$f"
