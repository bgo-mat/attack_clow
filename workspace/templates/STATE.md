# Engagement State — {TARGET}

## Objective

{Operator's mission objective — copy verbatim from operator instruction}

## Status

- **Current Phase:** PHASE_0_OPSEC_SETUP
- **Started:** {YYYY-MM-DD HH:MM}
- **Last Updated:** {YYYY-MM-DD HH:MM}
- **Progress:** 0%
- **Status:** ACTIVE

## OPSEC

- **Exit IP:** {verified IP from opsec-check.sh}
- **Tor Status:** {OK / FAIL}
- **Proxychains:** {OK / FAIL}
- **Last Circuit Rotation:** {YYYY-MM-DD HH:MM}
- **WAF Detected:** {NONE / type if detected}

---

## Attack Surface Map

### Target Info

| Field | Value |
|-------|-------|
| Domain/IP | {target} |
| Scope | {scope definition from operator} |
| OS (if known) | {unknown} |

### Ports & Services

| Port | Protocol | Service | Version | Notes |
|------|----------|---------|---------|-------|
| | | | | |

### Subdomains

| Subdomain | IP | Status | Notes |
|-----------|----|----|-------|
| | | | |

### Web Technologies

| Technology | Version | Source |
|------------|---------|--------|
| | | |

### WAF / CDN

| Target | WAF Type | Bypass Attempted | Result |
|--------|----------|------------------|--------|
| | | | |

---

## Findings

### Vulnerabilities Confirmed

| ID | Type | Severity | Location | Description | Status |
|----|------|----------|----------|-------------|--------|
| V-001 | | | | | FOUND / EXPLOITED / FAILED |

### Credentials Found

| Source | Username | Password/Hash | Type | Reuse Tested |
|--------|----------|---------------|------|--------------|
| | | | | YES / NO |

### Access Obtained

| Host | User | Privilege Level | Method | Persistent |
|------|------|-----------------|--------|------------|
| | | | | YES / NO |

---

## Completed Phases

- [ ] PHASE 0: OPSEC Setup
- [ ] PHASE 1: Reconnaissance
  - [ ] 1A: Passive Recon
  - [ ] 1B: Active Recon
- [ ] PHASE 2: Enumeration
  - [ ] 2A: Web Enumeration
  - [ ] 2B: Service Enumeration
  - [ ] 2C: User Enumeration
- [ ] PHASE 3: Vulnerability Analysis
  - [ ] 3A: Automated Scanning
  - [ ] 3B: OWASP Testing (if web target)
- [ ] PHASE 4: Exploitation
- [ ] PHASE 5: Post-Exploitation
- [ ] PHASE 5B: Lateral Movement (if applicable)
- [ ] PHASE 6: Reporting

## OWASP Checklist (Web Targets)

> Only fill if HTTP/HTTPS services detected. See METHODOLOGY.md for details.

- [ ] OTG-INFO: Information Gathering
- [ ] OTG-CONFIG: Configuration Management
- [ ] OTG-IDENT: Identity Management
- [ ] OTG-AUTHN: Authentication
- [ ] OTG-AUTHZ: Authorization
- [ ] OTG-SESS: Session Management
- [ ] OTG-INPVAL: Input Validation (SQLi, XSS, CMDi, Path Traversal, SSRF, XXE, SSTI)
- [ ] OTG-ERR: Error Handling
- [ ] OTG-CRYPST: Cryptography
- [ ] OTG-BUSLOGIC: Business Logic

---

## Dead Ends (Documented Pivots)

> Approaches tried that did not succeed. NEVER delete entries — this prevents retrying failed vectors.

| # | Phase | Vector Attempted | Attempts | Why It Failed | Pivoted To |
|---|-------|------------------|----------|---------------|------------|
| 1 | | | | | |

---

## Next Actions Queue

> Ordered by priority. Update after every cognitive loop. Max 5 items.

| # | Action | Reasoning | Phase |
|---|--------|-----------|-------|
| 1 | {next action} | {why this is the best next step} | PHASE X |
| 2 | {fallback action} | {if #1 fails or is blocked} | PHASE X |
| 3 | {alternative vector} | {different attack surface} | PHASE X |
