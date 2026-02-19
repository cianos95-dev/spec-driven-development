# Project Hygiene Protocol

Projects are the container that gives issues strategic context. A well-maintained project makes milestone progress visible, keeps descriptions honest, and ensures new contributors (or future sessions) can orient quickly. This section defines what the agent maintains at the project level.

## Project Artifacts

| Artifact | Purpose | Cadence | Owner |
|----------|---------|---------|-------|
| **Summary** | One-line elevator pitch visible in project lists | On creation, rename, or major pivot | Agent |
| **Description** | Living document: milestone map, delineation table, hygiene rules, decision log | When milestones added/completed/restructured | Agent |
| **Resources** | Links to repo, specs, key docs, insights reports | When new key artifacts ship | Agent |
| **Project Update** | Daily status: what changed, what's next, health signal | End of each active working session | Agent |
| **Milestone progress** | Issue completion percentages | Automatic (on issue status change) | Agent (auto) |

## Project Description Structure

Every project description should contain these sections (adapt as needed):

1. **Opening line** -- What this project is, in one sentence
2. **Repo link** -- Clickable link to source code
3. **Milestone Map** -- Table showing all milestones, their focus, and dependencies
4. **Delineation** -- What's shareable/public vs personal/temporal (for plugin projects)
5. **Hygiene Protocol** -- Cadence table (copy from this skill, configure per project)
6. **Decision Log** -- Date + decision + context for major choices

## Staleness Detection Rule

The agent must check for project description staleness using these triggers:

| Trigger | Action |
|---------|--------|
| `updatedAt` on description is >14 days old AND any milestone has new Done issues | Flag "Project description may be stale" and propose an update |
| Milestone count changes (added or removed) | Update description in same session |
| Project renamed | Update summary and description opening line in same session |
| Major pivot or restructuring | Rewrite description; add entry to decision log |

**Configuration for plugin users:** The staleness threshold (default: 14 days) and trigger conditions should be documented in the project description itself so the agent knows what rules to follow for each project. Projects with daily active development may use 7 days; maintenance projects may use 30 days.

## Health Signal Definition (Canonical Source)

All health signal consumers reference this single definition. Do not duplicate these conditions elsewhere.

| Signal | Condition |
|--------|-----------|
| **On Track** | No overdue milestones AND no unresolved blockers on active (In Progress) issues |
| **At Risk** | Any blocker on an active issue OR any milestone target date within 3 days |
| **Off Track** | Any milestone past its target date with open issues remaining |

**Evaluation order:** Off Track > At Risk > On Track (worst signal wins).

**When milestone data is unavailable:** Default to On Track. Note the default in the update body.

**User override:** The `/ccc:status-update --health <signal>` flag allows manual correction when the computed signal is incorrect (e.g., stale milestone date that hasn't been updated).

**Consumers:** `project-status-update` skill, `session-exit` Step 4, `hygiene` command (read-only display).

## Daily Project Update

Project updates are posted to the **native Updates tab** via GraphQL `projectUpdateCreate`, NOT as Linear documents. This populates Linear's Pulse/Reviews view for project health visibility.

**Mechanism:** The `project-status-update` skill handles all posting logic. Session-exit Step 4 delegates to this skill.

**Format:**

```markdown
**Health:** On Track | At Risk | Off Track

## Progress
- CIA-XXX: Status change -- 1-line summary
- CIA-YYY: Status change -- 1-line summary

## Blocked
- CIA-ZZZ: Blocker description

## Created
- CIA-AAA: New issue title -- why created

## Next
- Planned next steps for the project

Posted by Claude agent | Session: YYYY-MM-DD
```

**Rules:**
- Post at end of each working session where issue statuses changed
- Skip if no issue status changes occurred (no empty updates)
- Same-day updates are amended (not duplicated) via dedup check
- Keep updates concise -- 3-5 bullets per section maximum
- Apply sensitivity filtering before posting (no credentials, no absolute paths, no stack traces)

## Resource Management

Resources are added as a Linear document attached to the project. Maintain a single "Key Resources" document with sections for:

- Source code repositories
- Specs and plans (with local file paths or URLs)
- Insights reports and archives
- Methodology references
- Linear navigation references (team, prefix, milestone names)

**Update rule:** When a new key artifact is created (new spec, new plan, new insights report), add it to the resources document in the same session. Do not create separate resource documents per artifact.

## Applying Project Hygiene

When the agent completes any of these actions, it should check the project hygiene checklist:

1. **Created a milestone** --> Update project description milestone map
2. **Completed a triage/routing session** --> Post daily update, update description if structure changed
3. **Shipped a key deliverable** --> Add to resources document
4. **Renamed or pivoted a project** --> Update summary + description + decision log
5. **End of any session with status changes** --> Post daily update
