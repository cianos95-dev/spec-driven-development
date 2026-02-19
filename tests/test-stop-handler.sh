#!/usr/bin/env bash
# CCC Stop Handler Integration Tests — CIA-521
#
# Tests for hooks/scripts/ccc-stop-handler.sh (Stop hook)
# The stop handler is the core execution loop driver — it fires after each
# Claude Code turn and decides whether to continue or allow the session to stop.
#
# Run: bash tests/test-stop-handler.sh
# Requires: jq, git
# Optional: yq (preference-dependent tests are skipped without it)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK="$PLUGIN_ROOT/hooks/scripts/ccc-stop-handler.sh"

# Test workspace — isolated from real project
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# Initialize a git repo so the hook can find project root
git init "$TEST_DIR" --quiet

PASS=0
FAIL=0
SKIP=0
TOTAL=0

# Detect yq — preference-dependent tests require it
HAS_YQ=false
command -v yq &>/dev/null && HAS_YQ=true

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

reset_state() {
    rm -f "$TEST_DIR/.ccc-state.json"
    rm -f "$TEST_DIR/.ccc-progress.md"
    rm -f "$TEST_DIR/.ccc-preferences.yaml"
    rm -f "$TEST_DIR/.ccc-agents.md"
    rm -f "$TEST_DIR/transcript.jsonl"
    rm -f "$TEST_DIR/stdout.tmp"
    rm -f "$TEST_DIR/stderr.tmp"
}

# Create a minimal state file for the execution phase
make_state() {
    local task_index="${1:-0}"
    local total_tasks="${2:-3}"
    local task_iter="${3:-1}"
    local max_task_iter="${4:-5}"
    local global_iter="${5:-0}"
    local max_global_iter="${6:-50}"
    local exec_mode="${7:-quick}"
    local phase="${8:-execution}"
    local awaiting_gate="${9:-}"
    local linear_issue="${10:-CIA-521}"
    local spec_path="${11:-}"
    local replan_count="${12:-0}"

    jq -n \
        --argjson taskIndex "$task_index" \
        --argjson totalTasks "$total_tasks" \
        --argjson taskIteration "$task_iter" \
        --argjson maxTaskIterations "$max_task_iter" \
        --argjson globalIteration "$global_iter" \
        --argjson maxGlobalIterations "$max_global_iter" \
        --arg executionMode "$exec_mode" \
        --arg phase "$phase" \
        --arg awaitingGate "$awaiting_gate" \
        --arg linearIssue "$linear_issue" \
        --arg specPath "$spec_path" \
        --argjson replanCount "$replan_count" \
        '{
            phase: $phase,
            taskIndex: $taskIndex,
            totalTasks: $totalTasks,
            taskIteration: $taskIteration,
            maxTaskIterations: $maxTaskIterations,
            globalIteration: $globalIteration,
            maxGlobalIterations: $maxGlobalIterations,
            executionMode: $executionMode,
            awaitingGate: (if $awaitingGate == "" then null else $awaitingGate end),
            linearIssue: $linearIssue,
            specPath: $specPath,
            replanCount: $replanCount
        }' > "$TEST_DIR/.ccc-state.json"
}

# Create a fake transcript with an assistant message containing the given text
make_transcript() {
    local message_text="$1"
    local transcript_file="$TEST_DIR/transcript.jsonl"
    # Write a compact JSONL line (-c) that mimics Claude Code transcript format.
    # The handler greps for "role":"assistant" on a single line, so compact is required.
    jq -cn --arg text "$message_text" \
        '{"role":"assistant","message":{"content":[{"type":"text","text":$text}]}}' \
        > "$transcript_file"
    echo "$transcript_file"
}

# Run the stop handler with optional transcript path
run_hook() {
    local transcript_path="${1:-}"
    local exit_code=0
    local input
    input=$(jq -n --arg tp "$transcript_path" '{transcript_path: $tp}')
    export CCC_PROJECT_ROOT="$TEST_DIR"
    echo "$input" | bash "$HOOK" >"$TEST_DIR/stdout.tmp" 2>"$TEST_DIR/stderr.tmp" || exit_code=$?
    echo "$exit_code"
}

