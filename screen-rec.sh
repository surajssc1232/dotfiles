#!/usr/bin/env bash
# screen-record-toggle.sh
# Video+system audio: wf-recorder (no loopbacks ever)
# Mic: pw-record (native PipeWire, no clock drift)
# Mux: ffmpeg on stop

set -euo pipefail

LOCKFILE="/tmp/screenrecord.lock"
LOGFILE="/tmp/screenrecord-debug.log"
MAX_LOG_SIZE=50000

if [[ -f "$LOGFILE" ]] && (( $(stat -c%s "$LOGFILE") > MAX_LOG_SIZE )); then
    mv "$LOGFILE" "$LOGFILE.old"
fi

log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOGFILE"; }

log "====================================="
log "Script started by $(whoami) — $0 $*"

EARPODS_MIC="alsa_input.usb-Apple__Inc._EarPods_GP4FV6FDJ5-00.mono-fallback"

# --- Cleanup stale lock ---
cleanup_stale() {
    [[ ! -f "$LOCKFILE" ]] && return 0
    local old_pid
    old_pid=$(awk '{print $1}' "$LOCKFILE" 2>/dev/null || echo "")
    if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
        log "PID $old_pid still running — not stale"
        return 1
    fi
    log "PID $old_pid dead — removing stale lock"
    rm -f "$LOCKFILE"
    rm -f /tmp/screenrec-*.mp4 /tmp/screenrec-*.mkv /tmp/screenrec-mic-*.wav
    notify-send "Cleaned stale recording lock" "Old PID $old_pid was dead" --icon=dialog-warning
    return 0
}

# --- STOP PATH ---
if [[ -f "$LOCKFILE" ]]; then
    read -r WFR_PID MIC_PID VIDFILE MICFILE AUDIO_MODE < "$LOCKFILE" || true
    log "Stop: WFR=$WFR_PID MIC=${MIC_PID} VID=$VIDFILE MIC_F=$MICFILE MODE=$AUDIO_MODE"

    if ! kill -0 "$WFR_PID" 2>/dev/null; then
        cleanup_stale; exit 0
    fi

    notify-send "Stopping..." "Saving recording" --icon=media-record

    kill -SIGINT "$WFR_PID" 2>/dev/null || true
    if [[ "$MIC_PID" != "-" ]] && kill -0 "$MIC_PID" 2>/dev/null; then
        kill -SIGINT "$MIC_PID" 2>/dev/null || true
        log "Stopped pw-record PID $MIC_PID"
    fi

    # Wait for both processes to finish writing
    sleep 1.5

    rm -f "$LOCKFILE"

    if [[ ! -f "$VIDFILE" ]]; then
        notify-send "Recording FAILED" "No video file found" --icon=dialog-error
        log "No video file at $VIDFILE"
        exit 1
    fi

    FINALFILE="${VIDFILE//.mkv/.mp4}"
    FINALFILE="${FINALFILE//-final/}"
    FINALFILE="${FINALFILE//.mp4/-final.mp4}"

    case "$AUDIO_MODE" in
        mic+sys)
            if [[ -f "$MICFILE" ]]; then
                log "Muxing mic + system audio with ducking → $FINALFILE"
                ffmpeg -y \
                    -i "$VIDFILE" \
                    -i "$MICFILE" \
                    -filter_complex \
                      "[0:a]aresample=async=1[a0];[1:a]aresample=async=1,volume=3.4[a1];[a1]asplit=2[a1_mix][a1_sc];[a0][a1_sc]sidechaincompress=threshold=0.04:ratio=9:attack=200:release=800:makeup=1[a0_ducked];[a0_ducked][a1_mix]amix=inputs=2:duration=first,loudnorm[aout]" \
                    -map 0:v -map "[aout]" \
                    -c:v copy -c:a aac -b:a 192k -ar 48000 \
                    "$FINALFILE" \
                    >>/tmp/screenrec-ffmpeg.log 2>&1 \
                && { rm -f "$VIDFILE" "$MICFILE"; log "Mux done → $FINALFILE"; } \
                || { log "ffmpeg mux failed"; FINALFILE="$VIDFILE"; }
            else
                log "No mic file — remuxing to mp4"
                ffmpeg -y -i "$VIDFILE" -c copy "$FINALFILE" >>/tmp/screenrec-ffmpeg.log 2>&1 \
                && rm -f "$VIDFILE" || FINALFILE="$VIDFILE"
            fi
            ;;
        mic_only)
            if [[ -f "$MICFILE" ]]; then
                log "Replacing audio with mic → $FINALFILE"
                ffmpeg -y \
                    -i "$VIDFILE" \
                    -i "$MICFILE" \
                    -map 0:v -map 1:a \
                    -filter:a "volume=4.0,loudnorm" \
                    -c:v copy -c:a aac -b:a 192k -ar 48000 \
                    -shortest \
                    "$FINALFILE" \
                    >>/tmp/screenrec-ffmpeg.log 2>&1 \
                && { rm -f "$VIDFILE" "$MICFILE"; log "Mic-only done → $FINALFILE"; } \
                || { log "ffmpeg failed"; FINALFILE="$VIDFILE"; }
            else
                log "No mic file — remuxing to mp4"
                ffmpeg -y -i "$VIDFILE" -c copy "$FINALFILE" >>/tmp/screenrec-ffmpeg.log 2>&1 \
                && rm -f "$VIDFILE" || FINALFILE="$VIDFILE"
            fi
            ;;
        *)
            # sys_only / no_audio — just remux mkv→mp4, no re-encode needed
            log "Remuxing mkv → mp4"
            ffmpeg -y -i "$VIDFILE" -c copy "$FINALFILE" >>/tmp/screenrec-ffmpeg.log 2>&1 \
            && { rm -f "$VIDFILE"; log "Remux done → $FINALFILE"; } \
            || { log "ffmpeg remux failed — keeping mkv"; FINALFILE="$VIDFILE"; }
            ;;
    esac

    URI="file://$FINALFILE"
    echo "$URI" | wl-copy -t text/uri-list
    log "Done → $URI"
    notify-send "Recording saved" "$(basename "$FINALFILE")\nURI copied" --icon=video-x-generic
    exit 0
