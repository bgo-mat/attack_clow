# Agents Registry — Spectre Ecosystem

> Master registry for all Spectre agents. Defines the multi-agent architecture, available agents, delegation rules, and how to create new specialized agents.

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                 SPECTRE (Main Agent)                 │
│         Orchestrator — General Pentest Engine        │
│                                                     │
│  Reads: SOUL.md, METHODOLOGY.md, TOOLS.md, STATE.md │
│  Runs:  Full MITRE ATT&CK kill chain (Phase 0-6)   │
│  Role:  Detect domain, delegate or execute          │
└────────┬──────────┬──────────┬──────────┬───────────┘
         │          │          │          │
    ┌────▼───┐ ┌────▼───┐ ┌───▼────┐ ┌───▼────┐
    │  WEB   │ │   AD   │ │NETWORK │ │   RE   │
    │spectre-│ │spectre-│ │spectre-│ │spectre-│
    │  web   │ │  ad    │ │network │ │  re    │
    └────────┘ └────────┘ └────────┘ └────────┘
```

### Principles

1. **Spectre (main) is always the orchestrator.** It runs the engagement, detects domains, and delegates when deep expertise is needed.
2. **Specialized agents inherit ALL OPSEC rules** from `SOUL.md`. No exceptions.
3. **Communication is file-based.** Agents share data through `engagements/<target>/` — STATE.md, notes.md, and a per-agent findings file.
4. **One engagement, one STATE.md.** Specialized agents write findings back to the shared STATE.md and notes.md. They do NOT maintain separate state.
5. **Delegation is not abdication.** Spectre monitors delegated work and integrates results into the global attack plan.

---

## Available Agents

| Agent | Domain | Profile | Delegation Trigger | Status |
|-------|--------|---------|-------------------|--------|
| **spectre** | General pentest | `SOUL.md` | Default — always active as orchestrator | ACTIVE |
| **spectre-web** | Web application | `agents/web-agent.md` | Complex web apps, SPAs, REST/GraphQL APIs, multi-step auth flows | ACTIVE |
| **spectre-ad** | Active Directory | `agents/ad-agent.md` | Windows domain detected (ports 88/389/445 + domain context) | ACTIVE |
| **spectre-network** | Network / Infra | `agents/network-agent.md` | Internal network pivot required, multi-host engagement | ACTIVE |
| **spectre-re** | Reverse Engineering | `agents/re-agent.md` | Binary exploitation, firmware analysis, CTF binaries | ACTIVE |

---

## Delegation Rules

### When to Delegate

Spectre delegates during **PHASE 2 (ENUMERATION)** or later, when it detects that a domain requires deep specialized expertise.

```
IF complex web app detected (SPA, framework, auth flow, API with 10+ endpoints)
   AND target is primarily web-based
   → DELEGATE to spectre-web for full OWASP Testing Guide

IF Windows domain detected:
   Port 88 (Kerberos) OR Port 389/636 (LDAP) OR Port 445 (SMB) with domain context
   AND domain name / DC identified
   → DELEGATE to spectre-ad for AD kill chain

IF pivot needed:
   Internal network discovered via post-exploitation
   AND multiple internal hosts to enumerate
   → DELEGATE to spectre-network for internal cartography + pivot management

IF binary encountered:
   Executable to analyze (ELF/PE/firmware)
   AND exploitation or reverse engineering required
   → DELEGATE to spectre-re for static/dynamic analysis
```

### When NOT to Delegate

- **Simple web targets** (static site, single login, few endpoints) → Spectre handles with OWASP checklist from METHODOLOGY.md
- **Single-service exploits** (one known CVE, one port) → Spectre handles directly
- **Basic SMB/SSH enumeration** without AD context → Spectre handles
- **Quick hash cracking or credential testing** → Spectre handles

### Rule of Thumb

> If Spectre can handle it with the standard METHODOLOGY.md phases → do it.
> If it requires 20+ specialized actions in one domain → delegate.

---

## Delegation Protocol

### Step 1: Decide to Delegate

During the cognitive loop `[DECIDE]` step, Spectre identifies that delegation is optimal.

### Step 2: Prepare Context

Spectre writes a delegation brief in `engagements/<target>/delegation-<agent>.md`:

```markdown
# Delegation Brief — spectre-<domain>

## Target
{target info}

## Objective
{specific objective for the specialized agent}

## Context Already Gathered
{relevant findings from STATE.md — ports, services, vulns discovered}

## Scope Boundaries
{what the agent is authorized to do / not do}

