#!/usr/bin/env bash
# CCC Hook: SessionStart
# Trigger: Session begins
# Purpose: Load active spec, verify context budget, set ownership scope
#
# Install: Copy to your project's .claude/hooks/session-start.sh
# Configure in .claude/settings.json:
#   "hooks": { "SessionStart": [{ "matcher": "", "hooks": [{ "type": "command", "command": ".claude/hooks/session-start.sh" }] }] }
#
# Environment variables:
#   CCC_SPEC_PATH    - Path to active spec file (auto-detected if not set)
#   SDD_CONTEXT_THRESHOLD - Context budget warning threshold (default: 50)
#   SDD_PROJECT_ROOT - Project root directory (default: git root)

set -uo pipefail
# NOTE: Do NOT use set -e in hooks. Hooks must always exit 0 on informational
# messages. Non-zero exits are treated as hook failures by Claude Code.
# Only exit non-zero when the hook needs to BLOCK the action.

PROJECT_ROOT="${SDD_PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
CONTEXT_THRESHOLD="${SDD_CONTEXT_THRESHOLD:-50}"

# --- 0. Prerequisite validation ---
# Check tools required by the execution engine (ccc-stop-handler.sh).
# Missing jq causes the stop hook to silently exit 0, breaking the loop.
# Missing yq causes preferences to silently fall back to defaults.

CCC_PREREQ_OK=true

if ! command -v git &>/dev/null; then
  echo "[CCC] WARNING: git not found. Version control features will not work."
  CCC_PREREQ_OK=false
fi

if ! command -v jq &>/dev/null; then
  echo "[CCC] WARNING: jq not found. The execution loop (stop hook) will silently fail."
  echo "[CCC]   Install: brew install jq"
  CCC_PREREQ_OK=false
fi

if ! command -v yq &>/dev/null; then
  echo "[CCC] NOTE: yq not found. Execution preferences will use defaults."
  echo "[CCC]   Install: brew install yq"
fi

if [[ "$CCC_PREREQ_OK" == "true" ]]; then
  echo "[CCC] Prerequisites OK (git, jq)"
else
  echo "[CCC] Some prerequisites missing. Execution loop may not function correctly."
fi

# --- 1. Load active spec ---
# Look for spec reference in frontmatter of active issues
# Customize this section based on your project tracker integration

if [[ -n "${CCC_SPEC_PATH:-}" ]] && [[ -f "$CCC_SPEC_PATH" ]]; then
  echo "[CCC] Active spec loaded: $CCC_SPEC_PATH"
else
  echo "[CCC] No active spec path set. Set CCC_SPEC_PATH or ensure issue has spec link."
fi

# --- 2. Check for stale context ---
# Look for codebase index and check freshness

INDEX_FILE="$PROJECT_ROOT/.claude/codebase-index.md"
if [[ -f "$INDEX_FILE" ]]; then
  INDEX_DATE=$(head -5 "$INDEX_FILE" | sed -n 's/.*Generated: \([0-9-]*\).*/\1/p' | head -1)
  INDEX_DATE="${INDEX_DATE:-unknown}"
  echo "[CCC] Codebase index found (generated: $INDEX_DATE)"
else
  echo "[CCC] No codebase index found. Consider running /ccc:index"
fi

# --- 3. Git state summary ---

if git rev-parse --is-inside-work-tree &>/dev/null; then
  BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")
  UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  echo "[CCC] Branch: $BRANCH | Uncommitted files: $UNCOMMITTED"
else
  echo "[CCC] Not in a git repository. Git state checks skipped."
fi

# --- 4. Ownership scope ---
# Log which files are expected to be modified in this session
# Customize based on your spec's file scope

# --- 5. Execution state check ---
# Warn if a .ccc-state.json exists and is stale (>24h since last update)

STATE_FILE="$PROJECT_ROOT/.ccc-state.json"
if [[ -f "$STATE_FILE" ]] && command -v jq &>/dev/null; then
  PHASE=$(jq -r '.phase // "unknown"' "$STATE_FILE" 2>/dev/null)
  TASK_IDX=$(jq -r '.taskIndex // 0' "$STATE_FILE" 2>/dev/null)
  TOTAL=$(jq -r '.totalTasks // 0' "$STATE_FILE" 2>/dev/null)
  LINEAR_ISSUE=$(jq -r '.linearIssue // "unknown"' "$STATE_FILE" 2>/dev/null)
  LAST_UPDATED=$(jq -r '.lastUpdatedAt // empty' "$STATE_FILE" 2>/dev/null)

  echo "[CCC] Active execution: $LINEAR_ISSUE | Phase: $PHASE | Task: $TASK_IDX/$TOTAL"

  # Check staleness (>24h)
  if [[ -n "$LAST_UPDATED" ]]; then
    LAST_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${LAST_UPDATED%%[.Z]*}" "+%s" 2>/dev/null || echo 0)
    NOW_EPOCH=$(date "+%s")
    AGE_HOURS=$(( (NOW_EPOCH - LAST_EPOCH) / 3600 ))
    if [[ "$AGE_HOURS" -gt 24 ]]; then
      echo "[CCC] WARNING: State file is ${AGE_HOURS}h old. Run /ccc:go to resume or delete .ccc-state.json to start fresh."
    fi
  fi
fi

# --- 6. Dispatch readiness hint ---
# Signal that a readiness scan is available. The actual scan requires MCP access
# (Linear API) which hooks cannot call directly. This is a lightweight hint that
# prompts Claude to invoke the dispatch-readiness skill when appropriate.

if [[ -f "$STATE_FILE" ]] || git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
  echo "[CCC] Readiness scan available. Use /ccc:go --scan to check for unblocked issues."
fi

echo "[CCC] Session initialized. Context threshold: ${CONTEXT_THRESHOLD}%"

# Hooks must exit 0 unless blocking an action
exit 0
