#!/bin/bash
# =============================================================
# Attack Claw — Spectre Pentest Agent — Automated Installation
# =============================================================
# Usage: git clone ... && cd attack_clow && chmod +x install.sh && ./install.sh
#
# Requirements: Debian/Ubuntu server with GPU, root access
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
systemctl enable tor 2>/dev/null || true
systemctl restart tor@default 2>/dev/null || systemctl restart tor 2>/dev/null || warn "Tor start failed — may need manual config"
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

# Start Ollama service
systemctl enable ollama 2>/dev/null || true
systemctl start ollama 2>/dev/null || true

# Wait for Ollama to be ready
info "Waiting for Ollama API..."
for i in $(seq 1 30); do
    if curl -s http://127.0.0.1:11434/api/tags &>/dev/null; then
        break
    fi
    sleep 2
done

if ! curl -s http://127.0.0.1:11434/api/tags &>/dev/null; then
    # Ollama might not have systemd — start manually in background
    ollama serve &>/dev/null &
    sleep 5
fi

log "Ollama running"

# Pull the uncensored model
info "Pulling dolphin-llama3.1:70b-q4_K_M (this will take a while ~40GB)..."
ollama pull dolphin-llama3.1:70b-q4_K_M
log "Model downloaded"

# Create custom Spectre model with embedded system prompt
log "Creating Spectre model..."
cp "$SCRIPT_DIR/configs/ollama/Modelfile" /tmp/Modelfile.spectre
ollama create spectre -f /tmp/Modelfile.spectre
rm /tmp/Modelfile.spectre
log "Spectre model created"

# Quick test
info "Testing model..."
RESPONSE=$(curl -s http://127.0.0.1:11434/api/generate -d '{"model":"spectre","prompt":"Reply with only: READY","stream":false}' 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('response','FAIL'))" 2>/dev/null)
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

# Run onboard to initialize
openclaw onboard --accept-risk 2>/dev/null || true

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

chown caddy:caddy "$CERT_DIR"/*.pem 2>/dev/null || true
chmod 640 "$CERT_DIR"/*.pem

# Deploy Caddyfile with token
cp "$SCRIPT_DIR/configs/caddy/Caddyfile" /etc/caddy/Caddyfile
sed -i "s/__TOKEN__/$GATEWAY_TOKEN/g" /etc/caddy/Caddyfile

systemctl enable caddy 2>/dev/null || true
systemctl restart caddy
log "Caddy HTTPS configured for $VPS_IP"

# =============================================================
# 12. OPENCLAW GATEWAY SERVICE
# =============================================================
log "Setting up OpenClaw gateway service..."

mkdir -p /root/.config/systemd/user
cp "$SCRIPT_DIR/configs/systemd/openclaw-gateway.service" /root/.config/systemd/user/

loginctl enable-linger root 2>/dev/null || true

export XDG_RUNTIME_DIR=/run/user/0
systemctl --user daemon-reload
systemctl --user enable openclaw-gateway
systemctl --user start openclaw-gateway

log "OpenClaw gateway started"

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
# DONE
# =============================================================
echo ""
echo "========================================="
echo "  SPECTRE INSTALLATION COMPLETE"
echo "========================================="
echo ""
echo "  Server IP:     $VPS_IP"
echo "  Dashboard:     https://$VPS_IP/"
echo "  Password:      (the one you entered)"
echo "  Model:         spectre (dolphin-llama3.1:70b uncensored)"
echo "  Ollama API:    http://127.0.0.1:11434"
echo ""
echo "  Next steps:"
echo "  1. Run: claude /login"
echo "  2. Open https://$VPS_IP/ in your browser"
echo "  3. Accept the self-signed certificate"
echo "  4. Enter your password to connect"
echo "  5. Approve device: openclaw devices list && openclaw devices approve <id>"
echo ""
echo "  Commands:"
echo "  - start           → Launch Claude CLI with full Spectre context"
echo "  - ollama list     → Show installed models"
echo "  - scripts/opsec-check.sh → Verify OPSEC"
echo ""
echo "========================================="
