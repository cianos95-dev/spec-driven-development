#!/usr/bin/env bash
# Test: Mechanism Router + Agent Session Intents v2 + Platform Routing — CIA-580
#
# Validates that:
# 1-10:  mechanism-router skill defines dispatch hierarchy, handler contract,
#        agent selection tree, agent x intent matrix, and cross-references
# 11-16: agent-session-intents v2 schema additions (trigger block, issue_state,
#        state-based inference, unified parse flow, new intents, routing table)
# 17-18: platform-routing agent dispatch section and @mention routing row
#
# Run: bash tests/test-mechanism-router.sh
# Requires: python3

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MR_DIR="$PLUGIN_ROOT/skills/mechanism-router"
MR_FILE="$MR_DIR/SKILL.md"
ASI_DIR="$PLUGIN_ROOT/skills/agent-session-intents"
ASI_FILE="$ASI_DIR/SKILL.md"
PR_DIR="$PLUGIN_ROOT/skills/platform-routing"
PR_FILE="$PR_DIR/SKILL.md"
MANIFEST="$PLUGIN_ROOT/.claude-plugin/marketplace.json"

PASS=0
FAIL=0
TOTAL=0

pass() {
    TOTAL=$((TOTAL + 1))
    PASS=$((PASS + 1))
    echo "  PASS: $1"
}

fail() {
    local detail="${2:-}"
    TOTAL=$((TOTAL + 1))
    FAIL=$((FAIL + 1))
    if [[ -n "$detail" ]]; then
        echo "  FAIL: $1 ($detail)"
    else
        echo "  FAIL: $1"
    fi
}

echo ""
echo "=== Mechanism Router + Intents v2 + Platform Routing Tests (CIA-580) ==="
echo ""

# ===========================================================================
# SECTION A: mechanism-router skill (tests 1-10)
# ===========================================================================
echo "--- Section A: mechanism-router skill ---"
echo ""

# ---------------------------------------------------------------------------
# Test 1: Skill directory and file exist
# ---------------------------------------------------------------------------
echo "--- Test 1: Skill directory and file exist ---"

if [[ -d "$MR_DIR" ]]; then
    pass "Skill directory exists: skills/mechanism-router/"
else
    fail "Skill directory missing" "expected at $MR_DIR"
fi

if [[ -f "$MR_FILE" ]]; then
    pass "SKILL.md exists"
else
    fail "SKILL.md missing" "expected at $MR_FILE"
    echo ""
    echo "==========================================="
    echo "  Results: $PASS passed, $FAIL failed ($TOTAL total)"
    echo "==========================================="
    echo ""
    echo "FAILED: mechanism-router SKILL.md does not exist yet. Create it first."
    exit 1
fi

# ---------------------------------------------------------------------------
# Test 2: Skill has valid frontmatter (name: mechanism-router)
# ---------------------------------------------------------------------------
echo ""
echo "--- Test 2: Frontmatter validation ---"

FM_CHECK=$(python3 -c "
import sys
with open('$MR_FILE') as f:
    content = f.read()
if not content.startswith('---'):
    print('NO_FRONTMATTER')
    sys.exit(0)
try:
    end = content.index('---', 3)
except ValueError:
    print('NO_CLOSING')
    sys.exit(0)
yaml_text = content[3:end].strip()
has_name = any(l.strip().startswith('name:') for l in yaml_text.split('\n'))
has_desc = any(l.strip().startswith('description:') for l in yaml_text.split('\n'))
if not has_name:
    print('MISSING_NAME')
elif not has_desc:
    print('MISSING_DESCRIPTION')
else:
    for l in yaml_text.split('\n'):
        if l.strip().startswith('name:'):
            val = l.split(':', 1)[1].strip()
            if val == 'mechanism-router':
                print('OK')
            else:
                print('WRONG_NAME:' + val)
            break
" 2>&1)

case "$FM_CHECK" in
    OK) pass "Frontmatter valid with name: mechanism-router" ;;
    WRONG_NAME*) fail "Wrong skill name in frontmatter" "$FM_CHECK" ;;
    MISSING_NAME) fail "Frontmatter missing 'name' field" ;;
    MISSING_DESCRIPTION) fail "Frontmatter missing 'description' field" ;;
    NO_FRONTMATTER) fail "No YAML frontmatter (file must start with ---)" ;;
    NO_CLOSING) fail "Frontmatter not closed (missing closing ---)" ;;
    *) fail "Frontmatter error" "$FM_CHECK" ;;
