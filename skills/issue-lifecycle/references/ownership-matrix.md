# Issue Lifecycle Ownership Matrix

Full agent/human permissions matrix for issue and project management actions.

## Core Principle

The agent owns **process and implementation artifacts** (status, labels, specs, estimates). The human owns **business judgement** (priority, deadlines, capacity). Either can create and assign work. Closure follows a rules matrix based on assignee and complexity.

## Ownership Table

| Action | Owner | Rationale |
|--------|-------|-----------|
| Create issue | Either | Agent creates from plans, specs, or discovered work. Human creates ad hoc or from external input. |
| Status to In Progress | Whoever starts work | Agent marks as soon as implementation begins. Human marks for manual work. Never batch -- update immediately when work starts. |
| Status to Done | Agent (auto-close per rules) | Only when: agent is assignee + single PR + merged + deploy green. See closure rules. |
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
