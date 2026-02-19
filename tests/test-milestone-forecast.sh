#!/usr/bin/env bash
# Milestone Forecast Skill Tests — CIA-566
#
# Validates the milestone-forecast skill structure, frontmatter,
# algorithm documentation, and output format compliance.
#
# Run: bash tests/test-milestone-forecast.sh
# Requires: python3
#
# Exit codes: 0 = all checks pass, 1 = one or more checks failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_DIR="$PLUGIN_ROOT/skills/milestone-forecast"
SKILL_MD="$SKILL_DIR/SKILL.md"

PASS=0
FAIL=0
TOTAL=0

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

echo ""
echo "=== Milestone Forecast Skill Tests ==="
echo ""

# ---------------------------------------------------------------------------
# Test 1: Skill directory and SKILL.md exist
# ---------------------------------------------------------------------------

echo "--- Test 1: Skill structure ---"

if [[ -d "$SKILL_DIR" ]]; then
    pass "Skill directory exists"
else
    fail "Skill directory exists" "expected at $SKILL_DIR"
fi

if [[ -f "$SKILL_MD" ]]; then
    pass "SKILL.md exists"
else
    fail "SKILL.md exists" "expected at $SKILL_MD"
fi

# ---------------------------------------------------------------------------
# Test 2: Valid YAML frontmatter with required fields
# ---------------------------------------------------------------------------

echo "--- Test 2: Frontmatter validation ---"

