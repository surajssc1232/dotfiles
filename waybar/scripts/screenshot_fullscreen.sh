#!/usr/bin/env bash
# screenshot-fullscreen.sh

TMP_FILE=$(mktemp --suffix=.png)
if grim "$TMP_FILE"; then
    wl-copy < "$TMP_FILE"
    rm "$TMP_FILE"
    dunstify -u normal -i screenshot "Screenshot" "Fullscreen captured and copied to clipboard"
else
    rm -f "$TMP_FILE"
    dunstify -u critical -i error "Screenshot Failed" "Could not capture screen"
fi