# Run the hook with no stdin transcript path (empty)
run_hook_no_transcript() {
    local exit_code=0
    export CCC_PROJECT_ROOT="$TEST_DIR"
    echo '{}' | bash "$HOOK" >"$TEST_DIR/stdout.tmp" 2>"$TEST_DIR/stderr.tmp" || exit_code=$?
    echo "$exit_code"
}

get_stdout() {
    cat "$TEST_DIR/stdout.tmp"
}

get_decision() {
    cat "$TEST_DIR/stdout.tmp" | jq -r '.decision // empty' 2>/dev/null
}

get_reason() {
    cat "$TEST_DIR/stdout.tmp" | jq -r '.reason // empty' 2>/dev/null
}

get_state_field() {
    local field="$1"
    jq -r ".$field // empty" "$TEST_DIR/.ccc-state.json" 2>/dev/null
}

assert_eq() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"
    TOTAL=$((TOTAL + 1))
    if [[ "$expected" == "$actual" ]]; then
        echo "  PASS: $test_name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $test_name (expected '$expected', got '$actual')"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local test_name="$1"
    local needle="$2"
    local haystack="$3"
    TOTAL=$((TOTAL + 1))
    if echo "$haystack" | grep -q "$needle"; then
        echo "  PASS: $test_name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $test_name (expected to contain '$needle')"
        FAIL=$((FAIL + 1))
    fi
}

assert_not_contains() {
    local test_name="$1"
    local needle="$2"
    local haystack="$3"
    TOTAL=$((TOTAL + 1))
    if echo "$haystack" | grep -q "$needle"; then
        echo "  FAIL: $test_name (should NOT contain '$needle')"
        FAIL=$((FAIL + 1))
    else
        echo "  PASS: $test_name"
        PASS=$((PASS + 1))
    fi
}

assert_file_exists() {
    local test_name="$1"
    local file="$2"
    TOTAL=$((TOTAL + 1))
    if [[ -f "$file" ]]; then
        echo "  PASS: $test_name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $test_name (file '$file' does not exist)"
        FAIL=$((FAIL + 1))
    fi
}

assert_file_not_exists() {
    local test_name="$1"
    local file="$2"
    TOTAL=$((TOTAL + 1))
    if [[ ! -f "$file" ]]; then
        echo "  PASS: $test_name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $test_name (file '$file' should not exist)"
        FAIL=$((FAIL + 1))
    fi
}

# Skip a test (e.g. missing optional dependency)
skip_test() {
    local test_name="$1"
    local reason="${2:-}"
    TOTAL=$((TOTAL + 1))
    SKIP=$((SKIP + 1))
    if [[ -n "$reason" ]]; then
        echo "  SKIP: $test_name ($reason)"
    else
        echo "  SKIP: $test_name"
    fi
}

# ===================================================================
echo ""
echo "=== Test Suite: CCC Stop Handler (hooks/scripts/ccc-stop-handler.sh) ==="
echo ""
# ===================================================================

# ===================================================================
echo "--- Section: Early Exit Conditions ---"
echo ""
# ===================================================================

# --- Test 1: No state file → allow stop ---
echo "Test 1: No state file allows stop (exit 0, no output)"
reset_state
EXIT_CODE=$(run_hook_no_transcript)
STDOUT=$(get_stdout)
assert_eq "Exit code 0" "0" "$EXIT_CODE"
assert_eq "No stdout output" "" "$STDOUT"

# --- Test 2: Empty state file → allow stop ---
echo ""
echo "Test 2: Empty state file allows stop"
reset_state
touch "$TEST_DIR/.ccc-state.json"
EXIT_CODE=$(run_hook_no_transcript)
STDOUT=$(get_stdout)
assert_eq "Exit code 0" "0" "$EXIT_CODE"
assert_eq "No stdout output" "" "$STDOUT"

# --- Test 3: Corrupt state (invalid JSON) → allow stop ---
echo ""
echo "Test 3: Corrupt state file (invalid JSON) allows stop"
reset_state
echo "NOT VALID JSON {{{" > "$TEST_DIR/.ccc-state.json"
EXIT_CODE=$(run_hook_no_transcript)
STDOUT=$(get_stdout)
assert_eq "Exit code 0" "0" "$EXIT_CODE"
assert_eq "No stdout output" "" "$STDOUT"

