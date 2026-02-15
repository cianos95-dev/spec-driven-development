---
name: execution-engine
description: |
  Autonomous task execution loop powered by a stop hook. Dispatches decomposed tasks one at a time with fresh context per task, respects human approval gates, syncs Linear status, and maintains an append-only progress log.
  Use when understanding the task loop, debugging execution state, resuming interrupted sessions, or configuring execution parameters.
  Trigger with phrases like "how does the execution loop work", "task loop configuration", "stop hook behavior", "resume execution", "execution state", "progress tracking", "TASK_COMPLETE signal", "task iteration budget".
---

# Execution Engine

The execution engine is the autonomous loop that powers Stage 6 (Implementation) of the SDD funnel. It uses a Claude Code stop hook to intercept session exits and re-feed the next task, giving each task a fresh context window. This prevents drift and context accumulation across multi-task implementations.

## Core Design

Three control mechanisms keep the loop safe:

| Mechanism | Purpose | Default |
|-----------|---------|---------|
| **Gate pauses** | Stop the loop when a human approval gate is reached | Gates 1, 2, 3 per spec-workflow |
| **Retry budget** | Cap retries per task before escalating to a human | 5 iterations per task |
| **Safety cap** | Hard limit on total loop iterations across all tasks | 50 global iterations |

The loop is designed for unattended execution. A human starts it with `/sdd:go`, walks away, and returns to find either completed work or a clear explanation of where and why the loop stopped.

## How It Works

### Step-by-step flow

1. **`/sdd:go` or `/sdd:start`** creates `.sdd-state.json` with the task list from `/sdd:decompose`. The agent begins executing the first task (taskIndex 0).

2. **Agent executes the task.** It reads `.sdd-progress.md` for context from prior tasks, implements the current task, runs verification (tests, lint, build), commits changes, and updates the progress log.

3. **Agent signals `TASK_COMPLETE`.** This exact string (case-sensitive) must appear in the agent's response after all acceptance criteria for the task are met.

4. **The stop hook intercepts the session exit.** It detects `TASK_COMPLETE` in the transcript and:
   - Increments `taskIndex` in `.sdd-state.json`
   - Resets `taskIteration` to 1
   - Increments `globalIteration`
   - Returns a `block` decision with the next task's prompt injected

5. **Claude Code restarts with fresh context.** The new session receives the next task prompt, reads `.sdd-progress.md` for accumulated context from prior tasks, and begins execution.

6. **Repeat** until all tasks complete, a gate is reached, or a budget limit is hit.

### What "fresh context" means

Each task gets a clean context window. The stop hook's `block` decision causes Claude Code to restart rather than continue, which means:

- No stale assumptions from prior tasks leak into the new session
- Context budget resets to zero for each task
- The only carry-forward is the explicit `.sdd-progress.md` file
- Drift prevention is structural, not prompt-based

## State Files

The engine maintains two files in the project root. Both are gitignored.

