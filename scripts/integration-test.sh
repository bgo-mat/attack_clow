#!/bin/bash
# =============================================================
# TICKET-016: Test d'intégration complet — Spectre v2
# =============================================================
# Validates that ALL components of the Spectre system work
# together correctly before deployment on a real engagement.
#
# Usage:
#   ./integration-test.sh              # Run all tests
#   ./integration-test.sh --live       # Include live service tests
#   ./integration-test.sh --simulate   # Run simulated engagement cycle
# =============================================================

set -uo pipefail

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# --- Counters ---
PASS=0
FAIL=0
WARN=0
SKIP=0

# --- Paths ---
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORKSPACE="$REPO_DIR/workspace"
CONFIGS="$REPO_DIR/configs"
SCRIPTS="$REPO_DIR/scripts"

# Installed paths (used for --live tests)
INSTALLED_WORKSPACE="/root/.openclaw/workspace"
INSTALLED_CONFIG="/root/.openclaw/openclaw.json"
GATEWAY_PORT=18790

# --- Flags ---
LIVE=false
SIMULATE=false
for arg in "$@"; do
    case "$arg" in
        --live) LIVE=true ;;
        --simulate) SIMULATE=true ;;
    esac
done

# --- Helpers ---
pass() { ((PASS++)); echo -e "  ${GREEN}PASS${NC} $1"; }
fail() { ((FAIL++)); echo -e "  ${RED}FAIL${NC} $1"; }
warn() { ((WARN++)); echo -e "  ${YELLOW}WARN${NC} $1"; }
skip() { ((SKIP++)); echo -e "  ${CYAN}SKIP${NC} $1"; }
section() { echo -e "\n${BOLD}=== $1 ===${NC}"; }

file_exists()   { [ -f "$1" ]; }
dir_exists()    { [ -d "$1" ]; }
file_contains() { grep -q "$2" "$1" 2>/dev/null; }
file_lines()    { wc -l < "$1" 2>/dev/null | tr -d ' '; }
count_matches() { grep -c "$2" "$1" 2>/dev/null || echo 0; }

# =============================================================
# TEST SUITE 1: File Structure Validation
# =============================================================
test_file_structure() {
    section "1. File Structure"

    local required_files=(
        "$WORKSPACE/SOUL.md"
        "$WORKSPACE/AGENTS.md"
        "$WORKSPACE/METHODOLOGY.md"
        "$WORKSPACE/IDENTITY.md"
        "$WORKSPACE/TOOLS.md"
        "$WORKSPACE/AGENTS-REGISTRY.md"
        "$WORKSPACE/USER.md"
        "$WORKSPACE/templates/STATE.md"
        "$WORKSPACE/agents/web-agent.md"
        "$WORKSPACE/agents/ad-agent.md"
        "$WORKSPACE/agents/network-agent.md"
        "$WORKSPACE/agents/re-agent.md"
        "$WORKSPACE/scripts/opsec-check.sh"
        "$WORKSPACE/scripts/tor-rotate.sh"
        "$WORKSPACE/scripts/stealth-wrapper.sh"
        "$CONFIGS/ollama/Modelfile"
        "$CONFIGS/openclaw.json"
        "$CONFIGS/exec-approvals.json"
        "$CONFIGS/proxychains/proxychains4.conf"
        "$CONFIGS/tor/torrc"
        "$CONFIGS/caddy/Caddyfile"
        "$CONFIGS/systemd/openclaw-gateway.service"
        "$SCRIPTS/openclaw-watchdog.sh"
        "$REPO_DIR/install.sh"
    )

    for f in "${required_files[@]}"; do
        local rel="${f#$REPO_DIR/}"
        if file_exists "$f"; then
            pass "$rel exists"
        else
            fail "$rel MISSING"
        fi
    done

    # Check directories
    for d in "$WORKSPACE/agents" "$WORKSPACE/templates" "$WORKSPACE/scripts"; do
        local rel="${d#$REPO_DIR/}"
        if dir_exists "$d"; then
            pass "$rel/ directory exists"
        else
            fail "$rel/ directory MISSING"
        fi
    done
}

