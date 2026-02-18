#!/usr/bin/env bash
# Test: Agent Session Intents Skill — CIA-550
#
# Validates that the agent-session-intents skill defines:
# 1. Intent parsing rules for @mention comments
# 2. Structured intent schema
# 3. Routing table mapping intents to handlers
# 4. Integration points for Tembo and Claude Code
# 5. Error handling for malformed @mentions
#
# Run: bash tests/test-agent-session-intents.sh
# Requires: python3

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_DIR="$PLUGIN_ROOT/skills/agent-session-intents"
SKILL_FILE="$SKILL_DIR/SKILL.md"
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
echo "=== Agent Session Intents Skill Tests (CIA-550) ==="
echo ""

# ---------------------------------------------------------------------------
# Test 1: Skill file exists
# ---------------------------------------------------------------------------
echo "--- Test 1: Skill file exists ---"

if [[ -d "$SKILL_DIR" ]]; then
    pass "Skill directory exists: skills/agent-session-intents/"
else
    fail "Skill directory missing" "expected at $SKILL_DIR"
fi

if [[ -f "$SKILL_FILE" ]]; then
    pass "SKILL.md exists"
else
    fail "SKILL.md missing" "expected at $SKILL_FILE"
    echo ""
    echo "==========================================="
    echo "  Results: $PASS passed, $FAIL failed ($TOTAL total)"
    echo "==========================================="
    echo ""
    echo "FAILED: Skill file does not exist yet. Create it first."
    exit 1
fi

# ---------------------------------------------------------------------------
# Test 2: Frontmatter contains required fields
# ---------------------------------------------------------------------------
echo ""
echo "--- Test 2: Frontmatter validation ---"

FM_CHECK=$(python3 -c "
import sys
with open('$SKILL_FILE') as f:
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
    # Check name value is correct
    for l in yaml_text.split('\n'):
        if l.strip().startswith('name:'):
            val = l.split(':', 1)[1].strip()
            if val == 'agent-session-intents':
                print('OK')
            else:
                print('WRONG_NAME:' + val)
            break
" 2>&1)

case "$FM_CHECK" in
    OK) pass "Frontmatter valid with name: agent-session-intents" ;;
    WRONG_NAME*) fail "Wrong skill name in frontmatter" "$FM_CHECK" ;;
    MISSING_NAME) fail "Frontmatter missing 'name' field" ;;
    MISSING_DESCRIPTION) fail "Frontmatter missing 'description' field" ;;
    NO_FRONTMATTER) fail "No YAML frontmatter (file must start with ---)" ;;
    NO_CLOSING) fail "Frontmatter not closed (missing closing ---)" ;;
    *) fail "Frontmatter error" "$FM_CHECK" ;;
esac

# ---------------------------------------------------------------------------
# Test 3: Manifest registration
# ---------------------------------------------------------------------------
echo ""
echo "--- Test 3: Manifest registration ---"

