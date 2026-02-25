---
name: planning-preflight
description: |
  Automated context gathering protocol that runs before planning phases.
  Produces a Planning Context Bundle with codebase state, issue overlap
  detection, strategic zoom-out, and timeline validation.
  Use before writing specs, during plan mode, or when entering any planning phase.
  Trigger with phrases like "preflight check", "what exists already",
  "check for overlapping issues", "planning context", "landscape scan".
compatibility:
  surfaces: [code]
  tier: code-only
---

# Planning Preflight

Before writing specs or plans, the agent must map the strategic landscape. Without this, planning sessions suffer from "tunnelling" -- the agent solves the literal question asked without checking what already exists in the codebase or project tracker. This leads to redundant specs, missed stale issues, plans invented without codebase context, and unjustified timeline deferrals.

The preflight protocol runs automatically before any planning phase (`/ccc:go` routing to spec, `/ccc:write-prfaq`, Plan Mode). It produces a **Planning Context Bundle** -- a concise summary that becomes input to the plan or spec.

## Session Naming

Before running the preflight protocol, ensure the session is named for traceability. If the session has not been renamed and a CIA-XXX issue is active (from `.ccc-state.json` or the issue being loaded), rename the session:

```
/rename CIA-XXX: <short title>
```

This makes plan files at `~/.claude/plans/<session-slug>.md` traceable to their originating issue. Named sessions persist across resume and compaction (Claude Code v2.1.47+).

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

## Pre-Step: Gather Issue Context Bundle

Before executing this skill, gather the issue context bundle (see `issue-lifecycle/references/issue-context-bundle.md`). The planning preflight requires the full bundle to build accurate strategic context. This supplements the landscape scan below with issue-level detail.

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

**2b. Sibling issues.** Fetch issues in the same project and milestone. Produce a compact table with **linked issue IDs**:

```
| ID | Title | Status | Labels | Estimate |
| [CIA-XXX](https://linear.app/claudian/issue/CIA-XXX) | Title here | Todo | type:feature | 3pt |
```

All issue references in plan output must use clickable markdown links: `[CIA-XXX](https://linear.app/claudian/issue/CIA-XXX)` in table ID columns, or `[CIA-XXX: Title](https://linear.app/claudian/issue/CIA-XXX)` in inline references. Plain text issue IDs are not permitted in plan files.

Limit to 10 issues. Sort by priority descending, then by most recently updated.

**2c. Keyword overlap detection.** Extract 3-5 key nouns or phrases from the current task description. For each keyword, search existing issues in the same project using `list_issues(query: keyword, limit: 5)`. Deduplicate results across keywords.

Score each result for overlap:
- **Title similarity:** Count exact words in common between the current task title and the found issue title.
- **Label similarity:** Same `exec:*` mode, same milestone, or same `spec:*` stage.
- **Issues scoring >50% similarity** are flagged with a classification.

After gathering sibling issues, pass each issue's description through the **issue-lifecycle** skill's `detectDependencies` utility (Dependencies section) with the sibling issue IDs as `knownIssueIds`. This surfaces explicit and inferred dependency signals (blocks, blockedBy, relatedTo) that keyword matching alone would miss.

**2d. Classify each flagged issue:**

| Classification | Meaning | Example |
|----------------|---------|---------|
| **SUPERSEDED** | New work makes the old issue obsolete | New architecture spec supersedes old module-level spec |
| **OVERLAPPING** | Partial scope overlap -- merge or scope-split needed | Two issues both touch the same command file |
| **SYNERGY** | Independent but complementary -- link as related | Auth skill + permissions skill |
| **BLOCKS** | Current task depends on this issue completing first | Must have DB schema before API endpoints |
| **BLOCKED-BY** | This issue depends on the current task | Downstream feature waiting on this foundation |
| **LIKELY STALE** | Issue number is a statistical outlier relative to active project velocity | CIA-215 among CIA-500+ siblings (detected by Step 2f) |

For BLOCKS and BLOCKED-BY classifications, use the `DependencySignal.type` field returned by `issue-lifecycle`'s `detectDependencies` (Dependencies section) to populate these entries. Do not duplicate the signal detection logic here — delegate it.

For BLOCKS and BLOCKED-BY classifications, use the `DependencySignal.type` field returned by `issue-lifecycle`'s `detectDependencies` (Dependencies section) to populate these entries. Do not duplicate the signal detection logic here — delegate it.

**2e. Same-coverage check.** Look for issues with the same `exec:*` mode AND overlapping stage coverage. These are candidates for batching or sequencing.

**2f. Velocity-aware staleness detection.** Detect issues that are statistical outliers in age relative to the project's current velocity. The sibling scan from Step 2b already provides the issue set — no additional API calls are needed.

**Algorithm:**

1. Extract the numeric issue IDs from the sibling set (e.g., CIA-510 → 510, CIA-532 → 532).
2. **If 10 or more siblings:** Compute the interquartile range (IQR).
   - Sort the issue numbers. Find Q1 (25th percentile) and Q3 (75th percentile).
   - IQR = Q3 - Q1.
   - Lower fence = Q1 - `planning.stale_issue_iqr_multiplier` * IQR (default multiplier: 1.5).
   - Any issue with a number below the lower fence is flagged as **LIKELY STALE**.
3. **If fewer than 10 siblings (fallback):** Compute the median issue number and the median gap between consecutive sorted issue numbers.
   - An issue is flagged as **LIKELY STALE** if its gap from the nearest sibling exceeds `median_gap * 3`.
4. Add each flagged issue to the Step 2d overlap table with classification `LIKELY STALE`.
5. **Advisory only** — present flagged issues in the Planning Context Bundle for human review. Never auto-cancel or auto-close based on staleness detection alone.