# --- Test 4: Awaiting gate → allow stop ---
echo ""
echo "Test 4: Awaiting gate allows stop immediately"
reset_state
make_state 0 3 1 5 0 50 "quick" "execution" "2"
EXIT_CODE=$(run_hook_no_transcript)
STDOUT=$(get_stdout)
assert_eq "Exit code 0" "0" "$EXIT_CODE"
assert_eq "No stdout output" "" "$STDOUT"

# --- Test 5: Non-execution phase → allow stop ---
echo ""
echo "Test 5: Non-execution phase (spec) allows stop"
reset_state
make_state 0 3 1 5 0 50 "quick" "spec"
EXIT_CODE=$(run_hook_no_transcript)
STDOUT=$(get_stdout)
assert_eq "Exit code 0" "0" "$EXIT_CODE"
assert_eq "No stdout output" "" "$STDOUT"

# --- Test 6: Null/empty phase → allow stop ---
echo ""
echo "Test 6: Null phase allows stop"
reset_state
echo '{"phase": null, "taskIndex": 0, "totalTasks": 3}' > "$TEST_DIR/.ccc-state.json"
EXIT_CODE=$(run_hook_no_transcript)
STDOUT=$(get_stdout)
assert_eq "Exit code 0" "0" "$EXIT_CODE"
assert_eq "No stdout output" "" "$STDOUT"

# --- Test 7: Pair mode → allow stop ---
echo ""
echo "Test 7: Pair execution mode allows stop"
reset_state
make_state 0 3 1 5 0 50 "pair" "execution"
TRANSCRIPT=$(make_transcript "I completed the work")
EXIT_CODE=$(run_hook "$TRANSCRIPT")
STDOUT=$(get_stdout)
assert_eq "Exit code 0" "0" "$EXIT_CODE"
assert_eq "No stdout output" "" "$STDOUT"

# --- Test 8: Swarm mode → allow stop ---
echo ""
echo "Test 8: Swarm execution mode allows stop"
reset_state
make_state 0 3 1 5 0 50 "swarm" "execution"
TRANSCRIPT=$(make_transcript "I completed the work")
EXIT_CODE=$(run_hook "$TRANSCRIPT")
STDOUT=$(get_stdout)
assert_eq "Exit code 0" "0" "$EXIT_CODE"
assert_eq "No stdout output" "" "$STDOUT"

# ===================================================================
echo ""
echo "--- Section: Safety Caps ---"
echo ""
# ===================================================================

# --- Test 9: Global iteration cap reached → block ---
echo "Test 9: Global iteration cap reached blocks with reason"
reset_state
make_state 0 3 1 5 50 50 "quick" "execution"
TRANSCRIPT=$(make_transcript "Working on it...")
EXIT_CODE=$(run_hook "$TRANSCRIPT")
DECISION=$(get_decision)
REASON=$(get_reason)
assert_eq "Exit code 0" "0" "$EXIT_CODE"
assert_eq "Decision is block" "block" "$DECISION"
assert_contains "Reason mentions max global iterations" "Max global iterations" "$REASON"

# --- Test 10: Per-task iteration cap reached → block ---
echo ""
echo "Test 10: Per-task iteration cap reached blocks with reason"
reset_state
make_state 0 3 5 5 2 50 "quick" "execution"
TRANSCRIPT=$(make_transcript "Still working...")
EXIT_CODE=$(run_hook "$TRANSCRIPT")
DECISION=$(get_decision)
REASON=$(get_reason)
assert_eq "Exit code 0" "0" "$EXIT_CODE"
assert_eq "Decision is block" "block" "$DECISION"
assert_contains "Reason mentions task failure" "failed after" "$REASON"

# ===================================================================
echo ""
echo "--- Section: Task Completion ---"
echo ""
# ===================================================================

# --- Test 11: All tasks already completed → clean up state, keep progress ---
echo "Test 11: All tasks completed removes state, preserves progress"
reset_state
make_state 3 3 1 5 5 50 "quick" "execution"
echo "# Progress log" > "$TEST_DIR/.ccc-progress.md"
TRANSCRIPT=$(make_transcript "Done")
EXIT_CODE=$(run_hook "$TRANSCRIPT")
STDOUT=$(get_stdout)
assert_eq "Exit code 0" "0" "$EXIT_CODE"
assert_eq "No stdout output" "" "$STDOUT"
assert_file_not_exists "State file removed" "$TEST_DIR/.ccc-state.json"
assert_file_exists "Progress file preserved" "$TEST_DIR/.ccc-progress.md"