### `.sdd-state.json` -- Execution Loop State

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
  "createdAt": "2026-02-15T12:00:00Z",
  "lastUpdatedAt": "2026-02-15T12:30:00Z"
}
```

**Field reference:**

| Field | Type | Description |
|-------|------|-------------|
| `linearIssue` | string | The Linear issue ID being worked on. Used for status syncing. |
| `phase` | enum | Current funnel phase: `intake`, `spec`, `review`, `decompose`, `execution`, `verification`, `closure`. The engine only operates during `execution`. |
| `taskIndex` | number | 0-based index of the current task in the decomposed list. |
| `totalTasks` | number | Total number of decomposed tasks. Loop completes when `taskIndex >= totalTasks`. |
| `taskIteration` | number | Current retry attempt for this task (1-based). Resets to 1 when advancing to the next task. |
| `maxTaskIterations` | number | Maximum retries before the task is blocked and escalated. Default 5, which accommodates the SDD retry budget of 2 failed approaches plus recovery attempts. |
| `globalIteration` | number | Running count of total loop iterations across all tasks. Never resets. |
| `maxGlobalIterations` | number | Safety cap on total iterations. Default 50. Prevents runaway loops. |
| `executionMode` | enum | The exec mode for this task set: `quick`, `tdd`, `pair`, `checkpoint`, `swarm`. Inherited from the spec frontmatter. |
| `gatesPassed` | number[] | Array of gate numbers (1, 2, 3) already passed by this issue. Gates are passed before execution begins. |
| `awaitingGate` | number \| null | If set, the loop is paused waiting for this gate to be approved. `null` means no gate is blocking. |
| `specPath` | string | Relative path to the spec file. The agent reads this for acceptance criteria. |
| `createdAt` | ISO 8601 | When the state file was created (execution started). |
| `lastUpdatedAt` | ISO 8601 | When the state file was last modified by the stop hook. |

### `.sdd-progress.md` -- Append-Only Memory

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

**Sections:**

| Section | Purpose | Who Writes |
|---------|---------|------------|
| Goal | One-sentence summary from the spec. Set once at creation. | `/sdd:go` |
| Linear Issue | Issue ID and title for traceability. Set once at creation. | `/sdd:go` |
| Completed Tasks | Append-only log of finished tasks with commit hash and duration. | Agent, before signaling TASK_COMPLETE |
| Learnings | Discoveries that future tasks should know about: file locations, patterns, gotchas. | Agent, during task execution |
| Current Task | The task currently being worked on. Updated by each new session. | Agent, at session start |
| Blocked / Flagged | Items requiring human attention. Non-empty means the loop should pause. | Agent, when a blocker is found |

**Critical rule:** This file is append-only for Completed Tasks and Learnings. Never remove or edit prior entries. Current Task and Blocked / Flagged are overwritten each session.

## Execution Mode Behavior in the Loop

The execution mode determines how the stop hook behaves and what gets injected into each task prompt.

| Mode | Loop Active | Continue Prompt Additions | Special Handling |
|------|-------------|--------------------------|------------------|
| `quick` | Yes | None | Standard loop, minimal ceremony |
| `tdd` | Yes | "Follow red-green-refactor. Write a failing test first." | TDD instruction prepended to every task prompt |
| `pair` | **No** | N/A | Loop disabled. Always allow stop. Human-in-the-loop means no automatic continuation. |
| `checkpoint` | Yes, with pauses | "Check if this task crosses a checkpoint milestone." | Pauses at checkpoint milestones defined in the spec |
| `swarm` | **No** | N/A | Loop disabled. Swarm manages its own parallelism via subagents. Stop hook defers to swarm orchestration. |

**Why `pair` and `swarm` disable the loop:**

- `pair` is human-in-the-loop by definition. Automatically continuing would bypass the human participant.
- `swarm` uses parallel subagents, not sequential sessions. The stop hook's sequential restart model does not apply.

For both modes, the stop hook returns `allow` (normal session end) instead of `block` (restart with next task).

## Gate Integration

The stop hook respects the three human approval gates defined in the spec-workflow skill.

### How gates interact with the loop

1. Before starting execution, `/sdd:go` checks which gates have been passed and records them in `gatesPassed`.
2. During execution, if the agent reaches a point that requires a gate (e.g., all tasks done, PR needs review), it sets `awaitingGate` and the hook allows stop.
3. The human reviews and approves the gate outside the loop.
4. After approval, the human (or a follow-up command) updates `gatesPassed` and clears `awaitingGate`.
5. `/sdd:go` resumes from where the loop paused.

### Gate timing in the execution phase

| Gate | When It Blocks | How It Resumes |
|------|---------------|----------------|
| Gate 1 (Approve spec) | Before execution starts | Must be in `gatesPassed` before `/sdd:go` will create state |
| Gate 2 (Accept review) | Before execution starts | Must be in `gatesPassed` before `/sdd:go` will create state |
| Gate 3 (Review PR) | After all tasks complete | Agent opens PR, sets `awaitingGate: 3`, loop stops. Human approves PR, then runs `/sdd:go` to trigger verification and closure. |

Gates 1 and 2 are preconditions -- they must already be passed before the execution engine activates. Gate 3 is a postcondition -- it triggers after all execution tasks are done.

## Retry Budget

The execution engine enforces the SDD retry budget at the task level.

### Per-task iteration tracking

Each time the stop hook restarts a session for the same task (because `TASK_COMPLETE` was not found in the transcript), it increments `taskIteration`.

| Iteration | What Happens |
|-----------|-------------|
| 1 | First attempt. Normal execution. |
| 2 | Second attempt. Agent should try a different approach. |
| 3 | Third attempt. Agent has exhausted the SDD retry budget of 2 failed approaches. The continue prompt includes a warning: "Two approaches have failed. Document failures in progress log and try a fundamentally different strategy." |
| 4 | Fourth attempt. Escalation warning injected: "This is your last attempt before the task is blocked. If you cannot complete it, add to Blocked / Flagged in the progress log." |
| 5 (maxTaskIterations) | Hook blocks with an error. The loop stops. A message tells the user to fix the task manually, then resume with `/sdd:go`. |

### What counts as an "iteration"

An iteration is one complete session for a single task. If the agent crashes mid-task, that counts as an iteration (the stop hook increments regardless of why the session ended without `TASK_COMPLETE`).

### Budget reset

`taskIteration` resets to 1 when the task advances (i.e., `TASK_COMPLETE` is found and `taskIndex` increments). The budget is per-task, not cumulative.

## The TASK_COMPLETE Signal

The agent must output `TASK_COMPLETE` (exact string, case-sensitive) in its response when a task is done. The stop hook greps the transcript for this signal.

### Pre-signal checklist

Before outputting `TASK_COMPLETE`, the agent must verify:

1. **All acceptance criteria for the task are met.** Not "most" or "the important ones" -- all of them.
2. **Verification passes.** Run tests, lint, and build. All must pass.
3. **Changes are committed.** Unstaged or uncommitted work will be lost when the context resets.
4. **`.sdd-progress.md` is updated.** Add the task to Completed Tasks with commit hash and duration. Note any Learnings discovered.

### What happens if TASK_COMPLETE is missing

If the session ends without `TASK_COMPLETE` in the transcript:

- The stop hook assumes the task is incomplete
- `taskIteration` increments (retry budget consumed)
- The same task is re-injected on the next restart
- After `maxTaskIterations`, the loop blocks

### What happens if TASK_COMPLETE is premature

If the agent signals `TASK_COMPLETE` but the task is not actually done (tests failing, criteria unmet), the stop hook advances to the next task anyway. The failure surfaces later when dependent tasks break or during verification (Stage 7). This is why the pre-signal checklist is critical -- the hook trusts the signal.

## Resuming After Interruption

The execution engine is designed to survive interruptions gracefully.

### Interruption scenarios

| Scenario | State Preserved | Resume Behavior |
|----------|----------------|-----------------|
| Agent crashes mid-task | `.sdd-state.json` points to current task, `taskIteration` not yet incremented | `/sdd:go` resumes from current task. Work since last commit is lost. |
| Manual stop (Ctrl+C) | Same as crash | Same as crash |
| Context exhaustion | Stop hook fires, increments `taskIteration` | `/sdd:go` resumes, retrying current task with fresh context |
| Machine restart | State files persist on disk | `/sdd:go` resumes from last known position |

### Resume protocol

1. Run `/sdd:go` in the project directory.
2. The command reads `.sdd-state.json` and determines the current position.
3. If `awaitingGate` is set, it tells the user which gate is needed.
4. If `taskIteration >= maxTaskIterations`, it tells the user the task is blocked.
5. Otherwise, it resumes execution from the current `taskIndex`.
6. The new session reads `.sdd-progress.md` for context from prior tasks.

### No work is lost

The stop hook only advances `taskIndex` after verifying `TASK_COMPLETE` in the transcript. This means:

- Crashes leave state pointing at the incomplete task
- The task is retried, not skipped
- Committed work from prior tasks is safe in git
- The progress log preserves all learnings from prior sessions

## Linear Status Syncing

The execution engine keeps the Linear issue in sync with loop state.

| Loop Event | Linear Update |
|------------|---------------|
| `/sdd:go` starts execution | Status to In Progress, label to `spec:implementing` |
| Task completes | Comment: "Task N/M complete: [description] -- [commit hash]" |
| Gate reached | Comment: "Awaiting Gate N: [gate description]" |
| Task blocked (retry exhausted) | Comment: "Task N blocked after M attempts. Manual intervention needed." |
| All tasks complete | Comment: "All N tasks complete. Opening PR for Gate 3 review." |
| Execution resumes after interruption | Comment: "Resuming execution from task N/M." |

Comments are brief status updates per the issue content discipline rules. Detailed evidence goes in `.sdd-progress.md`, not in issue comments.

## Configuration

### Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SDD_STATE_FILE` | `.sdd-state.json` | Override state file path (relative to project root) |
| `SDD_PROGRESS_FILE` | `.sdd-progress.md` | Override progress file path (relative to project root) |
| `SDD_MAX_TASK_ITER` | `5` | Maximum iterations per task before blocking |
| `SDD_MAX_GLOBAL_ITER` | `50` | Maximum total iterations before hard stop |

