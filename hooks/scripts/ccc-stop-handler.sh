#!/usr/bin/env bash
# CCC Stop Hook Handler — Autonomous Task Execution Engine
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
# State file: $PROJECT_ROOT/.ccc-state.json
# Progress file: $PROJECT_ROOT/.ccc-progress.md (persists after completion)
#
# Install: Configure in .claude/settings.json:
#   "hooks": { "Stop": [{ "matcher": "", "hooks": [{ "type": "command",
#     "command": ".claude/hooks/scripts/ccc-stop-handler.sh" }] }] }

set -uo pipefail
# NOTE: Do NOT use set -e in hooks. Non-zero exit = hook failure in Claude Code.

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

PROJECT_ROOT="${CCC_PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
STATE_FILE="$PROJECT_ROOT/.ccc-state.json"

if [[ ! -f "$STATE_FILE" ]]; then
    # No active CCC session — allow stop.
    exit 0
fi

STATE=$(cat "$STATE_FILE" 2>/dev/null) || exit 0
if [[ -z "$STATE" ]]; then
    exit 0
fi

# ---------------------------------------------------------------------------
# 2.5. Load preferences from .ccc-preferences.yaml (via yq)
# ---------------------------------------------------------------------------
# All preferences have safe defaults. If yq is missing or the file does not
# exist, every preference variable is set to its default value.
#
# Requires: yq (https://github.com/mikefarah/yq) — install with:
#   brew install yq
#
# Preference file: $PROJECT_ROOT/.ccc-preferences.yaml
# Schema reference: examples/sample-preferences.yaml

PREFS_FILE="$PROJECT_ROOT/.ccc-preferences.yaml"

# --- Set all defaults first ---
# NOTE: Gate preferences (spec_approval, review_acceptance, pr_review) are NOT
# loaded here. Gate behavior is driven solely by .awaitingGate in the state file
# (Section 5). The /go command handles gate skipping via its own preference read.
PREF_MAX_TASK_ITER=""          # empty = use state file value
PREF_MAX_GLOBAL_ITER=""        # empty = use state file value
PREF_DEFAULT_MODE=""           # empty = use state file value
PREF_SUBAGENT="true"
PREF_SEARCH="true"
PREF_AGENTS_FILE="true"
PREF_REPLAN="true"
MAX_REPLANS=2
# Planning enrichments
PREF_ALWAYS_RECOMMEND="true"
PREF_PRIORITIZATION_FW="none"
# Eval enrichments
PREF_EVAL_ANALYZE_FIRST="true"
PREF_EVAL_COST_PROFILE="budget"
PREF_EVAL_MAX_BUDGET="10"
# Session economics
PREF_CONTEXT_BUDGET_PCT=50
PREF_CHECKPOINT_PCT=70
# Style — per-role explanation depth
PREF_STYLE_BASE="balanced"
PREF_STYLE_SCAN=""
PREF_STYLE_REVIEW=""

# --- Attempt to load from file via yq ---
# NOTE: yq's // (alternative) operator treats boolean false as falsy, so we
# cannot use `yq '.path // "default"'` for boolean prefs — it would ignore
# explicit `false` values. Instead, read the raw value and default in bash
# only when yq outputs "null" (path missing).
_yq_bool() {
    # Usage: _yq_bool '.path' 'default' file
    local val
    val=$(yq "$1" "$3" 2>/dev/null) || val="null"
    if [[ "$val" == "null" ]]; then echo "$2"; else echo "$val"; fi
}
_yq_str() {
    # Usage: _yq_str '.path' 'default' file — same but for strings
    local val
    val=$(yq "$1" "$3" 2>/dev/null) || val="null"
    if [[ "$val" == "null" || -z "$val" ]]; then echo "$2"; else echo "$val"; fi
}

