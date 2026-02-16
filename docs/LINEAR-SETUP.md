# Linear Platform Integration Guide

This guide configures Linear as the reference ~~project-tracker~~ implementation for the Claude Command Centre (CCC) methodology. It covers team structure, label taxonomy, milestones, agent delegation, and operational workflows that make the CCC funnel work at full capacity.

**Audience:** Solo developers and small teams adopting CCC with Linear as their project tracker.

**Prerequisites:** A Linear workspace (free tier is sufficient) and at least one CCC-connected Claude Code session.

---

## 1. Team Structure

### Solo Developer (Recommended Default)

Create a single team. All issues, labels, and milestones live in one place.

| Setting | Value |
|---------|-------|
| Team name | Your choice (e.g., your name, project codename) |
| Team key | 3-4 letter prefix (e.g., `CIA`, `PRJ`) — this prefixes all issue IDs |
| Default assignee | You |
| Default priority | Normal (P3) |

One team is sufficient for most CCC users. The methodology's label taxonomy handles categorization that other teams might use multiple teams for.

### Multi-Team (Organizations)

Use multiple teams when you have genuinely separate domains with different workflows, backlogs, and team members. Common patterns:

| Pattern | Teams | When |
|---------|-------|------|
| **Domain split** | `Engineering`, `Design`, `Research` | Different skill sets, different backlogs |
| **Product split** | `ProductA`, `ProductB` | Separate products with separate roadmaps |
| **Stage split** | Not recommended | CCC labels handle stage tracking — don't use teams for this |

**Cross-team rules:**
- Labels are workspace-level (shared across teams) — create them once
- Projects can span teams — a single CCC project can contain issues from multiple teams
- Milestones are per-project, not per-team

### Team Settings to Configure

| Setting | Recommended Value | Why |
|---------|-------------------|-----|
| Issue ID prefix | Short, memorable | You'll type this constantly (e.g., `CIA-123`) |
| Default issue estimate | Off (let agent set per-issue) | Estimates inform execution mode — they should be deliberate |
| Triage mode | Enabled | New issues land in Triage for review before entering backlog |
| Auto-archive | 3 months after completion | Keeps active views clean |
| Enable cycles | Yes | Required for cycle planning (Section 10) |
| Cycle duration | 1 week | CCC default cadence |
| Cycle start day | Monday | Aligns with weekly planning rhythm |

---

## 2. Label Taxonomy

CCC uses 29 workspace-level labels organized into 6 groups. Labels are the primary mechanism for routing issues through the CCC funnel — they replace what other methodologies use separate boards, columns, or team structures for.

### Why Workspace-Level

Create all labels at the workspace level (not team level) so they're available across all teams. This is critical for multi-team setups — a `type:feature` label should mean the same thing everywhere.

### Label Groups

#### Type Labels (Required on Every Issue)

Every issue must have exactly one type label. These drive triage routing and reporting.

| Label | Color | When to Apply |
|-------|-------|---------------|
| `type:feature` | Green | New functionality, user-facing capabilities |
| `type:bug` | Red | Broken behavior, regressions |
| `type:chore` | Gray | Maintenance, refactoring, dependency updates, cleanup |
| `type:spike` | Purple | Research, investigation, timeboxed exploration |

#### Spec Lifecycle Labels

Track where a spec stands in the CCC authoring pipeline. These coexist with execution mode labels — an issue can be both `spec:implementing` and `exec:tdd`.

| Label | Color | State | Description |
|-------|-------|-------|-------------|
| `spec:draft` | Light blue | Authoring | Initial spec being written. May be incomplete. |
| `spec:ready` | Blue | Review-ready | Spec complete enough for adversarial review. |
| `spec:review` | Orange | Under review | Adversarial review in progress. |
| `spec:implementing` | Yellow | In development | Spec passed review, implementation begun. |
| `spec:complete` | Green | Delivered | Implementation matches spec. Acceptance criteria met. |

**Transition rules:**
- `draft` → `ready`: Agent or human asserts completeness
- `ready` → `review`: Reviewer begins adversarial review
- `review` → `implementing`: Review passes (no blocking issues)
- `review` → `draft`: Fundamental gaps found, rework needed
- `implementing` → `complete`: All acceptance criteria verified

#### Execution Mode Labels

The execution mode determines how implementation happens. Set by the agent based on complexity estimate.

