---
description: |
  Audit project tracker issues for label consistency, stale items, and missing metadata.
  Use when running periodic issue health checks, cleaning up stale backlog items, fixing missing labels or project assignments, or triaging old issues interactively.
  Trigger with phrases like "audit my issues", "issue hygiene check", "clean up stale issues", "fix missing labels", "triage the backlog", "project health score".
argument-hint: "[--check | --fix | --triage]"
platforms: [cli, cowork]
---

# Issue Hygiene Audit

Audit open issues in the connected project tracker for label consistency, stale items, missing metadata, and overall project health. Supports three modes of operation.

## Modes

- **`--check`** (default) — Read-only audit. Report findings without making changes.
- **`--fix`** — Apply safe, non-destructive fixes automatically. Report what was changed.
- **`--triage`** — Interactive walkthrough of stale backlog items with user-driven decisions.

If no mode is specified, default to `--check`.

## Step 1: Fetch Open Issues

Query the connected project tracker for all open issues. Delegate bulk reads to a subagent to manage context.

Collect for each issue:
- Title, ID, status, assignee
- Labels (all)
- Project assignment
- Priority
- Age (days since creation)
- Last updated (days since last activity)
- Linked PRs (if any)

## Step 2: Run Hygiene Checks

Evaluate every open issue against the following rules. Each finding is classified as Error, Warning, or Info.

### Label Consistency

| Check | Severity | Rule |
|-------|----------|------|
| Missing `spec:*` label | Warning | Every issue should have a spec lifecycle label. Suggest based on current state: Backlog/Todo = `spec:draft`, In Progress = `spec:implementing`, Done = `spec:complete`. |
| Missing `exec:*` label | Warning | Every issue should have an execution mode label. Suggest based on description complexity: short description + single concern = `exec:quick`, has acceptance criteria = `exec:tdd`, marked uncertain = `exec:pair`. |
| Conflicting labels | Error | An issue should not have both `spec:draft` and `spec:complete`, or multiple `exec:*` labels. |
| Orphaned `spec:implementing` | Warning | Issue has `spec:implementing` but status is not "In Progress". Either the label or status is stale. |

### Metadata Completeness

| Check | Severity | Rule |
|-------|----------|------|
| Missing project assignment | Error | Every issue must belong to a project. Infer from title and description keywords. |
| Unassigned issue | Warning | Issues without an assignee may be forgotten. Suggest agent assignment for implementation tasks, human assignment for decision tasks. |
| Missing priority | Info | Suggest a default priority based on labels and project. |
| Missing description | Warning | Issues with only a title and no description or acceptance criteria are under-specified. |

### Staleness

| Check | Severity | Rule |
|-------|----------|------|
| Cian-assigned issue > 14 days | Error | A human decision has been pending for over 2 weeks. Flag as stale decision requiring escalation. Query by `assignee = Cian`, not by label. |
| Backlog issue > 30 days | Warning | Issue has been in Backlog for over a month without activity. Flag for triage. |
| In Progress > 14 days without update | Warning | Issue marked In Progress but no comments or status changes in 2 weeks. May be abandoned. |
| Completed PR but issue still open | Warning | All linked PRs are merged but the issue was never closed. Suggest running `/close`. |

## Step 3: Report

Generate a structured hygiene report:

```
## Hygiene Report

**Date:** [timestamp]
**Issues audited:** N
**Hygiene score:** XX/100

### Summary
- Errors: N
- Warnings: N
- Info: N

### Errors (must fix)
| Issue | Check | Details | Suggested Fix |
|-------|-------|---------|---------------|
| [ID] | [Check name] | [What's wrong] | [What to do] |

### Warnings (should fix)
| Issue | Check | Details | Suggested Fix |
|-------|-------|---------|---------------|
| [ID] | [Check name] | [What's wrong] | [What to do] |

### Info (nice to fix)
| Issue | Check | Details | Suggested Fix |
|-------|-------|---------|---------------|
| [ID] | [Check name] | [What's wrong] | [What to do] |
```

**Hygiene score calculation:**
- Start at 100
- Each Error: -10 points
- Each Warning: -3 points
- Each Info: -1 point
- Floor at 0

## Step 4: Auto-Fix (if `--fix`)

Apply safe, non-destructive fixes only. A fix is safe if:
- It adds missing metadata (labels, project assignment) but does not remove or change existing metadata.
- It is based on clear heuristic rules, not subjective judgment.
- It does not change issue status or close issues.

Fixes applied:
1. **Add default `spec:*` label** — Based on current issue status.
2. **Add default `exec:*` label** — Based on description complexity heuristic.
3. **Add project assignment** — Based on keyword matching in title/description.
4. **Add comment on stale items** — Post a comment noting the issue has been flagged as stale by the hygiene audit.

For each fix applied, log the issue ID, what was changed, and why.

Do NOT auto-fix:
- Priority (human-owned field)
- Assignee (requires judgment)
- Status transitions (requires verification)
- Issue closure (use `/close` instead)

## Step 5: Interactive Triage (if `--triage`)

Walk through stale backlog issues one by one. For each issue, present:

```
## [Issue ID] — [Title]
**Age:** N days | **Priority:** [priority] | **Project:** [project]
**Description:** [first 2-3 sentences]
**Labels:** [list]

What would you like to do?
1. **Keep** — Leave in backlog, no changes
2. **Promote** — Move to current sprint / set higher priority
3. **Close** — Close as won't-fix with a comment explaining why
4. **Merge** — Merge with another issue (specify target)
5. **Skip** — Come back to this one later
```

Wait for user input on each issue before proceeding to the next. Track decisions and apply them in batch after the triage session is complete.

After triage, output a summary of all decisions made:

```
## Triage Summary
- Kept: N issues
- Promoted: N issues
- Closed: N issues
- Merged: N issues
- Skipped: N issues
```

## What If

| Situation | Response |
|-----------|----------|
| **Project tracker returns no issues** | Report a clean bill of health (score 100/100) and confirm the query parameters used. If the user expected issues, suggest checking team/project filters. |
| **Too many issues for context window** | Delegate the bulk read to a subagent. Process issues in batches (e.g., 25 at a time). Aggregate findings across batches into a single report. |
| **`--fix` would change a human-owned field** | Never auto-fix priority, assignee, status, or closure. Log the finding as a suggestion in the report and let the human act on it. |
