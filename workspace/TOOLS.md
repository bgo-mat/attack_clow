# TOOLS.md - Spectre's Arsenal

## OPSEC / Anonymity (USE THESE FIRST)
- **tor** — `/usr/sbin/tor` — Onion routing, 4 SOCKS ports (9050-9053), circuit rotation every 30s
- **proxychains4** — `/usr/bin/proxychains4` — Route ANY tool through Tor. Usage: `proxychains4 -q <command>`
- **scripts/opsec-check.sh** — Pre-flight anonymity verification
- **scripts/tor-rotate.sh** — Force new Tor circuit (new exit IP). Usage: `--check` (show IP), `--loop 30` (rotate every 30s)
- **scripts/stealth-wrapper.sh** — Wrap command with proxychains + random delay + random User-Agent
- **socat** — `/usr/bin/socat` — Advanced relay, tunneling, port forwarding

## Passive Reconnaissance
- **subfinder** — `/usr/local/bin/subfinder` — Passive subdomain discovery (APIs, no direct target contact)
- **whois** — `/usr/bin/whois` — Domain registration lookup
- **dnsutils** — dig, nslookup, host (ALWAYS through proxychains)

## Active Reconnaissance
- **nmap** — `/usr/bin/nmap` — Port scanning, service detection, NSE scripts. Stealth: `-sT -T2 --scan-delay 1s --data-length 50`
- **masscan** — `/usr/bin/masscan` — High-speed port scanning (use sparingly — very noisy)
- **whatweb** — `/usr/bin/whatweb` — Web technology fingerprinting
- **wafw00f** — `wafw00f` — WAF detection and identification. Run BEFORE any web fuzzing

## Web Application Testing
- **ffuf** — `/usr/bin/ffuf` — Fast web fuzzer (dirs, params, vhosts). Stealth: `-rate 10`
- **gobuster** — `/usr/bin/gobuster` — Directory/DNS/vhost brute-forcing
- **dirb** — `/usr/bin/dirb` — Web content scanner
- **sqlmap** — `/usr/bin/sqlmap` — Automated SQL injection. Stealth: `--random-agent --delay=1 --tor`
- **wfuzz** — `/usr/bin/wfuzz` — Web fuzzer
- **nuclei** — `/usr/local/bin/nuclei` — Template-based vulnerability scanner. Stealth: `-rate-limit 5`
- **httpx** — `/usr/local/bin/httpx` — Fast HTTP probe and tech detection

## Credential Attacks
- **hydra** — `/usr/bin/hydra` — Online password brute-forcing. Stealth: `-t 2 -W 3`
- **medusa** — `/usr/bin/medusa` — Parallel login brute-forcer
- **john** — `/usr/sbin/john` — Offline password cracking (John the Ripper)

## Exploitation
- **searchsploit** — `/usr/local/bin/searchsploit` — Exploit-DB local search
- **python3** — `/usr/bin/python3` — Custom exploit scripts
- **netcat** — `/usr/bin/nc` — Reverse shells, port listening

## Reverse Engineering
- **radare2 (r2)** — `/usr/bin/r2` — Binary analysis framework
- **gdb** — `/usr/bin/gdb` — GNU debugger
- **binwalk** — `/usr/bin/binwalk` — Firmware analysis, file carving
- **ltrace** — `/usr/bin/ltrace` — Library call tracer
- **strace** — `/usr/bin/strace` — System call tracer
- **strings** — `/usr/bin/strings` — Extract printable strings from binaries

## Utilities
- **curl** — HTTP client (use `--socks5-hostname 127.0.0.1:9050` for Tor)
- **httpie** — Human-friendly HTTP client
- **jq** — JSON processor
- **tmux** — Terminal multiplexer for persistent sessions
- **python3-pip** — Python package manager

## Wordlists
- `/usr/share/seclists/` — **SecLists** (full collection): Discovery, Passwords, Fuzzing, etc.
  - Web content: `/usr/share/seclists/Discovery/Web-Content/`
  - Passwords: `/usr/share/seclists/Passwords/`
  - Subdomains: `/usr/share/seclists/Discovery/DNS/`
  - Usernames: `/usr/share/seclists/Usernames/`
- `/usr/share/dirb/wordlists/` — DIRB wordlists (common.txt, big.txt)
- `/root/.openclaw/workspace/wordlists/` — Custom wordlists

## Notes
- All tools run as root — no sudo needed
- **ALWAYS use proxychains4 for offensive commands** — see SOUL.md OPSEC rules
- For long-running scans, use tmux or background processes
- Save all scan outputs to `engagements/<target>/scans/`
- Rotate Tor circuit between scan phases: `scripts/tor-rotate.sh`
