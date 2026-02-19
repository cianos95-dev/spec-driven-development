---
name: dispatch-readiness
description: |
  Detect when blocked issues become unblocked by scanning downstream dependencies after blocker resolution.
  Produces a readiness report listing issues whose blockers are all Done, enabling automatic dispatch.
  Integrates with /ccc:go --scan for on-demand scanning and the session-start hook for passive detection.
  Use when checking for newly unblocked work, after completing a blocking issue, reviewing the dispatch
  queue, or investigating stalled dependency chains.
  Trigger with phrases like "scan for unblocked issues", "what's ready to dispatch", "check blockers",
  "readiness scan", "unblocked tasks", "dispatch queue", "cleared blockers", "dependency scan",
  "what can I work on next", "any issues unblocked".
---

# Dispatch Readiness

Detect when blocked issues become unblocked. When a blocking issue is marked Done, this skill identifies all downstream issues whose blockers have fully cleared, making them ready for dispatch.

## Problem

When a blocking issue is completed, nothing automatically happens to downstream issues. They sit in Backlog or Todo with cleared blockers until someone manually notices. This creates invisible delays in the execution pipeline.

Real examples from the Claudian workspace:
- CIA-307 marked Done → CIA-313 sat in Backlog for days (nobody noticed the unblock)
- CIA-395 marked Done → CIA-297, CIA-394 stayed blocked in the plan
- CIA-317 had no blockers → sat unnoticed for 6 days

## Readiness Pipeline

```
Issue marked Done
  → Check: does this issue block anything?
    → YES → For each downstream issue:
      → Are ALL blockers now Done?
        → YES → Flag as ready (report + optional label)
        → NO → Skip (still blocked by other issues)
    → NO → No action needed
```

The key distinction: an issue is only "ready" when **all** of its blockers are Done, not just one.

## When to Use

- **After completing work** — Run a scan to see if your completed issue unblocked anything.
- **Session start** — Passive scan reveals work that became available since the last session.
- **Planning** — Before starting a new cycle, check what's been unblocked.
- **Stall investigation** — When work feels slow, scan for issues sitting with cleared blockers.

## Scan Modes

### Mode 1: Full Scan (default)

Scan all issues in the target project(s) that have `blockedBy` relations. Check each one for full readiness.

**Algorithm:**

```
FUNCTION full_scan(project, statuses):
  candidates = list_issues(
    project: project,
    status: statuses,       # Default: ["Backlog", "Todo"]
    includeRelations: true,
    limit: 50
  )

  ready = []
  still_blocked = []

  FOR each issue in candidates:
    IF issue has no blockedBy relations:
      SKIP  # Not a blocked issue

    all_clear = true
    pending_blockers = []

    FOR each blocker in issue.blockedBy:
      blocker_detail = get_issue(blocker.id)
      IF blocker_detail.status NOT IN ["Done", "Canceled", "Duplicate"]:
        all_clear = false
        pending_blockers.append(blocker_detail)

    IF all_clear:
      ready.append(issue)
    ELSE IF len(pending_blockers) < len(issue.blockedBy):
      # Some blockers cleared but not all — partially unblocked
      still_blocked.append({issue, pending_blockers})

  RETURN {ready, still_blocked}
```

**Performance budget:** Full scan makes 1 `list_issues` call + 1 `get_issue` per blocker relation. For a typical workspace with ~20 blocked issues and ~2 blockers each, this is ~41 API calls. Well within session budget.

### Mode 2: Targeted Scan

When a specific issue was just completed, scan only its direct downstream dependents.

**Algorithm:**

```
FUNCTION targeted_scan(completed_issue_id):
  issue = get_issue(completed_issue_id, includeRelations: true)

  IF issue has no "blocks" relations:
    RETURN {ready: [], message: "This issue does not block anything."}

  ready = []

  FOR each downstream in issue.blocks:
    downstream_detail = get_issue(downstream.id, includeRelations: true)

    IF downstream_detail.status IN ["Done", "Canceled", "Duplicate"]:
      SKIP  # Already resolved

    all_clear = true
    FOR each blocker in downstream_detail.blockedBy:
      IF blocker.id == completed_issue_id:
        CONTINUE  # This is the one we just completed
      blocker_detail = get_issue(blocker.id)
      IF blocker_detail.status NOT IN ["Done", "Canceled", "Duplicate"]:
        all_clear = false
        BREAK

    IF all_clear:
      ready.append(downstream_detail)

  RETURN {ready}
```

