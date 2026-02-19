#!/usr/bin/env bash
# Pattern Aggregation Tests — CIA-436
#
# Comprehensive test suite for aggregate-patterns.sh.
# Creates temporary fixtures, runs the script, validates output with jq assertions.
#
# Run: bash tests/test-pattern-aggregation.sh
# Requires: jq, bash 3.2+
#
# Exit codes: 0 = all tests pass, 1 = one or more tests failed

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AGGREGATE_SCRIPT="$PLUGIN_ROOT/skills/pattern-aggregation/aggregate-patterns.sh"

PASS=0
FAIL=0
TOTAL=0

# ---------------------------------------------------------------------------
# Helpers
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

# Create a temporary directory for test fixtures
setup_test_dir() {
    local test_dir
    test_dir=$(mktemp -d "${TMPDIR:-/tmp}/pattern-agg-test.XXXXXX")
    mkdir -p "$test_dir/archives"
    echo "$test_dir"
}

# Clean up test directory
cleanup_test_dir() {
    local test_dir="$1"
    if [[ -d "$test_dir" ]]; then
        rm -rf "$test_dir"
    fi
}

# Run the aggregation script with a custom insights dir
run_aggregate() {
    local insights_dir="$1"
    shift
    INSIGHTS_DIR="$insights_dir" bash "$AGGREGATE_SCRIPT" "$@" 2>/dev/null
}

# Run the aggregation script capturing stderr
run_aggregate_stderr() {
    local insights_dir="$1"
    shift
    INSIGHTS_DIR="$insights_dir" bash "$AGGREGATE_SCRIPT" "$@" 2>&1 1>/dev/null
}

# ---------------------------------------------------------------------------
# Preconditions
# ---------------------------------------------------------------------------

if [[ ! -f "$AGGREGATE_SCRIPT" ]]; then
    echo "ERROR: aggregate-patterns.sh not found at $AGGREGATE_SCRIPT"
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo "ERROR: jq is required for test assertions"
    exit 1
fi

# ===================================================================
echo ""
echo "=== Test Group 1: Single Report Parsing ==="
echo ""
# ===================================================================

TEST_DIR=$(setup_test_dir)

cat > "$TEST_DIR/archives/2026-02-10.md" << 'REPORT'
---
source: Claude Code Insights (Anthropic)
period: 2026-02-06 to 2026-02-10
---

# Claude Code Insights

## Friction Points

| Type | Count | Pattern |
|------|-------|---------|
| Wrong approach | 28 | Commits to incorrect strategy |
| Buggy code | 10 | Code errors requiring fixes |
| Misunderstood request | 8 | Expands scope beyond asked |
| Excessive changes | 5 | Deep research when quick update needed |
| Tool limitation | 5 | MCP/API constraints |
REPORT

run_aggregate "$TEST_DIR"
OUTPUT="$TEST_DIR/patterns.json"

if [[ -f "$OUTPUT" ]]; then
    pass "Single report: patterns.json created"
else
    fail "Single report: patterns.json not created"
    cleanup_test_dir "$TEST_DIR"
    # Continue with remaining tests
fi

# Check schema_version
if [[ -f "$OUTPUT" ]]; then
    sv=$(jq -r '.schema_version' "$OUTPUT")
    if [[ "$sv" == "1" ]]; then
        pass "Single report: schema_version is 1"
    else
        fail "Single report: schema_version" "expected 1, got $sv"
    fi
fi

# Check report_count
if [[ -f "$OUTPUT" ]]; then
    rc=$(jq -r '.report_count' "$OUTPUT")
    if [[ "$rc" == "1" ]]; then
        pass "Single report: report_count is 1"
    else
        fail "Single report: report_count" "expected 1, got $rc"
    fi
fi

# Check generated_at is ISO 8601
if [[ -f "$OUTPUT" ]]; then
    ga=$(jq -r '.generated_at' "$OUTPUT")
    if echo "$ga" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}'; then
        pass "Single report: generated_at is ISO 8601"
    else
        fail "Single report: generated_at format" "got $ga"
    fi
fi

# Check pattern count
if [[ -f "$OUTPUT" ]]; then
    pc=$(jq '.patterns | length' "$OUTPUT")
    if [[ "$pc" == "5" ]]; then
        pass "Single report: 5 patterns extracted"
    else
        fail "Single report: pattern count" "expected 5, got $pc"
    fi
fi

