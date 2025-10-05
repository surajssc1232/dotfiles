#!/usr/bin/env bash
# v0.5.0 - wl-screenrec + Toggle support + Fuzzel UI + Hardware acceleration + Niri support
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
WFRC_AUDIO="${WFRC_AUDIO:-1}"
WFRC_AUDIO_DEV="${WFRC_AUDIO_DEV:-$(LANG=C pactl list sources 2>/dev/null | grep 'Name.*output' | head -1 | cut -d ' ' -f2)}"
WFRC_FILE_NAME="${WFRC_FILE_NAME:-$WFRC_FOLDER/${SCRIPT_NAME}-$(date +%Y-%m-%dT%H:%M:%S).mp4}"
WFRC_USE_VAAPI="${WFRC_USE_VAAPI:-1}"  # Enable hardware acceleration by default

# Toggle check: if already recording, stop it
if [ -f "$WFRC_LOCK" ]; then
    old_pid=$(cat "$WFRC_LOCK" 2>/dev/null)
    if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
        # Recording is active, stop it
        kill -SIGINT "$old_pid" 2>/dev/null
        if [ "$WFRC_NOTIFY" -eq 1 ]; then
            notify-send -t 1000 --app-name="$SCRIPT_NAME" "Stopping recording..." --icon="$WFRC_ICON"
        fi
        exit 0
    else
        # Stale lock file, remove it
        rm -f "$WFRC_LOCK"
    fi
fi

# Check for required tools
for tool in wl-screenrec fuzzel wl-copy; do
    if ! command -v "$tool" &> /dev/null; then
        error_msg="Required tool '$tool' not found. Please install it."
        echo "$error_msg" >&2
        notify-send --app-name="$SCRIPT_NAME" "Error" "$error_msg" --icon="$WFRC_ICON"
        exit 1
    fi
done

# Not recording, so start a new recording
echo $$ > "$WFRC_LOCK"

cleanup_recording() {
    if [ -n "$recorder_pid" ] && kill -0 "$recorder_pid" 2>/dev/null; then
        kill -SIGINT "$recorder_pid" 2>/dev/null
        wait "$recorder_pid" 2>/dev/null
    fi
    
    # Give time for file to finish writing
    sleep 1
    
    rm -f "$WFRC_LOCK"
    
    if [ -f "$WFRC_FILE_NAME" ]; then
        # Copy file as URI for drag-and-drop support
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
    
    # Don't exit immediately, let wl-copy establish itself
    sleep 0.5
    exit 0
}

trap 'cleanup_recording' SIGINT SIGTERM EXIT

# Detect compositor
COMPOSITOR="sway"
if ! command -v swaymsg &> /dev/null || ! swaymsg -t get_version &>/dev/null; then
    # Not Sway, detect others
    if command -v niri &> /dev/null && pgrep -x niri > /dev/null; then
        COMPOSITOR="niri"
    elif command -v hyprctl &> /dev/null; then
        COMPOSITOR="hyprland"
    else
        COMPOSITOR="unknown"
    fi
fi

# Ask user what to record using fuzzel
if [ "$COMPOSITOR" = "sway" ]; then
    CHOICE=$(printf "Fullscreen\nWindow\nRegion" | fuzzel --dmenu -p "Record:")
else
    # For Niri and others, don't offer window selection
    CHOICE=$(printf "Fullscreen\nRegion" | fuzzel --dmenu -p "Record:")
fi

if [ -z "$CHOICE" ]; then
    notify-send --app-name="$SCRIPT_NAME" "Selection canceled." --icon="$WFRC_ICON"
    rm -f "$WFRC_LOCK"
    exit 1
fi

case "$CHOICE" in
    "Fullscreen")
        resolution="Full Screen"
        geometry=""
        ;;
    "Window")
        # Only works with Sway
        if [ "$COMPOSITOR" != "sway" ]; then
            notify-send --app-name="$SCRIPT_NAME" "Window selection only works with Sway." --icon="$WFRC_ICON"
            rm -f "$WFRC_LOCK"
            exit 1
        fi
        
        # Get window info from sway
windows=$(swaymsg -t get_tree 2>/dev/null | jq -r '.. | objects | select(.type? == "con" and .nodes == [] and .name != null) | .name')
        
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
        
        # Parse the geometry: "x,y widthxheight name"
        geometry=$(echo "$selected" | awk '{print $1" "$2}')
        resolution=$(echo "$selected" | awk '{print $2}')
        ;;
    "Region")
        if ! command -v slurp &> /dev/null; then
            notify-send --app-name="$SCRIPT_NAME" "slurp not found. Install it." --icon="$WFRC_ICON"
            rm -f "$WFRC_LOCK"
            exit 1
        fi
        
        geometry=$(slurp 2>/dev/null)
        
        if [ $? -ne 0 ] || [ -z "$geometry" ]; then
            notify-send --app-name="$SCRIPT_NAME" "Selection canceled." --icon="$WFRC_ICON"
            rm -f "$WFRC_LOCK"
            exit 1
        fi
        
        # slurp outputs: "x,y widthxheight"
        resolution=$(echo "$geometry" | awk '{print $2}')
        ;;
    *)
        notify-send --app-name="$SCRIPT_NAME" "Invalid choice." --icon="$WFRC_ICON"
        rm -f "$WFRC_LOCK"
        exit 1
        ;;
esac

if [ "$WFRC_NOTIFY" -eq 1 ]; then
    notify-send -t 1000 --app-name="$SCRIPT_NAME" "Recording started..." --icon="$WFRC_ICON"
fi

STARTTIME=$(date +%s)

# Set up VA-API for Intel iGPU
export LIBVA_DRIVER_NAME=iHD

# Build wl-screenrec command
WL_CMD="wl-screenrec"

# Add system audio if enabled and device found
if [ "$WFRC_AUDIO" -eq 1 ] && [ -n "$WFRC_AUDIO_DEV" ]; then
    WL_CMD="$WL_CMD --audio --audio-device \"$WFRC_AUDIO_DEV\""
fi

# Add geometry if not fullscreen
if [ -n "$geometry" ]; then
    WL_CMD="$WL_CMD --geometry \"$geometry\""
fi

# Use hardware acceleration if enabled and available
if [ "$WFRC_USE_VAAPI" -eq 1 ]; then
    # Check if VA-API is working
    if vainfo &>/dev/null; then
        # Use hardware acceleration, suppress low_power warning
        WL_CMD="$WL_CMD --low-power=off"
    else
        # Fall back to software encoding
        WL_CMD="$WL_CMD --ffmpeg-encoder libx264"
    fi
else
    # Use software encoding
    WL_CMD="$WL_CMD --ffmpeg-encoder libx264"
fi

# Add filename
WL_CMD="$WL_CMD --filename \"$WFRC_FILE_NAME\""

# Execute the command
eval "$WL_CMD" &
recorder_pid=$!
wait $recorder_pid
