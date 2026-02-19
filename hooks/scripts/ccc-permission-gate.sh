#!/usr/bin/env bash
# CCC Hook: Permission Gate — PermissionRequest event
# Trigger: Claude Code permission dialog (before user sees the prompt)
# Purpose: Circuit breaker enforcement + execution mode tool filtering
#
# This hook provides an additional enforcement point beyond PreToolUse:
# PermissionRequest fires on the permission dialog itself, allowing CCC
# to deny requests before the user is even asked.
#
# Output format (PermissionRequest):
#   stdout JSON with hookSpecificOutput.permissionDecision = "allow" | "deny"
#
# Exit codes:
#   0 — Permission allowed (or no enforcement active)
#   2 — Permission denied (circuit breaker open or exec mode restriction)

set -uo pipefail
# NOTE: Do NOT use set -e in hooks. Non-zero exit = hook failure in Claude Code.

# ---------------------------------------------------------------------------
# 0. Prerequisite check
# ---------------------------------------------------------------------------

if ! command -v jq &>/dev/null; then
    exit 0
fi

# ---------------------------------------------------------------------------
# 1. Read stdin (permission request details from Claude Code)
# ---------------------------------------------------------------------------

HOOK_INPUT=$(cat)

TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // empty' 2>/dev/null) || true

if [[ -z "$TOOL_NAME" ]]; then
    exit 0
fi

# ---------------------------------------------------------------------------
# 2. Locate project root and state files
# ---------------------------------------------------------------------------

PROJECT_ROOT="${CCC_PROJECT_ROOT:-${SDD_PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}}"
CB_FILE="$PROJECT_ROOT/.ccc-circuit-breaker.json"
STATE_FILE="$PROJECT_ROOT/.ccc-state.json"

# ---------------------------------------------------------------------------
# 3. Check circuit breaker state
# ---------------------------------------------------------------------------

if [[ -f "$CB_FILE" ]]; then
    CB_STATE=$(cat "$CB_FILE" 2>/dev/null) || true
    IS_OPEN=$(echo "$CB_STATE" | jq -r '.open // false' 2>/dev/null) || true

    if [[ "$IS_OPEN" == "true" ]]; then
        ERROR_COUNT=$(echo "$CB_STATE" | jq -r '.consecutiveErrors // 0' 2>/dev/null) || true
        LAST_TOOL=$(echo "$CB_STATE" | jq -r '.lastToolName // "unknown"' 2>/dev/null) || true

        MSG="[CCC Circuit Breaker] Permission denied for '$TOOL_NAME' — circuit breaker is open"
        MSG="$MSG ($ERROR_COUNT consecutive errors on '$LAST_TOOL')."
        MSG="$MSG Resolve the error pattern first, or delete .ccc-circuit-breaker.json to reset."

        jq -n \
            --arg msg "$MSG" \
            '{
                hookSpecificOutput: {
                    permissionDecision: "deny"
                },
                systemMessage: $msg
            }' >&2
        exit 2
    fi
fi

# ---------------------------------------------------------------------------
# 4. Check execution mode tool restrictions
# ---------------------------------------------------------------------------

if [[ -f "$STATE_FILE" ]]; then
    STATE=$(cat "$STATE_FILE" 2>/dev/null) || true
    EXEC_MODE=$(echo "$STATE" | jq -r '.executionMode // ""' 2>/dev/null) || true

    # In quick mode: block swarm/team tools (no multi-agent for quick tasks)
    if [[ "$EXEC_MODE" == "quick" ]]; then
        if echo "$TOOL_NAME" | grep -qiE "^(TeamCreate|SendMessage|Task)$"; then
            MSG="[CCC Exec Mode] Permission denied for '$TOOL_NAME' — quick mode does not allow multi-agent tools."
            MSG="$MSG Change execution mode or remove .ccc-state.json to override."

            jq -n \
                --arg msg "$MSG" \
                '{
                    hookSpecificOutput: {
                        permissionDecision: "deny"
                    },
                    systemMessage: $msg
                }' >&2
            exit 2
        fi
    fi

    # In pair mode: allow all tools (human is watching)
    # In tdd mode: allow all tools (TDD needs full access)
    # In checkpoint mode: allow all tools (complex tasks need flexibility)
    # In swarm mode: allow all tools (multi-agent by design)
fi

# ---------------------------------------------------------------------------
# 5. No restrictions — allow the permission request
# ---------------------------------------------------------------------------

exit 0
