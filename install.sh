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
    hydra medusa john hashcat \
    gdb binwalk ltrace strace \
    proxychains4 tor \
    curl httpie jq whois dnsutils \
    tmux git unzip wget \
    python3 python3-pip \
    whatweb nikto \
    ruby rubygems libyajl-dev \
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
" 2>/dev/null) || true
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
install_go_tool katana projectdiscovery/katana

# Go tools via go install (require Go SDK)
log "Installing Go SDK and additional tools..."
if ! command -v go &>/dev/null; then
    wget -q https://go.dev/dl/go1.23.6.linux-amd64.tar.gz -O /tmp/go.tar.gz && \
        tar -C /usr/local -xzf /tmp/go.tar.gz && rm /tmp/go.tar.gz || warn "Go SDK install failed"
fi
export GOPATH=/root/go PATH=$PATH:/usr/local/go/bin:/root/go/bin

for gotool in \
    "github.com/owasp-amass/amass/v4/...@master" \
    "github.com/projectdiscovery/interactsh/cmd/interactsh-client@latest" \
    "github.com/hahwul/dalfox/v2@latest" \
    "github.com/jpillora/chisel@latest"; do
    name=$(basename "${gotool%%@*}" | sed 's|/cmd/||; s|/\.\.\.$||; s|.*/||')
    if ! command -v "$name" &>/dev/null; then
        go install "$gotool" 2>/dev/null && log "$name installed" || warn "$name install failed"
    fi
done
# Symlink Go tools
for bin in /root/go/bin/*; do
    [ -f "$bin" ] && ln -sf "$bin" "/usr/local/bin/$(basename "$bin")" 2>/dev/null
done

# Kiterunner (API fuzzer)
if ! command -v kr &>/dev/null; then
    curl -sL https://github.com/assetnote/kiterunner/releases/download/v1.0.2/kiterunner_1.0.2_linux_amd64.tar.gz | tar xz -C /usr/local/bin kr 2>/dev/null && \
        chmod +x /usr/local/bin/kr && log "kiterunner installed" || warn "kiterunner install failed"
fi

# LinPEAS / WinPEAS
mkdir -p /opt/peass
curl -sL https://github.com/peass-ng/PEASS-ng/releases/latest/download/linpeas.sh -o /opt/peass/linpeas.sh && chmod +x /opt/peass/linpeas.sh
curl -sL https://github.com/peass-ng/PEASS-ng/releases/latest/download/winPEASx64.exe -o /opt/peass/winpeas.exe
log "LinPEAS/WinPEAS installed"

# =============================================================
# 4. PIP TOOLS
# =============================================================
log "Installing pip tools..."
pip3 install --break-system-packages wafw00f commix arjun impacket 2>/dev/null || warn "Some pip tools failed"
pip3 install --break-system-packages pipx 2>/dev/null && pipx install git+https://github.com/Pennyw0rth/NetExec.git 2>/dev/null || warn "NetExec install failed"
# Symlink pipx tools
for bin in /root/.local/bin/*; do
    [ -f "$bin" ] && ln -sf "$bin" "/usr/local/bin/$(basename "$bin")" 2>/dev/null
done

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
# 6b. METASPLOIT FRAMEWORK
# =============================================================
if ! command -v msfconsole &>/dev/null; then
    log "Installing Metasploit Framework (this takes a while)..."
    curl -s https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb > /tmp/msfinstall && \
        chmod +x /tmp/msfinstall && /tmp/msfinstall 2>/dev/null && \
        log "Metasploit installed" || warn "Metasploit install failed"
    rm -f /tmp/msfinstall
fi

# =============================================================
# 6c. MCP SECURITY HUB + PLAYWRIGHT MCP
# =============================================================
log "Installing MCP security servers..."
if [ ! -d /opt/mcp-security-hub ]; then
    git clone --depth 1 https://github.com/FuzzingLabs/mcp-security-hub /opt/mcp-security-hub 2>/dev/null || warn "MCP security hub clone failed"
fi
pip3 install --break-system-packages mcp 2>/dev/null || true
if [ -d /opt/mcp-security-hub ]; then
    for mcp_dir in /opt/mcp-security-hub/*/; do
        for srv in "$mcp_dir"*/; do
            [ -f "$srv/requirements.txt" ] && pip3 install --break-system-packages -q -r "$srv/requirements.txt" 2>/dev/null || true
        done
    done
fi
npm install -g @playwright/mcp 2>/dev/null || warn "Playwright MCP install failed"
log "MCP servers installed"