**Performance budget:** Targeted scan makes 1 + N calls (where N is the number of downstream issues). Typically 2-5 calls.

### Mode 3: Session-Start Passive Scan

A lightweight version of the full scan that runs during session initialization. It checks for newly unblocked issues since the last session and reports them in the session-start output.

**Algorithm:**

Same as full scan but with these constraints:
- Limited to the **current project** (detected from `.ccc-state.json` or git remote)
- Only checks issues in **Backlog** and **Todo** statuses
- Capped at **10 candidates** to keep startup fast
- Output is a single summary line (not the full report)

**Performance budget:** Max 1 + 10×2 = 21 API calls. Acceptable for session start.

## Readiness Report Format

### Full Report (for `/go --scan` and direct invocation)

```markdown
## Dispatch Readiness Report

**Date:** [timestamp]
**Project:** [project name]
**Issues scanned:** N
**Newly ready:** N
**Partially unblocked:** N

### Ready for Dispatch

These issues have ALL blockers cleared and can be picked up immediately:

| Issue | Title | Priority | Estimate | Cleared Blockers |
|-------|-------|----------|----------|-----------------|
| CIA-313 | Build search component | High | 3pt | CIA-307 (Done Feb 14) |
| CIA-394 | Add filter endpoints | Medium | 5pt | CIA-395 (Done Feb 15), CIA-296 (Done Feb 13) |

### Partially Unblocked

These issues have some blockers cleared but are still waiting on others:

| Issue | Title | Cleared | Remaining |
|-------|-------|---------|-----------|
| CIA-297 | Integrate search API | 1/2 | CIA-398 (In Progress) |

### Suggested Actions

1. **CIA-313** — Ready. Run `/ccc:go CIA-313` to start.
2. **CIA-394** — Ready. Run `/ccc:go CIA-394` to start.
3. **CIA-297** — Waiting on CIA-398. Monitor or help unblock.
```

### Session-Start Summary (for hook output)

```
[CCC] Readiness scan: 2 issues newly unblocked (CIA-313, CIA-394). Run /ccc:go --scan for details.
```

If no newly unblocked issues are found:
```
[CCC] Readiness scan: no newly unblocked issues found.
```

### Targeted Report (after completing a specific issue)

```markdown
## Dispatch Readiness — CIA-307 Completed

Completing CIA-307 unblocked the following:

| Issue | Title | Status | All Clear? |
|-------|-------|--------|-----------|
| CIA-313 | Build search component | Todo | Yes — ready for dispatch |
| CIA-297 | Integrate search API | Backlog | No — still blocked by CIA-398 |

**Next:** Run `/ccc:go CIA-313` to pick up the unblocked issue.
```

## `/go --scan` Integration

The `/go` command accepts a `--scan` flag that triggers a full readiness scan:

```
/ccc:go --scan              # Full scan of current project
/ccc:go --scan CIA-307      # Targeted scan after completing CIA-307
/ccc:go --scan --all        # Full scan across all projects
```

**Behavior:**
1. Run the appropriate scan mode (full or targeted).
2. Display the readiness report.
3. If any issues are ready, offer to start the highest-priority one via the standard `/go` routing.
4. If no issues are ready, report that and suggest checking back after completing current work.

**Flag combinations:**
- `--scan` alone: Full scan of the current project (from `.ccc-state.json` or git remote).
- `--scan CIA-XXX`: Targeted scan for downstream issues of the specified issue.
- `--scan --all`: Full scan across all projects in the team. More expensive (multiplies API calls by project count).

## Session-Start Hook Integration

The session-start hook includes a passive readiness scan after the existing checks (prerequisites, spec load, index check, git state, execution state).

**Addition to `hooks/session-start.sh`:**

After the execution state check (section 5), add a readiness scan section:

```bash
# --- 6. Dispatch readiness scan ---
# Check for issues that became unblocked since last session
# Only runs when Linear MCP is available and we can detect the project
```

**Important constraints:**
- The session-start hook runs as a shell script. It cannot call Linear MCP tools directly.
- The hook's role is to **signal** that a readiness scan should happen, not to perform it.
- The hook outputs a message that prompts Claude to invoke the dispatch-readiness skill.