# Check wrong_approach normalization
if [[ -f "$OUTPUT" ]]; then
    wa_type=$(jq -r '.patterns[] | select(.type == "wrong_approach") | .type' "$OUTPUT")
    if [[ "$wa_type" == "wrong_approach" ]]; then
        pass "Single report: wrong_approach normalized correctly"
    else
        fail "Single report: wrong_approach normalization" "type not found"
    fi
fi

# Check display_name is Title Case
if [[ -f "$OUTPUT" ]]; then
    wa_dn=$(jq -r '.patterns[] | select(.type == "wrong_approach") | .display_name' "$OUTPUT")
    if [[ "$wa_dn" == "Wrong Approach" ]]; then
        pass "Single report: display_name is Title Case"
    else
        fail "Single report: display_name" "expected 'Wrong Approach', got '$wa_dn'"
    fi
fi

# Check count
if [[ -f "$OUTPUT" ]]; then
    wa_count=$(jq -r '.patterns[] | select(.type == "wrong_approach") | .count' "$OUTPUT")
    if [[ "$wa_count" == "28" ]]; then
        pass "Single report: wrong_approach count is 28"
    else
        fail "Single report: wrong_approach count" "expected 28, got $wa_count"
    fi
fi

# Check per_report array
if [[ -f "$OUTPUT" ]]; then
    wa_pr=$(jq -c '.patterns[] | select(.type == "wrong_approach") | .per_report' "$OUTPUT")
    if [[ "$wa_pr" == "[28]" ]]; then
        pass "Single report: per_report is [28]"
    else
        fail "Single report: per_report" "expected [28], got $wa_pr"
    fi
fi

# Check trend is "new" for single report
if [[ -f "$OUTPUT" ]]; then
    wa_trend=$(jq -r '.patterns[] | select(.type == "wrong_approach") | .trend' "$OUTPUT")
    if [[ "$wa_trend" == "new" ]]; then
        pass "Single report: trend is 'new' for single report"
    else
        fail "Single report: trend" "expected 'new', got $wa_trend"
    fi
fi

# Check first_seen and last_seen from filename
if [[ -f "$OUTPUT" ]]; then
    wa_fs=$(jq -r '.patterns[] | select(.type == "wrong_approach") | .first_seen' "$OUTPUT")
    wa_ls=$(jq -r '.patterns[] | select(.type == "wrong_approach") | .last_seen' "$OUTPUT")
    if [[ "$wa_fs" == "2026-02-10" && "$wa_ls" == "2026-02-10" ]]; then
        pass "Single report: first_seen and last_seen from filename"
    else
        fail "Single report: dates" "expected 2026-02-10, got fs=$wa_fs ls=$wa_ls"
    fi
fi

cleanup_test_dir "$TEST_DIR"

# ===================================================================
echo ""
echo "=== Test Group 2: Multi-Report Aggregation ==="
echo ""
# ===================================================================

TEST_DIR=$(setup_test_dir)

cat > "$TEST_DIR/archives/2026-02-10.md" << 'REPORT'
---
source: Claude Code Insights (Anthropic)
period: 2026-02-06 to 2026-02-10
---

# Claude Code Insights

## Friction Points

| Type | Count | Pattern |
|------|-------|---------|
| Wrong approach | 28 | Commits to incorrect strategy |
| Buggy code | 10 | Code errors |
| Misunderstood request | 8 | Expands scope |
| Excessive changes | 5 | Deep research |
| Tool limitation | 5 | MCP constraints |
REPORT

cat > "$TEST_DIR/archives/2026-02-18.md" << 'REPORT'
---
period: Feb 10-18, 2026
---

# Claude Code Insights

## Primary Friction Types

| Type | Count |
|------|-------|
| Wrong Approach | 40 |
| Misunderstood Request | 9 |
| Buggy Code | 9 |
| Excessive Changes | 5 |
| Tool Limitation | 3 |
| Tool Error | 1 |
REPORT

run_aggregate "$TEST_DIR"
OUTPUT="$TEST_DIR/patterns.json"

# Check report_count
if [[ -f "$OUTPUT" ]]; then
    rc=$(jq -r '.report_count' "$OUTPUT")
    if [[ "$rc" == "2" ]]; then
        pass "Multi-report: report_count is 2"
    else
        fail "Multi-report: report_count" "expected 2, got $rc"
    fi
fi

# Check total count for wrong_approach (28 + 40 = 68)
if [[ -f "$OUTPUT" ]]; then
    wa_count=$(jq -r '.patterns[] | select(.type == "wrong_approach") | .count' "$OUTPUT")
    if [[ "$wa_count" == "68" ]]; then
        pass "Multi-report: wrong_approach total count 68"
    else
        fail "Multi-report: wrong_approach total" "expected 68, got $wa_count"
    fi
