#!/usr/bin/env sh
# Opens the clipboard history panel, or closes it if it is already up, so one
# keybind does both. Kept as a script so the compositor only ever has to spawn
# a single argument-free command.
exec qs ipc call clipboard toggle
