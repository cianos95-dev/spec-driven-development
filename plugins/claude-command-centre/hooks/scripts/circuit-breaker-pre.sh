#!/usr/bin/env bash
# CCC Hook: Circuit Breaker — PreToolUse (Block Destructive Ops)
# Trigger: Before tool execution (PreToolUse)
# Purpose: Block destructive operations when the circuit breaker is open
#
# When the circuit breaker is open (.ccc-circuit-breaker.json has open: true),
# this hook blocks destructive tools (Write, Edit, MultiEdit, Bash, NotebookEdit)
# and allows read-only tools to proceed.
#
# Output format (PreToolUse):
#   stdout JSON with hookSpecificOutput.permissionDecision = "allow" | "deny"
#
# Exit codes:
#   0 — Tool allowed (or circuit breaker not active)
#   2 — Tool blocked (circuit open + destructive operation)

set -euo pipefail

# ---------------------------------------------------------------------------
# 0. Prerequisite check
# ---------------------------------------------------------------------------

if ! command -v jq &>/dev/null; then
    exit 0
fi

# ---------------------------------------------------------------------------
# 1. Read stdin (tool call details from Claude Code)
# ---------------------------------------------------------------------------

TOOL_INPUT=$(cat)

TOOL_NAME=$(echo "$TOOL_INPUT" | jq -r '.tool_name // empty' 2>/dev/null) || true

if [[ -z "$TOOL_NAME" ]]; then
    exit 0
fi

# ---------------------------------------------------------------------------
# 2. Check circuit breaker state
# ---------------------------------------------------------------------------

PROJECT_ROOT="${SDD_PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
CB_FILE="$PROJECT_ROOT/.ccc-circuit-breaker.json"

if [[ ! -f "$CB_FILE" ]]; then
    # No circuit breaker state — allow everything
    exit 0
fi

CB_STATE=$(cat "$CB_FILE" 2>/dev/null) || exit 0
IS_OPEN=$(echo "$CB_STATE" | jq -r '.open // false' 2>/dev/null) || true

if [[ "$IS_OPEN" != "true" ]]; then
    # Circuit is closed — allow everything
    exit 0
fi

# ---------------------------------------------------------------------------
# 3. Circuit is OPEN — classify the tool
# ---------------------------------------------------------------------------

# Destructive tools that should be blocked when circuit is open
DESTRUCTIVE_TOOLS="Write|Edit|MultiEdit|NotebookEdit|Bash"

# Read-only tools that are always safe
READONLY_TOOLS="Read|Glob|Grep|Ls|WebFetch|WebSearch|Task|TodoWrite|TodoRead"

IS_DESTRUCTIVE=false
if echo "$TOOL_NAME" | grep -qE "^($DESTRUCTIVE_TOOLS)$"; then
    IS_DESTRUCTIVE=true
fi

# MCP write tools (create, update, delete, push, etc.)
if echo "$TOOL_NAME" | grep -qiE "^mcp__.*__(create|update|delete|push|write|edit|remove|merge)"; then
    IS_DESTRUCTIVE=true
fi

# ---------------------------------------------------------------------------
# 4. Allow or block based on classification
# ---------------------------------------------------------------------------

LAST_TOOL=$(echo "$CB_STATE" | jq -r '.lastToolName // "unknown"' 2>/dev/null) || true
ERROR_COUNT=$(echo "$CB_STATE" | jq -r '.consecutiveErrors // 0' 2>/dev/null) || true

if [[ "$IS_DESTRUCTIVE" == "true" ]]; then
    # Block destructive operation
    MSG="[CCC Circuit Breaker] BLOCKED: '$TOOL_NAME' denied — circuit is open ($ERROR_COUNT consecutive errors on '$LAST_TOOL')."
    MSG="$MSG Use /rewind to recover, or delete .ccc-circuit-breaker.json to force reset."

    # Output PreToolUse deny decision
    jq -n \
        --arg msg "$MSG" \
        '{
            hookSpecificOutput: {
                permissionDecision: "deny"
            },
            systemMessage: $msg
        }' >&2
    exit 2
else
    # Allow read-only operation
    echo "[CCC] Circuit open but allowing read-only tool: $TOOL_NAME"
    exit 0
fi
