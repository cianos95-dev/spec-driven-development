---
name: mechanism-router
description: |
  Unified entry point for all Linear agent dispatch mechanisms (delegateId, @mention, assignee).
  Detects how dispatch was triggered, extracts or infers intent, validates preconditions,
  and routes to the appropriate handler. Defines the handler registration contract and
  agent selection tree. Source of truth: CIA-575 Unified Agent Dispatch Architecture.
  Use when processing any Linear event that should trigger agent action.
  Trigger with phrases like "mechanism router", "dispatch routing", "agent selection",
  "delegateId handler", "assignee dispatch", "intent routing", "handler registration".
---

# Mechanism Router

The mechanism router is the single entry point between raw Linear events and intent handlers. All three signal sources — delegateId, @mention, and assignee — converge into this router before being dispatched to handlers. It is the runtime consumer of the intent schema defined in the **agent-session-intents** skill.

This skill defines the detection logic, dispatch hierarchy, handler registration contract, and agent selection tree. It is the operational counterpart to agent-session-intents (which defines the schema and parsing rules). Together they form the complete dispatch pipeline from CIA-575.

## Architecture Overview

```
Linear Events
  |
  +-- AgentSessionEvent (webhook) --+-- has comment body --> @mention path
  |                                 +-- no comment body ---> delegateId path
  |
  +-- Poll result (no webhook) ---------> assignee path
  |
  v
[Mechanism Router]
  |
  +-- Detect mechanism (delegateId | mention | assignee)
  +-- Parse or infer intent (comment-based or state-based)
  +-- Validate preconditions
  +-- Select handler + agent
  |
  v
[Intent Handler]
  |
  +-- Execute action
  +-- Post response to Linear
  +-- Update issue state
```

## The Three Mechanisms

Three distinct signal sources can trigger agent action in Linear. Each has different delivery characteristics, fidelity, and automation potential.

| Mechanism | Signal Source | Delivery | Fires AgentSessionEvent? | Intent Source |
|-----------|-------------|----------|:------------------------:|---------------|
| delegateId | `issueUpdate(delegateId)` | Webhook push | Yes | Inferred from issue state |
| @mention | Comment with `@agent` | Webhook push | Yes | Parsed from comment body |
| assignee | Issue assignee field | Poll / native integration | No | Inferred from issue state |

### delegateId — Primary Mechanism

The delegateId is set via `issueUpdate` when a user (or automation) delegates an issue to an agent through Linear's delegate field. This fires an `AgentSessionEvent` webhook **without a comment body**. The agent must infer intent from the issue's current state (labels, status, linked documents, PR status).

**When to use:** Automated dispatch pipelines, template-driven workflows, bulk delegation. The delegateId mechanism is the most reliable for programmatic dispatch because it doesn't require composing a comment.

### @mention — Secondary Mechanism

An @mention in a comment fires an `AgentSessionEvent` **with a comment body**. The agent parses intent from the comment text using keyword matching (see agent-session-intents skill).

**When to use:** Interactive, human-initiated dispatch where the user wants to specify exactly what the agent should do. The comment body provides explicit intent that doesn't require inference.

### assignee — Fallback Mechanism

Setting the issue's assignee field to an agent. This does **not** fire an `AgentSessionEvent` — the agent must discover the assignment via polling or native Linear integration (e.g., Tembo's Linear bot). Intent is inferred from issue state, same as delegateId.