# =============================================================
# TEST SUITE 2: Modelfile Validation
# =============================================================
test_modelfile() {
    section "2. Modelfile Configuration"
    local mf="$CONFIGS/ollama/Modelfile"

    # Temperature
    if file_contains "$mf" "temperature 0.55"; then
        pass "Temperature = 0.55"
    else
        fail "Temperature should be 0.55"
    fi

    # num_ctx
    if file_contains "$mf" "num_ctx 131072"; then
        pass "num_ctx = 131072"
    else
        fail "num_ctx should be 131072"
    fi

    # Cognitive loop in system prompt
    if file_contains "$mf" "COGNITIVE LOOP"; then
        pass "Cognitive loop present in system prompt"
    else
        fail "Cognitive loop MISSING from system prompt"
    fi

    # Persistence rules
    if file_contains "$mf" "NEVER stop"; then
        pass "Persistence rule (NEVER stop) present"
    else
        fail "Persistence rule MISSING"
    fi

    # OPSEC in system prompt
    if file_contains "$mf" "proxychains4"; then
        pass "OPSEC (proxychains4) in system prompt"
    else
        fail "OPSEC rule MISSING from system prompt"
    fi

    # Compact prompt (< 600 tokens ~= < 50 lines)
    local lines
    lines=$(file_lines "$mf")
    if [ "$lines" -lt 50 ]; then
        pass "System prompt is compact ($lines lines)"
    else
        warn "System prompt may be too long ($lines lines, target < 50)"
    fi

    # Language: system prompt in English
    if file_contains "$mf" "SYSTEM \"\"\"You are Spectre"; then
        pass "System prompt in English"
    else
        warn "System prompt may not be in English"
    fi

    # French response instruction
    if file_contains "$mf" "French\|français\|en français"; then
        pass "French response instruction present"
    else
        if file_contains "$mf" "French"; then
            pass "French response instruction present"
        else
            warn "French response instruction not found"
        fi
    fi
}

# =============================================================
# TEST SUITE 3: SOUL.md Validation
# =============================================================
test_soul() {
    section "3. SOUL.md — Core Identity & Cognitive Loop"
    local soul="$WORKSPACE/SOUL.md"

    # Cognitive loop stages
    local stages=("THINK" "ACT" "OBSERVE" "ANALYZE" "DECIDE" "UPDATE" "NOTIFY" "LOOP")
    for stage in "${stages[@]}"; do
        if file_contains "$soul" "\[${stage}\]"; then
            pass "Cognitive loop stage [$stage] defined"
        else
            fail "Cognitive loop stage [$stage] MISSING"
        fi
    done

    # Persistence rules
    if file_contains "$soul" "persistent agent\|NEVER stop\|never stops"; then
        pass "Persistence rule present"
    else
        fail "Persistence rule MISSING"
    fi

    # Anti-stagnation (TICKET-007)
    if file_contains "$soul" "3.*attempt\|3.*fail\|3+.*attempt"; then
        pass "Anti-stagnation pivot rule (3 failures → pivot)"
    else
        fail "Anti-stagnation pivot rule MISSING"
    fi

    # Self-check mechanism
    if file_contains "$soul" "progress\|self-check\|Am I making"; then
        pass "Progress self-check mechanism present"
    else
        warn "Explicit self-check mechanism not found"
    fi

    # OPSEC rules
    if file_contains "$soul" "proxychains\|OPSEC"; then
        pass "OPSEC rules referenced"
    else
        fail "OPSEC rules MISSING"
    fi

    # Agent delegation (TICKET-015)
    if file_contains "$soul" "spectre-web\|spectre-ad\|delegat"; then
        pass "Agent delegation rules present"
    else
        fail "Agent delegation MISSING (TICKET-015)"
    fi

    # Communication language rule
    if file_contains "$soul" "French\|français"; then
        pass "French communication rule present"
    else
        warn "French communication rule not found"
    fi

    # File length check (< 200 lines)
    local lines
    lines=$(file_lines "$soul")
    if [ "$lines" -le 200 ]; then
        pass "SOUL.md is compact ($lines lines, target ≤ 200)"
    else
        warn "SOUL.md is $lines lines (target ≤ 200)"
    fi
}

# =============================================================
# TEST SUITE 4: METHODOLOGY.md Validation
# =============================================================
test_methodology() {
    section "4. METHODOLOGY.md — Phase State Machine"
    local meth="$WORKSPACE/METHODOLOGY.md"

    # All phases present
    local phases=(
        "PHASE 0\|OPSEC_SETUP\|OPSEC"
        "PHASE 1\|RECONNAISSANCE"
        "PHASE 2\|ENUMERATION"
        "PHASE 3\|VULNERABILITY"
        "PHASE 4\|EXPLOITATION"
        "PHASE 5\|POST.EXPLOITATION"
        "PHASE 5B\|LATERAL"
        "PHASE 6\|REPORTING"
    )
    for phase_pattern in "${phases[@]}"; do
        local label
        label=$(echo "$phase_pattern" | sed 's/\\|.*//; s/\\//g')
        if grep -qE "$(echo "$phase_pattern" | sed 's/\\|/|/g')" "$meth" 2>/dev/null; then
            pass "$label defined"
        else
            fail "$label MISSING"
        fi
    done

    # Exit criteria for phases
    local exit_count
    exit_count=$(count_matches "$meth" "[Ee]xit [Cc]riter\|[Tt]ransition\|→ PHASE")
    if [ "$exit_count" -ge 6 ]; then
        pass "Phase transitions/exit criteria defined ($exit_count references)"
    else
        warn "Limited phase transition definitions ($exit_count found, expected ≥ 6)"
    fi

    # OWASP integration in Phase 3
    if file_contains "$meth" "OWASP\|OTG-"; then
        pass "OWASP methodology integrated"
    else
        fail "OWASP integration MISSING in Phase 3"
    fi

    # Decision trees
    if grep -qi "port.*80\|port.*443\|port.*22\|port.*445" "$meth" 2>/dev/null; then
        pass "Port-based decision trees present"
    else
        fail "Port-based decision trees MISSING"
    fi

    # Non-stop rules per phase
    if file_contains "$meth" "do NOT skip\|return.*PHASE\|not mean.*over\|NOT achieved"; then
        pass "Non-stop rules per phase defined"
    else
        fail "Non-stop rules MISSING"
    fi

    # Dead end handling
    if file_contains "$meth" "[Dd]ead [Ee]nd\|pivot\|fail"; then
        pass "Dead end / pivot handling defined"
    else
        fail "Dead end handling MISSING"
    fi
}

