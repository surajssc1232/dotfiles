#!/usr/bin/env sh
# Opens the launcher, or closes it if it is already up, so a single keybind
# both raises and dismisses it. Kept as a script rather than inlined into the
# keybind so the compositor only ever needs to spawn one argument-free command.
exec qs ipc call launcher toggle
