#!/bin/bash
# =============================================================
# OpenClaw Watchdog — Auto-restart stuck/crashed gateway
# =============================================================
# Detects:
#   1. Gateway process not responding
#   2. Sessions stuck in "aborted" state for >2 minutes
# Recovery: restart the gateway process
# =============================================================

LOG_FILE="/var/log/openclaw-watchdog.log"
SESSIONS_JSON="/root/.openclaw/agents/main/sessions/sessions.json"
MARKER_DIR="/tmp/openclaw-watchdog"
GATEWAY_PORT=18790
STALE_THRESHOLD=120  # seconds

mkdir -p "$MARKER_DIR"

log() { echo "$(date -u '+%Y-%m-%d %H:%M:%S UTC') $1" >> "$LOG_FILE"; }

# --- CHECK 1: Is the gateway alive? ---
gateway_alive() {
    curl -s --max-time 5 "http://127.0.0.1:${GATEWAY_PORT}" >/dev/null 2>&1
}

# --- CHECK 2: Is a session stuck in aborted state? ---
session_is_stuck() {
    local session_file="$1"
    [ -f "$session_file" ] || return 1

    local last_line
    last_line=$(tail -1 "$session_file")
    [ -z "$last_line" ] && return 1

    # Check if last entry indicates abort
    local is_aborted
    is_aborted=$(echo "$last_line" | jq -r '
        if .type == "custom" and .customType == "openclaw:prompt-error" and .data.error == "aborted" then "yes"
        elif .message.stopReason == "aborted" then "yes"
        else "no"
        end
    ' 2>/dev/null)

    [ "$is_aborted" != "yes" ] && return 1

    # Check timestamp age
    local entry_ts
    entry_ts=$(echo "$last_line" | jq -r '
        if .timestamp then .timestamp
        elif .data.timestamp then (.data.timestamp / 1000 | todate)
        else empty
        end
    ' 2>/dev/null)
    [ -z "$entry_ts" ] && return 1

    local entry_epoch now_epoch age
    entry_epoch=$(date -d "$entry_ts" +%s 2>/dev/null) || return 1
    now_epoch=$(date +%s)
    age=$(( now_epoch - entry_epoch ))

    [ "$age" -ge "$STALE_THRESHOLD" ]
}

# --- RESTART ---
restart_gateway() {
    local reason="$1"
    log "RESTART: $reason"

    if pidof systemd &>/dev/null || [ -d /run/systemd/system ]; then
        export XDG_RUNTIME_DIR=/run/user/0
        systemctl --user restart openclaw-gateway 2>&1 | while read -r line; do log "  systemctl: $line"; done
    else
        pkill -f "openclaw.*gateway" 2>/dev/null || true
        sleep 2
        OLLAMA_API_KEY="ollama-local" openclaw gateway --port "$GATEWAY_PORT" &>/dev/null &
        disown
    fi

    sleep 5
    if gateway_alive; then
        log "RESTART: Gateway recovered successfully"
    else
        log "RESTART: WARNING — Gateway still not responding after restart"
    fi
}

# --- MAIN ---

# Check 1: Gateway alive?
if ! gateway_alive; then
    log "ALERT: Gateway not responding on port $GATEWAY_PORT"
    restart_gateway "Gateway not responding"
    exit 0
fi

# Check 2: Stuck sessions?
if [ -f "$SESSIONS_JSON" ]; then
    for sf in $(jq -r '.[].sessionFile // empty' "$SESSIONS_JSON" 2>/dev/null); do
        if session_is_stuck "$sf"; then
            # Skip if we already restarted for this exact session state
            line_count=$(wc -l < "$sf" | tr -d ' ')
            marker="$MARKER_DIR/$(basename "$sf").${line_count}"
            if [ -f "$marker" ]; then
                continue
            fi
            log "ALERT: Stuck aborted session: $(basename "$sf")"
            restart_gateway "Stuck aborted session: $(basename "$sf")"
            # Mark as handled (cleared when session gets new lines)
            rm -f "$MARKER_DIR/$(basename "$sf")".* 2>/dev/null
            touch "$marker"
            exit 0
        fi
    done
fi