### Hook registration

The execution engine stop hook is registered in the project's hooks configuration:

```json
{
  "hooks": {
    "Stop": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": ".claude/hooks/sdd-execution-stop.sh"
      }]
    }]
  }
}
```

This hook coexists with the general hygiene stop hook defined in hook-enforcement. The execution engine hook runs first (checks for `TASK_COMPLETE` and decides whether to block or allow), then the hygiene hook runs if the session is actually ending (status normalization, closing comments).

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| Loop does not start | No `.sdd-state.json` exists | Run `/sdd:go` or `/sdd:start` to create state from the decomposed task list |
| Loop does not advance | Agent did not output `TASK_COMPLETE` | Ensure the agent outputs the exact string `TASK_COMPLETE` after finishing the task |
| Task keeps retrying | Task fails verification (tests, lint, build) | Fix the underlying issue. If stuck, increase `SDD_MAX_TASK_ITER` or fix manually and resume. |
| Loop stops unexpectedly | `pair` or `swarm` execution mode | These modes disable the loop by design. This is expected behavior, not a bug. |
| State file corrupt | Failed write during hook execution | Delete `.sdd-state.json` and re-run `/sdd:go` to recreate from the task list |
| Fresh context not working | Stop hook not registered | Verify `hooks/hooks.json` includes the execution engine stop hook configuration |
| Progress file missing | Deleted or moved | `/sdd:go` creates a new one, but learnings from prior sessions are lost. Check git history. |
| Global iteration cap hit | Many task retries consuming the budget | Review which tasks are failing. Fix root causes rather than increasing the cap. |
| Gate blocking unexpectedly | `awaitingGate` set in state | Complete the gate review, then clear `awaitingGate` and run `/sdd:go` |

## Cross-Skill References

- **spec-workflow** -- Defines the 9-stage funnel this engine powers (Stage 6: Implementation)
- **execution-modes** -- Defines the 5 modes and their decision heuristic; determines loop behavior
- **issue-lifecycle** -- Defines closure rules triggered after execution completes (Stage 7.5)
- **context-management** -- Defines delegation tiers used during task execution within each session
- **drift-prevention** -- The `/sdd:anchor` protocol runs automatically at the start of each task in the loop
- **hook-enforcement** -- Defines the broader hook framework; the execution engine extends the Stop hook