**Implementation approach:**
- The hook checks if `.ccc-state.json` exists (indicating an active project context).
- If it does, the hook outputs: `[CCC] Readiness scan available. Use /ccc:go --scan to check for unblocked issues.`
- The actual API-calling scan is performed by Claude when the user (or the go command) invokes it.

This avoids the shell-to-MCP boundary problem. The hook is a lightweight reminder; the skill does the heavy lifting.

## Label Strategy

The scan can optionally apply a label to flag ready issues:

**Label:** `auto:ready-for-dispatch`

**Behavior:**
- Only applied if the user confirms (not automatic by default).
- The readiness report includes a prompt: "Apply `auto:ready-for-dispatch` label to N ready issues? [y/n]"
- If applied, the label makes ready issues discoverable via Linear filters without running another scan.
- The label is removed when the issue moves to "In Progress" (manual cleanup or via the go command).

**Why optional:** Labeling is a write operation that modifies shared state. The advisory-only principle means we detect and report; the human decides whether to label.

## Stale Blocker Detection

Beyond readiness, the scan also detects stale blocking relationships:

| Signal | Threshold | Severity | Action |
|--------|-----------|----------|--------|
| Blocker in Backlog >14 days | 14 days | Warning | "CIA-XXX blocks CIA-YYY but has been in Backlog for N days" |
| Blocker has no assignee | Any | Info | "CIA-XXX blocks CIA-YYY but is unassigned" |
| Circular dependency | Any | Error | "Circular dependency detected: CIA-A → CIA-B → CIA-A" |
| Blocker is Canceled but not unlinked | Any | Warning | "CIA-XXX was Canceled but still blocks CIA-YYY" |

Stale blocker findings are included in the readiness report under a "Dependency Health" section. This overlaps with the `dependency-management` skill but is focused specifically on dispatch-blocking relationships, not general dependency health.

## Graceful Degradation

| Failure | Response |
|---------|----------|
| Linear API unavailable | Skip scan entirely. Report: "Readiness scan skipped — Linear API unavailable." |
| `list_issues` returns no results | Report: "No blocked issues found in [project]. Nothing to scan." |
| `get_issue` fails for a blocker | Skip that blocker. Report the issue as "partially scanned" with a note about the failed lookup. |
| No `.ccc-state.json` and no git remote | Cannot determine project scope. Report: "Readiness scan requires a project context. Use --scan with a project name or ensure .ccc-state.json exists." |
| Rate limit hit during scan | Stop scanning. Report partial results with: "Scan incomplete — rate limit reached after N issues." |

## Performance Budget

| Scan Mode | API Calls | Typical Duration |
|-----------|-----------|-----------------|
| Full scan (1 project) | 1 + 2×N (N = blocked issues) | ~20-40 calls |
| Targeted scan | 1 + N (N = downstream issues) | ~3-6 calls |
| Session-start passive | 0 (hook only signals) | Instant |
| Full scan (all projects) | P × (1 + 2×N) per project | ~60-120 calls |

**Budget limit:** If the full scan would exceed 50 API calls, truncate to the first 25 blocked issues and note: "Scan truncated — showing first 25 of N blocked issues."

## Cross-Skill References

- **execution-engine** — The execution loop can trigger a targeted scan when completing a task that has `blocks` relations. This closes the loop: complete task → scan downstream → surface ready work.
- **parallel-dispatch** — Ready issues identified by this skill are candidates for parallel dispatch. The readiness report feeds into dispatch planning.
- **dependency-management** — Handles general dependency health (creation, validation, visualization). Dispatch-readiness focuses specifically on the dispatch-blocking subset.
- **planning-preflight** — Preflight checks issue dependencies as part of planning. Dispatch-readiness operates at a different time (post-completion, session-start) and with a different focus (readiness, not overlap).
- **issue-lifecycle** — The lifecycle skill's carry-forward protocol may move issues between milestones. Dispatch-readiness operates after carry-forward, detecting issues that are ready regardless of which milestone they're in.
- **milestone-management** — Milestone-level readiness (is the milestone on track?) vs. issue-level readiness (is this specific issue unblocked?). Complementary, not overlapping.
