---
name: project-status-update
description: |
  Post automated status updates at two levels: project-level via GraphQL projectUpdateCreate
  (native Updates tab), and initiative-level via save_status_update MCP tool. Handles health
  signal calculation, initiative roll-ups, sensitivity filtering, deduplication, and error recovery.
  Use when posting project or initiative status updates, during session exit, or when the user
  requests a status update on demand.
  Trigger with phrases like "post status update", "project health", "initiative update",
  "status report", "weekly roll-up", "project progress".
---

# Project Status Update

Post automated status updates for projects and initiatives in Linear. Uses a two-tier architecture based on MCP tool constraints discovered in CIA-549 and spike-tested in CIA-537.

## Two-Tier Architecture

**Key constraint:** `save_status_update` only supports `type: "initiative"`. Project-level status updates are NOT available via this MCP tool. The `project` parameter provides filtering context only, not a posting target.

**Solution:** GraphQL `projectUpdateCreate` for project-level updates (native Updates tab). MCP `save_status_update` for initiative-level updates.

### Tier 1: Initiative Status Updates (MCP native)

Posts to Linear's native Updates tab on initiatives.

**Tool:** `save_status_update(type: "initiative", initiative: "...", health: "...", body: "...")`

**When:**
- Monday initiative roll-ups (default cadence)
- On-demand via `/ccc:status-update --initiative "..."`

**Health values:** `onTrack` | `atRisk` | `offTrack`

### Tier 2: Project Status Updates (GraphQL native)

Posts to the project's native Updates tab, populating Linear's Pulse/Reviews view.

**Tool:** GraphQL `projectUpdateCreate` mutation via `$LINEAR_API_KEY`

**When:**
- Session exit (if issue statuses changed) — best-effort, with user confirmation
- On-demand via `/ccc:status-update` or `/ccc:status-update --project "..."`
- NOT during `/ccc:hygiene` — hygiene remains a read-only audit tool

**Auth:** `$LINEAR_API_KEY` (personal `lin_api_*` token). The OAuth agent token (`$LINEAR_AGENT_TOKEN` / `lin_oauth_*`) returns 401 for GraphQL project updates.

See `references/graphql-project-updates.md` for mutation signatures and curl examples.

## When to Post

| Trigger | Tier | Behavior |
|---------|------|----------|
| Session exit (issue statuses changed) | Tier 2 (project) | Show preview, ask confirmation. Failures MUST NOT block session-exit. |
| `/ccc:status-update` (no flags) | Tier 2 (project) | Dry-run preview by default. `--post` required to write. |
| `/ccc:status-update --project "X"` | Tier 2 (project) | Specific project. Dry-run default. |
| `/ccc:status-update --project "X" --post` | Tier 2 (project) | Post for specific project. |
| `/ccc:status-update --initiative "X"` | Tier 1 (initiative) | Specific initiative update (works any day). |
| Monday (end of session with changes) | Tier 1 + Tier 2 | Project updates first, then initiative roll-up. |

### User Confirmation

| Trigger | Default behavior | Override |
|---------|-----------------|----------|
| Session-exit (automatic) | Show preview, ask confirmation before posting | `--force` skips confirmation |
| Command (manual) | `--dry-run` preview (default) | `--post` flag required to write |

Follows the `/ccc:close` propose-close pattern — never writes to a team-visible surface without user consent.

## Status Generation Algorithm

### Step 1: Gather Affected Issues

Consume the affected-issues inventory from session-exit Step 1 (or build it on-demand for `/ccc:status-update`). This includes every issue whose status, labels, description, or linked artifacts changed during the session.

### Step 2: Group by Project

Partition affected issues by their `project` field. Skip issues with no project assignment.

### Step 3: Calculate Health Signal

For each project, determine the health signal. **Canonical definition** lives in `skills/issue-lifecycle/references/project-hygiene.md` — this skill references it, not duplicates it.

| Signal | Condition |
|--------|-----------|
| **On Track** | No overdue milestones AND no unresolved blockers |
| **At Risk** | Any blocker exists OR any milestone target date within 3 days |
| **Off Track** | Any milestone target date has passed with open issues |

Evaluate conditions in order: Off Track > At Risk > On Track (worst signal wins).

**User override:** `--health <signal>` flag allows manual correction when computed signal is wrong (e.g., stale milestone date).

**When milestone data is unavailable:** Default to On Track with a note in the update body.

**MCP tools for health calculation:**
- `list_milestones(project, limit: 10)` — check for overdue or near-due milestones
- Issue relations from `get_issue(includeRelations: true)` — check for blockers

### Step 4: Compose Update Content