# =============================================================
# TEST SUITE 5: AGENTS.md Validation
# =============================================================
test_agents() {
    section "5. AGENTS.md — Startup Flow & State Management"
    local agents="$WORKSPACE/AGENTS.md"

    # Startup flow
    if file_contains "$agents" "[Ss]tartup\|[Bb]oot"; then
        pass "Startup flow defined"
    else
        fail "Startup flow MISSING"
    fi

    # STATE.md check on startup
    if file_contains "$agents" "STATE.md"; then
        pass "STATE.md referenced in startup flow"
    else
        fail "STATE.md check MISSING from startup flow"
    fi

    # Session resumption
    if file_contains "$agents" "[Rr]esum\|[Rr]eprise\|active engagement"; then
        pass "Session resumption logic defined"
    else
        fail "Session resumption MISSING"
    fi

    # Notes format (TICKET-006)
    if file_contains "$agents" "notes.md\|YYYY-MM-DD\|[Aa]ppend"; then
        pass "Structured notes format defined (TICKET-006)"
    else
        fail "Structured notes format MISSING"
    fi

    # Notification format (TICKET-008)
    if file_contains "$agents" "\[SPECTRE.*|"; then
        pass "Notification format defined (TICKET-008)"
    else
        if file_contains "$agents" "SPECTRE.*PHASE_CHANGE\|SPECTRE.*FINDING\|notification"; then
            pass "Notification format defined (TICKET-008)"
        else
            fail "Notification format MISSING"
        fi
    fi

    # OPSEC reference
    if file_contains "$agents" "opsec-check\|OPSEC"; then
        pass "OPSEC reference present"
    else
        warn "OPSEC reference not found in AGENTS.md"
    fi
}

# =============================================================
# TEST SUITE 6: STATE.md Template Validation
# =============================================================
test_state_template() {
    section "6. STATE.md Template — Engagement Tracking"
    local state="$WORKSPACE/templates/STATE.md"

    # Required sections
    local sections=(
        "Objective"
        "Status\|Current Phase"
        "OPSEC"
        "Attack Surface"
        "Vulnerabilities\|Findings"
        "Credentials"
        "Access Obtained"
        "Completed Phases\|Phase.*Checklist"
        "Dead Ends"
        "Next Actions"
    )
    for section_pattern in "${sections[@]}"; do
        local label
        label=$(echo "$section_pattern" | sed 's/\\|.*//; s/\\//g')
        if grep -qE "$(echo "$section_pattern" | sed 's/\\|/|/g')" "$state" 2>/dev/null; then
            pass "Section: $label"
        else
            fail "Section MISSING: $label"
        fi
    done

    # Phase checklist covers all phases
    local phase_checks
    phase_checks=$(count_matches "$state" "PHASE\|Phase [0-9]")
    if [ "$phase_checks" -ge 6 ]; then
        pass "Phase checklist covers all phases ($phase_checks entries)"
    else
        warn "Phase checklist may be incomplete ($phase_checks entries, expected ≥ 6)"
    fi

    # Tables for structured data
    local table_count
    table_count=$(count_matches "$state" "|.*|.*|.*|")
    if [ "$table_count" -ge 3 ]; then
        pass "Structured tables present ($table_count rows)"
    else
        warn "Limited structured tables ($table_count found)"
    fi
}

# =============================================================
# TEST SUITE 7: Specialized Agents Validation
# =============================================================
test_specialized_agents() {
    section "7. Specialized Agents"

    local agents=(
        "web-agent.md:OWASP:OTG-:10 OWASP categories"
        "ad-agent.md:Kerberos:DCSync\|Golden:AD kill chain"
        "network-agent.md:pivot\|chisel:tunnel:Network pivoting"
        "re-agent.md:radare2\|r2:gdb\|GDB:Reverse engineering"
    )

    for entry in "${agents[@]}"; do
        IFS=':' read -r filename check1 check2 label <<< "$entry"
        local filepath="$WORKSPACE/agents/$filename"

        if ! file_exists "$filepath"; then
            fail "$filename MISSING"
            continue
        fi
        pass "$filename exists"

        if grep -qE "$(echo "$check1" | sed 's/\\|/|/g')" "$filepath" 2>/dev/null; then
            pass "$filename: $label — primary methodology present"
        else
            fail "$filename: primary methodology keyword not found"
        fi

        if grep -qE "$(echo "$check2" | sed 's/\\|/|/g')" "$filepath" 2>/dev/null; then
            pass "$filename: advanced techniques referenced"
        else
            warn "$filename: advanced technique keywords not found"
        fi

        # OPSEC inheritance
        if file_contains "$filepath" "OPSEC\|SOUL.md\|proxychains"; then
            pass "$filename: OPSEC inheritance referenced"
        else
            warn "$filename: OPSEC inheritance not explicitly referenced"
        fi
    done

    # AGENTS-REGISTRY.md
    local registry="$WORKSPACE/AGENTS-REGISTRY.md"
    if file_exists "$registry"; then
        pass "AGENTS-REGISTRY.md exists"

        local agent_names=("spectre-web" "spectre-ad" "spectre-network" "spectre-re")
        for name in "${agent_names[@]}"; do
            if file_contains "$registry" "$name"; then
                pass "Registry lists $name"
            else
                fail "Registry MISSING $name"
            fi
        done

        if file_contains "$registry" "[Dd]elegat"; then
            pass "Delegation rules documented"
        else
            fail "Delegation rules MISSING from registry"
        fi
    else
        fail "AGENTS-REGISTRY.md MISSING"
    fi
}