if command -v yq &>/dev/null && [[ -f "$PREFS_FILE" ]]; then
    # Execution overrides (only apply if non-null/non-empty)
    _mti=$(_yq_str '.execution.max_task_iterations' "" "$PREFS_FILE") && [[ -n "$_mti" ]] && PREF_MAX_TASK_ITER="$_mti"
    _mgi=$(_yq_str '.execution.max_global_iterations' "" "$PREFS_FILE") && [[ -n "$_mgi" ]] && PREF_MAX_GLOBAL_ITER="$_mgi"
    _dm=$(_yq_str '.execution.default_mode' "" "$PREFS_FILE") && [[ -n "$_dm" ]] && PREF_DEFAULT_MODE="$_dm"

    # Prompt enrichments (boolean)
    PREF_SUBAGENT=$(_yq_bool '.prompts.subagent_discipline' "true" "$PREFS_FILE")
    PREF_SEARCH=$(_yq_bool '.prompts.search_before_build' "true" "$PREFS_FILE")
    PREF_AGENTS_FILE=$(_yq_bool '.prompts.agents_file' "true" "$PREFS_FILE")

    # Replan (boolean + numeric)
    PREF_REPLAN=$(_yq_bool '.replan.enabled' "true" "$PREFS_FILE")
    MAX_REPLANS=$(_yq_str '.replan.max_replans_per_session' "2" "$PREFS_FILE")

    # Planning
    PREF_ALWAYS_RECOMMEND=$(_yq_bool '.planning.always_recommend' "true" "$PREFS_FILE")
    PREF_PRIORITIZATION_FW=$(_yq_str '.planning.prioritization_framework' "none" "$PREFS_FILE")

    # Eval
    PREF_EVAL_ANALYZE_FIRST=$(_yq_bool '.eval.analyze_before_execute' "true" "$PREFS_FILE")
    PREF_EVAL_COST_PROFILE=$(_yq_str '.eval.cost_profile' "budget" "$PREFS_FILE")
    PREF_EVAL_MAX_BUDGET=$(_yq_str '.eval.max_budget_usd' "10" "$PREFS_FILE")

    # Session economics
    PREF_CONTEXT_BUDGET_PCT=$(_yq_str '.session.context_budget_pct' "50" "$PREFS_FILE")
    PREF_CHECKPOINT_PCT=$(_yq_str '.session.checkpoint_pct' "70" "$PREFS_FILE")

    # Style — base and per-role overrides for advisory output
    PREF_STYLE_BASE=$(_yq_str '.style.explanatory' "balanced" "$PREFS_FILE")
    PREF_STYLE_SCAN=$(_yq_str '.style.explanatory_by_role.scan' "" "$PREFS_FILE")
    PREF_STYLE_REVIEW=$(_yq_str '.style.explanatory_by_role.review' "" "$PREFS_FILE")
fi

# --- Apply execution overrides to state-derived caps ---
# These override the values parsed from state in Section 3, so we store them
# and apply after Section 3 parsing.

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
REPLAN_COUNT=$(echo "$STATE" | jq -r '.replanCount // 0' 2>/dev/null) || exit 0

# Normalise "null" string to empty for gate check
if [[ "$AWAITING_GATE" == "null" ]]; then
    AWAITING_GATE=""
fi

# --- Apply preference overrides to state-derived caps ---
[[ -n "$PREF_MAX_TASK_ITER" ]] && MAX_TASK_ITER="$PREF_MAX_TASK_ITER"
[[ -n "$PREF_MAX_GLOBAL_ITER" ]] && MAX_GLOBAL_ITER="$PREF_MAX_GLOBAL_ITER"
[[ -n "$PREF_DEFAULT_MODE" ]] && EXEC_MODE="$PREF_DEFAULT_MODE"

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
    # .ccc-progress.md is intentionally kept for historical reference.
    exit 0
fi

# ---------------------------------------------------------------------------
# 10.5. Check for REPLAN signal (before TASK_COMPLETE)
# ---------------------------------------------------------------------------
# The agent signals REPLAN when 2+ remaining tasks are invalid, an existing
# solution was discovered, or an unseen dependency emerged. This triggers
# mid-execution replanning: re-read spec + progress, regenerate remaining tasks.
#
# Checked BEFORE TASK_COMPLETE because a session that signals REPLAN should
# not also be treated as a task completion.