fi

# --- START PATH ---
cleanup_stale

TIMESTAMP=$(date +%s)
VIDFILE="/tmp/screenrec-${TIMESTAMP}.mp4"
MICFILE="/tmp/screenrec-mic-${TIMESTAMP}.wav"
log "Video: $VIDFILE"

# --- Niri socket ---
if [[ -z "${NIRI_SOCKET:-}" ]]; then
    _sock="/run/user/$(id -u)/niri/socket"
    [[ -S "$_sock" ]] && export NIRI_SOCKET="$_sock" && log "Niri socket: $NIRI_SOCKET"
fi

# --- Pick monitor ---
MONITOR_LIST=""

if [[ -n "${NIRI_SOCKET:-}" ]] && command -v niri &>/dev/null; then
    MONITOR_LIST=$(niri msg --json outputs 2>/dev/null \
        | jq -r '.[] | "\(.name)  [\(.current_mode.width)x\(.current_mode.height)@\(.current_mode.refresh_rate|floor)Hz]"' \
        || echo "")
    log "niri monitors: $MONITOR_LIST"
fi

if [[ -z "$MONITOR_LIST" ]] && command -v wlr-randr &>/dev/null; then
    MONITOR_LIST=$(wlr-randr 2>/dev/null \
        | awk '/^[A-Za-z]/{name=$1} /current/{print name "  [" $1 "]"}' || echo "")
    log "wlr-randr monitors: $MONITOR_LIST"
fi

if [[ -z "$MONITOR_LIST" ]]; then
    MONITOR_LIST=$(wf-recorder --list-outputs 2>&1 | grep -oP '(?<=Name: )[^\s]+' || echo "")
    log "wf-recorder monitors: $MONITOR_LIST"
fi

if [[ -z "$MONITOR_LIST" ]]; then
    notify-send "Recording FAILED" "Could not detect monitors" --icon=dialog-error
    log "ERROR: no monitors found"; exit 1
fi

MONITOR_CHOICE=$(echo "$MONITOR_LIST" | fuzzel --dmenu -p "Display: " -l 10 || echo "")
[[ -z "$MONITOR_CHOICE" ]] && exit 0
MONITOR_NAME=$(echo "$MONITOR_CHOICE" | awk '{print $1}')
log "Monitor: $MONITOR_NAME"

# --- Pick mode ---
MODE=$(printf "Fullscreen\nRegion\nActive Window (Niri)" | fuzzel --dmenu -p "Record: " -l 3 || echo "")
[[ -z "$MODE" ]] && exit 0
log "Mode: $MODE"

# --- Pick audio ---
AUDIO_OPTIONS="System audio (no mic)"
if pactl list sources short 2>/dev/null | grep -q "$EARPODS_MIC"; then
    AUDIO_OPTIONS+=$'\nEarPods mic + system audio'
    AUDIO_OPTIONS+=$'\nEarPods mic only'
fi
AUDIO_OPTIONS+=$'\nNo audio'

AUDIO_CHOICE=$(echo "$AUDIO_OPTIONS" | fuzzel --dmenu -p "Audio: " -l 5 || echo "")
[[ -z "$AUDIO_CHOICE" ]] && exit 0
log "Audio: $AUDIO_CHOICE"

SYSTEM_AUDIO="$(pactl get-default-sink).monitor"

