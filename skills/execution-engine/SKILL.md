---
name: execution-engine
description: |
  Autonomous task execution loop powered by a stop hook. Dispatches decomposed tasks one at a time with fresh context per task, respects human approval gates, syncs Linear status, and maintains an append-only progress log.
  Use when understanding the task loop, debugging execution state, resuming interrupted sessions, or configuring execution parameters.
  Trigger with phrases like "how does the execution loop work", "task loop configuration", "stop hook behavior", "resume execution", "execution state", "progress tracking", "TASK_COMPLETE signal", "task iteration budget".
---

# Execution Engine

The execution engine is the autonomous loop that powers Stage 6 (Implementation) of the CCC funnel. It uses a Claude Code stop hook to intercept session exits and re-feed the next task, giving each task a fresh context window. This prevents drift and context accumulation across multi-task implementations.

## Core Design

Three control mechanisms keep the loop safe:

| Mechanism | Purpose | Default |
|-----------|---------|---------|
| **Gate pauses** | Stop the loop when a human approval gate is reached | Gates 1, 2, 3 per spec-workflow |
| **Retry budget** | Cap retries per task before escalating to a human | 5 iterations per task |
| **Safety cap** | Hard limit on total loop iterations across all tasks | 50 global iterations |

The loop is designed for unattended execution. A human starts it with `/ccc:go`, walks away, and returns to find either completed work or a clear explanation of where and why the loop stopped.

> See [references/replan-protocol.md](references/replan-protocol.md) for the Disposable Plan Principle, authority hierarchy, REPLAN signal, and replan limits.

> See [references/retry-budget.md](references/retry-budget.md) for per-task iteration tracking, escalation sequence, and budget reset rules.

## How It Works

### Step-by-step flow

1. **`/ccc:go` or `/ccc:start`** creates `.ccc-state.json` with the task list from `/ccc:decompose`. The agent begins executing the first task (taskIndex 0).

2. **Agent executes the task.** It reads `.ccc-progress.md` for context from prior tasks, implements the current task, runs verification (tests, lint, build), commits changes, and updates the progress log.

3. **Agent signals `TASK_COMPLETE`.** This exact string (case-sensitive) must appear in the agent's response after all acceptance criteria for the task are met.

4. **The stop hook intercepts the session exit.** It detects `TASK_COMPLETE` in the transcript and:
   - Increments `taskIndex` in `.ccc-state.json`
   - Resets `taskIteration` to 1
   - Increments `globalIteration`
   - Returns a `block` decision with the next task's prompt injected

5. **Claude Code restarts with fresh context.** The new session receives the next task prompt, reads `.ccc-progress.md` for accumulated context from prior tasks, and begins execution.

6. **Repeat** until all tasks complete, a gate is reached, or a budget limit is hit.

### What "fresh context" means

Each task gets a clean context window. The stop hook's `block` decision causes Claude Code to restart rather than continue, which means:

- No stale assumptions from prior tasks leak into the new session
- Context budget resets to zero for each task
- The only carry-forward is the explicit `.ccc-progress.md` file
- Drift prevention is structural, not prompt-based

### Intra-task progress tracking (TodoWrite)

At the start of each task session, create a TodoWrite list from the task's acceptance criteria. This provides visible progress tracking within a single task execution and helps the agent stay on track.

```
TodoWrite([
  { content: "Acceptance criterion 1", status: "pending", activeForm: "Implementing criterion 1" },
  { content: "Acceptance criterion 2", status: "pending", activeForm: "Implementing criterion 2" },
  { content: "Run verification (tests, lint, build)", status: "pending", activeForm: "Running verification" },
  { content: "Commit changes", status: "pending", activeForm: "Committing changes" },
  { content: "Update .ccc-progress.md", status: "pending", activeForm: "Updating progress log" }
])
```

Mark each item as `completed` when verified. The last three items (verify, commit, update progress) are standard for every task.

This tracking is **ephemeral** -- it disappears when the session ends and `TASK_COMPLETE` fires. The persistent record lives in `.ccc-progress.md`.

## State Files

The engine maintains two files in the project root. Both are gitignored.

### `.ccc-state.json` -- Execution Loop State

