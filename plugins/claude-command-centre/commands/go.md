---
description: |
  Unified entry point for the CCC workflow. Auto-detects context and routes to the correct funnel stage.
  Use to start new work, resume in-progress tasks, check status, or enter quick mode for small fixes.
  Trigger with phrases like "let's go", "what should I work on", "resume work", "start building", "quick fix", "show status", "where was I", "continue working".
argument-hint: "<issue ID, text description, --next, --status, or --quick>"
platforms: [cli, cowork]
---

# Go -- Unified Workflow Entry Point

Single entry point for the CCC funnel. Detects your context and routes you to the right stage. All existing commands (`/start`, `/decompose`, `/close`, etc.) remain directly invocable -- `/go` is the convenience layer on top.

## Step 1: Detect Context

Determine the correct action based on the argument provided.

### 1A: No Argument -- Check for Active Work

If no argument is given, look for existing work in progress:

1. Check for `.ccc-state.json` in the project root.
   - **Found AND `phase` is `execution`** -- Resume the execution loop. Show the status view (Step 4), then continue from the current task.
   - **Found AND `phase` is `replan`** -- The stop hook triggered a replan. Show the status view with `[>] Replan` indicator. Execute the replan protocol: re-read the spec and `.ccc-progress.md`, compare completed work against all acceptance criteria, regenerate remaining tasks, update `.ccc-state.json` (set `phase` back to `execution`, update `totalTasks` and `taskIndex`), then continue executing from the first new task.
   - **Found AND `phase` is NOT `execution` or `replan`** -- Show the status view and suggest the next action for the current phase.
2. If no state file exists, query the connected project tracker for agent-assigned issues with status "In Progress".
   - **Found one** -- Load that issue and resume (route through the Issue ID logic in 1C).
   - **Found multiple** -- List all in-progress agent issues and ask the user to choose one.
   - **Found none** -- Ask "What would you like to build?" and wait for input.

### 1B: `--status` Flag -- Show Status Only

Read `.ccc-state.json` and the project tracker issue state. Display the status view (Step 4). Do NOT start any work. This is a read-only inspection.

### 1C: Issue ID (e.g., `CIA-042`) -- Route by Issue Status

Fetch the issue from the connected project tracker and route based on its current state:

| Issue State | Has Spec? | Route To |
|-------------|-----------|----------|
| Backlog/Todo | No spec, no `spec:*` label | Stage 3: Run `/write-prfaq` |
| Todo | Has `spec:draft` label | Stage 3: Continue spec draft |
| Todo | Has `spec:ready` label | Stage 4: Run `/review` |
| Todo | Has `spec:review` label | Gate 2 check: read RDR from comments → if all Critical/Important decided, run `/decompose` then `/start` → if decisions pending, present RDR table and collect decisions |
| In Progress | Has sub-issues | Resume execution loop |
| Done | -- | Run `/close` evaluation |

If the issue has `spec:implementing` but no `.ccc-state.json`, recreate the state file from the issue's sub-issues and resume execution.

### 1D: Text Description (Free Text) -- New Idea Intake

Create a new issue in the project tracker (Stage 0: Intake):

1. Apply normalization rules:
   - Verb-first, outcome-oriented title
   - Source label (`source:direct` for CLI, `source:cowork` for cowork session)
   - Project assignment based on topic (see project assignment table in CLAUDE.md)
2. Duplicate detection: search existing issues for overlapping scope before creating.
3. Determine execution mode:
   - If `--quick` flag: Apply `exec:quick`, use `prfaq-quick` template, skip adversarial review. See Step 2.
   - If `--mode MODE` flag: Apply the specified mode.
   - Otherwise: Proceed to Stage 3 (PR/FAQ draft) with interactive template selection via `/write-prfaq`.

### 1E: `--next` Flag -- Pick Up Next Unblocked Task

Query the project tracker for the next unblocked task. Selection criteria (in priority order):

