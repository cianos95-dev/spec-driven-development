#!/usr/bin/env bash
# Resource Freshness Skill Tests — CIA-543
#
# Validates the resource-freshness skill meets all acceptance criteria.
# TDD: Written BEFORE the skill implementation.
#
# Run: bash tests/test-resource-freshness.sh
# Requires: python3 (for YAML/JSON parsing)
#
# Exit codes: 0 = all checks pass, 1 = one or more checks failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_DIR="$PLUGIN_ROOT/skills/resource-freshness"
SKILL_FILE="$SKILL_DIR/SKILL.md"
MANIFEST="$PLUGIN_ROOT/.claude-plugin/marketplace.json"
HYGIENE_CMD="$PLUGIN_ROOT/commands/hygiene.md"

PASS=0
FAIL=0
WARN=0
TOTAL=0

# ---------------------------------------------------------------------------
# Helpers (same pattern as test-static-quality.sh)
# ---------------------------------------------------------------------------

pass() {
    local test_name="$1"
    TOTAL=$((TOTAL + 1))
    PASS=$((PASS + 1))
    echo "  PASS: $test_name"
}

fail() {
    local test_name="$1"
    local detail="${2:-}"
    TOTAL=$((TOTAL + 1))
    FAIL=$((FAIL + 1))
    if [[ -n "$detail" ]]; then
        echo "  FAIL: $test_name ($detail)"
    else
        echo "  FAIL: $test_name"
    fi
}

warn() {
    local test_name="$1"
    local detail="${2:-}"
    WARN=$((WARN + 1))
    if [[ -n "$detail" ]]; then
        echo "  WARN: $test_name ($detail)"
    else
        echo "  WARN: $test_name"
    fi
}

# ---------------------------------------------------------------------------
# Preconditions
# ---------------------------------------------------------------------------

if ! command -v python3 &>/dev/null; then
    echo "ERROR: python3 is required"
    exit 1
fi

# ===================================================================
echo ""
echo "=== Resource Freshness Skill Tests (CIA-543) ==="
echo ""
# ===================================================================

# -------------------------------------------------------------------
echo "--- Test Group 1: Skill Structure ---"
echo ""
# -------------------------------------------------------------------

# T1.1: SKILL.md exists
if [[ -f "$SKILL_FILE" ]]; then
    pass "T1.1: SKILL.md exists"
else
    fail "T1.1: SKILL.md exists" "expected at $SKILL_FILE"
fi

# T1.2: Valid YAML frontmatter with name and description
if [[ -f "$SKILL_FILE" ]]; then
    FM_RESULT=$(python3 -c "
import sys
try:
    with open('$SKILL_FILE') as f:
        content = f.read()
    if not content.startswith('---'):
        print('NO_FRONTMATTER')
        sys.exit(0)
    end = content.index('---', 3)
    yaml_text = content[3:end].strip()
    import importlib
    try:
        yaml = importlib.import_module('yaml')
        data = yaml.safe_load(yaml_text)
        if not isinstance(data, dict):
            print('NOT_DICT')
        elif not data.get('name'):
            print('MISSING_NAME')
        elif data.get('name') != 'resource-freshness':
            print('WRONG_NAME:' + str(data.get('name')))
        elif not data.get('description'):
            print('MISSING_DESCRIPTION')
        else:
            print('OK')
    except ImportError:
        has_name = any(l.strip().startswith('name:') for l in yaml_text.split('\n'))
        has_desc = any(l.strip().startswith('description:') for l in yaml_text.split('\n'))
        if not has_name:
            print('MISSING_NAME')
        elif not has_desc:
            print('MISSING_DESCRIPTION')
        else:
            print('OK')
except ValueError:
    print('NO_CLOSING_DELIMITER')
except Exception as e:
    print(f'ERROR:{e}')
" 2>&1)

    case "$FM_RESULT" in
        OK) pass "T1.2: Valid frontmatter with name='resource-freshness'" ;;
        *) fail "T1.2: Valid frontmatter with name='resource-freshness'" "$FM_RESULT" ;;
    esac
else
    fail "T1.2: Valid frontmatter with name='resource-freshness'" "SKILL.md does not exist"
fi

# T1.3: Skill depth >= 8192 characters
if [[ -f "$SKILL_FILE" ]]; then
    CHAR_COUNT=$(wc -c < "$SKILL_FILE" | tr -d ' ')
    if [[ "$CHAR_COUNT" -ge 8192 ]]; then
        pass "T1.3: Skill depth >= 8192 chars (${CHAR_COUNT} chars)"
    else
        fail "T1.3: Skill depth >= 8192 chars" "only ${CHAR_COUNT} chars"
    fi
else
    fail "T1.3: Skill depth >= 8192 chars" "SKILL.md does not exist"
fi