MANIFEST_HAS_SKILL=$(python3 -c "
import json
d = json.load(open('$MANIFEST'))
skills = d['plugins'][0].get('skills', [])
found = any('agent-session-intents' in s for s in skills)
print('YES' if found else 'NO')
" 2>&1)

if [[ "$MANIFEST_HAS_SKILL" == "YES" ]]; then
    pass "Skill registered in marketplace.json"
else
    fail "Skill not registered in marketplace.json" "add ./skills/agent-session-intents to skills array"
fi

# ---------------------------------------------------------------------------
# Test 4: Depth threshold (8192 chars minimum)
# ---------------------------------------------------------------------------
echo ""
echo "--- Test 4: Depth threshold ---"

CHAR_COUNT=$(wc -c < "$SKILL_FILE" | tr -d ' ')
if [[ "$CHAR_COUNT" -ge 8192 ]]; then
    pass "Skill depth OK (${CHAR_COUNT} chars >= 8192)"
else
    fail "Skill below depth threshold" "${CHAR_COUNT} chars < 8192 minimum"
fi

# ---------------------------------------------------------------------------
# Test 5: Intent types defined
# ---------------------------------------------------------------------------
echo ""
echo "--- Test 5: Intent types defined ---"

# The skill must define these four intents
for intent in "review" "implement" "gate2" "dispatch"; do
    if grep -qi "\b${intent}\b" "$SKILL_FILE"; then
        pass "Intent type defined: $intent"
    else
        fail "Intent type missing: $intent" "skill must define the '$intent' intent"
    fi
done

# ---------------------------------------------------------------------------
# Test 6: Intent schema defined
# ---------------------------------------------------------------------------
echo ""
echo "--- Test 6: Intent schema structure ---"

# Must define a structured intent format with these fields
SCHEMA_CHECK=$(python3 -c "
with open('$SKILL_FILE') as f:
    content = f.read().lower()
fields = ['intent', 'target_issue', 'source_comment', 'parameters']
alt_fields = ['intent_type', 'target issue', 'source comment', 'params']
found = []
missing = []
for f, alt in zip(fields, alt_fields):
    # Check for field name in schema context (code block, table, or definition)
    if f in content or alt in content or f.replace('_', ' ') in content:
        found.append(f)
    else:
        missing.append(f)
if missing:
    print('MISSING:' + ','.join(missing))
else:
    print('OK')
" 2>&1)

if [[ "$SCHEMA_CHECK" == "OK" ]]; then
    pass "Intent schema defines all required fields"
else
    fail "Intent schema incomplete" "$SCHEMA_CHECK"
fi

# ---------------------------------------------------------------------------
# Test 7: Routing table maps intents to handlers
# ---------------------------------------------------------------------------
echo ""
echo "--- Test 7: Routing rules ---"

# Must map review → code-reviewer, implement → implementer
ROUTING_CHECK=$(python3 -c "
with open('$SKILL_FILE') as f:
    content = f.read().lower()
checks = {
    'review_to_reviewer': 'review' in content and ('code-reviewer' in content or 'reviewer agent' in content or 'reviewer' in content),
    'implement_to_implementer': 'implement' in content and 'implementer' in content,
    'gate2_to_handler': 'gate2' in content or 'gate 2' in content,
}
missing = [k for k, v in checks.items() if not v]
if missing:
    print('MISSING:' + ','.join(missing))
else:
    print('OK')
" 2>&1)

if [[ "$ROUTING_CHECK" == "OK" ]]; then
    pass "Routing table maps all intents to handlers"
else
    fail "Routing rules incomplete" "$ROUTING_CHECK"
fi

# ---------------------------------------------------------------------------
# Test 8: Integration points documented
# ---------------------------------------------------------------------------
echo ""
echo "--- Test 8: Integration points ---"

HAS_TEMBO=$(grep -ci "tembo" "$SKILL_FILE" || echo 0)
HAS_CLAUDE_CODE=$(grep -ci "claude code" "$SKILL_FILE" || echo 0)
HAS_WEBHOOK=$(grep -ci "webhook" "$SKILL_FILE" || echo 0)
HAS_LINEAR=$(grep -ci "linear" "$SKILL_FILE" || echo 0)

if [[ "$HAS_TEMBO" -gt 0 ]]; then
    pass "Tembo integration documented"
else
    fail "Tembo integration not documented"
fi

if [[ "$HAS_CLAUDE_CODE" -gt 0 ]]; then
    pass "Claude Code integration documented"
else
    fail "Claude Code integration not documented"
fi

if [[ "$HAS_WEBHOOK" -gt 0 ]]; then
    pass "Webhook integration documented"
else
    fail "Webhook integration not documented"
fi

if [[ "$HAS_LINEAR" -gt 0 ]]; then
    pass "Linear integration documented"
else
    fail "Linear integration not documented"
fi

# ---------------------------------------------------------------------------
# Test 9: Error handling section
# ---------------------------------------------------------------------------
echo ""
echo "--- Test 9: Error handling ---"

ERROR_CHECK=$(python3 -c "
with open('$SKILL_FILE') as f:
    content = f.read().lower()
checks = {
    'malformed_mentions': any(x in content for x in ['malformed', 'invalid @mention', 'unrecognized', 'unknown intent', 'parse error', 'parsing error']),
    'permission_checks': any(x in content for x in ['permission', 'authorization', 'unauthorized', 'access control']),
    'error_handling_section': any(x in content for x in ['error handling', 'error cases', 'failure modes', 'edge cases']),
}
missing = [k for k, v in checks.items() if not v]
if missing:
    print('MISSING:' + ','.join(missing))
else:
    print('OK')
" 2>&1)

if [[ "$ERROR_CHECK" == "OK" ]]; then
    pass "Error handling covers malformed mentions, permissions, and has dedicated section"
else
    fail "Error handling incomplete" "$ERROR_CHECK"
fi

# ---------------------------------------------------------------------------
# Test 10: Cross-skill references are valid
# ---------------------------------------------------------------------------
echo ""
echo "--- Test 10: Cross-skill references ---"

# Must reference at least tembo-dispatch and issue-lifecycle
CROSS_REFS=$(python3 -c "
import re
with open('$SKILL_FILE') as f:
    text = f.read()
refs = set()
for m in re.finditer(r'\x60([a-z][a-z-]{2,})\x60\s+skill', text):
    refs.add(m.group(1))
for m in re.finditer(r'\*\*([a-z][a-z-]{2,})\*\*\s+skill', text):
    refs.add(m.group(1))
required = {'issue-lifecycle', 'adversarial-review'}
missing = required - refs
if missing:
    print('MISSING:' + ','.join(sorted(missing)))
else:
    print('OK:' + ','.join(sorted(refs)))
" 2>&1)

if [[ "$CROSS_REFS" == OK* ]]; then
    pass "Cross-skill references include issue-lifecycle and adversarial-review"
else
    fail "Missing required cross-references" "$CROSS_REFS"
fi

# ---------------------------------------------------------------------------
# Test 11: AgentSessionEvent payload documented
# ---------------------------------------------------------------------------
echo ""
echo "--- Test 11: AgentSessionEvent payload ---"

HAS_PAYLOAD=$(python3 -c "
with open('$SKILL_FILE') as f:
    content = f.read()
checks = {
    'event_type': 'AgentSessionEvent' in content or 'agent_session' in content.lower() or 'agentsession' in content.lower(),
    'comment_body': any(x in content.lower() for x in ['comment body', 'comment.body', 'comment text', 'body', 'comment_body']),
    'delegate_id': any(x in content.lower() for x in ['delegateid', 'delegate_id', 'delegate id', 'agent id']),
}
missing = [k for k, v in checks.items() if not v]
if missing:
    print('MISSING:' + ','.join(missing))
else:
    print('OK')
" 2>&1)

if [[ "$HAS_PAYLOAD" == "OK" ]]; then
    pass "AgentSessionEvent payload structure documented"
else
    fail "AgentSessionEvent payload incomplete" "$HAS_PAYLOAD"
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
