# Spectre v2 — Upgrade TODO

> Chaque ticket est autonome et peut être implémenté indépendamment sauf indication contraire.
> Priorité : P0 (bloquant) → P1 (important) → P2 (amélioration) → P3 (futur)

---

## Déjà en place (baseline)

- [x] Architecture VPS complète (Ollama + OpenClaw + Caddy + Tor)
- [x] Arsenal 70+ outils installés et documentés (TOOLS.md)
- [x] OPSEC stack (proxychains, tor-rotate, opsec-check, stealth-wrapper)
- [x] Watchdog auto-restart (gateway crash + stuck sessions)
- [x] Systemd service avec restart=always
- [x] exec-approvals.json (whitelist binaires)
- [x] MCP servers (nmap, nuclei, sqlmap, shodan, virustotal, playwright, etc.)
- [x] Config Tor multi-circuits (4 SOCKS ports, rotation 30s)
- [x] Dashboard web via Caddy HTTPS
- [x] Scripts OPSEC (opsec-check.sh, tor-rotate.sh, stealth-wrapper.sh)
- [x] Structure engagements/<target>/ (scans/, loot/, notes.md, report.md)
- [x] Modelfile Ollama fonctionnel (Qwen3.5-abliterated 122B)
- [x] SOUL.md, AGENTS.md, TOOLS.md, IDENTITY.md, USER.md

---

## Phase 1 — Anti-arrêt & boucle cognitive (P0)

### TICKET-001: Réécriture du Modelfile
**Fichier:** `configs/ollama/Modelfile`
**Statut:** [ ] TODO
**Dépendances:** Aucune
**Description:**
Réécrire le system prompt du Modelfile en anglais avec les changements suivants :
- **Température:** 0.7 → 0.55 (moins de variabilité, plus de rigueur)
- **num_ctx:** 32768 → 49152 (plus de contexte pour engagements longs)
- **System prompt en anglais** (meilleure performance LLM), avec instruction de répondre en français
- **Instruction de non-arrêt explicite:** "NEVER conclude or summarize an engagement as finished unless the operator explicitly tells you to stop. After EVERY action, evaluate progress against the objective. If the objective is not fully achieved, plan and execute the next step immediately."
- **Boucle cognitive obligatoire:** Intégrer le cycle `THINK → ACT → OBSERVE → EVALUATE → LOOP` dans le system prompt
- **Suppression des infos redondantes** avec SOUL.md (le Modelfile doit être compact, SOUL.md a le détail)
- Garder les règles OPSEC critiques (proxychains obligatoire) car elles doivent être dans le system prompt de base

**Critères de validation:**
- Le modèle ne s'arrête plus spontanément après une phase
- Le modèle produit un bloc de réflexion après chaque action
- Le system prompt fait < 600 tokens (compact)

---

### TICKET-002: Réécriture de SOUL.md
**Fichier:** `workspace/SOUL.md`
**Statut:** [ ] TODO
**Dépendances:** TICKET-001
**Description:**
Réécrire SOUL.md entièrement en anglais avec cette structure :
1. **Core Identity** (3-4 lignes max)
2. **Cognitive Loop** — Le cycle obligatoire après chaque action :
   ```
   [THINK] What is my current objective? What phase am I in?
   [ACT] Execute the next logical action
   [OBSERVE] What did the tool output reveal?
   [ANALYZE] What does this mean for the attack surface?
   [DECIDE] What is the next step and why?
   [UPDATE] Update STATE.md with findings and next actions
   [NOTIFY] If significant finding → notify operator in chat
   [LOOP] Go back to THINK — NEVER stop unless operator says so
   ```
3. **Persistence Rules:**
   - "You are a persistent agent. You do NOT stop after completing a phase."
   - "If you feel like concluding, instead ask yourself: Have I achieved root/flag/full compromise? If no → continue."
   - "If stuck on one vector for 3+ attempts → pivot to another attack surface. Document the dead end."
   - "After each tool execution, you MUST produce the cognitive loop output."
4. **OPSEC Rules** (gardées telles quelles, elles sont bonnes)
5. **Communication:** réponses en français, termes techniques en anglais
6. **Référence à METHODOLOGY.md** pour le détail des phases