esac

# ---------------------------------------------------------------------------
# Test 3: Documents all 3 mechanisms (delegateId, @mention, assignee)
# ---------------------------------------------------------------------------
echo ""
echo "--- Test 3: Three dispatch mechanisms documented ---"

MECH_CHECK=$(python3 -c "
with open('$MR_FILE') as f:
    content = f.read().lower()
mechanisms = {
    'delegateId': 'delegateid' in content,
    'mention': '@mention' in content or 'mention' in content,
    'assignee': 'assignee' in content,
}
missing = [k for k, v in mechanisms.items() if not v]
if missing:
    print('MISSING:' + ','.join(missing))
else:
    print('OK')
" 2>&1)

if [[ "$MECH_CHECK" == "OK" ]]; then
    pass "All 3 mechanisms documented: delegateId, @mention, assignee"
else
    fail "Missing dispatch mechanisms" "$MECH_CHECK"
fi

# ---------------------------------------------------------------------------
# Test 4: Defines canonical dispatch hierarchy (delegateId > @mention > assignee)
# ---------------------------------------------------------------------------
echo ""
echo "--- Test 4: Canonical dispatch hierarchy ---"

HIER_CHECK=$(python3 -c "
with open('$MR_FILE') as f:
    content = f.read()
# Must define the priority ordering
has_hierarchy = ('delegateId' in content and 'mention' in content and 'assignee' in content)
# Check for explicit hierarchy statement (e.g., 'delegateId > @mention > assignee' or 'primary > secondary > fallback')
has_ordering = (
    ('primary' in content.lower() and 'secondary' in content.lower() and 'fallback' in content.lower())
    or ('delegateId (primary) > @mention (secondary) > assignee (fallback)' in content)
    or ('delegateId' in content and '>' in content and 'assignee' in content)
)
if has_hierarchy and has_ordering:
    print('OK')
elif not has_hierarchy:
    print('MISSING:mechanism_names')
else:
    print('MISSING:hierarchy_ordering')
" 2>&1)

if [[ "$HIER_CHECK" == "OK" ]]; then
    pass "Canonical dispatch hierarchy defined (delegateId > @mention > assignee)"
else
    fail "Dispatch hierarchy incomplete" "$HIER_CHECK"
fi

# ---------------------------------------------------------------------------
# Test 5: Includes handler registration contract (Handler interface)
# ---------------------------------------------------------------------------
echo ""
echo "--- Test 5: Handler registration contract ---"

HANDLER_CHECK=$(python3 -c "
with open('$MR_FILE') as f:
    content = f.read()
checks = {
    'interface_def': 'interface Handler' in content or 'Handler interface' in content.lower(),
    'validate': 'validatePreconditions' in content or 'validate' in content.lower(),
    'execute': 'execute(' in content or 'execute' in content.lower(),
    'respond': 'respond(' in content or 'respond' in content.lower(),
    'intents_field': 'intents:' in content or 'intents' in content,
}
missing = [k for k, v in checks.items() if not v]
if missing:
    print('MISSING:' + ','.join(missing))
else:
    print('OK')
" 2>&1)

if [[ "$HANDLER_CHECK" == "OK" ]]; then
    pass "Handler registration contract includes interface, validate, execute, respond"
else
    fail "Handler registration contract incomplete" "$HANDLER_CHECK"
fi

# ---------------------------------------------------------------------------
# Test 6: Includes agent selection tree for implement intent
# ---------------------------------------------------------------------------
echo ""
echo "--- Test 6: Agent selection tree for implement intent ---"

TREE_CHECK=$(python3 -c "
with open('$MR_FILE') as f:
    content = f.read()
content_lower = content.lower()
checks = {
    'implement_section': 'implement' in content_lower and 'agent selection' in content_lower,
    'exec_quick': 'exec:quick' in content,
    'exec_tdd': 'exec:tdd' in content,
    'exec_pair': 'exec:pair' in content,
    'tembo_route': 'tembo' in content_lower,
    'claude_code_route': 'claude code' in content_lower,
}
missing = [k for k, v in checks.items() if not v]
if missing:
    print('MISSING:' + ','.join(missing))
else:
    print('OK')
" 2>&1)

if [[ "$TREE_CHECK" == "OK" ]]; then
    pass "Agent selection tree for implement covers exec modes, Tembo, Claude Code"
else
    fail "Agent selection tree incomplete" "$TREE_CHECK"
fi

# ---------------------------------------------------------------------------
# Test 7: Includes agent x intent matrix
# ---------------------------------------------------------------------------
echo ""
echo "--- Test 7: Agent x Intent matrix ---"

MATRIX_CHECK=$(python3 -c "
with open('$MR_FILE') as f:
    content = f.read()
content_lower = content.lower()
# Must have a matrix section with agent columns and intent rows
checks = {
    'matrix_section': 'agent' in content_lower and 'intent' in content_lower and 'matrix' in content_lower,
    'claude_column': '| Claude |' in content or '| Claude' in content,
    'tembo_column': '| Tembo |' in content or '| Tembo' in content,
    'copilot_column': 'Copilot' in content,
    'codex_column': 'Codex' in content,
    'review_row': any('review' in line.lower() and '|' in line for line in content.split('\n')),
    'implement_row': any('implement' in line.lower() and '|' in line for line in content.split('\n')),
}
missing = [k for k, v in checks.items() if not v]
if missing:
    print('MISSING:' + ','.join(missing))
else:
    print('OK')
" 2>&1)

if [[ "$MATRIX_CHECK" == "OK" ]]; then
    pass "Agent x Intent matrix includes agent columns and intent rows"
else
    fail "Agent x Intent matrix incomplete" "$MATRIX_CHECK"
fi

# ---------------------------------------------------------------------------
# Test 8: Includes unknown intent response template
# ---------------------------------------------------------------------------
echo ""
echo "--- Test 8: Unknown intent response template ---"

UNKNOWN_CHECK=$(python3 -c "
with open('$MR_FILE') as f:
    content = f.read()
content_lower = content.lower()
checks = {
    'unknown_section': 'unknown intent' in content_lower or 'unknown' in content_lower,
    'response_template': 'available commands' in content_lower or 'available intents' in content_lower,
    'syntax_examples': '@claude' in content_lower and 'review' in content_lower and 'implement' in content_lower,
    'help_hint': 'help' in content_lower,
}
missing = [k for k, v in checks.items() if not v]
if missing:
    print('MISSING:' + ','.join(missing))
else:
    print('OK')
" 2>&1)

if [[ "$UNKNOWN_CHECK" == "OK" ]]; then
    pass "Unknown intent response template with available commands and examples"
else
    fail "Unknown intent response template incomplete" "$UNKNOWN_CHECK"
fi

# ---------------------------------------------------------------------------
# Test 9: Cross-references agent-session-intents skill
# ---------------------------------------------------------------------------
echo ""
echo "--- Test 9: Cross-references agent-session-intents skill ---"

ASI_REF=$(python3 -c "
with open('$MR_FILE') as f:
    content = f.read()
# Must reference agent-session-intents skill (as code ref or bold ref)
has_ref = (
    'agent-session-intents' in content
    and ('skill' in content.lower())
)
if has_ref:
    print('OK')
else:
    print('MISSING:agent-session-intents cross-reference')
" 2>&1)

if [[ "$ASI_REF" == "OK" ]]; then
    pass "Cross-references agent-session-intents skill"
else
    fail "Missing agent-session-intents cross-reference" "$ASI_REF"
fi

# ---------------------------------------------------------------------------
# Test 10: Cross-references CIA-575 architecture document
# ---------------------------------------------------------------------------
echo ""
echo "--- Test 10: Cross-references CIA-575 ---"

CIA575_REF=$(python3 -c "
with open('$MR_FILE') as f:
    content = f.read()
has_ref = 'CIA-575' in content
if has_ref:
    print('OK')
else:
    print('MISSING:CIA-575 reference')
" 2>&1)

if [[ "$CIA575_REF" == "OK" ]]; then
    pass "Cross-references CIA-575 architecture document"
else
    fail "Missing CIA-575 cross-reference" "$CIA575_REF"
fi

# ===========================================================================
# SECTION B: agent-session-intents v2 additions (tests 11-16)
# ===========================================================================
echo ""
echo "--- Section B: agent-session-intents v2 additions ---"
echo ""

# Guard: agent-session-intents SKILL.md must exist
if [[ ! -f "$ASI_FILE" ]]; then
    fail "agent-session-intents SKILL.md missing" "expected at $ASI_FILE"
    echo ""
    echo "==========================================="
    echo "  Results: $PASS passed, $FAIL failed ($TOTAL total)"
    echo "==========================================="
    echo ""
    echo "FAILED: agent-session-intents SKILL.md does not exist."
    exit 1
fi

# ---------------------------------------------------------------------------
# Test 11: ParsedIntent v2 schema has trigger block
# ---------------------------------------------------------------------------
echo "--- Test 11: ParsedIntent v2 schema has trigger block ---"

TRIGGER_CHECK=$(python3 -c "
with open('$ASI_FILE') as f:
    content = f.read()
checks = {
    'trigger_field': 'trigger:' in content or 'trigger' in content,
    'mechanism_field': 'mechanism' in content and ('delegateId' in content or 'delegateid' in content.lower()),
    'initiated_by': 'initiated_by' in content,
    'auto_field': any(x in content for x in ['auto:', 'auto:', 'trigger.auto']),
}
missing = [k for k, v in checks.items() if not v]
if missing:
    print('MISSING:' + ','.join(missing))
else:
    print('OK')
" 2>&1)

if [[ "$TRIGGER_CHECK" == "OK" ]]; then
    pass "ParsedIntent v2 schema has trigger block (mechanism, initiated_by, auto)"
else
    fail "ParsedIntent v2 trigger block incomplete" "$TRIGGER_CHECK"
fi

# ---------------------------------------------------------------------------
# Test 12: ParsedIntent v2 schema has issue_state in parameters
# ---------------------------------------------------------------------------
echo ""
echo "--- Test 12: ParsedIntent v2 schema has issue_state ---"

STATE_CHECK=$(python3 -c "
with open('$ASI_FILE') as f:
    content = f.read()
checks = {
    'issue_state': 'issue_state' in content,
    'status_field': 'status' in content,
    'labels_field': 'labels' in content,
    'spec_label': 'spec_label' in content,
    'exec_label': 'exec_label' in content,
    'type_label': 'type_label' in content,
    'has_merged_pr': 'has_merged_pr' in content,
}
missing = [k for k, v in checks.items() if not v]
if missing:
    print('MISSING:' + ','.join(missing))
else:
    print('OK')
" 2>&1)

if [[ "$STATE_CHECK" == "OK" ]]; then
    pass "ParsedIntent v2 has issue_state with status, labels, spec/exec/type labels, has_merged_pr"
else
    fail "ParsedIntent v2 issue_state incomplete" "$STATE_CHECK"
fi

# ---------------------------------------------------------------------------
# Test 13: Defines state-based inference table (at least 6 state->intent mappings)
# ---------------------------------------------------------------------------
echo ""
echo "--- Test 13: State-based inference table ---"

INFERENCE_CHECK=$(python3 -c "
with open('$ASI_FILE') as f:
    content = f.read()
# Count rows in the state inference table
# Look for lines with '|' that contain state patterns and inferred intents
import re
lines = content.split('\n')
# Find lines that look like table rows with state->intent mappings
state_rows = []
in_table = False
for line in lines:
    stripped = line.strip()
    # Skip header and separator rows
    if '---' in stripped and '|' in stripped:
        in_table = True
        continue
    if in_table and stripped.startswith('|') and stripped.endswith('|'):
        # Check if this looks like a data row (not header)
        cells = [c.strip() for c in stripped.split('|')[1:-1]]
        if len(cells) >= 2 and cells[0] and not cells[0].startswith('Issue State'):
            state_rows.append(stripped)
    elif in_table and not stripped.startswith('|'):
        in_table = False

# Also check for the section header
has_section = 'state-based intent inference' in content.lower() or 'state inference table' in content.lower()

if has_section and len(state_rows) >= 6:
    print('OK:' + str(len(state_rows)))
elif not has_section:
    print('MISSING:state_inference_section')
else:
    print('MISSING:only_' + str(len(state_rows)) + '_mappings_need_6')
" 2>&1)

if [[ "$INFERENCE_CHECK" == OK* ]]; then
    count="${INFERENCE_CHECK#OK:}"
    pass "State-based inference table has $count state->intent mappings (>= 6)"
else
    fail "State-based inference table insufficient" "$INFERENCE_CHECK"
fi

# ---------------------------------------------------------------------------
# Test 14: Documents unified parse flow handling both comment-based and state-based
# ---------------------------------------------------------------------------
echo ""
echo "--- Test 14: Unified parse flow ---"

FLOW_CHECK=$(python3 -c "
with open('$ASI_FILE') as f:
    content = f.read()
content_lower = content.lower()
checks = {
    'unified_section': 'unified parse flow' in content_lower or 'parseunifiedintent' in content_lower,
    'comment_path': 'comment' in content_lower and ('body' in content_lower or 'text' in content_lower),
    'state_path': 'state' in content_lower and ('inference' in content_lower or 'infer' in content_lower),
    'delegateid_path': 'delegateid' in content_lower,
    'assignee_path': 'assignee' in content_lower,
}
missing = [k for k, v in checks.items() if not v]
if missing:
    print('MISSING:' + ','.join(missing))
else:
    print('OK')
" 2>&1)

if [[ "$FLOW_CHECK" == "OK" ]]; then
    pass "Unified parse flow documents comment-based, delegateId, and assignee paths"
else
    fail "Unified parse flow incomplete" "$FLOW_CHECK"
fi

# ---------------------------------------------------------------------------
# Test 15: Intent enum includes new types: close, spike, spec-author, status, expand, help
# ---------------------------------------------------------------------------
echo ""
echo "--- Test 15: New intent types in enum ---"

INTENT_CHECK=$(python3 -c "
with open('$ASI_FILE') as f:
    content = f.read()
new_intents = ['close', 'spike', 'spec-author', 'status', 'expand', 'help']
found = []
missing = []
for intent in new_intents:
    # Check for intent in schema definition or section headers
    if '\"' + intent + '\"' in content or \"'\" + intent + \"'\" in content or '## \`' + intent + '\`' in content or '### \`' + intent + '\`' in content:
        found.append(intent)
    else:
        missing.append(intent)
if missing:
    print('MISSING:' + ','.join(missing))
else:
    print('OK')
" 2>&1)

if [[ "$INTENT_CHECK" == "OK" ]]; then
    pass "Intent enum includes close, spike, spec-author, status, expand, help"
else
    fail "New intent types missing from enum" "$INTENT_CHECK"
fi

# ---------------------------------------------------------------------------
# Test 16: Routing table includes new intents
# ---------------------------------------------------------------------------
echo ""
echo "--- Test 16: Routing table includes new intents ---"

ROUTE_CHECK=$(python3 -c "
with open('$ASI_FILE') as f:
    content = f.read()
# Check that the routing table section includes rows for new intents
lines = content.split('\n')
new_intents = ['close', 'spike', 'spec-author', 'status', 'expand', 'help']
found = []
missing = []
for intent in new_intents:
    # Check for table row containing the intent (backtick-wrapped in a pipe-delimited row)
    pattern = '| \`' + intent + '\`'
    if any(pattern in line for line in lines):
        found.append(intent)
    else:
        missing.append(intent)
if missing:
    print('MISSING:' + ','.join(missing))
else:
    print('OK')
" 2>&1)

if [[ "$ROUTE_CHECK" == "OK" ]]; then
    pass "Routing table includes rows for all new intents"
else
    fail "Routing table missing new intent rows" "$ROUTE_CHECK"
fi

# ===========================================================================
# SECTION C: platform-routing updates (tests 17-18)
# ===========================================================================
echo ""
echo "--- Section C: platform-routing updates ---"
echo ""

# Guard: platform-routing SKILL.md must exist
if [[ ! -f "$PR_FILE" ]]; then
    fail "platform-routing SKILL.md missing" "expected at $PR_FILE"
    echo ""
    echo "==========================================="
    echo "  Results: $PASS passed, $FAIL failed ($TOTAL total)"
    echo "==========================================="
    echo ""
    echo "FAILED: platform-routing SKILL.md does not exist."
    exit 1
fi

# ---------------------------------------------------------------------------
# Test 17: Agent dispatch section exists
# ---------------------------------------------------------------------------
echo "--- Test 17: Agent dispatch section in platform-routing ---"

DISPATCH_CHECK=$(python3 -c "
with open('$PR_FILE') as f:
    content = f.read()
content_lower = content.lower()
checks = {
    'dispatch_section': 'agent dispatch' in content_lower,
    'mention_mechanism': '@mention' in content or 'mention' in content_lower,
    'delegateid_mechanism': 'delegateid' in content_lower,
    'mechanism_router_ref': 'mechanism-router' in content,
}
missing = [k for k, v in checks.items() if not v]
if missing:
    print('MISSING:' + ','.join(missing))
else:
    print('OK')
" 2>&1)

if [[ "$DISPATCH_CHECK" == "OK" ]]; then
    pass "Agent dispatch section exists with @mention, delegateId, mechanism-router reference"
else
    fail "Agent dispatch section incomplete" "$DISPATCH_CHECK"
fi

# ---------------------------------------------------------------------------
# Test 18: @mention dispatch row in routing table
# ---------------------------------------------------------------------------
echo ""
echo "--- Test 18: @mention dispatch row in routing table ---"

MENTION_ROW=$(python3 -c "
with open('$PR_FILE') as f:
    content = f.read()
lines = content.split('\n')
# Look for a routing table row that references @mention or delegateId dispatch
found = False
for line in lines:
    stripped = line.strip()
    if stripped.startswith('|') and stripped.endswith('|'):
        lower = stripped.lower()
        if ('mention' in lower or 'delegateid' in lower or 'agent dispatch' in lower) and 'linear' in lower:
            found = True
            break
        if '@mention' in stripped.lower() and '|' in stripped:
            found = True
            break
if found:
    print('OK')
else:
    print('MISSING:@mention_routing_table_row')
" 2>&1)

if [[ "$MENTION_ROW" == "OK" ]]; then
    pass "@mention dispatch row present in platform routing table"
else
    fail "@mention dispatch row missing from routing table" "$MENTION_ROW"
fi

# ---------------------------------------------------------------------------
# Results
# ---------------------------------------------------------------------------
echo ""
echo "==========================================="
echo "  Results: $PASS passed, $FAIL failed ($TOTAL total)"
echo "==========================================="
echo ""

if [[ $FAIL -gt 0 ]]; then
    echo "FAILED: $FAIL check(s) did not pass."
    exit 1
else
    echo "ALL CHECKS PASSED."
    exit 0
fi