1. Assigned to the agent and status is "Todo" or "Backlog"
2. Not blocked by any incomplete tasks
3. Highest priority first
4. If tied, prefer tasks on the critical path (most downstream dependents)

Route the selected task through the Issue ID logic in 1C.

## Step 1.5: Planning Preflight

Before routing to a planning phase (Stage 3: `/write-prfaq`, or Plan Mode exploration), invoke the `planning-preflight` skill:

1. Run the preflight protocol (5 steps from the skill).
2. Present the Planning Context Bundle to the user.
3. If the overlap table contains SUPERSEDED or OVERLAPPING entries, pause:
   - "Found [N] potentially overlapping issues. Review before continuing?"
   - Present the overlap table.
   - Wait for user to acknowledge or request merges/cancellations.
4. Proceed to the detected stage with the context bundle loaded.

**Skip preflight when:**
- `--quick` flag is set (quick mode minimizes ceremony)
- Resuming an existing execution loop (`.ccc-state.json` with `phase: execution` or `phase: replan`)
- Running `/ccc:start` (implementation, not planning)
- The detected route is NOT a planning phase (e.g., routing to execution, closure, or verification)

**Preflight applies to these routes from Step 1:**
- 1C routes to Stage 3 (no spec, no `spec:*` label) -- run preflight before `/write-prfaq`
- 1C routes to "Continue spec draft" (`spec:draft`) -- run preflight before resuming draft
- 1D creates a new issue and proceeds to Stage 3 -- run preflight before `/write-prfaq`

**Preflight does NOT apply to:**
- 1A resuming execution (`.ccc-state.json` found with execution phase)
- 1C routing to review, decomposition, execution, or closure
- 1B status-only inspection
- 1E next-task pickup (routes through 1C, preflight applies only if 1C routes to planning)

## Step 2: Quick Mode (`--quick`)

When `--quick` is passed (with either a description or issue ID):

1. **Collapse the funnel.** Skip stages 1, 2, 4, 5 (ideation, analytics, adversarial review, visual prototype).
2. **Quick template.** Use `prfaq-quick` template -- minimal spec with just acceptance criteria.
3. **Auto-decompose.** If the task is simple enough (single concern, estimated <4h), skip decomposition entirely and go straight to execution.
4. **Keep gates.** Gate 3 (PR review) is still required. Quality scoring still runs at closure.
5. **Label.** Apply `exec:quick` and `template:prfaq-quick`.

Quick mode is for: bug fixes, config changes, dependency updates, small features with obvious implementation.

**Flag precedence:** If `--quick` and `--mode MODE` are both passed, `--mode` takes precedence over `--quick`'s default of `exec:quick`. The funnel collapsing behavior of `--quick` still applies.

## Step 3: Initialize State

When entering the execution phase (either fresh or resuming), create the state and progress files if they do not already exist.

### `.ccc-state.json`

```json
{
  "linearIssue": "CIA-XXX",
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
  "specPath": "docs/specs/feature-name.md",
  "replanCount": 0,
  "createdAt": "2026-02-15T12:00:00Z",
  "lastUpdatedAt": "2026-02-15T12:00:00Z"
}
```

Field definitions are documented in the **execution-engine** skill. Key initialization rules:

- `taskIndex` starts at 0 (the first decomposed task).
- `totalTasks` is derived from the count of sub-issues created by `/decompose`.
- `gatesPassed` is populated by checking the issue's spec labels and review state. Gate 1 requires `spec:ready` or higher. Gate 2 requires a review acceptance comment or `spec:review` label with no blocking findings.
- `executionMode` is read from the issue's `exec:*` label.
- `specPath` is the relative path to the spec file, or `null` if the spec lives in the issue description.

### `.ccc-progress.md`

```markdown
## Goal
[Spec summary -- extracted from the PR/FAQ press release section]

## Linear Issue
CIA-XXX: [Issue title]

## Completed Tasks
(none yet)

## Learnings
(none yet)

## Current Task
Task 0: [First task description]

## Blocked / Flagged
(none)
```

