#!/usr/bin/env bash
# v0.2.2 - Rofi UI + Hyprland-specific window capture fix

#!/usr/bin/env bash
# v0.2.3 - Rofi UI + Hyprland-specific window capture fix + audio support

XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$UID}"
WFRC_FOLDER="${WFRC_FOLDER:-$XDG_RUNTIME_DIR/wfrc}"
SCRIPT_NAME="${SCRIPT_NAME:-wfrc}"
WFRC_LOCK="${WFRC_LOCK:-$WFRC_FOLDER/WFRCLOCK}"
WFRC_ICON="${WFRC_ICON:-camera-web}"
mkdir -p "$WFRC_FOLDER"

if ! [ -n "$WAYLAND_DISPLAY" ]; then
    WFRC_NOWAYLAND="No WAYLAND_DISPLAY found. Are you running under Wayland?"
    echo "$WFRC_NOWAYLAND" >&2
    notify-send --app-name="$SCRIPT_NAME" "Error" "$WFRC_NOWAYLAND" --icon="$WFRC_ICON"
    exit 1
fi

# Configurable options
WFRC_NOTIFY="${WFRC_NOTIFY:-1}"
WFRC_AUDIO_DEV="${WFRC_AUDIO_DEV:-$(LANG=C pactl list sources | grep 'Name.*output' | cut -d ' ' -f2)}"
WFRC_FILE_NAME="${WFRC_FILE_NAME:-$WFRC_FOLDER/${SCRIPT_NAME}-$(date +%Y-%m-%dT%H:%M:%S).mp4}"

# Single instance check
if [ -f "$WFRC_LOCK" ]; then
    kill $(cat "$WFRC_LOCK")
    rm "$WFRC_LOCK"
fi
echo $$ > "$WFRC_LOCK"

kill_wfrc() {
    kill -TERM "$wf_recorder_pid" 2>/dev/null
    rm -f "$WFRC_LOCK"
    echo -n "file://$WFRC_FILE_NAME" | wl-copy -t 'text/uri-list'
    if [ "$WFRC_NOTIFY" -eq 1 ]; then
        SIZE=$(ls -lh "$WFRC_FILE_NAME" | awk '{print $5}')
        ENDTIME=$(date +%s)
        duration=$((ENDTIME - STARTTIME))
        minutes=$((duration / 60))
        seconds=$((duration % 60))
        formatted_duration="${minutes}m ${seconds}s"
        [[ $minutes -eq 0 ]] && formatted_duration="${seconds}s"
        notify-send -t 5000 --app-name="$SCRIPT_NAME" "Recording Finished" \
            "$formatted_duration | $SIZE | $resolution" --icon="$WFRC_ICON"
    fi
    exit
}

trap 'kill_wfrc' SIGINT SIGTERM

# Ask user what to record
CHOICE=$(printf "Fullscreen\nWindow\nRegion" | rofi -dmenu -i -p "Record:")

case "$CHOICE" in
    "Fullscreen")
        resolution="Full Screen"
        output=""
        ;;
    "Window")
        # Get visible windows as bounding boxes
        clients=$(hyprctl -j clients)
        boxes=$(echo "$clients" | jq -r '.[] | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')

        # Use slurp to select one
        output=$(echo "$boxes" | slurp -r)
        if [ $? -ne 0 ]; then
            rm "$WFRC_LOCK"
            notify-send --app-name="$SCRIPT_NAME" "Selection canceled." --icon="$WFRC_ICON"
            exit 1
        fi

        resolution=$(echo "$output" | awk '{split($0,a," "); print a[2]}')
        ;;
    "Region")
        output=$(slurp)
        if [ $? -ne 0 ]; then
            rm "$WFRC_LOCK"
            notify-send --app-name="$SCRIPT_NAME" "Selection canceled." --icon="$WFRC_ICON"
            exit 1
        fi
        resolution=$(echo "$output" | awk '{split($0,a," "); print a[3]"x"a[4]}')
        ;;
    *)
        rm "$WFRC_LOCK"
        notify-send --app-name="$SCRIPT_NAME" "Invalid choice or canceled." --icon="$WFRC_ICON"
        exit 1
        ;;
esac

if [ "$WFRC_NOTIFY" -eq 1 ]; then
    notify-send -t 1000 --app-name="$SCRIPT_NAME" "Recording..." --icon="$WFRC_ICON"
fi

STARTTIME=$(date +%s)

# Start wf-recorder with appropriate geometry and audio
if [ -z "$output" ]; then
    # Fullscreen mode
    wf-recorder -f "$WFRC_FILE_NAME" --audio="$WFRC_AUDIO_DEV" &
else
    wf-recorder -f "$WFRC_FILE_NAME" -g "$output" --audio="$WFRC_AUDIO_DEV" &
fi

wf_recorder_pid=$!
wait $wf_recorder_pid
