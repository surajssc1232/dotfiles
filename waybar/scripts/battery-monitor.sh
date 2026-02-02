#!/usr/bin/env bash

# Battery Monitor - Dunst Notification Daemon
# Usage: ./battery-monitor.sh &

POLL_INTERVAL=2
STATE_FILE="/tmp/battery-monitor-state-$USER"

# Find battery (handles multiple batteries)
BATTERY_PATH=$(find /sys/class/power_supply/ -name "BAT*" 2>/dev/null | head -n 1)

if [[ -z "$BATTERY_PATH" ]]; then
    dunstify -u critical -i battery-missing "Power Monitor" "No battery found!" -t 5000
    exit 1
fi

notify_power() {
    local status="$1"
    local percent="$2"
    
    case "$status" in
        "Charging")
            dunstify -a "battery-monitor" -u normal -i battery-full-charging \
                "🔌 Power Connected" "Charging at ${percent}%" -t 3000
            ;;
        "Not charging")
            dunstify -a "battery-monitor" -u low -i battery-full-charging \
                "⚡ Plugged In" "Not charging (${percent}%)" -t 3000
            ;;
        "Discharging")
            if [[ $percent -le 20 ]]; then
                dunstify -a "battery-monitor" -u critical -i battery-caution \
                    "🔋 Low Battery!" "${percent}% remaining" -t 0
            elif [[ $percent -le 50 ]]; then
                dunstify -a "battery-monitor" -u normal -i battery-low \
                    "🔋 On Battery" "${percent}% remaining" -t 3000
            else
                dunstify -a "battery-monitor" -u low -i battery-good \
                    "🔋 On Battery" "${percent}% remaining" -t 3000
            fi
            ;;
        "Full")
            dunstify -a "battery-monitor" -u low -i battery-full-charged \
                "✓ Fully Charged" "Battery at 100%" -t 3000
            ;;
        *)
            dunstify -a "battery-monitor" -u low -i battery \
                "Battery Status" "$status at ${percent}%" -t 3000
            ;;
    esac
}

get_status() {
    if [[ -f "$BATTERY_PATH/status" ]]; then
        cat "$BATTERY_PATH/status" 2>/dev/null | tr -d '[:space:]'
    else
        echo "UNKNOWN"
    fi
}

get_percentage() {
    if [[ -f "$BATTERY_PATH/capacity" ]]; then
        cat "$BATTERY_PATH/capacity" 2>/dev/null | tr -d '[:space:]'
    else
        echo "0"
    fi
}

cleanup() {
    rm -f "$STATE_FILE"
    dunstify -a "battery-monitor" -u low -i process-stop \
        "Power Monitor" "Stopped" -t 2000
    exit 0
}

# Handle termination signals
trap cleanup SIGINT SIGTERM

# Check if already running
if [[ -f "$STATE_FILE" ]]; then
    OLD_PID=$(cat "$STATE_FILE" 2>/dev/null)
    if [[ -n "$OLD_PID" ]] && ps -p "$OLD_PID" >/dev/null 2>&1; then
        echo "Battery monitor already running (PID: $OLD_PID)"
        exit 0
    fi
fi

# Save current PID
echo $$ > "$STATE_FILE"

# Initialize
PREV_STATUS=$(get_status)
PREV_PCT=$(get_percentage)

dunstify -a "battery-monitor" -u low -i battery \
    "Power Monitor" "Started: $PREV_STATUS ($PREV_PCT%)" -t 2000

# Main monitoring loop
while true; do
    CURRENT_STATUS=$(get_status)
    CURRENT_PCT=$(get_percentage)
    
    # Notify on status change
    if [[ "$CURRENT_STATUS" != "$PREV_STATUS" ]]; then
        notify_power "$CURRENT_STATUS" "$CURRENT_PCT"
        PREV_STATUS="$CURRENT_STATUS"
    fi
    
    # Also notify if battery gets critically low
    if [[ "$CURRENT_STATUS" == "Discharging" ]]; then
        if [[ $CURRENT_PCT -le 10 && $PREV_PCT -gt 10 ]]; then
            dunstify -a "battery-monitor" -u critical -i battery-empty \
                "⚠️  CRITICAL BATTERY" "Only ${CURRENT_PCT}% remaining!" -t 0
        elif [[ $CURRENT_PCT -le 20 && $PREV_PCT -gt 20 ]]; then
            dunstify -a "battery-monitor" -u critical -i battery-caution \
                "⚠️  Low Battery Warning" "${CURRENT_PCT}% remaining" -t 0
        fi
    fi
    
    PREV_PCT=$CURRENT_PCT
    
    sleep $POLL_INTERVAL
done