If `.ccc-state.json` already exists (resuming), do NOT overwrite it. Read the existing state and resume from the current `taskIndex`.

If `.ccc-progress.md` already exists, do NOT overwrite it. Read it for context from prior tasks.

### Update Project Tracker

- Mark the parent issue "In Progress" immediately (do not batch).
- Add a comment: "Execution started. Mode: `[exec mode]`. Tasks: `[N]`. Timestamp: `[ISO-8601]`."
- Update the spec label to `spec:implementing` if it is currently `spec:ready` or `spec:review`.

## Step 4: Show Status View

Before starting any work, always display the "You Are Here" status view. This orients the user and confirms the routing decision.

```
CCC: CIA-042 -- "Add user preference sync"

  [x] Intake          -- direct (Feb 14)
  [x] PR/FAQ Draft    -- prfaq-feature
  [x] Gate 1          -- Approved (Feb 14)
  [x] Review          -- 2 Critical addressed
  [x] Gate 2          -- Accepted (Feb 15)
  [x] Decompose       -- 8 tasks, critical path: 5
  [>] Execute          -- Task 4/8: "Add conflict resolution" (tdd)
  [ ] Gate 3          -- PR not opened
  [ ] Verify
  [ ] Close

Progress: 3/8 tasks | Mode: tdd | Iteration: 1/5
Next action: Execute task 4
```

### Stage Completion Detection

Determine each stage's status from two sources: `.ccc-state.json` (execution loop state) and the project tracker issue metadata (status, labels, comments).

| Stage | Completed When |
|-------|---------------|
| Intake | Issue exists in the project tracker |
| PR/FAQ Draft | `spec:draft` or higher label present |
| Gate 1 | `spec:ready` or higher label present |
| Review | `spec:review` or higher label present |
| Gate 2 | Issue has a review acceptance comment |
| Decompose | Issue has sub-issues |
| Execute | Check `taskIndex` vs `totalTasks` from state file |
| Gate 3 | PR approved |
| Verify | PR merged and deploy passing |
| Close | `spec:complete` label present |

### Stage Indicators

- `[x]` -- Stage completed
- `[>]` -- Current active stage
- `[~]` -- Stage auto-passed (e.g., gate disabled in preferences)
- `[R]` -- Replan in progress (shown on Execute stage during replanning)
- `[ ]` -- Stage not yet reached

## Step 5: Begin Work

After displaying the status view, start the work for the detected stage:

| Detected Stage | Action |
|----------------|--------|
| Intake (new idea) | Issue created. Suggest next step: `/ccc:go CIA-XXX` or `/ccc:write-prfaq CIA-XXX` |
| PR/FAQ Draft | Invoke `/write-prfaq` with the issue ID |
| Gate 1 pending | Inform the user that Gate 1 (spec approval) is needed. Present the spec for review. |
| Adversarial Review | Invoke `/review` with the issue ID |
| Gate 2 pending | Inform the user that Gate 2 (review acceptance) is needed. Present the review findings. |
| Decompose | Invoke `/decompose` with the issue ID |
| Execution | Load context from `.ccc-progress.md`, read the current task's acceptance criteria, and begin implementation per the execution mode. Follow the execution-engine protocol. |
| Gate 3 pending | All tasks complete. Open a PR if not already open. Inform the user that Gate 3 (PR review) is needed. Set `awaitingGate: 3` in state. |
| Verification | PR merged. Run verification checks against the deployment. |
| Closure | Invoke `/close` with the issue ID |

For execution-phase work, follow the **execution-engine** skill protocol: read `.ccc-progress.md` for accumulated context, implement the current task, run verification, commit, update the progress log, and signal `TASK_COMPLETE` when done.

## Step 6: Suggest Next Step

After completing any stage-level work, always suggest the next action. This ensures the user knows how to continue, whether they prefer `/go` or direct commands.

```
PR/FAQ draft complete for CIA-042.
  Next: Run `/ccc:go` to continue (will route to adversarial review)
  Or: Run `/ccc:review CIA-042` directly
```

