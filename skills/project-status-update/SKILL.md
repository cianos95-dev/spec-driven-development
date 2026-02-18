---
name: project-status-update
description: |
  Post automated status updates at two levels: initiative-level via save_status_update MCP tool,
  and project-level via create_document with naming convention. Handles health signal calculation,
  initiative roll-ups, sensitivity filtering, deduplication, and error recovery.
  Use when posting project or initiative status updates, during session exit, during hygiene checks,
  or when the user requests a status update on demand.
  Trigger with phrases like "post status update", "project health", "initiative update",
  "status report", "weekly roll-up", "project progress".
---

# Project Status Update

Post automated status updates for projects and initiatives in Linear. Uses a two-tier architecture based on MCP tool constraints discovered in CIA-549.

## Two-Tier Architecture

**Key constraint:** `save_status_update` only supports `type: "initiative"`. Project-level status updates are NOT available via this MCP tool. The `project` parameter provides filtering context only, not a posting target.

### Tier 1: Initiative Status Updates (MCP native)

Posts to Linear's native Updates tab on initiatives.

**Tool:** `save_status_update(type: "initiative", initiative: "...", health: "...", body: "...")`

**When:**
- Monday initiative roll-ups (default cadence)
- On-demand via `/ccc:status-update --initiative "..."`

**Health values:** `onTrack` | `atRisk` | `offTrack`

### Tier 2: Project Status Updates (document-based)

Posts to the project's Documents tab using the naming convention from CIA-538's document type taxonomy.

**Tool:** `create_document(project: "...", title: "Project Update — YYYY-MM-DD", content: "...")`

**When:**
- Session exit (if issue statuses changed) — best-effort only
- During `/ccc:hygiene`
- On-demand via `/ccc:status-update` or `/ccc:status-update --project "..."`

## When to Post

| Trigger | Tier | Behavior |
|---------|------|----------|
| Session exit (issue statuses changed) | Tier 2 (project) | Best-effort. Failures MUST NOT block session-exit. Log warning and continue. |
| `/ccc:hygiene` | Tier 2 (project) | Part of project health assessment |
| `/ccc:status-update` (no flags) | Tier 2 (project) | Auto-detect all projects with recent changes |
| `/ccc:status-update --project "X"` | Tier 2 (project) | Specific project update |
| `/ccc:status-update --initiative "X"` | Tier 1 (initiative) | Specific initiative update |
| Monday (end of session with changes) | Tier 1 + Tier 2 | Project updates first, then initiative roll-up |

## Status Generation Algorithm

### Step 1: Gather Affected Issues

Consume the affected-issues inventory from session-exit Step 1 (or build it on-demand for `/ccc:status-update`). This includes every issue whose status, labels, description, or linked artifacts changed during the session.

### Step 2: Group by Project

Partition affected issues by their `project` field. Skip issues with no project assignment.

### Step 3: Calculate Health Signal

For each project, determine the health signal:

| Signal | Condition |
|--------|-----------|
| **On Track** | No overdue milestones AND no blocking relationships on active (In Progress) issues |
| **At Risk** | Any blocker on an active issue OR any milestone within 3 days of its target date |
| **Off Track** | Any milestone past its target date |

Evaluate conditions in order: Off Track > At Risk > On Track (worst signal wins).

**v1 simplicity note:** Health signals are advisory, not contractual. This calculation may be refined in future versions. When milestone data is unavailable, default to On Track.

**MCP tools for health calculation:**
- `list_milestones` — check for overdue or near-due milestones
- Issue relations from `get_issue(includeRelations: true)` — check for blockers

### Step 4: Compose Update Content

For each project, compose a markdown update:

```markdown
# Project Update — YYYY-MM-DD

**Health:** On Track | At Risk | Off Track

## Progress
- [CIA-XXX]: Status change — 1-line summary
- [CIA-YYY]: Status change — 1-line summary

## Blocked
- [CIA-ZZZ]: Blocker description

## Created
- [CIA-AAA]: New issue title — why created

## Next
- Planned next steps for the project
```

**Content rules:**
- Group progress items by theme when there are more than 5
- Reference issue IDs for traceability
- Keep each section to 3-5 bullets maximum
- Truncate issue descriptions to first 100 characters in the update body

