# Status Update Protocol (absorbed from project-status-update)

Post automated status updates for projects and initiatives in Linear. Uses a two-tier architecture based on MCP tool constraints.

## Two-Tier Architecture

**Key constraint:** `save_status_update` only supports `type: "initiative"`. Project-level status updates are NOT available via this MCP tool.

### Tier 1: Initiative Status Updates (MCP native)

**Tool:** `save_status_update(type: "initiative", initiative: "...", health: "...", body: "...")`

**When:** Monday initiative roll-ups (default cadence), or on-demand via `/ccc:status-update --initiative "..."`

### Tier 2: Project Status Updates (GraphQL native)

**Tool:** GraphQL `projectUpdateCreate` mutation via `$LINEAR_API_KEY`

**When:** Session exit (if issue statuses changed), on-demand via `/ccc:status-update`

**Auth:** `$LINEAR_API_KEY` (personal `lin_api_*` token). The OAuth agent token returns 401 for GraphQL project updates.

See `graphql-project-updates.md` for mutation signatures and curl examples.

## When to Post

| Trigger | Tier | Behavior |
|---------|------|----------|
| Session exit (issue statuses changed) | Tier 2 (project) | Show preview, ask confirmation. Failures MUST NOT block session-exit. |
| `/ccc:status-update` (no flags) | Tier 2 (project) | Dry-run preview by default. `--post` required to write. |
| `/ccc:status-update --initiative "X"` | Tier 1 (initiative) | Specific initiative update. |
| Monday (end of session with changes) | Tier 1 + Tier 2 | Project updates first, then initiative roll-up. |

## Status Generation Algorithm

1. **Gather** affected issues from session-exit inventory
2. **Group** by project (skip unassigned issues)
3. **Calculate health** signal per `project-hygiene.md` canonical definition
4. **Compose** markdown update (Progress, Blocked, Created, Next sections)
5. **Post** with dedup check (amend same-day updates, don't duplicate)
6. **Initiative roll-up** (Mondays only): aggregate project health using worst-signal-wins

## Sensitivity Filtering

Before posting any update, apply these content filters:

**NEVER include:** API keys, tokens, credentials, file paths with usernames, raw stack traces, internal discussion

**ALWAYS sanitize:** Replace absolute paths with relative, truncate descriptions to 100 chars, remove credential patterns

**Validation scan before posting:** Check for `sk-`, `lin_`, `ghp_`, `Bearer `, `/Users/`, `/home/`, stack trace signatures. Redact if found.

## Error Handling

Status updates are informational, not critical path. Failures are logged and skipped.

| Failure | Action |
|---------|--------|
| GraphQL fails | Log warning, skip this project, continue others |
| MCP `save_status_update` fails | Log warning, do NOT fall back to `create_document` |
| Auth error (401) | Check `$LINEAR_API_KEY` is set (OAuth token doesn't work) |
| Any failure during session-exit | Log warning, continue. NEVER block exit. |

## Anti-Patterns

- **Blocking session-exit** on status update failures
- **Using `save_status_update` for projects** (MCP only supports initiatives)
- **Using `create_document` for updates** (use native Updates tab via GraphQL)
- **Using `$LINEAR_AGENT_TOKEN` for GraphQL** (returns 401)
- **Round-tripping content** (always compose fresh markdown)
- **Posting empty updates** (skip if no status changes)
