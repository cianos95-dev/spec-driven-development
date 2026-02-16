# Issue Content Discipline

Issue comments, descriptions, sub-issues, and resources each serve a distinct purpose. Using the wrong container for content creates clutter and makes issues hard to navigate.

## Where Content Belongs

| Content Type | Container | Why |
|---|---|---|
| Status updates, @mentions, decisions | **Comments** | Comments are a chronological conversation thread. Keep them for communication, not data storage. |
| Evidence tables, audit findings, detailed analysis | **Resources** (documents or linked files) | Rich content belongs in a document. Link from the description. |
| Plans, specs, research from repos | **Resources** (linked to repo files or Linear documents) | Repo artifacts are the source of truth. Resources point to them. |
| New work discovered during implementation | **Sub-issues** | Sub-issues maintain parent-child traceability. Never add scope to the parent issue. |
| Session orchestration for batched work | **Master session plan issue** (parent) | When multiple sessions or sequential issues form a batch, create a parent issue that tracks the overall plan. Sub-issues represent individual sessions or steps. |

## Anti-Patterns

- **Comment dumping**: Do not write evidence tables, credential audits, or spec content as comments. Comments get buried in the thread and are not searchable or linkable.
- **Orphan work items**: Do not track new work discovered during implementation as informal notes. Create sub-issues immediately.
- **Implicit session plans**: When you identify a sequence of sessions (e.g., "Session 1: merge PR, Session 2: add Mailchimp, Session 3: add geo"), create a master plan issue with sub-issues. Do not leave the orchestration implicit in a plan file or conversation.

## Master Session Plan Pattern

When a project phase involves multiple sequential or parallel sessions:

1. **Create a parent issue** titled "Session Plan: [Phase/Feature Name]"
2. **Create sub-issues** for each session, with blocking relationships reflecting the execution order
3. **Update the parent description** with the overall plan, linking to sub-issues
4. **As sessions complete**, close sub-issues with evidence and update the parent with progress notes
5. **Close the parent** when all sub-issues are complete

This pattern replaces ad-hoc session planning in plan files or conversation context, making the plan visible and trackable in the ~~project-tracker~~.

## Scope Limitation Handoff Protocol

When the agent encounters an action it cannot perform due to OAuth scope limitations, API restrictions, or ownership rules that require human execution, follow this protocol instead of silently skipping the action:

### When This Applies

- API operations requiring scopes the agent token does not have (e.g., creating initiatives, modifying workspace settings)
- Actions explicitly owned by humans per the ownership table (e.g., setting priority, assigning to cycles)
- Platform operations that require UI interaction (e.g., enabling integrations, configuring webhooks)
- Any destructive or irreversible action the agent is not authorized to perform

### The Handoff Pattern

1. **Output the exact content needed.** Write the complete text, configuration, or values the human needs to enter. Do not summarize or abbreviate -- provide copy-paste-ready content.
2. **State the specific action required.** Name the platform, the UI location, and the exact steps (e.g., "In Linear > Settings > Initiatives > Create New").
3. **Document what was output.** Add a comment to the relevant ~~project-tracker~~ issue recording that a handoff was made, what content was provided, and what action the human needs to take.
4. **Do not block on completion.** Continue with other tasks. The handoff is asynchronous -- the human will complete it when they can.

### Example

```
## Scope Limitation Handoff

**Action needed:** Create a Linear initiative (requires OAuth scope `initiative:read/write` which the agent token does not have)

**Where:** Linear > Initiatives > Create New

**Content to enter:**
- Name: [exact name]
- Status: Active
- Owner: [person]
- Description: [exact text]
- Projects linked: [project names]

**Documented on:** [issue ID] -- comment added with handoff details
```

This pattern ensures no work is lost when the agent hits a capability boundary. The human receives a complete, actionable handoff rather than a vague request.
