---
name: hook-enforcement
description: |
  Documents the Claude Code hooks shipped with the CCC plugin and what each one enforces.
  Covers session-start checks, pre/post-tool-use gates, stop hygiene, circuit breaker,
  conformance auditing, prompt enrichment, style injection, and Agent Teams hooks.
  Use when configuring hooks, understanding what a hook enforces, debugging hook failures,
  or choosing which hooks to enable for a project.
---

# Hook Enforcement

The CCC plugin ships shell-based Claude Code hooks that enforce workflow constraints at runtime. Unlike prompt-based rules (which are advisory), hooks block or enrich tool calls structurally.

## Why Hooks

| Approach | Enforcement | Failure Mode |
|----------|-------------|--------------|
| CLAUDE.md rules | Advisory | Agent forgets or ignores |
| Skills (SKILL.md) | Methodology | Agent applies inconsistently |
| Hooks | Runtime | Violation blocked before execution |

**Core principle: Claude as orchestrator, not logic engine.** SKILL.md files should orchestrate — making judgement calls and coordinating steps — while all deterministic logic lives in tested shell scripts invoked by hooks. Every time a SKILL.md embeds deterministic branching, it expands the surface area for hallucination. Moving that logic into code files (that can be unit-tested) keeps Claude in the role it excels at: resolving indeterminism. Source: Pierce Lamb Deep Trilogy — "respect the boundary between what should be code and what should be Claude."

## Hook Registry

All hooks are registered in `hooks/hooks.json`. The plugin uses nine event types:

| Event | Scripts | Purpose |
|-------|---------|---------|
| SessionStart | `session-start.sh`, `style-injector.sh`, `conformance-cache.sh` | Initialize session context, inject style preferences, cache acceptance criteria |
| PreToolUse | `pre-tool-use.sh`, `circuit-breaker-pre.sh` | Scope-check file writes, block destructive ops during error loops |
| PostToolUse | `post-tool-use.sh`, `circuit-breaker-post.sh`, `conformance-log.sh` | Audit tool usage, detect error loops, log writes for conformance |
| Stop | `ccc-stop-handler.sh`, `stop.sh`, `conformance-check.sh` | Drive task loop, report session hygiene, generate conformance report |
| SessionEnd | `ccc-session-end.sh` | Session summary, progress archival, analytics on explicit termination |
| PermissionRequest | `ccc-permission-gate.sh` | Circuit breaker + exec mode enforcement on permission dialogs |
| UserPromptSubmit | `prompt-enrichment.sh` | Inject worktree/issue context into prompts |
| TeammateIdle | `teammate-idle-gate.sh` | Prevent idle when tasks remain (Agent Teams) |
| TaskCompleted | `task-completed-gate.sh` | Validate task completion claims (Agent Teams) |

## Hook Details

### session-start.sh

**Event:** SessionStart
**Purpose:** Verify prerequisites and report session context.

What it does:

- Validates that `git`, `jq`, and `yq` are available
- Loads the active spec path from `CCC_SPEC_PATH`
- Reports git state (branch, uncommitted files)
- Warns if `.ccc-state.json` is stale (>24h old)
- Checks for `.claude/codebase-index.md` freshness

Fail-open: exits 0 on all paths. Informational only.

**Design note:** Early validation in SessionStart gives the best chance of catching environment issues before the agent consumes context on the actual task. Failing fast on missing tools is cheaper than failing mid-execution. SessionStart hooks can also output structured JSON that Claude receives at session start, enabling deterministic session-id passing without relying on `CLAUDE_ENV_FILE` (which does not persist after `/clear`). Source: Pierce Lamb Deep Trilogy — "validate early" principle and SessionStart JSON output pattern.

### style-injector.sh

**Event:** SessionStart
**Purpose:** Inject audience-aware output style instructions.

Reads the `style.explanatory` preference from `.ccc-preferences.yaml`:

| Level | Behavior |
|-------|----------|
| `terse` (default) | No injection |
| `balanced` / `detailed` | Injects `styles/explanatory.md` |
| `educational` | Injects `styles/educational.md` |

