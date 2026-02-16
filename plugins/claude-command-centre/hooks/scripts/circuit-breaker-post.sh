#!/usr/bin/env bash
# CCC Hook: Circuit Breaker — PostToolUse (Error Detection)
# Trigger: After any tool execution (PostToolUse)
# Purpose: Detect consecutive identical errors and open the circuit breaker
#
# When 3+ consecutive identical tool errors occur, this hook:
#   1. Opens the circuit breaker (writes state file)
#   2. Warns via stderr to use /rewind
#   3. Auto-escalates exec mode from quick→pair
#
# State file: $PROJECT_ROOT/.ccc-circuit-breaker.json
# Preferences: circuit_breaker.threshold (default: 3)
#
# Exit codes:
#   0 — Normal (circuit remains closed or was just opened)
#   2 — Circuit opened (stderr warning sent to Claude)

set -euo pipefail

# ---------------------------------------------------------------------------
# 0. Prerequisite check
# ---------------------------------------------------------------------------

if ! command -v jq &>/dev/null; then
    exit 0
fi

# ---------------------------------------------------------------------------
# 1. Read stdin (tool result from Claude Code)
# ---------------------------------------------------------------------------

TOOL_OUTPUT=$(cat)

# Extract tool name and error status
TOOL_NAME=$(echo "$TOOL_OUTPUT" | jq -r '.tool_name // empty' 2>/dev/null) || true
TOOL_ERROR=$(echo "$TOOL_OUTPUT" | jq -r '.tool_result.is_error // false' 2>/dev/null) || true
ERROR_MSG=$(echo "$TOOL_OUTPUT" | jq -r '.tool_result.content // empty' 2>/dev/null) || true

# If no error, reset the breaker and exit
if [[ "$TOOL_ERROR" != "true" ]]; then
    # Successful tool use — reset consecutive error count
    PROJECT_ROOT="${SDD_PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
    CB_FILE="$PROJECT_ROOT/.ccc-circuit-breaker.json"
    if [[ -f "$CB_FILE" ]]; then
        STATE=$(cat "$CB_FILE")
        IS_OPEN=$(echo "$STATE" | jq -r '.open // false' 2>/dev/null) || true
        if [[ "$IS_OPEN" != "true" ]]; then
            # Circuit is closed and tool succeeded — reset counter
            rm -f "$CB_FILE"
        fi
        # If circuit is open, don't reset on success — require explicit reset
    fi
    exit 0
fi

# ---------------------------------------------------------------------------
# 2. Locate project root and circuit breaker state
# ---------------------------------------------------------------------------

PROJECT_ROOT="${SDD_PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
CB_FILE="$PROJECT_ROOT/.ccc-circuit-breaker.json"

# ---------------------------------------------------------------------------
# 3. Load threshold from preferences
# ---------------------------------------------------------------------------

THRESHOLD=3
PREFS_FILE="$PROJECT_ROOT/.ccc-preferences.yaml"

if command -v yq &>/dev/null && [[ -f "$PREFS_FILE" ]]; then
    _th=$(yq '.circuit_breaker.threshold // 3' "$PREFS_FILE" 2>/dev/null) && THRESHOLD="$_th"
fi

# Validate threshold is a positive integer
if ! [[ "$THRESHOLD" =~ ^[0-9]+$ ]] || [[ "$THRESHOLD" -lt 1 ]]; then
    THRESHOLD=3
fi

# ---------------------------------------------------------------------------
# 4. Build error signature (tool name + truncated error message)
# ---------------------------------------------------------------------------

# Normalize the error to a stable signature for comparison
# Take first 200 chars of error message to avoid noise from timestamps/paths
ERROR_SIG="${TOOL_NAME}:$(echo "$ERROR_MSG" | head -c 200 | tr -d '\n')"

# ---------------------------------------------------------------------------
# 5. Load existing circuit breaker state
# ---------------------------------------------------------------------------

if [[ -f "$CB_FILE" ]]; then
    CB_STATE=$(cat "$CB_FILE")
    PREV_SIG=$(echo "$CB_STATE" | jq -r '.lastErrorSignature // empty' 2>/dev/null) || true
    CONSECUTIVE=$(echo "$CB_STATE" | jq -r '.consecutiveErrors // 0' 2>/dev/null) || true
    IS_OPEN=$(echo "$CB_STATE" | jq -r '.open // false' 2>/dev/null) || true
