#!/usr/bin/env bash
# CCC Hook: Agent Teams — TaskCompleted (Completion Gate)
# Trigger: When a task is being marked as completed via TaskUpdate
# Purpose: Verify task completion is legitimate before allowing it
#
# Checks (when task_gate = basic):
#   1. task_description is non-empty (>10 chars)
#   2. task_description contains no error indicators
#
# On successful completion:
#   - Updates .ccc-agent-teams.json state file (task counter)
#   - Appends a line to .ccc-agent-teams-log.jsonl (Linear audit trail)
#
# Preferences (.ccc-preferences.yaml):
#   agent_teams.task_gate:
#     off   — no verification (always allow)
#     basic — block if description is empty or contains error keywords (default)
#
# Exit codes:
#   0 — Allow task completion
#   2 — Block completion (stderr fed back to model)

set -uo pipefail
# NOTE: Do NOT use set -e in hooks.

# ---------------------------------------------------------------------------
# 0. Prerequisite check
# ---------------------------------------------------------------------------

if ! command -v jq &>/dev/null; then
    exit 0
fi

# ---------------------------------------------------------------------------
# 1. Read stdin (TaskCompleted event from Claude Code)
# ---------------------------------------------------------------------------

HOOK_INPUT=$(cat)

TASK_ID=$(echo "$HOOK_INPUT" | jq -r '.task_id // empty' 2>/dev/null) || true
TASK_SUBJECT=$(echo "$HOOK_INPUT" | jq -r '.task_subject // empty' 2>/dev/null) || true
TASK_DESC=$(echo "$HOOK_INPUT" | jq -r '.task_description // empty' 2>/dev/null) || true
TEAMMATE_NAME=$(echo "$HOOK_INPUT" | jq -r '.teammate_name // empty' 2>/dev/null) || true
TEAM_NAME=$(echo "$HOOK_INPUT" | jq -r '.team_name // empty' 2>/dev/null) || true

# ---------------------------------------------------------------------------
# 2. Locate project root
# ---------------------------------------------------------------------------

PROJECT_ROOT="${CCC_PROJECT_ROOT:-${SDD_PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}}"

# ---------------------------------------------------------------------------
# 3. Load task_gate preference
# ---------------------------------------------------------------------------

TASK_GATE="basic"
PREFS_FILE="$PROJECT_ROOT/.ccc-preferences.yaml"

if command -v yq &>/dev/null && [[ -f "$PREFS_FILE" ]]; then
    _gate=$(yq '.agent_teams.task_gate // "basic"' "$PREFS_FILE" 2>/dev/null) && TASK_GATE="$_gate"
fi

if [[ "$TASK_GATE" == "off" ]]; then
    exit 0
fi

# ---------------------------------------------------------------------------
# 4. Basic heuristic checks
# ---------------------------------------------------------------------------