# --- Test 12: TASK_COMPLETE signal → advance taskIndex, reset taskIteration ---
echo ""
echo "Test 12: TASK_COMPLETE advances taskIndex and resets taskIteration"
reset_state
make_state 0 3 2 5 5 50 "quick" "execution"
TRANSCRIPT=$(make_transcript "All done. TASK_COMPLETE")
EXIT_CODE=$(run_hook "$TRANSCRIPT")
DECISION=$(get_decision)
assert_eq "Exit code 0" "0" "$EXIT_CODE"
assert_eq "Decision is block (continue to next task)" "block" "$DECISION"
# Check state was updated
NEW_INDEX=$(get_state_field "taskIndex")
NEW_TASK_ITER=$(get_state_field "taskIteration")
NEW_GLOBAL_ITER=$(get_state_field "globalIteration")
assert_eq "taskIndex advanced to 1" "1" "$NEW_INDEX"
assert_eq "taskIteration reset to 1" "1" "$NEW_TASK_ITER"
assert_eq "globalIteration incremented to 6" "6" "$NEW_GLOBAL_ITER"

# --- Test 13: TASK_COMPLETE on last task → remove state ---
echo ""
echo "Test 13: TASK_COMPLETE on last task removes state file"
reset_state
make_state 2 3 1 5 8 50 "quick" "execution"
echo "# Progress log" > "$TEST_DIR/.ccc-progress.md"
TRANSCRIPT=$(make_transcript "Finished the last one. TASK_COMPLETE")
EXIT_CODE=$(run_hook "$TRANSCRIPT")
STDOUT=$(get_stdout)
assert_eq "Exit code 0" "0" "$EXIT_CODE"
assert_eq "No stdout (session ends)" "" "$STDOUT"
assert_file_not_exists "State file removed" "$TEST_DIR/.ccc-state.json"
assert_file_exists "Progress file preserved" "$TEST_DIR/.ccc-progress.md"

# --- Test 14: No TASK_COMPLETE → retry (increment taskIteration, block) ---
echo ""
echo "Test 14: No TASK_COMPLETE signal triggers retry with incremented taskIteration"
reset_state
make_state 1 3 1 5 3 50 "quick" "execution"
TRANSCRIPT=$(make_transcript "I made some progress but didn't finish")
EXIT_CODE=$(run_hook "$TRANSCRIPT")
DECISION=$(get_decision)
REASON=$(get_reason)
assert_eq "Exit code 0" "0" "$EXIT_CODE"
assert_eq "Decision is block (retry)" "block" "$DECISION"
assert_contains "Reason mentions retry" "Retry attempt" "$REASON"
# Check state was updated
NEW_TASK_ITER=$(get_state_field "taskIteration")
NEW_GLOBAL_ITER=$(get_state_field "globalIteration")
assert_eq "taskIteration incremented to 2" "2" "$NEW_TASK_ITER"
assert_eq "globalIteration incremented to 4" "4" "$NEW_GLOBAL_ITER"

# --- Test 15: No transcript path → retry (no signal possible) ---
echo ""
echo "Test 15: No transcript path triggers retry (cannot detect TASK_COMPLETE)"
reset_state
make_state 0 3 1 5 0 50 "quick" "execution"
EXIT_CODE=$(run_hook_no_transcript)
DECISION=$(get_decision)
REASON=$(get_reason)
assert_eq "Exit code 0" "0" "$EXIT_CODE"
assert_eq "Decision is block (retry)" "block" "$DECISION"
assert_contains "Reason mentions retry" "Retry attempt" "$REASON"

# ===================================================================
echo ""
echo "--- Section: REPLAN Signal ---"
echo ""
# ===================================================================

# --- Test 16: REPLAN signal → update state, block with planning prompt ---
echo "Test 16: REPLAN signal updates state and blocks with planning prompt"
reset_state
make_state 1 3 1 5 3 50 "quick" "execution" "" "CIA-521" "docs/spec.md" 0
TRANSCRIPT=$(make_transcript "The remaining tasks are invalid. REPLAN needed.")
EXIT_CODE=$(run_hook "$TRANSCRIPT")
DECISION=$(get_decision)
REASON=$(get_reason)
assert_eq "Exit code 0" "0" "$EXIT_CODE"
assert_eq "Decision is block (replan)" "block" "$DECISION"
assert_contains "Reason mentions REPLAN" "REPLAN" "$REASON"
assert_contains "Reason mentions spec path" "docs/spec.md" "$REASON"
# Check state was updated
NEW_PHASE=$(get_state_field "phase")
NEW_REPLAN=$(get_state_field "replanCount")
assert_eq "Phase set to replan" "replan" "$NEW_PHASE"
assert_eq "replanCount incremented to 1" "1" "$NEW_REPLAN"

