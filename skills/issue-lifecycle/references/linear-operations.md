# Linear-Specific Operational Guidance

Linear is the reference project-tracker implementation for CCC. This reference maps Linear-native features to CCC lifecycle stages. For full Linear setup (labels, milestones, agents, cycles), see [docs/LINEAR-SETUP.md](../../../../docs/LINEAR-SETUP.md).

## Inbox and Triage (Stage 0)

Use Linear's native Triage view with responsibility settings (No action / Notify / Assign). CCC adds: `type:*` and `source:*` labels are required before an issue leaves Triage state. Use Linear's Delegate field to route implementation to an AI agent.

## Status Transitions (All Stages)

Use Linear's native workflow automation for status transitions. CCC adds the ownership model (see `ownership-matrix.md`) governing who can make each transition. Update status immediately when transitions happen -- never batch.

## Reviews and Pulse (Stage 7.5 + Ongoing)

Post project updates through Linear's Reviews feature at session end (not as issue comments). This feeds into Pulse, giving weekly visibility:

- **When to post:** End of any session where issue statuses changed
- **Format:** Use the daily update template from `project-hygiene.md`
- **Health signals:** On Track / At Risk / Off Track -- Pulse aggregates these across projects

## Cycles (Ongoing)

Linear cycles are the operational heartbeat for CCC:

- **Duration:** 1-week cycles, Monday start
- **Capacity:** 5-7 issues per cycle (mix of research, implementation, cleanup)
- **Monday ritual:** Review Pulse, triage inbox, select and assign cycle items
- **Mid-week check:** Surface blockers, move low-priority items back to backlog if overloaded
- **Auto-complete:** Enable so incomplete issues roll to the next cycle automatically

## Initiatives (Portfolio View)

When managing multiple CCC projects, use Linear Initiatives to group related milestones:

- One initiative per strategic theme or time-bound goal
- Link projects (not individual issues) to initiatives
- Post initiative-level status updates for portfolio visibility
- Review initiative health during Monday planning

## Customer Feedback Routing

External feedback enters the CCC funnel through Linear:

1. Route feedback to Linear Inbox (via email integration, direct creation, or Vercel comment sync)
2. Triage during daily inbox review
3. Apply `source:*` origin label to track where feedback came from
4. Process through Stage 0 intake (verb-first title, type label, brief description)

## Template Selection

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

## Estimate-to-Execution-Mode Mapping

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

## Triage Intelligence

Linear's Triage Intelligence runs in suggestions-only mode -- it never auto-applies changes. The agent should review suggestions before accepting, override if CCC methodology requires different labels, and always defer priority to the human (human-owned field). Always verify `type:*` label is present after triage.

## Agent Delegation Patterns

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
- Status transitions follow the ownership table — the delegate does not override assignee ownership rules
