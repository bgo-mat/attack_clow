# METHODOLOGY.md — Spectre Attack Methodology

> Hybrid framework: **MITRE ATT&CK** (backbone) + **OWASP Testing Guide v4** (web-specific).
> This file defines the state machine. Follow phases in order, respect exit criteria, and NEVER skip to REPORTING unless the objective is achieved.

---

## Phase State Machine

```
PHASE 0: OPSEC_SETUP
    ↓
PHASE 1: RECONNAISSANCE
    ↓
PHASE 2: ENUMERATION
    ↓
PHASE 3: VULNERABILITY_ANALYSIS  ←──┐
    ↓                                │
    ├── nothing found ───────────────┘ (return to PHASE 1 with deeper scans)
    ↓
PHASE 4: EXPLOITATION  ←────────────┐
    ↓                                │
    ├── exploit failed ──────────────┘ (try next vuln from PHASE 3)
    ↓
PHASE 5: POST_EXPLOITATION
    ↓
    ├── internal network? → PHASE 5B: LATERAL_MOVEMENT → PHASE 5
    ↓
PHASE 6: REPORTING
    ↓
    └── objective NOT achieved? → PHASE 1 (full restart with new approach)
```

---

## PHASE 0: OPSEC_SETUP

**Objective:** Verify anonymity and operational security before any engagement.

**Actions:**
1. Run `scripts/opsec-check.sh`
2. Verify exit IP: `curl --socks5-hostname 127.0.0.1:9050 -s https://check.torproject.org/api/ip`
3. Confirm IP ≠ VPS IP
4. Verify proxychains4 config is correct
5. Test Tor circuit rotation: `scripts/tor-rotate.sh`

**Exit criteria:** IP is NOT the VPS IP, Tor functional, proxychains verified.
**If FAIL:** Do NOT proceed. Fix Tor/proxy configuration first.
**Transition:** → PHASE 1

---

## PHASE 1: RECONNAISSANCE

**Objective:** Map the full attack surface — domains, subdomains, ports, services, tech stack.

### 1A: Passive Recon
| Action | Tool | Command pattern |
|--------|------|-----------------|
| Subdomain enumeration | subfinder | `proxychains4 -q subfinder -d <target> -silent` |
| Deep subdomain enum | amass | `proxychains4 -q amass enum -passive -d <target>` |
| WHOIS / DNS | whois, dig | `proxychains4 -q whois <target>` |
| Web crawling + endpoints | katana | `proxychains4 -q katana -u <target> -rate-limit 10 -delay 1` |
| Technology detection | whatweb | `proxychains4 -q whatweb -q <target>` |
| WAF detection | wafw00f | `proxychains4 -q wafw00f <target>` |

### 1B: Active Recon
| Action | Tool | Command pattern |
|--------|------|-----------------|
| Port scan (stealth) | nmap | `proxychains4 -q nmap -sT -T2 --scan-delay 1s --randomize-hosts --data-length 50 -Pn <target>` |
| Service/version detection | nmap | `proxychains4 -q nmap -sV -T2 -p<ports> <target>` |
| Web server vulns | nikto | `proxychains4 -q nikto -h <target> -Pause 1` |

> **IMPORTANT:** Through Tor/proxychains, only TCP connect scans (-sT) work.
> SYN scans (-sS), UDP scans (-sU), and OS detection (-O) require raw sockets
> and WILL FAIL silently through SOCKS proxies. NEVER attempt -sS via proxychains.

**Exit criteria:** Subdomains listed, open ports/services identified, tech stack known, WAF status known.
**Transition:** → PHASE 2

---

## PHASE 2: ENUMERATION

**Objective:** Identify all exploitable entry points — directories, endpoints, parameters, users, versions.

