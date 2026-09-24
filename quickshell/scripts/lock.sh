#!/usr/bin/env sh
# Hands the request to the running Quickshell instance, which raises the
# session lock itself through ext-session-lock-v1. Kept as a script rather than
# inlined into the keybind so the compositor only ever needs to spawn one
# argument-free command.
exec qs ipc call lock lock
