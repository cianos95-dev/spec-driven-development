#!/usr/bin/env bash
# Agent Teams Hook Tests — CIA-565
#
# Tests for hooks/scripts/teammate-idle-gate.sh and task-completed-gate.sh
#
# Run: bash tests/test-agent-teams-hooks.sh
# Requires: jq

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
IDLE_HOOK="$PLUGIN_ROOT/hooks/scripts/teammate-idle-gate.sh"
TASK_HOOK="$PLUGIN_ROOT/hooks/scripts/task-completed-gate.sh"

# Test workspace — isolated from real project
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# Initialize a git repo so hooks can find project root
git init "$TEST_DIR" --quiet
export CCC_PROJECT_ROOT="$TEST_DIR"

PASS=0
FAIL=0
TOTAL=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

reset_state() {
    rm -f "$TEST_DIR/.ccc-agent-teams.json"
    rm -f "$TEST_DIR/.ccc-agent-teams-log.jsonl"
    rm -f "$TEST_DIR/.ccc-state.json"
    rm -f "$TEST_DIR/.ccc-preferences.yaml"
}

run_idle_hook() {
    local input="$1"
    local exit_code=0
    echo "$input" | bash "$IDLE_HOOK" >"$TEST_DIR/stdout.tmp" 2>"$TEST_DIR/stderr.tmp" || exit_code=$?
    echo "$exit_code"
}

run_task_hook() {
    local input="$1"
    local exit_code=0
    echo "$input" | bash "$TASK_HOOK" >"$TEST_DIR/stdout.tmp" 2>"$TEST_DIR/stderr.tmp" || exit_code=$?
    echo "$exit_code"
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
    if echo "$haystack" | grep -qi "$needle"; then
        echo "  PASS: $test_name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $test_name (expected to contain '$needle')"
        FAIL=$((FAIL + 1))
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

# JSON helpers for hook input
make_idle_input() {
    local teammate_name="${1:-worker-1}"
    local team_name="${2:-test-team}"
    jq -n \
        --arg tn "$teammate_name" \
        --arg tm "$team_name" \
        '{
            session_id: "test-session",
            transcript_path: "/tmp/test-transcript.jsonl",
            cwd: "/tmp",
            hook_event_name: "TeammateIdle",
            teammate_name: $tn,
            team_name: $tm
        }'
}

make_task_input() {
    local task_id="${1:-task-001}"
    local task_subject="${2:-Test task}"
    local task_description="${3-Task completed successfully}"
    local teammate_name="${4:-worker-1}"
    local team_name="${5:-test-team}"
    jq -n \
        --arg tid "$task_id" \
        --arg ts "$task_subject" \
        --arg td "$task_description" \
        --arg tn "$teammate_name" \
        --arg tm "$team_name" \
        '{
            session_id: "test-session",
            transcript_path: "/tmp/test-transcript.jsonl",
            cwd: "/tmp",
            hook_event_name: "TaskCompleted",
            task_id: $tid,
            task_subject: $ts,
            task_description: $td,
            teammate_name: $tn,
            team_name: $tm
        }'
}

STATE_FILE="$TEST_DIR/.ccc-agent-teams.json"
LOG_FILE="$TEST_DIR/.ccc-agent-teams-log.jsonl"

# ===================================================================
echo ""
echo "=== Test Suite: TeammateIdle Hook (Idle Gate) ==="
echo ""
# ===================================================================

# --- Test 1: No preferences file — allow idle (default) ---
echo "Test 1: No preferences file allows idle (default)"
reset_state
EXIT_CODE=$(run_idle_hook "$(make_idle_input)")
assert_eq "Exit code 0 (allow idle)" "0" "$EXIT_CODE"

# --- Test 2: idle_gate: allow — explicitly allow ---
echo ""
echo "Test 2: idle_gate=allow explicitly allows idle"
reset_state
cat > "$TEST_DIR/.ccc-preferences.yaml" << 'EOF'
agent_teams:
  idle_gate: allow
EOF
EXIT_CODE=$(run_idle_hook "$(make_idle_input)")
assert_eq "Exit code 0 (allow idle)" "0" "$EXIT_CODE"

# --- Test 3: block_without_tasks, no state file — graceful degradation ---
echo ""
echo "Test 3: block_without_tasks with no state file allows idle"
reset_state
cat > "$TEST_DIR/.ccc-preferences.yaml" << 'EOF'
agent_teams:
  idle_gate: block_without_tasks
EOF
EXIT_CODE=$(run_idle_hook "$(make_idle_input)")
assert_eq "Exit code 0 (graceful degradation)" "0" "$EXIT_CODE"

# --- Test 4: block_without_tasks, pending=0 — allow ---
echo ""
echo "Test 4: block_without_tasks with pending=0 allows idle"
reset_state
cat > "$TEST_DIR/.ccc-preferences.yaml" << 'EOF'
agent_teams:
  idle_gate: block_without_tasks
