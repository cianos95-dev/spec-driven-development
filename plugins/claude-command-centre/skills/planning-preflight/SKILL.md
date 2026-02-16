---
name: planning-preflight
description: |
  Automated context gathering protocol that runs before planning phases.
  Produces a Planning Context Bundle with codebase state, issue overlap
  detection, strategic zoom-out, and timeline validation.
  Use before writing specs, during plan mode, or when entering any planning phase.
  Trigger with phrases like "preflight check", "what exists already",
  "check for overlapping issues", "planning context", "landscape scan".
---

# Planning Preflight

Before writing specs or plans, the agent must map the strategic landscape. Without this, planning sessions suffer from "tunnelling" -- the agent solves the literal question asked without checking what already exists in the codebase or project tracker. This leads to redundant specs, missed stale issues, plans invented without codebase context, and unjustified timeline deferrals.

The preflight protocol runs automatically before any planning phase (`/ccc:go` routing to spec, `/ccc:write-prfaq`, Plan Mode). It produces a **Planning Context Bundle** -- a concise summary that becomes input to the plan or spec.

## When Preflight Runs

| Trigger | Auto-Invoke? | Mechanism |
|---------|:---:|-----------|
| `/ccc:go` routes to spec drafting (Stage 3) | YES | Step 1.5 in `go.md` |
| `/ccc:write-prfaq` called directly | YES | Step 1.5 in `write-prfaq.md` |
| `EnterPlanMode` invoked with planning keywords | YES | Skill keyword auto-trigger |
| `/ccc:start` begins implementation | NO | Start loads task-specific context, not strategic context |
| `/ccc:review` begins adversarial review | OPTIONAL | Only if reviewer needs landscape context |

## When Preflight is Skipped

- `--quick` flag is set (quick mode minimizes ceremony)
- Resuming an existing execution loop (`.ccc-state.json` with `phase: execution`)
- Running `/ccc:start` (implementation phase, not planning phase)
- Preflight already ran this session and the cached bundle is still valid

## The 5-Step Protocol

### Step 1: Codebase Index

Build or refresh the local understanding of the repository.

1. **Auto-invoke `/ccc:index` in incremental mode.** If no codebase index exists (`.claude/codebase-index.md` missing), run a full index on first invocation.
2. **Load the index.** Read `.claude/codebase-index.md` for the module map, pattern inventory, and integration points.
3. **Recent changes.** Run `git log --oneline -10` to surface the most recent commits. Note any that relate to the current planning topic.
4. **Drift check.** Compare top-level files and directories against the index. Flag any new or deleted entries since the last index run.

**Budget:** 5-10 seconds. Incremental indexing touches only changed files.

**If the index is missing:** Run a full `/ccc:index`. This adds 10-15 seconds on first invocation only. Do not block -- show a progress indicator: "Preflight: building codebase index..."

### Step 2: Linear Landscape Scan

Search the connected project tracker for related work. This prevents creating specs that duplicate or conflict with existing issues.

**2a. Parent context.** If the current issue has a parent, fetch the parent issue. Read its description and list its children. Understand the broader initiative this work belongs to.

**2b. Sibling issues.** Fetch issues in the same project and milestone. Produce a compact table:

```
| ID | Title | Status | Labels | Estimate |
```

Limit to 10 issues. Sort by priority descending, then by most recently updated.

**2c. Keyword overlap detection.** Extract 3-5 key nouns or phrases from the current task description. For each keyword, search existing issues in the same project using `list_issues(query: keyword, limit: 5)`. Deduplicate results across keywords.

Score each result for overlap:
- **Title similarity:** Count exact words in common between the current task title and the found issue title.
- **Label similarity:** Same `exec:*` mode, same milestone, or same `spec:*` stage.
- **Issues scoring >50% similarity** are flagged with a classification.

**2d. Classify each flagged issue:**

| Classification | Meaning | Example |
|----------------|---------|---------|
| **SUPERSEDED** | New work makes the old issue obsolete | New architecture spec supersedes old module-level spec |
| **OVERLAPPING** | Partial scope overlap -- merge or scope-split needed | Two issues both touch the same command file |
| **SYNERGY** | Independent but complementary -- link as related | Auth skill + permissions skill |
| **BLOCKS** | Current task depends on this issue completing first | Must have DB schema before API endpoints |
| **BLOCKED-BY** | This issue depends on the current task | Downstream feature waiting on this foundation |

**2e. Same-coverage check.** Look for issues with the same `exec:*` mode AND overlapping stage coverage. These are candidates for batching or sequencing.

**Budget:** 10-15 seconds. Use `limit` on all queries.

**If no project tracker is connected:** Skip Steps 2 and 3 entirely. The bundle contains only codebase context. Log: "Preflight: no project tracker connected -- codebase-only mode."

### Step 3: Zoom Out

Widen the aperture beyond the immediate task to understand the strategic context.

**3a. Initiative context.** What initiative does this project belong to? Fetch the initiative name and status. Understanding the portfolio-level goal prevents tunnel vision.

**3b. Milestone context.** What else is in the same milestone? List the milestone's issues by status (how many done, how many in progress, how many todo). This reveals whether the milestone is on track and where the current task fits.

**3c. Relevant agents and tools.** From the codebase index, identify which agents, tools, or integrations are relevant to the current task. This prevents plans that ignore available capabilities.

**3d. Recent decisions.** Check for Linear documents attached to the project or parent issue. Read the last 5 comments on the parent issue. Surface any decisions, constraints, or context that should inform the plan.