# wf-recorder handles system audio natively — no loopbacks
# For mic: pw-record runs in parallel, ffmpeg muxes on stop
case "$AUDIO_CHOICE" in
    "System audio (no mic)")
        AUDIO_MODE="sys_only"
        # No codec flags — wf-recorder defaults to aac and it works perfectly
        WFR_AUDIO=(--audio="$SYSTEM_AUDIO")
        VIDFILE="/tmp/screenrec-${TIMESTAMP}.mkv"
        ;;
    "EarPods mic + system audio")
        AUDIO_MODE="mic+sys"
        WFR_AUDIO=(--audio="$SYSTEM_AUDIO")
        VIDFILE="/tmp/screenrec-${TIMESTAMP}.mkv"
        ;;
    "EarPods mic only")
        AUDIO_MODE="mic_only"
        WFR_AUDIO=(--audio="$SYSTEM_AUDIO")
        VIDFILE="/tmp/screenrec-${TIMESTAMP}.mkv"
        ;;
    "No audio")
        AUDIO_MODE="no_audio"
        WFR_AUDIO=()
        VIDFILE="/tmp/screenrec-${TIMESTAMP}.mkv"
        ;;
esac

# --- Geometry ---
case "$MODE" in
    Fullscreen)
        GEOM_ARGS=(-o "$MONITOR_NAME")
        ;;
    Region)
        GEOM=$(slurp -d || echo "")
        [[ -z "$GEOM" ]] && { notify-send "Recording cancelled"; exit 0; }
        GEOM_ARGS=(-g "$GEOM")
        log "Region: $GEOM"
        ;;
    "Active Window (Niri)")
        WIN_JSON=$(NIRI_SOCKET="${NIRI_SOCKET:-/run/user/$(id -u)/niri/socket}" \
            niri msg --json focused-window 2>/dev/null || echo "")
        if [[ -z "$WIN_JSON" || "$WIN_JSON" == "null" ]]; then
            notify-send "No focused window" --icon=dialog-error; exit 1
        fi
        X=$(echo "$WIN_JSON" | jq -r '.x // empty')
        Y=$(echo "$WIN_JSON" | jq -r '.y // empty')
        W=$(echo "$WIN_JSON" | jq -r '.width // empty')
        H=$(echo "$WIN_JSON" | jq -r '.height // empty')
        [[ -z "$X" || -z "$W" ]] && { notify-send "Window geometry unavailable" --icon=dialog-error; exit 1; }
        GEOM="${X},${Y} ${W}x${H}"
        GEOM_ARGS=(-g "$GEOM")
        log "Window: $GEOM"
        ;;
    *)
        log "Unknown mode: $MODE"; exit 1 ;;
esac

REC_ARGS=(-c libx264 "${GEOM_ARGS[@]}" "${WFR_AUDIO[@]}" -f "$VIDFILE")
log "wf-recorder: ${REC_ARGS[*]}"

nohup wf-recorder "${REC_ARGS[@]}" >/tmp/screenrec-stdout.log 2>/tmp/screenrec-stderr.log &
WFR_PID=$!

sleep 0.5
if ! kill -0 "$WFR_PID" 2>/dev/null; then
    log "wf-recorder died. STDERR: $(cat /tmp/screenrec-stderr.log 2>/dev/null)"
    notify-send "Recording FAILED" "Check $LOGFILE" --icon=dialog-error
    exit 1
fi

# --- Start pw-record for mic if needed ---
MIC_PID="-"
if [[ "$AUDIO_MODE" == "mic+sys" || "$AUDIO_MODE" == "mic_only" ]]; then
    log "Starting pw-record mic → $MICFILE"
    # pw-record uses native PipeWire — no PulseAudio compat layer, no clock drift
    nohup pw-record \
        --target="$EARPODS_MIC" \
        --rate=48000 \
        --channels=1 \
        --format=s16 \
        "$MICFILE" \
        >/tmp/screenrec-mic.log 2>&1 &
    MIC_PID=$!
    sleep 0.3
    if ! kill -0 "$MIC_PID" 2>/dev/null; then
        log "pw-record died. Log: $(cat /tmp/screenrec-mic.log 2>/dev/null)"
        notify-send "Mic capture failed" "Recording without mic" --icon=dialog-warning
        MIC_PID="-"
        AUDIO_MODE="sys_only"
    else
        log "pw-record started — PID $MIC_PID"
        disown "$MIC_PID"
    fi
fi

echo "$WFR_PID $MIC_PID $VIDFILE $MICFILE $AUDIO_MODE" > "$LOCKFILE"
disown "$WFR_PID"

notify-send "Recording started" "$MODE — $MONITOR_NAME\n$AUDIO_CHOICE" --icon=media-record
log "Recording — WFR=$WFR_PID MIC=$MIC_PID MODE=$AUDIO_MODE"

exit 0
