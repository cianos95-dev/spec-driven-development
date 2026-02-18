---
description: |
  Audit project tracker issues for label consistency, stale items, and missing metadata.
  Use when running periodic issue health checks, cleaning up stale backlog items, fixing missing labels or project assignments, or triaging old issues interactively.
  Trigger with phrases like "audit my issues", "issue hygiene check", "clean up stale issues", "fix missing labels", "triage the backlog", "project health score".
argument-hint: "[--check | --fix | --triage]"
allowed-tools: Read, Grep, Glob
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

> **Check groups run in order:** Label Consistency → Metadata Completeness → Staleness → Milestone Health → Document Health → Dependency Health → Resource Freshness.

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
| Missing project assignment | Error | Every issue must belong to a project. Infer from title and description keywords using the project routing table: CCC/tooling/MCP → Claude Command Centre (CCC), Alteri features/research → Alteri, new ideas/evaluations → Ideas & Prototypes, SoilWorx → Cognito SoilWorx. |
| Misrouted project assignment | Warning | Issue keywords suggest a different project than the one assigned. Cross-check title and description against the project routing table. Flag if the assigned project doesn't match the topic. |
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

### Milestone Health

Delegates to the `milestone-management` skill for milestone-level checks. For each project that has active milestones:

1. Call `list_milestones(project)` (use session cache if available — do NOT re-fetch if already called this session).
2. Evaluate active milestones (exclude completed/archived) against these rules:

| Check | Severity | Rule |
|-------|----------|------|
| Orphaned issue (no milestone) | Warning | Open issue exists in a project that has active milestones but the issue has no milestone assigned. Suggest assigning to the nearest active milestone. |
| Expired milestone with open issues | Warning | Milestone target date has passed and one or more issues remain open. Flag for carry-forward (see `milestone-management` skill). |
| Milestone with 0% progress and issues | Info | Milestone has issues but 0 Done/Canceled. May be newly created (normal) or stalled (flag if >14 days old). |

**Orphan detection:** If `get_issue` returns a milestone reference that `list_milestones` does not contain (milestone was deleted), flag as Error: "Issue [ID] references deleted milestone [name] — orphaned, needs reassignment."

### Document Health

Delegates to the `document-lifecycle` skill for document-level checks. For each project:

1. Read the project description and scan for `<!-- no-auto-docs -->`. If present, skip document checks for that project.
2. Call `list_documents(projectId)` to get all project documents.
3. Evaluate against these rules:

| Check | Severity | Rule |
|-------|----------|------|
| Missing Key Resources doc | Warning | No document matching the Key Resources naming pattern (`Key Resources`) exists and the project has not opted out. |
| Missing Decision Log | Warning | No document matching the Decision Log naming pattern (`Decision Log`) exists and the project has not opted out. |
| Stale document | Warning | Document's `updatedAt` exceeds its type-specific staleness threshold. Default threshold for unrecognized document types is 30 days. |
| 100+ documents in project | Info | Staleness check was limited to first 100 documents; audit may be incomplete. |

**Staleness thresholds (from `document-lifecycle` skill):** Key Resources and Decision Log use their configured thresholds (default 30 days for unspecified). Documents typed as "Project Update" have no staleness threshold — skip.

### Dependency Health

Delegates to the `dependency-management` skill for relation-level checks. For each open issue:

| Check | Severity | Rule |
|-------|----------|------|
| Circular dependency | Error | Issue A blocks Issue B, and Issue B (directly or transitively) blocks Issue A. Flag both issues. Circular chains of any depth are flagged. |
| Blocked issue with stale blocker | Warning | Issue is marked blocked-by another issue that has had no status change or activity in >14 days. The blocker may be abandoned — flag for human review. |
| Dependency chain depth >3 | Warning | A dependency chain (A blocks B blocks C blocks D or deeper) that is >3 levels deep. Long chains indicate over-specification or a need for milestone restructuring. |

**Circular detection algorithm:** For each issue with `blocks` relations, perform a depth-first traversal of the dependency graph. If the traversal revisits the starting node, a cycle exists. Report all nodes in the cycle.

**Chain depth algorithm:** For each "root" issue (no `blockedBy` relations), walk the blocks chain and count depth. Flag any chain where depth > 3.

### Resource Freshness

Delegates to the `resource-freshness` skill for ecosystem-wide staleness detection. This check group audits resources beyond individual issues: project descriptions, initiative status updates, milestone health, document freshness, and plugin reference doc drift.

1. Call the `resource-freshness` skill with the current project scope.
2. The skill returns findings in the standard `{severity, resource, category, details, suggested_fix}` format.
3. Merge findings into the overall hygiene report.

