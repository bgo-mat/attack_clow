#!/bin/bash
# =============================================================
# OpenClaw Watchdog v2 — Auto-restart stuck/crashed gateway
# =============================================================
# Detects:
#   1. Gateway process not responding
#   2. Sessions stuck in "aborted" state for >2 minutes
#   3. Agent idle — active session but no tool output for >5 minutes
#   4. STATE.md stale — not updated for >10 minutes during engagement
#   5. Context overflow — detected via gateway/ollama logs
# Recovery: restart the gateway process (checks 1-2) or notify (checks 3-5)
# =============================================================

LOG_FILE="/var/log/openclaw-watchdog.log"
SESSIONS_JSON="/root/.openclaw/agents/main/sessions/sessions.json"
MARKER_DIR="/tmp/openclaw-watchdog"
GATEWAY_PORT=18790
STALE_THRESHOLD=120      # seconds — aborted session age
IDLE_THRESHOLD=300       # seconds — no activity in active session
STATE_THRESHOLD=600      # seconds — STATE.md not updated
ENGAGEMENTS_DIR="/root/workspace/engagements"
GATEWAY_LOG="/var/log/openclaw-gateway.log"
OLLAMA_LOG="/var/log/ollama.log"

mkdir -p "$MARKER_DIR"

log() { echo "$(date -u '+%Y-%m-%d %H:%M:%S UTC') $1" >> "$LOG_FILE"; }
notify_operator() { log "NOTIFY: $1"; echo "[WATCHDOG | $(date -u '+%H:%M:%S')] $1" >> /tmp/openclaw-watchdog-alerts.log; }

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

# --- CHECK 3: Is the agent idle? (active session, no output for >5 min) ---
session_is_idle() {
    local session_file="$1"
    [ -f "$session_file" ] || return 1

    local last_line
    last_line=$(tail -1 "$session_file")
    [ -z "$last_line" ] && return 1

    # Skip if session is already in aborted/ended state
    local is_terminal
    is_terminal=$(echo "$last_line" | jq -r '
        if .type == "custom" and .customType == "openclaw:prompt-error" then "yes"
        elif .message.stopReason == "aborted" then "yes"
        elif .message.stopReason == "end_turn" then "yes"
        else "no"
        end
    ' 2>/dev/null)
    [ "$is_terminal" = "yes" ] && return 1

    # Check how old the last entry is
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

    [ "$age" -ge "$IDLE_THRESHOLD" ]
}

# --- CHECK 4: Is STATE.md stale during an active engagement? ---
state_is_stale() {
    [ -d "$ENGAGEMENTS_DIR" ] || return 1

    for state_file in "$ENGAGEMENTS_DIR"/*/STATE.md; do
        [ -f "$state_file" ] || continue

        # Only check active engagements (not completed ones)
        if grep -q "Progress.*100%" "$state_file" 2>/dev/null; then
            continue
        fi

        local file_age now_epoch file_epoch
        file_epoch=$(stat -c %Y "$state_file" 2>/dev/null || stat -f %m "$state_file" 2>/dev/null) || continue
        now_epoch=$(date +%s)
        file_age=$(( now_epoch - file_epoch ))

        if [ "$file_age" -ge "$STATE_THRESHOLD" ]; then
            echo "$state_file"
            return 0
        fi
    done
    return 1
}

# --- CHECK 5: Context overflow detection via logs ---
context_overflow_detected() {
    local now_epoch check_since

    now_epoch=$(date +%s)
    check_since=$(( now_epoch - 120 ))  # look back 2 minutes

    # Check gateway log for context/token overflow errors
    for logfile in "$GATEWAY_LOG" "$OLLAMA_LOG"; do
        [ -f "$logfile" ] || continue
        if tail -100 "$logfile" 2>/dev/null | grep -qi \
            -e "context.*overflow" \
            -e "context.*length.*exceed" \
            -e "token.*limit.*exceed" \
            -e "num_ctx.*exceed" \
            -e "out of memory" \
            -e "context window.*full" \
            -e "truncat.*context"; then
            return 0
        fi
    done
    return 1
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

    # Retry loop: wait up to 30s for gateway to come back
    for attempt in 1 2 3; do
        sleep 10
        if gateway_alive; then
            log "RESTART: Gateway recovered successfully (attempt $attempt)"
            return
        fi
        # If not up yet, kill and relaunch
        if [ "$attempt" -lt 3 ]; then
            log "RESTART: Attempt $attempt failed, retrying..."
            pkill -f "openclaw.*gateway" 2>/dev/null || true
            sleep 3
            OLLAMA_API_KEY="ollama-local" openclaw gateway --port "$GATEWAY_PORT" &>/dev/null &
            disown
        fi
    done
    log "RESTART: FAILED — Gateway not responding after 3 attempts"
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

# Check 3: Idle sessions? (active but no output for >5 min)
if [ -f "$SESSIONS_JSON" ]; then
    for sf in $(jq -r '.[].sessionFile // empty' "$SESSIONS_JSON" 2>/dev/null); do
        if session_is_idle "$sf"; then
            marker="$MARKER_DIR/idle-$(basename "$sf")"
            if [ -f "$marker" ]; then
                continue
            fi
            log "ALERT: Agent idle for >${IDLE_THRESHOLD}s: $(basename "$sf")"
            notify_operator "Agent idle depuis >$(( IDLE_THRESHOLD / 60 )) min — session $(basename "$sf"). Possible stall."
            restart_gateway "Agent idle for >${IDLE_THRESHOLD}s: $(basename "$sf")"
            touch "$marker"
            exit 0
        fi
    done
fi

# Check 4: STATE.md stale during active engagement?
stale_state=$(state_is_stale)
if [ -n "$stale_state" ]; then
    marker="$MARKER_DIR/stale-$(echo "$stale_state" | md5sum | cut -d' ' -f1)"
    if [ ! -f "$marker" ]; then
        log "ALERT: STATE.md stale for >${STATE_THRESHOLD}s: $stale_state"
        notify_operator "STATE.md non mis à jour depuis >$(( STATE_THRESHOLD / 60 )) min: $stale_state. L'agent ne suit peut-être plus la boucle cognitive."
        touch "$marker"
        # Don't restart — just notify. The agent may be running a long tool.
        # Clear marker after 10 min so we re-alert if still stale
        (sleep 600 && rm -f "$marker" 2>/dev/null) &
    fi
fi

# Check 5: Context overflow?
if context_overflow_detected; then
    marker="$MARKER_DIR/ctx-overflow"
    if [ ! -f "$marker" ]; then
        log "ALERT: Context overflow detected in logs"
        notify_operator "Context overflow détecté ! Le modèle dépasse num_ctx. Restart du gateway pour reset la session."
        restart_gateway "Context overflow detected"
        touch "$marker"
        # Clear marker after 5 min
        (sleep 300 && rm -f "$marker" 2>/dev/null) &
        exit 0
    fi
fi
