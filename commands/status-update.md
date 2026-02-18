---
description: |
  Post project or initiative status updates to Linear using the two-tier architecture.
  Use when you want to post a status update, check project health, generate an initiative roll-up,
  or preview what an update would contain before posting.
  Trigger with phrases like "post status update", "project status", "initiative roll-up",
  "status report", "what changed today".
argument-hint: "[--project <name> | --initiative <name>] [--dry-run]"
allowed-tools: Read, Grep, Glob
platforms: [cli, cowork]
---

# Status Update

Post project or initiative status updates to Linear. Uses a two-tier architecture: initiative updates go to Linear's native Updates tab via `save_status_update`, project updates go to the Documents tab via `create_document`.

## Modes

### Auto-detect (default)

```
/ccc:status-update
```

Detect all projects with issue status changes in the current session. Post a Tier 2 (document-based) project update for each.

**Steps:**
1. Gather all issues touched during the current session
2. Group by project, skip issues with no project assignment
3. For each project with changes, run the project-status-update skill (Tier 2)
4. If today is Monday, also run initiative roll-ups (Tier 1) for affected initiatives

### Specific Project

```
/ccc:status-update --project "CCC"
```

Post a Tier 2 project update for the named project only. Gathers all recent issue changes for that project regardless of session scope.

**Steps:**
1. Query recent issues for the specified project (last 24 hours of activity)
2. Calculate health signal from milestone and blocker data
3. Compose and post the project update document

### Specific Initiative

```
/ccc:status-update --initiative "Workspace Maturity"
```

Post a Tier 1 initiative update. Aggregates health signals from all projects under the initiative.

**Steps:**
1. Identify all projects belonging to the named initiative
2. For each project, calculate health signal
3. Aggregate using worst-signal-wins
4. Compose and post via `save_status_update(type: "initiative", initiative: "...", health: "...", body: "...")`

### Dry Run

```
/ccc:status-update --dry-run
/ccc:status-update --project "CCC" --dry-run
/ccc:status-update --initiative "Workspace Maturity" --dry-run
```

Preview the update content without posting. Outputs:
- The target (document title or initiative name)
- The health signal that would be set
- The full markdown body that would be posted
- Whether this would create a new update or update an existing one (dedup result)

`--dry-run` is combinable with any other flag.

## Step 1: Determine Scope

Based on the mode:

| Mode | Scope |
|------|-------|
| Auto-detect | All projects with session changes |
| `--project` | Single named project |
| `--initiative` | All projects under named initiative |

If auto-detect finds no projects with changes, report: "No issue status changes detected in this session. Nothing to update."

## Step 2: Gather Data

For each project in scope:

1. **Issues:** Query recent issue activity (status changes, label changes, new issues, completions)
2. **Milestones:** Call `list_milestones` to check for overdue or near-due milestones
3. **Blockers:** From issue relations, identify any active blocking relationships
4. **Project context:** Call `get_project` for project metadata

## Step 3: Calculate Health

Apply the health signal logic:

| Signal | Condition |
|--------|-----------|
| **On Track** | No overdue milestones AND no blockers on active issues |
| **At Risk** | Any blocker on active issue OR milestone within 3 days of target |
| **Off Track** | Any milestone past its target date |

If milestone data is unavailable, default to On Track with a note.

## Step 4: Compose Update

Build the update markdown following the template in the project-status-update skill.

**Before composing, apply sensitivity filtering:**
- Remove absolute file paths, credentials, stack traces
- Truncate issue descriptions to 100 characters
- Scan for API key patterns and redact

## Step 5: Dedup Check

**For project updates (Tier 2):**
- Call `list_documents(project: "...")` and check for `"Project Update — YYYY-MM-DD"` with today's date
- If found: will update existing document
- If not found: will create new document

**For initiative updates (Tier 1):**
- Call `get_status_updates(type: "initiative", initiative: "...", createdAt: "-P1D")`
- If found: will update existing status update
- If not found: will create new status update

## Step 6: Post (or Preview)

**If `--dry-run`:** Output the composed content, target, and dedup result. Stop here.

**If not dry-run:** Post the update using the appropriate tool:
- Tier 2: `create_document` or `update_document` (fresh markdown only, never round-trip)
- Tier 1: `save_status_update` (with or without `id` depending on dedup)

Report what was posted:
```
Posted project update for "CCC" — Health: On Track
  Document: "Project Update — 2026-02-18"
  Issues covered: 5 (3 completed, 1 in progress, 1 created)
```

## Error Handling

| Situation | Response |
|-----------|----------|
| **MCP tool call fails** | Log warning with error details. Skip this update. Continue with remaining projects/initiatives. |
| **No issues changed** | Report "nothing to update" and exit cleanly. Do not post empty updates. |
| **Dedup check fails** | Proceed with create (acceptable duplicate risk). |
| **Called during session-exit** | Best-effort only. Any failure logged and skipped — session-exit continues. |
| **Health calculation incomplete** | Default to On Track. Note in update body that milestone data was unavailable. |

## Next Step

After posting:

```
Status update(s) posted.
  Next: Run `/ccc:go` to continue with remaining work
  Or: End the session — status updates are complete
```

## What If

| Situation | Response |
|-----------|----------|
| **User asks for status update mid-session** | Run on-demand. Gather changes so far (not just completed items). Note in update that session is still in progress. |
| **Multiple sessions on same day** | Dedup check finds the earlier update. Newer data replaces it via `update_document` (fresh compose, not round-trip). |
| **Initiative has no projects with changes** | Skip the initiative. Do not post an empty initiative update. |
| **Project has no milestones** | Health defaults to On Track. Note in update that no milestones are configured. |