# =============================================================
# TEST SUITE 8: IDENTITY.md Validation
# =============================================================
test_identity() {
    section "8. IDENTITY.md"
    local id="$WORKSPACE/IDENTITY.md"

    if file_contains "$id" "[Pp]ersistent"; then
        pass "Persistent trait present"
    else
        fail "Persistent trait MISSING (TICKET-009)"
    fi

    if file_contains "$id" "[Mm]ethodical\|[Ss]ystematic\|MITRE\|OWASP"; then
        pass "Methodical trait present"
    else
        warn "Methodical trait not explicitly present"
    fi

    if file_contains "$id" "[Ss]elf.reflect\|evaluat\|progress"; then
        pass "Self-reflective trait present"
    else
        warn "Self-reflective trait not explicitly present"
    fi
}

# =============================================================
# TEST SUITE 9: OPSEC Scripts Validation
# =============================================================
test_opsec_scripts() {
    section "9. OPSEC Scripts"

    # opsec-check.sh
    local opsec="$WORKSPACE/scripts/opsec-check.sh"
    if file_exists "$opsec"; then
        pass "opsec-check.sh exists"
        if file_contains "$opsec" "tor\|Tor\|9050"; then
            pass "opsec-check.sh verifies Tor"
        else
            warn "opsec-check.sh may not verify Tor"
        fi
        if [ -x "$opsec" ]; then
            pass "opsec-check.sh is executable"
        else
            warn "opsec-check.sh is NOT executable"
        fi
    else
        fail "opsec-check.sh MISSING"
    fi

    # tor-rotate.sh
    local rotate="$WORKSPACE/scripts/tor-rotate.sh"
    if file_exists "$rotate"; then
        pass "tor-rotate.sh exists"
        if file_contains "$rotate" "circuit\|NEWNYM\|rotate"; then
            pass "tor-rotate.sh handles circuit rotation"
        else
            warn "tor-rotate.sh may not handle circuit rotation"
        fi
    else
        fail "tor-rotate.sh MISSING"
    fi

    # stealth-wrapper.sh
    local stealth="$WORKSPACE/scripts/stealth-wrapper.sh"
    if file_exists "$stealth"; then
        pass "stealth-wrapper.sh exists"
        if file_contains "$stealth" "proxychains\|delay\|random"; then
            pass "stealth-wrapper.sh wraps with proxy + randomization"
        else
            warn "stealth-wrapper.sh may not properly wrap commands"
        fi
    else
        fail "stealth-wrapper.sh MISSING"
    fi
}

# =============================================================
# TEST SUITE 10: Watchdog Validation
# =============================================================
test_watchdog() {
    section "10. Watchdog v2"
    local wd="$SCRIPTS/openclaw-watchdog.sh"

    if ! file_exists "$wd"; then
        fail "openclaw-watchdog.sh MISSING"
        return
    fi
    pass "openclaw-watchdog.sh exists"

    # 5 detection cases
    local checks=(
        "gateway_alive:Gateway alive check"
        "session_is_stuck:Stuck session detection"
        "session_is_idle\|IDLE:Idle session detection"
        "state_is_stale\|STATE:Stale STATE.md detection"
        "context_overflow\|overflow:Context overflow detection"
    )
    for entry in "${checks[@]}"; do
        IFS=':' read -r pattern label <<< "$entry"
        if grep -qE "$(echo "$pattern" | sed 's/\\|/|/g')" "$wd" 2>/dev/null; then
            pass "Watchdog: $label"
        else
            fail "Watchdog MISSING: $label"
        fi
    done

    # Restart mechanism
    if file_contains "$wd" "restart_gateway"; then
        pass "Watchdog: restart mechanism present"
    else
        fail "Watchdog: restart mechanism MISSING"
    fi

    # Notification mechanism
    if file_contains "$wd" "notify_operator\|NOTIFY"; then
        pass "Watchdog: operator notification present"
    else
        fail "Watchdog: operator notification MISSING"
    fi

    if [ -x "$wd" ]; then
        pass "Watchdog is executable"
    else
        warn "Watchdog is NOT executable"
    fi
}

