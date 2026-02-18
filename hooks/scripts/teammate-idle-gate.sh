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

PROJECT_ROOT="${CCC_PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

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
# 4. Check pending tasks in state file
# ---------------------------------------------------------------------------

STATE_FILE="$PROJECT_ROOT/.ccc-agent-teams.json"

if [[ ! -f "$STATE_FILE" ]]; then
    # No state file — graceful degradation, allow idle
    exit 0
fi

STATE=$(cat "$STATE_FILE" 2>/dev/null) || exit 0

# Check team name matches
STATE_TEAM=$(echo "$STATE" | jq -r '.team_name // empty' 2>/dev/null) || true
if [[ "$STATE_TEAM" != "$TEAM_NAME" ]]; then
    # State is for a different team — allow idle
    exit 0
fi

PENDING=$(echo "$STATE" | jq -r '.pending_tasks // 0' 2>/dev/null) || true

# Validate pending is a number
if ! [[ "$PENDING" =~ ^[0-9]+$ ]]; then
    PENDING=0
fi

if [[ "$PENDING" -gt 0 ]]; then
    echo "[CCC TeammateIdle] Pending tasks remain for team '${TEAM_NAME}'. Check task list and claim a task before going idle." >&2
    exit 2
fi

exit 0
