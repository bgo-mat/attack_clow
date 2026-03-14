#!/bin/bash
# =============================================================
# Attack Claw — Spectre Pentest Agent — Automated Installation
# =============================================================
# Compatible with: VPS (systemd) and Docker containers (no systemd)
# Requirements: Debian/Ubuntu, root access, GPU recommended
# =============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[-]${NC} $1"; exit 1; }
info() { echo -e "${CYAN}[*]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Detect if we have systemd
HAS_SYSTEMD=false
if pidof systemd &>/dev/null || [ -d /run/systemd/system ]; then
    HAS_SYSTEMD=true
fi

# =============================================================
# PRE-CHECKS
# =============================================================
if [ "$EUID" -ne 0 ]; then
    err "Run as root"
fi

echo ""
echo "========================================="
echo "  SPECTRE — Attack Claw Setup"
echo "========================================="
echo ""

if [ "$HAS_SYSTEMD" = true ]; then
    info "Detected: systemd environment (VPS/VM)"
else
    info "Detected: container environment (no systemd)"
fi

# Interactive: ask for dashboard password
read -s -p "[?] Choose a dashboard password: " DASHBOARD_PASSWORD
echo ""
if [ -z "$DASHBOARD_PASSWORD" ]; then
    err "Password cannot be empty"
fi

# Generate a gateway token (strip special chars for URL safety)
GATEWAY_TOKEN=$(echo -n "$DASHBOARD_PASSWORD" | tr -d '!@#$%^&*(){}[]|\\:;<>?,./~`')

VPS_IP=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')
log "VPS IP detected: $VPS_IP"
log "Dashboard password set"

# =============================================================
# 1. SYSTEM PACKAGES — Pentest Arsenal
# =============================================================
log "Installing system packages..."

apt-get update -qq

apt-get install -y -qq \
    nmap masscan netcat-openbsd socat \
    ffuf gobuster dirb sqlmap wfuzz \
    hydra medusa john \
    gdb binwalk ltrace strace \
    proxychains4 tor \
    curl httpie jq whois dnsutils \
    tmux git unzip wget \
    python3 python3-pip \
    whatweb \
    ruby rubygems \
    nodejs npm \
    openssl \
    caddy 2>/dev/null || warn "Some packages may have failed — check manually"

log "System packages installed"

# =============================================================
# 2. RADARE2 (from GitHub releases)
# =============================================================
if ! command -v r2 &>/dev/null; then
    log "Installing radare2..."
    R2_DEB=$(curl -s https://api.github.com/repos/radareorg/radare2/releases/latest | python3 -c "
import sys,json
for a in json.load(sys.stdin).get('assets',[]):
    if 'amd64.deb' in a['name'] and 'dev' not in a['name']:
        print(a['browser_download_url']); break
" 2>/dev/null)
    if [ -n "$R2_DEB" ]; then
        wget -q "$R2_DEB" -O /tmp/r2.deb && dpkg -i /tmp/r2.deb && rm /tmp/r2.deb
        log "radare2 installed"
    else
        warn "radare2 download failed — install manually"
    fi
fi

# =============================================================
# 3. GO TOOLS (subfinder, httpx, nuclei)
# =============================================================
log "Installing Go security tools..."

install_go_tool() {
    local name=$1 repo=$2
    if command -v "$name" &>/dev/null; then
        log "$name already installed"
        return
    fi
    local ver=$(curl -sI "https://github.com/$repo/releases/latest" | grep -i location | grep -oP 'v[\d.]+')
    local url="https://github.com/$repo/releases/download/${ver}/${name}_${ver#v}_linux_amd64.zip"
    curl -sL "$url" -o "/tmp/${name}.zip" && \
        unzip -o "/tmp/${name}.zip" "$name" -d /tmp/ && \
        mv "/tmp/$name" /usr/local/bin/ && \
        chmod +x "/usr/local/bin/$name" && \
        log "$name $ver installed" || warn "$name install failed"
    rm -f "/tmp/${name}.zip"
}

install_go_tool subfinder projectdiscovery/subfinder
install_go_tool httpx projectdiscovery/httpx
install_go_tool nuclei projectdiscovery/nuclei

# =============================================================
# 4. PIP TOOLS
# =============================================================
log "Installing pip tools..."
pip3 install --break-system-packages wafw00f 2>/dev/null || warn "wafw00f pip install failed"

# =============================================================
# 5. SEARCHSPLOIT
# =============================================================
if ! command -v searchsploit &>/dev/null; then
    log "Installing searchsploit..."
    git clone --depth 1 https://gitlab.com/exploit-database/exploitdb.git /opt/exploitdb 2>/dev/null
    ln -sf /opt/exploitdb/searchsploit /usr/local/bin/searchsploit
    log "searchsploit installed"
fi

# =============================================================
# 6. SECLISTS
# =============================================================
if [ ! -d /usr/share/seclists ]; then
    log "Installing SecLists (this takes a moment)..."
    git clone --depth 1 https://github.com/danielmiessler/SecLists.git /usr/share/seclists
    log "SecLists installed"
else
    log "SecLists already present"
fi

# =============================================================
# 7. TOR CONFIGURATION
# =============================================================
log "Configuring Tor..."
cp "$SCRIPT_DIR/configs/tor/torrc" /etc/tor/torrc
mkdir -p /var/log/tor
chown debian-tor:debian-tor /var/log/tor 2>/dev/null || true

if [ "$HAS_SYSTEMD" = true ]; then
    systemctl enable tor 2>/dev/null || true
    systemctl restart tor@default 2>/dev/null || systemctl restart tor 2>/dev/null || warn "Tor systemd start failed"
else
    # Container mode: start Tor directly
    pkill tor 2>/dev/null || true
    tor &
    sleep 3
    if ss -tlnp | grep -q ":9050 "; then
        log "Tor started (direct mode)"
    else
        warn "Tor may not have started — run 'tor &' manually"
    fi
fi
log "Tor configured"

# =============================================================
# 8. PROXYCHAINS CONFIGURATION
# =============================================================
log "Configuring proxychains..."
cp "$SCRIPT_DIR/configs/proxychains/proxychains4.conf" /etc/proxychains4.conf
log "Proxychains configured"

# =============================================================
# 9. OLLAMA + UNCENSORED MODEL
# =============================================================
log "Installing Ollama..."
if ! command -v ollama &>/dev/null; then
    curl -fsSL https://ollama.ai/install.sh | sh
fi

# Start Ollama
if [ "$HAS_SYSTEMD" = true ]; then
    systemctl enable ollama 2>/dev/null || true
    systemctl start ollama 2>/dev/null || true
fi

# Wait for Ollama to be ready (or start manually)
info "Waiting for Ollama API..."
for i in $(seq 1 15); do
    if curl -s http://127.0.0.1:11434/api/tags &>/dev/null; then
        break
    fi
    sleep 2
done

if ! curl -s http://127.0.0.1:11434/api/tags &>/dev/null; then
    # No systemd or service failed — start manually
    info "Starting Ollama manually..."
    ollama serve &>/dev/null &
    sleep 5
fi

if curl -s http://127.0.0.1:11434/api/tags &>/dev/null; then
    log "Ollama running"
else
    warn "Ollama API not responding — run 'ollama serve &' manually"
fi

# Pull the uncensored model
info "Pulling huihui_ai/qwen3-abliterated:32b (this will take a while ~20GB)..."
ollama pull huihui_ai/qwen3-abliterated:32b
log "Model downloaded"

# Create custom Spectre model with embedded system prompt
log "Creating Spectre model..."
cp "$SCRIPT_DIR/configs/ollama/Modelfile" /tmp/Modelfile.spectre
ollama create spectre -f /tmp/Modelfile.spectre
rm /tmp/Modelfile.spectre
log "Spectre model created"

# Quick test
info "Testing model..."
RESPONSE=$(curl -s --max-time 120 http://127.0.0.1:11434/api/generate -d '{"model":"spectre","prompt":"Reply with only: READY","stream":false}' 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('response','FAIL'))" 2>/dev/null)
if echo "$RESPONSE" | grep -qi "ready"; then
    log "Model test passed"
else
    warn "Model test returned: $RESPONSE"
fi

# =============================================================
# 10. OPENCLAW
# =============================================================
log "Installing OpenClaw..."
if ! command -v openclaw &>/dev/null; then
    npm install -g openclaw 2>/dev/null || warn "OpenClaw npm install failed — install manually"
fi

# Workspace
WORKSPACE_DIR="/root/.openclaw/workspace"
mkdir -p "$WORKSPACE_DIR/scripts" "$WORKSPACE_DIR/engagements" "$WORKSPACE_DIR/wordlists" "$WORKSPACE_DIR/memory"
mkdir -p /root/.openclaw

cp "$SCRIPT_DIR/workspace/SOUL.md" "$WORKSPACE_DIR/"
cp "$SCRIPT_DIR/workspace/IDENTITY.md" "$WORKSPACE_DIR/"
cp "$SCRIPT_DIR/workspace/AGENTS.md" "$WORKSPACE_DIR/"
cp "$SCRIPT_DIR/workspace/TOOLS.md" "$WORKSPACE_DIR/"
cp "$SCRIPT_DIR/workspace/USER.md" "$WORKSPACE_DIR/"
cp "$SCRIPT_DIR/workspace/scripts/"*.sh "$WORKSPACE_DIR/scripts/"
chmod +x "$WORKSPACE_DIR/scripts/"*.sh

# Config — replace placeholders
cp "$SCRIPT_DIR/configs/openclaw.json" /root/.openclaw/openclaw.json
sed -i "s/__PASSWORD__/$DASHBOARD_PASSWORD/g" /root/.openclaw/openclaw.json
sed -i "s/__TOKEN__/$GATEWAY_TOKEN/g" /root/.openclaw/openclaw.json
sed -i "s/__VPS_IP__/$VPS_IP/g" /root/.openclaw/openclaw.json

cp "$SCRIPT_DIR/configs/exec-approvals.json" /root/.openclaw/exec-approvals.json

# Initialize OpenClaw
openclaw onboard --accept-risk 2>/dev/null || true
openclaw doctor --fix 2>/dev/null || true

# Set OLLAMA_API_KEY globally
export OLLAMA_API_KEY="ollama-local"
echo 'export OLLAMA_API_KEY="ollama-local"' >> /root/.bashrc

# Configure provider — auth-profiles.json
# IMPORTANT: provider name must NOT be "ollama" — OpenClaw auto-detects
# ollama providers and overrides contextWindow with the model's hardcoded
# llama.context_length (8192), ignoring our models.json values.
# Using "openai-compat" bypasses this and uses our contextWindow (32768).
mkdir -p /root/.openclaw/agents/main/agent
cat > /root/.openclaw/agents/main/agent/auth-profiles.json << 'AUTHJSON'
{
  "version": 1,
  "profiles": {
    "openai-compat:default": {
      "type": "api_key",
      "provider": "openai-compat",
      "key": "ollama-local"
    }
  }
}
AUTHJSON

# Configure models — models.json (via Ollama's OpenAI-compatible endpoint)
cat > /root/.openclaw/agents/main/agent/models.json << 'MODELJSON'
{
  "providers": {
    "openai-compat": {
      "baseUrl": "http://127.0.0.1:11434/v1",
      "api": "openai-completions",
      "apiKey": "ollama-local",
      "models": [
        {
          "id": "spectre:latest",
          "name": "Spectre (huihui_ai/qwen3-abliterated:32b uncensored)",
          "reasoning": false,
          "input": ["text"],
          "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0},
          "contextWindow": 32768,
          "maxTokens": 16384
        },
        {
          "id": "huihui_ai/qwen3-abliterated:32b",
          "name": "huihui_ai/qwen3-abliterated:32b",
          "reasoning": false,
          "input": ["text"],
          "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0},
          "contextWindow": 32768,
          "maxTokens": 16384
        }
      ]
    }
  }
}
MODELJSON

log "OpenClaw workspace deployed"

# =============================================================
# 11. HTTPS PROXY (Caddy + self-signed cert)
# =============================================================
log "Configuring HTTPS proxy..."

CERT_DIR="/etc/caddy/certs"
mkdir -p "$CERT_DIR"

openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
    -keyout "$CERT_DIR/key.pem" \
    -out "$CERT_DIR/cert.pem" \
    -subj "/CN=$VPS_IP" \
    -addext "subjectAltName=IP:$VPS_IP" 2>/dev/null

chown caddy:caddy "$CERT_DIR"/*.pem 2>/dev/null || chmod 644 "$CERT_DIR"/*.pem
chmod 640 "$CERT_DIR"/*.pem 2>/dev/null || true

# Deploy Caddyfile with token
cp "$SCRIPT_DIR/configs/caddy/Caddyfile" /etc/caddy/Caddyfile
sed -i "s/__TOKEN__/$GATEWAY_TOKEN/g" /etc/caddy/Caddyfile

if [ "$HAS_SYSTEMD" = true ]; then
    systemctl enable caddy 2>/dev/null || true
    systemctl restart caddy
else
    # Container mode: start Caddy directly
    caddy stop 2>/dev/null || true
    caddy start --config /etc/caddy/Caddyfile
fi
log "Caddy HTTPS configured for $VPS_IP"

# =============================================================
# 12. OPENCLAW GATEWAY
# =============================================================
log "Starting OpenClaw gateway..."

if [ "$HAS_SYSTEMD" = true ]; then
    mkdir -p /root/.config/systemd/user
    cp "$SCRIPT_DIR/configs/systemd/openclaw-gateway.service" /root/.config/systemd/user/
    loginctl enable-linger root 2>/dev/null || true
    export XDG_RUNTIME_DIR=/run/user/0
    systemctl --user daemon-reload
    systemctl --user enable openclaw-gateway
    systemctl --user start openclaw-gateway
else
    # Container mode: start gateway directly in background
    OLLAMA_API_KEY="ollama-local" openclaw gateway --port 18790 &>/dev/null &
    sleep 3
    if curl -s http://127.0.0.1:18790 &>/dev/null; then
        log "OpenClaw gateway running (direct mode)"
    else
        warn "OpenClaw gateway may not have started — run 'openclaw gateway --port 18790 &' manually"
    fi
fi

log "OpenClaw gateway started"

# =============================================================
# 12b. CLOUDFLARE TUNNEL (Vast.ai containers)
# =============================================================
DASHBOARD_URL="https://$VPS_IP/"
if [ "$HAS_SYSTEMD" = false ] && curl -s http://localhost:11112/ &>/dev/null; then
    log "Vast.ai detected — creating Cloudflare tunnel for dashboard..."
    TUNNEL_JSON=$(curl -s --max-time 30 "http://localhost:11112/get-quick-tunnel/http://localhost:18790" 2>/dev/null)
    TUNNEL_URL=$(echo "$TUNNEL_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tunnel_url',''))" 2>/dev/null)
    if [ -n "$TUNNEL_URL" ]; then
        log "Cloudflare tunnel created: $TUNNEL_URL"
        DASHBOARD_URL="$TUNNEL_URL"
        # Add tunnel URL to allowedOrigins
        python3 -c "
import json
with open('/root/.openclaw/openclaw.json') as f:
    cfg = json.load(f)
origins = cfg['gateway']['controlUi']['allowedOrigins']
if '$TUNNEL_URL' not in origins:
    origins.append('$TUNNEL_URL')
with open('/root/.openclaw/openclaw.json', 'w') as f:
    json.dump(cfg, f, indent=2)
"
        log "Added tunnel to allowedOrigins"
    else
        warn "Cloudflare tunnel creation failed — access gateway directly at http://$VPS_IP:18790"
    fi
else
    log "Direct IP access: $DASHBOARD_URL"
fi

# =============================================================
# 13. CLAUDE CLI
# =============================================================
log "Installing Claude CLI..."
npm install -g @anthropic-ai/claude-code 2>/dev/null || warn "Claude CLI install failed"

# Create the 'start' command
cp "$SCRIPT_DIR/start-context.md" /root/.spectre-context.md
sed -i "s/__VPS_IP__/$VPS_IP/g" /root/.spectre-context.md

cat > /usr/local/bin/start << 'STARTEOF'
#!/bin/bash
# Launch Claude CLI with full Spectre context
CONTEXT=$(cat /root/.spectre-context.md 2>/dev/null)
if [ -z "$CONTEXT" ]; then
    echo "Error: /root/.spectre-context.md not found"
    exit 1
fi
claude -p "$CONTEXT"
STARTEOF
chmod +x /usr/local/bin/start

log "Claude CLI installed — run 'claude /login' to authenticate, then 'start' to launch with context"

# =============================================================
# 14. STARTUP SCRIPT (for containers without systemd)
# =============================================================
if [ "$HAS_SYSTEMD" = false ]; then
    cat > /usr/local/bin/spectre-start-all << 'ALLEOF'
#!/bin/bash
# Start all Spectre services (for containers without systemd)
echo "[*] Starting Spectre services..."

# Tor
if ! pgrep -x tor &>/dev/null; then
    tor &
    sleep 3
    echo "[+] Tor started"
else
    echo "[+] Tor already running"
fi

# Ollama
if ! curl -s http://127.0.0.1:11434/api/tags &>/dev/null; then
    ollama serve &>/dev/null &
    sleep 5
    echo "[+] Ollama started"
else
    echo "[+] Ollama already running"
fi

# Caddy
if ! pgrep -x caddy &>/dev/null; then
    caddy start --config /etc/caddy/Caddyfile
    echo "[+] Caddy started"
else
    echo "[+] Caddy already running"
fi

# OpenClaw Gateway
if ! curl -s http://127.0.0.1:18790 &>/dev/null; then
    OLLAMA_API_KEY="ollama-local" openclaw gateway --port 18790 &>/dev/null &
    sleep 3
    echo "[+] OpenClaw gateway started"
else
    echo "[+] OpenClaw gateway already running"
fi

# Cloudflare tunnel (Vast.ai)
DASHBOARD_URL=""
if curl -s http://localhost:11112/ &>/dev/null; then
    TUNNEL_JSON=$(curl -s --max-time 30 "http://localhost:11112/get-quick-tunnel/http://localhost:18790" 2>/dev/null)
    TUNNEL_URL=$(echo "$TUNNEL_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tunnel_url',''))" 2>/dev/null)
    if [ -n "$TUNNEL_URL" ]; then
        DASHBOARD_URL="$TUNNEL_URL"
        # Update allowedOrigins
        python3 -c "
import json
with open('/root/.openclaw/openclaw.json') as f:
    cfg = json.load(f)
origins = cfg['gateway']['controlUi']['allowedOrigins']
if '$TUNNEL_URL' not in origins:
    origins.append('$TUNNEL_URL')
    with open('/root/.openclaw/openclaw.json', 'w') as f:
        json.dump(cfg, f, indent=2)
"
        echo "[+] Cloudflare tunnel: $TUNNEL_URL"
    fi
fi

if [ -z "$DASHBOARD_URL" ]; then
    VPS_IP=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null)
    DASHBOARD_URL="https://$VPS_IP/"
fi

echo ""
echo "========================================="
echo "  All services running"
echo "  Dashboard: $DASHBOARD_URL"
echo "========================================="
ALLEOF
    chmod +x /usr/local/bin/spectre-start-all

    # Auto-start services on login (first shell session triggers it)
    cat > /etc/profile.d/spectre-autostart.sh << 'PROFILEEOF'
# Spectre auto-start: launch services if not already running
if [ "$(id -u)" = "0" ] && ! curl -s http://127.0.0.1:18790 &>/dev/null 2>&1; then
    spectre-start-all
fi
PROFILEEOF
    chmod +x /etc/profile.d/spectre-autostart.sh
    log "Created auto-start hook in /etc/profile.d/"
    log "Created 'spectre-start-all' command for container restarts"
fi

# =============================================================
# DONE
# =============================================================
echo ""
echo "========================================="
echo "  SPECTRE INSTALLATION COMPLETE"
echo "========================================="
echo ""
echo "  Server IP:     $VPS_IP"
echo "  Dashboard:     $DASHBOARD_URL"
echo "  Password:      (the one you entered)"
echo "  Model:         spectre (huihui_ai/qwen3-abliterated:32b uncensored)"
echo "  Ollama API:    http://127.0.0.1:11434"
echo ""
echo "  Next steps:"
echo "  1. Run: claude /login"
echo "  2. Open $DASHBOARD_URL in your browser"
echo "  3. Enter your password to connect"
echo "  4. Approve device: openclaw devices list && openclaw devices approve <id>"
echo ""
echo "  Commands:"
echo "  - start              → Launch Claude CLI with full Spectre context"
echo "  - spectre-start-all  → Restart all services (container mode)"
echo "  - ollama list        → Show installed models"
echo "  - opsec-check.sh     → Verify OPSEC"
echo ""
echo "========================================="
