#!/usr/bin/env sh
# Starts a full-screen recording, or stops the one in progress. The audio
# source follows whatever is chosen in the control centre's Record tile.
exec qs ipc call recorder toggle