if echo "$LAST_OUTPUT" | grep -q "REPLAN"; then
    if [[ "$PREF_REPLAN" != "true" ]]; then
        # Replan disabled in preferences — treat as incomplete task (fall through to Section 11)
        :
    elif [[ $REPLAN_COUNT -ge $MAX_REPLANS ]]; then
        # Max replans reached — halt the loop
        jq -n --argjson count "$REPLAN_COUNT" --argjson max "$MAX_REPLANS" \
            --arg reason "Max replans ($MAX_REPLANS) reached after $REPLAN_COUNT replans. Halting — review .ccc-progress.md and adjust tasks manually." \
            '{"decision": "block", "reason": $reason}'
        exit 0
    else
        # Replan allowed — update state and block with planning prompt
        NEW_REPLAN_COUNT=$((REPLAN_COUNT + 1))
        NEW_GLOBAL_ITER=$((GLOBAL_ITER + 1))

        TEMP_STATE=$(mktemp)
        UPDATED=$(echo "$STATE" | jq \
            --argjson rc "$NEW_REPLAN_COUNT" \
            --argjson gi "$NEW_GLOBAL_ITER" \
            '.replanCount = $rc | .phase = "replan" | .globalIteration = $gi | .lastUpdatedAt = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))' \
            2>/dev/null) || true

        if [[ -n "$UPDATED" ]] && echo "$UPDATED" > "$TEMP_STATE" 2>/dev/null && [[ -s "$TEMP_STATE" ]]; then
            mv "$TEMP_STATE" "$STATE_FILE"
        else
            rm -f "$TEMP_STATE"
            exit 0
        fi

        REASON="REPLAN triggered for ${LINEAR_ISSUE:-unknown issue} (replan $NEW_REPLAN_COUNT of $MAX_REPLANS)."
        REASON="$REASON Read the spec${SPEC_PATH:+ at $SPEC_PATH} and .ccc-progress.md."
        REASON="$REASON Compare completed work against ALL acceptance criteria."
        REASON="$REASON Regenerate remaining tasks based on what actually exists in the codebase."
        REASON="$REASON Update .ccc-state.json: set phase back to execution, update totalTasks and taskIndex."
        REASON="$REASON Then continue executing from the first new task. Signal TASK_COMPLETE when done."

        jq -n --arg reason "$REASON" '{"decision": "block", "reason": $reason}'
        exit 0
    fi
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
    REASON="Continue CCC execution for ${LINEAR_ISSUE:-unknown issue}. Mode: ${EXEC_MODE}."
    REASON="$REASON Read .ccc-progress.md for completed task context."
    REASON="$REASON Task $TASK_INDEX did not signal TASK_COMPLETE. Retry attempt $NEW_TASK_ITER of $MAX_TASK_ITER."
    REASON="$REASON Execute task $TASK_INDEX from the decomposed task list."

    if [[ "$EXEC_MODE" == "tdd" ]]; then
        REASON="$REASON Follow red-green-refactor cycle for each acceptance criterion."
    fi

    if [[ "$EXEC_MODE" == "checkpoint" ]]; then
        REASON="$REASON Pause at any checkpoint gates for human review before proceeding."
    fi

    # Prompt enrichments (configurable via .ccc-preferences.yaml)
    [[ "$PREF_SUBAGENT" == "true" ]] && REASON="$REASON Use parallel subagents for codebase reads; single subagent for build/test."
    [[ "$PREF_SEARCH" == "true" ]] && REASON="$REASON Before implementing, search the codebase for existing solutions. Don't assume functionality is missing."
    [[ "$PREF_AGENTS_FILE" == "true" ]] && [[ -f "$PROJECT_ROOT/.ccc-agents.md" ]] && REASON="$REASON Read .ccc-agents.md for project-specific build commands and codebase patterns."
    [[ "$PREF_ALWAYS_RECOMMEND" == "true" ]] && REASON="$REASON When presenting options, always highlight your recommended choice."
    # Prioritization framework enrichment
    case "$PREF_PRIORITIZATION_FW" in
        rice)      REASON="$REASON Use RICE (Reach, Impact, Confidence, Effort) as a reasoning lens when prioritizing tasks." ;;
        moscow)    REASON="$REASON Use MoSCoW (Must, Should, Could, Won't) as a reasoning lens when prioritizing tasks." ;;
        eisenhower) REASON="$REASON Use the Eisenhower Matrix (Urgent/Important) as a reasoning lens when prioritizing tasks." ;;
    esac
    # Eval enrichments
    [[ "$PREF_EVAL_ANALYZE_FIRST" == "true" ]] && REASON="$REASON For eval tools, run structural analysis first before expensive execution stages."
    if [[ "$PREF_EVAL_COST_PROFILE" == "pay-per-use" ]]; then
        REASON="$REASON Cost profile: pay-per-use. Default to structural-only evaluation; require explicit opt-in for execution."
    elif [[ "$PREF_EVAL_COST_PROFILE" == "budget" ]]; then
        REASON="$REASON Cost profile: budget. Checkpoint if estimated eval cost exceeds \$${PREF_EVAL_MAX_BUDGET}."
    fi
    # Per-role style depth for execution output
    _exec_style="${PREF_STYLE_SCAN:-$PREF_STYLE_BASE}"
    if [[ "$_exec_style" != "balanced" ]]; then
        REASON="$REASON Explanation depth for scan/execution output: ${_exec_style}."
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

