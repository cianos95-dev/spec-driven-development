---
description: |
  Break an epic or spec into atomic, implementable tasks with execution mode assignments.
  Use when a spec is approved and needs to be broken into work items, an epic needs task decomposition, or you need to plan implementation order with dependency tracking.
  Trigger with phrases like "break this into tasks", "decompose this epic", "create subtasks for", "plan the implementation of", "what tasks do I need for", "split this into work items".
argument-hint: "<issue ID or spec file path>"
---

# Decompose Spec into Tasks

Break an epic or specification into atomic, independently implementable tasks. Each task gets an execution mode assignment and dependency mapping.

## Step 1: Read the Spec

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

## What If

| Situation | Response |
|-----------|----------|
| **Spec has no acceptance criteria** | Warn the user (as noted in Step 1). Suggest running `/write-prfaq` or `/review` to generate acceptance criteria before decomposing. Decomposition without AC produces tasks that cannot be verified. |
| **Circular dependencies detected** | Flag the cycle explicitly (e.g., "Task A blocks Task B which blocks Task A"). This indicates a spec ambiguity. Ask the user to clarify which task should come first, or whether the tasks should be merged. |
| **Project tracker not connected** | Output the decomposition summary table to the user but skip Step 5 (tracker creation). Note the tasks and suggest the user create them manually or connect a tracker and re-run. |
