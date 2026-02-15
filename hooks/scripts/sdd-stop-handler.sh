#!/usr/bin/env bash
# SDD Stop Hook Handler — Autonomous Task Execution Engine
#
# This script is the core loop driver for Stage 6 (Implementation) of the
# Spec-Driven Development funnel. It runs as a Claude Code stop hook, reading
# stdin for session metadata (transcript_path) and deciding whether to:
#   - Allow the session to stop (exit 0)
#   - Block and re-enter with a continue prompt (output JSON with decision: block)
#
# The loop advances through decomposed tasks one at a time, giving each new
# session fresh context. It respects the 3 human approval gates, the 5
# execution modes, and per-task/global iteration safety caps.
#
# State file: $PROJECT_ROOT/.sdd-state.json
# Progress file: $PROJECT_ROOT/.sdd-progress.md (persists after completion)
#
# Install: Configure in .claude/settings.json:
#   "hooks": { "Stop": [{ "matcher": "", "hooks": [{ "type": "command",
#     "command": ".claude/hooks/scripts/sdd-stop-handler.sh" }] }] }

set -euo pipefail

# ---------------------------------------------------------------------------
# 0. Prerequisite check — jq must be available
# ---------------------------------------------------------------------------

if ! command -v jq &>/dev/null; then
    # Without jq we cannot parse state. Allow stop gracefully.
    exit 0
fi

# ---------------------------------------------------------------------------
# 1. Read stdin (session metadata from Claude Code)
# ---------------------------------------------------------------------------

INPUT=$(cat)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null) || true

# ---------------------------------------------------------------------------
# 2. Locate project root and state file
# ---------------------------------------------------------------------------

PROJECT_ROOT="${SDD_PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
STATE_FILE="$PROJECT_ROOT/.sdd-state.json"

if [[ ! -f "$STATE_FILE" ]]; then
    # No active SDD session — allow stop.
    exit 0
fi

STATE=$(cat "$STATE_FILE" 2>/dev/null) || exit 0
if [[ -z "$STATE" ]]; then
    exit 0
fi

# ---------------------------------------------------------------------------
# 3. Parse state fields (with safe defaults)
# ---------------------------------------------------------------------------

PHASE=$(echo "$STATE" | jq -r '.phase // empty' 2>/dev/null) || exit 0
TASK_INDEX=$(echo "$STATE" | jq -r '.taskIndex // 0' 2>/dev/null) || exit 0
TOTAL_TASKS=$(echo "$STATE" | jq -r '.totalTasks // 0' 2>/dev/null) || exit 0
TASK_ITER=$(echo "$STATE" | jq -r '.taskIteration // 1' 2>/dev/null) || exit 0
MAX_TASK_ITER=$(echo "$STATE" | jq -r '.maxTaskIterations // 5' 2>/dev/null) || exit 0
GLOBAL_ITER=$(echo "$STATE" | jq -r '.globalIteration // 0' 2>/dev/null) || exit 0
MAX_GLOBAL_ITER=$(echo "$STATE" | jq -r '.maxGlobalIterations // 50' 2>/dev/null) || exit 0
EXEC_MODE=$(echo "$STATE" | jq -r '.executionMode // "quick"' 2>/dev/null) || exit 0
AWAITING_GATE=$(echo "$STATE" | jq -r '.awaitingGate // "null"' 2>/dev/null) || exit 0
LINEAR_ISSUE=$(echo "$STATE" | jq -r '.linearIssue // empty' 2>/dev/null) || exit 0
SPEC_PATH=$(echo "$STATE" | jq -r '.specPath // empty' 2>/dev/null) || exit 0

# Normalise "null" string to empty for gate check
if [[ "$AWAITING_GATE" == "null" ]]; then
    AWAITING_GATE=""
fi

# ---------------------------------------------------------------------------
# 4. Extract last assistant output from transcript (for TASK_COMPLETE signal)
# ---------------------------------------------------------------------------

