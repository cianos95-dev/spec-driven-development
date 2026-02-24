---
name: dispatch-readiness
description: |
  Detect issues that have become unblocked and are ready for dispatch.
  Uses an inverted scan protocol: starts from recently-completed (Done) issues,
  looks outward to find downstream issues whose blockers are now all cleared.
  Enforces a 20-call API budget and 30-minute result cache.
  Use when checking for newly-unblocked work, during session start, or when
  planning next tasks.
  Trigger with phrases like "scan for unblocked issues", "dispatch readiness",
  "what's ready to work on", "check blocked issues", "unblocked scan",
  "ready for dispatch", "--scan".
---

# Dispatch Readiness

When a blocking issue is marked Done, downstream issues become unblocked -- but nothing in the project tracker surfaces this automatically. Issues sit in Backlog/Todo with cleared blockers until someone manually notices. This skill detects those newly-unblocked issues via an inverted scan protocol.

## Pre-Step: Gather Issue Context Bundle

Before executing this skill, gather the issue context bundle for candidate issues (see `issue-lifecycle/references/issue-context-bundle.md`). Before flagging as ready to dispatch, check comments for blocker resolution signals and prior dispatch results. Use the minimum viable bundle (2 API calls per issue) to stay within the 20-call budget.

## Inverted Scan Protocol

The naive approach (scan all Backlog/Todo issues, check each for blockers) causes O(n * m) API calls where n=issues and m=blockers per issue. The inverted scan starts from recently-completed issues and looks outward, capping API calls.

### Algorithm

```
Pass 1: list_issues(status: "Done", limit: 50, orderBy: completedAt_DESC)
  → Collect up to 50 recently completed issues (most recent first)

Pass 2: For each Done issue in order, up to 10 issues (Pass 2 budget):
  → get_issue(includeRelations: true)
  → Filter: does this issue have `blocks` relations?
  → Collect downstream issue IDs

Pass 3: For each unique downstream issue:
  → get_issue(includeRelations: true)
  → Check: is status Backlog or Todo?
  → Check: are ALL blockedBy issues now Done?
  → YES → Add to dispatch-ready list
  → NO → Skip (still blocked by other issues)
```

### Why Inverted?

| Approach | API Calls (100 issues, 2 blockers avg) | Direction |
|----------|---------------------------------------|-----------|
| Forward scan (all Backlog/Todo → check blockers) | 100 + 200 = 300 | Backlog → blockers |
| Inverted scan (Done → check downstream) | 1 + 10 + 9 = 20 | Done → blocked issues |

The inverted scan is O(d + b) where d=Done issues with blocks relations and b=unique downstream issues. In practice, most Done issues don't block anything, so d << n.

## API Call Budget

**Hard cap: 20 calls per scan invocation.**

| Phase | Max Calls | Purpose |
|-------|-----------|---------|
| Pass 1 | 1 | `list_issues(status: "Done", limit: 50)` |
| Pass 2 | 10 | `get_issue(includeRelations: true)` for Done issues with potential blocks |
| Pass 3 | 9 | `get_issue(includeRelations: true)` for downstream blocked issues |

### Budget Enforcement

- Track call count through all three passes
- If budget is exhausted mid-scan, stop and return partial results
- Partial results include a warning: `"Budget exhausted (20/20 calls). N issues not scanned."`
- Pass 2 prioritizes Done issues by most recent completion date (most likely to have newly-unblocked downstream)

### Budget Optimization

- **Pass 2 early exit:** If a Done issue's `blocks` array from `get_issue` is empty, skip it (no downstream impact). This costs 1 call but saves multiple Pass 3 calls.
- **Pass 3 deduplication:** If multiple Done issues block the same downstream issue, only check the downstream issue once.
- **Pass 1 limit tuning:** 50 is the default. For projects with high throughput, reduce to 20 to preserve budget for Passes 2 and 3.

## Cache Strategy

Scan results are cached in session memory to avoid redundant API calls.

| Parameter | Value |
|-----------|-------|
| TTL | 30 minutes |
| Scope | Session-scoped (not persisted across sessions) |
| Key | Project ID (timestamp stored in cached value for TTL check) |
| Invalidation | TTL expiry, `--force` flag, or project change |

### Cache Behavior

```
/go --scan
  → Check cache: is there a valid result within TTL?
    → YES → Return cached result with note: "Cached result from [timestamp]. Use --force for fresh scan."
    → NO → Run full inverted scan, cache result, return

/go --scan --force
  → Bypass cache, run full scan, update cache
```

## Output Format

```
Dispatch Readiness Scan -- [project name]

| ID | Title | Cleared Blockers | Suggested Action |
|----|-------|-----------------|------------------|
| [CIA-XXX](url) | Issue title | CIA-YYY (Done), CIA-ZZZ (Done) | Move to Todo / assign to agent |

N issues ready for dispatch. M issues still blocked.
API calls used: X/20. Cache expires: [HH:MM].
```

### Output Rules

- Issue IDs are clickable markdown links: `[CIA-XXX](https://linear.app/claudian/issue/CIA-XXX)`
- Cleared blockers column lists all blockers that were Done at scan time
- Suggested action is one of:
  - `Move to Todo` — if issue is in Backlog
  - `Assign to agent` — if issue is in Todo but unassigned
  - `Ready for /go` — if issue is in Todo and assigned
- If no issues are dispatch-ready: `"No newly-unblocked issues found. All blocked issues still have pending blockers."`
- If partial results due to budget: append `"(partial — budget exhausted)"`

## Sub-Issue Limitation (Phase 1)

**Known limitation:** `list_issues` with project filter returns top-level issues only. Sub-issues are excluded from the scan.

**Impact:** If a sub-issue has `blockedBy` relations, the scan will not detect when those blockers are cleared. Sub-issues must be checked manually or via `/go --next` on the parent issue.

**Phase 2 mitigation:** Recursive sub-issue traversal will be added when session-start hook integration is implemented. The hook will call `get_issue(includeRelations: true)` on parent issues to discover sub-issue blocking relationships.

## Session-Start Integration (Phase 2 — Future)

When implemented, the session-start hook will:

1. Run the inverted scan with a reduced budget (10 calls)
2. Display results in the session greeting
3. Use the same cache strategy (skip if scanned within 30 min)
4. Only scan the project associated with the current working directory

Integration point: `hooks/scripts/ccc-session-start.sh` → invoke dispatch-readiness scan.

## MCP Tools Used

| Tool | Usage |
|------|-------|
| `list_issues` | Pass 1: fetch Done issues (with `status` filter and `limit`) |
| `get_issue` | Pass 2 & 3: fetch relations for Done and downstream issues (`includeRelations: true`) |

No write operations. This skill is read-only — it detects readiness but does not modify issue status or labels. The caller (e.g., `/go --scan`) decides whether to act on the results.

## Cross-Skill References

- **go command** — `--scan` and `--scan --force` flags route to this skill's protocol
- **dependency-management** — Consumes the same `blocks`/`blockedBy` relation data; this skill reads relations but does not modify them
- **planning-preflight** — Similar scan pattern (Linear landscape scan in Step 2); this skill is narrower (only blocker resolution)
- **issue-lifecycle** — Status transitions (Backlog → Todo → In Progress) are suggested but not enacted by this skill
- **parallel-dispatch** — Coordinates multi-session work; dispatch-readiness feeds into dispatch decisions