Strips YAML frontmatter from the style file and returns it via `hookSpecificOutput.additionalContext`.

### conformance-cache.sh

**Event:** SessionStart
**Purpose:** Parse acceptance criteria from the active spec for later audit.

What it does:

- Reads the spec file at `CCC_SPEC_PATH`
- Extracts unchecked checkboxes (`- [ ] text`)
- Tokenizes each criterion into keywords (lowercase, >=4 chars, stop words removed)
- Writes `.ccc-conformance-cache.json` with criteria IDs, raw text, keywords, and spec hash

Fail-open: exits silently if `CCC_SPEC_PATH` is unset or spec is missing.

### pre-tool-use.sh

**Event:** PreToolUse
**Matcher:** `Write|Edit|MultiEdit|NotebookEdit`
**Purpose:** Scope-check file writes against allowed paths.

What it does:

- Extracts `file_path` from the tool call
- If `CCC_ALLOWED_PATHS` is set, checks the file against the colon-separated path patterns
- In strict mode (`SDD_STRICT_MODE=true`): blocks out-of-scope writes (exit 1)
- In non-strict mode: logs a warning but allows the write

### circuit-breaker-pre.sh

**Event:** PreToolUse
**Matcher:** `Write|Edit|MultiEdit|NotebookEdit|Bash`
**Purpose:** Block destructive operations when an error loop is detected.

What it does:

- Reads `.ccc-circuit-breaker.json` to check if the circuit breaker is open
- Destructive tools (Write, Edit, Bash, MCP create/update/delete): **blocked** when circuit is open
- Read-only tools (Read, Glob, Grep, WebFetch, Task, TodoWrite): **allowed** even when circuit is open
- Returns `permissionDecision: "deny"` for blocked tools

### post-tool-use.sh

**Event:** PostToolUse
**Matcher:** (all tools)
**Purpose:** Audit tool execution and detect drift.

What it does:

- Appends to daily evidence log at `.claude/logs/tool-log-YYYYMMDD.jsonl`
- Checks current branch against protected branches (main, master, production)
- Warns if uncommitted file count exceeds 20 (suggests `/ccc:anchor`)
- In strict mode: blocks writes on protected branches

### circuit-breaker-post.sh

**Event:** PostToolUse
**Matcher:** (all tools)
**Purpose:** Detect consecutive identical errors and trip the circuit breaker.

What it does:

- Tracks error signatures (200-char hash of tool name + error message)
- Increments counter on consecutive identical errors
- At threshold (default 3, configurable via `.ccc-preferences.yaml`): opens circuit breaker
- Writes state to `.ccc-circuit-breaker.json`
- Auto-escalates execution mode from `quick` to `pair` (human-in-the-loop)
- Resets counter on successful tool execution

### conformance-log.sh

**Event:** PostToolUse
**Matcher:** `Write|Edit|MultiEdit|NotebookEdit`
**Purpose:** Log write operations for end-of-session conformance audit.

What it does:

- Appends a JSONL entry to `.ccc-conformance-queue.jsonl` with timestamp, tool name, file path, and parameter keys
- Only activates when `.ccc-conformance-cache.json` exists (i.e., conformance audit is active)
- Always exits 0, never blocks

### ccc-stop-handler.sh

**Event:** Stop
**Purpose:** Drive the autonomous task loop across decomposed tasks.

What it does:

- Reads `.ccc-state.json` for execution phase, task index, and iteration counts
- Checks for `TASK_COMPLETE` signal in the last assistant output
- If task incomplete: increments retry counter, generates continue prompt
- If task complete: advances to next task, resets per-task counter
- Detects `REPLAN` signal for mid-execution task regeneration (max 2 replans)
- Safety caps: global iteration limit (default 50), per-task limit (default 5)
- Allows immediate stop when awaiting human approval gates
- Reads preferences from `.ccc-preferences.yaml`

### stop.sh

**Event:** Stop
**Purpose:** Report session hygiene and activity summary.