# =============================================================
# TEST SUITE 11: Cross-Reference Integrity
# =============================================================
test_cross_references() {
    section "11. Cross-Reference Integrity"

    # SOUL.md references METHODOLOGY.md
    if file_contains "$WORKSPACE/SOUL.md" "METHODOLOGY.md"; then
        pass "SOUL.md → METHODOLOGY.md reference"
    else
        warn "SOUL.md doesn't reference METHODOLOGY.md"
    fi

    # AGENTS.md references SOUL.md
    if file_contains "$WORKSPACE/AGENTS.md" "SOUL.md"; then
        pass "AGENTS.md → SOUL.md reference"
    else
        warn "AGENTS.md doesn't reference SOUL.md"
    fi

    # AGENTS.md references STATE.md
    if file_contains "$WORKSPACE/AGENTS.md" "STATE.md"; then
        pass "AGENTS.md → STATE.md reference"
    else
        fail "AGENTS.md doesn't reference STATE.md"
    fi

    # AGENTS.md references METHODOLOGY.md
    if file_contains "$WORKSPACE/AGENTS.md" "METHODOLOGY.md"; then
        pass "AGENTS.md → METHODOLOGY.md reference"
    else
        warn "AGENTS.md doesn't reference METHODOLOGY.md"
    fi

    # AGENTS.md references TOOLS.md
    if file_contains "$WORKSPACE/AGENTS.md" "TOOLS.md"; then
        pass "AGENTS.md → TOOLS.md reference"
    else
        warn "AGENTS.md doesn't reference TOOLS.md"
    fi

    # Modelfile references SOUL.md and METHODOLOGY.md
    if file_contains "$CONFIGS/ollama/Modelfile" "SOUL.md"; then
        pass "Modelfile → SOUL.md reference"
    else
        warn "Modelfile doesn't reference SOUL.md"
    fi

    if file_contains "$CONFIGS/ollama/Modelfile" "METHODOLOGY.md"; then
        pass "Modelfile → METHODOLOGY.md reference"
    else
        warn "Modelfile doesn't reference METHODOLOGY.md"
    fi

    # Agent profiles reference SOUL.md for OPSEC
    for agent_file in "$WORKSPACE/agents/"*.md; do
        local name
        name=$(basename "$agent_file")
        if file_contains "$agent_file" "SOUL.md\|OPSEC"; then
            pass "$name → OPSEC/SOUL.md reference"
        else
            warn "$name doesn't reference OPSEC/SOUL.md"
        fi
    done
}

# =============================================================
# TEST SUITE 12: Configuration Consistency
# =============================================================
test_config_consistency() {
    section "12. Configuration Consistency"

    # Tor config: 4 SOCKS ports
    local torrc="$CONFIGS/tor/torrc"
    if file_exists "$torrc"; then
        local socks_count
        socks_count=$(count_matches "$torrc" "SocksPort\|SOCKSPort")
        if [ "$socks_count" -ge 4 ]; then
            pass "Tor: $socks_count SOCKS ports configured"
        else
            warn "Tor: only $socks_count SOCKS ports (expected 4)"
        fi
    else
        fail "torrc MISSING"
    fi

    # Proxychains points to Tor
    local pc="$CONFIGS/proxychains/proxychains4.conf"
    if file_exists "$pc"; then
        if file_contains "$pc" "9050\|socks"; then
            pass "Proxychains routes through Tor (port 9050)"
        else
            fail "Proxychains not configured for Tor"
        fi
        if file_contains "$pc" "dynamic_chain\|strict_chain"; then
            pass "Proxychains chain type configured"
        else
            warn "Proxychains chain type not found"
        fi
    else
        fail "proxychains4.conf MISSING"
    fi

    # exec-approvals.json is valid JSON
    local ea="$CONFIGS/exec-approvals.json"
    if file_exists "$ea"; then
        if python3 -m json.tool "$ea" >/dev/null 2>&1 || jq empty "$ea" 2>/dev/null; then
            pass "exec-approvals.json is valid JSON"
        else
            fail "exec-approvals.json is INVALID JSON"
        fi
    else
        fail "exec-approvals.json MISSING"
    fi

    # openclaw.json is valid JSON
    local oc="$CONFIGS/openclaw.json"
    if file_exists "$oc"; then
        if python3 -m json.tool "$oc" >/dev/null 2>&1 || jq empty "$oc" 2>/dev/null; then
            pass "openclaw.json is valid JSON"
        else
            fail "openclaw.json is INVALID JSON"
        fi
        # Check model reference
        if file_contains "$oc" "spectre"; then
            pass "openclaw.json references spectre model"
        else
            warn "openclaw.json doesn't reference spectre model"
        fi
    else
        fail "openclaw.json MISSING"
    fi
}