if [[ -n "$TRANSCRIPT_PATH" ]] && [[ -f "$TRANSCRIPT_PATH" ]]; then
    LAST_OUTPUT=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" 2>/dev/null \
        | tail -1 \
        | jq -r '
            .message.content |
            map(select(.type == "text")) |
            map(.text) |
            join("\n")
        ' 2>/dev/null || echo "")
else
    LAST_OUTPUT=""
fi

# ---------------------------------------------------------------------------
# 5. Gate check — if awaiting a human gate, allow stop immediately
# ---------------------------------------------------------------------------
# Gates:
#   1 = Spec approval needed (Stage 3 exit)
#   2 = Review findings acceptance needed (Stage 4 exit)
#   3 = PR review needed (Stage 6 exit)
#
# When a gate is pending, the human must act. The loop does not continue.

if [[ -n "$AWAITING_GATE" ]]; then
    # Human must review — allow the session to end.
    exit 0
fi

# ---------------------------------------------------------------------------
# 6. Phase check — only the execution phase drives the task loop
# ---------------------------------------------------------------------------
# Phases: intake, spec, review, decompose, execution, verification, closure
# All phases except "execution" allow stop without intervention.

if [[ -z "$PHASE" || "$PHASE" == "null" ]]; then
    exit 0
fi

if [[ "$PHASE" != "execution" ]]; then
    exit 0
fi

# ---------------------------------------------------------------------------
# 7. Execution mode check — pair and swarm do not loop
# ---------------------------------------------------------------------------
# - pair: Human-in-the-loop means no automatic continuation. The human
#   decides when to resume.
# - swarm: Subagent dispatch is handled by the orchestrator, not the stop
#   hook. Each subagent runs independently.

if [[ "$EXEC_MODE" == "pair" ]] || [[ "$EXEC_MODE" == "swarm" ]]; then
    exit 0
fi

# ---------------------------------------------------------------------------
# 8. Global iteration safety cap
# ---------------------------------------------------------------------------

if [[ $GLOBAL_ITER -ge $MAX_GLOBAL_ITER ]]; then
    jq -n --arg reason "Max global iterations ($MAX_GLOBAL_ITER) reached. Halting to prevent runaway execution." \
        '{"decision": "block", "reason": $reason}'
    exit 0
fi

# ---------------------------------------------------------------------------
# 9. Per-task iteration safety cap
# ---------------------------------------------------------------------------

if [[ $TASK_ITER -ge $MAX_TASK_ITER ]]; then
    jq -n \
        --argjson idx "$TASK_INDEX" \
        --argjson max "$MAX_TASK_ITER" \
        --arg reason "Task $TASK_INDEX failed after $MAX_TASK_ITER attempts. Halting — manual intervention required." \
        '{"decision": "block", "reason": $reason}'
    exit 0
fi

# ---------------------------------------------------------------------------
# 10. All tasks completed — clean up state, keep progress file
# ---------------------------------------------------------------------------

if [[ $TASK_INDEX -ge $TOTAL_TASKS ]]; then
    # All tasks done. Remove state file but preserve progress.
    rm -f "$STATE_FILE"
    # .sdd-progress.md is intentionally kept for historical reference.
    exit 0
fi

# ---------------------------------------------------------------------------
# 11. Check for TASK_COMPLETE signal in last assistant output
# ---------------------------------------------------------------------------