**Critères de validation:**
- Fichier en anglais sauf section Communication
- Boucle cognitive clairement définie
- Règles anti-arrêt explicites
- < 200 lignes

---

### TICKET-003: Création de METHODOLOGY.md
**Fichier:** `workspace/METHODOLOGY.md`
**Statut:** [ ] TODO
**Dépendances:** Aucune
**Description:**
Créer un nouveau fichier qui définit la machine à états méthodologique. Structure hybride MITRE ATT&CK (backbone) + OWASP Testing Guide (web-specific).

**Contenu requis:**

**A. Machine à états principale (MITRE ATT&CK-based):**
```
PHASE 0: OPSEC_SETUP
  → Objectif: Vérifier anonymat
  → Actions: opsec-check.sh, verify exit IP
  → Critère de sortie: IP ≠ VPS IP, Tor fonctionnel
  → Transition: → PHASE 1

PHASE 1: RECONNAISSANCE
  → Objectif: Cartographier la surface d'attaque
  → Sous-phases: passive recon, active recon
  → Outils: subfinder, amass, whois, katana, whatweb, wafw00f, nmap
  → Critère de sortie: Liste de ports/services, subdomains, tech stack identifié
  → Transition: → PHASE 2

PHASE 2: ENUMERATION
  → Objectif: Identifier tous les points d'entrée exploitables
  → Sous-phases: web enum, service enum, user enum
  → Outils: ffuf, gobuster, arjun, kiterunner, nikto, nmap scripts
  → Critère de sortie: Dirs/endpoints/params découverts, users/versions identifiés
  → Transition: → PHASE 3

PHASE 3: VULNERABILITY_ANALYSIS
  → Objectif: Identifier et confirmer les vulnérabilités
  → Sous-phases: automated scanning, manual testing, OWASP checks
  → Outils: nuclei, dalfox, sqlmap, commix, searchsploit, interactsh
  → Critère de sortie: Au moins 1 vulnérabilité confirmée exploitable
  → Si aucune trouvée: retour PHASE 1 avec scan plus profond ou nouvelles wordlists
  → Transition: → PHASE 4

PHASE 4: EXPLOITATION
  → Objectif: Obtenir un accès initial
  → Outils: metasploit, custom scripts, sqlmap --os-shell, reverse shells
  → Critère de sortie: Shell/accès obtenu sur la cible
  → Si échec: retour PHASE 3, essayer un autre vecteur
  → Transition: → PHASE 5

PHASE 5: POST_EXPLOITATION
  → Objectif: Escalade de privilèges, persistence, data exfil
  → Outils: linpeas/winpeas, impacket, nxc, hashcat
  → Critère de sortie: root/SYSTEM ou objectif opérateur atteint
  → Transition: → PHASE 6 ou PHASE 5B

PHASE 5B: LATERAL_MOVEMENT (si réseau interne découvert)
  → Objectif: Pivoter vers d'autres machines
  → Outils: chisel, nxc, impacket, nmap (internal)
  → Critère de sortie: Accès à machines supplémentaires
  → Note: Demander confirmation opérateur si hors scope initial
  → Transition: → PHASE 5 (sur nouvelle cible) ou PHASE 6

PHASE 6: REPORTING
  → Objectif: Documenter tout
  → Actions: Générer report.md structuré
  → Critère de sortie: Report complet avec findings, evidence, remediation
  → Note: NE PAS s'arrêter ici si l'objectif n'est pas atteint → retour PHASE 1
```

**B. Sous-méthodologie OWASP (intégrée dans PHASE 3):**
Checklist OWASP Testing Guide v4 adaptée pour l'agent :
- Information Gathering (OTG-INFO)
- Configuration/Deploy Management (OTG-CONFIG)
- Identity Management (OTG-IDENT)
- Authentication (OTG-AUTHN)
- Authorization (OTG-AUTHZ)
- Session Management (OTG-SESS)
- Input Validation (OTG-INPVAL) — SQLi, XSS, CMDi, Path Traversal, etc.
- Error Handling (OTG-ERR)
- Cryptography (OTG-CRYPST)
- Business Logic (OTG-BUSLOGIC)

