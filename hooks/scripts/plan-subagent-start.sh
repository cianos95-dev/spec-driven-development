#!/usr/bin/env bash
# CCC Hook: SubagentStart — Plan Quality Injection
# Trigger: Plan subagent spawns (SubagentStart with matcher: "Plan")
# Purpose: Inject CCC planning template, business context framing,
#          AskUserQuestion guidance, and style-aware writing instructions
#          into every Plan subagent
#
# This is the highest-leverage planning hook — it improves every plan
# CCC generates with zero skill changes or manual invocation.
#
# Input (stdin): JSON with agent_type, permission_mode, session_id, etc.
# Output (stdout): JSON hookSpecificOutput with additionalContext
#
# Exit codes:
#   0 — Always (fail-open). Output JSON only when context applies.

set -uo pipefail

# ---------------------------------------------------------------------------
# 0. Prerequisite check
# ---------------------------------------------------------------------------

if ! command -v jq &>/dev/null; then
    exit 0
fi

# ---------------------------------------------------------------------------
# 1. Read stdin (SubagentStart event)
# ---------------------------------------------------------------------------

HOOK_INPUT=$(cat)

# ---------------------------------------------------------------------------
# 2. Read preferences for style and planning settings
# ---------------------------------------------------------------------------

PROJECT_ROOT="${CCC_PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
PREFS_FILE="$PROJECT_ROOT/.ccc-preferences.yaml"
STATE_FILE="$PROJECT_ROOT/.ccc-state.json"

STYLE="balanced"
ALWAYS_RECOMMEND="true"

if command -v yq &>/dev/null && [[ -f "$PREFS_FILE" ]]; then
    # Check per-role planning style first, fall back to base explanatory
    _role_style=$(yq '.style.explanatory_by_role.planning // ""' "$PREFS_FILE" 2>/dev/null) || true
    if [[ "$_role_style" == "terse" || "$_role_style" == "balanced" || "$_role_style" == "detailed" || "$_role_style" == "educational" ]]; then
        STYLE="$_role_style"
    else
        _style=$(yq '.style.explanatory // "balanced"' "$PREFS_FILE" 2>/dev/null) || true
        if [[ "$_style" == "terse" || "$_style" == "balanced" || "$_style" == "detailed" || "$_style" == "educational" ]]; then
            STYLE="$_style"
        fi
    fi

    _rec=$(yq '.planning.always_recommend // "true"' "$PREFS_FILE" 2>/dev/null) || true
    if [[ "$_rec" == "false" ]]; then
        ALWAYS_RECOMMEND="false"
    fi
fi

# ---------------------------------------------------------------------------
# 3. Read active issue context (if available)
# ---------------------------------------------------------------------------

ISSUE_CONTEXT=""
if [[ -f "$STATE_FILE" ]] && command -v jq &>/dev/null; then
    _issue=$(jq -r '.linearIssue // empty' "$STATE_FILE" 2>/dev/null) || true
    _mode=$(jq -r '.executionMode // empty' "$STATE_FILE" 2>/dev/null) || true
    if [[ -n "$_issue" ]]; then
        ISSUE_CONTEXT="Active issue: ${_issue} (https://linear.app/claudian/issue/${_issue})"
        if [[ -n "$_mode" ]]; then
            ISSUE_CONTEXT="${ISSUE_CONTEXT}. Execution mode: ${_mode}."
        fi
    fi
fi

# ---------------------------------------------------------------------------
# 4. Build planning template context
# ---------------------------------------------------------------------------

# Core plan sections template
PLAN_TEMPLATE="## CCC Plan Quality Standards

When writing a plan, include these sections (omit any that are genuinely not applicable):

### Required Sections
1. **Context** — What problem is being solved and why now
2. **Scope** — What is included in this work
3. **Non-Goals** — What is explicitly excluded (prevents scope creep)
4. **Tasks** — Concrete, ordered steps with file paths where applicable
5. **Verification** — How to confirm the work is complete and correct

### Recommended Sections (for 3+ point work)
6. **Risks** — What could go wrong and mitigations
7. **Dependencies** — What must exist before this can start
8. **Alternatives Considered** — Other approaches evaluated and why they were rejected

### Issue References
All issue references must use clickable markdown links: [CIA-XXX](https://linear.app/claudian/issue/CIA-XXX). Plain text issue IDs are not permitted in plans."

# Style-aware writing guidance
STYLE_GUIDANCE=""
case "$STYLE" in
    terse)
        STYLE_GUIDANCE="Plan writing style: TERSE. Use technical bullet points, no narrative. Minimize prose. Focus on actionable steps and file paths."
        ;;
    balanced)
        STYLE_GUIDANCE="Plan writing style: BALANCED. Use structured sections with brief rationale for key decisions. Keep explanations concise but include context for non-obvious choices."
        ;;
    detailed)
        STYLE_GUIDANCE="Plan writing style: DETAILED. Include full context, trade-off analysis, and alternatives considered. Explain reasoning behind architectural choices. Suitable for plans that will be reviewed by others."
        ;;
    educational)
        STYLE_GUIDANCE="Plan writing style: EDUCATIONAL. Write for accessibility — explain technical concepts, provide learning-oriented context, include decision guides. This plan may be read by someone unfamiliar with the codebase or domain."
        ;;
esac

# AskUserQuestion guidance
ASK_GUIDANCE=""
if [[ "$ALWAYS_RECOMMEND" == "true" ]]; then
    ASK_GUIDANCE="When using AskUserQuestion: ALWAYS make the first option your recommended choice with '(Recommended)' suffix. Include an explanatory 'description' field on each option explaining trade-offs or implications. The user prefers explanatory style over terse options."
fi

# Business context framing
BUSINESS_FRAMING="When planning, consider the business context: Who is the customer for this work? What problem does it solve for them? What does success look like? If ChatPRD or business validation output exists in the issue description or linked documents, incorporate those findings into the plan context."

# ---------------------------------------------------------------------------
# 5. Assemble and output
# ---------------------------------------------------------------------------

CONTEXT="${PLAN_TEMPLATE}"

if [[ -n "$ISSUE_CONTEXT" ]]; then
    CONTEXT="${CONTEXT}\\n\\n${ISSUE_CONTEXT}"
fi

if [[ -n "$STYLE_GUIDANCE" ]]; then
    CONTEXT="${CONTEXT}\\n\\n${STYLE_GUIDANCE}"
fi

if [[ -n "$ASK_GUIDANCE" ]]; then
    CONTEXT="${CONTEXT}\\n\\n${ASK_GUIDANCE}"
fi

CONTEXT="${CONTEXT}\\n\\n${BUSINESS_FRAMING}"

# Output JSON in hookSpecificOutput pattern
jq -n \
    --arg ctx "$CONTEXT" \
    '{
        hookSpecificOutput: {
            hookEventName: "SubagentStart",
            additionalContext: $ctx
        }
    }'

exit 0