# =============================================================
# 7. TOR CONFIGURATION
# =============================================================
log "Configuring Tor..."
cp "$SCRIPT_DIR/configs/tor/torrc" /etc/tor/torrc 2>/dev/null || warn "Tor config copy failed"
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
cp "$SCRIPT_DIR/configs/proxychains/proxychains4.conf" /etc/proxychains4.conf 2>/dev/null || warn "Proxychains config copy failed"
log "Proxychains configured"

# =============================================================
# 9. OLLAMA + UNCENSORED MODEL
# =============================================================
log "Installing Ollama..."
if ! command -v ollama &>/dev/null; then
    curl -fsSL https://ollama.ai/install.sh | sh || warn "Ollama install script failed — will retry manually"
fi

if ! command -v ollama &>/dev/null; then
    warn "Ollama binary not found after install attempt — skipping model pull"
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
if command -v ollama &>/dev/null; then
    info "Pulling huihui_ai/qwen3.5-abliterated:122b (this will take a while ~70GB)..."
    ollama pull huihui_ai/qwen3.5-abliterated:122b || warn "Model pull failed — retry with: ollama pull huihui_ai/qwen3.5-abliterated:122b"
    log "Model download attempted"

    # Create custom Spectre model with embedded system prompt
    log "Creating Spectre model..."
    cp "$SCRIPT_DIR/configs/ollama/Modelfile" /tmp/Modelfile.spectre
    ollama create spectre -f /tmp/Modelfile.spectre || warn "Spectre model creation failed"
    rm -f /tmp/Modelfile.spectre
    log "Spectre model created"

    # Quick test
    info "Testing model..."
    RESPONSE=$(curl -s --max-time 180 http://127.0.0.1:11434/api/generate -d '{"model":"spectre","prompt":"Reply with only: READY","stream":false}' 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('response','FAIL'))" 2>/dev/null) || RESPONSE="TIMEOUT_OR_ERROR"
    if echo "$RESPONSE" | grep -qi "ready"; then
        log "Model test passed"
    else
        warn "Model test returned: $RESPONSE (model may still be loading — this is normal for 122B)"
    fi
else
    warn "Ollama not available — skipping model pull and test. Install manually: curl -fsSL https://ollama.ai/install.sh | sh"
fi

# =============================================================
# 10. OPENCLAW
# =============================================================
log "Installing OpenClaw..."
if ! command -v openclaw &>/dev/null; then
    npm install -g openclaw || warn "OpenClaw npm install failed — install manually"
fi

# Workspace
WORKSPACE_DIR="/root/.openclaw/workspace"
mkdir -p "$WORKSPACE_DIR/scripts" "$WORKSPACE_DIR/engagements" "$WORKSPACE_DIR/wordlists" "$WORKSPACE_DIR/memory"
mkdir -p /root/.openclaw

cp "$SCRIPT_DIR/workspace/SOUL.md" "$WORKSPACE_DIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/workspace/IDENTITY.md" "$WORKSPACE_DIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/workspace/AGENTS.md" "$WORKSPACE_DIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/workspace/TOOLS.md" "$WORKSPACE_DIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/workspace/USER.md" "$WORKSPACE_DIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/workspace/scripts/"*.sh "$WORKSPACE_DIR/scripts/" 2>/dev/null || true
chmod +x "$WORKSPACE_DIR/scripts/"*.sh 2>/dev/null || true

# Config — will be deployed AFTER onboard (step 15) to avoid being overwritten
# Just copy exec-approvals now (not touched by onboard)
cp "$SCRIPT_DIR/configs/exec-approvals.json" /root/.openclaw/exec-approvals.json 2>/dev/null || true

# Set OLLAMA_API_KEY and Go paths globally
export OLLAMA_API_KEY="ollama-local"
grep -qxF 'export OLLAMA_API_KEY="ollama-local"' /root/.bashrc 2>/dev/null || \
    echo 'export OLLAMA_API_KEY="ollama-local"' >> /root/.bashrc
grep -qxF 'export PATH=$PATH:/usr/local/go/bin:/root/go/bin' /root/.bashrc 2>/dev/null || \
    echo 'export PATH=$PATH:/usr/local/go/bin:/root/go/bin' >> /root/.bashrc

log "OpenClaw files deployed (onboard will run at the end)"

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
cp "$SCRIPT_DIR/configs/caddy/Caddyfile" /etc/caddy/Caddyfile 2>/dev/null || warn "Caddyfile copy failed"
[ -f /etc/caddy/Caddyfile ] && sed -i "s/__TOKEN__/$GATEWAY_TOKEN/g" /etc/caddy/Caddyfile

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
# 12. HTTPS DASHBOARD URL (determined before gateway start)
# =============================================================
DASHBOARD_URL="https://$VPS_IP/"

# =============================================================
# 13. CLAUDE CLI
# =============================================================
log "Installing Claude CLI..."
npm install -g @anthropic-ai/claude-code || warn "Claude CLI install failed"

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

# Watchdog
if [ -x /usr/local/bin/openclaw-watchdog ]; then
    if command -v crontab &>/dev/null; then
        (crontab -l 2>/dev/null | grep -v openclaw-watchdog; echo "*/2 * * * * /usr/local/bin/openclaw-watchdog") | crontab -
        service cron start 2>/dev/null || true
        echo "[+] Watchdog cron ensured"
    elif ! pgrep -f openclaw-watchdog-loop &>/dev/null; then
        nohup /usr/local/bin/openclaw-watchdog-loop &>/dev/null &
        disown
        echo "[+] Watchdog loop started"
    fi
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
# 15. OPENCLAW ONBOARD + CONFIGURATION (non-interactive)
# =============================================================
# Use --non-interactive with all required flags to avoid the
# interactive wizard dialog that blocks the rest of installation.
log "Initializing OpenClaw (non-interactive setup)..."
if command -v openclaw &>/dev/null; then
    openclaw onboard \
        --non-interactive \
        --accept-risk \
        --mode local \
        --flow quickstart \
        --auth-choice ollama \
        --gateway-auth password \
        --gateway-password "$DASHBOARD_PASSWORD" \
        --gateway-token "$GATEWAY_TOKEN" \
        --gateway-port 18790 \
        --gateway-bind lan \
        --workspace /root/.openclaw/workspace \
        --skip-channels \
        --skip-skills \
        --skip-search \
        --skip-daemon \
        --skip-health \
        --skip-ui \
        2>/dev/null || warn "openclaw onboard failed — will configure manually"
    openclaw doctor --fix 2>/dev/null || true
else
    warn "OpenClaw not installed — skipping onboard"
fi

# Deploy our pre-built openclaw.json AFTER onboard/doctor to avoid being overwritten
log "Deploying pre-built OpenClaw config (overrides onboard defaults)..."
cp "$SCRIPT_DIR/configs/openclaw.json" /root/.openclaw/openclaw.json 2>/dev/null || warn "openclaw.json template copy failed"
if [ -f /root/.openclaw/openclaw.json ]; then
    sed -i "s/__PASSWORD__/$DASHBOARD_PASSWORD/g" /root/.openclaw/openclaw.json
    sed -i "s/__TOKEN__/$GATEWAY_TOKEN/g" /root/.openclaw/openclaw.json
    sed -i "s/__VPS_IP__/$VPS_IP/g" /root/.openclaw/openclaw.json
fi

# Configure provider AFTER doctor (doctor auto-detects ollama and
# overwrites models.json — we re-write it with our config).
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
          "name": "Spectre (122B uncensored)",
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

# Fix openclaw.json — onboard/doctor overwrite the model primary
# with ollama provider. Force it back to openai-compat/spectre:latest.
python3 -c "
import json
with open('/root/.openclaw/openclaw.json') as f:
    cfg = json.load(f)
defaults = cfg.get('agents', {}).get('defaults', {})
defaults['model'] = {'primary': 'openai-compat/spectre:latest', 'fallbacks': []}
defaults['models'] = {'openai-compat/spectre:latest': {'alias': 'Spectre (122B uncensored)'}}
with open('/root/.openclaw/openclaw.json', 'w') as f:
    json.dump(cfg, f, indent=2)
" || warn "Failed to fix openclaw.json model config"

log "OpenClaw configured"

# =============================================================
# 15b. CLAWHUB SKILLS
# =============================================================
log "Installing ClawHub skills..."
SKILLS="auto-security-audit pentest-api-attacker pentest-auth-bypass sql-injection-testing nmap-pentest-scans security-scanner metasploit-skill context-budgeting memory-manager memory-tiering parallel-agents tmux-agents autonomous-execution claude-code-supervisor clawsec-suite"
for skill in $SKILLS; do
    if [ ! -d "/root/.openclaw/workspace/skills/$skill" ]; then
        npx clawhub@latest install "$skill" --force 2>/dev/null && \
            log "Skill $skill installed" || { warn "Skill $skill failed"; true; }
        sleep 2
    else
        log "Skill $skill already installed"
    fi
done
log "ClawHub skills installed"

# =============================================================
# 16. OPENCLAW GATEWAY
# =============================================================
log "Starting OpenClaw gateway..."

if command -v openclaw &>/dev/null; then
    if [ "$HAS_SYSTEMD" = true ]; then
        mkdir -p /root/.config/systemd/user
        cp "$SCRIPT_DIR/configs/systemd/openclaw-gateway.service" /root/.config/systemd/user/ 2>/dev/null || true
        loginctl enable-linger root 2>/dev/null || true
        export XDG_RUNTIME_DIR=/run/user/0
        systemctl --user daemon-reload 2>/dev/null || true
        systemctl --user enable openclaw-gateway 2>/dev/null || true
        systemctl --user start openclaw-gateway 2>/dev/null || true
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
else
    warn "OpenClaw not installed — skipping gateway start"
fi

log "OpenClaw gateway started"

# =============================================================
# 16b. CLOUDFLARE TUNNEL (Vast.ai containers)
# =============================================================
if [ "$HAS_SYSTEMD" = false ] && curl -s http://localhost:11112/ &>/dev/null; then
    log "Vast.ai detected — creating Cloudflare tunnel for dashboard..."
    TUNNEL_JSON=$(curl -s --max-time 30 "http://localhost:11112/get-quick-tunnel/http://localhost:18790" 2>/dev/null)
    TUNNEL_URL=$(echo "$TUNNEL_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tunnel_url',''))" 2>/dev/null) || true
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
" || warn "Failed to update allowedOrigins"
        log "Added tunnel to allowedOrigins"
    else
        warn "Cloudflare tunnel creation failed — access gateway directly at http://$VPS_IP:18790"
    fi
fi

# =============================================================
# 17. WATCHDOG — Auto-restart for stuck/crashed gateway
# =============================================================
log "Setting up OpenClaw watchdog..."

cp "$SCRIPT_DIR/scripts/openclaw-watchdog.sh" /usr/local/bin/openclaw-watchdog 2>/dev/null || warn "Watchdog script copy failed"
chmod +x /usr/local/bin/openclaw-watchdog 2>/dev/null || true
touch /var/log/openclaw-watchdog.log

if [ "$HAS_SYSTEMD" = true ]; then
    cat > /root/.config/systemd/user/openclaw-watchdog.service << 'WDSVC'
[Unit]
Description=OpenClaw Watchdog Check

[Service]
Type=oneshot
ExecStart=/usr/local/bin/openclaw-watchdog
Environment=HOME=/root
Environment=PATH=/usr/local/bin:/usr/bin:/bin
WDSVC

    cat > /root/.config/systemd/user/openclaw-watchdog.timer << 'WDTMR'
[Unit]
Description=Run OpenClaw watchdog every 2 minutes

[Timer]
OnBootSec=120
OnUnitActiveSec=120

[Install]
WantedBy=timers.target
WDTMR

    export XDG_RUNTIME_DIR=/run/user/0
    systemctl --user daemon-reload
    systemctl --user enable openclaw-watchdog.timer
    systemctl --user start openclaw-watchdog.timer
    log "Watchdog systemd timer configured (every 2 min)"
else
    if command -v crontab &>/dev/null; then
        (crontab -l 2>/dev/null | grep -v openclaw-watchdog; echo "*/2 * * * * /usr/local/bin/openclaw-watchdog") | crontab -
        service cron start 2>/dev/null || crond 2>/dev/null || true
        log "Watchdog cron configured (every 2 min)"
    else
        cat > /usr/local/bin/openclaw-watchdog-loop << 'LOOPEOF'
#!/bin/bash
while true; do
    /usr/local/bin/openclaw-watchdog
    sleep 120
done
LOOPEOF
        chmod +x /usr/local/bin/openclaw-watchdog-loop
        nohup /usr/local/bin/openclaw-watchdog-loop &>/dev/null &
        disown
        log "Watchdog background loop started (every 2 min)"
    fi
fi

log "Watchdog setup complete"

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
echo "  Model:         spectre (huihui_ai/qwen3.5-abliterated:122b uncensored)"
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
echo "  - openclaw-watchdog   → Auto-restart stuck sessions (every 2 min)"
echo "  - opsec-check.sh     → Verify OPSEC"
echo ""
echo "========================================="
