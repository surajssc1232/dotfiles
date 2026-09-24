#!/usr/bin/env sh
# Opens the notification history, or closes it if it is already up. Kept as a
# script rather than inlined into the keybind so the compositor only ever needs
# to spawn one argument-free command.
exec qs ipc call notifs toggle
