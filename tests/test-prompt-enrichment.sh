#!/usr/bin/env bash
# Prompt Enrichment Hook Tests — CIA-556
#
# Tests for hooks/scripts/prompt-enrichment.sh (UserPromptSubmit hook)
#
# Run: bash tests/test-prompt-enrichment.sh
# Requires: jq, git

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK="$PLUGIN_ROOT/hooks/scripts/prompt-enrichment.sh"

# Test workspace — isolated from real project
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

PASS=0
FAIL=0
TOTAL=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

reset_state() {
    rm -f "$TEST_DIR/.ccc-preferences.yaml"
    # .git could be a file or directory from previous test — remove both ways
    rm -rf "$TEST_DIR/.git" 2>/dev/null || true
    # Re-create as worktree by default (file, not directory)
    echo "gitdir: /tmp/fake-main-repo/.git/worktrees/test-wt" > "$TEST_DIR/.git"
}

reset_state_non_worktree() {
    rm -f "$TEST_DIR/.ccc-preferences.yaml"
    # .git could be a file or directory from previous test — remove both ways
    rm -rf "$TEST_DIR/.git" 2>/dev/null || true
    # Create as normal repo (.git is a directory)
    mkdir -p "$TEST_DIR/.git"
}

run_hook() {
    local input="$1"
    local branch="${2:-}"
    local exit_code=0
    # Export env vars so the hook subprocess receives them
    export CCC_PROJECT_ROOT="$TEST_DIR"
    export CCC_TEST_BRANCH="$branch"
    export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
    echo "$input" | bash "$HOOK" >"$TEST_DIR/stdout.tmp" 2>"$TEST_DIR/stderr.tmp" || exit_code=$?
    echo "$exit_code"
}

make_prompt_input() {
    local prompt="${1:-implement the feature}"
    jq -n \
        --arg p "$prompt" \
        '{
            session_id: "test-session",
            transcript_path: "/tmp/test-transcript.jsonl",
            cwd: "/tmp",
            hook_event_name: "UserPromptSubmit",
            prompt: $p
        }'
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

assert_not_contains() {
    local test_name="$1"
    local needle="$2"
    local haystack="$3"
    TOTAL=$((TOTAL + 1))
    if echo "$haystack" | grep -qi "$needle"; then
        echo "  FAIL: $test_name (should NOT contain '$needle')"
        FAIL=$((FAIL + 1))
    else
        echo "  PASS: $test_name"
        PASS=$((PASS + 1))
    fi
}

assert_valid_json() {
    local test_name="$1"
    local content="$2"
    TOTAL=$((TOTAL + 1))
    if echo "$content" | jq . >/dev/null 2>&1; then
        echo "  PASS: $test_name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $test_name (not valid JSON)"
        FAIL=$((FAIL + 1))
    fi
}

# ===================================================================
echo ""
echo "=== Test Suite: Prompt Enrichment Hook (UserPromptSubmit) ==="
echo ""
# ===================================================================

# --- Test 1: Worktree with CIA branch — outputs enrichment context ---
echo "Test 1: Worktree with CIA branch outputs enrichment context"
reset_state
EXIT_CODE=$(run_hook "$(make_prompt_input)" "feat/cia-556-prompt-enrichment-hook")
STDOUT=$(cat "$TEST_DIR/stdout.tmp")
assert_eq "Exit code 0" "0" "$EXIT_CODE"
assert_valid_json "Output is valid JSON" "$STDOUT"
ADDITIONAL_CONTEXT=$(echo "$STDOUT" | jq -r '.hookSpecificOutput.additionalContext // empty')
assert_contains "Context contains CIA-556" "CIA-556" "$ADDITIONAL_CONTEXT"
assert_contains "Context mentions worktree" "worktree" "$ADDITIONAL_CONTEXT"

# --- Test 2: Not a worktree (.git is directory) — no output ---
echo ""
echo "Test 2: Non-worktree session produces no output"
reset_state_non_worktree
EXIT_CODE=$(run_hook "$(make_prompt_input)" "feat/cia-556-prompt-enrichment-hook")
STDOUT=$(cat "$TEST_DIR/stdout.tmp")
assert_eq "Exit code 0" "0" "$EXIT_CODE"
assert_eq "No stdout output" "" "$STDOUT"

# --- Test 3: Worktree but no CIA in branch name — no output ---
echo ""
echo "Test 3: Worktree without CIA in branch name produces no output"
reset_state
EXIT_CODE=$(run_hook "$(make_prompt_input)" "feature/add-dark-mode")
STDOUT=$(cat "$TEST_DIR/stdout.tmp")
assert_eq "Exit code 0" "0" "$EXIT_CODE"
assert_eq "No stdout output" "" "$STDOUT"