# =============================================================
# TEST SUITE 13: Cognitive Loop Integration
# =============================================================
test_cognitive_loop_integration() {
    section "13. Cognitive Loop Integration"

    # Loop defined in Modelfile
    if file_contains "$CONFIGS/ollama/Modelfile" "THINK.*ACT.*OBSERVE"; then
        pass "Cognitive loop in Modelfile (compact)"
    elif file_contains "$CONFIGS/ollama/Modelfile" "COGNITIVE LOOP"; then
        pass "Cognitive loop header in Modelfile"
    else
        fail "Cognitive loop MISSING from Modelfile"
    fi

    # Loop defined in SOUL.md (detailed)
    local loop_stages
    loop_stages=$(count_matches "$WORKSPACE/SOUL.md" "\[THINK\]\|\[ACT\]\|\[OBSERVE\]\|\[ANALYZE\]\|\[DECIDE\]\|\[UPDATE\]\|\[NOTIFY\]\|\[LOOP\]")
    if [ "$loop_stages" -ge 6 ]; then
        pass "Full cognitive loop in SOUL.md ($loop_stages stages)"
    else
        warn "Incomplete cognitive loop in SOUL.md ($loop_stages stages found)"
    fi

    # STATE.md update is part of the loop
    if file_contains "$WORKSPACE/SOUL.md" "UPDATE.*STATE\|state.*update\|Update STATE"; then
        pass "STATE.md update integrated in cognitive loop"
    else
        warn "STATE.md update not explicitly in cognitive loop"
    fi

    # Notification step in loop
    if file_contains "$WORKSPACE/SOUL.md" "\[NOTIFY\]\|notify.*operator\|notification"; then
        pass "Notification step in cognitive loop"
    else
        warn "Notification step not explicit in loop"
    fi
}

# =============================================================
# TEST SUITE 14: Non-Stop Behavior Validation
# =============================================================
test_nonstop_behavior() {
    section "14. Non-Stop / Persistence Behavior"

    # Multiple layers of persistence enforcement
    local persistence_points=0

    # Layer 1: Modelfile
    if file_contains "$CONFIGS/ollama/Modelfile" "NEVER stop\|NEVER conclude\|do NOT stop"; then
        pass "Persistence enforced in Modelfile"
        ((persistence_points++))
    else
        fail "Persistence NOT enforced in Modelfile"
    fi

    # Layer 2: SOUL.md
    if file_contains "$WORKSPACE/SOUL.md" "never stop\|NEVER stop\|persistent agent\|do NOT stop"; then
        pass "Persistence enforced in SOUL.md"
        ((persistence_points++))
    else
        fail "Persistence NOT enforced in SOUL.md"
    fi

    # Layer 3: METHODOLOGY.md
    if file_contains "$WORKSPACE/METHODOLOGY.md" "does not mean.*over\|NOT achieved.*return\|do NOT skip"; then
        pass "Persistence enforced in METHODOLOGY.md"
        ((persistence_points++))
    else
        if file_contains "$WORKSPACE/METHODOLOGY.md" "return\|loop\|retry\|NOT"; then
            pass "Persistence/retry logic in METHODOLOGY.md"
            ((persistence_points++))
        else
            warn "Persistence not clearly enforced in METHODOLOGY.md"
        fi
    fi

    # Layer 4: Watchdog (detects idle)
    if file_contains "$SCRIPTS/openclaw-watchdog.sh" "idle\|IDLE"; then
        pass "Watchdog detects idle agent"
        ((persistence_points++))
    else
        warn "Watchdog doesn't detect idle agent"
    fi

    if [ "$persistence_points" -ge 3 ]; then
        pass "Multi-layer persistence: $persistence_points/4 layers active"
    else
        fail "Insufficient persistence layers: $persistence_points/4 (need ≥ 3)"
    fi
}

# =============================================================
# TEST SUITE 15: Notification System Validation
# =============================================================
test_notification_system() {
    section "15. Notification System (TICKET-008)"

    local agents="$WORKSPACE/AGENTS.md"
    local soul="$WORKSPACE/SOUL.md"

    local notification_types=(
        "PHASE_CHANGE:Phase change notification"
        "FINDING:Finding notification"
        "ACCESS:Access gained notification"
        "CREDS:Credentials found notification"
        "PIVOT:Pivot/dead-end notification"
        "STUCK:Stuck notification"
        "PROGRESS:Progress summary notification"
    )

    local found=0
    for entry in "${notification_types[@]}"; do
        IFS=':' read -r tag label <<< "$entry"
        if file_contains "$agents" "$tag" || file_contains "$soul" "$tag"; then
            pass "$label"
            ((found++))
        else
            warn "$label not found"
        fi
    done

    if [ "$found" -ge 5 ]; then
        pass "Notification system coverage: $found/${#notification_types[@]} types"
    else
        warn "Limited notification coverage: $found/${#notification_types[@]} types"
    fi
}