else
    PREV_SIG=""
    CONSECUTIVE=0
    IS_OPEN="false"
fi

# If circuit is already open, just warn again
if [[ "$IS_OPEN" == "true" ]]; then
    echo "[CCC Circuit Breaker] Circuit is OPEN. Use /rewind to recover from error loop." >&2
    exit 2
fi

# ---------------------------------------------------------------------------
# 6. Compare error signature — same error or new error?
# ---------------------------------------------------------------------------

if [[ "$ERROR_SIG" == "$PREV_SIG" ]]; then
    # Same error repeating
    CONSECUTIVE=$((CONSECUTIVE + 1))
else
    # Different error — reset counter
    CONSECUTIVE=1
fi

# ---------------------------------------------------------------------------
# 7. Check threshold — open circuit if met
# ---------------------------------------------------------------------------

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if [[ $CONSECUTIVE -ge $THRESHOLD ]]; then
    # CIRCUIT OPEN — write state, warn, escalate

    # Read current exec mode from .ccc-state.json for escalation
    STATE_FILE="$PROJECT_ROOT/.ccc-state.json"
    CURRENT_MODE="unknown"
    ESCALATED_MODE=""
    if [[ -f "$STATE_FILE" ]]; then
        CURRENT_MODE=$(jq -r '.executionMode // "unknown"' "$STATE_FILE" 2>/dev/null) || true
        if [[ "$CURRENT_MODE" == "quick" ]]; then
            ESCALATED_MODE="pair"
            # Update the state file with escalated mode
            TEMP=$(mktemp)
            UPDATED=$(jq '.executionMode = "pair"' "$STATE_FILE" 2>/dev/null) || true
            if [[ -n "$UPDATED" ]]; then
                echo "$UPDATED" > "$TEMP" && mv "$TEMP" "$STATE_FILE"
            else
                rm -f "$TEMP"
            fi
        fi
    fi

    # Write circuit breaker state
    jq -n \
        --arg sig "$ERROR_SIG" \
        --argjson count "$CONSECUTIVE" \
        --argjson threshold "$THRESHOLD" \
        --arg tool "$TOOL_NAME" \
        --arg ts "$TIMESTAMP" \
        --arg prev_mode "$CURRENT_MODE" \
        --arg esc_mode "${ESCALATED_MODE:-}" \
        '{
            open: true,
            consecutiveErrors: $count,
            threshold: $threshold,
            lastErrorSignature: $sig,
            lastToolName: $tool,
            openedAt: $ts,
            previousExecMode: $prev_mode,
            escalatedTo: (if $esc_mode != "" then $esc_mode else null end)
        }' > "$CB_FILE"

    # Stderr warning (exit 2 feeds this back to Claude)
    MSG="[CCC Circuit Breaker] CIRCUIT OPEN: $CONSECUTIVE consecutive identical errors detected on '$TOOL_NAME'."
    MSG="$MSG The same error has repeated $CONSECUTIVE times (threshold: $THRESHOLD)."
    MSG="$MSG RECOMMENDED: Use /rewind to undo the last few tool calls and try a different approach."
    if [[ -n "$ESCALATED_MODE" ]]; then
        MSG="$MSG Exec mode auto-escalated from '$CURRENT_MODE' to '$ESCALATED_MODE' (human-in-the-loop)."
    fi
    MSG="$MSG To reset the circuit breaker, resolve the root cause or delete .ccc-circuit-breaker.json."
    echo "$MSG" >&2
    exit 2
else
    # Below threshold — update state, no alarm
    jq -n \
        --arg sig "$ERROR_SIG" \
        --argjson count "$CONSECUTIVE" \
        --argjson threshold "$THRESHOLD" \
        --arg tool "$TOOL_NAME" \
        --arg ts "$TIMESTAMP" \
        '{
            open: false,
            consecutiveErrors: $count,
            threshold: $threshold,
            lastErrorSignature: $sig,
            lastToolName: $tool,
            updatedAt: $ts
        }' > "$CB_FILE"

    echo "[CCC] Error $CONSECUTIVE of $THRESHOLD on '$TOOL_NAME'. Circuit still closed."
    exit 0
fi
