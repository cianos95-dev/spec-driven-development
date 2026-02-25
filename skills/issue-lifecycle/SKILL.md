---
name: issue-lifecycle-ownership
description: |
  Agent/human ownership model for issue and project management. Defines who owns which actions on issues (status, labels, priority, estimates, closure) and projects (summary, description, updates, resources). Includes closure rules matrix, session hygiene protocols, spec lifecycle labels, project hygiene protocol with staleness detection, and daily update format.
  Use when determining what the agent can change vs what requires human approval, closing issues, updating issue status, managing labels, handling session-end cleanup, maintaining project descriptions, posting project updates, or managing project resources.
  Trigger with phrases like "can I close this issue", "who owns priority", "issue ownership rules", "session cleanup protocol", "what labels should I set", "closure evidence requirements", "project description stale", "post project update", "add resource to project", "update project summary".
compatibility:
  surfaces: [code, cowork]
  tier: degraded-cowork
  degradation_notes: "Linear ownership rules and MCP operations work in Cowork; hooks and file-system operations require Code"
---

# Issue Lifecycle Ownership

AI agents and humans have complementary strengths in issue management. This skill defines clear ownership boundaries so the agent acts autonomously where appropriate and defers where human judgement is required. The goal is maximum agent autonomy within safe, well-defined rails.

## Core Principle

The agent owns **process and implementation artifacts** (status, labels, specs, estimates). The human owns **business judgement** (priority, deadlines, capacity). Either can create and assign work. Closure follows a rules matrix based on assignee and complexity.

## Ownership Table

| Action | Owner | Rationale |
|--------|-------|-----------|
| Create issue | Either | Agent creates from plans, specs, or discovered work. Human creates ad hoc or from external input. |
| Status to In Progress | Whoever starts work | Agent marks as soon as implementation begins. Human marks for manual work. Never batch -- update immediately when work starts. |
| Status to Done | Agent (auto-close per rules) | Only when: agent is assignee + single PR + merged + deploy green. See closure rules below. |
| Status to Done (propose) | Agent proposes, human confirms | For human-owned issues, multi-PR efforts, pair work, or research tasks. Agent provides evidence, waits for confirmation. |
| Status to Todo/Backlog | Agent during triage | After planning sessions, during batch status normalization. |
| Add/remove labels | Agent | Labels are programmatic workflow markers, not human-facing metadata. Agent maintains label hygiene. |
| Update description/spec | Agent | Spec content is the agent's domain. Agent keeps specs current as understanding evolves. |
| Assign/delegate | Either | Agent assigns to self or proposes assignment. Human assigns based on capacity or expertise. |
| Set priority | Human | Priority reflects business value, stakeholder urgency, and strategic context that only humans can assess. |
| Set estimates | Agent | The implementer owns complexity assessment. Estimates inform execution mode selection. |
| Set due dates | Human | Due dates represent commitments to stakeholders. Only humans make commitments. |
| Assign to cycle/sprint | Human | Capacity planning requires awareness of team bandwidth, competing priorities, and external constraints. |
| Close stale items | Agent proposes, human confirms | Never auto-close without evidence. Agent surfaces candidates with rationale; human decides. |

## Session Naming for Traceability

Every working session should be named to link it to the issue being worked on. Use `/rename CIA-XXX: <short title>` at session start. This:
- Makes plan files at `~/.claude/plans/<session-slug>.md` traceable to their originating issue
- Provides provenance when plans are promoted to Linear Documents
- Persists across resume and compaction (Claude Code v2.1.47+)

The `/ccc:go` command auto-renames the session when loading an issue. Manual rename is needed when starting work outside the go command.

## Sub-Issue Creation and Dependency Wiring

When `/ccc:decompose` (or any workflow step) creates sub-issues under a parent, the **dependency-management** skill is automatically invoked to wire sequential relations.

**Protocol:**
1. After all sub-issues are created, pass the ordered list to `dependency-management`'s auto-relation protocol.
2. The skill identifies sequential pairs from the decomposition and proposes `blocks` relations.
3. Present the proposed relation table to the user for confirmation (unless `--yes` is passed).
4. On confirmation, `dependency-management` executes `safeUpdateRelations` for each pair.

**This skill does NOT contain relation logic.** All `blocks`, `blockedBy`, and `relatedTo` operations are delegated to `dependency-management`. Never call `update_issue` with relation parameters directly from this skill.

See `dependency-management` skill for the `safeUpdateRelations` protocol and the C1 safety rule (relation arrays replace, not append).

## Project Creation and Document Bootstrap

When a new project is created (or an existing project has no structural documents), invoke the **document-lifecycle** skill to bootstrap required documents.

