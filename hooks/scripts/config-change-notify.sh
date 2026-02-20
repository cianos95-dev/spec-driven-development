#!/usr/bin/env bash
# CCC Hook: ConfigChange
# Trigger: MCP config file (~/.mcp.json or claude_desktop_config.json) is modified
# Purpose: Inform the agent that MCP auth cache may be stale after config changes
#
# Added in Claude Code v2.1.49. This hook is informational only — it does not block.
# The agent should suggest restarting the session to pick up new MCP configurations.

set -uo pipefail

# The ConfigChange hook receives the changed file path via CLAUDE_CONFIG_FILE env var
CHANGED_FILE="${CLAUDE_CONFIG_FILE:-unknown}"

echo "[CCC] MCP config updated: $(basename "$CHANGED_FILE")"
echo "[CCC]   Auth cache may be stale. Restart session to pick up changes."
echo "[CCC]   Run /mcp to inspect MCP server status."

exit 0