```json
{
  "linearIssue": "CIA-042",
  "phase": "execution",
  "taskIndex": 0,
  "totalTasks": 8,
  "taskIteration": 1,
  "maxTaskIterations": 5,
  "globalIteration": 0,
  "maxGlobalIterations": 50,
  "executionMode": "tdd",
  "gatesPassed": [1, 2],
  "awaitingGate": null,
  "specPath": "docs/specs/user-preferences.md",
  "replanCount": 0,
  "createdAt": "2026-02-15T12:00:00Z",
  "lastUpdatedAt": "2026-02-15T12:30:00Z"
}
```

**Field reference:**

| Field | Type | Description |
|-------|------|-------------|
| `linearIssue` | string | The Linear issue ID being worked on. Used for status syncing. |
| `phase` | enum | Current funnel phase: `intake`, `spec`, `review`, `decompose`, `execution`, `replan`, `verification`, `closure`. The engine operates during `execution` and `replan`. |
| `taskIndex` | number | 0-based index of the current task in the decomposed list. |
| `totalTasks` | number | Total number of decomposed tasks. Loop completes when `taskIndex >= totalTasks`. |
| `taskIteration` | number | Current retry attempt for this task (1-based). Resets to 1 when advancing to the next task. |
| `maxTaskIterations` | number | Maximum retries before the task is blocked and escalated. Default 5. |
| `globalIteration` | number | Running count of total loop iterations across all tasks. Never resets. |
| `maxGlobalIterations` | number | Safety cap on total iterations. Default 50. |
| `executionMode` | enum | The exec mode for this task set: `quick`, `tdd`, `pair`, `checkpoint`, `swarm`. |
| `gatesPassed` | number[] | Array of gate numbers (1, 2, 3) already passed by this issue. |
| `awaitingGate` | number \| null | If set, the loop is paused waiting for this gate. `null` means no gate is blocking. |
| `specPath` | string | Relative path to the spec file. |
| `replanCount` | number | Number of times the agent has replanned during this execution. |
| `createdAt` | ISO 8601 | When execution started. |
| `lastUpdatedAt` | ISO 8601 | When the state file was last modified. |

### `.ccc-progress.md` -- Append-Only Memory

```markdown
## Goal
Add preference sync so users can save and restore their settings across devices.

## Linear Issue
CIA-042: Add user preference sync

## Completed Tasks
- [x] Task 0: Add schema migration -- abc1234 (2 min)
- [x] Task 1: Implement API endpoint -- def5678 (5 min)

## Learnings
- [2026-02-15 12:30] Discovered existing preference utils in src/lib/preferences.ts
- [2026-02-15 12:45] Test pattern: use factory helpers from tests/factories/

## Current Task
Task 2: Build preference sync service

## Blocked / Flagged
(none)
```

| Section | Purpose | Who Writes |
|---------|---------|------------|
| Goal | One-sentence summary from the spec. Set once. | `/ccc:go` |
| Completed Tasks | Append-only log with commit hash and duration. | Agent, before TASK_COMPLETE |
| Learnings | Discoveries for future tasks. | Agent, during execution |
| Current Task | Overwritten each session. | Agent, at session start |
| Blocked / Flagged | Non-empty means loop should pause. | Agent, when blocker found |

**Critical rule:** Completed Tasks and Learnings are append-only. Never remove or edit prior entries.

## The TASK_COMPLETE Signal

The agent must output `TASK_COMPLETE` (exact string, case-sensitive) in its response when a task is done.

### Pre-signal checklist

Before outputting `TASK_COMPLETE`, the agent must verify:

1. **All acceptance criteria for the task are met.** Not "most" -- all of them.
2. **Verification passes.** Run tests, lint, and build. All must pass.
3. **Changes are committed.** Unstaged work will be lost when context resets.
4. **`.ccc-progress.md` is updated.** Add to Completed Tasks with commit hash and duration. Note any Learnings.

If `TASK_COMPLETE` is missing, the stop hook assumes incomplete, increments `taskIteration` (consuming retry budget), and re-injects the same task. If premature, the hook trusts the signal and advances — failures surface during verification (Stage 7).

## Execution Mode Behavior in the Loop

| Mode | Loop Active | Special Handling |
|------|-------------|------------------|
| `quick` | Yes | Standard loop, minimal ceremony |
| `tdd` | Yes | "Follow red-green-refactor" prepended to every task prompt |
| `pair` | **No** | Always allow stop. Human-in-the-loop means no auto-continuation. |
| `checkpoint` | Yes, with pauses | Pauses at checkpoint milestones defined in the spec |
| `swarm` | **No** | Swarm manages its own parallelism via subagents. |

## Gate Integration

The stop hook respects the three human approval gates from spec-workflow.