# -------------------------------------------------------------------
echo ""
echo "--- Test Group 2: Required Content Sections ---"
echo ""
# -------------------------------------------------------------------

if [[ -f "$SKILL_FILE" ]]; then
    CONTENT=$(cat "$SKILL_FILE")

    # T2.1: Has project description staleness check
    if echo "$CONTENT" | grep -qi "project.*description.*stale\|project.*staleness\|stale.*project.*description"; then
        pass "T2.1: Documents project description staleness detection"
    else
        fail "T2.1: Documents project description staleness detection"
    fi

    # T2.2: Has initiative status update checks
    if echo "$CONTENT" | grep -qi "initiative.*status\|initiative.*update\|status.*update.*overdue"; then
        pass "T2.2: Documents initiative status update checks"
    else
        fail "T2.2: Documents initiative status update checks"
    fi

    # T2.3: Has milestone health checks
    if echo "$CONTENT" | grep -qi "milestone.*health\|milestone.*target.*date\|milestone.*stall"; then
        pass "T2.3: Documents milestone health checks"
    else
        fail "T2.3: Documents milestone health checks"
    fi

    # T2.4: Has document freshness checks
    if echo "$CONTENT" | grep -qi "document.*fresh\|document.*stale\|document.*staleness"; then
        pass "T2.4: Documents document freshness checks"
    else
        fail "T2.4: Documents document freshness checks"
    fi

    # T2.5: Has severity rating output (Error/Warning/Info)
    if echo "$CONTENT" | grep -q "Error" && echo "$CONTENT" | grep -q "Warning" && echo "$CONTENT" | grep -q "Info"; then
        pass "T2.5: Uses Error/Warning/Info severity ratings"
    else
        fail "T2.5: Uses Error/Warning/Info severity ratings"
    fi

    # T2.6: Has freshness report output format
    if echo "$CONTENT" | grep -qi "freshness.*report\|resource.*freshness.*report\|## .*report\|report.*format"; then
        pass "T2.6: Defines freshness report output format"
    else
        fail "T2.6: Defines freshness report output format"
    fi

    # T2.7: Has configurable thresholds (not hardcoded-only)
    if echo "$CONTENT" | grep -qi "configur\|threshold\|default.*days\|override"; then
        pass "T2.7: Documents configurable thresholds"
    else
        fail "T2.7: Documents configurable thresholds"
    fi

    # T2.8: Has graceful degradation (what happens when API fails)
    if echo "$CONTENT" | grep -qi "graceful.*degrad\|api.*fail\|unavailable\|What.*If\|error.*handling"; then
        pass "T2.8: Documents graceful degradation"
    else
        fail "T2.8: Documents graceful degradation"
    fi
else
    fail "T2.1: Documents project description staleness detection" "SKILL.md does not exist"
    fail "T2.2: Documents initiative status update checks" "SKILL.md does not exist"
    fail "T2.3: Documents milestone health checks" "SKILL.md does not exist"
    fail "T2.4: Documents document freshness checks" "SKILL.md does not exist"
    fail "T2.5: Uses Error/Warning/Info severity ratings" "SKILL.md does not exist"
    fail "T2.6: Defines freshness report output format" "SKILL.md does not exist"
    fail "T2.7: Documents configurable thresholds" "SKILL.md does not exist"
    fail "T2.8: Documents graceful degradation" "SKILL.md does not exist"
fi

# -------------------------------------------------------------------
echo ""
echo "--- Test Group 3: Hygiene Integration ---"
echo ""
# -------------------------------------------------------------------

