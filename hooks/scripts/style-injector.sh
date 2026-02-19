#!/usr/bin/env bash
# CCC Hook: SessionStart — Style Injector
# Trigger: Session begins (runs alongside session-start.sh)
# Purpose: Read style.explanatory preference, inject audience-aware context
#
# Reads: .ccc-preferences.yaml → style.explanatory (terse|balanced|detailed|educational)
#         .ccc-preferences.yaml → style.explanatory_by_role.<role> (per-role overrides)
# Output: JSON hookSpecificOutput with additionalContext (Anthropic pattern)
#
# When style.explanatory is "terse" (or unset) AND no per-role overrides exist,
# this hook outputs nothing (no context cost). Otherwise it injects CCC-specific
# output instructions that supplement the agent prompts, including any per-role
# depth overrides for planning, synthesis, review, and scan roles.

set -uo pipefail

PROJECT_ROOT="${SDD_PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
PREFS_FILE="$PROJECT_ROOT/.ccc-preferences.yaml"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"

# --- Read style.explanatory preference ---
STYLE="terse"  # default: no injection
ROLE_OVERRIDES=""
if command -v yq &>/dev/null && [[ -f "$PREFS_FILE" ]]; then
    _s=$(yq '.style.explanatory // "terse"' "$PREFS_FILE" 2>/dev/null)
    if [[ "$_s" == "balanced" || "$_s" == "detailed" || "$_s" == "educational" ]]; then
        STYLE="$_s"
    fi

    # --- Read per-role overrides (explanatory_by_role) ---
    _by_role=$(yq '.style.explanatory_by_role // ""' "$PREFS_FILE" 2>/dev/null)
    if [[ -n "$_by_role" && "$_by_role" != "null" ]]; then
        for _role in planning synthesis review scan; do
            _rv=$(yq ".style.explanatory_by_role.${_role} // \"\"" "$PREFS_FILE" 2>/dev/null)
            if [[ "$_rv" == "terse" || "$_rv" == "balanced" || "$_rv" == "detailed" || "$_rv" == "educational" ]]; then
                ROLE_OVERRIDES="${ROLE_OVERRIDES}  ${_role}: ${_rv}\\n"
            fi
        done
    fi
fi

# --- If terse and no role overrides, output nothing (zero context cost) ---
if [[ "$STYLE" == "terse" && -z "$ROLE_OVERRIDES" ]]; then
    exit 0
fi

# --- Build context based on style level ---
# Read the appropriate style file from the plugin's styles/ directory
STYLE_FILE=""
case "$STYLE" in
    balanced|detailed)
        STYLE_FILE="$PLUGIN_ROOT/styles/explanatory.md"
        ;;
    educational)
        STYLE_FILE="$PLUGIN_ROOT/styles/educational.md"
        ;;
esac

ESCAPED_CONTENT=""
if [[ -n "$STYLE_FILE" && -f "$STYLE_FILE" ]]; then
    # Read style content, stripping YAML frontmatter (--- ... --- block at top of file)
    STYLE_CONTENT=$(awk 'BEGIN{n=0} /^---$/{n++; if(n<=2) next} n>=2{print}' "$STYLE_FILE" 2>/dev/null)

    if [[ -n "$STYLE_CONTENT" ]]; then
        # Escape for JSON: backslashes, quotes, newlines, tabs
        ESCAPED_CONTENT=$(printf '%s' "$STYLE_CONTENT" | \
            sed 's/\\/\\\\/g' | \
            sed 's/"/\\"/g' | \
            sed 's/	/\\t/g' | \
            awk '{printf "%s\\n", $0}' | \
            sed 's/\\n$//')
    fi
fi

# If no style content and no role overrides, nothing to inject
if [[ -z "$ESCAPED_CONTENT" && -z "$ROLE_OVERRIDES" ]]; then
    exit 0
fi

# --- Build role override context ---
ROLE_CONTEXT=""
if [[ -n "$ROLE_OVERRIDES" ]]; then
    ROLE_CONTEXT="\\n\\nPer-role explanation depth overrides (from style.explanatory_by_role):\\n${ROLE_OVERRIDES}Missing roles fall back to the base '${STYLE}' depth. Use the role-specific depth when generating output for that role (e.g., planning output uses the 'planning' depth, review output uses the 'review' depth)."
fi

# --- Build the full additional context ---
BASE_MSG="You are in CCC '${STYLE}' explanation mode (set via style.explanatory in .ccc-preferences.yaml)."

if [[ -n "$ESCAPED_CONTENT" ]]; then
    FULL_CONTEXT="${BASE_MSG}\\n\\nWhen working within the CCC workflow (specs, adversarial reviews, decomposition, execution), follow these audience-aware communication rules:\\n\\n${ESCAPED_CONTENT}${ROLE_CONTEXT}"
else
    # Base style is terse (no style file), but role overrides exist
    FULL_CONTEXT="${BASE_MSG}${ROLE_CONTEXT}"
fi

# --- Output JSON in Anthropic's hookSpecificOutput pattern ---
cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "${FULL_CONTEXT}"
  }
}
EOF

exit 0