```
All 8 tasks complete for CIA-042.
  Next: Run `/ccc:go` to continue (will open PR for Gate 3 review)
  Or: Open the PR manually and run `/ccc:close CIA-042` after merge
```

```
Task 4/8 complete. Signaling TASK_COMPLETE.
  The stop hook will advance to task 5 automatically.
  If the loop does not restart, run `/ccc:go` to resume.
```

## What If

| Situation | Response |
|-----------|----------|
| **No project tracker connected** | Show a warning. Offer to work without project tracker integration (file-based state only). Skip project-tracker-specific routing (label checks, status queries). Issue ID arguments will not work -- only text descriptions and `--status` are available. |
| **`.ccc-state.json` exists but is stale** | If `lastUpdatedAt` is >24 hours ago, warn the user: "State file is N hours old. Resume this work or start fresh?" Wait for confirmation before proceeding. |
| **Multiple in-progress issues** | List all in-progress agent-assigned issues with their titles, priorities, and last activity timestamps. Ask the user to choose one. |
| **Issue has no `exec:*` label** | Apply the execution-modes decision heuristic to infer the correct mode. Apply the label and inform the user which mode was selected and why. |
| **Issue is blocked by dependencies** | Show the blocking issues with their current statuses. Suggest running `/ccc:go --next` to find an unblocked task instead. |
| **User passes both `--quick` and `--mode`** | `--mode` takes precedence for the execution mode label. `--quick` still applies the funnel collapsing behavior (skip stages 1, 2, 4, 5). |
| **Execution loop is already running** | If `.ccc-state.json` exists with `phase: execution`, resume from the current `taskIndex` rather than restarting. Do not recreate state files. |
| **User wants to abort the loop** | Advise deleting `.ccc-state.json` or running a future `/ccc:cancel` command. Progress is preserved in `.ccc-progress.md` and git commits. The project tracker issue remains In Progress until explicitly closed. |
| **`awaitingGate` is set in state** | The loop is paused at a gate. Display which gate is needed and what is required to pass it (e.g., "Gate 3: PR needs approval"). Do not resume execution until the gate is cleared. |
| **`taskIteration >= maxTaskIterations`** | The current task has exhausted its retry budget. Inform the user that manual intervention is needed. Show the task description, the iteration count, and suggest reviewing `.ccc-progress.md` for failure context. |
| **State file is corrupt or malformed** | Warn the user. Offer to delete the state file and recreate it from the project tracker issue and its sub-issues. Progress in `.ccc-progress.md` is preserved regardless. |
| **`--next` finds no unblocked tasks** | Report that all agent-assigned tasks are either complete, in progress, or blocked. List the blocked tasks with their blockers. Suggest checking on the blocking issues. |

## Integration Notes

- **Dual access.** This command is additive. All 9 existing commands (`/anchor`, `/close`, `/decompose`, `/hygiene`, `/index`, `/insights`, `/review`, `/start`, `/write-prfaq`) continue to work independently. `/go` is a router that calls into them, not a replacement.
- **Stop hook dependency.** The execution loop in Step 3 relies on the stop hook registered in `hooks/scripts/ccc-stop-handler.sh`. If the hook is not active, the loop will not auto-advance between tasks. Manual `/start` per task still works. `/go` will warn if the hook is not detected.
- **Phase progression.** `/go` reads project tracker state and `.ccc-state.json` to determine position in the funnel, then invokes the appropriate internal command. It does not duplicate the logic of those commands -- it delegates to them.
- **State file lifecycle.** `.ccc-state.json` is created when entering execution and deleted (or archived) when `/close` completes successfully. `.ccc-progress.md` persists as a record of what happened and is never auto-deleted.
- **Execution mode behavior.** For `exec:pair` and `exec:swarm`, the stop hook is disabled by design. `/go` still routes correctly and shows status, but the autonomous loop does not apply. See the **execution-engine** skill for details.
