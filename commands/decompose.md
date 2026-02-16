---
description: |
  Break an epic or spec into atomic, implementable tasks with execution mode assignments.
  Use when a spec is approved and needs to be broken into work items, an epic needs task decomposition, or you need to plan implementation order with dependency tracking.
  Trigger with phrases like "break this into tasks", "decompose this epic", "create subtasks for", "plan the implementation of", "what tasks do I need for", "split this into work items".
argument-hint: "<issue ID or spec file path>"
platforms: [cli, cowork]
---

# Decompose Spec into Tasks

Break an epic or specification into atomic, independently implementable tasks. Each task gets an execution mode assignment and dependency mapping.

## Step 1: Read the Spec

### Gate 2 Pre-Check

Before reading the spec, verify that Gate 2 (Accept Findings) has passed. This ensures all Critical and Important review findings have explicit human decisions.

1. **Read issue comments** from the connected project tracker.
2. **Find the RDR** — Search for the most recent comment containing `## Review Decision Record`.
3. **Parse the RDR table** — Extract all rows with their ID, Severity, Decision, and Response values.
4. **Scan replies for decisions** — If any Critical or Important rows have empty Decision cells, scan all comments posted AFTER the RDR comment for decision language. Parse natural language patterns:
   - `"agree all"` / `"agreed all"` → set all rows to `agreed`
   - `"agree all except C2, I3"` → set all to `agreed`, leave C2 and I3 empty
   - `"agreed C1-C3"` → set C1, C2, C3 to `agreed`
   - `"override I2: [reason]"` → set I2 to `override` with reason in Response
   - `"defer I3 to CIA-456"` / `"deferred I3: CIA-456"` → set I3 to `deferred` with issue link in Response
   - `"reject N1: [reason]"` / `"rejected N1: not applicable"` → set N1 to `rejected` with reason in Response
   - Decisions from multiple reply comments are merged (later comments take precedence for the same finding ID).
   - If reply-scanned decisions are found, update the RDR comment in the project tracker with the filled Decision/Response values, then proceed with verification.
5. **Verify decisions:**
   - Every row where Severity = `Critical` or `Important` must have a non-empty Decision value.
   - Every row where Decision = `override` or `rejected` must have a non-empty Response.
   - Every row where Decision = `deferred` must have an issue link in Response.
   - If `review.gate2_require_consider` is `true` in `.sdd-preferences.yaml`, Consider rows also require Decision values.
6. **Gate 2 outcome:**
   - **All checks pass** → Gate 2 = PASSED. Proceed to read the spec.
   - **Any check fails** → Report which findings lack decisions. Do NOT proceed. Prompt the human to fill decisions using reply comments or the inline shorthand.
   - **No RDR found** → Fallback: if the issue has `spec:implementing` label (work already started in a prior session), proceed. Otherwise, suggest running `/review` first.

### Read the Spec

Fetch the epic or spec using the provided argument:

- **Issue ID** — Fetch from the connected project tracker. Read the description, acceptance criteria, and any linked documents or child issues.
- **File path** — Read the spec from disk.

Extract and list:
- All requirements (functional and non-functional)
- All acceptance criteria
- Scope boundaries (what is explicitly out of scope)
- Dependencies on external systems or teams
- Any existing sub-issues already created

If the spec is missing acceptance criteria, warn the user and suggest running `/write-prfaq` or `/review` first.

## Step 2: Identify Atomic Tasks

Break the spec into tasks where **each task** satisfies ALL of these criteria:

1. **Well-scoped files** — Modifies a well-defined, predictable set of files.
2. **Clear acceptance criteria** — Has at least one testable acceptance criterion derived from the parent spec.
3. **Independent or explicitly dependent** — Can be completed independently, or has an explicit dependency on another task in the list.
4. **Right-sized** — Estimated at no more than ~4 hours of focused work. If larger, break it down further.
5. **Single concern** — Addresses one logical concern (a feature, a refactor, a test, a config change) rather than mixing concerns.

Common task patterns:
- Data model / schema changes
- API endpoint implementation
- UI component creation
- Business logic / service layer
- Test suite for a specific module
- Configuration / environment setup
- Documentation updates
- Migration scripts

## Step 3: Assign Execution Modes

For each task, apply the execution-modes decision heuristic:

