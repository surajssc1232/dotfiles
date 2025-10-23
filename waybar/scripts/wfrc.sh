#!/usr/bin/env bash
# v0.3.1 - Toggle recording support + Fuzzel UI + Sway support + audio capture
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
WFRC_AUDIO_DEV="${WFRC_AUDIO_DEV:-$(LANG=C pactl list sources 2>/dev/null | grep 'Name.*output' | head -1 | cut -d ' ' -f2)}"
WFRC_FILE_NAME="${WFRC_FILE_NAME:-$WFRC_FOLDER/${SCRIPT_NAME}-$(date +%Y-%m-%dT%H:%M:%S).mp4}"

# Toggle check: if already recording, stop it
if [ -f "$WFRC_LOCK" ]; then
    old_pid=$(cat "$WFRC_LOCK" 2>/dev/null)
    if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
        # Recording is active, stop it
        kill -TERM "$old_pid" 2>/dev/null
        if [ "$WFRC_NOTIFY" -eq 1 ]; then
            notify-send -t 1000 --app-name="$SCRIPT_NAME" "Stopping recording..." --icon="$WFRC_ICON"
        fi
        exit 0
    else
        # Stale lock file, remove it
        rm -f "$WFRC_LOCK"
    fi
fi

# Not recording, so start a new recording
echo $$ > "$WFRC_LOCK"

kill_wfrc() {
    if [ -n "$wf_recorder_pid" ] && kill -0 "$wf_recorder_pid" 2>/dev/null; then
        kill -TERM "$wf_recorder_pid" 2>/dev/null
        wait "$wf_recorder_pid" 2>/dev/null
    fi
    rm -f "$WFRC_LOCK"
    
    if [ -f "$WFRC_FILE_NAME" ]; then
        echo -n "file://$WFRC_FILE_NAME" | wl-copy -t 'text/uri-list' 2>/dev/null
        
        if [ "$WFRC_NOTIFY" -eq 1 ]; then
            SIZE=$(ls -lh "$WFRC_FILE_NAME" 2>/dev/null | awk '{print $5}')
            ENDTIME=$(date +%s)
            duration=$((ENDTIME - STARTTIME))
            minutes=$((duration / 60))
            seconds=$((duration % 60))
            formatted_duration="${minutes}m ${seconds}s"
            [[ $minutes -eq 0 ]] && formatted_duration="${seconds}s"
            notify-send -t 5000 --app-name="$SCRIPT_NAME" "Recording Finished" \
                "$formatted_duration | $SIZE | $resolution" --icon="$WFRC_ICON"
        fi
    fi
    exit 0
}

trap 'kill_wfrc' SIGINT SIGTERM EXIT

# Ask user what to record using fuzzel
CHOICE=$(printf "Fullscreen\nWindow\nRegion" | fuzzel --dmenu -p "Record:")

case "$CHOICE" in
    "Fullscreen")
        resolution="Full Screen"
        output=""
        ;;
    "Window")
        # Get window info from sway
        windows=$(swaymsg -t get_tree 2>/dev/null | jq -r '.. | objects | select(.type? == "con" and .nodes == [] and .name != null) | "\(.rect.x),\(.rect.y) \(.rect.width)x\(.rect.height) \(.name)"')
        if [ -z "$windows" ]; then
            notify-send --app-name="$SCRIPT_NAME" "No windows found." --icon="$WFRC_ICON"
            rm -f "$WFRC_LOCK"
            exit 1
        fi
        selected=$(echo "$windows" | fuzzel --dmenu -p "Select window:")
        if [ -z "$selected" ]; then
            notify-send --app-name="$SCRIPT_NAME" "Selection canceled." --icon="$WFRC_ICON"
            rm -f "$WFRC_LOCK"
            exit 1
        fi
        output=$(echo "$selected" | awk '{print $1" "$2}')
        resolution=$(echo "$selected" | awk '{print $2}')
        ;;
    "Region")
        output=$(slurp 2>/dev/null)
        if [ $? -ne 0 ] || [ -z "$output" ]; then
            notify-send --app-name="$SCRIPT_NAME" "Selection canceled." --icon="$WFRC_ICON"
            rm -f "$WFRC_LOCK"
            exit 1
        fi
        resolution=$(echo "$output" | awk '{print $2}')
        ;;
    *)
        notify-send --app-name="$SCRIPT_NAME" "Invalid choice or canceled." --icon="$WFRC_ICON"
        rm -f "$WFRC_LOCK"
        exit 1
        ;;
esac

if [ "$WFRC_NOTIFY" -eq 1 ]; then
    notify-send -t 1000 --app-name="$SCRIPT_NAME" "Recording started..." --icon="$WFRC_ICON"
fi

STARTTIME=$(date +%s)

# Start wf-recorder with geometry and audio
if [ -z "$output" ]; then
    # Fullscreen
    if [ -n "$WFRC_AUDIO_DEV" ]; then
        wf-recorder -f "$WFRC_FILE_NAME" --audio="$WFRC_AUDIO_DEV" &
    else
        wf-recorder -f "$WFRC_FILE_NAME" &
    fi
else
    # With geometry
    if [ -n "$WFRC_AUDIO_DEV" ]; then
        wf-recorder -f "$WFRC_FILE_NAME" -g "$output" --audio="$WFRC_AUDIO_DEV" &
    else
        wf-recorder -f "$WFRC_FILE_NAME" -g "$output" &
    fi
fi

wf_recorder_pid=$!
wait $wf_recorder_pid
