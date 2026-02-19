---
description: |
  Post project or initiative status updates to Linear using the two-tier architecture.
  Project updates go to the native Updates tab via GraphQL projectUpdateCreate.
  Initiative updates go to the native Updates tab via save_status_update MCP tool.
  Use when you want to post a status update, check project health, generate an initiative roll-up,
  or preview what an update would contain before posting.
  Trigger with phrases like "post status update", "project status", "initiative roll-up",
  "status report", "what changed today".
argument-hint: "[--project <name> | --initiative <name>] [--dry-run | --post] [--edit | --delete] [--health <signal>]"
allowed-tools: Read, Grep, Glob
platforms: [cli, cowork]
---

# Status Update

Post project or initiative status updates to Linear. Uses a two-tier architecture: project updates go to the native Updates tab via GraphQL `projectUpdateCreate`, initiative updates go via `save_status_update` MCP tool.

## Modes

| Invocation | Behavior |
|------------|----------|
| `/ccc:status-update` | Dry-run preview of auto-detected projects (default) |
| `/ccc:status-update --post` | Post updates for auto-detected projects |
| `/ccc:status-update --project "CCC"` | Specific project (dry-run default) |
| `/ccc:status-update --project "CCC" --post` | Post for specific project |
| `/ccc:status-update --initiative "Workspace Maturity"` | Initiative level (works any day) |
| `/ccc:status-update --dry-run` | Explicit preview mode |
| `/ccc:status-update --edit` | Amend latest update |
| `/ccc:status-update --delete` | Delete latest update (with confirmation) |
| `/ccc:status-update --health onTrack` | Override computed health signal |

Flags are combinable: `--project "CCC" --post --health atRisk` posts a project update with a manually set health signal.

### Auto-detect (default)

```
/ccc:status-update
```

Detect all projects with issue status changes in the current session. Preview a Tier 2 (GraphQL) project update for each.

**Steps:**
1. Gather all issues touched during the current session
2. Group by project, skip issues with no project assignment
3. For each project with changes, compose a preview using the project-status-update skill
4. If today is Monday, also preview initiative roll-ups (Tier 1) for affected initiatives
5. Display preview. User must run `--post` to publish.

### Specific Project

```
/ccc:status-update --project "CCC" --post
```

Post a Tier 2 project update for the named project. Gathers all recent issue changes for that project regardless of session scope.

**Steps:**
1. Query recent issues for the specified project (last 24 hours of activity)
2. Calculate health signal from milestone and blocker data
3. Compose and post the project update via GraphQL

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

### Edit

```
/ccc:status-update --edit
/ccc:status-update --edit --project "CCC"
```

Amend the most recent update for the auto-detected or specified project/initiative.

**Steps:**
1. Fetch the latest update via GraphQL query (project) or `get_status_updates` (initiative)
2. Present current content for editing
3. Compose fresh replacement from user guidance (never round-trip the content)
4. Post via `projectUpdateUpdate` (project) or `save_status_update(id: "...")` (initiative)

### Delete

```
/ccc:status-update --delete
/ccc:status-update --delete --project "CCC"
```

Delete the most recent update. Always confirms with the user before deletion.

**Steps:**
1. Fetch the latest update
2. Display it with a confirmation prompt: "Delete this update? (y/n)"
3. On confirmation: `projectUpdateDelete` (project) or `delete_status_update` (initiative)

## Step 1: Determine Scope

Based on the mode:

| Mode | Scope |
|------|-------|
| Auto-detect | All projects with session changes |
| `--project` | Single named project |
| `--initiative` | All projects under named initiative |

If auto-detect finds no projects with changes, report: "No issue status changes detected in this session. Nothing to update."

### Auto-Detect Scope

"Recent changes" = issues changed in the current session (same scope as session-exit inventory). If invoked outside session-exit context, scope = issues updated today.

## Step 2: Gather Data

For each project in scope:

1. **Issues:** Query recent issue activity (status changes, label changes, new issues, completions)
2. **Milestones:** Call `list_milestones(project, limit: 10)` to check for overdue or near-due milestones
3. **Blockers:** From issue relations, identify any active blocking relationships
4. **Project context:** Call `get_project` for project metadata and UUID

## Step 3: Calculate Health

Apply the health signal logic from `project-hygiene.md` (canonical source):

| Signal | Condition |
|--------|-----------|
| **On Track** | No overdue milestones AND no blockers on active issues |
| **At Risk** | Any blocker on active issue OR milestone within 3 days of target |
| **Off Track** | Any milestone past its target date |

If milestone data is unavailable, default to On Track with a note.

Override with `--health <signal>` when the computed signal is incorrect.

## Step 4: Compose Update

Build the update markdown following the template in the project-status-update skill.

**Before composing, apply sensitivity filtering:**
- Remove absolute file paths, credentials, stack traces
- Truncate issue descriptions to 100 characters
- Scan for API key patterns and redact
- Add provenance footer: `Posted by Claude agent | Session: YYYY-MM-DD`

## Step 5: Dedup Check

**For project updates (Tier 2):**
- Query existing same-day updates via GraphQL (see `references/graphql-project-updates.md`)
- If found: will amend existing update via `projectUpdateUpdate`
- If not found: will create new update via `projectUpdateCreate`

**For initiative updates (Tier 1):**
- Call `get_status_updates(type: "initiative", initiative: "...", createdAt: "-P1D")`
- If found: will update existing status update
- If not found: will create new status update

## Step 6: Post (or Preview)

**If `--dry-run` or no `--post` flag:** Output the composed content, target, and dedup result. Stop here.

```markdown
## Status Update Preview — [Project Name]

**Health:** On Track (computed) | Override: --health <signal>
**Target:** Project Updates tab (GraphQL)
**Dedup:** Would create new update | Would amend existing

### Would post:

[Markdown body preview]

---
Run with `--post` to publish.
```

**If `--post` (or session-exit with confirmation):** Post the update:
- Tier 2: GraphQL `projectUpdateCreate` or `projectUpdateUpdate`
- Tier 1: `save_status_update` (with or without `id` depending on dedup)

Report what was posted:
```
Status update posted to [Project Name]
  Health: On Track
  Target: Updates tab
  Issues covered: 5 (3 completed, 1 in progress, 1 created)
  Next: Run `/ccc:status-update --edit` to amend
```

## Error Handling

| Situation | Response |
|-----------|----------|
| **GraphQL call fails** | Log warning with error details. Skip this update. Continue with remaining projects/initiatives. |
| **MCP tool call fails** | Log warning. Skip this initiative update. Continue. |
| **No issues changed** | Report "nothing to update" and exit cleanly. Do not post empty updates. |
| **Dedup check fails** | Proceed with create (acceptable duplicate risk). |
| **Called during session-exit** | Best-effort only. Any failure logged and skipped — session-exit continues. |
| **Health calculation incomplete** | Default to On Track. Note in update body that milestone data was unavailable. |
| **Auth error (401)** | Check `$LINEAR_API_KEY` is set. OAuth token does not work for GraphQL project updates. |

## What If

| Situation | Response |
|-----------|----------|
| **User asks for status update mid-session** | Run on-demand. Gather changes so far (not just completed items). Note in update that session is still in progress. |
| **Multiple sessions on same day** | Dedup check finds the earlier update. Newer data replaces it via `projectUpdateUpdate` (fresh compose, not round-trip). |
| **Initiative has no projects with changes** | Skip the initiative. Do not post an empty initiative update. |
| **Project has no milestones** | Health defaults to On Track. Note in update that no milestones are configured. |
| **`$LINEAR_API_KEY` not set** | Report error with setup instructions. Do not fall back to `create_document`. |
