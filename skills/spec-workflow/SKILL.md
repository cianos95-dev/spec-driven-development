---
name: spec-workflow
description: |
  Complete 9-stage spec-driven development funnel from ideation through deployment, with 3 approval gates, universal intake protocol, plan promotion to durable documents, and issue closure rules.
  Use when understanding the full development workflow, checking what stage a feature is in, determining next steps for an issue, promoting plans to Linear Documents, or onboarding to the spec-driven process.
  Trigger with phrases like "what stage is this in", "development workflow overview", "what are the approval gates", "how does the funnel work", "intake process", "what happens after spec approval", "promote this plan", "save plan to Linear", "make plan durable".
compatibility:
  surfaces: [code, cowork, desktop]
  tier: degraded-cowork
  degradation_notes: "/ccc:go command requires Claude Code; workflow methodology and Linear MCP operations work in all surfaces"
---

# Claude Command Centre Workflow

This is the complete funnel from idea to production. Every feature, fix, and infrastructure change flows through these stages. The funnel enforces three human approval gates and eliminates ambiguity about what is being built, why, and when it is done.

## Funnel Overview

The funnel flows: Intake (Stage 0) → Ideation (1) → Analytics (2) → PR/FAQ Draft (3) → **Gate 1** → Adversarial Review (4) → **Gate 2** → Visual Prototype (5) → Implementation (6) → **Gate 3** → Verification (7) → Closure (7.5) → Async Handoff (8).

> See [references/stage-details.md](references/stage-details.md) for the full mermaid diagrams and stage-by-stage breakdown with activities, outputs, and skip conditions.

## Unified Entry Point: `/ccc:go`

```
/ccc:go [argument] [--quick] [--mode MODE] [--status] [--next]
```

| Argument | Behavior |
|----------|----------|
| (none) | Check for active work, resume or ask what to build |
| `--status` | Show "You Are Here" text-based funnel view |
| `CIA-XXX` | Route by issue status to correct stage |
| `"free text"` | New idea → intake → spec draft |
| `--quick` | Collapse funnel for small tasks |
| `--next` | Pick up next unblocked task |

See the `/ccc:go` command definition and the **execution-engine** skill for full details.

## Fast Paths

Not every task needs the full 9-stage funnel. The execution mode determines which stages to skip:

| Execution Mode | Stages Used | Stages Skipped | Typical Use |
|---------------|-------------|----------------|-------------|
| `quick` | 0, 3 (quick template), 6, 7, 7.5 | 1, 2, 4, 5, 8 | Bug fixes, small features, config changes |
| `tdd` | 0, 3, 6, 7, 7.5 | 2, 4, 5, 8 | Well-defined features with clear AC |
| `pair` | 0, 1, 3, 4, 6, 7, 7.5 | 2, 5, 8 | Uncertain scope requiring human-in-the-loop |
| `checkpoint` | All stages | None | High-risk changes, infrastructure, breaking changes |
| `swarm` | 0, 3, 4, 6, 7, 7.5 | 2, 5, 8 | Large scope decomposed into parallel subtasks |

**Rule of thumb:** If the task can be described in one sentence and has an obvious implementation, use `quick` and skip to Stage 6 after intake.

## Stage Reference

| # | Stage | Key Tools | Gate |
|---|-------|-----------|------|
| 0 | Universal Intake | ~~project-tracker~~ | None (normalization) |
| 1 | Ideation | ~~project-tracker~~ MCP | None |
| 2 | Analytics Review | ~~analytics-platform~~ | None (informational) |
| 3 | PR/FAQ Draft | PR/FAQ templates, ~~project-tracker~~ MCP | **Human: approve spec** |
| 4 | Adversarial Review | Review options A-H, RDR table | **Human: accept findings** |
| 5 | Visual Prototype | Design tool routing | None (skip for non-UI) |
| 6 | Implementation | Subagents, model mixing | **Human: review PR** |
| 7 | Verification | Preview deploy, analytics check | Merge to production |
| 7.5 | Issue Closure | Metadata-driven closure rules | Auto/propose per rules |
| 8 | Async Handoff | Remote dispatch | N/A |

## Approval Gates

The three gates are the only points where human judgment is required. Everything else can be automated or agent-driven.

1. **Gate 1: Approve Spec** (Stage 3 exit) — Is this spec clear enough and valuable enough? On approval: `spec:draft` → `spec:ready`. On rejection: return to Stage 3.

2. **Gate 2: Accept Findings** (Stage 4 exit) — Are review findings acceptable? Human fills Decision/Response columns in the RDR table. Gate passes when all Critical and Important findings have a Decision value. On REVISE: return to Stage 3. On RETHINK: return to Stage 1.