What it does:

- Reports git state (branch, uncommitted files, unpushed commits)
- Displays session exit protocol checklist (issue normalization, evidence, sub-issues)
- Counts tool executions from today's evidence log
- Reports Agent Teams activity if `.ccc-agent-teams-log.jsonl` exists

### conformance-check.sh

**Event:** Stop
**Purpose:** Batch-audit all session writes against acceptance criteria.

What it does:

- Reads `.ccc-conformance-queue.jsonl` (writes logged during session)
- Reads `.ccc-conformance-cache.json` (acceptance criteria keywords)
- For each write: tokenizes file path and parameters, calculates keyword overlap with each criterion
- A write is "conforming" if it matches any criterion at >=50% keyword overlap
- Checks drifting files for `// ccc:suppress` comments
- Writes `.ccc-conformance-report.json` with conforming/drifting counts, drift details, and per-criterion coverage
- Cleans up queue and cache files after reporting

### ccc-session-end.sh

**Event:** SessionEnd
**Matcher:** `clear|logout|exit`
**Purpose:** Generate session summary, archive progress, and fire analytics on explicit session termination.

What it does:

- Reads `.ccc-state.json` for current task state (issue, phase, task index, exec mode)
- Collects git summary (branch, uncommitted files, unpushed commits)
- Counts files changed from today's evidence log
- Fires PostHog `session_ended` event via `posthog-capture.sh` (if the script exists)
- Archives `.ccc-progress.md` to `.ccc-progress-{timestamp}.md`
- Returns a session summary via `hookSpecificOutput.additionalContext`

Fail-open: exits 0 on all paths. Informational only.

**Distinct from Stop:** Stop fires on mid-session agent stops (task loop boundaries). SessionEnd fires only on actual session termination (user ran `/clear`, `/exit`, or logged out). The execution loop (ccc-stop-handler.sh) does NOT fire on SessionEnd, and ccc-session-end.sh does NOT fire on Stop.

### ccc-permission-gate.sh

**Event:** PermissionRequest
**Purpose:** Circuit breaker enforcement and execution mode tool filtering on permission dialogs.

What it does:

- Reads `.ccc-circuit-breaker.json` to check if the circuit breaker is open
- If circuit is open: denies the permission request with `permissionDecision: "deny"` and a message directing the user to resolve the error pattern
- If circuit is closed: checks `.ccc-state.json` for execution mode restrictions
- In `quick` mode: blocks multi-agent tools (TeamCreate, SendMessage, Task)
- In all other modes: allows all tools
- Returns `permissionDecision: "deny"` (exit 2) when blocking, or exits 0 to allow

**Relationship to PreToolUse:** PermissionRequest fires earlier than PreToolUse — on the permission dialog itself, before the user is asked. This provides a faster feedback loop: the user never sees a permission prompt for an operation that CCC would block anyway. PreToolUse (`circuit-breaker-pre.sh`) remains as a second enforcement layer for tools that bypass the permission dialog (auto-allowed tools).

### prompt-enrichment.sh

**Event:** UserPromptSubmit
**Purpose:** Inject worktree and issue context into user prompts.

What it does:

- Detects worktree sessions (checks if `.git` is a file, not a directory)
- Extracts CIA-XXX issue ID from the git branch name
- Injects context at configurable levels (`minimal`, `standard`, `full`) via `.ccc-preferences.yaml`:
  - **minimal:** Issue link only
  - **standard:** Issue link + branch name + isolation notice
  - **full:** Issue link + branch + isolation + commit conventions

### teammate-idle-gate.sh

**Event:** TeammateIdle (Agent Teams)
**Purpose:** Prevent teammates from going idle when tasks remain.

Configurable via `agent_teams.idle_gate` in `.ccc-preferences.yaml`:

- `allow` (default): always allow idle
- `block_without_tasks`: re-prompt teammate if pending tasks > 0 in `.ccc-agent-teams.json`

### task-completed-gate.sh

**Event:** TaskCompleted (Agent Teams)
**Purpose:** Validate task completion claims with basic heuristics.