EOF
jq -n '{team_name: "test-team", pending_tasks: 0, completed_tasks: 2, updatedAt: "2026-02-18T10:00:00Z"}' > "$STATE_FILE"
EXIT_CODE=$(run_idle_hook "$(make_idle_input)")
assert_eq "Exit code 0 (no pending tasks)" "0" "$EXIT_CODE"

# --- Test 5: block_without_tasks, pending=2 — block ---
echo ""
echo "Test 5: block_without_tasks with pending=2 blocks idle"
reset_state
cat > "$TEST_DIR/.ccc-preferences.yaml" << 'EOF'
agent_teams:
  idle_gate: block_without_tasks
EOF
jq -n '{team_name: "test-team", pending_tasks: 2, completed_tasks: 0, updatedAt: "2026-02-18T10:00:00Z"}' > "$STATE_FILE"
EXIT_CODE=$(run_idle_hook "$(make_idle_input)")
assert_eq "Exit code 2 (block idle)" "2" "$EXIT_CODE"

# --- Test 6: Block stderr message contains team info ---
echo ""
echo "Test 6: Block stderr contains team name and 'Pending tasks'"
STDERR=$(cat "$TEST_DIR/stderr.tmp")
assert_contains "Stderr contains 'Pending tasks'" "Pending tasks" "$STDERR"
assert_contains "Stderr contains team name" "test-team" "$STDERR"

# --- Test 7: Different team name in state — no match, allow ---
echo ""
echo "Test 7: State for different team allows idle"
reset_state
cat > "$TEST_DIR/.ccc-preferences.yaml" << 'EOF'
agent_teams:
  idle_gate: block_without_tasks
EOF
jq -n '{team_name: "other-team", pending_tasks: 5, completed_tasks: 0, updatedAt: "2026-02-18T10:00:00Z"}' > "$STATE_FILE"
EXIT_CODE=$(run_idle_hook "$(make_idle_input "worker-1" "test-team")")
assert_eq "Exit code 0 (different team)" "0" "$EXIT_CODE"

# ===================================================================
echo ""
echo "=== Test Suite: TaskCompleted Hook (Completion Gate) ==="
echo ""
# ===================================================================

# --- Test 8: basic gate, clean description — allow ---
echo "Test 8: Clean description passes basic gate"
reset_state
cat > "$TEST_DIR/.ccc-preferences.yaml" << 'EOF'
agent_teams:
  task_gate: basic
EOF
EXIT_CODE=$(run_task_hook "$(make_task_input "task-001" "Implement auth" "Successfully implemented authentication with JWT tokens and session management")")
assert_eq "Exit code 0 (clean description)" "0" "$EXIT_CODE"

# --- Test 9: basic gate, empty description — block ---
echo ""
echo "Test 9: Empty description blocked by basic gate"
reset_state
cat > "$TEST_DIR/.ccc-preferences.yaml" << 'EOF'
agent_teams:
  task_gate: basic
EOF
EXIT_CODE=$(run_task_hook "$(make_task_input "task-002" "Build API" "")")
assert_eq "Exit code 2 (empty description)" "2" "$EXIT_CODE"
STDERR=$(cat "$TEST_DIR/stderr.tmp")
assert_contains "Stderr mentions task subject" "Build API" "$STDERR"

# --- Test 10: basic gate, description with error keyword — block ---
echo ""
echo "Test 10: Description with 'Error:' blocked"
reset_state
cat > "$TEST_DIR/.ccc-preferences.yaml" << 'EOF'
agent_teams:
  task_gate: basic
EOF
EXIT_CODE=$(run_task_hook "$(make_task_input "task-003" "Fix bug" "Error: build failed with exit code 1")")
assert_eq "Exit code 2 (error keyword)" "2" "$EXIT_CODE"

# --- Test 11: basic gate, description with 'failed to' — block ---
echo ""
echo "Test 11: Description with 'failed to' blocked"
reset_state
cat > "$TEST_DIR/.ccc-preferences.yaml" << 'EOF'
agent_teams:
  task_gate: basic
EOF
EXIT_CODE=$(run_task_hook "$(make_task_input "task-004" "Connect DB" "failed to connect to database server")")
assert_eq "Exit code 2 (failed keyword)" "2" "$EXIT_CODE"

# --- Test 12: task_gate: off, empty description — allow ---
echo ""
echo "Test 12: Gate off allows empty description"
reset_state
cat > "$TEST_DIR/.ccc-preferences.yaml" << 'EOF'
agent_teams:
  task_gate: "off"
EOF
EXIT_CODE=$(run_task_hook "$(make_task_input "task-005" "Quick fix" "")")
assert_eq "Exit code 0 (gate off)" "0" "$EXIT_CODE"

