# Issue Context Bundle

A shared read primitive for all CCC skills that operate on Linear issues. Before taking any action on an issue, the agent MUST gather the full context bundle defined below.

## The Problem

Acting on an issue based on its description alone leads to incorrect decisions. Descriptions are written at creation time and often become stale. The real state of an issue lives across multiple data sources: comments contain dispatch results, decisions, and blocker resolutions; relations reveal dependency chains; labels encode execution mode and type; and acceptance criteria checkboxes track actual progress.

Skills that skip any of these sources make decisions on incomplete information.

## Bundle Protocol

Before ANY action on a Linear issue, gather the following six data sources:

### 1. Description (via `get_issue`)

Fetch the full issue description. This provides:
- Original scope and intent
- Acceptance criteria (raw checklist)
- Links to specs, PRs, or documents
- Any inline context or constraints

### 2. Last 10 Comments (via `list_comments` with limit 10)

Fetch the most recent 10 comments on the issue. Comments reveal:
- **Dispatch results** -- outcomes from prior agent sessions ("Task 3 complete, committed abc1234")
- **Decisions** -- scope changes, approach pivots, human overrides ("Let's skip the migration for now")
- **Blocker changes** -- resolution signals ("CIA-415 merged, unblocked"), new blockers raised
- **Review findings** -- adversarial review results, PR review feedback
- **Closure attempts** -- prior `/close` evaluations, re-open reasons

### 3. Acceptance Criteria State (parse `- [ ]` / `- [x]` from description)

Parse the description for checklist items:
- `- [ ]` -- criterion not yet met
- `- [x]` -- criterion met

Count completed vs total to assess progress. If no checklist exists, note "No structured acceptance criteria" and rely on description prose.

### 4. Blocking/Blocked Relations (via `get_issue` with `includeRelations: true`)

Fetch the issue with relations to discover:
- **Blocks** -- issues that depend on this one completing
- **Blocked by** -- issues that must complete before this one can proceed
- **Related to** -- issues with shared scope or context

A blocked issue cannot be started. An issue that blocks others should be prioritized.

### 5. Sub-Issue Statuses (if parent issue)

If the issue has children (sub-issues), fetch their statuses:
- How many are Done, In Progress, Todo, Blocked?
- Are there sub-issues blocking the parent's completion?
- Have any sub-issues been cancelled (indicating scope reduction)?

Skip this step if the issue is not a parent.

### 6. Current Labels (for exec mode, type inference)

Read the issue's labels for:
- **`exec:*`** -- execution mode (quick, tdd, pair, checkpoint, swarm)
- **`type:*`** -- issue type (feature, bug, spike, chore)
- **`spec:*`** -- spec lifecycle stage (draft, ready, review, implementing, complete)
- **`needs:*`** -- flags for human decisions or external dependencies
- **`research:*`** -- research grounding state

Labels encode workflow state that is not visible in the description or comments alone.

## Anti-Pattern: Description-Only Actions

**Never act on an issue based on description alone.**

The description is the least reliable source of current state. It captures intent at creation time but does not reflect:
- Work completed in subsequent sessions (visible only in comments)
- Scope changes decided in comment threads
- Blocker resolutions that unblocked the issue
- Prior dispatch results that changed the approach
- Acceptance criteria that were checked off during implementation

An agent that reads only the description will:
- Duplicate work already done (comments show prior completions)
- Miss scope changes (comments contain human overrides)
- Ignore resolved blockers (relations show current state)
- Misjudge progress (checklist state shows actual AC completion)
- Apply wrong execution mode (labels may have been updated since creation)

## What Each Data Source Reveals

| Source | Reveals | Example |
|--------|---------|---------|
| Description | Original intent, acceptance criteria structure | "Build user preference sync with 5 ACs" |
| Comments | Dispatch results, decisions, blocker changes | "Task 2 complete (def5678). Skipping migration per user decision." |
| AC checkboxes | Actual progress against criteria | 3/5 checked = 60% complete |
| Relations | Dependency chain, dispatch order | Blocked by CIA-410 (still In Progress) |
| Sub-issues | Decomposition progress, child blockers | 4/6 sub-issues Done, 1 blocked |
| Labels | Workflow state, execution mode | `exec:tdd`, `spec:implementing`, `type:feature` |

## Minimum Viable Bundle

For skills that need to minimize API calls (e.g., dispatch-readiness with its 20-call budget), the minimum viable bundle is:

1. `get_issue` with `includeRelations: true` (covers description, labels, relations) -- 1 API call
2. `list_comments` with limit 10 -- 1 API call

This costs 2 API calls and covers the most critical data sources. Sub-issue statuses can be deferred if the issue is not a parent.

## Cross-Skill Usage

This bundle is referenced by the following skills and commands:

| Skill/Command | Why It Needs the Bundle |
|---------------|------------------------|
| `/close` (commands/close.md) | Closure evaluation requires comments for evidence, relations for blocker state, ACs for completion |
| `/start` (commands/start.md) | Starting work requires comments for prior work and decisions, relations for blocker verification |
| session-exit | Writing closing comments requires existing comments to avoid duplication |
| dispatch-readiness | Blocker resolution detection requires relations and comments |
| quality-scoring | Comment thread health affects review dimension scoring |
| drift-prevention | Comments contain decisions that change scope, affecting drift checks |
| planning-preflight | Strategic context requires full issue state including comments and relations |