| Check | Severity | Rule |
|-------|----------|------|
| Stale project description | Warning | Project description not updated in >14 days and milestone progress has occurred. Threshold configurable per project via `<!-- freshness:N -->`. |
| Overdue initiative status update | Warning | Initiative status update overdue per weekly cadence (>7 days since last update). |
| Expired milestone with open issues | Warning | Milestone target date has passed with open issues remaining. |
| Stalled milestone | Warning | Milestone has issues but 0% completion after >14 days. |
| Stale document | Warning | Document `updatedAt` exceeds its type-specific staleness threshold (per `document-lifecycle` taxonomy). |
| Reference doc count mismatch | Error | README.md skill/command/agent/hook counts differ from marketplace.json. |
| Reference doc version mismatch | Warning | README.md or plugin-manifest.md version differs from marketplace.json. |

**Plugin repo detection:** Category 5 (reference doc drift) only runs when the current working directory contains `.claude-plugin/marketplace.json`. Otherwise skipped with note.

**Session cache:** Reuses milestone and document data fetched by earlier check groups. Do NOT re-fetch.

## Step 3: Report

Generate a structured hygiene report:

```
## Hygiene Report

**Date:** [timestamp]
**Issues audited:** N
**Projects audited:** N
**Hygiene score:** XX/100

### Summary
- Errors: N
- Warnings: N
- Info: N

### Check Group Coverage
| Group | Checks Run | Errors | Warnings | Info |
|-------|-----------|--------|----------|------|
| Label Consistency | N | N | N | N |
| Metadata Completeness | N | N | N | N |
| Staleness | N | N | N | N |
| Milestone Health | N | N | N | N |
| Document Health | N | N | N | N |
| Dependency Health | N | N | N | N |
| Resource Freshness | N | N | N | N |

### Errors (must fix)
| Issue/Project | Check | Details | Suggested Fix |
|---------------|-------|---------|---------------|
| [ID or project name] | [Check name] | [What's wrong] | [What to do] |

### Warnings (should fix)
| Issue/Project | Check | Details | Suggested Fix |
|---------------|-------|---------|---------------|
| [ID or project name] | [Check name] | [What's wrong] | [What to do] |

### Info (nice to fix)
| Issue/Project | Check | Details | Suggested Fix |
|---------------|-------|---------|---------------|
| [ID or project name] | [Check name] | [What's wrong] | [What to do] |
```

**Notes on the report table:** Milestone, document, and dependency findings are scoped to a project or issue as appropriate. The "Issue/Project" column uses an issue ID (e.g., `CIA-123`) for issue-level findings and a project name (e.g., `Claude Command Centre`) for project-level findings (missing docs, milestone expiry).

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
3. **Add project assignment** — Based on keyword matching in title/description against the project routing table (CCC/tooling → CCC, Alteri → Alteri, new ideas → Ideas & Prototypes, SoilWorx → Cognito SoilWorx).
4. **Flag misrouted project** — If keyword analysis suggests a different project than the one assigned, add a comment noting the potential misrouting. Do NOT auto-reassign (project changes may have downstream effects).
5. **Add comment on stale items** — Post a comment noting the issue has been flagged as stale by the hygiene audit.
6. **Assign orphaned issue to active milestone** — If an issue is in a project with exactly one active milestone and the issue has no milestone, auto-assign via `update_issue(id, milestone: "name")`. Use the `milestone-management` skill's assignment protocol. If multiple active milestones exist, flag but do not auto-assign.
7. **Create missing Key Resources doc** — If a project is missing a Key Resources document and has not opted out (`<!-- no-auto-docs -->`), create it using the template from the `document-lifecycle` skill.

For each fix applied, log the issue ID, what was changed, and why.

Do NOT auto-fix:
- Priority (human-owned field)
- Assignee (requires judgment)
- Status transitions (requires verification)
- Issue closure (use `/close` instead)
- Circular dependencies (require human restructuring)
- Milestone expiry carry-forward (always human-confirmed per `milestone-management` skill)
- Decision Log creation (requires project context the agent may not have)

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
| **Project has no active milestones** | Skip milestone health checks for that project. Report: "Milestone health: skipped (no active milestones in [project])." |
| **`list_milestones` fails or returns error** | Skip milestone health checks for that project. Report: "Milestone health: skipped (API error)." Do not fail the entire hygiene run. |
| **Project has opted out of auto-docs** | Skip document health checks for that project. Report: "Document health: skipped ([project] has opted out via <!-- no-auto-docs -->)." |
| **`list_documents` fails or returns error** | Skip document checks for that project. Report: "Document health: skipped (API error)." Do not fail the entire hygiene run. |
| **No issues have dependency relations** | Skip dependency health checks entirely. Report: "Dependency health: skipped (no issues have dependency relations)." |
| **Circular dependency detected** | Always report as Error. Never attempt to auto-fix a circular dependency — breaking cycles requires human architectural judgment. |
| **Dependency chain >3 detected** | Report as Warning. Do not auto-fix. Suggest the user review and potentially decompose or restructure. |
