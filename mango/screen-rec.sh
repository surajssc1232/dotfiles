#!/usr/bin/bash
# wl-record-toggle.sh — bullet-proof version with full logging

set -euo pipefail

LOCKFILE="/tmp/wlrecord.lock"
LOGFILE="/tmp/wlrecord-debug.log"
MAX_LOG_SIZE=50000  # ~50 KB, rotates

# Rotate log if too big
if [[ -f "$LOGFILE" ]] && (( $(stat -c%s "$LOGFILE") > MAX_LOG_SIZE )); then
    mv "$LOGFILE" "$LOGFILE.old"
fi

log() {
    echo "[$(date '+%H:%M:%S')] $*" >> "$LOGFILE"
}

log "====================================="
log "Script started by $(whoami) — $0 $*"

# --- Cleanup stale lock + orphan files ---
cleanup_stale() {
    if [[ ! -f "$LOCKFILE" ]]; then
        return 0
    fi

    local old_pid=$(cat "$LOCKFILE" 2>/dev/null || echo "")
    log "Found lockfile with PID $old_pid"

    if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
        log "PID $old_pid is STILL RUNNING → not stale"
        return 1
    else
        log "PID $old_pid is dead → removing stale lock + orphan files"
        rm -f "$LOCKFILE"
        rm -f /tmp/wlrecord-*.mp4
        notify-send "Cleaned stale recording lock" "Old PID $old_pid was dead" --icon=dialog-warning
        return 0
    fi
}

# --- Stop recording if running ---
if [[ -f "$LOCKFILE" ]]; then
    PID=$(cat "$LOCKFILE")
    log "Lockfile exists → checking PID $PID"

    if kill -0 "$PID" 2>/dev/null; then
        log "Stopping recording (PID $PID)..."
        kill -SIGINT "$PID"
        if wait "$PID" 2>/dev/null; then
            log "wl-screenrec exited gracefully"
        else
            log "wl-screenrec was already dead or killed"
        fi

        rm -f "$LOCKFILE"
        LATEST=$(ls -t /tmp/wlrecord-*.mp4 2>/dev/null | head -n1 || echo "")
        if [[ -f "$LATEST" ]]; then
            URI="file://$LATEST"
            echo "$URI" | wl-copy -t text/uri-list
            log "Copied URI: $URI"
            notify-send "Recording stopped" "$(basename "$LATEST")\nURI copied" --icon=video-x-generic
        else
            log "No output file found!"
            notify-send "Recording stopped" "No file found" --icon=dialog-error
        fi
    else
        log "Stale lock detected (PID $PID not running)"
        cleanup_stale
    fi

    log "Script ending (stop path)"
    exit 0
fi

# --- Start new recording ---
cleanup_stale  # final safety

AUDIO_DEVICE="$(pactl get-default-sink).monitor"
log "Default audio monitor: $AUDIO_DEVICE"

TMPFILE="/tmp/wlrecord-$(date +%s).mp4"
log "Output file will be: $TMPFILE"

# Choose mode
MODE=$(printf "Fullscreen\nRegion\nActive Window (Hyprland)" | fuzzel --dmenu -p "Record: " -l 3 || echo "")
[[ -z "$MODE" ]] && { log "User cancelled mode selection"; exit 0; }
log "Selected mode: $MODE"

REC_ARGS=(--audio --audio-device "$AUDIO_DEVICE" -f "$TMPFILE")

case "$MODE" in
    Fullscreen)
        log "Recording fullscreen"
        ;;
    Region)
        GEOM=$(slurp -d || echo "")
        [[ -z "$GEOM" ]] && { log "slurp cancelled"; notify-send "Recording cancelled"; exit 0; }
        REC_ARGS+=(-g "$GEOM")
        log "Region selected: $GEOM"
        ;;
    "Active Window (Hyprland)")
        if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
            notify-send "Not in Hyprland"
            log "Active window mode requested but not in Hyprland"
            exit 1
        fi
        GEOM=$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
        [[ "$GEOM" == "0,0 0x0" || "$GEOM" == "null" ]] && { notify-send "No active window"; exit 1; }
        REC_ARGS+=(-g "$GEOM")
        log "Hyprland active window geometry: $GEOM"
        ;;
    *)
        log "Unknown mode: $MODE"
        exit 1
        ;;
esac

notify-send "Recording started" "$MODE" --icon=media-record
log "Starting wl-screenrec with args: ${REC_ARGS[*]}"

# Start recording — redirect BOTH stdout+stderr so no zombie output
nohup wl-screenrec "${REC_ARGS[@]}" >/tmp/wlrecord-stdout.log 2>/tmp/wlrecord-stderr.log &
PID=$!

# Double-check it actually started
sleep 0.3
if kill -0 "$PID" 2>/dev/null; then
    echo "$PID" > "$LOCKFILE"
    disown "$PID"
    log "Recording started successfully — PID $PID → lockfile created"
else
    log "wl-screenrec failed to start (PID $PID died instantly)"
    rm -f "$LOCKFILE"
    notify-send "Recording FAILED" "wl-screenrec died immediately — see logs" --icon=dialog-error
    exit 1
fi

exit 0