# --- Test 17: REPLAN at max replans → block with halt message ---
echo ""
echo "Test 17: REPLAN at max replans halts execution"
reset_state
make_state 1 3 1 5 5 50 "quick" "execution" "" "CIA-521" "" 2
TRANSCRIPT=$(make_transcript "This needs another REPLAN")
EXIT_CODE=$(run_hook "$TRANSCRIPT")
DECISION=$(get_decision)
REASON=$(get_reason)
assert_eq "Exit code 0" "0" "$EXIT_CODE"
assert_eq "Decision is block" "block" "$DECISION"
assert_contains "Reason mentions max replans" "Max replans" "$REASON"

# --- Test 18: REPLAN disabled in preferences → falls through to retry ---
echo ""
echo "Test 18: REPLAN disabled in preferences falls through to retry"
if $HAS_YQ; then
    reset_state
    make_state 1 3 1 5 3 50 "quick" "execution" "" "CIA-521" "" 0
    cat > "$TEST_DIR/.ccc-preferences.yaml" << 'PREFS'
replan:
  enabled: false
PREFS
    TRANSCRIPT=$(make_transcript "This needs REPLAN for sure")
    EXIT_CODE=$(run_hook "$TRANSCRIPT")
    DECISION=$(get_decision)
    REASON=$(get_reason)
    assert_eq "Exit code 0" "0" "$EXIT_CODE"
    assert_eq "Decision is block (retry, not replan)" "block" "$DECISION"
    assert_contains "Reason mentions retry (not replan)" "Retry attempt" "$REASON"
    # Phase should NOT be replan
    PHASE=$(get_state_field "phase")
    assert_eq "Phase remains execution" "execution" "$PHASE"
else
    skip_test "REPLAN disabled via preferences" "yq not installed"
fi

# ===================================================================
echo ""
echo "--- Section: Continue Prompt Enrichments ---"
echo ""
# ===================================================================

# --- Test 19: TDD mode enrichment in retry prompt ---
echo "Test 19: TDD execution mode adds red-green-refactor to retry prompt"
reset_state
make_state 0 3 1 5 0 50 "tdd" "execution"
TRANSCRIPT=$(make_transcript "Some work done")
EXIT_CODE=$(run_hook "$TRANSCRIPT")
REASON=$(get_reason)
assert_eq "Exit code 0" "0" "$EXIT_CODE"
assert_contains "Reason mentions red-green-refactor" "red-green-refactor" "$REASON"

# --- Test 20: Checkpoint mode enrichment in retry prompt ---
echo ""
echo "Test 20: Checkpoint execution mode adds checkpoint gates to retry prompt"
reset_state
make_state 0 3 1 5 0 50 "checkpoint" "execution"
TRANSCRIPT=$(make_transcript "Some work done")
EXIT_CODE=$(run_hook "$TRANSCRIPT")
REASON=$(get_reason)
assert_eq "Exit code 0" "0" "$EXIT_CODE"
assert_contains "Reason mentions checkpoint gates" "checkpoint gates" "$REASON"

# --- Test 21: TDD mode enrichment in TASK_COMPLETE continue prompt ---
echo ""
echo "Test 21: TDD mode adds enrichment to TASK_COMPLETE continue prompt"
reset_state
make_state 0 3 1 5 0 50 "tdd" "execution"
TRANSCRIPT=$(make_transcript "Done with this task. TASK_COMPLETE")
EXIT_CODE=$(run_hook "$TRANSCRIPT")
REASON=$(get_reason)
assert_contains "Continue prompt mentions red-green-refactor" "red-green-refactor" "$REASON"