Configurable via `agent_teams.task_gate` in `.ccc-preferences.yaml`:

- `off`: no validation
- `basic`: rejects if description is <=10 chars or contains error keywords (error, failed, exception, traceback, cannot, unable)

Updates `.ccc-agent-teams.json` task counters and appends to `.ccc-agent-teams-log.jsonl`.

### Hooks Not Adopted by CCC

**SubagentStop:** Fires when a subagent returns; can intercept output via the session JSONL transcript. Pierce Lamb's Deep Trilogy uses this to extract subagent-written content and write it to disk without consuming main-session context. CCC does not adopt this pattern because it couples to the internal JSONL schema, which is undocumented and subject to change. CCC instead uses subagent return discipline (see context-management skill) to control what flows back to the main session. Source: Pierce Lamb Deep Trilogy — SubagentStop for output interception, evaluated and deferred due to schema coupling risk.

## State Files

The hooks use these state files in the project root:

| File | Purpose | Lifecycle |
|------|---------|-----------|
| `.ccc-state.json` | Task loop state (phase, task index, iterations) | Persistent across sessions |
| `.ccc-circuit-breaker.json` | Error loop detection state | Cleared on reset |
| `.ccc-agent-teams.json` | Agent Teams task counters | Persistent |
| `.ccc-preferences.yaml` | User preferences for all hooks | User-managed |
| `.ccc-conformance-cache.json` | Acceptance criteria keywords | Session-scoped, cleared on Stop |
| `.ccc-conformance-queue.jsonl` | Write event buffer | Session-scoped, cleared on Stop |
| `.ccc-conformance-report.json` | End-of-session conformance audit | Generated on Stop |
| `.ccc-agent-teams-log.jsonl` | Task completion audit trail | Append-only |
| `.claude/logs/tool-log-YYYYMMDD.jsonl` | Daily tool evidence log | Daily rotation |

## Fail-Open Design

All hooks exit 0 when prerequisites or input files are missing. Only two hooks intentionally block operations:

- **circuit-breaker-pre.sh**: denies destructive tools when circuit is open
- **task-completed-gate.sh**: rejects incomplete task completion claims (when gate is `basic`)

## Environment Variables

| Variable | Used By | Purpose |
|----------|---------|---------|
| `CCC_SPEC_PATH` | conformance-cache.sh, session-start.sh | Path to active spec file |
| `CCC_ALLOWED_PATHS` | pre-tool-use.sh | Colon-separated allowed write paths |
| `CCC_PROJECT_ROOT` | ccc-stop-handler.sh | Project root directory |
| `CLAUDE_PLUGIN_ROOT` | style-injector.sh | Plugin installation directory |
| `SDD_STRICT_MODE` | pre-tool-use.sh, post-tool-use.sh | Enable strict enforcement |
| `SDD_LOG_DIR` | post-tool-use.sh, stop.sh | Directory for evidence logs |
| `SDD_PROJECT_ROOT` | session-start.sh, stop.sh | Project root (legacy alias) |

## Installation

1. Install the CCC plugin — hooks are registered via `hooks/hooks.json` automatically
2. Create `.ccc-preferences.yaml` in your project root to configure hook behavior
3. Set `CCC_SPEC_PATH` if using conformance auditing
4. Set `CCC_ALLOWED_PATHS` if using write scope enforcement

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Hook blocks all writes | Circuit breaker is open | Delete `.ccc-circuit-breaker.json` or resolve the error loop |
| Hook doesn't fire | Script missing executable bit | `chmod +x` the script, verify path in hooks.json |
| Session start slow | Too many prereq checks failing | Ensure `git`, `jq`, `yq` are installed |
| False drift in conformance report | Write doesn't match any acceptance criterion keywords | Add `// ccc:suppress` comment to the file or broaden the spec's acceptance criteria |
| Stop hook keeps re-entering session | ccc-stop-handler.sh driving task loop | Check `.ccc-state.json` for task progress; adjust iteration caps in preferences |