fi

# Check per_report for wrong_approach
if [[ -f "$OUTPUT" ]]; then
    wa_pr=$(jq -c '.patterns[] | select(.type == "wrong_approach") | .per_report' "$OUTPUT")
    if [[ "$wa_pr" == "[28,40]" ]]; then
        pass "Multi-report: wrong_approach per_report [28,40]"
    else
        fail "Multi-report: wrong_approach per_report" "expected [28,40], got $wa_pr"
    fi
fi

# Check trend for wrong_approach (28 -> 40 = increasing)
if [[ -f "$OUTPUT" ]]; then
    wa_trend=$(jq -r '.patterns[] | select(.type == "wrong_approach") | .trend' "$OUTPUT")
    if [[ "$wa_trend" == "increasing" ]]; then
        pass "Multi-report: wrong_approach trend is increasing"
    else
        fail "Multi-report: wrong_approach trend" "expected increasing, got $wa_trend"
    fi
fi

# Check trend for excessive_changes (5 -> 5 = stable)
if [[ -f "$OUTPUT" ]]; then
    ec_trend=$(jq -r '.patterns[] | select(.type == "excessive_changes") | .trend' "$OUTPUT")
    if [[ "$ec_trend" == "stable" ]]; then
        pass "Multi-report: excessive_changes trend is stable"
    else
        fail "Multi-report: excessive_changes trend" "expected stable, got $ec_trend"
    fi
fi

# Check trend for buggy_code (10 -> 9 = decreasing)
if [[ -f "$OUTPUT" ]]; then
    bc_trend=$(jq -r '.patterns[] | select(.type == "buggy_code") | .trend' "$OUTPUT")
    if [[ "$bc_trend" == "decreasing" ]]; then
        pass "Multi-report: buggy_code trend is decreasing"
    else
        fail "Multi-report: buggy_code trend" "expected decreasing, got $bc_trend"
    fi
fi

# Check tool_error is "new" (appears in only 1 report)
if [[ -f "$OUTPUT" ]]; then
    te_trend=$(jq -r '.patterns[] | select(.type == "tool_error") | .trend' "$OUTPUT")
    if [[ "$te_trend" == "new" ]]; then
        pass "Multi-report: tool_error trend is new (only in 1 report)"
    else
        fail "Multi-report: tool_error trend" "expected new, got $te_trend"
    fi
fi

# Check first_seen for wrong_approach
if [[ -f "$OUTPUT" ]]; then
    wa_fs=$(jq -r '.patterns[] | select(.type == "wrong_approach") | .first_seen' "$OUTPUT")
    if [[ "$wa_fs" == "2026-02-10" ]]; then
        pass "Multi-report: wrong_approach first_seen is 2026-02-10"
    else
        fail "Multi-report: wrong_approach first_seen" "expected 2026-02-10, got $wa_fs"
    fi
fi

# Check last_seen for wrong_approach
if [[ -f "$OUTPUT" ]]; then
    wa_ls=$(jq -r '.patterns[] | select(.type == "wrong_approach") | .last_seen' "$OUTPUT")
    if [[ "$wa_ls" == "2026-02-18" ]]; then
        pass "Multi-report: wrong_approach last_seen is 2026-02-18"
    else
        fail "Multi-report: wrong_approach last_seen" "expected 2026-02-18, got $wa_ls"
    fi
fi

# Check tool_error first_seen = last_seen = 2026-02-18
if [[ -f "$OUTPUT" ]]; then
    te_fs=$(jq -r '.patterns[] | select(.type == "tool_error") | .first_seen' "$OUTPUT")
    te_ls=$(jq -r '.patterns[] | select(.type == "tool_error") | .last_seen' "$OUTPUT")
    if [[ "$te_fs" == "2026-02-18" && "$te_ls" == "2026-02-18" ]]; then
        pass "Multi-report: tool_error dates both 2026-02-18"
    else
        fail "Multi-report: tool_error dates" "expected 2026-02-18, got fs=$te_fs ls=$te_ls"
    fi
fi

# Check total pattern count (5 from report 1 + 1 new from report 2 = 6)
if [[ -f "$OUTPUT" ]]; then
    pc=$(jq '.patterns | length' "$OUTPUT")
    if [[ "$pc" == "6" ]]; then
        pass "Multi-report: 6 total unique patterns"
    else
        fail "Multi-report: pattern count" "expected 6, got $pc"
    fi
fi