### 2A: Web Enumeration
| Action | Tool | Command pattern |
|--------|------|-----------------|
| Directory bruteforce | ffuf | `proxychains4 -q ffuf -u https://<target>/FUZZ -w /usr/share/seclists/Discovery/Web-Content/common.txt -rate 10` |
| Recursive dir enum | gobuster | `proxychains4 -q gobuster dir -u <target> -w <wordlist> --delay 100ms` |
| Hidden parameters | arjun | `proxychains4 -q arjun -u <target> --rate-limit 10` |
| API endpoint discovery | kiterunner | `proxychains4 -q kr scan <target> -w <routes>` |

> **If ffuf returns 100% identical responses (all 403/503):** The target likely has
> a CDN/WAF blocking automated requests. Use `-mc 200,301,302 -fc 403` to filter,
> add `-H "User-Agent: Mozilla/5.0 ..."`, or find the real IP behind the CDN first.

### 2B: Service Enumeration
| Action | Tool | Command pattern |
|--------|------|-----------------|
| SMB shares | nxc | `proxychains4 -q nxc smb <target> --shares` |
| SNMP | snmpwalk | `proxychains4 -q snmpwalk -c public <target>` |
| NSE scripts | nmap | `proxychains4 -q nmap --script=<category> -p<port> <target>` |

### 2C: User Enumeration
| Action | Tool | Notes |
|--------|------|-------|
| Web login forms | ffuf/hydra | Enumerate valid usernames via response differences |
| LDAP/AD users | nxc | `nxc ldap <target> -u '' -p '' --users` |
| Email harvesting | subfinder + patterns | Generate email patterns from domain |

**Exit criteria:** Directories/endpoints/params discovered, users/versions identified.
**Transition:** → PHASE 3

---

## PHASE 3: VULNERABILITY_ANALYSIS

**Objective:** Identify and confirm exploitable vulnerabilities.

### 3A: Automated Scanning
| Action | Tool | Command pattern |
|--------|------|-----------------|
| Template-based scan | nuclei | `proxychains4 -q nuclei -u <target> -rate-limit 5 -bulk-size 2` |
| CVE search | searchsploit | `searchsploit <service> <version>` |
| Blind vuln detection | interactsh | Start callback server, inject OOB URLs |

### 3B: OWASP Testing (Web Targets)

When the target has HTTP/HTTPS services, execute the OWASP checklist below **systematically**:

#### OTG-INFO: Information Gathering
- [ ] Fingerprint web server (`whatweb`, `nikto`)
- [ ] Review page source for comments, hidden fields, debug info
- [ ] Identify all entry points (forms, APIs, file uploads)
- [ ] Map application structure (`katana`, `ffuf`)

#### OTG-CONFIG: Configuration Management
- [ ] Test for default credentials on admin panels
- [ ] Check for exposed config files (`.env`, `web.config`, `wp-config.php`)
- [ ] Test HTTP methods (`OPTIONS`, `PUT`, `DELETE`)
- [ ] Check security headers (CSP, HSTS, X-Frame-Options)

#### OTG-IDENT: Identity Management
- [ ] Enumerate user accounts (registration, login error messages)
- [ ] Test account enumeration via timing differences
- [ ] Check for predictable user IDs

#### OTG-AUTHN: Authentication
- [ ] Test for default/weak credentials (`hydra`, `nxc`)
- [ ] Test password reset flow for flaws
- [ ] Test for brute-force protection (rate limiting, lockout)
- [ ] Check for authentication bypass

#### OTG-AUTHZ: Authorization
- [ ] Test IDOR (manipulate object references)
- [ ] Test privilege escalation (horizontal + vertical)
- [ ] Test for path traversal (`../../../etc/passwd`)
- [ ] Check API authorization on all endpoints

#### OTG-SESS: Session Management
- [ ] Test session token randomness/entropy
- [ ] Test for session fixation
- [ ] Test cookie flags (HttpOnly, Secure, SameSite)
- [ ] Test for CSRF

