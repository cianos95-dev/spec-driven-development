#!/usr/bin/env bash
# CCC Hook: Stop
# Trigger: Session ends (graceful exit)
# Purpose: Run hygiene check, remind about status updates, generate handoff summary
#
# Install: Copy to your project's .claude/hooks/stop.sh
# Configure in .claude/settings.json:
#   "hooks": { "Stop": [{ "matcher": "", "hooks": [{ "type": "command", "command": ".claude/hooks/stop.sh" }] }] }
#
# Environment variables:
#   SDD_LOG_DIR       - Directory for evidence logs (default: .claude/logs/)
#   SDD_PROJECT_ROOT  - Project root directory (default: git root)

set -euo pipefail

PROJECT_ROOT="${SDD_PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
LOG_DIR="${SDD_LOG_DIR:-$PROJECT_ROOT/.claude/logs}"

echo "============================================"
echo "[CCC] Session Exit Checklist"
echo "============================================"

# --- 1. Git state summary ---

BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")
UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
UNPUSHED=$(git log --oneline @{upstream}..HEAD 2>/dev/null | wc -l | tr -d ' ')

echo ""
echo "Git State:"
echo "  Branch: $BRANCH"
echo "  Uncommitted files: $UNCOMMITTED"
echo "  Unpushed commits: $UNPUSHED"

if [[ "$UNCOMMITTED" -gt 0 ]]; then
  echo "  WARNING: You have uncommitted changes"
fi

if [[ "$UNPUSHED" -gt 0 ]]; then
  echo "  WARNING: You have unpushed commits"
fi

# --- 2. Session hygiene reminders ---

echo ""
echo "Session Exit Protocol:"
echo "  [ ] Normalize all touched issue statuses (In Progress / Done / Blocked)"
echo "  [ ] Add closing comments with evidence to Done items"
echo "  [ ] Create sub-issues for any discovered out-of-scope work"
echo "  [ ] Post daily project update if issue statuses changed"
echo "  [ ] Present session summary tables (issues + documents)"

# --- 3. Evidence log summary ---

TODAY_LOG="$LOG_DIR/tool-log-$(date +%Y%m%d).jsonl"
if [[ -f "$TODAY_LOG" ]]; then
  TOOL_COUNT=$(wc -l < "$TODAY_LOG" | tr -d ' ')
  echo ""
  echo "Session Activity:"
  echo "  Tool executions logged: $TOOL_COUNT"
fi

echo ""
echo "============================================"
echo "[CCC] Remember: Status normalization is mandatory"
echo "============================================"
