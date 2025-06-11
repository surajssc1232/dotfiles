#!/bin/bash

# Get the current power profile
CURRENT_PROFILE=$(powerprofilesctl get)

# Define icons for each profile (using Font Awesome or similar)
case "$CURRENT_PROFILE" in
    "performance")
        ICON=""
        TEXT="Performance"
        ;;
    "balanced")
        ICON=""
        TEXT="Balanced"
        ;;
    "power-saver")
        ICON=""
        TEXT="Power Saver"
        ;;
    *)
        ICON=""
        TEXT="Unknown"
        ;;
esac

# Handle click events to cycle profiles
if [[ "$1" == "cycle" ]]; then
    case "$CURRENT_PROFILE" in
        "performance")
            powerprofilesctl set balanced
            notify-send -t 1000 "Power Profile" "Switched to Balanced"
            ;;
        "balanced")
            powerprofilesctl set power-saver
            notify-send -t 1000 "Power Profile" "Switched to Power Saver"
            ;;
        "power-saver")
            powerprofilesctl set performance
            notify-send -t 1000 "Power Profile" "Switched to Performance"
            ;;
    esac
    # Re-run the script to update Waybar
    exec "$0"
fi

# Output JSON for Waybar
echo "{\"text\": \"$ICON $TEXT\", \"tooltip\": \"Current Profile: $TEXT\", \"class\": \"$CURRENT_PROFILE\"}"
