---
name: milestone-management
description: |
  Milestone lifecycle automation using Linear MCP tools. Handles assignment inference,
  completion checks, health reporting, carry-forward, and orphan detection.
  Use when creating issues that need milestone assignment, when issues transition to Done,
  when reporting milestone health at session exit, or when milestone target dates pass.
  Trigger with phrases like "assign milestone", "milestone health", "check milestone",
  "carry forward", "milestone report", "orphaned issues", "milestone status".
compatibility:
  surfaces: [code, cowork]
  tier: universal
---

# Milestone Management

Automates the milestone lifecycle within CCC projects. This skill owns all milestone CRUD, assignment logic, completion checks, health reporting, and carry-forward protocols. Other skills (notably `issue-lifecycle`) delegate milestone operations here rather than duplicating logic.

## Core Principle

Milestones are the primary progress-tracking mechanism at the project level. Every issue in a project should belong to a milestone. The agent automates assignment and monitoring but **never auto-closes milestones** -- closure is always a human decision proposed by the agent with evidence.

## Skill Boundary

**milestone-management owns:**
- All milestone CRUD (`create_milestone`, `update_milestone`, `get_milestone`, `list_milestones`)
- Assignment inference and auto-assignment
- Completion checks after issue status transitions
- Health reporting tables
- Carry-forward protocol for overdue milestones
- Orphan detection for deleted milestones

**issue-lifecycle delegates here:**
- During issue creation, `issue-lifecycle` calls into this skill for milestone assignment
- `issue-lifecycle` does NOT contain assignment logic -- it references this skill

**Clean boundary:** `issue-lifecycle` calls `milestone-management` as a dependency, never the reverse. This skill never modifies issue status, labels, or closure -- those remain in `issue-lifecycle`.

## MCP Tools Used

All milestone operations use the Linear MCP with these corrected signatures:

| Tool | Signature | Purpose |
|------|-----------|---------|
| `list_milestones` | `list_milestones(project: "name-or-id")` | Assignment inference, health reporting |
| `get_milestone` | `get_milestone(project: "name-or-id", query: "milestone-name-or-id")` | Completion checks, detail lookup |
| `update_issue` | `update_issue(id: "issue-id", milestone: "name-or-id")` | Assign or reassign milestone |
| `create_milestone` | `create_milestone(project: "name-or-id", name: "name", ...)` | New milestones (human-initiated) |
| `update_milestone` | `update_milestone(project: "name-or-id", id: "name-or-id", ...)` | Description/date updates |

**DO NOT** use `get_milestone(id)` without specifying `project`. The correct call is always `get_milestone(project, query)`.

**DO NOT** use `update_issue(milestoneId: ...)`. The correct field is `milestone: "name-or-id"`.

## Milestone Assignment Protocol

When any issue is created or moved to a project, check if a milestone is assigned. If unassigned, infer and assign the correct milestone.

### Assignment Flow

```
Issue created/moved to project
    |
    v
Has milestone assigned? --YES--> Done (no action)
    |
    NO
    v
Fetch milestones: list_milestones(project) [use cache if available]
    |
    v
Filter to active milestones (exclude completed/archived)
    |
    v
How many active milestones?
    |
    +--> 0: No active milestone. Inform user: "No active milestone in [project]. Skipping assignment."
    |
    +--> 1: Unambiguous. Auto-assign via update_issue(id, milestone: "name")
    |
    +--> 2+: AMBIGUOUS. Prompt user to choose (see Ambiguity Handling below)
    |
    v
Output confirmation message
```

### Ambiguity Handling

When multiple active milestones exist (e.g., overlapping target dates, parallel workstreams), **do not auto-assign**. Instead:

1. Present the active milestones to the user with context:
   ```
   Multiple active milestones found in [project]:
   1. "M1: Foundation" (target: 2026-03-01, 5/12 issues done)
   2. "M2: Polish" (target: 2026-03-15, 0/8 issues done)

   Which milestone should [issue-id] be assigned to?
   ```

2. Use `AskUserQuestion` with single-select. Each option: label is the milestone name, description includes target date and progress.

3. After user selection, assign via `update_issue(id, milestone: "selected-name")`.

**Only auto-assign when exactly one active milestone is unambiguous.**

### Visibility Confirmation

**Every** auto-assignment outputs a confirmation message to the user:

```
Assigned [CIA-XXX] to milestone [Milestone Name] (target: [YYYY-MM-DD])
```

If the milestone has no target date:

```
Assigned [CIA-XXX] to milestone [Milestone Name] (no target date set)
```

This confirmation is mandatory even in batch operations. The user must always know which milestone an issue was assigned to.

### Undo / Reassignment

To reassign an issue to a different milestone:

```
update_issue(id: "issue-id", milestone: "new-milestone-name")
```

This overwrites the previous milestone assignment. The agent supports reassignment on request:
- "Move [issue] to [milestone]" -- direct reassignment
- "This issue belongs in [milestone] instead" -- reassignment with context

Document the reassignment in a brief output: `Reassigned [CIA-XXX] from [Old Milestone] to [New Milestone]`

## Milestone Completion Check

Completion checks are **trigger-based, not polling**. They fire only on issue status transitions, never on a timer or schedule.

### Trigger

After any issue transitions to **Done** or **Canceled**:

1. Check if the issue has a milestone assigned
2. If yes, fetch the milestone: `get_milestone(project: "project-name", query: "milestone-name")`
3. Inspect all issues in the milestone
4. If **all** issues are Done or Canceled, propose closure

### Proposing Closure

**Never auto-close milestones.** Always propose:

```
All issues in milestone [Milestone Name] are complete (X Done, Y Canceled).
Propose marking this milestone as complete. Confirm?
```

