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
- **amass** — `/usr/local/bin/amass` — Advanced subdomain enum with 50+ sources, ASN discovery, DNS brute. Superior to subfinder
- **whois** — `/usr/bin/whois` — Domain registration lookup
- **dnsutils** — dig, nslookup, host (ALWAYS through proxychains)
- **katana** — `/usr/local/bin/katana` — Web crawler/spider (ProjectDiscovery). Crawls JS, extracts endpoints
- **interactsh-client** — `/usr/local/bin/interactsh-client` — OOB interaction server for blind SSRF/XSS/RCE testing

## Active Reconnaissance
- **nmap** — `/usr/bin/nmap` — Port scanning, service detection, NSE scripts. Stealth: `-sT -T2 --scan-delay 1s --data-length 50`. **Tor limitation:** Only -sT works through proxychains/Tor. -sS/-sU/-O require raw sockets and will fail silently.
- **masscan** — `/usr/bin/masscan` — High-speed port scanning (use sparingly — very noisy)
- **whatweb** — `/usr/bin/whatweb` — Web technology fingerprinting
- **wafw00f** — `wafw00f` — WAF detection and identification. Run BEFORE any web fuzzing
- **nikto** — `/usr/bin/nikto` — Web server vulnerability scanner (7000+ checks)

## Web Application Testing
- **ffuf** — `/usr/bin/ffuf` — Fast web fuzzer (dirs, params, vhosts). Stealth: `-rate 10`. **Tips:** Use `-mc 200,301,302` to filter noise. Use `-H "User-Agent: Mozilla/5.0 ..."` to bypass basic bot detection. If all 403 → likely CDN/WAF, find real IP first.
- **gobuster** — `/usr/bin/gobuster` — Directory/DNS/vhost brute-forcing
- **dirb** — `/usr/bin/dirb` — Web content scanner
- **sqlmap** — `/usr/bin/sqlmap` — Automated SQL injection. Stealth: `--random-agent --delay=1 --tor`
- **wfuzz** — `/usr/bin/wfuzz` — Web fuzzer
- **nuclei** — `/usr/local/bin/nuclei` — Template-based vulnerability scanner. Stealth: `-rate-limit 5`
- **httpx** — `/usr/local/bin/httpx` — Fast HTTP probe and tech detection
- **dalfox** — `/usr/local/bin/dalfox` — Specialized XSS scanner with DOM analysis
- **commix** — `commix` — Automated OS command injection detection and exploitation
- **arjun** — `arjun` — Hidden HTTP parameter discovery
- **kiterunner (kr)** — `/usr/local/bin/kr` — API endpoint brute-forcer with REST-aware wordlists

## Credential Attacks
- **hydra** — `/usr/bin/hydra` — Online password brute-forcing. Stealth: `-t 2 -W 3`
- **medusa** — `/usr/bin/medusa` — Parallel login brute-forcer
- **john** — `/usr/sbin/john` — Offline password cracking (John the Ripper)
- **hashcat** — `/usr/bin/hashcat` — GPU-accelerated hash cracking (350+ hash types). Much faster than John

## Exploitation
- **msfconsole** — `/opt/metasploit-framework/bin/msfconsole` — Metasploit Framework (exploit modules, payloads, post-exploitation)
- **searchsploit** — `/usr/local/bin/searchsploit` — Exploit-DB local search
- **python3** — `/usr/bin/python3` — Custom exploit scripts
- **netcat** — `/usr/bin/nc` — Reverse shells, port listening
- **chisel** — `/usr/local/bin/chisel` — TCP/UDP tunnel over HTTP for network pivoting

## Post-Exploitation
- **impacket** — `psexec.py`, `secretsdump.py`, `smbexec.py` — Windows/AD attacks (pass-the-hash, Kerberoasting, etc.)
- **nxc (NetExec)** — `/usr/local/bin/nxc` — Swiss army knife for Windows/AD: SMB, WinRM, LDAP, MSSQL, credential spraying
- **linpeas** — `/opt/peass/linpeas.sh` — Linux privilege escalation enumeration (upload to target)
- **winpeas** — `/opt/peass/winpeas.exe` — Windows privilege escalation enumeration (upload to target)

## Reverse Engineering
- **radare2 (r2)** — `/usr/bin/r2` — Binary analysis framework
- **gdb** — `/usr/bin/gdb` — GNU debugger
- **binwalk** — `/usr/bin/binwalk` — Firmware analysis, file carving
- **ltrace** — `/usr/bin/ltrace` — Library call tracer
- **strace** — `/usr/bin/strace` — System call tracer
- **strings** — `/usr/bin/strings` — Extract printable strings from binaries

