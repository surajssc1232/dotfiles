#!/usr/bin/env bash
# Volume Monitor - Dunst Notification Daemon
# Usage: ./volume-monitor.sh &

POLL_INTERVAL=0.5
STATE_FILE="/tmp/volume-monitor-state-$USER"

notify_volume() {
    local volume="$1"
    local muted="$2"
    
    if [[ "$muted" == "yes" ]]; then
        dunstify -a "volume" -u low -i audio-volume-muted \
            "🔇 Volume Muted" "" -t 2000 -h int:value:0 -h string:synchronous:volume
    else
        local icon="audio-volume-high"
        local bar=""
        
        if [[ $volume -eq 0 ]]; then
            icon="audio-volume-muted"
        elif [[ $volume -le 33 ]]; then
            icon="audio-volume-low"
        elif [[ $volume -le 66 ]]; then
            icon="audio-volume-medium"
        fi
        
        dunstify -a "volume" -u low -i "$icon" \
            "🔊 Volume" "${volume}%" -t 2000 -h int:value:$volume -h string:synchronous:volume
    fi
}

get_volume() {
    # Try to get volume from default sink
    if command -v pamixer >/dev/null 2>&1; then
        pamixer --get-volume 2>/dev/null || echo "0"
    elif command -v pactl >/dev/null 2>&1; then
        pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -Po '\d+(?=%)' | head -n 1 || echo "0"
    else
        amixer get Master 2>/dev/null | grep -Po '\d+(?=%)' | head -n 1 || echo "0"
    fi
}

is_muted() {
    if command -v pamixer >/dev/null 2>&1; then
        pamixer --get-mute 2>/dev/null && echo "yes" || echo "no"
    elif command -v pactl >/dev/null 2>&1; then
        local mute=$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | grep -o 'yes\|no')
        echo "${mute:-no}"
    else
        amixer get Master 2>/dev/null | grep -q '\[off\]' && echo "yes" || echo "no"
    fi
}

cleanup() {
    rm -f "$STATE_FILE"
    dunstify -a "volume" -u low -i process-stop \
        "Volume Monitor" "Stopped" -t 2000
    exit 0
}

# Handle termination signals
trap cleanup SIGINT SIGTERM

# Check if already running
if [[ -f "$STATE_FILE" ]]; then
    OLD_PID=$(cat "$STATE_FILE" 2>/dev/null)
    if [[ -n "$OLD_PID" ]] && ps -p "$OLD_PID" >/dev/null 2>&1; then
        echo "Volume monitor already running (PID: $OLD_PID)"
        exit 0
    fi
fi

# Save current PID
echo $$ > "$STATE_FILE"

# Initialize
PREV_VOLUME=$(get_volume)
PREV_MUTED=$(is_muted)

dunstify -a "volume" -u low -i audio-volume-high \
    "Volume Monitor" "Started: ${PREV_VOLUME}%" -t 2000

# Main monitoring loop
while true; do
    CURRENT_VOLUME=$(get_volume)
    CURRENT_MUTED=$(is_muted)
    
    # Notify on volume or mute status change
    if [[ "$CURRENT_VOLUME" != "$PREV_VOLUME" ]] || [[ "$CURRENT_MUTED" != "$PREV_MUTED" ]]; then
        notify_volume "$CURRENT_VOLUME" "$CURRENT_MUTED"
        PREV_VOLUME="$CURRENT_VOLUME"
        PREV_MUTED="$CURRENT_MUTED"
    fi
    
    sleep $POLL_INTERVAL
done
