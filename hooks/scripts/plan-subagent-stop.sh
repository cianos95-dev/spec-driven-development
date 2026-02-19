#!/usr/bin/env bash
# CCC Hook: SubagentStop — Plan Quality Validation
# Trigger: Plan subagent completes (SubagentStop with matcher: "Plan")
# Purpose: Validate that generated plans include required CCC sections
#          and use linked issue references. Warn on missing sections.
#
# This hook cannot block plan presentation — it provides advisory
# warnings that appear after the plan is shown to the user.
#
# Input (stdin): JSON with agent_type, stop_reason, transcript, etc.
# Output (stdout): JSON hookSpecificOutput with additionalContext (warnings)
#
# Exit codes:
#   0 — Always (fail-open). Output JSON only when warnings apply.

set -uo pipefail

# ---------------------------------------------------------------------------
# 0. Prerequisite check
# ---------------------------------------------------------------------------

if ! command -v jq &>/dev/null; then
    exit 0
fi

# ---------------------------------------------------------------------------
# 1. Read stdin (SubagentStop event)
# ---------------------------------------------------------------------------

HOOK_INPUT=$(cat)

# ---------------------------------------------------------------------------
# 2. Check the plan file for required sections
# ---------------------------------------------------------------------------

# Find the most recently modified plan file
PLANS_DIR="${HOME}/.claude/plans"
if [[ ! -d "$PLANS_DIR" ]]; then
    exit 0
fi

PLAN_FILE=$(ls -t "$PLANS_DIR"/*.md 2>/dev/null | head -1)
if [[ -z "$PLAN_FILE" || ! -f "$PLAN_FILE" ]]; then
    exit 0
fi

# Check for required sections (case-insensitive grep)
MISSING_SECTIONS=""

# Context section
if ! grep -qi '## .*context\|### .*context' "$PLAN_FILE" 2>/dev/null; then
    MISSING_SECTIONS="${MISSING_SECTIONS}Context, "
fi

# Scope section
if ! grep -qi '## .*scope\|### .*scope' "$PLAN_FILE" 2>/dev/null; then
    MISSING_SECTIONS="${MISSING_SECTIONS}Scope, "
fi

# Tasks / Execution / Implementation section
if ! grep -qi '## .*task\|### .*task\|## .*execution\|## .*implementation\|## .*step' "$PLAN_FILE" 2>/dev/null; then
    MISSING_SECTIONS="${MISSING_SECTIONS}Tasks, "
fi

# Verification section
if ! grep -qi '## .*verif\|### .*verif' "$PLAN_FILE" 2>/dev/null; then
    MISSING_SECTIONS="${MISSING_SECTIONS}Verification, "
fi

# Check for unlinked CIA-XXX references (plain text without markdown link)
UNLINKED=""
if grep -qP 'CIA-\d+' "$PLAN_FILE" 2>/dev/null; then
    # Count references that are NOT inside markdown links
    UNLINKED_COUNT=$(grep -oP '(?<!\[)CIA-\d+(?!\])(?!\()' "$PLAN_FILE" 2>/dev/null | wc -l | tr -d ' ') || true
    if [[ "$UNLINKED_COUNT" -gt 0 ]]; then
        UNLINKED="Found ${UNLINKED_COUNT} unlinked issue reference(s). Use [CIA-XXX](https://linear.app/claudian/issue/CIA-XXX) format."
    fi
fi

# ---------------------------------------------------------------------------
# 3. Build warnings (if any)
# ---------------------------------------------------------------------------

# Strip trailing comma-space from missing sections
MISSING_SECTIONS="${MISSING_SECTIONS%, }"

WARNINGS=""

if [[ -n "$MISSING_SECTIONS" ]]; then
    WARNINGS="[CCC Plan Quality] Missing recommended sections: ${MISSING_SECTIONS}. Consider adding them for completeness."
fi

if [[ -n "$UNLINKED" ]]; then
    if [[ -n "$WARNINGS" ]]; then
        WARNINGS="${WARNINGS}\\n${UNLINKED}"
    else
        WARNINGS="[CCC Plan Quality] ${UNLINKED}"
    fi
fi

# ---------------------------------------------------------------------------
# 4. Output (only if warnings exist)
# ---------------------------------------------------------------------------

if [[ -z "$WARNINGS" ]]; then
    exit 0
fi

jq -n \
    --arg ctx "$WARNINGS" \
    '{
        hookSpecificOutput: {
            hookEventName: "SubagentStop",
            additionalContext: $ctx
        }
    }'

exit 0