# Check display_name uses first occurrence (Title Case of first-seen form)
if [[ -f "$OUTPUT" ]]; then
    wa_dn=$(jq -r '.patterns[] | select(.type == "wrong_approach") | .display_name' "$OUTPUT")
    if [[ "$wa_dn" == "Wrong Approach" ]]; then
        pass "Multi-report: display_name from first occurrence"
    else
        fail "Multi-report: display_name" "expected 'Wrong Approach', got '$wa_dn'"
    fi
fi

cleanup_test_dir "$TEST_DIR"

# ===================================================================
echo ""
echo "=== Test Group 3: Heading Variants ==="
echo ""
# ===================================================================

TEST_DIR=$(setup_test_dir)

# Test "Primary Friction Types" heading (different from "Friction Points")
cat > "$TEST_DIR/archives/2026-01-01.md" << 'REPORT'
---
source: Test
---

# Test Report

## Primary Friction Types

| Type | Count |
|------|-------|
| Wrong approach | 15 |
| New friction type | 7 |
REPORT

run_aggregate "$TEST_DIR"
OUTPUT="$TEST_DIR/patterns.json"

if [[ -f "$OUTPUT" ]]; then
    pc=$(jq '.patterns | length' "$OUTPUT")
    if [[ "$pc" == "2" ]]; then
        pass "Heading variant: Primary Friction Types detected"
    else
        fail "Heading variant: Primary Friction Types" "expected 2 patterns, got $pc"
    fi
fi

# Test case-insensitive heading
cleanup_test_dir "$TEST_DIR"
TEST_DIR=$(setup_test_dir)

cat > "$TEST_DIR/archives/2026-01-01.md" << 'REPORT'
---
source: Test
---

# Test Report

## friction points

| Type | Count |
|------|-------|
| Wrong approach | 12 |
REPORT

run_aggregate "$TEST_DIR"
OUTPUT="$TEST_DIR/patterns.json"

if [[ -f "$OUTPUT" ]]; then
    pc=$(jq '.patterns | length' "$OUTPUT")
    if [[ "$pc" == "1" ]]; then
        pass "Heading variant: case-insensitive heading detection"
    else
        fail "Heading variant: case-insensitive" "expected 1 pattern, got $pc"
    fi
fi

cleanup_test_dir "$TEST_DIR"

# ===================================================================
echo ""
echo "=== Test Group 4: Normalization ==="
echo ""
# ===================================================================

TEST_DIR=$(setup_test_dir)

cat > "$TEST_DIR/archives/2026-01-01.md" << 'REPORT'
---
source: Test
---

# Test

## Friction Points

| Type | Count |
|------|-------|
| Wrong approach | 10 |
|  Buggy Code  | 5 |
| TOOL LIMITATION | 3 |
| new custom type | 2 |
REPORT

run_aggregate "$TEST_DIR"
OUTPUT="$TEST_DIR/patterns.json"

# Check normalization: spaces to underscores, lowercase
if [[ -f "$OUTPUT" ]]; then
    types=$(jq -r '.patterns[].type' "$OUTPUT" | sort)
    expected=$(printf "buggy_code\nnew_custom_type\ntool_limitation\nwrong_approach")
    if [[ "$types" == "$expected" ]]; then
        pass "Normalization: all types correctly normalized"
    else
        fail "Normalization: types" "got: $(echo "$types" | tr '\n' ', ')"
    fi
fi

# Check display_name Title Case for custom type
if [[ -f "$OUTPUT" ]]; then
    ct_dn=$(jq -r '.patterns[] | select(.type == "new_custom_type") | .display_name' "$OUTPUT")
    if [[ "$ct_dn" == "New Custom Type" ]]; then
        pass "Normalization: custom type display_name Title Case"
    else
        fail "Normalization: custom type display_name" "expected 'New Custom Type', got '$ct_dn'"
    fi
fi

# Check trimmed whitespace doesn't affect matching
if [[ -f "$OUTPUT" ]]; then
    bc_count=$(jq -r '.patterns[] | select(.type == "buggy_code") | .count' "$OUTPUT")
    if [[ "$bc_count" == "5" ]]; then
        pass "Normalization: whitespace trimming works"
    else
        fail "Normalization: whitespace trim" "expected count 5, got $bc_count"
    fi
fi

cleanup_test_dir "$TEST_DIR"

# ===================================================================
echo ""
echo "=== Test Group 5: Error Handling ==="
echo ""
# ===================================================================

TEST_DIR=$(setup_test_dir)

