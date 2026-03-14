#!/bin/bash
# tor-rotate.sh — Force Tor to use a new circuit (new exit IP)
# Usage: ./tor-rotate.sh [optional: number of rotations with delay]

rotate_circuit() {
    # Send NEWNYM signal via control port
    echo -e 'AUTHENTICATE ""\r\nSIGNAL NEWNYM\r\nQUIT' | nc 127.0.0.1 9054 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "[+] Tor circuit rotated"
    else
        # Fallback: restart tor
        systemctl restart tor@default
        echo "[+] Tor restarted (fallback rotation)"
    fi
}

check_ip() {
    IP=$(curl --socks5-hostname 127.0.0.1:9050 -s --max-time 10 https://check.torproject.org/api/ip 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('IP','unknown'))" 2>/dev/null)
    echo "[*] Current exit IP: ${IP:-unknown}"
}

if [ "$1" == "--loop" ]; then
    INTERVAL=${2:-30}
    echo "[*] Rotating every ${INTERVAL}s (Ctrl+C to stop)"
    while true; do
        rotate_circuit
        sleep 2
        check_ip
        sleep $INTERVAL
    done
elif [ "$1" == "--check" ]; then
    check_ip
else
    rotate_circuit
    sleep 2
    check_ip
fi
