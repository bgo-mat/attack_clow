#!/bin/bash
# =============================================================
# Attack Claw — Dashboard Access & Device Pairing
# =============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[-]${NC} $1"; exit 1; }
info() { echo -e "${CYAN}[*]${NC} $1"; }

# =============================================================
# 1. CHECK SERVICES
# =============================================================
if ! curl -s http://127.0.0.1:18790 &>/dev/null; then
    warn "Gateway not running — starting services..."
    spectre-start-all 2>/dev/null || err "Run 'spectre-start-all' first"
fi

# =============================================================
# 2. GET DASHBOARD URL
# =============================================================
DASHBOARD_URL=""

# Try Cloudflare tunnel (Vast.ai)
if curl -s http://localhost:11112/ &>/dev/null; then
    info "Creating Cloudflare tunnel..."
    TUNNEL_JSON=$(curl -s --max-time 30 "http://localhost:11112/get-quick-tunnel/http://localhost:18790" 2>/dev/null)
    TUNNEL_URL=$(echo "$TUNNEL_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tunnel_url',''))" 2>/dev/null) || true

    if [ -n "$TUNNEL_URL" ]; then
        DASHBOARD_URL="$TUNNEL_URL"

        # Update allowedOrigins if needed
        python3 -c "
import json
with open('/root/.openclaw/openclaw.json') as f:
    cfg = json.load(f)
origins = cfg['gateway']['controlUi']['allowedOrigins']
if '$TUNNEL_URL' not in origins:
    origins.append('$TUNNEL_URL')
    with open('/root/.openclaw/openclaw.json', 'w') as f:
        json.dump(cfg, f, indent=2)
    print('UPDATED')
else:
    print('OK')
" 2>/dev/null | grep -q "UPDATED" && {
            log "Added tunnel to allowedOrigins — restarting gateway..."
            pkill -f "openclaw gateway" 2>/dev/null
            sleep 2
            OLLAMA_API_KEY="ollama-local" openclaw gateway --port 18790 &>/dev/null &
            sleep 3
        }
    else
        warn "Tunnel creation failed"
    fi
fi

# Fallback to direct IP
if [ -z "$DASHBOARD_URL" ]; then
    VPS_IP=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')
    DASHBOARD_URL="https://$VPS_IP/"
fi

# =============================================================
# 3. APPROVE PENDING DEVICES
# =============================================================
PENDING=$(openclaw devices list 2>/dev/null | grep -A100 "^Pending" | grep "│" | grep -v "Request\|─" | awk -F'│' '{print $2}' | tr -d ' ' | grep -v '^$')

if [ -n "$PENDING" ]; then
    info "Approving pending devices..."
    for req_id in $PENDING; do
        openclaw devices approve "$req_id" 2>&1 && log "Approved: $req_id" || warn "Failed to approve: $req_id"
    done
else
    log "No pending devices"
fi

# =============================================================
# SUMMARY
# =============================================================
echo ""
echo "========================================="
echo -e "  Dashboard: ${CYAN}$DASHBOARD_URL${NC}"
echo "========================================="
echo ""
