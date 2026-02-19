---
name: hook-enforcement
description: |
  Documents the actual Claude Code hooks shipped with CCC and how they enforce workflow
  constraints at runtime. Covers the circuit-breaker system, the autonomous execution loop,
  session lifecycle hooks, conformance checking, and prompt enrichment.
  Use when configuring hooks for a project, understanding what hooks enforce, debugging
  hook-related failures, or deciding which enforcement level to adopt.
  Trigger with phrases like "set up hooks", "configure enforcement", "why did the hook block me",
  "what do the hooks check", "install CCC hooks", "hook enforcement level", "circuit breaker".
---

# Hook Enforcement

Claude Code hooks enforce CCC workflow constraints at the runtime level. Unlike prompt-based rules (which are advisory), hooks make violations structurally impossible.

## Why Hooks

| Approach | Enforcement | Failure Mode |
|----------|-------------|--------------|
| CLAUDE.md rules | Advisory | Agent forgets or ignores |
| Skills (SKILL.md) | Methodology | Agent applies inconsistently |
| Hooks | Runtime | Violation blocked before execution |

## Hook Inventory

CCC ships 12 hook scripts across 7 Claude Code hook points. The table below maps every script to its trigger and purpose.

| Hook Point | Script | Purpose |
|------------|--------|---------|
| **SessionStart** | `session-start.sh` | Prereq check (git, jq, yq), spec loading, git state, stale execution state warning |
| **SessionStart** | `scripts/style-injector.sh` | Inject output style preferences into session context |
| **SessionStart** | `scripts/conformance-cache.sh` | Build conformance cache for later checks |
| **PreToolUse** | `pre-tool-use.sh` | Scope check — warn/block writes outside spec's allowed paths |
| **PreToolUse** | `scripts/circuit-breaker-pre.sh` | Block destructive ops when circuit breaker is open |
| **PostToolUse** | `post-tool-use.sh` | Audit logging, protected branch detection, drift warning |
| **PostToolUse** | `scripts/circuit-breaker-post.sh` | Detect consecutive identical errors, open circuit breaker |
| **PostToolUse** | `scripts/conformance-log.sh` | Log file writes for conformance tracking |
| **Stop** | `scripts/ccc-stop-handler.sh` | Autonomous execution loop — task advancement, safety caps, replan |
| **Stop** | `stop.sh` | Session exit checklist — git state, hygiene reminders, evidence summary |
| **Stop** | `scripts/conformance-check.sh` | Final conformance validation |
| **TeammateIdle** | `scripts/teammate-idle-gate.sh` | Gate teammate idle notifications in team workflows |
| **TaskCompleted** | `scripts/task-completed-gate.sh` | Gate task completion notifications |
| **UserPromptSubmit** | `scripts/prompt-enrichment.sh` | Enrich user prompts with context before submission |

## Circuit Breaker System

The circuit breaker is the primary runtime enforcement mechanism. It detects when an agent enters an error loop and stops it from making things worse.

### How It Works

Two scripts work together:

1. **`circuit-breaker-post.sh`** (PostToolUse) — monitors every tool result for errors. When 3+ consecutive identical errors occur on the same tool, it opens the circuit breaker.
2. **`circuit-breaker-pre.sh`** (PreToolUse) — checks the circuit breaker state before destructive operations. If the circuit is open, it blocks writes/edits/bash and allows only read-only tools.

### State File

The circuit breaker writes its state to `$PROJECT_ROOT/.ccc-circuit-breaker.json`:

```json
{
  "open": true,
  "consecutiveErrors": 3,
  "threshold": 3,
  "lastErrorSignature": "Edit:File not found at /path/to/file",
  "lastToolName": "Edit",
  "openedAt": "2026-02-19T10:30:00Z",
  "previousExecMode": "quick",
  "escalatedTo": "pair"
}
```

### Error Detection

The post hook builds an **error signature** from the tool name + first 200 chars of the error message. If the same signature repeats consecutively, the counter increments. A different error resets the counter.

- **Threshold**: 3 consecutive identical errors (configurable via `.ccc-preferences.yaml` → `circuit_breaker.threshold`)
- **Successful tool use**: Resets the counter (deletes state file if circuit is closed)
- **Circuit already open**: Warns again on each error, does not re-trigger

### Tool Classification

When the circuit is open, tools are classified as:

| Classification | Tools | Behavior |
|---------------|-------|----------|
| **Destructive** | Write, Edit, MultiEdit, NotebookEdit, Bash | Blocked (exit 2) |
| **Destructive (MCP)** | Any `mcp__*__create\|update\|delete\|push\|write\|edit\|remove\|merge` | Blocked (exit 2) |
| **Read-only** | Read, Glob, Grep, WebFetch, WebSearch, Task, TodoWrite | Allowed |

### Exec Mode Escalation

When the circuit opens and the current execution mode is `quick`, the breaker auto-escalates to `pair` (human-in-the-loop) by updating `.ccc-state.json`.

### Recovery

- **Recommended**: Use `/rewind` to undo the last few tool calls and try a different approach
- **Manual reset**: Delete `.ccc-circuit-breaker.json`

## Autonomous Execution Loop (Stop Hook)

The `ccc-stop-handler.sh` is the core loop driver for Stage 6 (Implementation). It runs as a Stop hook, reading the session transcript and deciding whether to continue execution or allow the session to end.

### Loop Mechanics

