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

## Daily Project Update Format

```markdown
# Daily Update -- YYYY-MM-DD

**Health:** On Track | At Risk | Off Track

## What happened today
- [Grouped by theme: milestone work, triage, infra, etc.]
- [Reference issue IDs for traceability]

## What's next
- [Immediate next actions for the next session]
- [Any blockers or decisions needed]
```

**Rules:**
- Post at end of each working session where issue statuses changed
- Skip if no issue status changes occurred (no empty updates)
- Create as a Linear document attached to the project (titled "Project Update -- YYYY-MM-DD")
- Health signal: "On Track" if milestone progress is positive, "At Risk" if blockers exist, "Off Track" if milestone is overdue
- Keep updates concise -- 3-5 bullets per section maximum

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