# Test malformed report (no friction heading)
cat > "$TEST_DIR/archives/2026-01-01.md" << 'REPORT'
---
source: Test
---

# Test Report

## Big Wins

Everything is great!
REPORT

# Also add a valid report to ensure partial success
cat > "$TEST_DIR/archives/2026-01-02.md" << 'REPORT'
---
source: Test
---

# Test

## Friction Points

| Type | Count |
|------|-------|
| Wrong approach | 5 |
REPORT

STDERR=$(run_aggregate_stderr "$TEST_DIR")
run_aggregate "$TEST_DIR"
OUTPUT="$TEST_DIR/patterns.json"

# Script should not crash
if [[ -f "$OUTPUT" ]]; then
    pass "Error handling: script did not crash on malformed report"
else
    fail "Error handling: script crashed on malformed report"
fi

# Should have a warning about the malformed report
if echo "$STDERR" | grep -qi "2026-01-01\|warning\|skip"; then
    pass "Error handling: stderr warning for malformed report"
else
    fail "Error handling: no stderr warning" "stderr was: $STDERR"
fi

# Should still process the valid report
if [[ -f "$OUTPUT" ]]; then
    rc=$(jq -r '.report_count' "$OUTPUT")
    if [[ "$rc" == "1" ]]; then
        pass "Error handling: only valid reports counted"
    else
        fail "Error handling: report_count" "expected 1, got $rc"
    fi
fi

cleanup_test_dir "$TEST_DIR"

# Test empty archives directory
TEST_DIR=$(setup_test_dir)

run_aggregate "$TEST_DIR"
OUTPUT="$TEST_DIR/patterns.json"

if [[ -f "$OUTPUT" ]]; then
    rc=$(jq -r '.report_count' "$OUTPUT")
    pc=$(jq '.patterns | length' "$OUTPUT")
    if [[ "$rc" == "0" && "$pc" == "0" ]]; then
        pass "Error handling: empty archives produces valid empty output"
    else
        fail "Error handling: empty archives" "expected 0 reports 0 patterns, got rc=$rc pc=$pc"
    fi
else
    fail "Error handling: no output for empty archives"
fi

cleanup_test_dir "$TEST_DIR"

# Test report with heading but no table
TEST_DIR=$(setup_test_dir)

cat > "$TEST_DIR/archives/2026-01-01.md" << 'REPORT'
---
source: Test
---

# Test

## Friction Points

No table here, just text about friction.
REPORT

STDERR=$(run_aggregate_stderr "$TEST_DIR")
run_aggregate "$TEST_DIR"
OUTPUT="$TEST_DIR/patterns.json"

if [[ -f "$OUTPUT" ]]; then
    rc=$(jq -r '.report_count' "$OUTPUT")
    if [[ "$rc" == "0" ]]; then
        pass "Error handling: heading without table skipped"
    else
        fail "Error handling: heading without table" "expected 0 reports, got $rc"
    fi
fi

cleanup_test_dir "$TEST_DIR"

# ===================================================================
echo ""
echo "=== Test Group 6: Idempotent Rebuild ==="
echo ""
# ===================================================================

TEST_DIR=$(setup_test_dir)

cat > "$TEST_DIR/archives/2026-02-10.md" << 'REPORT'
---
source: Test
---

# Test

## Friction Points

| Type | Count |
|------|-------|
| Wrong approach | 28 |
| Buggy code | 10 |
REPORT

# Run twice
run_aggregate "$TEST_DIR"
FIRST=$(cat "$TEST_DIR/patterns.json" | jq -c '{schema_version, report_count, patterns: [.patterns[] | {type, display_name, count, per_report, trend, first_seen, last_seen}]}')

run_aggregate "$TEST_DIR"
SECOND=$(cat "$TEST_DIR/patterns.json" | jq -c '{schema_version, report_count, patterns: [.patterns[] | {type, display_name, count, per_report, trend, first_seen, last_seen}]}')

if [[ "$FIRST" == "$SECOND" ]]; then
    pass "Idempotent: second run produces same core data"
else
    fail "Idempotent: runs differ" "first: $FIRST, second: $SECOND"
fi

cleanup_test_dir "$TEST_DIR"

# ===================================================================
echo ""
echo "=== Test Group 7: Merge Algorithm ==="
echo ""
# ===================================================================

TEST_DIR=$(setup_test_dir)

cat > "$TEST_DIR/archives/2026-02-10.md" << 'REPORT'
---
source: Test
---

# Test

## Friction Points

| Type | Count |
|------|-------|
| Wrong approach | 28 |
| Buggy code | 10 |
REPORT