| Label | Color | When | How |
|-------|-------|------|-----|
| `exec:quick` | Light green | Well-defined + simple | Direct implementation |
| `exec:tdd` | Blue | Testable acceptance criteria | Red-green-refactor loop |
| `exec:pair` | Purple | Uncertain scope | Plan Mode → human-in-loop |
| `exec:checkpoint` | Orange | High-risk changes | Pause at milestones for review |
| `exec:swarm` | Red | 5+ independent parallel tasks | Subagent delegation |

#### Research Labels (Research-Heavy Projects)

Track research maturity for issues that require literature grounding. Progression is one-directional.

| Label | Color | Requirements to Advance |
|-------|-------|------------------------|
| `research:needs-grounding` | Red | Issue created but no literature cited |
| `research:literature-mapped` | Yellow | 3+ papers cited in description or linked doc |
| `research:methodology-validated` | Blue | Instruments + statistical methods documented |
| `research:expert-reviewed` | Green | Human expert has reviewed (always manual) |

#### Template Labels

Indicate which PR/FAQ template an issue uses. Applied during spec authoring (Stage 2-3).

| Label | When |
|-------|------|
| `template:prfaq-feature` | User-facing feature with press release |
| `template:prfaq-infra` | Infrastructure or internal tooling |
| `template:prfaq-research` | Research-driven feature with literature base |
| `template:prfaq-quick` | Small scope, abbreviated PR/FAQ |

#### Origin Labels (Mutually Exclusive)

Track where an issue came from. Useful for intake analysis and understanding your ideation pipeline.

| Label | Source |
|-------|--------|
| `source:voice` | Voice memo transcription |
| `source:cowork` | Collaborative session (Cowork artifact) |
| `source:code-session` | Discovered during implementation |
| `source:direct` | Directly created (typed in) |
| `source:vercel-comments` | Vercel preview deployment comment |

### Setup Checklist

1. Go to **Settings > Labels** in your Linear workspace
2. Create each label with the name exactly as shown (including the prefix and colon)
3. Group labels by prefix for easy navigation — Linear auto-groups labels sharing a prefix
4. Optionally set colors per the suggestions above (or choose your own)
5. Verify: you should have 29 labels total across 6 groups

---

## 3. Milestone Conventions

Milestones represent deliverable scopes with a clear target date and completion criteria.

### Naming Convention

```
vX.Y — Short Description
```

Examples:
- `v1.0 — Core Funnel`
- `v2.0 — Capability Expansion`
- `M0 — Foundation` (use `M0` for pre-v1 foundational work)

### Target Dates

Set a target date for every milestone. This makes Pulse and progress tracking meaningful.

| Milestone Type | Typical Duration | Notes |
|---------------|-----------------|-------|
| Foundation (M0) | 2-4 weeks | One-time setup, basic functionality |
| Minor version (vX.Y) | 2-3 weeks | Feature batch, well-scoped |
| Major version (vX.0) | 4-6 weeks | Significant capability expansion |

### Completion Criteria

A milestone is complete when **all issues** in it are either Done or Cancelled. No exceptions.

**Rules:**
- Never leave open issues in a "completed" milestone — it creates confusing progress metrics
- If an issue needs to carry forward, move it to the next milestone before marking the current one complete
- Cancelled issues count as resolved (the decision not to do something is still a decision)

### When to Create New Milestones

| Trigger | Action |
|---------|--------|
| Major feature batch identified | Create milestone with target date |
| Current milestone is >80% done with significant remaining work | Split — close current, create next |
| Pivot or restructuring | Archive old milestone, create new one with updated scope |

---

## 4. Project Description Template

Every CCC project should have a structured description that serves as a living dashboard. Copy and adapt this template:

```markdown
# [Project Name]

[One-sentence elevator pitch]

**Repo:** [link to source code repository]

## Milestone Map

| Milestone | Focus | Target | Status |
|-----------|-------|--------|--------|
| M0 — Foundation | [scope] | YYYY-MM-DD | Complete |
| v1.0 — [Name] | [scope] | YYYY-MM-DD | Active |
| v2.0 — [Name] | [scope] | YYYY-MM-DD | Planned |

## Key Resources

- [Link to repo]
- [Link to key spec or plan]
- [Link to insights reports]

## Decision Log

| Date | Decision | Context |
|------|----------|---------|
| YYYY-MM-DD | [What was decided] | [Why, linking to issue or document] |

## Hygiene Rules

- **Staleness threshold:** 14 days (flag if description not updated and milestones changed)
- **Update cadence:** End of each session with issue status changes
- **Resource additions:** Same session as artifact creation
```