# --- Test 4: Case-insensitive CIA extraction (lowercase cia-) ---
echo ""
echo "Test 4: Case-insensitive CIA extraction (lowercase)"
reset_state
EXIT_CODE=$(run_hook "$(make_prompt_input)" "fix/cia-123-bug-fix")
STDOUT=$(cat "$TEST_DIR/stdout.tmp")
assert_eq "Exit code 0" "0" "$EXIT_CODE"
assert_valid_json "Output is valid JSON" "$STDOUT"
ADDITIONAL_CONTEXT=$(echo "$STDOUT" | jq -r '.hookSpecificOutput.additionalContext // empty')
assert_contains "Context contains CIA-123" "CIA-123" "$ADDITIONAL_CONTEXT"

# --- Test 5: Case-insensitive CIA extraction (uppercase CIA-) ---
echo ""
echo "Test 5: Case-insensitive CIA extraction (uppercase)"
reset_state
EXIT_CODE=$(run_hook "$(make_prompt_input)" "feat/CIA-789-new-feature")
STDOUT=$(cat "$TEST_DIR/stdout.tmp")
assert_eq "Exit code 0" "0" "$EXIT_CODE"
assert_valid_json "Output is valid JSON" "$STDOUT"
ADDITIONAL_CONTEXT=$(echo "$STDOUT" | jq -r '.hookSpecificOutput.additionalContext // empty')
assert_contains "Context contains CIA-789" "CIA-789" "$ADDITIONAL_CONTEXT"

# --- Test 6: Disabled via preferences ---
echo ""
echo "Test 6: Hook disabled via .ccc-preferences.yaml"
reset_state
cat > "$TEST_DIR/.ccc-preferences.yaml" << 'EOF'
prompt_enrichment:
  enabled: false
EOF
EXIT_CODE=$(run_hook "$(make_prompt_input)" "feat/cia-556-prompt-enrichment-hook")
STDOUT=$(cat "$TEST_DIR/stdout.tmp")
assert_eq "Exit code 0" "0" "$EXIT_CODE"
assert_eq "No stdout when disabled" "" "$STDOUT"

# --- Test 7: Explicitly enabled via preferences ---
echo ""
echo "Test 7: Hook explicitly enabled via preferences"
reset_state
cat > "$TEST_DIR/.ccc-preferences.yaml" << 'EOF'
prompt_enrichment:
  enabled: true
EOF
EXIT_CODE=$(run_hook "$(make_prompt_input)" "feat/cia-400-some-work")
STDOUT=$(cat "$TEST_DIR/stdout.tmp")
assert_eq "Exit code 0" "0" "$EXIT_CODE"
assert_valid_json "Output is valid JSON" "$STDOUT"
ADDITIONAL_CONTEXT=$(echo "$STDOUT" | jq -r '.hookSpecificOutput.additionalContext // empty')
assert_contains "Context contains CIA-400" "CIA-400" "$ADDITIONAL_CONTEXT"

# --- Test 8: Enrichment level minimal ---
echo ""
echo "Test 8: Enrichment level 'minimal' includes issue reference only"
reset_state
cat > "$TEST_DIR/.ccc-preferences.yaml" << 'EOF'
prompt_enrichment:
  enabled: true
  level: minimal
EOF
EXIT_CODE=$(run_hook "$(make_prompt_input)" "feat/cia-300-minimal-test")
STDOUT=$(cat "$TEST_DIR/stdout.tmp")
assert_eq "Exit code 0" "0" "$EXIT_CODE"
assert_valid_json "Output is valid JSON" "$STDOUT"
ADDITIONAL_CONTEXT=$(echo "$STDOUT" | jq -r '.hookSpecificOutput.additionalContext // empty')
assert_contains "Context contains CIA-300" "CIA-300" "$ADDITIONAL_CONTEXT"
assert_not_contains "Minimal does not contain commit conventions" "commit convention" "$ADDITIONAL_CONTEXT"

# --- Test 9: Enrichment level full ---
echo ""
echo "Test 9: Enrichment level 'full' includes issue ref and commit conventions"
reset_state
cat > "$TEST_DIR/.ccc-preferences.yaml" << 'EOF'
prompt_enrichment:
  enabled: true
  level: full