# First run
run_aggregate "$TEST_DIR"

# Manually inject linear_issue_id into patterns.json
jq '.patterns = [.patterns[] | if .type == "wrong_approach" then . + {"linear_issue_id": "CIA-999", "triaged_at": "2026-02-18T12:00:00Z"} else . end]' "$TEST_DIR/patterns.json" > "$TEST_DIR/patterns.json.tmp"
mv "$TEST_DIR/patterns.json.tmp" "$TEST_DIR/patterns.json"

# Run again — linear_issue_id should be preserved
run_aggregate "$TEST_DIR"
OUTPUT="$TEST_DIR/patterns.json"

if [[ -f "$OUTPUT" ]]; then
    lid=$(jq -r '.patterns[] | select(.type == "wrong_approach") | .linear_issue_id // empty' "$OUTPUT")
    ta=$(jq -r '.patterns[] | select(.type == "wrong_approach") | .triaged_at // empty' "$OUTPUT")
    if [[ "$lid" == "CIA-999" && "$ta" == "2026-02-18T12:00:00Z" ]]; then
        pass "Merge: linear_issue_id preserved across rebuild"
    else
        fail "Merge: linear_issue_id not preserved" "lid=$lid ta=$ta"
    fi
fi

# Verify buggy_code has no linear_issue_id (it was never set)
if [[ -f "$OUTPUT" ]]; then
    bc_lid=$(jq -r '.patterns[] | select(.type == "buggy_code") | .linear_issue_id // "null"' "$OUTPUT")
    if [[ "$bc_lid" == "null" ]]; then
        pass "Merge: unset linear_issue_id stays unset"
    else
        fail "Merge: unexpected linear_issue_id on buggy_code" "got $bc_lid"
    fi
fi

cleanup_test_dir "$TEST_DIR"

# Test merge with pattern that disappears
TEST_DIR=$(setup_test_dir)

cat > "$TEST_DIR/archives/2026-02-10.md" << 'REPORT'
---
source: Test
---

# Test

## Friction Points

| Type | Count |
|------|-------|
| Wrong approach | 28 |
| Temporary type | 3 |
REPORT

run_aggregate "$TEST_DIR"

# Inject linear_issue_id for temporary_type
jq '.patterns = [.patterns[] | if .type == "temporary_type" then . + {"linear_issue_id": "CIA-888", "triaged_at": "2026-02-18T12:00:00Z"} else . end]' "$TEST_DIR/patterns.json" > "$TEST_DIR/patterns.json.tmp"
mv "$TEST_DIR/patterns.json.tmp" "$TEST_DIR/patterns.json"

# Replace report with one that doesn't have "temporary type"
cat > "$TEST_DIR/archives/2026-02-10.md" << 'REPORT'
---
source: Test
---

# Test

## Friction Points

| Type | Count |
|------|-------|
| Wrong approach | 28 |
REPORT

run_aggregate "$TEST_DIR"
OUTPUT="$TEST_DIR/patterns.json"

if [[ -f "$OUTPUT" ]]; then
    tt_exists=$(jq '.patterns[] | select(.type == "temporary_type")' "$OUTPUT")
    if [[ -z "$tt_exists" ]]; then
        pass "Merge: disappeared pattern discarded with its tracking data"
    else
        fail "Merge: disappeared pattern not discarded"
    fi
fi

cleanup_test_dir "$TEST_DIR"

# ===================================================================
echo ""
echo "=== Test Group 8: 3+ Report Trends ==="
echo ""
# ===================================================================

TEST_DIR=$(setup_test_dir)

# Increasing: 10, 20, 30
cat > "$TEST_DIR/archives/2026-01-01.md" << 'REPORT'
---
source: Test
---

# Test

## Friction Points

| Type | Count |
|------|-------|
| Wrong approach | 10 |
| Stable type | 5 |
| Decreasing type | 30 |
REPORT

cat > "$TEST_DIR/archives/2026-01-08.md" << 'REPORT'
---
source: Test
---

# Test

## Friction Points

| Type | Count |
|------|-------|
| Wrong approach | 20 |
| Stable type | 5 |
| Decreasing type | 20 |
REPORT

cat > "$TEST_DIR/archives/2026-01-15.md" << 'REPORT'
---
source: Test
---

# Test

## Friction Points

| Type | Count |
|------|-------|
| Wrong approach | 30 |
| Stable type | 5 |
| Decreasing type | 10 |
REPORT