| Condition | Execution Mode |
|-----------|---------------|
| Well-defined, single-file, clear requirements | `exec:quick` |
| Has testable acceptance criteria, moderate scope | `exec:tdd` |
| Uncertain scope, requires human judgment during implementation | `exec:pair` |
| High-risk change, needs approval at milestones | `exec:checkpoint` |
| 5+ independent subtasks that can run in parallel | `exec:swarm` |

Label each task with its assigned mode. If a task could fit multiple modes, prefer the one that provides more safety for the risk level.

## Step 4: Analyze Dependencies

Build a dependency graph for all tasks:

1. Identify which tasks **block** other tasks (Task B cannot start until Task A is complete).
2. Identify which tasks are **independent** (can run in any order or in parallel).
3. Identify **shared dependencies** (multiple tasks depend on the same prerequisite).
4. Flag any **circular dependencies** as errors that need spec clarification.

Determine the **critical path** — the longest chain of sequential dependencies. This sets the minimum implementation timeline.

Group tasks into **implementation phases** based on the dependency graph:
- Phase 1: No dependencies (can start immediately, can run in parallel)
- Phase 2: Depends only on Phase 1 tasks
- Phase N: Depends on Phase N-1 tasks

## Step 5: Create in Tracker

Create sub-issues in the connected project tracker. Each sub-issue includes:

- **Title** — Clear, action-oriented (e.g., "Add user preference schema migration")
- **Description** — What needs to be done, why, and how it connects to the parent spec
- **Acceptance criteria** — Derived from the parent spec, specific to this task
- **Execution mode label** — The `exec:*` label assigned in Step 3
- **Spec lifecycle label** — Set to `spec:implementing` for the parent issue
- **Dependency links** — "Blocked by" relationships to prerequisite tasks
- **Estimated complexity** — Mapped to execution mode
- **Parent link** — Connected to the epic/parent issue

Set the parent issue's status to reflect that decomposition is complete.

## Step 6: Report

Output a summary table:

```
## Decomposition Summary

**Parent:** [Issue ID] — [Title]
**Total tasks:** N
**Critical path length:** N tasks (~N hours)
**Parallel opportunities:** N tasks can run simultaneously

| # | Task | Mode | Phase | Blocked By | Est. |
|---|------|------|-------|------------|------|
| 1 | [Title] | quick | 1 | — | 1h |
| 2 | [Title] | tdd | 1 | — | 3h |
| 3 | [Title] | pair | 2 | #1 | 4h |
| ... | ... | ... | ... | ... | ... |

## Dependency Graph

Phase 1 (parallel): #1, #2, #4
Phase 2 (after Phase 1): #3, #5
Phase 3 (after Phase 2): #6

## Suggested Start Order
1. [Task] — No dependencies, unblocks the most downstream tasks
2. [Task] — No dependencies, independent workstream
...
```

Ask the user if any tasks need further breakdown or if the decomposition looks correct before finalizing.

## Next Step

After the decomposition is complete and sub-issues are created:

```
✓ Decomposition complete. N tasks created with dependency graph.
  Next: Run `/sdd:go` to continue → will enter execution loop
  Or: Run `/sdd:start [first task ID]` to start a specific task
  Or: Run `/sdd:start --next` to pick the highest-priority unblocked task
```

The execution loop will process tasks one at a time with fresh context per task if the stop hook is active.

## What If

| Situation | Response |
|-----------|----------|
| **Spec has no acceptance criteria** | Warn the user (as noted in Step 1). Suggest running `/write-prfaq` or `/review` to generate acceptance criteria before decomposing. Decomposition without AC produces tasks that cannot be verified. |
| **Circular dependencies detected** | Flag the cycle explicitly (e.g., "Task A blocks Task B which blocks Task A"). This indicates a spec ambiguity. Ask the user to clarify which task should come first, or whether the tasks should be merged. |
| **Project tracker not connected** | Output the decomposition summary table to the user but skip Step 5 (tracker creation). Note the tasks and suggest the user create them manually or connect a tracker and re-run. |
| **Gate 2 not passed — some findings lack decisions** | Report which Critical/Important findings in the Review Decision Record still need decisions. Show the RDR table with unfilled rows highlighted. Prompt the human to fill decisions inline or in the project tracker. Do NOT proceed to decomposition until Gate 2 passes. |
| **No Review Decision Record found** | If the issue has `spec:implementing` (prior session started work), proceed as backward-compatible. Otherwise, suggest running `/review` first to generate the RDR. |
