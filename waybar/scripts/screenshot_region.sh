#!/usr/bin/env bash
# screenshot-region.sh
sleep 0.1  # Small delay
TMP_FILE=$(mktemp --suffix=.png)
if grim -g "$(slurp)" "$TMP_FILE"; then
    wl-copy < "$TMP_FILE"
    rm "$TMP_FILE"
    dunstify -u normal -i screenshot "Screenshot" "Region captured and copied to clipboard"
else
    rm -f "$TMP_FILE"
    dunstify -u critical -i error "Screenshot Failed" "Could not capture region"
fi