### Staleness Detection

The agent checks for staleness using these triggers:

| Trigger | Action |
|---------|--------|
| Description `updatedAt` >14 days AND milestone has new Done issues | Flag and propose update |
| Milestone count changes | Update description in same session |
| Project renamed | Update summary and description opening line |
| Major pivot | Rewrite description, add decision log entry |

---

## 5. Agent Delegation Setup

Linear supports AI agent delegation natively. Agents receive work through Linear's assignment and delegation primitives — no custom webhooks required.

### Enabling Agents

1. Go to **Settings > Agents** in your Linear workspace
2. Enable the agents you want to use
3. Configure workspace-level agent guidance (see below)

### Available Agents

| Agent | How to Enable | Cost | CCC Stages |
|-------|--------------|------|------------|
| **Claude** | OAuth app via Linear API | Included with Claude | All stages (pull-based) |
| **cto.new** (Engine Labs) | Enable in Linear Settings > Agents | Free | Stage 0 intake, Stages 5-6 |
| **Cursor** | Native Linear integration | $20/mo Pro | Stage 6 (exec:tdd) |
| **GitHub Copilot** | GitHub App + Actions label triggers | Free tier | Stage 6 (exec:quick) |
| **Sentry** | Linear integration from Sentry dashboard | Free tier | Stage 7 (error → auto-issue) |

### Agent Guidance Configuration

Linear supports workspace-level and team-level agent guidance — markdown instructions that every agent receives when working on issues in your workspace.

**Where to set it:** Settings > Agents > Additional guidance

**Recommended workspace guidance:**

```markdown
## CCC Workflow Context

This workspace uses Claude Command Centre (CCC). Issues follow a funnel:
Stage 0 (Intake) → 1-3 (Spec) → 4 (Review) → 5-6 (Implement) → 7 (Verify) → 7.5 (Close)

When working on an issue:
- Read the full description and all comments before acting
- Check labels for execution mode (exec:quick, exec:tdd, etc.)
- Post findings as structured comments, not inline edits
- Do not close or transition issues — only the primary assignee does that
- Branch naming: use your agent prefix (e.g., cursor/, copilot/) followed by the issue identifier
```

### Dispatch Flow

All agents follow the same pattern:

1. **Delegate** an issue to the agent (use the Delegate field or @mention in a comment)
2. Agent reads issue context (description, comments, labels, linked documents)
3. Agent produces output (comment, PR, status transition)
4. Human reviews agent output (accept, reject, iterate)
5. Remove delegation when agent work is complete

### Push vs Pull Agents

| Reactivity | Agents | Behavior |
|------------|--------|----------|
| **Push-based** (async) | cto.new, Cursor, Copilot, Sentry | Receives Linear webhook, processes autonomously |
| **Pull-based** (session) | Claude | Reads delegated issues when a Claude Code session starts |

Claude cannot reactively process Linear events without a running session. For truly async dispatch, use a push-based agent.

---

## 6. Initiative Mapping

Linear Initiatives provide a portfolio view across projects. Map CCC milestones to Initiatives for strategic oversight.

### When to Use Initiatives

| Scenario | Use Initiatives? |
|----------|-----------------|
| Single project, solo developer | Optional — milestones are sufficient |
| Multiple CCC projects | Yes — group related milestones across projects |
| Conference/deadline-driven work | Yes — initiative per conference or deadline |
| Organizational portfolio view | Yes — one initiative per strategic objective |

### Mapping Pattern

```
Initiative: "Q1 2026 Ship Goals"
├── Project A: Milestone "v2.0 — Feature Expansion"
├── Project B: Milestone "v1.0 — Launch"
└── Project C: Milestone "M0 — Foundation"
```

### Creating Initiatives

Initiatives link to projects (not individual issues). Structure them around:

- **Time horizons:** Quarterly or monthly goals
- **Strategic themes:** "Research capabilities", "Developer experience", "Distribution"
- **External deadlines:** Conference submissions, launch dates, funding milestones

### Status Updates on Initiatives

Use Linear's initiative status updates to communicate portfolio health. Post updates at the initiative level (not per-project) to avoid duplication.