**Trigger:** Any time this skill creates issues within a project that has no "Key Resources" or "Decision Log" document (detected via `list_documents`).

**Protocol:**
1. After issue creation, check `list_documents(project)` for required structural documents.
2. If "Key Resources" is missing: delegate creation to `document-lifecycle` structural checklist.
3. If "Decision Log" is missing: delegate creation to `document-lifecycle` structural checklist.
4. Respect the `<!-- no-auto-docs -->` opt-out in the project description (checked by `document-lifecycle`).

**This skill does NOT create documents.** Document creation is owned by `document-lifecycle`. This skill only triggers the check after project-level issue operations.

## Closure Rules

Closure is the highest-stakes status transition. The canonical closure matrix — including all AUTO-CLOSE, PROPOSE, and BLOCK conditions, quality gate thresholds, conflict resolution, and recovery commands — lives in `references/closure-rules.md`.

The `/close` command is the **universal entry point** for all closure. It applies the closure rules, computes the quality score, and executes the appropriate action. Branch-finish marks issues as "closure-ready" after merge; `/close` evaluates and executes.

**Every Done transition requires a closing comment** with evidence per `references/evidence-mandate.md`. Status changes without evidence are not permitted.

## Session Hygiene

### Mid-Session Rules

- **Mark In Progress immediately** when work begins on an issue. Do not wait until the work is complete to update status. The issue tracker should reflect reality at all times.
- **Update labels in real-time** as understanding evolves. If an issue turns out to need `exec:checkpoint` instead of `exec:quick`, change the label as soon as you realize it.
- **Do not batch status updates.** Each status change should happen at the moment the transition occurs, not at the end of a session.

### Session Exit Protocol

At the end of every work session, perform status normalization:

1. Review all issues touched during the session
2. Ensure every issue reflects its true current state
3. Add closing comments to any issues marked Done (with evidence)
4. Issues that are partially complete remain In Progress with a comment describing current state and next steps
5. Issues that were started but blocked get a comment explaining the blocker

### Re-open Protocol

If a human re-opens a closed issue within 48 hours:

1. Acknowledge the premature closure in a comment
2. Review what was missed or incomplete
3. Adjust approach based on the feedback
4. Do not re-close without addressing the reason for re-opening

This is a signal to calibrate. If premature closures happen repeatedly, tighten the closure criteria (e.g., require human confirmation for all closures in that project for a period).

## Spec Lifecycle Labels

Specs progress through a defined lifecycle. Apply these labels to track where a spec stands:

| Label | State | Description |
|-------|-------|-------------|
| `spec:draft` | Authoring | Initial spec being written. May be incomplete, have open questions, or lack acceptance criteria. |
| `spec:ready` | Review-ready | Spec is complete enough for adversarial review. All sections filled, acceptance criteria defined. |
| `spec:review` | Under review | Adversarial review in progress. Reviewer is actively challenging assumptions, finding gaps. |
| `spec:implementing` | In development | Spec passed review and implementation has begun. Spec content is now the source of truth for the implementer. |
| `spec:complete` | Delivered | Implementation matches spec. Acceptance criteria met. Spec is now documentation. |

**Transition rules:**
- `draft` to `ready`: Agent or human asserts completeness
- `ready` to `review`: Reviewer (agent or human) begins adversarial review
- `review` to `implementing`: Review passes with no blocking issues. Minor issues can be noted for implementation.
- `review` to `draft`: Review reveals fundamental gaps. Spec returns for rework.
- `implementing` to `complete`: All acceptance criteria verified. Tests pass. Deployment confirmed.

**Spec labels coexist with execution mode labels.** An issue can be both `spec:implementing` and `exec:tdd`. The spec label tracks the document lifecycle; the execution label tracks the implementation approach.

## Carry-Forward Items Protocol

When adversarial review findings or implementation tasks cannot be fully resolved within the current issue's scope, they must be explicitly tracked rather than silently dropped.

### When This Applies

- Adversarial review findings rated **Important** or **Consider** that are deferred during implementation
- Implementation discoveries that reveal work outside the current issue's scope
- Technical debt identified during implementation that is not blocking

### The Protocol

1. **Create a new issue** for each carry-forward item (or group closely related items into one issue)
2. **Link the new issue** as "related to" the source issue using ~~project-tracker~~ relations
3. **Reference the source** in the new issue description: "Carry-forward from CIA-XXX adversarial review finding I3"
4. **Add the carry-forward item** to the fix-forward summary in the source issue's closing comment (see adversarial-review skill)
5. **Apply appropriate labels** to the new issue (`spec:draft` if it needs a spec, or appropriate exec mode if scope is clear)

### What NOT to Do