## Expected Output
{what Spectre expects back — findings format, files to update}
```

### Step 3: Launch Agent

Use the installed multi-agent skills:

```bash
# Option A: parallel-agents skill (recommended for short tasks)
# Launches agent with its profile loaded

# Option B: tmux-agents skill (recommended for long-running tasks)
# Dedicated tmux session, agent runs independently
```

The agent profile file (`agents/<domain>-agent.md`) is loaded as the agent's system context.

### Step 4: Notify Operator

```
[SPECTRE | DELEGATE | <target>] Délégation à spectre-<domain>: {brief reason}
```

### Step 5: Monitor & Integrate

- Spectre checks `engagements/<target>/notes.md` periodically for new entries from the delegated agent.
- When the agent completes or reports findings, Spectre integrates them into STATE.md.
- Spectre decides next steps based on combined intelligence.

### Step 6: Resume Control

When the specialized task is complete, Spectre resumes the engagement from where it left off, incorporating new findings.

---

## Agent Communication Format

Specialized agents MUST write their findings using the same notes.md format defined in `AGENTS.md`:

```markdown
## {YYYY-MM-DD HH:MM} | PHASE X | [spectre-<domain>] {action summary}
**Tool:** {tool used}
**Command:** `{exact command}`
**Result:** {brief result}
**Analysis:** {what this means}
**Next:** {planned next action}
---
```

The only difference: the `[spectre-<domain>]` tag in the header to identify which agent produced the entry.

Findings that must be added to STATE.md immediately:
- Confirmed vulnerabilities → `Findings → Vulnerabilities Confirmed`
- Credentials → `Findings → Credentials Found`
- Access obtained → `Findings → Access Obtained`
- Dead ends → `Dead Ends` section

---

## How to Create a New Agent

### 1. Define the Domain

Identify a specific domain that requires deep expertise beyond Spectre's general methodology. The domain should have:
- Its own methodology or kill chain (e.g., OWASP for web, AD kill chain for Active Directory)
- A significant number of specialized tools
- Decision trees specific to that domain

### 2. Create the Profile File

Create `workspace/agents/<domain>-agent.md` with this structure:

```markdown
# Agent Profile — spectre-<domain>

## Identity
- **Name:** Spectre-<Domain>
- **Role:** {one-line description}
- **Domain:** {specific expertise area}

## Inherited Rules
- ALL OPSEC rules from SOUL.md apply without exception
- ALL communication rules from SOUL.md apply (French responses, English terms)
- Cognitive loop is MANDATORY after every action
- Persistence rules apply — do NOT stop until objective is met

## Methodology
{Domain-specific kill chain / phases}
- Phase by phase with: objective, tools, commands, exit criteria, transitions

## Decision Trees
{Domain-specific decision trees}
- By port/service/situation relevant to this domain

## Tools
{Subset of TOOLS.md relevant to this domain, plus any domain-specific usage patterns}

## Output Rules
- Write findings to shared `engagements/<target>/notes.md` with [spectre-<domain>] tag
- Update `engagements/<target>/STATE.md` for significant findings
- Notify operator via standard notification format
```

### 3. Register the Agent

Add a row to the **Available Agents** table in this file with:
- Agent name
- Domain
- Profile file path
- Delegation trigger conditions
- Status (PLANNED → ACTIVE once tested)

### 4. Add Delegation Trigger

Add the trigger condition to the **When to Delegate** section above, following the existing pattern.

### 5. Test

Run a controlled engagement where the delegation trigger fires. Verify:
- [ ] Agent loads its profile correctly
- [ ] OPSEC rules are followed (proxychains, Tor)
- [ ] Findings are written to shared notes.md and STATE.md
- [ ] Notifications use the correct format with agent tag
- [ ] Spectre can integrate results and resume control

---

## Agent Lifecycle

```
PLANNED → Profile file created, registered, trigger defined
TESTING → Being validated on controlled engagements
ACTIVE  → Production-ready, auto-delegation enabled
RETIRED → Superseded or merged into main methodology
```

---

## Future Agents (Backlog)

| Agent | Domain | Notes |
|-------|--------|-------|
| spectre-cloud | Cloud (AWS/Azure/GCP) | Cloud misconfigs, IAM, metadata abuse |
| spectre-mobile | Mobile apps | APK/IPA decompilation, API interception |
| spectre-wifi | Wireless | 802.11 attacks, evil twin, WPA cracking |
| spectre-social | Social Engineering | Phishing, pretexting, OSINT |

These are not prioritized — add only when a real engagement requires it.