Chaque catégorie avec : tests à effectuer, outils correspondants, critères pass/fail.

**C. Arbres de décision:**
- Port 80/443 ouvert → branche web complète (OWASP)
- Port 22 ouvert → try default creds → CVE search → bruteforce
- Port 21 (FTP) → anonymous login → version CVE
- Port 445 (SMB) → enum shares → EternalBlue check → credential spray
- Port 3306/5432 (DB) → default creds → injection depuis web app
- Service inconnu → banner grab → searchsploit → manual analysis
- WAF détecté → adapter payloads → essayer bypass techniques
- Dead end (3 échecs) → documenter → pivoter vers autre surface

**D. Règles de non-arrêt par phase:**
- "If PHASE 3 finds nothing, do NOT skip to REPORTING. Return to PHASE 1 with deeper scans."
- "If PHASE 4 exploitation fails, try ALL discovered vulns before declaring dead end."
- "PHASE 6 REPORTING does not mean the engagement is over unless the objective is achieved."

**Critères de validation:**
- Chaque phase a : objectif, outils, critère de sortie, transitions
- Arbres de décision pour les 10 ports/services les plus courants
- Sous-méthodologie OWASP intégrée dans PHASE 3
- Règles de boucle/retry clairement définies

---

### TICKET-004: Réécriture de AGENTS.md
**Fichier:** `workspace/AGENTS.md`
**Statut:** [ ] TODO
**Dépendances:** TICKET-002, TICKET-003, TICKET-005
**Description:**
Réécrire AGENTS.md en anglais avec focus sur la reprise de session et le suivi d'état.

**Nouveau startup flow:**
```
1. Read SOUL.md (identity, cognitive loop, persistence rules)
2. Read METHODOLOGY.md (phases, decision trees)
3. Read TOOLS.md (arsenal)
4. Check engagements/ for active STATE.md files
   → If active engagement found:
     a. Read STATE.md
     b. Read notes.md (recent entries)
     c. Notify operator: "[SPECTRE | RESUMING | <target>] Reprenant en phase X"
     d. Continue from last recorded phase/action
   → If no active engagement:
     a. Wait for operator instruction
5. If new engagement: create engagements/<target>/ structure + STATE.md
6. Run opsec-check.sh before any offensive action
```

