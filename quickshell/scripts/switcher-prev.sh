#!/usr/bin/env sh
f="${XDG_RUNTIME_DIR:-/tmp}/quickshell-switcher"
[ -p "$f" ] || exit 0
echo prev 1<>"$f"