EOF
EXIT_CODE=$(run_hook "$(make_prompt_input)" "feat/cia-301-full-test")
STDOUT=$(cat "$TEST_DIR/stdout.tmp")
assert_eq "Exit code 0" "0" "$EXIT_CODE"
assert_valid_json "Output is valid JSON" "$STDOUT"
ADDITIONAL_CONTEXT=$(echo "$STDOUT" | jq -r '.hookSpecificOutput.additionalContext // empty')
assert_contains "Full context contains CIA-301" "CIA-301" "$ADDITIONAL_CONTEXT"
assert_contains "Full context contains commit conventions" "commit" "$ADDITIONAL_CONTEXT"

# --- Test 10: Default enrichment level (standard) ---
echo ""
echo "Test 10: Default enrichment level is 'standard'"
reset_state
# No preferences file — defaults should apply
EXIT_CODE=$(run_hook "$(make_prompt_input)" "feat/cia-555-default-level")
STDOUT=$(cat "$TEST_DIR/stdout.tmp")
assert_eq "Exit code 0" "0" "$EXIT_CODE"
assert_valid_json "Output is valid JSON" "$STDOUT"
ADDITIONAL_CONTEXT=$(echo "$STDOUT" | jq -r '.hookSpecificOutput.additionalContext // empty')
assert_contains "Default includes CIA ref" "CIA-555" "$ADDITIONAL_CONTEXT"
assert_contains "Default includes branch name" "feat/cia-555-default-level" "$ADDITIONAL_CONTEXT"

# --- Test 11: Multiple CIA refs in branch — extracts first ---
echo ""
echo "Test 11: Multiple CIA refs in branch extracts first"
reset_state
EXIT_CODE=$(run_hook "$(make_prompt_input)" "feat/cia-100-and-cia-200")
STDOUT=$(cat "$TEST_DIR/stdout.tmp")
assert_eq "Exit code 0" "0" "$EXIT_CODE"
assert_valid_json "Output is valid JSON" "$STDOUT"
ADDITIONAL_CONTEXT=$(echo "$STDOUT" | jq -r '.hookSpecificOutput.additionalContext // empty')
assert_contains "Extracts CIA-100 (first)" "CIA-100" "$ADDITIONAL_CONTEXT"

# --- Test 12: No jq available — graceful degradation ---
echo ""
echo "Test 12: Missing jq degrades gracefully"
reset_state
# Create a temporary directory with a fake PATH that has bash but not jq
FAKE_BIN=$(mktemp -d)
ln -s "$(which bash)" "$FAKE_BIN/bash"
# Add coreutils needed by the hook (cat, echo, head, tr, grep)
for cmd in cat echo head tr grep; do
    _path=$(which "$cmd" 2>/dev/null) && ln -s "$_path" "$FAKE_BIN/$cmd" 2>/dev/null || true
done
EXIT_CODE=$(env CCC_PROJECT_ROOT="$TEST_DIR" \
    CCC_TEST_BRANCH="feat/cia-556-test" \
    CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" \
    PATH="$FAKE_BIN" \
    bash -c 'echo "{}" | bash "'"$HOOK"'"' >"$TEST_DIR/stdout.tmp" 2>"$TEST_DIR/stderr.tmp"; echo $?)
STDOUT=$(cat "$TEST_DIR/stdout.tmp")
rm -rf "$FAKE_BIN"
assert_eq "Exit code 0 when jq missing" "0" "$EXIT_CODE"
assert_eq "No output when jq missing" "" "$STDOUT"

# --- Test 13: hookEventName is UserPromptSubmit ---
echo ""
echo "Test 13: hookEventName is UserPromptSubmit"
reset_state
EXIT_CODE=$(run_hook "$(make_prompt_input)" "feat/cia-999-event-name")
STDOUT=$(cat "$TEST_DIR/stdout.tmp")
assert_eq "Exit code 0" "0" "$EXIT_CODE"
HOOK_EVENT=$(echo "$STDOUT" | jq -r '.hookSpecificOutput.hookEventName // empty')
assert_eq "hookEventName is UserPromptSubmit" "UserPromptSubmit" "$HOOK_EVENT"

# --- Test 14: Empty branch name — no output ---
echo ""
echo "Test 14: Empty branch name produces no output"
reset_state
EXIT_CODE=$(run_hook "$(make_prompt_input)" "")
STDOUT=$(cat "$TEST_DIR/stdout.tmp")
assert_eq "Exit code 0" "0" "$EXIT_CODE"
assert_eq "No stdout for empty branch" "" "$STDOUT"

# ===================================================================
echo ""
echo "==========================================="
echo "  Results: $PASS passed, $FAIL failed ($TOTAL total)"
echo "==========================================="
echo ""

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