# --- Test 22: Checkpoint mode enrichment in TASK_COMPLETE continue prompt ---
echo ""
echo "Test 22: Checkpoint mode adds enrichment to TASK_COMPLETE continue prompt"
reset_state
make_state 0 3 1 5 0 50 "checkpoint" "execution"
TRANSCRIPT=$(make_transcript "Done with this task. TASK_COMPLETE")
EXIT_CODE=$(run_hook "$TRANSCRIPT")
REASON=$(get_reason)
assert_contains "Continue prompt mentions checkpoint gates" "checkpoint gates" "$REASON"

# --- Test 23: Continue prompt includes linear issue ---
echo ""
echo "Test 23: Continue prompt includes linear issue reference"
reset_state
make_state 0 3 1 5 0 50 "quick" "execution" "" "CIA-521"
TRANSCRIPT=$(make_transcript "Working on it")
EXIT_CODE=$(run_hook "$TRANSCRIPT")
REASON=$(get_reason)
assert_contains "Reason mentions linear issue" "CIA-521" "$REASON"

# --- Test 24: Continue prompt includes spec path ---
echo ""
echo "Test 24: Continue prompt on TASK_COMPLETE includes spec path"
reset_state
make_state 0 3 1 5 0 50 "quick" "execution" "" "CIA-521" "docs/my-spec.md"
TRANSCRIPT=$(make_transcript "TASK_COMPLETE")
EXIT_CODE=$(run_hook "$TRANSCRIPT")
REASON=$(get_reason)
assert_contains "Reason mentions spec path" "docs/my-spec.md" "$REASON"

# --- Test 25: Continue prompt signals TASK_COMPLETE instruction ---
echo ""
echo "Test 25: Continue prompt always ends with TASK_COMPLETE instruction"
reset_state
make_state 0 3 1 5 0 50 "quick" "execution"
TRANSCRIPT=$(make_transcript "Progress")
EXIT_CODE=$(run_hook "$TRANSCRIPT")
REASON=$(get_reason)
assert_contains "Reason ends with TASK_COMPLETE instruction" "Signal TASK_COMPLETE when done" "$REASON"

# ===================================================================
echo ""
echo "--- Section: Preference Overrides ---"
echo ""
# ===================================================================

# --- Test 26: Preference overrides maxTaskIterations ---
echo "Test 26: Preference overrides maxTaskIterations"
if $HAS_YQ; then
    reset_state
    # State says max 5, but preference says max 2
    make_state 0 3 2 5 0 50 "quick" "execution"
    cat > "$TEST_DIR/.ccc-preferences.yaml" << 'PREFS'
execution:
  max_task_iterations: 2
PREFS
    TRANSCRIPT=$(make_transcript "Still working")
    EXIT_CODE=$(run_hook "$TRANSCRIPT")
    DECISION=$(get_decision)
    REASON=$(get_reason)
    assert_eq "Exit code 0" "0" "$EXIT_CODE"
    assert_eq "Decision is block (hit pref cap)" "block" "$DECISION"
    assert_contains "Reason mentions task failure" "failed after" "$REASON"
else
    skip_test "Preference overrides maxTaskIterations" "yq not installed"
fi

# --- Test 27: Preference overrides maxGlobalIterations ---
echo ""
echo "Test 27: Preference overrides maxGlobalIterations"
if $HAS_YQ; then
    reset_state
    # State says max 50, but preference says max 5
    make_state 0 3 1 5 5 50 "quick" "execution"
    cat > "$TEST_DIR/.ccc-preferences.yaml" << 'PREFS'
execution:
  max_global_iterations: 5
PREFS
    TRANSCRIPT=$(make_transcript "Still working")
    EXIT_CODE=$(run_hook "$TRANSCRIPT")
    DECISION=$(get_decision)
    REASON=$(get_reason)
    assert_eq "Exit code 0" "0" "$EXIT_CODE"
    assert_eq "Decision is block (hit pref cap)" "block" "$DECISION"
    assert_contains "Reason mentions max global" "Max global iterations" "$REASON"
else
    skip_test "Preference overrides maxGlobalIterations" "yq not installed"
fi

# ===================================================================
echo ""
echo "--- Section: State File Atomicity ---"
echo ""
# ===================================================================

