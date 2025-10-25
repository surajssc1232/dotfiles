#!/usr/bin/env bash
#
# wl-record-toggle.sh — toggle recording (Fullscreen / Region) + audio + URI copy
#

LOCKFILE="/tmp/wlrecord.lock"
# Dynamically get the active system audio monitor
AUDIO_DEVICE="$(pactl get-default-sink).monitor"


# If lock file exists, stop recording
if [ -f "$LOCKFILE" ]; then
    PID=$(cat "$LOCKFILE")
    if kill -0 "$PID" 2>/dev/null; then
        kill -SIGINT "$PID"
        wait "$PID" 2>/dev/null
        rm -f "$LOCKFILE"

        # Copy URI to clipboard
        TMPFILE=$(ls /tmp/wlrecord-*.mp4 2>/dev/null | tail -n1)
        if [ -f "$TMPFILE" ]; then
            wl-copy -t 'text/uri-list' <<< "file://$TMPFILE"
            notify-send "✅ Recording stopped" "File URI copied to clipboard"
        else
            notify-send "❌ Recording stopped" "No file found"
        fi
    else
        rm -f "$LOCKFILE"
        notify-send "⚠️ Stale lock removed"
    fi
    exit 0
fi

# Not recording → start new recording
TMPFILE="/tmp/wlrecord-$(date +%s).mp4"

# Ask capture mode (Fullscreen / Region only)
MODE=$(printf "Fullscreen\nRegion" | fuzzel --dmenu --prompt "Record mode:")
[[ -z "$MODE" ]] && exit 0

REC_ARGS=(--audio --audio-device "$AUDIO_DEVICE")

case "$MODE" in
  Fullscreen) ;;
  Region)
    GEOM=$(slurp)
    [[ -z "$GEOM" ]] && exit 0
    REC_ARGS+=(-g "$GEOM")
    ;;
esac

notify-send "🎥 Recording Started"
nohup wl-screenrec "${REC_ARGS[@]}" -f "$TMPFILE" > /dev/null 2>&1 &

PID=$!
echo "$PID" > "$LOCKFILE"
