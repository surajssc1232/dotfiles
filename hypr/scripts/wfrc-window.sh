#!/usr/bin/env bash
echo "recording=1" > /tmp/waybar_recording_active
pkill -SIGUSR1 waybar
XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$UID}"
WFRC_FOLDER="$XDG_RUNTIME_DIR/wfrc"
SCRIPT_NAME="wfrc-window"
WFRC_ICON="camera-web"
mkdir -p "$WFRC_FOLDER"

# Check Wayland
if [ -z "$WAYLAND_DISPLAY" ]; then
    echo "Error: Not running under Wayland." >&2
    notify-send --app-name="$SCRIPT_NAME" "Error" "Not running under Wayland" --icon="$WFRC_ICON"
    exit 1
fi

# Configurable options
WFRC_AUDIO_DEV="$(LANG=C pactl list sources | grep 'Name.*output' | cut -d ' ' -f2)"
WFRC_FILE_NAME="$WFRC_FOLDER/${SCRIPT_NAME}-$(date +%Y-%m-%dT%H:%M:%S).mp4"

# Single instance check
WFRC_LOCK="$WFRC_FOLDER/WFRCLOCK"
if [ -f "$WFRC_LOCK" ]; then
    kill $(cat "$WFRC_LOCK") &>/dev/null || true
    rm -f "$WFRC_LOCK"
fi
echo $$ > "$WFRC_LOCK"

kill_wfrc() {
    kill -TERM $wf_recorder_pid 2>/dev/null
    rm -f "$WFRC_LOCK"
    echo -n "file://$WFRC_FILE_NAME" | wl-copy -t 'text/uri-list'
    SIZE=$(ls -lh "$WFRC_FILE_NAME" | awk '{print $5}')
    ENDTIME=$(date +%s)
    duration=$((ENDTIME - STARTTIME))
    minutes=$((duration / 60))
    seconds=$((duration % 60))
    formatted_duration="${minutes}m ${seconds}s"
    [[ $minutes -eq 0 ]] && formatted_duration="${seconds}s"
    notify-send -t 5000 --app-name="$SCRIPT_NAME" "Recording Finished" \
        "$formatted_duration | $SIZE" --icon="$WFRC_ICON"
    exit
}

trap 'kill_wfrc' SIGINT SIGTERM

# Get visible windows as bounding boxes
clients=$(hyprctl -j clients)
boxes=$(echo "$clients" | jq -r '.[] | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')

# Use slurp to select one
output=$(echo "$boxes" | slurp -r)
result=$?
if [ $result -ne 0 ]; then
    rm -f "$WFRC_LOCK"
    notify-send --app-name="$SCRIPT_NAME" "Selection canceled." --icon="$WFRC_ICON"
    exit 1
fi

notify-send -t 1000 --app-name="$SCRIPT_NAME" "Recording selected window..." --icon="$WFRC_ICON"

wf-recorder -f "$WFRC_FILE_NAME" -g "$output" --audio="$WFRC_AUDIO_DEV" &
wf_recorder_pid=$!
wait $wf_recorder_pid
rm -f /tmp/waybar_recording_active
pkill -SIGUSR1 waybar
