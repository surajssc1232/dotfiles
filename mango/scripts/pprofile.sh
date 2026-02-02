#!/usr/bin/env bash

# NixOS-compatible power profile script for Waybar

# Get the current power profile
CURRENT_PROFILE=$(powerprofilesctl get 2>/dev/null)

# If powerprofilesctl fails, show error
if [[ -z "$CURRENT_PROFILE" ]]; then
    echo "{\"text\": \" Unknown\", \"tooltip\": \"power-profiles-daemon not running\", \"class\": \"error\"}"
    exit 0
fi

# Define icons for each profile
case "$CURRENT_PROFILE" in
    "performance")
        ICON=""
        TEXT="Performance"
        ;;
    "balanced")
        ICON=""
        TEXT="Balanced"
        ;;
    "power-saver")
        ICON=""
        TEXT="Power Saver"
        ;;
    *)
        ICON=""
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