## MCP Servers (AI-integrated tools via /opt/mcp-security-hub/)
- **nmap-mcp** — Port scanning via MCP protocol
- **nuclei-mcp** — Vulnerability scanning via MCP
- **sqlmap-mcp** — SQL injection via MCP
- **ffuf-mcp** — Fuzzing via MCP
- **shodan-mcp** — Internet device/service intelligence (requires SHODAN_API_KEY)
- **virustotal-mcp** — Malware/URL analysis (requires VIRUSTOTAL_API_KEY)
- **maigret-mcp** — Username OSINT across 2500+ platforms
- **dnstwist-mcp** — Typosquatting/phishing domain detection
- **hashcat-mcp** — GPU hash cracking via MCP
- **playwright-mcp** — Browser automation for testing SPAs and JS-heavy apps

## CDN / Real IP Discovery
- **curl headers check** — `curl -sI <target> | grep -i "cf-ray\|cloudflare\|server"` — Detect Cloudflare/CDN
- **crt.sh** — `curl -s "https://crt.sh/?q=%25.<domain>&output=json" | jq -r '.[].name_value'` — Certificate transparency logs
- **subfinder** — Subdomains may point to real IP (check A records with `dig`)
- **SecurityTrails / Censys** — Historical DNS records (manual/API)

## Output Parsing & Formatting (CRITICAL — use these to avoid context overflow)

### HTML / Web Response Parsing
- **htmlq** — `/usr/local/bin/htmlq` — CSS selectors on HTML (like jq for HTML). Extract links, forms, scripts, meta tags without dumping raw HTML
  - Links: `curl -s <url> | htmlq 'a' -a href`
  - Forms + hidden fields: `curl -s <url> | htmlq 'form' -a action` / `htmlq 'input[type=hidden]' -a value`
  - Title + generator: `curl -s <url> | htmlq 'title' -t` / `htmlq 'meta[name=generator]' -a content`
  - Script sources: `curl -s <url> | htmlq 'script[src]' -a src`
  - Strip tags, get text only: `curl -s <url> | htmlq -t 'body'`
- **html2text** — `html2text` — Convert HTML to readable Markdown-like text. Preserves links and structure, strips all tags
  - `curl -s <url> | html2text | head -100`
- **BeautifulSoup + lxml** — Python HTML/XML parser. Use for complex extractions (comments, inline JS, nested structures)
  - `python3 -c "from bs4 import BeautifulSoup, Comment; soup=BeautifulSoup(open('page.html'),'lxml'); [print(c.strip()) for c in soup.find_all(string=lambda t: isinstance(t, Comment))]"`

### Structured Data Parsing
- **jq** — `/usr/bin/jq` — JSON processor. Parse ffuf JSON, nuclei JSON, API responses
  - ffuf results: `jq -r '.results[] | select(.status==200) | "\(.status) \(.length)B \(.url)"' results.json`
  - Filter sensitive: `jq -r '.results[] | select(.input.FUZZ | test("env|config|backup")) | .url' results.json`
- **xq** — XML processor (like jq for XML). Parse nmap XML output
  - Open ports: `cat scan.xml | xq -r '.nmaprun.host.ports.port[] | select(.state["@state"]=="open") | "\(.["@portid"]) \(.service["@name"]) \(.service["@product"]//"-") \(.service["@version"]//"-")"'`
- **yq** — YAML processor. Parse config files, Kubernetes manifests
  - `cat config.yaml | yq -r '.database.url'`

### CSV / Tabular Data
- **csvkit** — CSV toolkit: csvgrep, csvcut, csvsql, csvlook. Parse ffuf CSV, scan exports
  - Filter sensitive findings: `csvgrep -c FUZZ -r "env|config|backup" results.csv | csvcut -c FUZZ,url,status | csvlook`
  - SQL queries on CSV: `csvsql --query "SELECT url,status,length FROM 'results' WHERE status=200 ORDER BY length DESC" results.csv`
- **mlr (miller)** — `/usr/local/bin/mlr` — CSV/JSON/tabular Swiss army knife
  - Filter + format: `mlr --icsv --opprint filter '$status == 200' then cut -f FUZZ,status,length results.csv`

### Search & Pattern Matching
- **rg (ripgrep)** — `/usr/local/bin/rg` — Ultra-fast recursive grep with better regex
  - Find secrets in files: `rg -in "api.key|password|secret|token|mysql://|sk-live" /path/`
  - Search with context: `rg -C3 "admin" scan-output.txt`

### Python Libraries (for one-liners and scripts)
- **beautifulsoup4** + **lxml** — HTML/XML parsing with CSS selectors and XPath
- **html2text** — HTML to Markdown conversion
- **rich** — Pretty-print tables, JSON, and formatted output in terminal

## Utilities
- **curl** — HTTP client (use `--socks5-hostname 127.0.0.1:9050` for Tor)
- **httpie** — Human-friendly HTTP client
- **jq** — JSON processor (see Output Parsing section for examples)
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
- MCP servers can be started individually: `python3 /opt/mcp-security-hub/<category>/<server>/server.py`
- Use `openclaw skill install <name>` to add new ClawHub skills