- Do not leave findings untracked in a review document without corresponding issues
- Do not close the source issue without documenting what was deferred and where
- Do not add carry-forward items to the source issue's own scope (this causes scope creep and blocks closure)

## Issue Naming Convention

### Verb-First, No Brackets

Issue titles start with an action verb, lowercase after first word. No bracket prefixes.

| Pattern | Correct | Incorrect |
|---------|---------|-----------|
| Feature | `Build avatar selection UI component` | `[Feature] Avatar Selection UI` |
| Research | `Survey limerence measurement instruments` | `[Research] Limerence Instruments` |
| Infrastructure | `Configure Supabase pgvector` | `[Infrastructure] Supabase pgvector` |

**Common verb starters:** Build, Implement, Fix, Add, Create, Evaluate, Survey, Design, Migrate, Configure, Audit, Ship, Set up, Wire up

### Reference Content Goes to Documents

Non-actionable content (research notes, decisions, session learnings) should be Linear Documents, not issues. Apply the "Can someone mark this Done?" test -- if no, it's a Document.

See the `project-cleanup` skill for the full Content Classification Matrix.

> See [references/project-hygiene.md](references/project-hygiene.md) for the full project hygiene protocol including artifact cadence, description structure, staleness detection, daily update format, and resource management.

> See [references/content-discipline.md](references/content-discipline.md) for issue content discipline rules, anti-patterns, master session plan pattern, and scope limitation handoff protocol.

## Linear-Specific Operational Guidance

Linear is the reference ~~project-tracker~~ implementation for CCC. This section maps Linear-native features to CCC lifecycle stages. For full Linear setup (labels, milestones, agents, cycles), see [docs/LINEAR-SETUP.md](../../../../docs/LINEAR-SETUP.md).

### Inbox and Triage (Stage 0)

Use Linear's native Triage view with responsibility settings (No action / Notify / Assign). CCC adds: `type:*` and `source:*` labels are required before an issue leaves Triage state. Use Linear's Delegate field to route implementation to an AI agent.

### Status Transitions (All Stages)

Use Linear's native workflow automation for status transitions. CCC adds the ownership model (table above) governing who can make each transition. Update status immediately when transitions happen -- never batch.

### Reviews and Pulse (Stage 7.5 + Ongoing)

Post project updates through Linear's Reviews feature at session end (not as issue comments). This feeds into Pulse, giving weekly visibility:

- **When to post:** End of any session where issue statuses changed
- **Format:** Use the daily update template from `references/project-hygiene.md`
- **Health signals:** On Track / At Risk / Off Track -- Pulse aggregates these across projects

### Cycles (Ongoing)

Linear cycles are the operational heartbeat for CCC:

- **Duration:** 1-week cycles, Monday start
- **Capacity:** 5-7 issues per cycle (mix of research, implementation, cleanup)
- **Monday ritual:** Review Pulse, triage inbox, select and assign cycle items
- **Mid-week check:** Surface blockers, move low-priority items back to backlog if overloaded
- **Auto-complete:** Enable so incomplete issues roll to the next cycle automatically

### Initiatives (Portfolio View)

When managing multiple CCC projects, use Linear Initiatives to group related milestones:

- One initiative per strategic theme or time-bound goal
- Link projects (not individual issues) to initiatives
- Post initiative-level status updates for portfolio visibility
- Review initiative health during Monday planning

### Customer Feedback Routing

External feedback enters the CCC funnel through Linear:

1. Route feedback to Linear Inbox (via email integration, direct creation, or Vercel comment sync)
2. Triage during daily inbox review
3. Apply `source:*` origin label to track where feedback came from
4. Process through Stage 0 intake (verb-first title, type label, brief description)

### Template Selection

When creating issues in Linear, select the correct template based on issue type. Templates pre-populate labels, estimates, and description structure:

| Issue Type | Template | Pre-Set Labels | Default Estimate | When |
|------------|----------|----------------|------------------|------|
| New functionality | Feature | `type:feature`, `spec:draft` | 3pt | User-facing capabilities, new components |
| Broken behavior | Bug | `type:bug` | (unset — assess per issue) | Regressions, incorrect behavior, crashes |
| Research/investigation | Spike | `type:spike`, `research:needs-grounding` | 3pt | Timeboxed exploration, literature review |
| Maintenance/cleanup | Chore | `type:chore` | 1pt | Refactoring, dependency updates, config |

**Template selection rule:** Always use a template rather than creating a blank issue. Templates enforce the label taxonomy and provide consistent description structure. If no template fits, default to Chore.