run_aggregate "$TEST_DIR"
OUTPUT="$TEST_DIR/patterns.json"

# Check increasing trend (slope > 0)
if [[ -f "$OUTPUT" ]]; then
    wa_trend=$(jq -r '.patterns[] | select(.type == "wrong_approach") | .trend' "$OUTPUT")
    if [[ "$wa_trend" == "increasing" ]]; then
        pass "3+ reports: increasing trend detected"
    else
        fail "3+ reports: increasing trend" "expected increasing, got $wa_trend"
    fi
fi

# Check stable trend (slope within +/-10% of mean)
if [[ -f "$OUTPUT" ]]; then
    st_trend=$(jq -r '.patterns[] | select(.type == "stable_type") | .trend' "$OUTPUT")
    if [[ "$st_trend" == "stable" ]]; then
        pass "3+ reports: stable trend detected"
    else
        fail "3+ reports: stable trend" "expected stable, got $st_trend"
    fi
fi

# Check decreasing trend (slope < 0)
if [[ -f "$OUTPUT" ]]; then
    dt_trend=$(jq -r '.patterns[] | select(.type == "decreasing_type") | .trend' "$OUTPUT")
    if [[ "$dt_trend" == "decreasing" ]]; then
        pass "3+ reports: decreasing trend detected"
    else
        fail "3+ reports: decreasing trend" "expected decreasing, got $dt_trend"
    fi
fi

# Check per_report arrays have 3 elements
if [[ -f "$OUTPUT" ]]; then
    wa_pr_len=$(jq '.patterns[] | select(.type == "wrong_approach") | .per_report | length' "$OUTPUT")
    if [[ "$wa_pr_len" == "3" ]]; then
        pass "3+ reports: per_report has 3 elements"
    else
        fail "3+ reports: per_report length" "expected 3, got $wa_pr_len"
    fi
fi

# Check report_count
if [[ -f "$OUTPUT" ]]; then
    rc=$(jq -r '.report_count' "$OUTPUT")
    if [[ "$rc" == "3" ]]; then
        pass "3+ reports: report_count is 3"
    else
        fail "3+ reports: report_count" "expected 3, got $rc"
    fi
fi

cleanup_test_dir "$TEST_DIR"

# ===================================================================
echo ""
echo "=== Test Group 9: Unknown Type Handling ==="
echo ""
# ===================================================================

TEST_DIR=$(setup_test_dir)

cat > "$TEST_DIR/archives/2026-01-01.md" << 'REPORT'
---
source: Test
---

# Test

## Friction Points

| Type | Count |
|------|-------|
| Completely new category | 7 |
| Another unknown | 3 |
REPORT

run_aggregate "$TEST_DIR"
OUTPUT="$TEST_DIR/patterns.json"

# Unknown types should be added with normalization
if [[ -f "$OUTPUT" ]]; then
    cn_type=$(jq -r '.patterns[] | select(.type == "completely_new_category") | .type' "$OUTPUT")
    if [[ "$cn_type" == "completely_new_category" ]]; then
        pass "Unknown types: normalized to canonical key"
    else
        fail "Unknown types: normalization" "type not found"
    fi
fi

# Unknown types should get Title Case display_name
if [[ -f "$OUTPUT" ]]; then
    cn_dn=$(jq -r '.patterns[] | select(.type == "completely_new_category") | .display_name' "$OUTPUT")
    if [[ "$cn_dn" == "Completely New Category" ]]; then
        pass "Unknown types: display_name Title Case"
    else
        fail "Unknown types: display_name" "expected 'Completely New Category', got '$cn_dn'"
    fi
fi

cleanup_test_dir "$TEST_DIR"

# ===================================================================
echo ""
echo "=== Test Group 10: Date Extraction and Sort Order ==="
echo ""
# ===================================================================

TEST_DIR=$(setup_test_dir)

# Create reports in reverse order on disk, but filenames ensure chronological sort
cat > "$TEST_DIR/archives/2026-03-15.md" << 'REPORT'
---
source: Test
---

# Test

## Friction Points

| Type | Count |
|------|-------|
| Wrong approach | 30 |
REPORT

cat > "$TEST_DIR/archives/2026-01-10.md" << 'REPORT'
---
source: Test
---

# Test

## Friction Points

| Type | Count |
|------|-------|
| Wrong approach | 10 |
REPORT

cat > "$TEST_DIR/archives/2026-02-20.md" << 'REPORT'
---
source: Test
---

# Test

## Friction Points

| Type | Count |
|------|-------|
| Wrong approach | 20 |
REPORT