# --- Test 28: State file has lastUpdatedAt after task advance ---
echo "Test 28: State file includes lastUpdatedAt after task advance"
reset_state
make_state 0 3 1 5 0 50 "quick" "execution"
TRANSCRIPT=$(make_transcript "TASK_COMPLETE")
EXIT_CODE=$(run_hook "$TRANSCRIPT")
LAST_UPDATED=$(get_state_field "lastUpdatedAt")
assert_eq "Exit code 0" "0" "$EXIT_CODE"
# lastUpdatedAt should be a non-empty ISO timestamp
TOTAL=$((TOTAL + 1))
if [[ -n "$LAST_UPDATED" ]] && echo "$LAST_UPDATED" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T'; then
    echo "  PASS: lastUpdatedAt is valid ISO timestamp ($LAST_UPDATED)"
    PASS=$((PASS + 1))
else
    echo "  FAIL: lastUpdatedAt should be ISO timestamp (got '$LAST_UPDATED')"
    FAIL=$((FAIL + 1))
fi

# --- Test 29: State file has lastUpdatedAt after retry ---
echo ""
echo "Test 29: State file includes lastUpdatedAt after retry"
reset_state
make_state 0 3 1 5 0 50 "quick" "execution"
TRANSCRIPT=$(make_transcript "Working on it...")
EXIT_CODE=$(run_hook "$TRANSCRIPT")
LAST_UPDATED=$(get_state_field "lastUpdatedAt")
TOTAL=$((TOTAL + 1))
if [[ -n "$LAST_UPDATED" ]] && echo "$LAST_UPDATED" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T'; then
    echo "  PASS: lastUpdatedAt is valid ISO timestamp after retry ($LAST_UPDATED)"
    PASS=$((PASS + 1))
else
    echo "  FAIL: lastUpdatedAt should be ISO timestamp after retry (got '$LAST_UPDATED')"
    FAIL=$((FAIL + 1))
fi

# --- Test 30: Other state fields preserved during task advance ---
echo ""
echo "Test 30: Other state fields preserved during task advance"
reset_state
make_state 0 3 1 5 0 50 "tdd" "execution" "" "CIA-999" "docs/spec.md"
TRANSCRIPT=$(make_transcript "TASK_COMPLETE")
EXIT_CODE=$(run_hook "$TRANSCRIPT")
# Verify non-modified fields are still present
EXEC_MODE=$(get_state_field "executionMode")
LINEAR=$(get_state_field "linearIssue")
SPEC=$(get_state_field "specPath")
assert_eq "executionMode preserved" "tdd" "$EXEC_MODE"
assert_eq "linearIssue preserved" "CIA-999" "$LINEAR"
assert_eq "specPath preserved" "docs/spec.md" "$SPEC"

# ===================================================================
echo ""
echo "--- Section: Prompt Enrichment Preferences ---"
echo ""
# ===================================================================

# --- Test 31: Subagent discipline enrichment included by default ---
echo "Test 31: Subagent discipline enrichment included by default"
reset_state
make_state 0 3 1 5 0 50 "quick" "execution"
TRANSCRIPT=$(make_transcript "Some work")
EXIT_CODE=$(run_hook "$TRANSCRIPT")
REASON=$(get_reason)
assert_contains "Reason mentions parallel subagents" "parallel subagents" "$REASON"

# --- Test 32: Search before build enrichment included by default ---
echo ""
echo "Test 32: Search before build enrichment included by default"
reset_state
make_state 0 3 1 5 0 50 "quick" "execution"
TRANSCRIPT=$(make_transcript "Some work")
EXIT_CODE=$(run_hook "$TRANSCRIPT")
REASON=$(get_reason)
assert_contains "Reason mentions search codebase" "search the codebase" "$REASON"

# --- Test 33: Subagent enrichment disabled via preferences ---
echo ""
echo "Test 33: Subagent discipline disabled via preferences"
if $HAS_YQ; then
    reset_state
    make_state 0 3 1 5 0 50 "quick" "execution"
    cat > "$TEST_DIR/.ccc-preferences.yaml" << 'PREFS'
prompts:
  subagent_discipline: false
PREFS
    TRANSCRIPT=$(make_transcript "Some work")
    EXIT_CODE=$(run_hook "$TRANSCRIPT")
    REASON=$(get_reason)
    assert_not_contains "Reason does not mention parallel subagents" "parallel subagents" "$REASON"
else
    skip_test "Subagent discipline disabled via preferences" "yq not installed"
fi

