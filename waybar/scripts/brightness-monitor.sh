#!/usr/bin/env bash
# Brightness Monitor - Dunst Notification Daemon
# Usage: ./brightness-monitor.sh &

POLL_INTERVAL=0.5
STATE_FILE="/tmp/brightness-monitor-state-$USER"

# Find backlight device
BACKLIGHT_PATH=$(find /sys/class/backlight/ -maxdepth 1 -type l 2>/dev/null | head -n 1)

if [[ -z "$BACKLIGHT_PATH" ]]; then
    dunstify -u critical -i display-brightness \
        "Brightness Monitor" "No backlight device found!" -t 5000
    exit 1
fi

notify_brightness() {
    local percent="$1"
    local icon="display-brightness"
    
    if [[ $percent -eq 0 ]]; then
        icon="display-brightness-off"
    elif [[ $percent -le 25 ]]; then
        icon="display-brightness-low"
    elif [[ $percent -le 75 ]]; then
        icon="display-brightness-medium"
    else
        icon="display-brightness-high"
    fi
    
    dunstify -a "brightness" -u low -i "$icon" \
        "☀️ Brightness" "${percent}%" -t 2000 -h int:value:$percent -h string:synchronous:brightness
}

get_brightness_percent() {
    if [[ -f "$BACKLIGHT_PATH/brightness" ]] && [[ -f "$BACKLIGHT_PATH/max_brightness" ]]; then
        local current=$(cat "$BACKLIGHT_PATH/brightness" 2>/dev/null || echo "0")
        local max=$(cat "$BACKLIGHT_PATH/max_brightness" 2>/dev/null || echo "1")
        
        if [[ $max -gt 0 ]]; then
            echo $((current * 100 / max))
        else
            echo "0"
        fi
    else
        echo "0"
    fi
}

cleanup() {
    rm -f "$STATE_FILE"
    dunstify -a "brightness" -u low -i process-stop \
        "Brightness Monitor" "Stopped" -t 2000
    exit 0
}

# Handle termination signals
trap cleanup SIGINT SIGTERM

# Check if already running
if [[ -f "$STATE_FILE" ]]; then
    OLD_PID=$(cat "$STATE_FILE" 2>/dev/null)
    if [[ -n "$OLD_PID" ]] && ps -p "$OLD_PID" >/dev/null 2>&1; then
        echo "Brightness monitor already running (PID: $OLD_PID)"
        exit 0
    fi
fi

# Save current PID
echo $$ > "$STATE_FILE"

# Initialize
PREV_BRIGHTNESS=$(get_brightness_percent)

dunstify -a "brightness" -u low -i display-brightness \
    "Brightness Monitor" "Started: ${PREV_BRIGHTNESS}%" -t 2000

# Main monitoring loop
while true; do
    CURRENT_BRIGHTNESS=$(get_brightness_percent)
    
    # Notify on brightness change
    if [[ "$CURRENT_BRIGHTNESS" != "$PREV_BRIGHTNESS" ]]; then
        notify_brightness "$CURRENT_BRIGHTNESS"
        PREV_BRIGHTNESS="$CURRENT_BRIGHTNESS"
    fi
    
    sleep $POLL_INTERVAL
done
