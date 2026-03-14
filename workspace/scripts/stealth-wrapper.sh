#!/bin/bash
# stealth-wrapper.sh — Wrap any command through proxychains + random delay
# Usage: ./stealth-wrapper.sh <command> [args...]
# Example: ./stealth-wrapper.sh nmap -sV target.com
#          ./stealth-wrapper.sh curl https://target.com

if [ $# -eq 0 ]; then
    echo "Usage: $0 <command> [args...]"
    exit 1
fi

# Random delay 1-5s to avoid pattern detection
DELAY=$((RANDOM % 5 + 1))
echo "[*] Stealth delay: ${DELAY}s"
sleep $DELAY

# Random User-Agent for HTTP tools
export HTTP_USER_AGENTS=(
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.2 Safari/605.1.15"
    "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:128.0) Gecko/20100101 Firefox/128.0"
    "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
)
RANDOM_UA=${HTTP_USER_AGENTS[$((RANDOM % ${#HTTP_USER_AGENTS[@]}))]}
export RANDOM_UA

echo "[*] User-Agent: $(echo $RANDOM_UA | cut -c1-50)..."
echo "[*] Running: proxychains4 -q $@"

proxychains4 -q "$@"