**Example:** Sibling scan returns issues CIA-498, CIA-510, CIA-515, CIA-520, CIA-522, CIA-525, CIA-528, CIA-530, CIA-532, CIA-215. Q1 = 512.5, Q3 = 529, IQR = 16.5. Lower fence = 512.5 - 1.5 * 16.5 = 487.75. CIA-215 (below 487.75) is flagged as LIKELY STALE.

The IQR multiplier is configurable via `planning.stale_issue_iqr_multiplier` in `.ccc-preferences.yaml` (default: 1.5). Lower values increase sensitivity (flag more issues); higher values decrease sensitivity.

**Budget:** 10-15 seconds. Use `limit` on all queries.

**If no project tracker is connected:** Skip Steps 2 and 3 entirely. The bundle contains only codebase context. Log: "Preflight: no project tracker connected -- codebase-only mode."

### Step 3: Zoom Out

Widen the aperture beyond the immediate task to understand the strategic context.

**3a. Initiative context.** What initiative does this project belong to? Fetch the initiative name and status. Understanding the portfolio-level goal prevents tunnel vision.

**3b. Milestone context.** Invoke the **milestone-management** skill to fetch milestone data. Use the cached `list_milestones` result (milestone-management maintains a session-scoped cache). Include in the Planning Context Bundle:
- Milestone name and target date
- Issue count by status (Done / In Progress / Todo)
- Health signal (On Track / At Risk / Overdue)
- Whether the current task is already assigned to a milestone

This replaces any direct `list_milestones` calls from within preflight. Delegate to milestone-management and consume its data. If milestone data is unavailable, note "No milestone assigned" in the bundle and continue.

**3c. Relevant agents and tools.** From the codebase index, identify which agents, tools, or integrations are relevant to the current task. This prevents plans that ignore available capabilities.

**3d. Recent decisions.** Check for Linear documents attached to the project or parent issue. Read the last 10 comments on the parent issue (per the issue context bundle protocol). Surface any decisions, constraints, or context that should inform the plan.

**Budget:** 3-5 seconds. Single `get_issue` for parent, single `list_issues` for milestone.

### Step 4: Research Dependency Check

Before planning implementation, verify that related research spikes are resolved. Building on unvalidated assumptions is the most expensive failure mode in multi-session plans.

**4a. Find related spikes.** From the sibling issues gathered in Step 2, filter for issues with `type:spike` or `exec:spike` labels that are not Done or Cancelled. Also check: does the current issue's description reference any research, investigation, or evaluation that hasn't been completed?

**4b. Classify each unresolved spike:**

| Classification | Meaning | Action |
|----------------|---------|--------|
| **BLOCKING** | Current issue's design depends on spike findings | **STOP.** Flag the spike for immediate dispatch. Do not proceed to spec. |
| **INFORMING** | Spike findings would improve the design but aren't required | **WARN.** Note the spike, proceed with caveats documented. |
| **UNRELATED** | Spike exists in same project but has no bearing on current issue | **SKIP.** No action needed. |

**4c. Output.** If any BLOCKING spikes exist, add to the Planning Context Bundle:

```
### Research Dependencies (BLOCKING)
| Spike | Title | Status | Why Blocking |
```

This is a **hard pause** -- present the blocking spikes to the user and recommend dispatching them before proceeding with the current issue's spec.

**Budget:** 0-2 seconds. This filters data already gathered in Step 2.

### Step 5: Timeline Validation

For any deferred work mentioned in the plan or task context, validate that the deferral has a technical justification.

For each deferred item, answer:

1. **What is the EXPLICIT dependency or blocker?** Is there a specific issue, PR, or technical prerequisite that must complete first?
2. **Is this TECHNICAL or ASSUMED?**
   - **Technical:** Code needs X before Y can be built. There is a concrete dependency.
   - **Assumed:** "We'll do this after the conference" or "later" with no stated blocker.
3. **If assumed:** Flag as "No technical blocker -- consider moving earlier." This does not mean the deferral is wrong, only that it should be a conscious human decision rather than an unexamined assumption.

**Budget:** 0-2 seconds. This is a local analysis of data already gathered in Steps 1-3. No new API calls.

### Step 6: Output the Planning Context Bundle

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
| [CIA-XXX](https://linear.app/claudian/issue/CIA-XXX) | Title | OVERLAPPING | Rationale |

### Research Dependencies
[Table of blocking/informing spikes, or OMITTED if no unresolved spikes found]

| Spike | Title | Status | Classification | Impact |
|-------|-------|--------|----------------|--------|
| [CIA-XXX](https://linear.app/claudian/issue/CIA-XXX) | Title | Backlog | BLOCKING | Impact |

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
| Research dependency check | 0-2s | Filter Step 2 results for `type:spike` / `exec:spike` labels |
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
- **Duplicate skill logic.** Dependency detection is owned by the `issue-lifecycle` skill (Dependencies section). Milestone data is owned by `milestone-management`. Preflight delegates to these skills rather than reimplementing their logic.

## Cross-Skill References

- **issue-lifecycle** (Dependencies section) -- `detectDependencies` utility called in Step 2c to surface BLOCKS/BLOCKED-BY signals from issue descriptions
- **milestone-management** -- Invoked in Step 3b to fetch milestone health data for the Planning Context Bundle; uses session-scoped cache
- **go command** -- Step 1.5 in `go.md` invokes this preflight before routing to planning phases
- **write-prfaq** -- Step 1.5 in `write-prfaq.md` invokes this preflight before spec drafting
- **issue-lifecycle** -- Sibling issues gathered in Step 2 follow the issue naming conventions defined in `issue-lifecycle`