> **API note:** Linear templates are a UI feature — the Linear MCP's `create_issue` does not accept a template parameter, so template defaults are **not** auto-applied when agents create issues via API. However, templates ARE fully accessible via Linear's GraphQL API:
>
> - **Query:** `{ templates { id name type templateData } }` — returns all templates with their full `templateData` (labels, estimates, description structure)
> - **Mutations:** `templateCreate`, `templateUpdate`, `templateDelete` — full CRUD
> - **Integration templates** (`integrationTemplateCreate`) are for customer support channels only (`slackAsks`, `asks`, `intercom`, `slack`, `zendesk`, `salesforce`) — NOT for agent dispatch
>
> **Agent dispatch pattern:** Use `delegateId` on `issueCreate`/`issueUpdate` to assign work to agents. This triggers an `AgentSessionEvent` webhook with `promptContext`. Agents do NOT auto-apply templates — the Template Selection table above replicates template behavior programmatically. For dynamic template-aware creation, query `templateData` via GraphQL and apply fields to `create_issue`.

### Estimate-to-Execution-Mode Mapping

Issue estimates (Fibonacci extended) determine the execution mode label. The agent sets estimates based on complexity assessment, then applies the corresponding exec label:

| Estimate | Execution Mode | Rationale |
|----------|---------------|-----------|
| 1-2pt | `exec:quick` | Small, well-defined. Direct implementation. |
| 3pt | `exec:tdd` | Moderate complexity. Test-driven development appropriate. |
| 5pt | `exec:tdd` or `exec:pair` | Significant scope. TDD if acceptance criteria are clear; pair if scope is uncertain. |
| 8pt | `exec:pair` or `exec:checkpoint` | Large scope. Pair for collaborative work; checkpoint for high-risk changes. |
| 13pt | `exec:checkpoint` | Very large scope. Must decompose into sub-issues. Checkpoint with human review at milestones. |

**Rules:**
- Estimates inform exec mode — they are not arbitrary. If the estimate changes, re-evaluate the exec label.
- 13pt issues should always be decomposed. A single 13pt issue is a planning smell.
- Count unestimated issues as 1pt for velocity tracking (Linear setting: "Count unestimated" = ON).

### Triage Intelligence

Linear's Triage Intelligence runs in suggestions-only mode -- it never auto-applies changes. The agent should review suggestions before accepting, override if CCC methodology requires different labels, and always defer priority to the human (human-owned field). Always verify `type:*` label is present after triage.

### Agent Delegation Patterns

When issues are delegated to AI agents via Linear, the lifecycle ownership model intersects with the two-system agent architecture (see [docs/LINEAR-SETUP.md](../../../../docs/LINEAR-SETUP.md) Section 8):

| Delegation Pattern | System Used | Lifecycle Impact |
|-------------------|-------------|-----------------|
| Claude Code session reads delegated issues | OAuth app (pull-based) | Agent marks In Progress on session start, follows full ownership model |
| @mention Claude in a comment | Pre-built agent (webhook) | Agent responds conversationally. Does NOT trigger status transitions. |
| Delegate to Cursor/cto.new/Copilot | Pre-built agent (push-based) | Agent processes asynchronously. May create PR. Human reviews and manages status. |
| Delegate to Sentry | Pre-built agent (push-based) | Creates issues from errors. Issues enter Triage, follow normal lifecycle. |

**Ownership during delegation:**
- The **assignee** remains accountable for the issue even when delegated to an agent
- The **delegate** field tracks which agent is actively working
- Remove the delegate when the agent's work is complete
- Status transitions follow the ownership table above — the delegate does not override assignee ownership rules

## Cross-Skill References

- **`/close`** -- Universal closure entry point. Applies `references/closure-rules.md` matrix and quality gate.
- **references/closure-rules.md** -- Canonical closure matrix (AUTO-CLOSE/PROPOSE/BLOCK conditions, quality thresholds, recovery commands)
- **references/evidence-mandate.md** -- Evidence requirements for all completion claims and closing comments
- **branch-finish** -- Git operations and pre-completion verification. Marks "closure-ready" after merge; `/close` executes closure.
- **spec-workflow** -- Stage 7.5 (issue closure) is governed by the closure rules
- **project-cleanup** -- One-time structural normalization vs this skill's ongoing hygiene
- **context-management** -- Session exit summary tables follow the format defined in that skill
- **execution-engine** -- Execution loop updates issue status per the ownership model defined here
- **dependency-management** -- Invoked after sub-issue creation to auto-wire blocks/blockedBy relations via `safeUpdateRelations`
- **document-lifecycle** -- Invoked after project-level issue creation to bootstrap Key Resources and Decision Log structural documents
- **milestone-management** -- Delegates milestone assignment to `milestone-management` during issue creation (this skill does not contain assignment logic)
- **LINEAR-SETUP.md** -- Full Linear platform configuration guide (labels, milestones, agents, cycles, initiatives, OAuth app, pre-built agents, two-system architecture)