if [[ -f "$SKILL_MD" ]]; then
    FM_RESULT=$(python3 -c "
import sys
with open('$SKILL_MD') as f:
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
has_name = any(line.strip().startswith('name:') for line in yaml_text.split('\n'))
has_desc = any(line.strip().startswith('description:') for line in yaml_text.split('\n'))
if not has_name:
    print('MISSING_NAME')
elif not has_desc:
    print('MISSING_DESCRIPTION')
else:
    print('OK')
" 2>&1)

    case "$FM_RESULT" in
        OK) pass "Frontmatter has name and description" ;;
        NO_FRONTMATTER) fail "Frontmatter has name and description" "missing opening ---" ;;
        NO_CLOSING) fail "Frontmatter has name and description" "missing closing ---" ;;
        MISSING_NAME) fail "Frontmatter has name and description" "missing 'name' field" ;;
        MISSING_DESCRIPTION) fail "Frontmatter has name and description" "missing 'description' field" ;;
        *) fail "Frontmatter has name and description" "$FM_RESULT" ;;
    esac

    # Check name value is 'milestone-forecast'
    NAME_VAL=$(python3 -c "
with open('$SKILL_MD') as f:
    content = f.read()
end = content.index('---', 3)
yaml_text = content[3:end]
for line in yaml_text.split('\n'):
    if line.strip().startswith('name:'):
        print(line.split(':', 1)[1].strip())
        break
" 2>&1)

    if [[ "$NAME_VAL" == "milestone-forecast" ]]; then
        pass "Frontmatter name is 'milestone-forecast'"
    else
        fail "Frontmatter name is 'milestone-forecast'" "got '$NAME_VAL'"
    fi
else
    fail "Frontmatter has name and description" "SKILL.md not found"
    fail "Frontmatter name is 'milestone-forecast'" "SKILL.md not found"
fi

# ---------------------------------------------------------------------------
# Test 3: Weighted velocity calculation documented
# ---------------------------------------------------------------------------

echo "--- Test 3: Velocity calculation documentation ---"

if [[ -f "$SKILL_MD" ]]; then
    # Check that the weights [0.35, 0.25, 0.20, 0.12, 0.08] are documented
    WEIGHTS_FOUND=$(python3 -c "
import re
with open('$SKILL_MD') as f:
    content = f.read()
# Also check references
ref_content = ''
import os
ref_dir = os.path.join('$SKILL_DIR', 'references')
if os.path.isdir(ref_dir):
    for fname in os.listdir(ref_dir):
        fpath = os.path.join(ref_dir, fname)
        if os.path.isfile(fpath):
            with open(fpath) as rf:
                ref_content += rf.read()
combined = content + ref_content
# Check for all 5 weights
weights = ['0.35', '0.25', '0.20', '0.12', '0.08']
found = all(w in combined for w in weights)
print('OK' if found else 'MISSING')
" 2>&1)

    if [[ "$WEIGHTS_FOUND" == "OK" ]]; then
        pass "Weighted velocity weights documented (0.35, 0.25, 0.20, 0.12, 0.08)"
    else
        fail "Weighted velocity weights documented" "expected all 5 weights: 0.35, 0.25, 0.20, 0.12, 0.08"
    fi

    # Check that 3-5 cycles are mentioned
    CYCLES_FOUND=$(grep -c "3.*5.*cycle\|3-5 cycle\|last 3.*5\|3 to 5" "$SKILL_MD" 2>/dev/null || echo 0)
    if [[ "$CYCLES_FOUND" -gt 0 ]]; then
        pass "3-5 cycle window documented"
    else
        fail "3-5 cycle window documented" "no mention of 3-5 cycle window in SKILL.md"
    fi
else
    fail "Weighted velocity weights documented" "SKILL.md not found"
    fail "3-5 cycle window documented" "SKILL.md not found"
fi

# ---------------------------------------------------------------------------
# Test 4: Three-date projection output (optimistic, expected, pessimistic)
# ---------------------------------------------------------------------------

echo "--- Test 4: Three-date projection output ---"

if [[ -f "$SKILL_MD" ]]; then
    # Check for all three projection types
    HAS_OPTIMISTIC=$(grep -ci "optimistic" "$SKILL_MD" 2>/dev/null || echo 0)
    HAS_EXPECTED=$(grep -ci "expected" "$SKILL_MD" 2>/dev/null || echo 0)
    HAS_PESSIMISTIC=$(grep -ci "pessimistic" "$SKILL_MD" 2>/dev/null || echo 0)

    if [[ "$HAS_OPTIMISTIC" -gt 0 ]]; then
        pass "Optimistic date projection documented"
    else
        fail "Optimistic date projection documented" "no mention of 'optimistic'"
    fi

    if [[ "$HAS_EXPECTED" -gt 0 ]]; then
        pass "Expected date projection documented"
    else
        fail "Expected date projection documented" "no mention of 'expected'"
    fi

    if [[ "$HAS_PESSIMISTIC" -gt 0 ]]; then
        pass "Pessimistic date projection documented"
    else
        fail "Pessimistic date projection documented" "no mention of 'pessimistic'"
    fi
else
    fail "Optimistic date projection documented" "SKILL.md not found"
    fail "Expected date projection documented" "SKILL.md not found"
    fail "Pessimistic date projection documented" "SKILL.md not found"
fi

# ---------------------------------------------------------------------------
# Test 5: 40% buffer documented
# ---------------------------------------------------------------------------

echo "--- Test 5: Buffer range ---"

if [[ -f "$SKILL_MD" ]]; then
    BUFFER_FOUND=$(grep -c "40%" "$SKILL_MD" 2>/dev/null || echo 0)
    COMBINED_BUFFER=0
    if [[ "$BUFFER_FOUND" -gt 0 ]]; then
        COMBINED_BUFFER=$BUFFER_FOUND
    else
        # Check references too
        if [[ -d "$SKILL_DIR/references" ]]; then
            for ref in "$SKILL_DIR"/references/*.md; do
                [[ -f "$ref" ]] || continue
                REF_BUFFER=$(grep -c "40%" "$ref" 2>/dev/null || echo 0)
                COMBINED_BUFFER=$((COMBINED_BUFFER + REF_BUFFER))
            done
        fi
    fi

    if [[ "$COMBINED_BUFFER" -gt 0 ]]; then
        pass "40% buffer range documented"
    else
        fail "40% buffer range documented" "no mention of 40% buffer"
    fi
else
    fail "40% buffer range documented" "SKILL.md not found"
fi

# ---------------------------------------------------------------------------
# Test 6: Confidence level output
# ---------------------------------------------------------------------------

echo "--- Test 6: Confidence level ---"

if [[ -f "$SKILL_MD" ]]; then
    CONFIDENCE_FOUND=$(grep -ci "confidence" "$SKILL_MD" 2>/dev/null || echo 0)
    if [[ "$CONFIDENCE_FOUND" -gt 0 ]]; then
        pass "Confidence level documented"
    else
        fail "Confidence level documented" "no mention of 'confidence'"
    fi
else
    fail "Confidence level documented" "SKILL.md not found"
fi

# ---------------------------------------------------------------------------
# Test 7: Markdown table output format
# ---------------------------------------------------------------------------

echo "--- Test 7: Markdown table output ---"

if [[ -f "$SKILL_MD" ]]; then
    # Check for pipe-delimited table rows (markdown table syntax)
    TABLE_FOUND=$(grep -c '^|' "$SKILL_MD" 2>/dev/null || echo 0)
    if [[ "$TABLE_FOUND" -ge 3 ]]; then
        pass "Markdown table format present (for Linear comments)"
    else
        fail "Markdown table format present" "expected at least 3 pipe-delimited lines, found $TABLE_FOUND"
    fi
else
    fail "Markdown table format present" "SKILL.md not found"
fi

# ---------------------------------------------------------------------------
# Test 8: Linear API reference (completedScopeHistory)
# ---------------------------------------------------------------------------

echo "--- Test 8: Linear API reference ---"

if [[ -f "$SKILL_MD" ]]; then
    SCOPE_HIST=$(grep -ci "completedScopeHistory\|completed.*scope.*history\|completedScopeHistory" "$SKILL_MD" 2>/dev/null || echo 0)
    # Also check references
    COMBINED_SCOPE=0
    if [[ "$SCOPE_HIST" -gt 0 ]]; then
        COMBINED_SCOPE=$SCOPE_HIST
    else
        if [[ -d "$SKILL_DIR/references" ]]; then
            for ref in "$SKILL_DIR"/references/*.md; do
                [[ -f "$ref" ]] || continue
                REF_SCOPE=$(grep -ci "completedScopeHistory\|completed.*scope.*history" "$ref" 2>/dev/null || echo 0)
                COMBINED_SCOPE=$((COMBINED_SCOPE + REF_SCOPE))
            done
        fi
    fi

    if [[ "$COMBINED_SCOPE" -gt 0 ]]; then
        pass "Linear completedScopeHistory referenced"
    else
        fail "Linear completedScopeHistory referenced" "no mention of completedScopeHistory"
    fi
else
    fail "Linear completedScopeHistory referenced" "SKILL.md not found"
fi

# ---------------------------------------------------------------------------
# Test 9: Skill registered in marketplace.json
# ---------------------------------------------------------------------------

echo "--- Test 9: Manifest registration ---"

MANIFEST="$PLUGIN_ROOT/.claude-plugin/marketplace.json"
if [[ -f "$MANIFEST" ]]; then
    REGISTERED=$(python3 -c "
import json
d = json.load(open('$MANIFEST'))
skills = d['plugins'][0].get('skills', [])
found = any('milestone-forecast' in s for s in skills)
print('OK' if found else 'MISSING')
" 2>&1)

    if [[ "$REGISTERED" == "OK" ]]; then
        pass "Skill registered in marketplace.json"
    else
        fail "Skill registered in marketplace.json" "not found in skills array"
    fi
else
    fail "Skill registered in marketplace.json" "manifest not found"
fi

# ---------------------------------------------------------------------------
# Test 10: Skill depth threshold (>= 8192 chars across SKILL.md + references)
# ---------------------------------------------------------------------------

echo "--- Test 10: Skill depth ---"

if [[ -f "$SKILL_MD" ]]; then
    TOTAL_CHARS=$(wc -c < "$SKILL_MD" | tr -d ' ')
    if [[ -d "$SKILL_DIR/references" ]]; then
        for ref in "$SKILL_DIR"/references/*.md; do
            [[ -f "$ref" ]] || continue
            REF_CHARS=$(wc -c < "$ref" | tr -d ' ')
            TOTAL_CHARS=$((TOTAL_CHARS + REF_CHARS))
        done
    fi

    if [[ "$TOTAL_CHARS" -ge 8192 ]]; then
        pass "Combined depth >= 8192 chars ($TOTAL_CHARS chars)"
    else
        fail "Combined depth >= 8192 chars" "only $TOTAL_CHARS chars total"
    fi
else
    fail "Combined depth >= 8192 chars" "SKILL.md not found"
fi

# ---------------------------------------------------------------------------
# Test 11: Cross-skill references valid
# ---------------------------------------------------------------------------

echo "--- Test 11: Cross-skill references ---"

if [[ -f "$SKILL_MD" ]]; then
    # Extract referenced skill names
    REFS=$(python3 -c "
import re
with open('$SKILL_MD') as f:
    text = f.read()
refs = set()
for m in re.finditer(r'\x60([a-z][a-z-]{2,})\x60\s+skill', text):
    refs.add(m.group(1))
for m in re.finditer(r'\*\*([a-z][a-z-]{2,})\*\*\s+skill', text):
    refs.add(m.group(1))
for r in sorted(refs):
    # Skip self-reference
    if r != 'milestone-forecast':
        print(r)
" 2>&1)

    ALL_REFS_OK=true
    while IFS= read -r ref_name; do
        [[ -z "$ref_name" ]] && continue
        if [[ -d "$PLUGIN_ROOT/skills/$ref_name" ]]; then
            pass "Cross-ref valid: milestone-forecast -> $ref_name"
        else
            fail "Cross-ref valid: milestone-forecast -> $ref_name" "skill directory not found"
            ALL_REFS_OK=false
        fi
    done <<< "$REFS"

    if $ALL_REFS_OK && [[ -n "$REFS" ]]; then
        : # already reported individual passes
    elif [[ -z "$REFS" ]]; then
        pass "No cross-skill references to validate"
    fi
else
    fail "Cross-skill references" "SKILL.md not found"
fi

# ---------------------------------------------------------------------------
# Test 12: Velocity math example (numerical correctness)
# ---------------------------------------------------------------------------

echo "--- Test 12: Velocity math example ---"

# Check that the skill or references contain a worked example
# The weighted velocity formula: sum(weight_i * velocity_i) for i in range(n)
# With weights [0.35, 0.25, 0.20, 0.12, 0.08] and sample velocities
if [[ -f "$SKILL_MD" ]]; then
    EXAMPLE_FOUND=$(python3 -c "
import os, re
combined = ''
with open('$SKILL_MD') as f:
    combined += f.read()
ref_dir = os.path.join('$SKILL_DIR', 'references')
if os.path.isdir(ref_dir):
    for fname in os.listdir(ref_dir):
        fpath = os.path.join(ref_dir, fname)
        if os.path.isfile(fpath):
            with open(fpath) as rf:
                combined += rf.read()
# Look for a worked example with actual numbers
has_formula = 'velocity' in combined.lower() and any(c.isdigit() for c in combined)
has_example = bool(re.search(r'(example|worked|sample).*velocity', combined, re.IGNORECASE) or
                   re.search(r'\d+\.?\d*\s*[×x*]\s*0\.\d+', combined))
print('OK' if (has_formula and has_example) else 'MISSING')
" 2>&1)

    if [[ "$EXAMPLE_FOUND" == "OK" ]]; then
        pass "Worked velocity calculation example present"
    else
        fail "Worked velocity calculation example present" "no numerical example found"
    fi
else
    fail "Worked velocity calculation example present" "SKILL.md not found"
fi

# ---------------------------------------------------------------------------
# Summary
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
