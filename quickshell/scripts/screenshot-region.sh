#!/usr/bin/env sh
# Hands the request to the running Quickshell instance, which does the capture
# itself through wlr-screencopy. Kept as a script rather than inlined into the
# keybind so the compositor only ever needs to spawn one argument-free command.
exec qs ipc call screenshot region