**Budget:** 3-5 seconds. Single `get_issue` for parent, single `list_issues` for milestone.

### Step 4: Timeline Validation

For any deferred work mentioned in the plan or task context, validate that the deferral has a technical justification.

For each deferred item, answer:

1. **What is the EXPLICIT dependency or blocker?** Is there a specific issue, PR, or technical prerequisite that must complete first?
2. **Is this TECHNICAL or ASSUMED?**
   - **Technical:** Code needs X before Y can be built. There is a concrete dependency.
   - **Assumed:** "We'll do this after the conference" or "later" with no stated blocker.
3. **If assumed:** Flag as "No technical blocker -- consider moving earlier." This does not mean the deferral is wrong, only that it should be a conscious human decision rather than an unexamined assumption.

**Budget:** 0-2 seconds. This is a local analysis of data already gathered in Steps 1-3. No new API calls.

### Step 5: Output the Planning Context Bundle

Assemble the findings into a structured markdown summary. This bundle becomes the input context for the spec or plan.

**Format:**

```markdown
## Planning Context Bundle

### Codebase State
- Repository: [name] ([N] modules, [M] files)
- Last indexed: [timestamp]
- Recent changes: [1-3 bullet summary of relevant commits]
- Drift: [any new/deleted files since last index, or "None"]

### Related Issues
[Compact table of sibling issues, or "No siblings in milestone"]

### Overlap Detection
[Table of flagged issues with classifications, or OMITTED if no overlaps found]

| ID | Title | Classification | Rationale |
|----|-------|----------------|-----------|

### Strategic Context
- Initiative: [name] ([status])
- Milestone: [name] — [X/Y] issues done
- Relevant tools: [list from codebase index]
- Recent decisions: [1-2 bullet summary, or "None found"]

### Timeline Flags
[List of deferred items with no technical blocker, or "No flags"]

### Recommendations
[0-3 actionable recommendations: merge, cancel, resequence, or "Proceed — landscape is clear"]
```

**Rules:**
- **Hard cap: 500 words.** If the bundle exceeds this, compress the sibling table and decision summaries.
- **Suppress clean results.** If the overlap table is empty, omit it entirely. If timeline flags are empty, omit that section. A clean preflight should be concise.
- **Overlap table only when overlaps found.** Do not include an empty table -- it adds noise without value.
- **Advisory only.** All classifications and recommendations are for human review. NEVER auto-cancel, auto-merge, or auto-close issues based on preflight findings.

**Budget:** 1-2 seconds. Markdown formatting of already-gathered data.

## Overlap Handling

When the overlap table contains SUPERSEDED or OVERLAPPING entries, the agent must pause before proceeding:

1. Present the overlap table to the user.
2. State: "Found [N] potentially overlapping issues. Review before continuing?"
3. Wait for the user to acknowledge, request merges, request cancellations, or dismiss the findings.
4. Only proceed to the planning phase after the user responds.

This is a blocking pause, not an advisory footnote. Overlapping specs are expensive to reconcile after drafting.

## Caching

The Planning Context Bundle is cached in memory for the session. If preflight is invoked again within the same session (e.g., user runs `/ccc:write-prfaq` after `/ccc:go` already ran preflight), reuse the cached bundle rather than re-querying.

The cache is invalidated if:
- The user explicitly requests a fresh preflight ("re-run preflight", "refresh context")
- The session switches to a different issue
- More than 30 minutes have elapsed since the last preflight

## Performance Budget

Target: **<30 seconds** total preflight time for an incremental index with a ~10-issue project.

| Step | Budget | Mechanism |
|------|--------|-----------|
| Codebase index | 5-10s | Incremental `/ccc:index` (only changed files) |
| Linear landscape scan | 10-15s | `list_issues` with `limit: 10`, keyword search with `limit: 5` |
| Zoom out | 3-5s | Single `get_issue` for parent, `list_issues` for milestone |
| Timeline validation | 0-2s | Local analysis of preflight data (no new API calls) |
| Bundle generation | 1-2s | Markdown formatting |

If preflight exceeds 5 seconds, show a progress indicator:
```
Preflight: scanning codebase... scanning issues... analyzing overlaps... done.
```

Never silently block. The user should always know the preflight is running.

## Graceful Degradation

| Missing Component | Behavior |
|-------------------|----------|
| No project tracker connected | Skip Steps 2 and 3. Bundle contains codebase index only. |
| No codebase index exists | Run full `/ccc:index` (adds 10-15s). Proceed normally after. |
| No parent issue | Skip 2a and 3d. Sibling scan still runs against the project. |
| No milestone assigned | Skip 3b. Note "No milestone assigned" in the bundle. |
| No initiative | Skip 3a. Note "No initiative context" in the bundle. |
| API rate limit or timeout | Log the failure, include what was gathered so far, proceed with partial bundle. |

The preflight must always produce a bundle, even if partial. A partial bundle is better than no context.

## What Preflight Does NOT Do

- **Auto-cancel issues.** All overlap classifications are advisory. False positive supersession detection is high-impact -- the human always decides.
- **Auto-merge issues.** Scope merges require human judgment about priority and sequencing.
- **Replace domain expertise.** The preflight provides context, not decisions. The human or spec author uses the bundle to make better choices.
- **Run during execution.** Implementation tasks load task-specific context via `.ccc-progress.md`, not strategic context. Preflight is for planning phases only.
- **Block on clean results.** If the landscape is clear (no overlaps, no timeline flags), the preflight completes silently with a minimal bundle and proceeds immediately.
