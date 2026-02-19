#!/usr/bin/env bash
# CCC Hook: Agent Teams — TeammateIdle (Idle Gate)
# Trigger: When a teammate finishes its turn and is about to go idle
# Purpose: Optionally keep a teammate working when pending tasks remain
#
# Preferences (.ccc-preferences.yaml):
#   agent_teams.idle_gate:
#     allow              — always allow idle (default, zero overhead)
#     block_without_tasks — re-prompt teammate if pending tasks exist
#
# State file: .ccc-agent-teams.json (written by task-completed-gate.sh)
#
# Exit codes:
#   0 — Allow teammate to go idle
#   2 — Keep teammate working (stderr fed back to teammate)

set -uo pipefail
# NOTE: Do NOT use set -e in hooks.

# ---------------------------------------------------------------------------
# 0. Prerequisite check
# ---------------------------------------------------------------------------

if ! command -v jq &>/dev/null; then
    exit 0
fi

# ---------------------------------------------------------------------------
# 1. Read stdin (TeammateIdle event from Claude Code)
# ---------------------------------------------------------------------------

HOOK_INPUT=$(cat)

TEAMMATE_NAME=$(echo "$HOOK_INPUT" | jq -r '.teammate_name // empty' 2>/dev/null) || true
TEAM_NAME=$(echo "$HOOK_INPUT" | jq -r '.team_name // empty' 2>/dev/null) || true

if [[ -z "$TEAMMATE_NAME" ]]; then
    exit 0
fi

# ---------------------------------------------------------------------------
# 2. Locate project root
# ---------------------------------------------------------------------------

PROJECT_ROOT="${CCC_PROJECT_ROOT:-${SDD_PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}}"

# ---------------------------------------------------------------------------
# 3. Load idle_gate preference
# ---------------------------------------------------------------------------

IDLE_GATE="allow"
PREFS_FILE="$PROJECT_ROOT/.ccc-preferences.yaml"

if command -v yq &>/dev/null && [[ -f "$PREFS_FILE" ]]; then
    _gate=$(yq '.agent_teams.idle_gate // "allow"' "$PREFS_FILE" 2>/dev/null) && IDLE_GATE="$_gate"
fi

if [[ "$IDLE_GATE" != "block_without_tasks" ]]; then
    exit 0
fi

# ---------------------------------------------------------------------------
# 4. Check pending tasks in agent-teams state file
# ---------------------------------------------------------------------------

STATE_FILE="$PROJECT_ROOT/.ccc-agent-teams.json"

if [[ -f "$STATE_FILE" ]]; then
    STATE=$(cat "$STATE_FILE" 2>/dev/null) || true

    if [[ -n "${STATE:-}" ]]; then
        # Check team name matches
        STATE_TEAM=$(echo "$STATE" | jq -r '.team_name // empty' 2>/dev/null) || true
        if [[ "$STATE_TEAM" == "$TEAM_NAME" ]]; then
            PENDING=$(echo "$STATE" | jq -r '.pending_tasks // 0' 2>/dev/null) || true
            if ! [[ "$PENDING" =~ ^[0-9]+$ ]]; then
                PENDING=0
            fi
            if [[ "$PENDING" -gt 0 ]]; then
                echo "[CCC TeammateIdle] Pending tasks remain for team '${TEAM_NAME}'. Check task list and claim a task before going idle." >&2
                exit 2
            fi
        fi
    fi
fi

# ---------------------------------------------------------------------------
# 5. Check pending tasks in execution engine state file (.ccc-state.json)
# ---------------------------------------------------------------------------

CCC_STATE_FILE="$PROJECT_ROOT/.ccc-state.json"

if [[ -f "$CCC_STATE_FILE" ]]; then
    CCC_STATE=$(cat "$CCC_STATE_FILE" 2>/dev/null) || true

    if [[ -n "${CCC_STATE:-}" ]]; then
        PHASE=$(echo "$CCC_STATE" | jq -r '.phase // empty' 2>/dev/null) || true
        TASK_INDEX=$(echo "$CCC_STATE" | jq -r '.taskIndex // 0' 2>/dev/null) || true
        TOTAL_TASKS=$(echo "$CCC_STATE" | jq -r '.totalTasks // 0' 2>/dev/null) || true

        # Validate numbers
        if ! [[ "$TASK_INDEX" =~ ^[0-9]+$ ]]; then TASK_INDEX=0; fi
        if ! [[ "$TOTAL_TASKS" =~ ^[0-9]+$ ]]; then TOTAL_TASKS=0; fi

        # If execution phase is active and tasks remain, block idle
        if [[ "$PHASE" == "execution" ]] && [[ "$TASK_INDEX" -lt "$TOTAL_TASKS" ]]; then
            REMAINING=$(( TOTAL_TASKS - TASK_INDEX ))
            echo "[CCC TeammateIdle] Execution loop active with ${REMAINING} tasks remaining (task ${TASK_INDEX}/${TOTAL_TASKS}). Continue working or signal TASK_COMPLETE." >&2
            exit 2
        fi
    fi
fi

exit 0