### Step 5: Post Project Update (Tier 2)

1. **Dedup check:** Call `list_documents(project: "...")` and search for a document titled `"Project Update — YYYY-MM-DD"` with today's date.
2. **If existing update found:** Call `update_document(id: "...", content: "...")` with freshly composed markdown. NEVER read the existing document and modify it — always compose from scratch.
3. **If no existing update:** Call `create_document(project: "...", title: "Project Update — YYYY-MM-DD", content: "...")`.

### Step 6: Initiative Roll-Up (Tier 1, Mondays only)

Only execute this step if today is Monday (or if explicitly requested via `--initiative`).

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

**Cadence configuration:** Check initiative description for annotation `<!-- status-update: daily|weekly|biweekly -->`. Default: weekly (Monday). If cadence annotation says `biweekly`, only post on the 1st and 3rd Monday of the month.

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

### Tier 2 (Project Documents)

Before creating a project update document:

1. Call `list_documents(project: "...")`.
2. Search results for a title matching `"Project Update — YYYY-MM-DD"` (today's date).
3. If found: use `update_document(id: "...", content: "...")` with freshly composed content.
4. If not found: use `create_document(...)`.

**Safety:** All `update_document` calls must compose fresh markdown. NEVER call `get_document` → modify → `update_document` (this causes double-escape corruption per CIA-538 C1 rule).

### Tier 1 (Initiative Updates)

Before creating an initiative update:

1. Call `get_status_updates(type: "initiative", initiative: "...", createdAt: "-P1D")`.
2. If results contain an update from today: use `save_status_update(id: "...", ...)` to update it.
3. If no results: use `save_status_update(initiative: "...", ...)` to create a new one.

## Error Handling

Status updates are a reporting mechanism, not a critical path operation. Failures are logged and skipped — they never block the calling workflow.

| Failure | Action |
|---------|--------|
| `save_status_update` fails (initiative) | Log warning with error details. Do NOT fall back to `create_document` — initiative updates belong in the Updates tab, not Documents. |
| `create_document` fails (project update) | Log warning. Skip this project's update. Other projects still proceed. |
| `update_document` fails (same-day update) | Log warning. Attempt `create_document` as fallback (risk of duplicate is acceptable). |
| `list_documents` fails (dedup check) | Proceed with `create_document` (risk of duplicate is acceptable vs. blocking the update entirely). |
| `get_status_updates` fails (dedup check) | Proceed with `save_status_update` without `id` (risk of duplicate is acceptable). |
| `list_milestones` fails (health calc) | Default to `onTrack` health signal. Note in update body: "Health signal defaulted — milestone data unavailable." |
| Any failure during session-exit | Log warning and continue to next session-exit step. NEVER block exit. |

## Integration with Other Skills

| Skill | This Skill's Role | Other Skill's Role |
|-------|-------------------|-------------------|
| **session-exit** | Called at Step 4 (best-effort, after status normalization) | Provides affected-issues inventory (Step 1) and triggers the update |
| **hygiene** | Called during project health assessment | Triggers the update and reports health scores |
| **document-lifecycle** (CIA-538) | Project updates follow document type taxonomy; uses same `update_document` safety rules | Defines naming conventions and validation functions |
| **issue-lifecycle** | Consumes affected-issues inventory | Defines the inventory format and closure rules |
| **context-management** | Delegates bulk operations to subagents when >3 projects touched | Defines delegation tiers |

## Anti-Patterns

**Blocking session-exit.** Status updates are informational. If the MCP call fails, the session must still end cleanly. Never retry status update calls during session-exit.

**Using `save_status_update` for projects.** The MCP tool only supports `type: "initiative"`. Attempting to post project-level updates via this tool will fail silently or produce unexpected results. Always use `create_document` for project updates.

**Round-tripping documents.** Never read an existing project update document and modify it for re-posting. Always compose fresh markdown from the current session's data.

**Posting empty updates.** If no issue statuses changed during the session, do not post an update. Empty updates add noise without signal.

**Over-detailed updates.** Status updates should be scannable in 30 seconds. If an update exceeds 500 words, it's too detailed — summarize more aggressively.