# T3.1: Skill is registered in marketplace.json
MANIFEST_HAS_SKILL=$(python3 -c "
import json
d = json.load(open('$MANIFEST'))
skills = d['plugins'][0].get('skills', [])
found = any('resource-freshness' in s for s in skills)
print('YES' if found else 'NO')
" 2>&1)

if [[ "$MANIFEST_HAS_SKILL" == "YES" ]]; then
    pass "T3.1: Skill registered in marketplace.json"
else
    fail "T3.1: Skill registered in marketplace.json" "not found in manifest skills array"
fi

# T3.2: Hygiene command references resource-freshness
if [[ -f "$HYGIENE_CMD" ]]; then
    if grep -qi "resource.freshness\|Resource.*Freshness" "$HYGIENE_CMD"; then
        pass "T3.2: Hygiene command references resource-freshness"
    else
        fail "T3.2: Hygiene command references resource-freshness" "no reference found in hygiene.md"
    fi
else
    fail "T3.2: Hygiene command references resource-freshness" "hygiene.md not found"
fi

# -------------------------------------------------------------------
echo ""
echo "--- Test Group 4: Cross-References ---"
echo ""
# -------------------------------------------------------------------

# T4.1: Has Cross-Skill References section
if [[ -f "$SKILL_FILE" ]]; then
    if grep -q "## Cross-Skill References" "$SKILL_FILE"; then
        pass "T4.1: Has Cross-Skill References section"
    else
        fail "T4.1: Has Cross-Skill References section"
    fi
else
    fail "T4.1: Has Cross-Skill References section" "SKILL.md does not exist"
fi

# T4.2: References document-lifecycle skill (delegated document checks)
if [[ -f "$SKILL_FILE" ]]; then
    if grep -q "document-lifecycle" "$SKILL_FILE"; then
        pass "T4.2: References document-lifecycle skill"
    else
        fail "T4.2: References document-lifecycle skill"
    fi
else
    fail "T4.2: References document-lifecycle skill" "SKILL.md does not exist"
fi

# T4.3: References milestone-management skill
if [[ -f "$SKILL_FILE" ]]; then
    if grep -q "milestone-management" "$SKILL_FILE"; then
        pass "T4.3: References milestone-management skill"
    else
        fail "T4.3: References milestone-management skill"
    fi
else
    fail "T4.3: References milestone-management skill" "SKILL.md does not exist"
fi

# T4.4: References project-status-update skill
if [[ -f "$SKILL_FILE" ]]; then
    if grep -q "project-status-update" "$SKILL_FILE"; then
        pass "T4.4: References project-status-update skill"
    else
        fail "T4.4: References project-status-update skill"
    fi
else
    fail "T4.4: References project-status-update skill" "SKILL.md does not exist"
fi

# T4.5: All cross-referenced skill names exist on disk
if [[ -f "$SKILL_FILE" ]]; then
    XREFS=$(python3 -c "
import re
with open('$SKILL_FILE') as f:
    text = f.read()
# Extract skill references from Cross-Skill References section
section = text.split('## Cross-Skill References')[-1] if '## Cross-Skill References' in text else ''
for m in re.finditer(r'\*\*([a-z][a-z0-9-]{2,})\*\*', section):
    print(m.group(1))
" 2>/dev/null || true)

    ALL_XREFS_VALID=true
    while IFS= read -r ref; do
        [[ -z "$ref" ]] && continue
        if [[ -d "$PLUGIN_ROOT/skills/$ref" ]] && [[ -f "$PLUGIN_ROOT/skills/$ref/SKILL.md" ]]; then
            pass "T4.5: Cross-ref valid: resource-freshness → $ref"
        else
            fail "T4.5: Cross-ref broken: resource-freshness → $ref" "skill directory not found"
            ALL_XREFS_VALID=false
        fi
    done <<< "$XREFS"

    if [[ -z "$XREFS" ]]; then
        fail "T4.5: Cross-references exist" "no cross-references found in Cross-Skill References section"
    fi
else
    fail "T4.5: Cross-references exist" "SKILL.md does not exist"
fi

# -------------------------------------------------------------------
echo ""
echo "--- Test Group 5: Disk-vs-Docs Drift Detection ---"
echo ""
# -------------------------------------------------------------------

# T5.1: Skill documents how to compare manifest counts vs documented counts
if [[ -f "$SKILL_FILE" ]]; then
    if echo "$CONTENT" | grep -qi "manifest\|marketplace.json\|plugin.json\|actual.*count\|documented.*count\|drift.*detect"; then
        pass "T5.1: Documents manifest-vs-docs drift detection"
    else
        fail "T5.1: Documents manifest-vs-docs drift detection"
    fi
else
    fail "T5.1: Documents manifest-vs-docs drift detection" "SKILL.md does not exist"
fi

# T5.2: Skill documents README staleness checks
if [[ -f "$SKILL_FILE" ]]; then
    if echo "$CONTENT" | grep -qi "README"; then
        pass "T5.2: Documents README freshness checks"
    else
        fail "T5.2: Documents README freshness checks"
    fi
else
    fail "T5.2: Documents README freshness checks" "SKILL.md does not exist"
fi

# T5.3: Skill documents CONNECTORS staleness checks
if [[ -f "$SKILL_FILE" ]]; then
    if echo "$CONTENT" | grep -qi "CONNECTORS"; then
        pass "T5.3: Documents CONNECTORS freshness checks"
    else
        fail "T5.3: Documents CONNECTORS freshness checks"
    fi
else
    fail "T5.3: Documents CONNECTORS freshness checks" "SKILL.md does not exist"
fi

# ===================================================================
echo ""
echo "==========================================="
echo "  Results: $PASS passed, $FAIL failed, $WARN warnings ($TOTAL total)"
echo "==========================================="
echo ""

if [[ $FAIL -gt 0 ]]; then
    echo "FAILED: $FAIL check(s) did not pass."
    exit 1
else
    echo "ALL CHECKS PASSED."
    exit 0
fi
