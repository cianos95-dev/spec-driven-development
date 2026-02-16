---
name: hook-enforcement
description: |
  Claude Code hook patterns that enforce CCC workflow constraints at the runtime level.
  Covers session-start context loading, pre-tool-use spec alignment checks, post-tool-use
  ownership boundary enforcement, and session-end hygiene automation.
  Use when configuring hooks for a project, understanding what hooks enforce, debugging
  hook-related failures, or deciding which enforcement level to adopt.
  Trigger with phrases like "set up hooks", "configure enforcement", "why did the hook block me",
  "what do the hooks check", "install CCC hooks", "hook enforcement level".
---

# Hook Enforcement

Claude Code hooks enforce CCC workflow constraints at the runtime level. Unlike prompt-based rules (which are advisory), hooks make violations structurally impossible.

## Why Hooks

Prompt-based workflow rules have a fundamental limitation: they rely on the agent's compliance. A careless agent can skip steps, forget context, or drift from the spec without any structural barrier. Hooks provide that barrier.

| Approach | Enforcement | Failure Mode |
|----------|-------------|--------------|
| CLAUDE.md rules | Advisory | Agent forgets or ignores |
| Skills (SKILL.md) | Methodology | Agent applies inconsistently |
| Hooks | Runtime | Violation blocked before execution |

## Hook Inventory

### SessionStart Hook

**Trigger:** Session begins
**Purpose:** Establish session context and constraints before any work happens

What it enforces:
- Loads the active spec (from frontmatter `linear` field) into session context
- Verifies context budget is within threshold
- Sets ownership scope (which issues/files the agent can modify)
- Checks for stale context from previous sessions

Configuration:
```json
{
  "hooks": {
    "SessionStart": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": ".claude/hooks/session-start.sh"
      }]
    }]
  }
}
```

### PreToolUse Hook

**Trigger:** Before any file write operation
**Purpose:** Verify the write aligns with the active spec's acceptance criteria

What it enforces:
- File being written is within the spec's scope (expected files/modules)
- Changes are traceable to at least one acceptance criterion
- No writes to files owned by other issues or outside the current scope

Configuration:
```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Write|Edit|MultiEdit|NotebookEdit",
      "hooks": [{
        "type": "command",
        "command": ".claude/hooks/pre-tool-use.sh"
      }]
    }]
  }
}
```

### PostToolUse Hook

**Trigger:** After tool execution completes
**Purpose:** Check for ownership boundary violations and log evidence

What it enforces:
- No ownership boundary violations (e.g., modifying human-owned fields)
- Evidence logging for audit trail
- Drift detection after significant changes

Configuration:
```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": ".claude/hooks/post-tool-use.sh"
      }]
    }]
  }
}
```

### Stop Hook

**Trigger:** Session ends (graceful exit)
**Purpose:** Run hygiene checks and generate handoff

What it enforces:
- Status normalization across all touched issues
- Closing comments with evidence on Done items
- Handoff summary generated for the next session
- Context budget report

Configuration:
```json
{
  "hooks": {
    "Stop": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": ".claude/hooks/stop.sh"
      }]
    }]
  }
}
```

## Enforcement Levels

Not every project needs all four hooks. Choose the level that matches your workflow:

| Level | Hooks Enabled | Best For |
|-------|---------------|----------|
| **Minimal** | SessionStart + Stop | Solo projects, low ceremony |
| **Standard** | SessionStart + Stop + PostToolUse | Most projects |
| **Strict** | All four | Multi-agent, regulated, or high-stakes |

## Installation

1. Copy desired hook scripts from the plugin's `hooks/` directory to your project's `.claude/hooks/`
2. Add hook configuration to your project's `.claude/settings.json`
3. Test each hook independently before enabling the full set
4. Monitor hook output for false positives and adjust matchers as needed

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Hook blocks all writes | Matcher too broad | Narrow the `matcher` pattern |
| Hook doesn't fire | Wrong path or missing executable bit | `chmod +x` the script, verify path |
| Session start slow | Hook loading too much context | Reduce spec size or cache the load |
| False positive on ownership | File shared across specs | Add to hook's allowlist |

## Customization

Each hook script accepts environment variables for configuration:

- `CCC_SPEC_PATH` -- Path to active spec file
- `SDD_CONTEXT_THRESHOLD` -- Context budget warning threshold (default: 50%)
- `SDD_STRICT_MODE` -- Enable strict enforcement (default: false)
- `SDD_LOG_DIR` -- Directory for evidence logs