# --- Test 13: No preferences, clean description — allow (basic default) ---
echo ""
echo "Test 13: No preferences uses basic default, clean desc passes"
reset_state
EXIT_CODE=$(run_task_hook "$(make_task_input "task-006" "Add feature" "Added the new feature with all edge cases handled")")
assert_eq "Exit code 0 (basic default)" "0" "$EXIT_CODE"

# --- Test 14: State file updated on success ---
echo ""
echo "Test 14: State file updated after successful completion"
reset_state
cat > "$TEST_DIR/.ccc-preferences.yaml" << 'EOF'
agent_teams:
  task_gate: basic
EOF
jq -n '{team_name: "test-team", pending_tasks: 3, completed_tasks: 0, updatedAt: "2026-02-18T10:00:00Z"}' > "$STATE_FILE"
run_task_hook "$(make_task_input "task-007" "First task" "Completed the first task successfully" "worker-1" "test-team")" >/dev/null 2>&1
COMPLETED=$(jq -r '.completed_tasks' "$STATE_FILE" 2>/dev/null) || true
PENDING=$(jq -r '.pending_tasks' "$STATE_FILE" 2>/dev/null) || true
assert_eq "completed_tasks incremented to 1" "1" "$COMPLETED"
assert_eq "pending_tasks decremented to 2" "2" "$PENDING"

# --- Test 15: State write failure doesn't block completion ---
echo ""
echo "Test 15: State write failure still allows completion"
reset_state
cat > "$TEST_DIR/.ccc-preferences.yaml" << 'EOF'
agent_teams:
  task_gate: basic
EOF
# Create a directory where the state file should be — write will fail
mkdir -p "$STATE_FILE" 2>/dev/null || true
EXIT_CODE=$(run_task_hook "$(make_task_input "task-008" "Robust task" "This task completed despite state issues")")
assert_eq "Exit code 0 (state write failure tolerated)" "0" "$EXIT_CODE"
rm -rf "$STATE_FILE"

# --- Test 16: JSONL log written on success ---
echo ""
echo "Test 16: JSONL completion log written on success"
reset_state
cat > "$TEST_DIR/.ccc-preferences.yaml" << 'EOF'
agent_teams:
  task_gate: basic
EOF
jq -n '{linearIssue: "CIA-565"}' > "$TEST_DIR/.ccc-state.json"
run_task_hook "$(make_task_input "task-009" "Logged task" "Task completed and should be logged" "worker-2" "test-team")" >/dev/null 2>&1
assert_file_exists "JSONL log file created" "$LOG_FILE"
LOG_LINES=$(wc -l < "$LOG_FILE" | tr -d ' ')
assert_eq "Log has 1 entry" "1" "$LOG_LINES"
LOG_ISSUE=$(jq -r '.linear_issue' "$LOG_FILE" | head -1 2>/dev/null) || true
assert_eq "Log entry references CIA-565" "CIA-565" "$LOG_ISSUE"

# ===================================================================
echo ""
echo "=== Test Suite: Integration (2-Hook Sequence) ==="
echo ""
# ===================================================================

# --- Test 17: Full 2-hook sequence ---
echo "Test 17: Two-hook interaction through shared state"
reset_state
cat > "$TEST_DIR/.ccc-preferences.yaml" << 'EOF'
agent_teams:
  idle_gate: block_without_tasks
  task_gate: basic
EOF
# Seed state with 2 pending tasks
jq -n '{team_name: "test-team", pending_tasks: 2, completed_tasks: 0, updatedAt: "2026-02-18T10:00:00Z"}' > "$STATE_FILE"

# Step 1: First task completes — state should go to pending=1
run_task_hook "$(make_task_input "task-A" "First task" "Completed first task successfully" "worker-1" "test-team")" >/dev/null 2>&1
PENDING=$(jq -r '.pending_tasks' "$STATE_FILE" 2>/dev/null) || true
assert_eq "After first completion: pending=1" "1" "$PENDING"

# Step 2: Teammate tries to idle — should be blocked (pending=1)
EXIT_CODE=$(run_idle_hook "$(make_idle_input "worker-1" "test-team")")
assert_eq "Idle blocked with pending=1" "2" "$EXIT_CODE"

# Step 3: Second task completes — state should go to pending=0
run_task_hook "$(make_task_input "task-B" "Second task" "Completed second task successfully" "worker-2" "test-team")" >/dev/null 2>&1
PENDING=$(jq -r '.pending_tasks' "$STATE_FILE" 2>/dev/null) || true
assert_eq "After second completion: pending=0" "0" "$PENDING"

# Step 4: Teammate tries to idle — should be allowed (pending=0)
EXIT_CODE=$(run_idle_hook "$(make_idle_input "worker-1" "test-team")")
assert_eq "Idle allowed with pending=0" "0" "$EXIT_CODE"

# ===================================================================
echo ""
echo "==========================================="
echo "  Results: $PASS passed, $FAIL failed ($TOTAL total)"
echo "==========================================="
echo ""

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