# Check 1: Description non-empty (>10 chars after trimming whitespace)
TRIMMED_DESC=$(echo "$TASK_DESC" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
if [[ ${#TRIMMED_DESC} -le 10 ]]; then
    echo "[CCC TaskCompleted] Task '${TASK_SUBJECT}' (id: ${TASK_ID}) has no output. Add evidence of completion before marking complete." >&2
    exit 2
fi

# Check 2: No error indicator keywords
if echo "$TASK_DESC" | grep -qiE '(^|[^a-z])(error|failed|exception|traceback|cannot|unable to)([^a-z]|$)'; then
    echo "[CCC TaskCompleted] Task '${TASK_SUBJECT}' (id: ${TASK_ID}) contains error indicators. Resolve errors before marking complete." >&2
    exit 2
fi

# ---------------------------------------------------------------------------
# 5. Execution mode quality validation
# ---------------------------------------------------------------------------

CCC_STATE_FILE="$PROJECT_ROOT/.ccc-state.json"
EXEC_MODE=""

if [[ -f "$CCC_STATE_FILE" ]]; then
    EXEC_MODE=$(jq -r '.executionMode // empty' "$CCC_STATE_FILE" 2>/dev/null) || true
fi

case "$EXEC_MODE" in
    tdd)
        # TDD mode: check that test files were created or modified
        # Scan recent git diff for test/spec file patterns
        if command -v git &>/dev/null; then
            TEST_FILES=$(git diff --cached --name-only 2>/dev/null; git diff --name-only 2>/dev/null) || true
            if [[ -n "$TEST_FILES" ]]; then
                HAS_TESTS=$(echo "$TEST_FILES" | grep -iE '(test|spec)\.' 2>/dev/null) || true
                if [[ -z "$HAS_TESTS" ]]; then
                    # Also check recent commits (last 2) for test files
                    RECENT_TEST_FILES=$(git diff HEAD~2 --name-only 2>/dev/null | grep -iE '(test|spec)\.' 2>/dev/null) || true
                    if [[ -z "$RECENT_TEST_FILES" ]]; then
                        echo "[CCC TaskCompleted] TDD mode requires test files. No *test* or *spec* files found in recent changes. Add tests before marking complete." >&2
                        exit 2
                    fi
                fi
            fi
        fi
        ;;
    pair)
        # Pair mode: check that both implementation and review artifacts exist
        # Look for review comments or co-authored commits as evidence
        if command -v git &>/dev/null; then
            CHANGED_FILES=$(git diff --cached --name-only 2>/dev/null; git diff --name-only 2>/dev/null) || true
            if [[ -n "$CHANGED_FILES" ]]; then
                # Check for review artifacts: .ccc-progress.md should have review notes,
                # or recent commits should have Co-Authored-By
                REVIEW_EVIDENCE=$(git log -3 --format="%b" 2>/dev/null | grep -iE '(co-authored|reviewed|review)' 2>/dev/null) || true
                PROGRESS_REVIEW=$(grep -iE '(review|pair)' "$PROJECT_ROOT/.ccc-progress.md" 2>/dev/null) || true
                if [[ -z "$REVIEW_EVIDENCE" ]] && [[ -z "$PROGRESS_REVIEW" ]]; then
                    echo "[CCC TaskCompleted] Pair mode expects review artifacts. Add review notes to .ccc-progress.md or include review evidence in commits." >&2
                    exit 2
                fi
            fi
        fi
        ;;
    quick|checkpoint|swarm|"")
        # quick mode: any non-error completion is sufficient (already handled by basic checks)
        # checkpoint/swarm/empty: no additional validation
        ;;
esac

# ---------------------------------------------------------------------------
# 6. Update state file (best-effort, non-blocking)
# ---------------------------------------------------------------------------

STATE_FILE="$PROJECT_ROOT/.ccc-agent-teams.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if [[ -f "$STATE_FILE" ]] && [[ ! -d "$STATE_FILE" ]]; then
    TEMP=$(mktemp 2>/dev/null) || true
    if [[ -n "${TEMP:-}" ]]; then
        UPDATED=$(jq \
            --arg tn "$TEAMMATE_NAME" \
            --arg ts "$TIMESTAMP" \
            '.completed_tasks = ((.completed_tasks // 0) + 1)
             | .pending_tasks = ([(.pending_tasks // 0) - 1, 0] | max)
             | .last_completed_by = $tn
             | .updatedAt = $ts' \
            "$STATE_FILE" 2>/dev/null) || true
        if [[ -n "${UPDATED:-}" ]]; then
            echo "$UPDATED" > "$TEMP" && mv "$TEMP" "$STATE_FILE"
        else
            rm -f "$TEMP"
        fi
    fi
fi

# ---------------------------------------------------------------------------
# 6. Append to completion log (best-effort, non-blocking)
# ---------------------------------------------------------------------------

LOG_FILE="$PROJECT_ROOT/.ccc-agent-teams-log.jsonl"

# Read linear issue from .ccc-state.json if available
LINEAR_ISSUE=""
CCC_STATE_FILE="$PROJECT_ROOT/.ccc-state.json"
if [[ -f "$CCC_STATE_FILE" ]]; then
    LINEAR_ISSUE=$(jq -r '.linearIssue // empty' "$CCC_STATE_FILE" 2>/dev/null) || true
fi

jq -cn \
    --arg tid "$TASK_ID" \
    --arg ts "$TASK_SUBJECT" \
    --arg tn "$TEAMMATE_NAME" \
    --arg tm "$TIMESTAMP" \
    --arg li "$LINEAR_ISSUE" \
    '{task_id: $tid, task_subject: $ts, teammate: $tn, timestamp: $tm, linear_issue: $li}' \
    >> "$LOG_FILE" 2>/dev/null || true

exit 0
