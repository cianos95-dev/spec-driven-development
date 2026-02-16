#!/usr/bin/env bash
# CCC Hook: PostToolUse
# Trigger: After tool execution completes
# Purpose: Check for ownership boundary violations and log evidence
#
# Install: Copy to your project's .claude/hooks/post-tool-use.sh
# Configure in .claude/settings.json:
#   "hooks": { "PostToolUse": [{ "matcher": "", "hooks": [{ "type": "command", "command": ".claude/hooks/post-tool-use.sh" }] }] }
#
# Environment variables:
#   SDD_LOG_DIR       - Directory for evidence logs (default: .claude/logs/)
#   SDD_STRICT_MODE   - "true" to enforce ownership boundaries strictly

set -euo pipefail

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
LOG_DIR="${SDD_LOG_DIR:-$PROJECT_ROOT/.claude/logs}"
STRICT_MODE="${SDD_STRICT_MODE:-false}"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Read tool result from stdin
TOOL_OUTPUT=$(cat)

# --- 1. Log tool execution for audit trail ---

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
LOG_FILE="$LOG_DIR/tool-log-$(date +%Y%m%d).jsonl"

# Append a log entry (tool name, timestamp, success/failure)
echo "{\"timestamp\":\"$TIMESTAMP\",\"status\":\"completed\"}" >> "$LOG_FILE"

# --- 2. Ownership boundary check ---
# Customize these checks based on your ownership model
#
# Example violations to detect:
# - Modifying files outside the spec's scope
# - Changing priority/due-date fields (human-owned per issue-lifecycle)
# - Writing to protected branches
# - Modifying CI/CD configuration without explicit permission

CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
PROTECTED_BRANCHES="main master production"

for BRANCH in $PROTECTED_BRANCHES; do
  if [[ "$CURRENT_BRANCH" == "$BRANCH" ]]; then
    if [[ "$STRICT_MODE" == "true" ]]; then
      echo "[CCC] VIOLATION: Direct modification on protected branch '$BRANCH'"
      exit 1
    else
      echo "[CCC] WARNING: Working directly on protected branch '$BRANCH'"
    fi
  fi
done

# --- 3. Drift detection ---
# Check if uncommitted changes have grown significantly since session start

UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
if [[ "$UNCOMMITTED" -gt 20 ]]; then
  echo "[CCC] WARNING: $UNCOMMITTED uncommitted files. Consider committing or running /ccc:anchor"
fi
