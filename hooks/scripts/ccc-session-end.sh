#!/usr/bin/env bash
# CCC Hook: Session End — SessionEnd event
# Trigger: Explicit session termination (clear, logout, exit)
# Purpose: Generate session summary, archive progress, fire analytics
#
# Distinct from Stop: Stop fires on mid-session agent stops (execution loop
# pauses, task boundaries). SessionEnd fires only on actual session termination.
#
# Output format (SessionEnd):
#   stdout JSON with hookSpecificOutput.additionalContext = session summary
#
# Exit codes:
#   0 — Always (fail-open)

set -uo pipefail
# NOTE: Do NOT use set -e in hooks. Non-zero exit = hook failure in Claude Code.

# ---------------------------------------------------------------------------
# 0. Prerequisite check
# ---------------------------------------------------------------------------

if ! command -v jq &>/dev/null; then
    exit 0
fi

# ---------------------------------------------------------------------------
# 1. Read stdin (session end details from Claude Code)
# ---------------------------------------------------------------------------

HOOK_INPUT=$(cat)

REASON=$(echo "$HOOK_INPUT" | jq -r '.reason // "unknown"' 2>/dev/null) || true

# ---------------------------------------------------------------------------
# 2. Locate project root and state files
# ---------------------------------------------------------------------------

PROJECT_ROOT="${CCC_PROJECT_ROOT:-${SDD_PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}}"
STATE_FILE="$PROJECT_ROOT/.ccc-state.json"
PROGRESS_FILE="$PROJECT_ROOT/.ccc-progress.md"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TIMESTAMP_SLUG=$(date -u +"%Y%m%d-%H%M%S")

# ---------------------------------------------------------------------------
# 3. Read current task state
# ---------------------------------------------------------------------------

SUMMARY_PARTS=()
SUMMARY_PARTS+=("[CCC] Session ended (reason: $REASON) at $TIMESTAMP")

if [[ -f "$STATE_FILE" ]]; then
    STATE=$(cat "$STATE_FILE" 2>/dev/null) || true
    LINEAR_ISSUE=$(echo "$STATE" | jq -r '.linearIssue // "none"' 2>/dev/null) || true
    PHASE=$(echo "$STATE" | jq -r '.phase // "unknown"' 2>/dev/null) || true
    TASK_INDEX=$(echo "$STATE" | jq -r '.taskIndex // 0' 2>/dev/null) || true
    TOTAL_TASKS=$(echo "$STATE" | jq -r '.totalTasks // 0' 2>/dev/null) || true
    EXEC_MODE=$(echo "$STATE" | jq -r '.executionMode // "unknown"' 2>/dev/null) || true

    SUMMARY_PARTS+=("Issue: $LINEAR_ISSUE | Phase: $PHASE | Task: $TASK_INDEX/$TOTAL_TASKS | Mode: $EXEC_MODE")
else
    SUMMARY_PARTS+=("No active task state (.ccc-state.json not found)")
fi

# ---------------------------------------------------------------------------
# 4. Collect git summary
# ---------------------------------------------------------------------------

BRANCH=$(git branch --show-current 2>/dev/null) || BRANCH="unknown"
UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ') || UNCOMMITTED="?"
UNPUSHED=$(git log --oneline '@{upstream}..HEAD' 2>/dev/null | wc -l | tr -d ' ') || UNPUSHED="?"

SUMMARY_PARTS+=("Branch: $BRANCH | Uncommitted: $UNCOMMITTED | Unpushed: $UNPUSHED")

# ---------------------------------------------------------------------------
# 5. Collect files changed during session (from today's evidence log)
# ---------------------------------------------------------------------------

LOG_DIR="${SDD_LOG_DIR:-$PROJECT_ROOT/.claude/logs}"
TODAY=$(date +"%Y%m%d")
EVIDENCE_LOG="$LOG_DIR/tool-log-$TODAY.jsonl"

FILES_CHANGED="none"
if [[ -f "$EVIDENCE_LOG" ]]; then
    FILES_CHANGED=$(jq -r '.file_path // empty' "$EVIDENCE_LOG" 2>/dev/null | sort -u | head -20 | paste -sd ', ' -) || true
    if [[ -z "$FILES_CHANGED" ]]; then
        FILES_CHANGED="none"
    fi
fi

SUMMARY_PARTS+=("Files changed today: $FILES_CHANGED")

# ---------------------------------------------------------------------------
# 6. Fire PostHog session_ended event (if capture script exists)
# ---------------------------------------------------------------------------

POSTHOG_SCRIPT="$PROJECT_ROOT/scripts/posthog-capture.sh"
if [[ -x "$POSTHOG_SCRIPT" ]]; then
    "$POSTHOG_SCRIPT" "session_ended" \
        "{\"reason\":\"$REASON\",\"branch\":\"$BRANCH\",\"uncommitted\":$UNCOMMITTED,\"unpushed\":$UNPUSHED}" \
        2>/dev/null || true
fi

# Also check plugin-local scripts directory
PLUGIN_POSTHOG="${CLAUDE_PLUGIN_ROOT:-}/scripts/posthog-capture.sh"
if [[ -x "$PLUGIN_POSTHOG" ]] && [[ "$PLUGIN_POSTHOG" != "$POSTHOG_SCRIPT" ]]; then
    "$PLUGIN_POSTHOG" "session_ended" \
        "{\"reason\":\"$REASON\",\"branch\":\"$BRANCH\",\"uncommitted\":$UNCOMMITTED,\"unpushed\":$UNPUSHED}" \
        2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# 7. Archive .ccc-progress.md
# ---------------------------------------------------------------------------

if [[ -f "$PROGRESS_FILE" ]]; then
    ARCHIVE_FILE="$PROJECT_ROOT/.ccc-progress-$TIMESTAMP_SLUG.md"
    cp "$PROGRESS_FILE" "$ARCHIVE_FILE" 2>/dev/null || true
    SUMMARY_PARTS+=("Progress archived to: .ccc-progress-$TIMESTAMP_SLUG.md")
fi

# ---------------------------------------------------------------------------
# 8. Output session summary as additionalContext
# ---------------------------------------------------------------------------

SESSION_SUMMARY=$(printf '%s\n' "${SUMMARY_PARTS[@]}")

jq -n \
    --arg summary "$SESSION_SUMMARY" \
    '{
        hookSpecificOutput: {
            additionalContext: $summary
        }
    }'

exit 0
