---
name: agent-session-intents
description: |
  Parse and route intents from Linear @mention comments in AgentSessionEvent
  webhook payloads. Defines the intent schema, parsing rules, routing table
  (review, implement, gate2, dispatch), and integration points for Tembo and
  Claude Code consumers. Use when building or extending webhook handlers that
  respond to agent @mentions in Linear issue comments.
  Trigger with phrases like "agent session webhook", "parse @mention intent",
  "route agent intent", "webhook intent parsing", "linear agent dispatch",
  "implement intent handler", "review intent handler", "agent-session event".
---

# Agent Session Intents

Agent Session Intents is the intent parsing and routing layer for Linear's `AgentSessionEvent` webhook. When a user @mentions an agent in a Linear issue comment, Linear fires an `AgentSessionEvent` to the configured webhook endpoint. This skill defines how to extract structured intents from those comments and route them to the correct handler.

This is a **definition layer** — CCC is a plugin, not a runtime. The intent schema and routing rules defined here are consumed by webhook handlers in deployment environments (n8n workflows, Vercel serverless functions, or direct API integrations).

## The Problem

Linear's `AgentSessionEvent` payload contains a `delegateId` (which agent was @mentioned) and the comment body, but no structured intent. The comment is free-form text like:

```
@Claude please review CIA-234
@Claude implement this
@Claude gate2 check on CIA-456
```

Without intent parsing, the webhook handler must guess what the user wants. This leads to:

- Misrouted actions (implementation triggered when review was intended)
- Ignored comments (handler doesn't recognize the intent)
- Brittle string matching scattered across handler code

This skill centralizes the parsing logic so all handlers consume the same structured intent format.

## AgentSessionEvent Payload

Linear fires `AgentSessionEvent` when an agent is @mentioned in a comment. The webhook payload structure:

```json
{
  "action": "create",
  "type": "AgentSession",
  "data": {
    "id": "session-uuid",
    "delegateId": "dd0797a4-3dd2-4ae9-add5-36a691825dc4",
    "issueId": "issue-uuid",
    "commentId": "comment-uuid",
    "comment": {
      "body": "@Claude review CIA-234",
      "userId": "user-uuid",
      "createdAt": "2026-02-18T10:00:00.000Z"
    }
  },
  "url": "https://linear.app/claudian/issue/CIA-234#comment-uuid",
  "organizationId": "org-uuid"
}
```

**Key fields for intent parsing:**

| Field | Path | Purpose |
|-------|------|---------|
| Comment body | `data.comment.body` | Free-text input to parse for intent |
| Delegate ID | `data.delegateId` | Which agent was @mentioned (must match our agent ID) |
| Issue ID | `data.issueId` | The Linear issue the comment belongs to |
| Comment ID | `data.commentId` | Source comment for audit trail |
| User ID | `data.comment.userId` | Who triggered the intent (for permission checks) |
| Organization ID | `organizationId` | Workspace scoping |

**Our agent ID:** `dd0797a4-3dd2-4ae9-add5-36a691825dc4` (Claude agent in Claudian workspace).

## Intent Schema

Every parsed intent conforms to this structure:

```typescript
interface ParsedIntent {
  /** The classified intent type */
  intent: "review" | "implement" | "gate2" | "dispatch" | "unknown";

  /** The target Linear issue identifier (e.g., "CIA-234") */
  target_issue: string;

  /** The comment ID that triggered this intent (audit trail) */
  source_comment: string;

  /** Intent-specific parameters extracted from the comment */
  parameters: {
    /** Raw comment body for fallback processing */
    raw_body: string;
    /** User ID of the person who triggered the intent */
    triggered_by: string;
    /** Explicit flags or modifiers (e.g., "urgent", "skip-tests") */
    flags: string[];
    /** For dispatch: target agent (tembo, claude-code) */
    dispatch_target?: string;
    /** For review: review type (adversarial, quick, security) */
    review_type?: string;
  };

  /** Parsing metadata */
  meta: {
    /** ISO 8601 timestamp of when parsing occurred */
    parsed_at: string;
    /** Confidence score (1.0 = exact keyword match, 0.5 = fuzzy) */
    confidence: number;
    /** Which parsing rule matched */
    matched_rule: string;
  };
}
```

**Field reference:**

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `intent` | enum | Yes | One of: `review`, `implement`, `gate2`, `dispatch`, `unknown` |
| `target_issue` | string | Yes | Linear issue key extracted from comment or inferred from context |
| `source_comment` | string | Yes | Linear comment UUID for audit trail and deduplication |
| `parameters` | object | Yes | Intent-specific parameters |
| `parameters.raw_body` | string | Yes | Original comment text |
| `parameters.triggered_by` | string | Yes | User ID who wrote the comment |
| `parameters.flags` | string[] | Yes | Modifier flags (empty array if none) |
| `parameters.dispatch_target` | string | No | Only for `dispatch` intent |
| `parameters.review_type` | string | No | Only for `review` intent |
| `meta.parsed_at` | ISO 8601 | Yes | Parsing timestamp |
| `meta.confidence` | number | Yes | 0.0-1.0 confidence score |
| `meta.matched_rule` | string | Yes | Rule identifier for debugging |

## Intent Types

### `review` — Trigger Adversarial Review

Triggers a code review or spec review via the code-reviewer agent (or a specific reviewer persona).

**Keyword patterns:**

| Pattern | Confidence | Example |
|---------|:----------:|---------|
| `review CIA-XXX` | 1.0 | `@Claude review CIA-234` |
| `review this` | 0.9 | `@Claude review this` (infers issue from context) |
| `adversarial review` | 1.0 | `@Claude adversarial review CIA-234` |
| `security review` | 1.0 | `@Claude security review CIA-234` |
| `check this spec` | 0.7 | `@Claude check this spec` |

**Routing:** `review` intent → reviewer agent (or persona-specific reviewer if `review_type` is set).

**Parameters extracted:**
- `review_type`: `adversarial` | `quick` | `security` | `performance` | `architecture` | `ux` (defaults to `adversarial`)
- `target_issue`: Extracted from `CIA-XXX` pattern in comment, or inferred from the issue the comment is on

### `implement` — Trigger Implementation

Triggers implementation of an issue via the implementer agent, dispatched to either Claude Code (interactive) or Tembo (background).

**Keyword patterns:**

| Pattern | Confidence | Example |
|---------|:----------:|---------|
| `implement CIA-XXX` | 1.0 | `@Claude implement CIA-234` |
| `implement this` | 0.9 | `@Claude implement this` |
| `build this` | 0.8 | `@Claude build this` |
| `go CIA-XXX` | 0.9 | `@Claude go CIA-234` |
| `start implementing` | 0.8 | `@Claude start implementing` |

**Routing:** `implement` intent → implementer agent. Dispatch target determined by execution mode:
- `exec:quick` or `exec:tdd` with Tembo-ready repo → Tembo dispatch
- `exec:pair` or `exec:checkpoint` → Claude Code interactive session
- Default → Claude Code interactive session

**Parameters extracted:**
- `dispatch_target`: `tembo` | `claude-code` (auto-determined or explicit)
- `target_issue`: Extracted from `CIA-XXX` pattern or inferred from context

### `gate2` — Trigger Gate 2 Review Check

Checks whether an issue has passed Gate 2 (adversarial review acceptance). Used as a pre-implementation guard.

**Keyword patterns:**

| Pattern | Confidence | Example |
|---------|:----------:|---------|
| `gate2 CIA-XXX` | 1.0 | `@Claude gate2 CIA-234` |
| `gate 2 check` | 1.0 | `@Claude gate 2 check CIA-234` |
| `review gate` | 0.8 | `@Claude review gate CIA-234` |
| `gate check` | 0.7 | `@Claude gate check` |

**Routing:** `gate2` intent → gate 2 handler (checks spec:review label, review findings, and approval status).

**Parameters extracted:**
- `target_issue`: Required — must specify which issue to check

### `dispatch` — Explicit Dispatch to Agent

Explicitly dispatches a task to a named agent (Tembo, Claude Code, or another configured agent). This is the generic dispatch intent — use `implement` or `review` for specific workflows.

**Keyword patterns:**

| Pattern | Confidence | Example |
|---------|:----------:|---------|
| `dispatch to tembo` | 1.0 | `@Claude dispatch CIA-234 to tembo` |
| `send to tembo` | 1.0 | `@Claude send CIA-234 to tembo` |
| `dispatch to claude-code` | 1.0 | `@Claude dispatch CIA-234 to claude-code` |
| `delegate CIA-XXX` | 0.8 | `@Claude delegate CIA-234` |

**Routing:** `dispatch` intent → target agent specified in parameters.

**Parameters extracted:**
- `dispatch_target`: Target agent name (required for dispatch intent)
- `target_issue`: Issue to dispatch

### `unknown` — Unrecognized Intent

Returned when the comment body doesn't match any known intent pattern. The handler should respond with a help message listing available intents.

## Intent Parsing Rules

Parsing follows a priority-ordered rule chain. The first matching rule wins.

### Rule Chain

```
1. Exact keyword match (confidence: 1.0)
   - "review", "implement", "gate2", "dispatch"
   - Case-insensitive, must appear as a distinct word

2. Synonym match (confidence: 0.8-0.9)
   - "build" → implement, "check" → gate2, "send" → dispatch
   - Context-dependent disambiguation

3. Issue ID extraction (parallel to intent matching)
   - Regex: /CIA-\d+/i
   - Falls back to the issue the comment is attached to

4. Flag extraction (parallel to intent matching)
   - "urgent", "skip-tests", "quick", "thorough"
   - Extracted as parameters.flags[]

5. Default (confidence: 0.0)
   - No match → intent: "unknown"
```

### Parsing Algorithm

```
function parseIntent(event: AgentSessionEvent): ParsedIntent {
  body = event.data.comment.body

  // Strip @mention prefix
  cleanBody = body.replace(/@\w+\s*/, "").trim()

  // Extract issue ID (if present in body)
  issueMatch = cleanBody.match(/CIA-\d+/i)
  targetIssue = issueMatch ? issueMatch[0] : resolveFromContext(event.data.issueId)

  // Extract flags
  flags = extractFlags(cleanBody)

  // Match intent (priority order)
  if matchesReview(cleanBody):
    return { intent: "review", target_issue: targetIssue, ... }
  if matchesImplement(cleanBody):
    return { intent: "implement", target_issue: targetIssue, ... }
  if matchesGate2(cleanBody):
    return { intent: "gate2", target_issue: targetIssue, ... }
  if matchesDispatch(cleanBody):
    return { intent: "dispatch", target_issue: targetIssue, ... }

  return { intent: "unknown", target_issue: targetIssue, ... }
}
```

### Issue Resolution

When the comment body doesn't contain an explicit `CIA-XXX` reference:

1. **Check the comment's parent issue.** The `data.issueId` field tells us which issue the comment is on. Resolve the issue key via Linear API.
2. **Use the parent issue as `target_issue`.** This handles `@Claude review this` — the "this" refers to the issue the comment is on.
3. **If no issue can be resolved**, return an error (see Error Handling below).

## Routing Table

The routing table maps parsed intents to handler agents and dispatch surfaces.

| Intent | Handler Agent | Dispatch Surface | Pre-conditions |
|--------|--------------|-----------------|----------------|
| `review` | reviewer (or persona) | Claude Code interactive | Issue has spec:ready or spec:review label |
| `review` (security) | reviewer-security-skeptic | Claude Code interactive | Same as above |
| `review` (performance) | reviewer-performance-pragmatist | Claude Code interactive | Same as above |
| `review` (architecture) | reviewer-architectural-purist | Claude Code interactive | Same as above |
| `review` (ux) | reviewer-ux-advocate | Claude Code interactive | Same as above |
| `implement` | implementer | Tembo (if eligible) or Claude Code | Issue has spec:ready + gate2 passed |
| `gate2` | gate2-handler | Inline response (comment) | Issue exists |
| `dispatch` | named agent | Per dispatch_target | Varies by target |
| `unknown` | none | Help response (comment) | None |

### Tembo Eligibility for `implement`

The `implement` intent routes to Tembo only when ALL conditions are met:

1. Issue has `exec:quick` or `exec:tdd` label
2. Target repo has a `tembo.md` file
3. Issue is not a spike (`type:spike`)
4. Spec is not in draft (`spec:draft`)
5. Gate 2 has been passed (spec:review label present, review findings addressed)

If any condition fails, route to Claude Code interactive session instead.

### Handler Response Contract

Each handler must:

1. **Post a Linear comment** acknowledging receipt: `"Intent received: {intent} for {target_issue}. Processing..."`
2. **Validate pre-conditions** before executing
3. **Execute the action** (review, implement, gate check, dispatch)
4. **Post a completion comment** with results or errors
5. **Update issue labels/status** as appropriate (e.g., add `spec:review` after review starts)

## Integration Points

### Webhook Endpoint (n8n or Vercel)

The webhook receiver is external to CCC. It:

1. Receives the `AgentSessionEvent` POST from Linear
2. Validates the webhook signature
3. Calls the intent parser (logic defined in this skill)
4. Routes to the appropriate handler based on the parsed intent

**Current deployment:** n8n workflow at `cianos.app.n8n.cloud` (see CIA-553 for Tembo dispatch wiring).

### Tembo Integration

For `implement` intents routed to Tembo:

1. Intent parser extracts `target_issue` and resolves issue details from Linear API
2. Handler constructs a Tembo dispatch prompt using the Tembo Dispatch Prompt Template v1 (see `skills/tembo-dispatch/SKILL.md`)
3. Handler calls `mcp__tembo__create_task` (or delegates via Linear assignee)
4. Handler posts a comment with the Tembo task link

### Claude Code Integration

For intents routed to Claude Code interactive sessions:

1. Intent parser extracts `target_issue` and parameters
2. Handler prepares a session prompt (equivalent to `/ccc:go` or `/ccc:review`)
3. Handler creates a Claude Code session (via API or manual handoff)
4. Handler posts a comment indicating a session has been initiated

**Note:** Claude Code session creation from a webhook is not yet automated (requires CIA-553 Tembo dispatch wiring). Current flow: webhook posts a comment with the structured intent, human launches the session manually.

### Linear API Integration

All handlers interact with Linear for:

- **Reading:** Issue details, labels, spec status, review findings
- **Writing:** Comments (acknowledgment, results, errors), label updates, status transitions
- **Webhook validation:** Signature verification using the webhook signing secret

## Error Handling

### Malformed @Mentions

| Error Case | Detection | Response |
|------------|-----------|----------|
| Empty body after @mention strip | `cleanBody.length === 0` | Post comment: "I received your mention but couldn't parse an intent. Try: `@Claude review CIA-XXX` or `@Claude implement CIA-XXX`" |
| Unrecognized intent keyword | `intent === "unknown"` | Post help comment listing available intents |
| Multiple conflicting intents | Two or more intent keywords in body | Use first match (priority order), log warning |
| No issue ID and no parent context | `target_issue` is null | Post error: "Could not determine target issue. Please specify: `@Claude review CIA-XXX`" |

### Permission and Authorization

| Check | Rule | Failure Response |
|-------|------|-----------------|
| Delegate ID matches our agent | `delegateId === "dd0797a4-..."` | Silently ignore (not our event) |
| User is a workspace member | Verify `userId` in org | Reject with "Unauthorized: workspace members only" |
| User has permission for action | Check user role vs. action type | Reject with specific permission error |
| Issue exists | Linear API lookup | Reject with "Issue not found: {id}" |
| Issue is in correct state | Label/status check | Reject with state requirement (e.g., "Issue must have spec:ready label for review") |

### Rate Limiting

- **Deduplication:** Track `commentId` to prevent processing the same comment twice (webhook retries)
- **Cooldown:** Minimum 30 seconds between actions on the same issue (prevents spam)
- **Budget:** Tembo dispatch respects credit limits (see `skills/tembo-dispatch/SKILL.md`)

### Webhook Retry Handling

Linear retries failed webhooks with exponential backoff. Handlers must be idempotent:

1. Check if `commentId` has already been processed (store in ephemeral state or check for existing response comment)
2. If already processed, return 200 OK without re-executing
3. If not processed, execute normally

## Anti-Patterns

**Parsing intents in handler code.** Every handler that does its own string matching will diverge. Use this centralized schema. One parser, many handlers.

**Guessing intent from context.** If the comment doesn't clearly match a known intent, return `unknown` with a help message. Don't try to infer "they probably meant implement" from ambiguous text.

**Skipping permission checks.** Even though Linear's @mention is workspace-scoped, validate that the user has appropriate permissions for the action. A junior team member should not be able to trigger `implement` on a spec that hasn't passed review.

**Processing duplicate webhooks.** Linear retries on 5xx. Without deduplication, the same action fires multiple times. Always track `commentId`.

**Hardcoding agent IDs.** Use the agent ID from configuration, not inline strings. Agent IDs change when OAuth tokens are rotated.

## Examples

### Example 1: Review Intent

**Comment:** `@Claude review CIA-234`

**Parsed intent:**
```json
{
  "intent": "review",
  "target_issue": "CIA-234",
  "source_comment": "comment-uuid-abc",
  "parameters": {
    "raw_body": "@Claude review CIA-234",
    "triggered_by": "user-uuid-xyz",
    "flags": [],
    "review_type": "adversarial"
  },
  "meta": {
    "parsed_at": "2026-02-18T10:00:01.000Z",
    "confidence": 1.0,
    "matched_rule": "exact_keyword:review"
  }
}
```

**Route:** reviewer agent via Claude Code interactive session.

### Example 2: Implement with Tembo

**Comment:** `@Claude implement CIA-345`

**Parsed intent:**
```json
{
  "intent": "implement",
  "target_issue": "CIA-345",
  "source_comment": "comment-uuid-def",
  "parameters": {
    "raw_body": "@Claude implement CIA-345",
    "triggered_by": "user-uuid-xyz",
    "flags": [],
    "dispatch_target": "tembo"
  },
  "meta": {
    "parsed_at": "2026-02-18T10:05:00.000Z",
    "confidence": 1.0,
    "matched_rule": "exact_keyword:implement"
  }
}
```

**Route:** implementer agent via Tembo (issue is exec:tdd, repo is Tembo-ready).

### Example 3: Unknown Intent

**Comment:** `@Claude what's the status of CIA-456?`

**Parsed intent:**
```json
{
  "intent": "unknown",
  "target_issue": "CIA-456",
  "source_comment": "comment-uuid-ghi",
  "parameters": {
    "raw_body": "@Claude what's the status of CIA-456?",
    "triggered_by": "user-uuid-xyz",
    "flags": []
  },
  "meta": {
    "parsed_at": "2026-02-18T10:10:00.000Z",
    "confidence": 0.0,
    "matched_rule": "default:unknown"
  }
}
```

**Route:** Post help comment listing available intents.

### Example 4: Gate 2 Check

**Comment:** `@Claude gate2 CIA-234`

**Parsed intent:**
```json
{
  "intent": "gate2",
  "target_issue": "CIA-234",
  "source_comment": "comment-uuid-jkl",
  "parameters": {
    "raw_body": "@Claude gate2 CIA-234",
    "triggered_by": "user-uuid-xyz",
    "flags": []
  },
  "meta": {
    "parsed_at": "2026-02-18T10:15:00.000Z",
    "confidence": 1.0,
    "matched_rule": "exact_keyword:gate2"
  }
}
```

**Route:** Gate 2 handler (inline check, posts comment with gate status).

## Cross-Skill References

- Tembo Dispatch (`skills/tembo-dispatch/SKILL.md`) — Provides the Dispatch Prompt Template v1 used when `implement` intent routes to Tembo. Credit estimation and Tembo-ready repo checks are defined there.
- **issue-lifecycle** skill — Defines issue status transitions triggered by intent handlers (e.g., moving to In Progress after implement, adding spec:review after review starts).
- **adversarial-review** skill — Defines the review taxonomy and process triggered by `review` intents. Review type selection (A-H options) maps to `parameters.review_type`.
- **platform-routing** skill — Decision tree for choosing between Claude Code, Tembo, Cowork, and @mention surfaces. This skill adds the @mention surface's intent layer.
- **execution-modes** skill — Determines whether `implement` routes to Tembo (exec:quick/tdd) or Claude Code (exec:pair/checkpoint). Mode lookup is a pre-condition for implement routing.
- **parallel-dispatch** skill — When multiple `implement` intents arrive for related issues, the parallel dispatch protocol handles coordination and conflict avoidance.