1. Reads `.ccc-state.json` for current phase, task index, iteration counts
2. Checks for human gate requirements (spec approval, review acceptance, PR review) — if a gate is pending, allows stop
3. Only drives the loop during the `execution` phase
4. Respects execution modes: `pair` and `swarm` do not auto-loop
5. Checks for `TASK_COMPLETE` signal in the last assistant output
6. Advances to the next task or retries the current one
7. Supports `REPLAN` signal for mid-execution replanning

### Safety Caps

| Cap | Default | Configurable Via |
|-----|---------|-----------------|
| Max task iterations | 5 | `.ccc-state.json` or `.ccc-preferences.yaml` |
| Max global iterations | 50 | `.ccc-state.json` or `.ccc-preferences.yaml` |
| Max replans per session | 2 | `.ccc-preferences.yaml` |

### Prompt Enrichments

The continue prompt includes configurable enrichments (all from `.ccc-preferences.yaml`):

- Subagent discipline
- Search-before-build reminders
- `.ccc-agents.md` project-specific patterns
- Prioritization framework (RICE / MoSCoW / Eisenhower)
- Eval cost profile and budget caps
- TDD and checkpoint mode-specific instructions

## Session Lifecycle Hooks

### SessionStart (`session-start.sh`)

Runs at the start of every session. Performs:

- **Prerequisite validation**: Checks git, jq (required), yq (optional). Warns if missing.
- **Spec loading**: Reads `CCC_SPEC_PATH` env var. Reports if no spec is set.
- **Codebase index freshness**: Checks `.claude/codebase-index.md` and reports its generation date.
- **Git state**: Reports current branch and uncommitted file count.
- **Stale execution state**: Warns if `.ccc-state.json` is >24h old.

### Stop (`stop.sh`)

Runs at session end (after the execution loop handler). Produces:

- Git state summary (branch, uncommitted files, unpushed commits)
- Session exit protocol checklist (status normalization, closing comments, sub-issues, project update, summary tables)
- Evidence log summary (tool execution count from today's JSONL log)
- Agent teams activity summary (if `.ccc-agent-teams-log.jsonl` exists)

### PreToolUse (`pre-tool-use.sh`)

Matches on `Write|Edit|MultiEdit|NotebookEdit`. Checks:

- File path against `CCC_ALLOWED_PATHS` (colon-separated patterns)
- In strict mode (`SDD_STRICT_MODE=true`): blocks writes outside scope
- In default mode: warns but allows

### PostToolUse (`post-tool-use.sh`)

Runs after every tool execution:

- Appends a log entry to `$LOG_DIR/tool-log-YYYYMMDD.jsonl`
- Checks if working on a protected branch (main, master, production) — blocks in strict mode, warns otherwise
- Drift warning if >20 uncommitted files

## Spec-Enforcement Hooks (Planned)

Full spec-aware enforcement — where hooks validate that every write traces to a specific acceptance criterion — is planned under CIA-396. The current pre-tool-use hook provides path-based scope checking but does not parse spec content.

See also: CIA-522 for the broader hook system improvements roadmap.

## Configuration

### hooks.json

The plugin ships `hooks/hooks.json` which registers all hooks with their matchers. Claude Code merges this with the project's `.claude/settings.json` at plugin load time.

### Environment Variables

| Variable | Used By | Default |
|----------|---------|---------|
| `CCC_SPEC_PATH` | session-start.sh | (none — spec loading skipped) |
| `CCC_PROJECT_ROOT` | ccc-stop-handler.sh | `git rev-parse --show-toplevel` |
| `SDD_PROJECT_ROOT` | Most hooks | `git rev-parse --show-toplevel` |
| `SDD_CONTEXT_THRESHOLD` | session-start.sh | 50 |
| `SDD_STRICT_MODE` | pre-tool-use.sh, post-tool-use.sh | false |
| `SDD_LOG_DIR` | post-tool-use.sh, stop.sh | `.claude/logs/` |
| `CCC_ALLOWED_PATHS` | pre-tool-use.sh | (none — all paths allowed) |

### Preferences File

`.ccc-preferences.yaml` in the project root controls execution loop behavior (gates, iteration caps, prompt enrichments, replan limits). See `examples/sample-preferences.yaml` for the full schema.

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| "Circuit is OPEN" blocks all writes | 3+ consecutive identical errors tripped the breaker | Use `/rewind` or delete `.ccc-circuit-breaker.json` |
| Hook doesn't fire | Missing executable bit or wrong path | `chmod +x` the script, verify path in hooks.json |
| Session start reports missing jq | jq not installed | `brew install jq` |
| Execution loop doesn't continue | `.ccc-state.json` missing or `phase` not `execution` | Run `/ccc:go` to initialize state |
| Loop halts unexpectedly | Safety cap reached (task or global iterations) | Check `.ccc-state.json` for iteration counts |
| Writes blocked but circuit is closed | `SDD_STRICT_MODE=true` and file outside `CCC_ALLOWED_PATHS` | Add path to `CCC_ALLOWED_PATHS` or set `SDD_STRICT_MODE=false` |

## Related

- CIA-396 — Spec-enforcement hooks (planned)
- CIA-522 — Hook system improvements roadmap
- `execution-modes` skill — Execution mode definitions referenced by the stop handler
- `execution-engine` skill — Full `/ccc:go` execution engine that initializes `.ccc-state.json`