For each project, compose a markdown update:

```markdown
**Health:** On Track | At Risk | Off Track

## Progress
- CIA-XXX: Status change — 1-line summary
- CIA-YYY: Status change — 1-line summary

## Blocked
- CIA-ZZZ: Blocker description

## Created
- CIA-AAA: New issue title — why created

## Next
- Planned next steps for the project
```

**Content rules:**
- Group progress items by theme when there are more than 5
- Reference issue IDs for traceability
- Keep each section to 3-5 bullets maximum
- Truncate issue descriptions to first 100 characters in the update body
- Add provenance footer: `Posted by Claude agent | Session: YYYY-MM-DD`

### Step 5: Post Project Update (Tier 2)

1. **Resolve project UUID:** Call `get_project` via MCP (cache from session-exit if available).
2. **Dedup check:** Query existing same-day project updates via GraphQL (`projectUpdates(filter: { project: { id: { eq: "UUID" } }, createdAt: { gte: "YYYY-MM-DDT00:00:00Z" } }, first: 1)`).
3. **If existing update found:** Amend via `projectUpdateUpdate(id: "...", body: "...", health: "...")` GraphQL mutation.
4. **If no existing update:** Create via `projectUpdateCreate(projectId: "...", body: "...", health: "...")` GraphQL mutation.

See `references/graphql-project-updates.md` for mutation details and auth.

### Step 6: Initiative Roll-Up (Tier 1)

Only execute if today is Monday OR if explicitly requested via `--initiative`.

1. Identify all initiatives that contain projects with changes from this session.
2. For each initiative, aggregate project health signals using **worst-signal-wins**:
   - Any project `offTrack` → initiative `offTrack`
   - Any project `atRisk` (and none `offTrack`) → initiative `atRisk`
   - All projects `onTrack` → initiative `onTrack`
3. Compose initiative update body:

```markdown
## Initiative Status — YYYY-MM-DD

### Per-Project Health
| Project | Health | Key Highlights |
|---------|--------|----------------|
| CCC | On Track | Shipped 3 skills, 2 commands |
| Alteri | At Risk | Blocked on external API |

### Summary
- [2-3 bullets summarizing initiative-wide progress]

### Decisions Needed
- [Any cross-project decisions or escalations]
```

4. **Dedup check:** Call `get_status_updates(type: "initiative", initiative: "...", createdAt: "-P1D")` to check for an existing update from today.
5. **If existing update found:** Call `save_status_update(type: "initiative", id: "...", health: "...", body: "...")` to update it.
6. **If no existing update:** Call `save_status_update(type: "initiative", initiative: "...", health: "...", body: "...")` to create it.

**Monday check location:** The Monday scheduling concern lives in session-exit Step 4 (scheduling), not in this skill (capability). This skill always posts when called — the caller decides when to call.

**Cadence configuration:** Check initiative description for annotation `<!-- status-update: daily|weekly|biweekly -->`. Default: weekly (Monday). If cadence annotation says `biweekly`, only post on the 1st and 3rd Monday of the month.

## Output to User

**After posting (automatic or manual):**

```
Status update posted to [Project Name]
  Health: On Track | At Risk | Off Track
  URL: https://linear.app/claudian/project/.../updates#...
  Next: Run `/ccc:status-update --edit` to amend
```

**On failure:** Show error message, log warning, continue session exit. **Never block session exit on a status update failure.**

## Sensitivity Filtering

Status updates are visible to all workspace members. Before posting any update (Tier 1 or Tier 2), apply these content filters:

### NEVER include

- API keys, tokens, credentials, or secrets of any kind
- File paths containing usernames (e.g., `/Users/cianosullivan/...`)
- Raw error messages with stack traces — summarize as "build error in module X"
- Personal task assignments beyond what's already visible in Linear issue assignees
- Internal discussion or decision rationale that hasn't been formalized

### ALWAYS sanitize

- Replace absolute local paths with relative repo paths (e.g., `~/Repositories/ccc/...` → `skills/...`)
- Truncate issue descriptions to first 100 characters in update body
- Remove any inline code blocks containing credentials patterns (`key=`, `token=`, `password=`)

### Validation

Before posting, scan the composed markdown for:
- Patterns matching API keys: strings starting with `sk-`, `lin_`, `ghp_`, `Bearer `
- Absolute paths containing `/Users/` or `/home/`
- Stack trace signatures: lines starting with `at `, `File "`, `Traceback`

If any match is found, redact the offending content and add a note: `[Redacted: sensitive content removed]`.

## Deduplication

### Tier 2 (Project Updates via GraphQL)

Before creating a project update:

1. Query existing same-day updates via GraphQL (see `references/graphql-project-updates.md`).
2. If found: amend via `projectUpdateUpdate(id, body, health)`.
3. If not found: create via `projectUpdateCreate(projectId, body, health)`.

### Tier 1 (Initiative Updates via MCP)

Before creating an initiative update:

1. Call `get_status_updates(type: "initiative", initiative: "...", createdAt: "-P1D")`.
2. If results contain an update from today: use `save_status_update(id: "...", ...)` to update it.
3. If no results: use `save_status_update(initiative: "...", ...)` to create a new one.

## Error Handling

Status updates are a reporting mechanism, not a critical path operation. Failures are logged and skipped — they never block the calling workflow.

| Failure | Action |
|---------|--------|
| `projectUpdateCreate` GraphQL fails | Log warning. Skip this project's update. Other projects still proceed. |
| `projectUpdateUpdate` GraphQL fails | Log warning. Attempt `projectUpdateCreate` as fallback (acceptable duplicate risk). |
| `save_status_update` fails (initiative) | Log warning with error details. Do NOT fall back to `create_document` — initiative updates belong in the Updates tab, not Documents. |
| GraphQL auth error (401) | Check `$LINEAR_API_KEY` is set. The OAuth token (`$LINEAR_AGENT_TOKEN`) does not work for GraphQL project updates. |
| `get_status_updates` fails (dedup check) | Proceed with `save_status_update` without `id` (acceptable duplicate risk). |
| `list_milestones` fails (health calc) | Default to `onTrack` health signal. Note in update body: "Health signal defaulted — milestone data unavailable." |
| Any failure during session-exit | Log warning and continue to next session-exit step. NEVER block exit. |

## Edit and Delete

Users can amend or remove posted updates:

- **`--edit`:** Fetch latest update via GraphQL query, present for editing, amend via `projectUpdateUpdate`.
- **`--delete`:** Fetch latest update, confirm with user, delete via `projectUpdateDelete` (GraphQL) or `delete_status_update` (MCP for initiatives).

## Tools Used

**MCP:**
- `get_project` — project context and UUID resolution
- `list_milestones(project, limit: 10)` — health signal calculation
- `get_status_updates(type: "initiative", initiative: "...", limit: 1, createdAt: "-P1D")` — dedup check for initiative updates
- `save_status_update(type: "initiative", ...)` — post initiative roll-ups
- `delete_status_update` — delete initiative updates

**GraphQL** (via `$LINEAR_API_KEY`):
- `projectUpdateCreate` — create project-level status update (native Updates tab)
- `projectUpdateUpdate` — amend existing update (same-day dedup)
- `projectUpdateDelete` — delete a bad update
- Query: fetch existing same-day project updates by `projectId` + `createdAt` filter

## Integration with Other Skills

| Skill | This Skill's Role | Other Skill's Role |
|-------|-------------------|-------------------|
| **session-exit** | Called at Step 4 (best-effort, after status normalization) | Provides affected-issues inventory (Step 1) and triggers the update |
| **document-lifecycle** (CIA-538) | Follows safety rules (no round-tripping) | Defines naming conventions. Note: project updates now use GraphQL, NOT `create_document`. |
| **issue-lifecycle** | Consumes affected-issues inventory | Defines the inventory format and closure rules |
| **project-hygiene** | References health signal definition | Canonical source of health signal conditions |
| **context-management** | Delegates bulk operations to subagents when >3 projects touched | Defines delegation tiers |

## Anti-Patterns

**Blocking session-exit.** Status updates are informational. If the GraphQL call or MCP call fails, the session must still end cleanly. Never retry status update calls during session-exit.

**Using `save_status_update` for projects.** The MCP tool only supports `type: "initiative"`. Attempting to post project-level updates via this tool will fail silently or produce unexpected results. Always use GraphQL `projectUpdateCreate` for project updates.

**Using `create_document` for project updates.** Documents are for structured content (specs, decision logs, resources). Status updates belong in the native Updates tab via GraphQL. This was the pre-spike design — do not regress.

**Using `$LINEAR_AGENT_TOKEN` for GraphQL.** The OAuth agent token returns 401 for GraphQL project update mutations. Always use `$LINEAR_API_KEY` (`lin_api_*`).

**Round-tripping content.** Never read an existing update and modify it for re-posting. Always compose fresh markdown from the current session's data.

**Posting empty updates.** If no issue statuses changed during the session, do not post an update. Empty updates add noise without signal.

**Over-detailed updates.** Status updates should be scannable in 30 seconds. If an update exceeds 500 words, it's too detailed — summarize more aggressively.