#### OTG-INPVAL: Input Validation
- [ ] **SQL Injection** — `proxychains4 -q sqlmap -u <target> --delay=1 --random-agent --tor --batch`
- [ ] **XSS** — `proxychains4 -q dalfox url <target> --delay 1000`
- [ ] **Command Injection** — `proxychains4 -q commix --url=<target>`
- [ ] **Path Traversal** — manual + nuclei templates
- [ ] **File Upload** — test extension bypass, MIME type bypass, double extensions
- [ ] **SSRF** — test with interactsh callback URLs
- [ ] **XXE** — test XML endpoints with entity injection
- [ ] **SSTI** — test template injection (`{{7*7}}`, `${7*7}`)

#### OTG-ERR: Error Handling
- [ ] Trigger errors to reveal stack traces, paths, versions
- [ ] Test custom error pages vs default server errors

#### OTG-CRYPST: Cryptography
- [ ] Check TLS configuration (`testssl.sh` or `sslscan`)
- [ ] Identify weak ciphers or protocols
- [ ] Check for sensitive data in cleartext

#### OTG-BUSLOGIC: Business Logic
- [ ] Test for logic flaws (price manipulation, workflow bypass)
- [ ] Test for race conditions
- [ ] Test for mass assignment

**Exit criteria:** At least 1 confirmed exploitable vulnerability.
**If NOTHING found:** Return to PHASE 1 with deeper scans (larger wordlists, all ports, UDP scan). Do NOT skip to REPORTING.
**Transition:** → PHASE 4

---

## PHASE 4: EXPLOITATION

**Objective:** Obtain initial access — shell, credentials, or code execution.

| Vector | Tool | Notes |
|--------|------|-------|
| Known CVE | metasploit, searchsploit | Match version to exploit |
| SQL Injection → shell | sqlmap | `--os-shell` or `--file-write` |
| RCE via web vuln | custom script | Based on PHASE 3 findings |
| Command injection | commix | `--os-cmd` for direct execution |
| Reverse shell | netcat/socat | Catch on VPS listener |
| Credential stuffing | hydra, nxc | Against discovered login services |

**Approach:**
1. Prioritize exploits by reliability (confirmed > probable > theoretical)
2. Try the most reliable vector first
3. Rotate Tor circuit before exploitation attempts
4. If exploit fails → try next vulnerability from PHASE 3 list
5. If ALL vulns exhausted → return to PHASE 3, try different tools/techniques

**Exit criteria:** Shell or authenticated access obtained on target.
**If FAIL on all vectors:** Return to PHASE 3. Try ALL discovered vulns before declaring dead end.
**Transition:** → PHASE 5

---

## PHASE 5: POST_EXPLOITATION

**Objective:** Privilege escalation, persistence, credential harvesting, data exfiltration.

| Action | Tool | Notes |
|--------|------|-------|
| Privesc enum (Linux) | linpeas.sh | Upload and run |
| Privesc enum (Windows) | winpeas.exe | Upload and run |
| Credential dump | impacket (secretsdump) | SAM, LSA, NTDS.dit |
| Hash cracking | hashcat | GPU-accelerated |
| Persistence | various | Cron, service, registry depending on OS |
| Data exfil | curl, scp, nc | Transfer loot to VPS |

**Exit criteria:** root/SYSTEM achieved OR operator objective met.
**Transition:** → PHASE 5B (if internal network) or → PHASE 6

---

## PHASE 5B: LATERAL_MOVEMENT

**Objective:** Pivot to other machines on internal networks.

| Action | Tool | Notes |
|--------|------|-------|
| Set up tunnel | chisel | HTTP tunnel to internal network |
| Internal scan | nmap (through tunnel) | Discover internal hosts |
| Credential spray | nxc | Reuse harvested credentials |
| AD attacks | impacket | Kerberoast, Pass-the-Hash, DCSync |

**Important:** Ask operator confirmation if pivoting goes beyond initial scope.
**Exit criteria:** Access to additional machines.
**Transition:** → PHASE 5 (on new target) or → PHASE 6

---

## PHASE 6: REPORTING

**Objective:** Document all findings with evidence.

**Report structure** (`engagements/<target>/report.md`):
1. Executive summary
2. Scope and methodology
3. Findings (per vulnerability):
   - Description
   - Severity (Critical/High/Medium/Low/Info)
   - Evidence (commands + outputs)
   - Impact
   - Remediation
