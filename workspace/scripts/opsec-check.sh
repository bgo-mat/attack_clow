#!/bin/bash
# opsec-check.sh — Pre-engagement OPSEC verification
# Run before any engagement to verify anonymity

echo "========================================="
echo "  SPECTRE OPSEC PRE-FLIGHT CHECK"
echo "========================================="
echo ""

# 1. Check Tor status
echo "[1] Tor Service"
if systemctl is-active --quiet tor@default; then
    echo "    [OK] Tor is running"
else
    echo "    [FAIL] Tor is NOT running"
    echo "    Fix: systemctl restart tor@default"
fi

# 2. Check SOCKS ports
echo ""
echo "[2] SOCKS Proxy Ports"
for port in 9050 9051 9052 9053; do
    if ss -tlnp | grep -q ":${port} "; then
        echo "    [OK] Port ${port} listening"
    else
        echo "    [FAIL] Port ${port} not listening"
    fi
done

# 3. Check Tor exit IP
echo ""
echo "[3] Tor Exit IP"
TOR_IP=$(curl --socks5-hostname 127.0.0.1:9050 -s --max-time 15 https://check.torproject.org/api/ip 2>/dev/null)
if [ -n "$TOR_IP" ]; then
    echo "    [OK] Exit IP: $(echo $TOR_IP | python3 -c "import sys,json; print(json.load(sys.stdin).get('IP','unknown'))" 2>/dev/null)"
    IS_TOR=$(echo $TOR_IP | python3 -c "import sys,json; print(json.load(sys.stdin).get('IsTor', False))" 2>/dev/null)
    echo "    [OK] Is Tor: $IS_TOR"
else
    echo "    [FAIL] Cannot reach Tor network"
fi

# 4. Check real IP (direct)
echo ""
echo "[4] Real VPS IP (direct — NOT through Tor)"
REAL_IP=$(curl -s --max-time 10 https://api.ipify.org 2>/dev/null)
echo "    Real IP: ${REAL_IP:-unknown}"

# 5. Check DNS leaks
echo ""
echo "[5] DNS Leak Check"
echo "    Proxychains DNS proxy: $(grep -c 'proxy_dns' /etc/proxychains4.conf 2>/dev/null) entries"
if grep -q "^proxy_dns" /etc/proxychains4.conf 2>/dev/null; then
    echo "    [OK] DNS proxying enabled in proxychains"
else
    echo "    [WARN] DNS proxying NOT enabled — DNS leaks possible"
fi

# 6. Check proxychains config
echo ""
echo "[6] Proxychains Config"
CHAIN_TYPE=$(grep -E "^(dynamic_chain|strict_chain|random_chain)" /etc/proxychains4.conf 2>/dev/null)
echo "    Chain type: ${CHAIN_TYPE:-unknown}"
PROXY_COUNT=$(grep -cE "^socks[45]|^http" /etc/proxychains4.conf 2>/dev/null)
echo "    Proxies configured: ${PROXY_COUNT}"

# 7. Verify proxychains works
echo ""
echo "[7] Proxychains Test"
PC_IP=$(proxychains4 -q curl -s --max-time 15 https://api.ipify.org 2>/dev/null)
if [ -n "$PC_IP" ] && [ "$PC_IP" != "$REAL_IP" ]; then
    echo "    [OK] Proxychains IP: $PC_IP (different from real IP)"
else
    echo "    [WARN] Proxychains IP: ${PC_IP:-failed} — may match real IP!"
fi

echo ""
echo "========================================="
echo "  CHECK COMPLETE"
echo "========================================="