REASON="Continue CCC execution for ${LINEAR_ISSUE:-unknown issue}. Mode: ${EXEC_MODE}."
REASON="$REASON Read .ccc-progress.md for completed task context."
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

# Prompt enrichments (configurable via .ccc-preferences.yaml)
[[ "$PREF_SUBAGENT" == "true" ]] && REASON="$REASON Use parallel subagents for codebase reads; single subagent for build/test."
[[ "$PREF_SEARCH" == "true" ]] && REASON="$REASON Before implementing, search the codebase for existing solutions. Don't assume functionality is missing."
[[ "$PREF_AGENTS_FILE" == "true" ]] && [[ -f "$PROJECT_ROOT/.ccc-agents.md" ]] && REASON="$REASON Read .ccc-agents.md for project-specific build commands and codebase patterns."
[[ "$PREF_ALWAYS_RECOMMEND" == "true" ]] && REASON="$REASON When presenting options, always highlight your recommended choice."
# Prioritization framework enrichment
case "$PREF_PRIORITIZATION_FW" in
    rice)      REASON="$REASON Use RICE (Reach, Impact, Confidence, Effort) as a reasoning lens when prioritizing tasks." ;;
    moscow)    REASON="$REASON Use MoSCoW (Must, Should, Could, Won't) as a reasoning lens when prioritizing tasks." ;;
    eisenhower) REASON="$REASON Use the Eisenhower Matrix (Urgent/Important) as a reasoning lens when prioritizing tasks." ;;
esac
# Eval enrichments
[[ "$PREF_EVAL_ANALYZE_FIRST" == "true" ]] && REASON="$REASON For eval tools, run structural analysis first before expensive execution stages."
if [[ "$PREF_EVAL_COST_PROFILE" == "pay-per-use" ]]; then
    REASON="$REASON Cost profile: pay-per-use. Default to structural-only evaluation; require explicit opt-in for execution."
elif [[ "$PREF_EVAL_COST_PROFILE" == "budget" ]]; then
    REASON="$REASON Cost profile: budget. Checkpoint if estimated eval cost exceeds \$${PREF_EVAL_MAX_BUDGET}."
fi
# Per-role style depth for execution output
_exec_style="${PREF_STYLE_SCAN:-$PREF_STYLE_BASE}"
if [[ "$_exec_style" != "balanced" ]]; then
    REASON="$REASON Explanation depth for scan/execution output: ${_exec_style}."
fi

REASON="$REASON Signal TASK_COMPLETE when done."

jq -n --arg reason "$REASON" '{"decision": "block", "reason": $reason}'