if ! echo "$LAST_OUTPUT" | grep -q "TASK_COMPLETE"; then
    # Task did not complete — increment task iteration (retry) and global iter.
    NEW_TASK_ITER=$((TASK_ITER + 1))
    NEW_GLOBAL_ITER=$((GLOBAL_ITER + 1))

    # Atomic state update: write to temp file, then move into place.
    TEMP_STATE=$(mktemp)
    UPDATED=$(echo "$STATE" | jq \
        --argjson ti "$NEW_TASK_ITER" \
        --argjson gi "$NEW_GLOBAL_ITER" \
        '.taskIteration = $ti | .globalIteration = $gi | .lastUpdatedAt = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))' \
        2>/dev/null) || true

    if [[ -n "$UPDATED" ]] && echo "$UPDATED" > "$TEMP_STATE" 2>/dev/null && [[ -s "$TEMP_STATE" ]]; then
        mv "$TEMP_STATE" "$STATE_FILE"
    else
        rm -f "$TEMP_STATE"
        # State update failed — allow stop to avoid corruption.
        exit 0
    fi

    # Build the retry continue prompt.
    REASON="Continue SDD execution for ${LINEAR_ISSUE:-unknown issue}. Mode: ${EXEC_MODE}."
    REASON="$REASON Read .sdd-progress.md for completed task context."
    REASON="$REASON Task $TASK_INDEX did not signal TASK_COMPLETE. Retry attempt $NEW_TASK_ITER of $MAX_TASK_ITER."
    REASON="$REASON Execute task $TASK_INDEX from the decomposed task list."

    if [[ "$EXEC_MODE" == "tdd" ]]; then
        REASON="$REASON Follow red-green-refactor cycle for each acceptance criterion."
    fi

    if [[ "$EXEC_MODE" == "checkpoint" ]]; then
        REASON="$REASON Pause at any checkpoint gates for human review before proceeding."
    fi

    REASON="$REASON Signal TASK_COMPLETE when done."

    jq -n --arg reason "$REASON" '{"decision": "block", "reason": $reason}'
    exit 0
fi

# ---------------------------------------------------------------------------
# 12. TASK_COMPLETE received — advance to next task
# ---------------------------------------------------------------------------

NEW_TASK_INDEX=$((TASK_INDEX + 1))
NEW_GLOBAL_ITER=$((GLOBAL_ITER + 1))

# Atomic state update: advance task index, reset per-task iteration counter.
TEMP_STATE=$(mktemp)
UPDATED=$(echo "$STATE" | jq \
    --argjson ti "$NEW_TASK_INDEX" \
    --argjson gi "$NEW_GLOBAL_ITER" \
    '.taskIndex = $ti | .taskIteration = 1 | .globalIteration = $gi | .lastUpdatedAt = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))' \
    2>/dev/null) || true

if [[ -n "$UPDATED" ]] && echo "$UPDATED" > "$TEMP_STATE" 2>/dev/null && [[ -s "$TEMP_STATE" ]]; then
    mv "$TEMP_STATE" "$STATE_FILE"
else
    rm -f "$TEMP_STATE"
    # State update failed — allow stop to avoid corruption.
    exit 0
fi

# Check if that was the last task.
if [[ $NEW_TASK_INDEX -ge $TOTAL_TASKS ]]; then
    # All tasks now complete. Clean up state, keep progress.
    rm -f "$STATE_FILE"
    exit 0
fi

# ---------------------------------------------------------------------------
# 13. Build continue prompt for the next task
# ---------------------------------------------------------------------------

REASON="Continue SDD execution for ${LINEAR_ISSUE:-unknown issue}. Mode: ${EXEC_MODE}."
REASON="$REASON Read .sdd-progress.md for completed task context."
REASON="$REASON Execute task $NEW_TASK_INDEX of $TOTAL_TASKS from the decomposed task list."

if [[ -n "$SPEC_PATH" ]]; then
    REASON="$REASON Spec: $SPEC_PATH."
fi

if [[ "$EXEC_MODE" == "tdd" ]]; then
    REASON="$REASON Follow red-green-refactor cycle for each acceptance criterion."
fi

if [[ "$EXEC_MODE" == "checkpoint" ]]; then
    REASON="$REASON Pause at any checkpoint gates for human review before proceeding."
fi

REASON="$REASON Signal TASK_COMPLETE when done."

jq -n --arg reason "$REASON" '{"decision": "block", "reason": $reason}'