| Health | Meaning | Action |
|--------|---------|--------|
| On Track | All linked milestones progressing normally | Continue |
| At Risk | One or more milestones have blockers | Identify and resolve blockers |
| Off Track | Milestone target date at risk | Rescope, reprioritize, or extend |

---

## 7. Inbox Discipline

Linear's Inbox is the unified feed for notifications, assignments, and mentions. Disciplined inbox usage prevents important signals from being lost in noise.

### Daily Triage Ritual

Spend 5-10 minutes at the start of each working session triaging your inbox:

1. **Process top-down** — newest first
2. **For each item**, decide immediately:
   - **Act** — respond, update, or delegate (takes <2 minutes)
   - **Defer** — snooze to a specific time if it needs focused work
   - **Archive** — informational only, no action needed
3. **Goal:** Empty inbox by end of triage

### Assignment vs Delegation

Linear distinguishes between assignment (who owns the issue) and delegation (which agent is working on it). Use them correctly:

| Field | Purpose | Who Sets It |
|-------|---------|-------------|
| **Assignee** | Who is accountable for the issue's completion | Human (or agent during triage) |
| **Delegate** | Which AI agent is actively working on it | Human (dispatch) or agent (self-assign) |

**Rules:**
- An issue should have at most one assignee and at most one delegate
- The assignee may differ from the delegate (e.g., you're accountable, but Claude is doing the work)
- Remove the delegate when the agent's work is complete
- Never assign more than 5-7 issues to a single person simultaneously — this is a capacity signal

### Triage States

New issues land in **Triage** (if triage mode is enabled). Process them into one of:

| Destination | When |
|-------------|------|
| **Backlog** | Accepted but not scheduled — will be picked up in a future cycle |
| **Todo** | Accepted and scheduled for current or next cycle |
| **In Progress** | Starting work immediately |
| **Cancelled** | Rejected — not worth doing. Add a comment explaining why. |

---

## 8. Reviews and Pulse

Linear's Reviews and Pulse features provide weekly operational visibility. Use them to maintain project health awareness.

### Project Updates (Reviews)

Post a project update at the end of each working session where issue statuses changed. Use the following format:

```markdown
# Daily Update — YYYY-MM-DD

**Health:** On Track | At Risk | Off Track

## What happened today
- [Grouped by theme: milestone work, triage, infra]
- [Reference issue IDs for traceability]

## What's next
- [Immediate next actions for the next session]
- [Any blockers or decisions needed]
```

**Rules:**
- Skip if no issue status changes occurred (no empty updates)
- Health signal: "On Track" if milestone progress is positive, "At Risk" if blockers exist, "Off Track" if milestone is overdue
- Keep updates concise — 3-5 bullets per section maximum

### Pulse (Weekly Digest)

Linear's Pulse provides an automated weekly summary of project activity. To get the most from it:

1. **Ensure accurate status transitions** — Pulse reflects what's in Linear, so real-time status updates (not batched) produce accurate signals
2. **Use milestones with target dates** — Pulse highlights milestone progress and velocity
3. **Review Pulse every Monday** — part of your cycle planning ritual (Section 10)

### Status Update Templates for Initiatives

When posting initiative-level status updates:

```markdown
## [Initiative Name] — Week of YYYY-MM-DD

**Health:** On Track | At Risk | Off Track

### Progress
- [Project A]: [milestone] — X/Y issues done
- [Project B]: [milestone] — X/Y issues done

### Highlights
- [Key accomplishments this week]

### Risks
- [Blockers, dependencies, capacity concerns]

### Next Week
- [Planned focus areas]
```

---

## 9. Customer Feedback Routing

External feedback from users, stakeholders, or collaborators should flow into the CCC funnel through a structured intake path.

### Feedback Sources

| Source | How to Route | Linear Entry Point |
|--------|-------------|-------------------|
| Email | Forward to Linear Inbox (via Linear's email integration) | Creates inbox item |
| Vercel preview comments | `source:vercel-comments` label auto-applied | Issue created via Vercel-Linear sync |
| Direct conversation | Manual issue creation | Apply `source:direct` label |
| User interviews | Manual issue creation | Apply `source:direct` + `type:spike` for research follow-up |
| Bug reports | Direct issue creation | Apply `type:bug` + `source:direct` |
| Feature requests | Direct issue creation | Apply `type:feature` + `source:direct` |

### Intake-to-Funnel Flow

```
External feedback
  → Linear Inbox (or direct issue creation)
  → Triage (daily ritual, Section 7)
  → Stage 0 (CCC intake — apply type + origin labels)
  → Stage 1-3 (spec authoring if feature/spike)
  → or immediate fix (if type:bug + exec:quick)
```

### Feedback Anti-Patterns

| Anti-Pattern | Why It Fails | Fix |
|-------------|-------------|-----|
| Feedback sits in email | Invisible to the funnel, never triaged | Route to Linear Inbox immediately |
| Feedback becomes a vague issue ("user wants X") | No acceptance criteria, no type label | Apply the CCC intake protocol: verb-first title, type label, brief description |
| Multiple feedback items in one issue | Can't track progress individually | One issue per distinct request |
| Feedback assigned directly to implementation | Skips spec and review stages | Route through Stage 0 intake, let the funnel do its job |

---

## 10. Cycle Planning

CCC uses 1-week cycles (sprints) starting on Mondays. Cycles are the operational heartbeat — they limit work-in-progress and create a regular planning cadence.

### Cycle Configuration

| Setting | Value |
|---------|-------|
| Duration | 1 week |
| Start day | Monday |
| Auto-complete | Enabled (moves incomplete issues to next cycle) |

### Planning Ritual (Monday, 15-20 minutes)

1. **Review Pulse** — check last week's velocity and carry-forward items
2. **Review Inbox** — triage anything that arrived over the weekend
3. **Select 5-7 issues** for the cycle using this mix:

| Category | Target | Why |
|----------|--------|-----|
| Research/Spec work | 1-2 issues | Keeps the pipeline fed (Stages 0-3) |
| Implementation | 2-3 issues | Core delivery (Stages 5-6) |
| Infra/Cleanup | 1-2 issues | Prevents technical debt accumulation |

4. **Assign issues** to cycle — drag from backlog into the current cycle
5. **Set priority** on cycle items (human-owned action)
6. **Delegate** implementation items to appropriate agents

### Capacity Rules

- **5-7 issues per cycle** for a solo developer is the sustainable target
- If carry-forward exceeds 3 issues, the cycle was overloaded — reduce next week
- Spikes and research should be timeboxed (add a time estimate to the description)
- Never fill a cycle to 100% — leave slack for unplanned work and bug fixes

### Mid-Cycle Check (Wednesday/Thursday)

Quick 5-minute check:
- Are any issues blocked? Surface blockers as comments.
- Is the cycle on track to complete? If not, move lowest-priority items back to backlog.
- Any new urgent items? Add to cycle only if you remove something else.

### Cycle Retrospective (Friday, 5 minutes)

At the end of each cycle:
1. How many issues completed vs planned?
2. What caused carry-forward? (Underestimation, blockers, scope creep)
3. One thing to adjust next week

This doesn't need to be formal — a mental check or brief note in your project update is sufficient.

---

## Quick-Start Checklist

For teams setting up Linear with CCC for the first time, complete these items in order:

- [ ] Create your team with a memorable key prefix
- [ ] Enable triage mode and cycles (1-week, Monday start)
- [ ] Create all 29 workspace-level labels (Section 2)
- [ ] Create your first project with the description template (Section 4)
- [ ] Create an initial milestone (e.g., `M0 — Foundation`)
- [ ] Configure agent guidance in Settings > Agents (Section 5)
- [ ] Enable at least one AI agent (Claude is the default)
- [ ] Create your first issue with proper labels (`type:*` required)
- [ ] Set up your daily inbox triage habit (Section 7)
- [ ] Configure your first 1-week cycle (Section 10)

---

## Cross-References

- **Issue lifecycle ownership:** See `skills/issue-lifecycle/SKILL.md` for the full ownership model (who changes what on issues)
- **Connector setup:** See `CONNECTORS.md` for the complete tool integration guide including ~~project-tracker~~ configuration
- **Execution modes:** See `skills/execution-modes/SKILL.md` for how `exec:*` labels map to implementation approaches
- **Adversarial review:** See `skills/adversarial-review/SKILL.md` for the review protocol that the `spec:review` label gates
- **Project hygiene:** See `skills/issue-lifecycle/references/project-hygiene.md` for the full project hygiene protocol
