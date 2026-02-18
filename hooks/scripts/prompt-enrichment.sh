#!/usr/bin/env bash
# CCC Hook: UserPromptSubmit — Prompt Enrichment for Worktree Sessions
# Trigger: User submits a prompt (UserPromptSubmit event)
# Purpose: Enrich prompt context with issue reference and commit conventions
#          when running in a worktree session with a CIA-XXX branch name
#
# Preferences (.ccc-preferences.yaml):
#   prompt_enrichment:
#     enabled: true|false     — enable/disable (default: true)
#     level: minimal|standard|full — enrichment depth (default: standard)
#
# Input (stdin): JSON with session_id, prompt, cwd, etc.
# Output (stdout): JSON hookSpecificOutput with additionalContext
#
# Exit codes:
#   0 — Always (fail-open). Output JSON only when enrichment applies.

set -uo pipefail

# ---------------------------------------------------------------------------
# 0. Prerequisite check
# ---------------------------------------------------------------------------

if ! command -v jq &>/dev/null; then
    exit 0
fi

# ---------------------------------------------------------------------------
# 1. Read stdin (UserPromptSubmit event)
# ---------------------------------------------------------------------------

HOOK_INPUT=$(cat)

# ---------------------------------------------------------------------------
# 2. Detect worktree
# ---------------------------------------------------------------------------

PROJECT_ROOT="${CCC_PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
GIT_PATH="$PROJECT_ROOT/.git"

# Worktree indicator: .git is a file (contains "gitdir: ..."), not a directory
if [[ -d "$GIT_PATH" ]]; then
    # Normal repo, not a worktree — no enrichment needed
    exit 0
fi

if [[ ! -f "$GIT_PATH" ]]; then
    # No .git file or directory — not a git repo
    exit 0
fi

# ---------------------------------------------------------------------------
# 3. Load preferences
# ---------------------------------------------------------------------------

PREFS_FILE="$PROJECT_ROOT/.ccc-preferences.yaml"
ENABLED="true"
LEVEL="standard"

if command -v yq &>/dev/null && [[ -f "$PREFS_FILE" ]]; then
    # Use explicit check — yq's // treats boolean false as falsy
    _enabled=$(yq '.prompt_enrichment.enabled' "$PREFS_FILE" 2>/dev/null) || true
    if [[ "$_enabled" == "false" ]]; then
        exit 0
    fi

    _level=$(yq '.prompt_enrichment.level // "standard"' "$PREFS_FILE" 2>/dev/null) || true
    if [[ "$_level" == "minimal" || "$_level" == "standard" || "$_level" == "full" ]]; then
        LEVEL="$_level"
    fi
fi

# ---------------------------------------------------------------------------
# 4. Extract CIA-XXX from branch name
# ---------------------------------------------------------------------------

# Allow test override for branch name (avoids needing a real git worktree in tests)
# Use ${var+x} to distinguish "set but empty" from "not set"
if [[ -n "${CCC_TEST_BRANCH+x}" ]]; then
    BRANCH="$CCC_TEST_BRANCH"
else
    BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || true
fi

if [[ -z "$BRANCH" ]]; then
    exit 0
fi

# Extract first CIA-NNN (case-insensitive)
CIA_ISSUE=$(echo "$BRANCH" | grep -oiE 'cia-[0-9]+' | head -1 | tr '[:lower:]' '[:upper:]') || true

if [[ -z "$CIA_ISSUE" ]]; then
    exit 0
fi

# ---------------------------------------------------------------------------
# 5. Build enrichment context based on level
# ---------------------------------------------------------------------------

CONTEXT=""

case "$LEVEL" in
    minimal)
        CONTEXT="You are working on ${CIA_ISSUE} (https://linear.app/claudian/issue/${CIA_ISSUE})."
        ;;
    standard)
        CONTEXT="You are working on ${CIA_ISSUE} (https://linear.app/claudian/issue/${CIA_ISSUE}).\\nWorktree branch: ${BRANCH}\\nThis is a worktree session — changes are isolated from the main working directory."
        ;;
    full)
        CONTEXT="You are working on ${CIA_ISSUE} (https://linear.app/claudian/issue/${CIA_ISSUE}).\\nWorktree branch: ${BRANCH}\\nThis is a worktree session — changes are isolated from the main working directory.\\n\\nCommit conventions:\\n- Prefix: feat(${CIA_ISSUE}): | fix(${CIA_ISSUE}): | chore(${CIA_ISSUE}):\\n- Reference ${CIA_ISSUE} in commit messages\\n- One PR per issue, push before session end"
        ;;
esac

if [[ -z "$CONTEXT" ]]; then
    exit 0
fi

# ---------------------------------------------------------------------------
# 6. Output JSON in hookSpecificOutput pattern
# ---------------------------------------------------------------------------

jq -n \
    --arg ctx "$CONTEXT" \
    '{
        hookSpecificOutput: {
            hookEventName: "UserPromptSubmit",
            additionalContext: $ctx
        }
    }'

exit 0