# --- Test 34: Agents file enrichment when .ccc-agents.md exists ---
echo ""
echo "Test 34: Agents file enrichment when .ccc-agents.md exists"
reset_state
make_state 0 3 1 5 0 50 "quick" "execution"
echo "# Agent config" > "$TEST_DIR/.ccc-agents.md"
TRANSCRIPT=$(make_transcript "Some work")
EXIT_CODE=$(run_hook "$TRANSCRIPT")
REASON=$(get_reason)
assert_contains "Reason mentions .ccc-agents.md" ".ccc-agents.md" "$REASON"

# --- Test 35: No agents file enrichment when .ccc-agents.md missing ---
echo ""
echo "Test 35: No agents file enrichment when .ccc-agents.md missing"
reset_state
make_state 0 3 1 5 0 50 "quick" "execution"
TRANSCRIPT=$(make_transcript "Some work")
EXIT_CODE=$(run_hook "$TRANSCRIPT")
REASON=$(get_reason)
assert_not_contains "Reason does not mention .ccc-agents.md" ".ccc-agents.md" "$REASON"

# ===================================================================
echo ""
echo "--- Section: Edge Cases ---"
echo ""
# ===================================================================

# --- Test 36: TASK_COMPLETE and REPLAN in same output — REPLAN takes priority ---
echo "Test 36: REPLAN checked before TASK_COMPLETE (REPLAN wins)"
reset_state
make_state 1 3 1 5 3 50 "quick" "execution" "" "CIA-521" "" 0
TRANSCRIPT=$(make_transcript "TASK_COMPLETE but also REPLAN")
EXIT_CODE=$(run_hook "$TRANSCRIPT")
REASON=$(get_reason)
NEW_PHASE=$(get_state_field "phase")
assert_eq "Exit code 0" "0" "$EXIT_CODE"
assert_eq "Phase set to replan" "replan" "$NEW_PHASE"
assert_contains "Reason mentions REPLAN" "REPLAN" "$REASON"

# --- Test 37: Non-looping phases (intake, review, closure, etc.) ---
echo ""
echo "Test 37: Various non-execution phases all allow stop"
reset_state
for PHASE in intake spec review decompose verification closure replan; do
    make_state 0 3 1 5 0 50 "quick" "$PHASE"
    EXIT_CODE=$(run_hook_no_transcript)
    STDOUT=$(get_stdout)
    assert_eq "Phase '$PHASE' allows stop" "0" "$EXIT_CODE"
done

# --- Test 38: taskIndex=0, totalTasks=0 → all tasks completed ---
echo ""
echo "Test 38: Zero total tasks means all tasks completed"
reset_state
make_state 0 0 1 5 0 50 "quick" "execution"
TRANSCRIPT=$(make_transcript "Nothing to do")
EXIT_CODE=$(run_hook "$TRANSCRIPT")
STDOUT=$(get_stdout)
assert_eq "Exit code 0" "0" "$EXIT_CODE"
assert_eq "No stdout (all done)" "" "$STDOUT"
assert_file_not_exists "State file removed" "$TEST_DIR/.ccc-state.json"

# --- Test 39: RICE prioritization framework enrichment ---
echo ""
echo "Test 39: RICE prioritization framework enrichment"
if $HAS_YQ; then
    reset_state
    make_state 0 3 1 5 0 50 "quick" "execution"
    cat > "$TEST_DIR/.ccc-preferences.yaml" << 'PREFS'
planning:
  prioritization_framework: rice
PREFS
    TRANSCRIPT=$(make_transcript "Working")
    EXIT_CODE=$(run_hook "$TRANSCRIPT")
    REASON=$(get_reason)
    assert_contains "Reason mentions RICE" "RICE" "$REASON"
else
    skip_test "RICE prioritization framework enrichment" "yq not installed"
fi

# --- Test 40: Budget eval enrichment ---
echo ""
echo "Test 40: Budget eval cost profile enrichment"
reset_state
make_state 0 3 1 5 0 50 "quick" "execution"
# Default preferences include budget cost profile
TRANSCRIPT=$(make_transcript "Working")
EXIT_CODE=$(run_hook "$TRANSCRIPT")
REASON=$(get_reason)
assert_contains "Reason mentions budget checkpoint" "budget" "$REASON"

# ===================================================================
echo ""
echo "==========================================="
echo "  Results: $PASS passed, $FAIL failed, $SKIP skipped ($TOTAL total)"
echo "==========================================="
echo ""

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