run_aggregate "$TEST_DIR"
OUTPUT="$TEST_DIR/patterns.json"

# per_report should be sorted by filename (chronological)
if [[ -f "$OUTPUT" ]]; then
    wa_pr=$(jq -c '.patterns[] | select(.type == "wrong_approach") | .per_report' "$OUTPUT")
    if [[ "$wa_pr" == "[10,20,30]" ]]; then
        pass "Date sort: per_report sorted chronologically [10,20,30]"
    else
        fail "Date sort: per_report order" "expected [10,20,30], got $wa_pr"
    fi
fi

# first_seen should be earliest
if [[ -f "$OUTPUT" ]]; then
    wa_fs=$(jq -r '.patterns[] | select(.type == "wrong_approach") | .first_seen' "$OUTPUT")
    if [[ "$wa_fs" == "2026-01-10" ]]; then
        pass "Date sort: first_seen is earliest date"
    else
        fail "Date sort: first_seen" "expected 2026-01-10, got $wa_fs"
    fi
fi

# last_seen should be latest
if [[ -f "$OUTPUT" ]]; then
    wa_ls=$(jq -r '.patterns[] | select(.type == "wrong_approach") | .last_seen' "$OUTPUT")
    if [[ "$wa_ls" == "2026-03-15" ]]; then
        pass "Date sort: last_seen is latest date"
    else
        fail "Date sort: last_seen" "expected 2026-03-15, got $wa_ls"
    fi
fi

cleanup_test_dir "$TEST_DIR"

# ===================================================================
echo ""
echo "=== Test Group 11: Display Name First Occurrence ==="
echo ""
# ===================================================================

TEST_DIR=$(setup_test_dir)

# First report has lowercase "wrong approach"
cat > "$TEST_DIR/archives/2026-01-01.md" << 'REPORT'
---
source: Test
---

# Test

## Friction Points

| Type | Count |
|------|-------|
| wrong approach | 10 |
REPORT

# Second report has "Wrong Approach" (different casing)
cat > "$TEST_DIR/archives/2026-02-01.md" << 'REPORT'
---
source: Test
---

# Test

## Friction Points

| Type | Count |
|------|-------|
| Wrong Approach | 20 |
REPORT

run_aggregate "$TEST_DIR"
OUTPUT="$TEST_DIR/patterns.json"

# display_name should be Title Case of the first occurrence: "wrong approach" -> "Wrong Approach"
if [[ -f "$OUTPUT" ]]; then
    wa_dn=$(jq -r '.patterns[] | select(.type == "wrong_approach") | .display_name' "$OUTPUT")
    if [[ "$wa_dn" == "Wrong Approach" ]]; then
        pass "Display name: first occurrence converted to Title Case"
    else
        fail "Display name: first occurrence" "expected 'Wrong Approach', got '$wa_dn'"
    fi
fi

cleanup_test_dir "$TEST_DIR"

# ===================================================================
echo ""
echo "=== Test Group 12: Non-MD Files Ignored ==="
echo ""
# ===================================================================

TEST_DIR=$(setup_test_dir)

cat > "$TEST_DIR/archives/2026-01-01.md" << 'REPORT'
---
source: Test
---

# Test

## Friction Points

| Type | Count |
|------|-------|
| Wrong approach | 10 |
REPORT

# Create a non-md file that should be ignored
cat > "$TEST_DIR/archives/notes.txt" << 'NOTES'
This is not a report.
NOTES

# Create a file without YYYY-MM-DD pattern
cat > "$TEST_DIR/archives/summary.md" << 'SUMMARY'
---
source: Test
---

# Summary

## Friction Points

| Type | Count |
|------|-------|
| Should be ignored | 99 |
SUMMARY

run_aggregate "$TEST_DIR"
OUTPUT="$TEST_DIR/patterns.json"

if [[ -f "$OUTPUT" ]]; then
    rc=$(jq -r '.report_count' "$OUTPUT")
    if [[ "$rc" == "1" ]]; then
        pass "File filter: only YYYY-MM-DD.md files processed"
    else
        fail "File filter: wrong report count" "expected 1, got $rc"
    fi
fi

cleanup_test_dir "$TEST_DIR"

# ===================================================================
echo ""
echo "==========================================="
echo "  Results: $PASS passed, $FAIL failed ($TOTAL total)"
echo "==========================================="
echo ""

if [[ $FAIL -gt 0 ]]; then
    echo "FAILED: $FAIL test(s) did not pass."
    exit 1
else
    echo "ALL TESTS PASSED."
    exit 0
fi