# =============================================================
# TEST SUITE 16: Live Service Tests (--live)
# =============================================================
test_live_services() {
    section "16. Live Service Tests"

    if ! $LIVE; then
        skip "Live tests skipped (use --live to enable)"
        return
    fi

    # Ollama running
    if curl -s --max-time 5 http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
        pass "Ollama is running (port 11434)"

        # Spectre model exists
        if curl -s http://127.0.0.1:11434/api/tags | grep -q "spectre"; then
            pass "Spectre model loaded in Ollama"
        else
            fail "Spectre model NOT found in Ollama"
        fi
    else
        fail "Ollama is NOT running"
    fi

    # Gateway running
    if curl -s --max-time 5 "http://127.0.0.1:${GATEWAY_PORT}" >/dev/null 2>&1; then
        pass "OpenClaw gateway is running (port $GATEWAY_PORT)"
    else
        fail "OpenClaw gateway is NOT running"
    fi

    # Tor running
    if curl -s --max-time 10 --socks5 127.0.0.1:9050 https://check.torproject.org/api/ip 2>/dev/null | grep -q '"IsTor":true'; then
        pass "Tor is running and functional"
    else
        if ss -tlnp 2>/dev/null | grep -q ":9050"; then
            warn "Tor port 9050 is open but connectivity check failed"
        else
            fail "Tor is NOT running (port 9050 not listening)"
        fi
    fi

    # Caddy running
    if ss -tlnp 2>/dev/null | grep -q ":443"; then
        pass "Caddy HTTPS is running (port 443)"
    else
        warn "Caddy HTTPS not detected on port 443"
    fi

    # Installed workspace
    if dir_exists "$INSTALLED_WORKSPACE"; then
        pass "Workspace installed at $INSTALLED_WORKSPACE"
    else
        warn "Workspace not installed yet at $INSTALLED_WORKSPACE"
    fi

    # Key tools available
    local tools=("nmap" "ffuf" "sqlmap" "nuclei" "subfinder" "hydra" "nikto" "gobuster" "hashcat" "msfconsole")
    local tools_found=0
    for tool in "${tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            ((tools_found++))
        else
            warn "Tool not found: $tool"
        fi
    done
    if [ "$tools_found" -eq "${#tools[@]}" ]; then
        pass "All $tools_found key tools available"
    elif [ "$tools_found" -ge 7 ]; then
        warn "$tools_found/${#tools[@]} key tools available"
    else
        fail "Only $tools_found/${#tools[@]} key tools available"
    fi

    # SecLists
    if dir_exists "/usr/share/seclists"; then
        pass "SecLists installed"
    else
        warn "SecLists not found at /usr/share/seclists"
    fi
}

# =============================================================
# TEST SUITE 17: Simulated Engagement Cycle (--simulate)
# =============================================================
test_simulated_engagement() {
    section "17. Simulated Engagement Cycle"

    if ! $SIMULATE; then
        skip "Simulation skipped (use --simulate to enable)"
        return
    fi

    local sim_dir
    sim_dir=$(mktemp -d /tmp/spectre-sim-XXXXXX)
    local target_dir="$sim_dir/engagements/sim-target"
    mkdir -p "$target_dir"

    # Step 1: Create STATE.md from template
    if cp "$WORKSPACE/templates/STATE.md" "$target_dir/STATE.md" 2>/dev/null; then
        # Replace placeholders
        sed -i "s/{TARGET}/sim-target/g; s/{timestamp}/$(date -u '+%Y-%m-%d %H:%M:%S UTC')/g; s/{Operator.*}/Simulate full engagement cycle/g" "$target_dir/STATE.md" 2>/dev/null
        pass "STATE.md created from template"
    else
        fail "Could not create STATE.md from template"
        rm -rf "$sim_dir"
        return
    fi

    # Step 2: Verify STATE.md is parseable
    if file_contains "$target_dir/STATE.md" "sim-target"; then
        pass "STATE.md target placeholder replaced"
    else
        warn "STATE.md placeholder replacement may have failed"
    fi

    # Step 3: Simulate notes.md entry
    cat > "$target_dir/notes.md" << 'NOTES_EOF'
## 2026-03-16 10:00 | PHASE 0 | OPSEC verification
**Tool:** opsec-check.sh
**Command:** `./opsec-check.sh`
**Result:** Tor OK, exit IP 185.x.x.x, proxychains functional
**Analysis:** OPSEC stack is operational, safe to proceed
**Next:** Begin Phase 1 reconnaissance
---
## 2026-03-16 10:05 | PHASE 1 | Port scan
**Tool:** nmap
**Command:** `proxychains4 nmap -sT -T2 -sV -p- sim-target`
**Result:** Ports 22, 80, 443 open. SSH OpenSSH 8.2, Apache 2.4.41
**Analysis:** Web server present, SSH for potential access. Focus on web first.
**Next:** Web technology identification with whatweb
---
NOTES_EOF
    if file_exists "$target_dir/notes.md"; then
        pass "notes.md created with structured format"
    else
        fail "notes.md creation failed"
    fi

    # Step 4: Verify notes format compliance
    local note_fields=0
    for field in "Tool:" "Command:" "Result:" "Analysis:" "Next:"; do
        if file_contains "$target_dir/notes.md" "$field"; then
            ((note_fields++))
        fi
    done
    if [ "$note_fields" -eq 5 ]; then
        pass "Notes format has all 5 required fields"
    else
        fail "Notes format incomplete ($note_fields/5 fields)"
    fi

    # Step 5: Simulate phase transition in STATE.md
    sed -i 's/PHASE_0_OPSEC_SETUP/PHASE_1_RECONNAISSANCE/' "$target_dir/STATE.md" 2>/dev/null
    sed -i 's/\[ \] PHASE 0/[x] PHASE 0/' "$target_dir/STATE.md" 2>/dev/null
    if file_contains "$target_dir/STATE.md" "PHASE_1_RECONNAISSANCE\|PHASE 1"; then
        pass "Phase transition simulated (0 → 1)"
    else
        warn "Phase transition simulation may have failed"
    fi

    # Step 6: Simulate finding addition
    if file_contains "$target_dir/STATE.md" "Vulnerabilities\|Findings"; then
        pass "Findings section ready for entries"
    else
        warn "Findings section not found in STATE.md"
    fi

    # Step 7: Simulate dead end documentation
    if file_contains "$target_dir/STATE.md" "Dead Ends"; then
        pass "Dead ends section available for pivot documentation"
    else
        warn "Dead ends section not found"
    fi

    # Step 8: Simulate next actions queue
    if file_contains "$target_dir/STATE.md" "Next Actions"; then
        pass "Next actions queue available"
    else
        warn "Next actions queue not found"
    fi

    # Cleanup
    rm -rf "$sim_dir"
    pass "Simulation cleanup complete"
}