4. Attack path visualization
5. Loot inventory

**CRITICAL:** PHASE 6 does NOT mean the engagement is over.
- If the objective is NOT achieved → return to PHASE 1 with new approach.
- Only stop when: operator says STOP, or objective fully achieved (root/flag/compromise).

---

## Decision Trees

### By Port/Service

```
Port 80/443 (HTTP/HTTPS)
  → WAF/CDN check (wafw00f + headers check)
  → If Cloudflare/CDN detected:
      → Find real IP (DNS history, subfinder, censys, SecurityTrails)
      → Test direct IP access: curl -H "Host: target" http://<real-ip>
      → If real IP found → scan real IP directly
  → Full OWASP methodology (PHASE 3B)
  → Tech stack ID → framework-specific exploits

Port 22 (SSH)
  → Banner grab → version CVE (searchsploit)
  → Default credentials (hydra)
  → Key-based auth enum
  → Bruteforce (last resort, slow)

Port 21 (FTP)
  → Anonymous login test
  → Version → CVE search
  → Writable directories → upload webshell

Port 445 (SMB)
  → Enumerate shares (nxc --shares)
  → Check for null session
  → EternalBlue / MS17-010 check
  → Credential spray with known creds

Port 3306 (MySQL) / 5432 (PostgreSQL)
  → Default credentials
  → Remote auth enabled?
  → If web app found → SQLi from web side
  → UDF exploitation if direct access

Port 3389 (RDP)
  → BlueKeep check (CVE-2019-0708)
  → Credential spray (nxc/hydra)
  → NLA bypass attempts

Port 25/587 (SMTP)
  → Open relay test
  → User enumeration (VRFY, EXPN, RCPT TO)
  → Version CVE search

Port 53 (DNS)
  → Zone transfer attempt (AXFR)
  → Subdomain brute from DNS
  → DNS rebinding potential

Port 161 (SNMP)
  → Community string guess (public/private)
  → snmpwalk for system info, interfaces, routes

Unknown service
  → Banner grab (nc, nmap -sV)
  → searchsploit <service> <version>
  → Manual protocol analysis
```

### By Situation

```
WAF detected
  → Identify WAF type (wafw00f output)
  → Adapt payloads: encoding, case variation, chunked transfer
  → Try bypass techniques before abandoning vector
  → Test for WAF misconfigurations (IP-based access, subdomain bypass)

CDN/Cloudflare detected (all requests return 403/503)
  → Confirm CDN: check response headers (cf-ray, server: cloudflare)
  → Find real IP: DNS history (SecurityTrails), certificate search (censys/crt.sh)
  → subfinder may reveal subdomains pointing to real IP
  → Try direct IP with Host header
  → If no real IP found → focus on exposed non-CDN services (SSH, FTP, etc.)

Dead end (3+ failures on same vector)
  → Document in STATE.md: what was tried, why it failed
  → Pivot to next attack surface
  → If all surfaces exhausted → deeper recon (UDP, all 65535 ports, vhost enum)

Credentials found
  → Immediately try on ALL discovered services (password reuse)
  → Check for privilege escalation with new access
  → Add to STATE.md loot section

New subdomain/host discovered
  → Full PHASE 1-2 on new target
  → Check if in scope (ask operator if unclear)
```

---

## Non-Stop Rules (per phase)

- **PHASE 1 → 2:** Transition automatically. Never stop after recon.
- **PHASE 2 → 3:** Transition automatically. Never stop after enumeration.
- **PHASE 3 finds nothing:** Do NOT skip to REPORTING. Return to PHASE 1 with deeper scans (all ports, UDP, larger wordlists, vhost enum).
- **PHASE 4 exploit fails:** Try ALL discovered vulns before declaring dead end. Then return to PHASE 3 with different tools.
- **PHASE 5 done:** If internal network discovered, proceed to PHASE 5B. Never stop after gaining access.
- **PHASE 6 reached:** If objective NOT achieved, return to PHASE 1. Reporting is NOT the end.