Wait for explicit human confirmation before any milestone status change.

### Edge Cases

- **Milestone has 0 issues:** Do not propose closure. A milestone with no issues is likely newly created.
- **Milestone has only Canceled issues:** Still propose closure, but note: "All [N] issues were Canceled (none completed). Consider whether this milestone should be archived rather than completed."
- **Issue removed from milestone (not transitioned):** Does not trigger a completion check. Only status transitions trigger checks.

## Milestone Health Reporting

Report milestone progress as a compact table, either on demand or during session-exit.

### Report Format

```
| Milestone | Done | In Progress | Todo | Target | Health |
|-----------|------|-------------|------|--------|--------|
```

**Health indicators:**
- `On Track` -- target date is >3 days away, or no target date set
- `At Risk` -- target date is within 3 days and open issues remain
- `Overdue` -- target date has passed and open issues remain

### Filtering Rules

- **Show only active milestones.** Filter out archived and completed milestones.
- **Sort by target date ascending** (soonest deadline first). Milestones without target dates sort last.
- **Include issue counts** by status category (Done, In Progress, Todo/Backlog/Triage).

### Example Output

```
Milestone Health Report — Claude Command Centre (CCC)

| Milestone | Done | In Progress | Todo | Target | Health |
|-----------|------|-------------|------|--------|--------|
| Linear Mastery | 3 | 2 | 4 | 2026-03-01 | On Track |
| Plugin Polish | 0 | 1 | 5 | 2026-02-20 | At Risk |
| Q1 Cleanup | 1 | 0 | 0 | — | On Track |
```

### Integration Points

- **session-exit**: The session-exit protocol may include a milestone health table in the session summary when milestones were affected during the session
- **planning-preflight**: Step 3b (Zoom Out) consumes milestone context for the Planning Context Bundle
- **go command**: `/ccc:go --status` may display milestone health alongside issue status

## Carry-Forward Protocol

When a milestone's target date passes with open issues, propose moving incomplete issues to the next milestone.

### Flow

```
Milestone target date passed
    |
    v
Any open issues? --NO--> Propose marking milestone complete
    |
    YES
    v
Identify next milestone (by target date, same project)
    |
    v
For each open issue, check carry-forward count
    |
    +--> Count < 2: Propose moving to next milestone
    |
    +--> Count >= 2: FLAG for human review (see Loop Prevention)
    |
    v
Present proposal to user for confirmation
```

### Carry-Forward Tracking

Track carry-forwards per issue. When an issue is moved from an overdue milestone to the next:

1. Increment the issue's carry-forward count (track in issue description or comment)
2. Add a comment: `Carried forward from [Old Milestone] to [New Milestone] (carry-forward #N)`

### Loop Prevention

**Maximum 2 carry-forwards per issue.** After 2 carry-forwards:

- **DO NOT** propose another move
- **Flag for human review** with a staleness warning:

```
Issue [CIA-XXX] "[title]" has been carried forward twice -- consider re-scoping or canceling.
Previously: [Milestone A] -> [Milestone B] -> [Milestone C]
```

This prevents issues from silently bouncing between milestones indefinitely. The human must actively decide to carry forward a third time, re-scope the issue, or cancel it.

### No Next Milestone

If no next milestone exists in the project:

```
Milestone [name] is overdue with [N] open issues, but no next milestone exists.
Consider creating a new milestone or re-scoping the remaining issues.
```

## Error Handling

### Orphaned Issue Detection

If `get_milestone` returns null for a previously-assigned milestone (the milestone was deleted), the issue is orphaned:

1. **Detect:** During health reporting or assignment checks, if an issue references a milestone that no longer exists
2. **Report:** Flag in hygiene output as `Orphaned: milestone deleted`
3. **Do not silently leave issues unassigned.** Every orphaned issue must be surfaced

**Orphan report format (in hygiene output):**

```
Orphaned Issues (milestone deleted):
- [CIA-XXX] "[title]" — previously assigned to [deleted milestone name]
- [CIA-YYY] "[title]" — previously assigned to [deleted milestone name]

Action: Reassign these issues to an active milestone or remove milestone assignment.
```

### API Errors

| Error | Response |
|-------|----------|
| `list_milestones` returns empty | Report "No milestones found in [project]". Do not fail silently. |
| `get_milestone` returns null | Check if the milestone was deleted (orphan detection). |
| `update_issue` fails on milestone assignment | Report the error. Do not retry automatically. Suggest manual assignment. |
| Rate limit / timeout | Log the failure, proceed with cached data if available, note degraded accuracy in output. |

## DO NOT Patterns

- **DO NOT auto-close milestones.** Always propose closure and wait for human confirmation.
- **DO NOT carry forward an issue more than twice** without human review. After 2 carry-forwards, flag with staleness warning.
- **DO NOT auto-assign when multiple active milestones exist.** Prompt the user to choose.
- **DO NOT use `get_milestone(id)` without `project`.** Always use `get_milestone(project, query)`.
- **DO NOT use `update_issue(milestoneId: ...)`.** Always use `update_issue(milestone: "name-or-id")`.
- **DO NOT modify issue status, labels, or closure.** Those operations belong to `issue-lifecycle`.

## Cross-Skill References

- **issue-lifecycle** -- Delegates milestone assignment here during issue creation. This skill never calls back into issue-lifecycle.
- **session-exit** -- May include milestone health table in session summary when milestones were affected.
- **planning-preflight** -- Step 3b (Zoom Out) reads milestone context. This skill provides the data; preflight consumes it.
- **go command** -- Auto-assignment triggers during issue creation via `/ccc:go` intake flow.
- **issue-lifecycle** (Maintenance section) -- May surface orphaned issues during structural normalization. This skill handles ongoing orphan detection.