# =============================================================
# TEST SUITE 18: TOOLS.md Coverage
# =============================================================
test_tools_coverage() {
    section "18. TOOLS.md — Arsenal Coverage"
    local tools="$WORKSPACE/TOOLS.md"

    if ! file_exists "$tools"; then
        fail "TOOLS.md MISSING"
        return
    fi

    # Key tool categories
    local categories=(
        "nmap:Reconnaissance/scanning"
        "sqlmap:SQL injection"
        "nuclei:Vulnerability scanning"
        "ffuf\|gobuster:Directory fuzzing"
        "hydra\|medusa:Credential bruteforce"
        "metasploit\|msfconsole:Exploitation framework"
        "impacket\|nxc:Post-exploitation"
        "radare2\|r2:Reverse engineering"
        "proxychains:OPSEC"
        "chisel\|socat:Pivoting/tunneling"
    )

    local found=0
    for entry in "${categories[@]}"; do
        IFS=':' read -r pattern label <<< "$entry"
        if grep -qE "$(echo "$pattern" | sed 's/\\|/|/g')" "$tools" 2>/dev/null; then
            pass "TOOLS.md covers: $label"
            ((found++))
        else
            fail "TOOLS.md MISSING: $label"
        fi
    done

    # MCP servers
    local mcp_count
    mcp_count=$(count_matches "$tools" "[Mm][Cc][Pp]\|mcp")
    if [ "$mcp_count" -ge 3 ]; then
        pass "MCP servers documented ($mcp_count references)"
    else
        warn "Limited MCP documentation ($mcp_count references)"
    fi

    # Rate limiting documentation
    if file_contains "$tools" "rate\|delay\|-T2\|-t 2"; then
        pass "Rate limiting documented for OPSEC"
    else
        warn "Rate limiting not documented in TOOLS.md"
    fi
}

# =============================================================
# MAIN
# =============================================================

echo -e "${BOLD}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║     SPECTRE v2 — Integration Test Suite             ║"
echo "║     TICKET-016                                      ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "Repo: $REPO_DIR"
echo "Flags: live=$LIVE simulate=$SIMULATE"

# Run all test suites
test_file_structure
test_modelfile
test_soul
test_methodology
test_agents
test_state_template
test_specialized_agents
test_identity
test_opsec_scripts
test_watchdog
test_cross_references
test_config_consistency
test_cognitive_loop_integration
test_nonstop_behavior
test_notification_system
test_live_services
test_simulated_engagement
test_tools_coverage

# =============================================================
# SUMMARY
# =============================================================
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║                    RESULTS                          ║${NC}"
echo -e "${BOLD}╠══════════════════════════════════════════════════════╣${NC}"
TOTAL=$((PASS + FAIL + WARN + SKIP))
echo -e "  ${GREEN}PASS${NC}: $PASS"
echo -e "  ${RED}FAIL${NC}: $FAIL"
echo -e "  ${YELLOW}WARN${NC}: $WARN"
echo -e "  ${CYAN}SKIP${NC}: $SKIP"
echo -e "  TOTAL: $TOTAL"
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"

if [ "$FAIL" -eq 0 ]; then
    echo -e "\n${GREEN}${BOLD}ALL CRITICAL TESTS PASSED${NC}"
    if [ "$WARN" -gt 0 ]; then
        echo -e "${YELLOW}$WARN warnings to review${NC}"
    fi
    exit 0
else
    echo -e "\n${RED}${BOLD}$FAIL CRITICAL TEST(S) FAILED${NC}"
    echo "Fix the failures above before deploying."
    exit 1
fi