**Sections requises:**
- Startup Flow (ci-dessus)
- Workspace Structure (mise à jour avec STATE.md)
- State Management Rules (quand/comment update STATE.md)
- OPSEC Rules (référence SOUL.md, pas de duplication)
- Notification Rules (quand notifier l'opérateur)
- Reporting Format

**Critères de validation:**
- Startup flow vérifie STATE.md en priorité
- Instructions de reprise de session explicites
- En anglais

---

## Phase 2 — Mémoire & persistance d'engagement (P1)

### TICKET-005: Création du template STATE.md
**Fichier:** `workspace/templates/STATE.md`
**Statut:** [ ] TODO
**Dépendances:** TICKET-003
**Description:**
Créer un template d'état d'engagement que l'agent copie dans `engagements/<target>/STATE.md` au début de chaque mission.

**Structure du template:**
```markdown
# Engagement State — {TARGET}

## Objective
{Operator's mission objective}

## Status
- **Current Phase:** PHASE_0_OPSEC_SETUP
- **Started:** {timestamp}
- **Last Updated:** {timestamp}
- **Progress:** 0%

## OPSEC
- Exit IP: {verified IP}
- Tor Status: {OK/FAIL}
- Last Circuit Rotation: {timestamp}

## Attack Surface Map
### Ports & Services
{nmap results summary}

### Subdomains
{subfinder/amass results}

### Web Technologies
{whatweb/wappalyzer results}

### WAF
{wafw00f results}

## Findings
### Vulnerabilities Confirmed
| ID | Type | Severity | Location | Status |
|----|------|----------|----------|--------|

### Credentials Found
| Source | Username | Password/Hash | Status |
|--------|----------|---------------|--------|

### Access Obtained
| Host | User | Level | Method |
|------|------|-------|--------|

## Completed Phases
- [ ] PHASE 0: OPSEC Setup
- [ ] PHASE 1: Reconnaissance
- [ ] PHASE 2: Enumeration
- [ ] PHASE 3: Vulnerability Analysis
- [ ] PHASE 4: Exploitation
- [ ] PHASE 5: Post-Exploitation
- [ ] PHASE 6: Reporting

## Dead Ends (documented pivots)
{Approaches tried and failed, with reasons}

## Next Actions Queue
1. {next action with reasoning}
2. {fallback action}
3. {alternative vector}
```

**Critères de validation:**
- Template couvre toutes les phases de METHODOLOGY.md
- Sections pour findings, credentials, access, dead ends
- Checklist de phases pour suivi visuel
- File d'attente d'actions next

---

### TICKET-006: Format structuré pour notes.md
**Fichier:** Documentation dans AGENTS.md (TICKET-004)
**Statut:** [ ] TODO
**Dépendances:** TICKET-004
**Description:**
Définir dans AGENTS.md le format obligatoire pour `engagements/<target>/notes.md` :

```markdown
## {YYYY-MM-DD HH:MM} | PHASE X | {action summary}
**Tool:** {tool used}
**Command:** `{exact command}`
**Result:** {brief result}
**Analysis:** {what this means}
**Next:** {what to do next}
---
```

L'agent DOIT append à ce fichier après chaque action significative.
Ce fichier est **append-only** (ne jamais supprimer d'entrées).
Sert de log d'audit ET de contexte pour la reprise de session.

**Critères de validation:**
- Format documenté dans AGENTS.md
- Chaque entrée a : timestamp, phase, tool, command, result, analysis, next
- Append-only explicitement requis

---

## Phase 3 — Réflexion & intelligence tactique (P1)

### TICKET-007: Bloc de réflexion dans SOUL.md
**Fichier:** Intégré dans TICKET-002 (SOUL.md)
**Statut:** [ ] TODO
**Dépendances:** TICKET-002
**Description:**
S'assurer que la boucle cognitive dans SOUL.md inclut un mécanisme anti-stagnation :

**Règles de pivot:**
- Si 3 tentatives échouées sur le même vecteur → documenter dans Dead Ends → pivoter
- Si 0 vulnérabilité trouvée après PHASE 3 complète → retour PHASE 1 avec :
  - Wordlists plus larges
  - Scan de ports complet (all 65535)
  - Techniques d'énumération alternatives
- Si exploitation échoue → essayer TOUS les vecteurs découverts avant de déclarer dead end
- Si stuck global (toutes les pistes épuisées) → notifier opérateur avec résumé complet et demander guidance

**Règles de self-check:**
- Toutes les ~10 actions : "Am I making progress toward the objective? If not, what should I change?"
- Avant chaque changement de phase : vérifier que les critères de sortie sont remplis
- Après un finding significatif : évaluer si ça ouvre de nouvelles pistes

**Note:** Ce ticket est intégré dans TICKET-002 mais listé séparément pour traçabilité.

---

## Phase 4 — Notifications opérateur (P1)

### TICKET-008: Système de notification
**Fichier:** Intégré dans SOUL.md (TICKET-002) et AGENTS.md (TICKET-004)
**Statut:** [ ] TODO
**Dépendances:** TICKET-002, TICKET-004
**Description:**
Définir les règles de notification dans le chat du dashboard :

**Notifications obligatoires (format standardisé):**
```
[SPECTRE | PHASE_CHANGE | <target>] Passage en Phase X: {phase_name}
[SPECTRE | FINDING | <target>] {severity}: {brief description}
[SPECTRE | ACCESS | <target>] Shell obtenu: {user}@{host} via {method}
[SPECTRE | CREDS | <target>] Credentials trouvées: {count} comptes
[SPECTRE | PIVOT | <target>] Dead end sur {vector}, pivot vers {new_vector}
[SPECTRE | STUCK | <target>] Toutes les pistes épuisées — en attente de guidance
[SPECTRE | PROGRESS | <target>] Résumé: Phase {X}, {N} findings, {progress}%
```

**Fréquence:**
- Changement de phase → immédiat
- Finding critique/high → immédiat
- Résumé de progression → toutes les ~10 actions ou ~15 minutes
- Dead end / pivot → immédiat
- Stuck → immédiat + pause (attente opérateur)

**Critères de validation:**
- Format de notification documenté
- Toutes les situations de notification listées
- En français dans le chat (format tags en anglais pour parsing)

---

## Phase 5 — Mise à jour mineure (P2)

### TICKET-009: Mise à jour IDENTITY.md
**Fichier:** `workspace/IDENTITY.md`
**Statut:** [ ] TODO
**Dépendances:** Aucune
**Description:**
Mettre à jour IDENTITY.md pour refléter la v2 :
- Ajouter: "Persistent — never stops until objective is achieved or operator intervenes"
- Ajouter: "Self-reflective — evaluates progress after every action"
- Ajouter: "Methodical — follows MITRE ATT&CK + OWASP hybrid methodology"
- Garder le style compact actuel

---

## Phase 6 — Agents spécialisés (P2)

> Cette phase prépare l'architecture pour créer des agents spécialisés par domaine.
> L'idée : quand Spectre détecte un domaine qui nécessite une expertise profonde
> (AD, web app complexe, réseau interne), il peut déléguer à un agent spécialisé
> via les skills parallel-agents / tmux-agents déjà installés.

### TICKET-010: Création de AGENTS-REGISTRY.md
**Fichier:** `workspace/AGENTS-REGISTRY.md`
**Statut:** [ ] TODO
**Dépendances:** TICKET-003
**Description:**
Créer un registre qui documente les agents disponibles et comment en créer de nouveaux.

**Structure:**
```markdown
# Agents Registry

## Agent Architecture
- Spectre (main) = orchestrateur, exécute la méthodologie principale
- Agents spécialisés = délégués pour domaines spécifiques
- Chaque agent hérite des règles OPSEC de SOUL.md
- Communication via fichiers dans engagements/<target>/

## Available Agents
| Agent | Domain | Profile File | When to Delegate |
|-------|--------|-------------|-----------------|
| spectre | General pentest | SOUL.md | Default — always active |
| spectre-web | Web application | agents/web-agent.md | Complex web apps, SPA, API |
| spectre-ad | Active Directory | agents/ad-agent.md | Windows domain, Kerberos, LDAP |
| spectre-network | Network/Infra | agents/network-agent.md | Internal network, pivoting |
| spectre-re | Reverse Engineering | agents/re-agent.md | Binary analysis, malware |

## How to Create a New Agent
{step-by-step guide}

## Delegation Rules
{when Spectre should delegate vs handle itself}
```

**Critères de validation:**
- Table des agents avec domaine et trigger de délégation
- Guide de création d'un nouvel agent
- Règles de quand déléguer

---

### TICKET-011: Agent spécialisé Web (spectre-web)
**Fichier:** `workspace/agents/web-agent.md`
**Statut:** [ ] TODO
**Dépendances:** TICKET-010, TICKET-003
**Description:**
Créer le profil de l'agent spécialisé web application.

**Contenu:**
- Identité: Spectre-Web, spécialiste web app
- Méthodologie: OWASP Testing Guide v4 complète (pas juste la checklist)
- Workflow détaillé pour chaque catégorie OWASP :
  - OTG-INFO: Information Gathering (whatweb, katana, wappalyzer)
  - OTG-CONFIG: Configuration testing (nikto, nuclei config templates)
  - OTG-IDENT: Identity management (user enum, registration flaws)
  - OTG-AUTHN: Authentication (hydra, auth bypass, default creds, 2FA bypass)
  - OTG-AUTHZ: Authorization (IDOR, privilege escalation, forced browsing)
  - OTG-SESS: Session management (cookie analysis, session fixation, CSRF)
  - OTG-INPVAL: Input validation (sqlmap, dalfox, commix, path traversal, SSTI, SSRF)
  - OTG-ERR: Error handling (verbose errors, stack traces)
  - OTG-CRYPST: Cryptography (weak TLS, insecure tokens)
  - OTG-BUSLOGIC: Business logic flaws (workflow bypass, race conditions)
- Outils spécifiques: ffuf, sqlmap, dalfox, commix, arjun, kiterunner, nuclei, interactsh, playwright-mcp
- Arbres de décision web-specific
- Hérite OPSEC de SOUL.md
- Produit des findings au format défini dans AGENTS.md

**Critères de validation:**
- Couvre les 10 catégories OWASP
- Chaque catégorie a des tests concrets et des outils
- Arbres de décision pour les scénarios courants (login page, API, SPA, file upload, etc.)

---

### TICKET-012: Agent spécialisé Active Directory (spectre-ad)
**Fichier:** `workspace/agents/ad-agent.md`
**Statut:** [ ] TODO
**Dépendances:** TICKET-010
**Description:**
Créer le profil de l'agent spécialisé Active Directory / Windows domain.

**Contenu:**
- Identité: Spectre-AD, spécialiste environnement Windows/AD
- Méthodologie basée sur la kill chain AD :
  1. AD Enumeration (nxc, ldapsearch, enum4linux-ng, bloodhound-python)
  2. Credential Harvesting (Kerberoasting, AS-REP roasting, NTLM relay)
  3. Lateral Movement (pass-the-hash, psexec, wmiexec, smbexec)
  4. Privilege Escalation (DCSync, Golden Ticket, Silver Ticket, PrintNightmare)
  5. Domain Dominance (DA → EA, forest trust abuse)
  6. Persistence (skeleton key, AdminSDHolder, GPO abuse)
- Outils spécifiques: impacket suite, nxc (NetExec), crackmapexec legacy, bloodhound, rubeus (si disponible), mimikatz (si disponible)
- Arbres de décision AD-specific :
  - "Port 88 (Kerberos) → AS-REP roast → Kerberoast → check delegation"
  - "Port 389/636 (LDAP) → anonymous bind? → enum users/groups/GPOs"
  - "Port 445 (SMB) → null session? → shares enum → relay attacks"
  - "Got user creds → check admin? → spray other services → Kerberoast"
  - "Got DA → DCSync → Golden Ticket → forest trust check"
- Hérite OPSEC de SOUL.md

**Critères de validation:**
- Kill chain AD complète en 6 étapes
- Arbres de décision pour chaque point d'entrée AD
- Couverture des attaques Kerberos, NTLM, LDAP, SMB, GPO

---

### TICKET-013: Agent spécialisé Network/Infrastructure (spectre-network)
**Fichier:** `workspace/agents/network-agent.md`
**Statut:** [ ] TODO
**Dépendances:** TICKET-010
**Description:**
Créer le profil de l'agent spécialisé réseau et infrastructure.

**Contenu:**
- Identité: Spectre-Network, spécialiste infrastructure réseau
- Méthodologie :
  1. Network Discovery (nmap, masscan, arp-scan)
  2. Service Enumeration (nmap -sV, banner grabbing)
  3. Vulnerability Assessment (nuclei, searchsploit, nmap NSE)
  4. Network-level Attacks (MITM, ARP spoofing si pertinent)
  5. Service Exploitation (SSH, FTP, SMTP, SNMP, databases)
  6. Pivoting (chisel, socat, SSH tunnels)
  7. Internal Network Mapping (après pivot)
- Focus sur : pivoting, tunnel management, internal network cartography
- Arbres de décision par service/port (les 50 ports les plus courants)
- Hérite OPSEC de SOUL.md

**Critères de validation:**
- Couverture des 50 ports/services les plus courants
- Workflow de pivoting détaillé
- Gestion de tunnels (chisel, SSH, socat)

---

### TICKET-014: Agent spécialisé Reverse Engineering (spectre-re)
**Fichier:** `workspace/agents/re-agent.md`
**Statut:** [ ] TODO
**Dépendances:** TICKET-010
**Description:**
Créer le profil de l'agent spécialisé reverse engineering.

**Contenu:**
- Identité: Spectre-RE, spécialiste analyse de binaires
- Méthodologie :
  1. Triage (file, binwalk, strings, entropy analysis)
  2. Static Analysis (radare2, objdump, readelf)
  3. Dynamic Analysis (gdb, ltrace, strace)
  4. Vulnerability Discovery (buffer overflows, format strings, use-after-free)
  5. Exploit Development (ROP chains, shellcode, bypass ASLR/NX/PIE)
- Focus sur : CTF binary exploitation, firmware analysis
- Hérite OPSEC de SOUL.md (sauf si analyse locale)

**Critères de validation:**
- Workflow d'analyse statique et dynamique
- Techniques d'exploitation mémoire courantes
- Adapté au contexte CTF

---

### TICKET-015: Mécanisme de délégation dans SOUL.md
**Fichier:** Ajout dans SOUL.md (TICKET-002) ou fichier séparé
**Statut:** [ ] TODO
**Dépendances:** TICKET-010, TICKET-011, TICKET-012, TICKET-013
**Description:**
Ajouter dans SOUL.md les règles de délégation automatique :

**Triggers de délégation:**
- Web app complexe détectée (SPA, API REST, auth flow) → déléguer à spectre-web
- Port 88/389/445 + domaine Windows détecté → déléguer à spectre-ad
- Pivot interne nécessaire (réseau différent découvert) → déléguer à spectre-network
- Binaire à analyser (CTF, firmware) → déléguer à spectre-re

**Mécanisme:**
- Spectre (main) détecte le domaine lors de PHASE 2 (ENUMERATION)
- Crée un sous-engagement ou ajoute un contexte spécialisé
- Utilise skills parallel-agents ou tmux-agents pour lancer l'agent spécialisé
- L'agent spécialisé écrit ses findings dans le même `engagements/<target>/`
- Spectre (main) intègre les résultats dans STATE.md

**Critères de validation:**
- Triggers clairs et non ambigus
- Mécanisme de communication entre agents documenté
- Fallback : si pas d'agent spécialisé → Spectre gère lui-même

---

## Phase 7 — Hardening & polish (P3)

### TICKET-016: Test d'intégration complet
**Statut:** [ ] TODO
**Dépendances:** Tous les tickets P0 et P1
**Description:**
Tester le système complet sur une cible CTF (ex: HackTheBox) :
- Vérifier que l'agent ne s'arrête pas prématurément
- Vérifier la reprise de session via STATE.md
- Vérifier les notifications dans le chat
- Vérifier la boucle cognitive (output structuré après chaque action)
- Vérifier les pivots sur dead end
- Mesurer la consommation de contexte avec num_ctx 49152
- Ajuster température/top_p si nécessaire

---

### TICKET-017: Optimisation du watchdog pour la v2
**Fichier:** `scripts/openclaw-watchdog.sh`
**Statut:** [ ] TODO
**Dépendances:** TICKET-005
**Description:**
Adapter le watchdog pour détecter les cas supplémentaires :
- Session active mais aucune action depuis > 5 minutes (agent idle)
- STATE.md non mis à jour depuis > 10 minutes pendant un engagement actif
- Contexte overflow (si détectable via logs)

**Note:** À évaluer après les tests d'intégration (TICKET-016). Peut ne pas être nécessaire si la boucle cognitive fonctionne bien.

---

## Ordre d'implémentation recommandé

```
TICKET-001 (Modelfile)           ─┐
TICKET-003 (METHODOLOGY.md)      ─┼─ Parallélisables
TICKET-005 (STATE.md template)   ─┘
         │
         ▼
TICKET-002 (SOUL.md)             ← dépend de 001, 003
         │
         ▼
TICKET-004 (AGENTS.md)           ← dépend de 002, 003, 005
TICKET-006 (format notes.md)     ← intégré dans 004
TICKET-007 (anti-stagnation)     ← intégré dans 002
TICKET-008 (notifications)       ← intégré dans 002 + 004
TICKET-009 (IDENTITY.md)         ← indépendant
         │
         ▼
TICKET-010 (AGENTS-REGISTRY.md)  ← dépend de 003
         │
         ▼
TICKET-011 (spectre-web)         ─┐
TICKET-012 (spectre-ad)          ─┼─ Parallélisables
TICKET-013 (spectre-network)     ─┘
TICKET-014 (spectre-re)          ─┘
         │
         ▼
TICKET-015 (délégation)          ← dépend de 010-014
         │
         ▼
TICKET-016 (test intégration)
TICKET-017 (watchdog v2)
```