| Gate | When It Blocks | How It Resumes |
|------|---------------|----------------|
| Gate 1 (Approve spec) | Before execution starts | Must be in `gatesPassed` before `/ccc:go` creates state |
| Gate 2 (Accept review) | Before execution starts | Must be in `gatesPassed` before `/ccc:go` creates state |
| Gate 3 (Review PR) | After all tasks complete | Agent opens PR, sets `awaitingGate: 3`, loop stops |

Gates 1 and 2 are preconditions. Gate 3 is a postcondition.

> See [references/configuration.md](references/configuration.md) for environment variables, hook registration, resume protocol, Linear syncing, and troubleshooting.

## Quality Gate Hooks

Two hooks fire during execution to enforce quality before the loop advances. Both read from `.ccc-state.json` to understand the current execution context.

### TaskCompleted Gate (`hooks/scripts/task-completed-gate.sh`)

Fires when a teammate calls `TaskUpdate` to mark a task complete. Validates output quality before allowing the completion to register and the `pending_tasks` counter to decrement.

**Validation flow:**

1. **Basic checks** (always active, `task_gate: basic`):
   - Task description is non-empty (>10 chars)
   - No error indicator keywords (`error`, `failed`, `exception`, `traceback`, etc.)

2. **Execution mode checks** (read from `.ccc-state.json → executionMode`):

   | Mode | Gate Behavior |
   |------|--------------|
   | `quick` | Basic checks only — any non-error completion passes |
   | `tdd` | Requires test files in recent git diff (`*test*` or `*spec*` patterns). Checks both staged/unstaged changes and last 2 commits. Blocks with a clear message if no tests found. |
   | `pair` | Requires review artifacts — `Co-Authored-By` in recent commits or review notes in `.ccc-progress.md`. Blocks if neither is present. |
   | `checkpoint` | Basic checks only |
   | `swarm` | Basic checks only |

3. **State update** (on pass): Decrements `pending_tasks` and increments `completed_tasks` in `.ccc-agent-teams.json`. Appends an audit entry to `.ccc-agent-teams-log.jsonl` with the Linear issue from `.ccc-state.json`.

**Preference control:** Set `agent_teams.task_gate: off` in `.ccc-preferences.yaml` to disable all validation (useful for spike work or when tests live in a separate repo).

### TeammateIdle Gate (`hooks/scripts/teammate-idle-gate.sh`)

Fires when a teammate finishes its turn. Checks two state sources to determine if work remains before allowing the agent to go idle.

**Check sequence** (when `idle_gate: block_without_tasks`):

1. **`.ccc-agent-teams.json`**: If `pending_tasks > 0` for the active team, block with a prompt to claim a task from the task list.

2. **`.ccc-state.json`**: If `phase == "execution"` and `taskIndex < totalTasks`, block with the remaining task count. This catches execution loop progress that hasn't yet been reflected in the agent-teams counter.

Both checks must pass (or their state files must be absent) before the agent is allowed to idle. Missing state files are treated as "no pending work" — graceful degradation.

**Preference control:** Set `idle_gate: allow` (default) to disable blocking entirely. Set `idle_gate: block_without_tasks` to enable the dual-source check.

### Feedback Loop to `.ccc-state.json`

The hooks do not write to `.ccc-state.json` directly — that file is owned by the stop hook (`ccc-stop-handler.sh`). Instead:

- **TaskCompleted gate** writes to `.ccc-agent-teams.json` (task counters) and `.ccc-agent-teams-log.jsonl` (audit trail)
- **TeammateIdle gate** reads from `.ccc-state.json` (execution loop progress) and `.ccc-agent-teams.json` (swarm task counters)
- The stop hook advances `taskIndex` in `.ccc-state.json` when `TASK_COMPLETE` is detected

This separation keeps the execution loop state authoritative in `.ccc-state.json` while agent-teams swarm state lives in `.ccc-agent-teams.json`.

## Cross-Skill References

- **spec-workflow** -- Defines the 9-stage funnel this engine powers (Stage 6: Implementation)
- **execution-modes** -- Defines the 5 modes and their decision heuristic; determines loop behavior
- **issue-lifecycle** -- Defines closure rules triggered after execution completes (Stage 7.5)
- **context-management** -- Defines delegation tiers used during task execution within each session
- **drift-prevention** -- The `/ccc:anchor` protocol runs automatically at the start of each task in the loop
- **hook-enforcement** -- Defines the broader hook framework; the execution engine extends the Stop hook