3. **Gate 3: Review PR** (Stage 6 exit) — Does implementation match the spec? On approval: merge and proceed. On changes requested: return to Stage 6.

Everything before Gate 1 is exploration. Everything between Gate 1 and Gate 3 is execution. Everything after Gate 3 is verification.

## Stage Transitions and Labels

| Label | Meaning | Set When |
|-------|---------|----------|
| `spec:draft` | PR/FAQ written, awaiting approval | Stage 3 complete |
| `spec:ready` | Spec approved, ready for review | Gate 1 passed |
| `spec:review` | Under adversarial review | Stage 4 in progress |
| `spec:implementing` | Code is being written | Stage 6 in progress |
| `spec:complete` | Shipped and verified | Stage 7.5 closure |

## Master Plan Pattern

When batched or sequential work spans 2+ sessions, create a **master session plan issue** with sub-issues for each step.

**Two-session gate:**
- **Session 1** = decisions, research, and planning. Produce recommendations, not changes.
- **Human review gate** between sessions.
- **Session 2** = execution. Apply the decisions made and approved in Session 1.

**Why separate sessions:** Never mix research/decisions and execution in the same session. Combining both leads to >70% context consumption, rushed decisions, and execution that outpaces approval.

## Plan Promotion

Elevate ephemeral session plans to durable Linear Documents for cross-surface access. This bridges the Code tab (where plans are written) and Cowork (where plans are refined collaboratively). Linear is the shared state layer.

### Two-Tier Plan Architecture

| Tier | Location | Lifecycle | Access |
|------|----------|-----------|--------|
| **Tier 1: Ephemeral** | `~/.claude/plans/<session-slug>.md` | Session-scoped, disposable after execution | Code tab only |
| **Tier 2: Durable** | Linear Document (primary) or `docs/plans/` (architectural) | Persists across sessions, projects, surfaces | Any surface with Linear MCP |

**When to promote (Tier 1 → Tier 2):**
- Plan spans multiple sessions or will be resumed later
- Plan captures architectural decisions needing team visibility
- Plan needs review or refinement in Cowork
- Plan is for a 3+ point issue (non-trivial scope)

**When NOT to promote:** Quick-mode plans, exploration plans, plans immediately superseded by execution.

**Protocol:** Resolve plan source → resolve target issue → check for existing plan document → create/update Linear Document → link to issue via comment → add local backlink.

> See [references/plan-promotion.md](references/plan-promotion.md) for the full 8-step promotion protocol, document format, pre-update validation, platform-specific behavior, and listing promoted plans.

## Scope Discipline

- **Pilot batch before bulk:** When a task affects 10+ items, do a pilot batch of 3-5 first.
- **Approach confirmation:** Before executing a plan touching >5 files or >10 issues, confirm the approach.
- **Scope creep guard:** If during execution you discover new work, create a sub-issue immediately. NEVER add scope to the parent issue.
- **Anti-pattern — "while I'm here":** Resist fixing adjacent issues during implementation. Log them as new issues.

## Human Review Gate Enforcement

- No gate can be skipped, even for `quick` mode (which still requires Gate 3: PR review)
- Gates are synchronization points: agent stops, human catches up, then work resumes
- Passing a gate is an **explicit human action**, never implicit
- **Architectural decisions require split sessions:** Any change to architecture, data models, or cross-cutting concerns → Session 1 produces proposal, human reviews, Session 2 executes only what was approved.
- **Evidence format:** Summary tables, linked to tracker issues, with explicit recommendation. Human should decide in under 5 minutes of reading.

## Cross-Skill References

- **execution-engine** -- Powers Stage 6 (stop hook task loop, `.ccc-state.json`, `.ccc-progress.md`, gate pauses, retry budget)
- **prfaq-methodology** -- Governs Stage 3 (PR/FAQ drafting process, templates, interactive questioning)
- **adversarial-review** -- Governs Stage 4 (reviewer perspectives, architecture options A-H, RDR for Gate 2)
- **execution-modes** -- Governs Stage 6 (quick, tdd, pair, checkpoint, swarm routing)
- **issue-lifecycle** -- Governs Stage 7.5 (closure rules, evidence requirements, ownership boundaries)
- **context-management** -- Applies across all stages (subagent delegation, output brevity, model mixing)
- **document-lifecycle** -- Safety rules for plan promotion (no round-tripping, pre-update validation)
- **platform-routing** -- Surface detection for Code vs Cowork plan promotion behavior
