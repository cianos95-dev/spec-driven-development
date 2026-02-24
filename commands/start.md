---
description: |
  Begin implementation of a task with automatic execution mode routing and status tracking.
  Use when starting work on a specific issue, picking up the next unblocked task, or beginning a coding session with proper status tracking and context loading.
  Trigger with phrases like "start working on", "begin implementation of", "pick up the next task", "implement this issue", "start coding", "what should I work on next".
argument-hint: "<issue ID or --next for next unblocked task>"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
platforms: [cli, cowork]
---

# Start Task Implementation

Begin working on a task with automatic routing to the correct execution mode and real-time status tracking in the project tracker.

## Pre-Step: Gather Issue Context Bundle

Before executing this command, gather the issue context bundle (see `issue-lifecycle/references/issue-context-bundle.md`). Before starting implementation, check comments for prior work, decisions made in earlier sessions, and blockers that have been resolved. This prevents duplicating completed work or missing scope changes.

## Step 1: Select Task

Determine which task to work on:

- **Explicit issue ID** — Fetch the specified issue from the connected project tracker.
- **`--next` flag** — Query the project tracker for the next unblocked task. Selection criteria (in priority order):
  1. Assigned to the agent and status is "Todo" or "Backlog"
  2. Not blocked by any incomplete tasks
  3. Highest priority first
  4. If tied, prefer tasks on the critical path (most downstream dependents)

Verify the task is ready for implementation:
- Has acceptance criteria defined
- Has an `exec:*` label assigned
- Is not blocked by incomplete dependencies
- Has a parent spec that is at least `spec:ready`
- Has a project assigned (not unassigned/orphaned)

If any of these are missing, warn the user and suggest running `/decompose` or `/review` first. For missing project assignment, suggest the project based on topic (CCC/tooling → Claude Command Centre (CCC), Alteri features → Alteri, new ideas → Ideas & Prototypes, SoilWorx → Cognito SoilWorx).

## Step 2: Route to Execution Mode

Read the `exec:*` label on the issue and configure the session accordingly:

### `exec:quick` — Direct Implementation
- Minimal ceremony. Read the acceptance criteria, implement directly.
- Skip test-first workflow. Write tests after implementation if appropriate.
- Target: complete in a single session without interruption.

### `exec:tdd` — Test-Driven Development
- **Red**: Write a failing test that captures the first acceptance criterion.
- **Green**: Write the minimum code to make the test pass.
- **Refactor**: Clean up while keeping tests green.
- Repeat for each acceptance criterion.
- Do not move to the next criterion until the current one is green.

### `exec:pair` — Navigator/Driver with Human-in-Loop
- Activate interactive mode. Present the plan before each step.
- Propose an approach for each acceptance criterion and wait for user approval.
- After each significant change, pause for user review.
- Flag any decisions that require human judgment with `needs:human-decision`.

### `exec:checkpoint` — Milestone-Gated Implementation
- Identify approval gates from the spec (e.g., "schema approved", "API contract reviewed", "UI mockup confirmed").
- Implement up to the first gate. Pause and present deliverables for approval.
- Do not proceed past a gate without explicit user confirmation.
- At each gate, update the project tracker with progress.

### `exec:swarm` — Multi-Agent Orchestration
- Identify independent subtasks that can run in parallel.
- Set up parallel subagent execution with appropriate model mix.
- Coordinate results and handle merge conflicts.
- Report consolidated progress.

## Step 3: Update Status

Immediately upon starting work:

1. **Mark In Progress** — Transition the issue to "In Progress" in the project tracker. Do not batch this with other updates.
2. **Add start comment** — Post a comment on the issue noting that implementation has begun, the execution mode being used, and the session timestamp.
3. **Update spec label** — If the parent spec has `spec:ready`, transition it to `spec:implementing`.

## Step 4: Load Context

Pull all relevant context into the session:

1. **Task details** — Full description, acceptance criteria, and any comments or discussion.
2. **Parent spec** — The PR/FAQ or spec document this task was decomposed from.
3. **Dependencies** — Review completed prerequisite tasks to understand what's already built.
4. **Related code** — Identify the files and modules this task will touch. Read them.
5. **Test patterns** — If `exec:tdd`, review existing test files for conventions and patterns.

Summarize the loaded context in 3-5 bullets before beginning implementation.

## Step 5: Begin Work

Start implementation according to the routed execution mode.

During implementation:
- Follow acceptance criteria as a checklist. Mark each one as addressed.
- If you discover a requirement gap or ambiguity, flag it immediately rather than making assumptions.
- If scope expands beyond the original task, create a new issue for the additional work rather than expanding the current task.
- Run verification commands (tests, lint, build) before claiming any acceptance criterion is met.

When all acceptance criteria are addressed:
- Run the full verification suite one final time.
- Summarize what was implemented and what evidence supports completion.
- Suggest running `/close` to evaluate closure conditions.

## Next Step

After all acceptance criteria are addressed and verification passes:

```
✓ Task implementation complete. All acceptance criteria met.
  Next: Run `/ccc:go` to continue → will route to next task or closure
  Or: Run `/ccc:close [issue ID]` to evaluate closure conditions
```

If the stop hook is active, the execution loop will automatically advance to the next task when you signal TASK_COMPLETE.

## What If

| Situation | Response |
|-----------|----------|
| **Issue has no `exec:*` label** | Apply the execution-modes decision heuristic from Step 3 of `/decompose` to infer the correct mode. Apply the label and inform the user which mode was selected and why. |
| **Issue is blocked by incomplete dependencies** | Do not start implementation. List the blocking tasks and their current status. Suggest working on an unblocked task instead (use `--next` to find one). |
| **Acceptance criteria are ambiguous during implementation** | Pause and flag the ambiguity with a comment on the issue. If in `exec:pair` or `exec:checkpoint` mode, ask the user for clarification before proceeding. In `exec:quick` or `exec:tdd`, make a reasonable interpretation, document the assumption, and continue. |
