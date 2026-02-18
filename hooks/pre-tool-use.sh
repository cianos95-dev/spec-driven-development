#!/usr/bin/env bash
# CCC Hook: PreToolUse
# Trigger: Before file write operations (Write, Edit, MultiEdit, NotebookEdit)
# Purpose: Verify write aligns with active spec's acceptance criteria and scope
#
# Install: Copy to your project's .claude/hooks/pre-tool-use.sh
# Configure in .claude/settings.json:
#   "hooks": { "PreToolUse": [{ "matcher": "Write|Edit|MultiEdit|NotebookEdit", "hooks": [{ "type": "command", "command": ".claude/hooks/pre-tool-use.sh" }] }] }
#
# This hook receives tool call details via stdin as JSON.
#
# Environment variables:
#   CCC_SPEC_PATH     - Path to active spec file
#   SDD_STRICT_MODE   - "true" to block writes outside spec scope (default: false)
#   CCC_ALLOWED_PATHS - Colon-separated list of allowed path patterns

set -euo pipefail

STRICT_MODE="${SDD_STRICT_MODE:-false}"

# Read tool call details from stdin
TOOL_INPUT=$(cat)

# Extract the file path being written to
# Uses jq for reliable JSON parsing (consistent with circuit-breaker hooks)
if command -v jq &>/dev/null; then
  FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // .filePath // empty' 2>/dev/null || echo "")
else
  # Fallback if jq not available
  FILE_PATH=$(echo "$TOOL_INPUT" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
fi
FILE_PATH="${FILE_PATH:-}"

if [[ -z "$FILE_PATH" ]]; then
  # Could not determine file path -- allow the operation
  exit 0
fi

# --- 1. Check against allowed paths ---

if [[ -n "${CCC_ALLOWED_PATHS:-}" ]]; then
  ALLOWED=false
  IFS=':' read -ra PATHS <<< "$CCC_ALLOWED_PATHS"
  for PATTERN in "${PATHS[@]}"; do
    if [[ "$FILE_PATH" == $PATTERN ]]; then
      ALLOWED=true
      break
    fi
  done

  if [[ "$ALLOWED" == "false" ]] && [[ "$STRICT_MODE" == "true" ]]; then
    echo "[CCC] BLOCKED: Write to $FILE_PATH is outside spec scope"
    echo "[CCC] Allowed paths: $CCC_ALLOWED_PATHS"
    exit 1
  elif [[ "$ALLOWED" == "false" ]]; then
    echo "[CCC] WARNING: Write to $FILE_PATH is outside spec scope"
  fi
fi

# --- 2. Log the write for audit trail ---

echo "[CCC] Pre-write check passed: $FILE_PATH"