**When to use:** Simple delegation to agents with native Linear integration (Tembo). Also used as a fallback when delegateId is unavailable (e.g., the agent doesn't have app-level OAuth with delegateId support).

## Canonical Dispatch Hierarchy

When multiple mechanisms could apply, the hierarchy determines precedence:

```
delegateId (primary) > @mention (secondary) > assignee (fallback)
```

**Rationale:**

1. **delegateId wins** because it is the most intentional signal — someone explicitly set the delegate field, which is a first-class Linear API concept designed for agent handoff. It also fires a webhook (no polling required) and carries organizational authority.

2. **@mention is secondary** because while it provides explicit intent via the comment body, it is a communication mechanism repurposed for dispatch. The comment may be ambiguous or conversational rather than a clear instruction.

3. **assignee is fallback** because assignment is the least specific signal — it traditionally means "this person is responsible" rather than "this agent should act now." It also requires polling (no webhook), adding latency.

**Conflict resolution:** If a delegateId event and an @mention event arrive for the same issue within a 60-second window, process only the delegateId event (higher precedence). The @mention is likely the user explaining what they want after delegating — the state-based inference from delegateId should match.

## Mechanism Detection

The router determines which mechanism triggered an event using this decision tree:

```
function detectMechanism(event):
  if event.type === "AgentSession":
    if event.data.comment && event.data.comment.body:
      return "mention"
    else:
      return "delegateId"

  if event.source === "poll":
    return "assignee"

  throw UnknownMechanismError(event)
```

**Edge cases:**

- **AgentSessionEvent with empty comment body:** Treat as delegateId (the comment field may be present but with an empty or whitespace-only body).
- **AgentSessionEvent from delegation + simultaneous comment:** If `comment.body` exists and is non-empty, treat as @mention. The comment provides more specific intent than the delegation alone.
- **Poll result with no assignee change:** Ignore — only process when the assignee field changes to our agent ID.

## Handler Registration Contract

Handlers implement the following interface to receive routed intents:

```typescript
interface Handler {
  /** Which intents this handler can process */
  intents: string[];

  /**
   * Validate that preconditions are met before executing.
   * Returns { valid: true } or { valid: false, reason: string }.
   */
  validatePreconditions(intent: ParsedIntent, issue: Issue): ValidationResult;

  /**
   * Execute the handler's primary action.
   * Returns a result object with outcome details.
   */
  execute(intent: ParsedIntent, issue: Issue): HandlerResult;

  /**
   * Post a response to Linear (acknowledgment, results, or errors).
   * Called after execute(), regardless of success or failure.
   */
  respond(intent: ParsedIntent, result: HandlerResult): void;
}

interface ValidationResult {
  valid: boolean;
  reason?: string;
}

interface HandlerResult {
  success: boolean;
  /** Human-readable summary for the Linear comment */
  summary: string;
  /** Structured output data (handler-specific) */
  data?: Record<string, unknown>;
  /** Error details if success is false */
  error?: {
    code: string;
    message: string;
    recoverable: boolean;
  };
}
```

### Handler Lifecycle

1. **Registration:** Handler registers with the router, declaring which intents it handles.
2. **Precondition check:** Router calls `validatePreconditions()` before dispatching. If invalid, router posts the reason as a Linear comment and does not call `execute()`.
3. **Execution:** Router calls `execute()` with the parsed intent and issue data.
4. **Response:** Router calls `respond()` to post results (or errors) back to Linear.
5. **State update:** Handler (or router) updates issue labels/status as appropriate.

### Handler Registration Table

| Handler | Intents | Description |
|---------|---------|-------------|
| review-handler | `review` | Launches adversarial review via reviewer agent personas |
| implement-handler | `implement` | Dispatches to Tembo or Claude Code based on exec mode |
| gate2-handler | `gate2` | Checks Gate 2 review approval status |
| dispatch-handler | `dispatch` | Routes to explicitly named agent |
| status-handler | `status` | Reports current issue state and recent activity |
| expand-handler | `expand` | Enriches issue description with detail |
| help-handler | `help` | Lists available intents with syntax examples |
| close-handler | `close` | Validates and completes issue closure |
| spike-handler | `spike` | Executes research spike workflow |
| spec-author-handler | `spec-author` | Drafts spec via spec-author agent |

## Agent Selection Tree

After intent is parsed and preconditions validated, the router selects which agent should execute the work. This is the decision tree for the `implement` intent (the most complex routing case), derived from CIA-575 section 7.2.

### `implement` Agent Selection

```
implement intent received
  |
  +-- Check exec label
       |
       +-- exec:quick or exec:tdd
       |    |
       |    +-- Is repo Tembo-ready? (has tembo.md + authorized)
       |    |    |
       |    |    +-- Yes --> Tembo
       |    |    +-- No  --> Claude Code (or Cyrus if available)
       |    |
       |    +-- Is issue type:spike?
       |         +-- Yes --> Claude Code (spikes need interactive research)
       |         +-- No  --> Continue to Tembo check above
       |
       +-- exec:pair or exec:checkpoint
       |    |
       |    +-- Claude Code (human-in-loop required)
       |
       +-- exec:swarm
       |    |
       |    +-- Tembo (multi-agent dispatch)
       |
       +-- No exec label
            |
            +-- Claude Code (default, interactive session)
```

### Other Intent Agent Selection

| Intent | Primary Agent | Fallback | Rationale |
|--------|--------------|----------|-----------|
| `review` | Claude (reviewer persona) | — | Review requires CCC methodology knowledge |
| `gate2` | Claude | — | Gate check is a read-only query |
| `dispatch` | Per `dispatch_target` | Claude | Explicit target in parameters |
| `status` | Claude | — | Status is a read-only query |
| `expand` | Claude | — | Needs CCC spec knowledge |
| `help` | Claude | — | Static response |
| `close` | Claude | — | Needs verification + Linear API |
| `spike` | Claude, Tembo | — | Claude for interactive, Tembo for background |
| `spec-author` | Claude (spec-author agent) | — | Needs PR/FAQ methodology |

## Agent x Intent Matrix

The full eligibility matrix from CIA-575 section 7.1. A checkmark indicates the agent is eligible for that intent; the router uses the Agent Selection Tree to pick the primary.

| Intent | Claude | Tembo | Cursor | Copilot | Codex | cto.new | Cyrus |
|--------|:------:|:-----:|:------:|:-------:|:-----:|:-------:|:-----:|
| `review` | Y | — | — | Y (PR only) | — | — | — |
| `implement` | Y | Y | Y | — | Y | Y | Y |
| `gate2` | Y | — | — | — | — | — | — |
| `dispatch` | Y | Y | — | — | — | — | — |
| `status` | Y | — | — | — | — | — | — |
| `expand` | Y | — | — | — | — | — | — |
| `help` | Y | — | — | — | — | — | — |
| `close` | Y | — | — | — | — | — | — |
| `spike` | Y | Y | — | — | — | — | — |
| `spec-author` | Y | — | — | — | — | — | — |
| `unknown` | Y | — | — | — | — | — | — |

**Agent notes:**

- **Claude:** Universal handler. Can process every intent type. Uses CCC methodology, has full Linear MCP access, supports interactive and background modes.
- **Tembo:** Background execution agent. Best for `implement` (exec:quick/tdd) and `spike` (background research). Cannot do interactive review or spec authoring.
- **Cursor:** Implementation only. Receives tasks via IDE integration, not Linear dispatch. Listed for completeness.
- **Copilot:** PR-level review only (auto-triggered on PR creation). Cannot process issue-level intents.
- **Codex:** Implementation only. Receives tasks via CLI dispatch. Background execution similar to Tembo.
- **cto.new:** Architecture review and implementation. Experimental integration.
- **Cyrus:** Implementation fallback. Alternative to Tembo for repos without Tembo configuration.

## Unknown Intent Response Template

When no handler matches (intent is `unknown`), the router posts a help comment to the Linear issue:

```markdown
I received your request but couldn't determine what action to take.

**Available commands:**

| Command | Syntax | Example |
|---------|--------|---------|
| Review | `@Claude review [CIA-XXX]` | `@Claude review CIA-234` |
| Implement | `@Claude implement [CIA-XXX]` | `@Claude implement CIA-345` |
| Gate 2 check | `@Claude gate2 [CIA-XXX]` | `@Claude gate2 CIA-234` |
| Dispatch | `@Claude dispatch [CIA-XXX] to [agent]` | `@Claude dispatch CIA-234 to tembo` |
| Status | `@Claude status [CIA-XXX]` | `@Claude status CIA-234` |
| Expand | `@Claude expand [CIA-XXX]` | `@Claude expand CIA-234` |
| Close | `@Claude close [CIA-XXX]` | `@Claude close CIA-234` |
| Spike | `@Claude spike [CIA-XXX]` | `@Claude spike CIA-234` |
| Draft spec | `@Claude draft spec [CIA-XXX]` | `@Claude draft spec CIA-234` |
| Help | `@Claude help` | `@Claude help` |

**Tip:** You can also delegate an issue to me (set the Delegate field) and I'll infer the right action from the issue's current state.
```

## Error Handling

### Precondition Failures

When `validatePreconditions()` returns `{ valid: false }`, the router posts a comment explaining what's missing:

```markdown
Cannot process **{intent}** for {target_issue}:

{reason}

**Required state:** {expected_state}
**Current state:** {actual_state}

Please update the issue and try again, or use `@Claude help` for available commands.
```

### Handler Execution Failures

When `execute()` returns `{ success: false }`:

- **Recoverable errors** (`error.recoverable: true`): Router retries once after 30 seconds.
- **Non-recoverable errors**: Router posts the error message as a Linear comment and stops.

### Deduplication

The router tracks processed events by `commentId` (for @mention) or `sessionId` (for delegateId) to prevent duplicate processing from webhook retries. Events seen within the last 5 minutes are silently dropped.

## Cross-Skill References

- **agent-session-intents** skill — Defines the `ParsedIntent` v2 schema, keyword patterns, state inference table, and parsing rules consumed by this router. This router is the runtime consumer; agent-session-intents is the definition layer.
- **platform-routing** skill — Decision tree for choosing between Claude Code, Tembo, Cowork, and @mention surfaces. The platform-routing skill's "Agent Dispatch via @mention" section references this router.
- **execution-modes** skill — Maps exec labels to execution strategies. The agent selection tree for `implement` uses exec mode to determine Tembo vs. Claude Code routing.
- **tembo-dispatch** skill — Tembo-specific dispatch prompt template, credit estimation, and repo readiness checks. Called by the implement-handler when Tembo is selected.
- **issue-lifecycle** skill — Defines the status transitions that handlers must perform after execution (e.g., moving to In Progress, adding spec:review label).
- **adversarial-review** skill — Defines the review process and persona selection triggered by the review-handler.
- **CIA-575 architecture document** (Linear) — Source of truth for the unified agent dispatch architecture. This skill is the CCC plugin's encoding of that document.
