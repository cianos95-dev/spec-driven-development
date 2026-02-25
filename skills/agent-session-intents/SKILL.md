---
name: agent-session-intents
description: |
  Parse and route intents from Linear agent dispatch events — @mention comments,
  delegateId handoffs, and assignee-based triggers. Defines the v2 intent schema
  (with mechanism detection, trigger block, and issue-state inference), parsing rules,
  routing table (review, implement, gate2, dispatch, status, expand, help, close,
  spike, spec-author), and integration points for Factory and Claude Code consumers.
  Use when building or extending webhook handlers that respond to any Linear agent
  dispatch mechanism. Works with the mechanism-router skill for unified entry-point routing.
  Trigger with phrases like "agent session webhook", "parse @mention intent",
  "route agent intent", "webhook intent parsing", "linear agent dispatch",
  "implement intent handler", "review intent handler", "agent-session event",
  "mechanism detection", "delegateId intent", "assignee dispatch", "state-based inference".
compatibility:
  surfaces: [code, cowork, desktop]
  tier: universal
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
  /** The classified intent type (v2: extended with status, expand, help, close, spike, spec-author) */
  intent:
    | "review" | "implement" | "gate2" | "dispatch"
    | "close" | "spike" | "spec-author"
    | "status" | "expand" | "help"
    | "unknown";

  /** The target Linear issue identifier (e.g., "CIA-234") */
  target_issue: string;

  /** The comment ID that triggered this intent (null for delegateId/assignee triggers) */
  source_comment: string | null;

  /** How dispatch was triggered — added in v2 for CIA-580 mechanism router */
  trigger: {
    /** Which dispatch mechanism fired */
    mechanism: "delegateId" | "mention" | "assignee";
    /** User or system that initiated the dispatch */
    initiated_by: string;
    /** The delegate ID from the AgentSessionEvent (only for delegateId mechanism) */
    delegate_id?: string;
    /** Whether this was an automated/template-dispatched trigger vs. human-initiated */
    auto: boolean;
  };

  /** Intent-specific parameters extracted from the comment or inferred from state */
  parameters: {
    /** Raw comment body for fallback processing (null for delegateId/assignee triggers) */
    raw_body: string | null;
    /** User ID of the person who triggered the intent */
    triggered_by: string;
    /** Explicit flags or modifiers (e.g., "urgent", "skip-tests") */
    flags: string[];
    /** For dispatch: target agent (factory, claude-code, amp) */
    dispatch_target?: string;
    /** For review: review type (adversarial, quick, security) */
    review_type?: string;
    /** Issue state snapshot used for state-based inference (populated when no comment body) */
    issue_state?: {
      /** Current issue status (e.g., "In Progress", "Todo") */
      status: string;
      /** All labels on the issue */
      labels: string[];
      /** Spec lifecycle label if present (e.g., "spec:draft", "spec:ready") */
      spec_label: string | null;
      /** Execution mode label if present (e.g., "exec:tdd", "exec:quick") */
      exec_label: string | null;
      /** Type label if present (e.g., "type:feature", "type:spike") */
      type_label: string | null;
      /** Whether unresolved adversarial review findings exist */
      has_review_findings: boolean;
      /** Whether a merged PR is linked to this issue */
      has_merged_pr: boolean;
      /** Whether a spec document is linked to this issue */
      has_linked_spec: boolean;
    };
  };

  /** Parsing metadata */
  meta: {
    /** ISO 8601 timestamp of when parsing occurred */
    parsed_at: string;
    /** Confidence score (1.0 = exact keyword match, 0.5 = fuzzy, 0.0 = no match) */
    confidence: number;
    /** Which parsing rule matched (prefixed with "state:" for state-based inference) */
    matched_rule: string;
  };
}
```

**Field reference:**

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `intent` | enum | Yes | One of: `review`, `implement`, `gate2`, `dispatch`, `close`, `spike`, `spec-author`, `status`, `expand`, `help`, `unknown` |
| `target_issue` | string | Yes | Linear issue key extracted from comment or inferred from context |
| `source_comment` | string \| null | Yes | Linear comment UUID for audit trail; null for delegateId/assignee triggers |
| `trigger` | object | Yes | Dispatch mechanism metadata (added in v2) |
| `trigger.mechanism` | enum | Yes | How dispatch was triggered: `delegateId`, `mention`, or `assignee` |
| `trigger.initiated_by` | string | Yes | User or system that initiated the dispatch |
| `trigger.delegate_id` | string | No | The delegate ID from the AgentSessionEvent (delegateId mechanism only) |
| `trigger.auto` | boolean | Yes | Whether this was an automated/template-dispatched trigger |
| `parameters` | object | Yes | Intent-specific parameters |
| `parameters.raw_body` | string \| null | Yes | Original comment text; null for delegateId/assignee triggers |
| `parameters.triggered_by` | string | Yes | User ID who wrote the comment or initiated the dispatch |
| `parameters.flags` | string[] | Yes | Modifier flags (empty array if none) |
| `parameters.dispatch_target` | string | No | Only for `dispatch` intent |
| `parameters.review_type` | string | No | Only for `review` intent |
| `parameters.issue_state` | object | No | Issue state snapshot for state-based inference; populated when no comment body |
| `parameters.issue_state.status` | string | — | Current issue status (e.g., "In Progress") |
| `parameters.issue_state.labels` | string[] | — | All labels on the issue |
| `parameters.issue_state.spec_label` | string \| null | — | Spec lifecycle label if present |
| `parameters.issue_state.exec_label` | string \| null | — | Execution mode label if present |
| `parameters.issue_state.type_label` | string \| null | — | Type label if present |
| `parameters.issue_state.has_review_findings` | boolean | — | Whether unresolved review findings exist |
| `parameters.issue_state.has_merged_pr` | boolean | — | Whether a merged PR is linked |
| `parameters.issue_state.has_linked_spec` | boolean | — | Whether a spec document is linked |
| `meta.parsed_at` | ISO 8601 | Yes | Parsing timestamp |
| `meta.confidence` | number | Yes | 0.0-1.0 confidence score |
| `meta.matched_rule` | string | Yes | Rule identifier; prefixed with `state:` for state-based inference |

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

Triggers implementation of an issue via the implementer agent, dispatched to either Claude Code (interactive) or Factory (background).

**Keyword patterns:**

| Pattern | Confidence | Example |
|---------|:----------:|---------|
| `implement CIA-XXX` | 1.0 | `@Claude implement CIA-234` |
| `implement this` | 0.9 | `@Claude implement this` |
| `build this` | 0.8 | `@Claude build this` |
| `go CIA-XXX` | 0.9 | `@Claude go CIA-234` |
| `start implementing` | 0.8 | `@Claude start implementing` |

**Routing:** `implement` intent → implementer agent. Dispatch target determined by execution mode:
- `exec:quick` or `exec:tdd` with Factory Cloud Template → Factory dispatch (native Linear delegation)
- `exec:pair` or `exec:checkpoint` → Claude Code interactive session
- Default → Claude Code interactive session

**Parameters extracted:**
- `dispatch_target`: `factory` | `claude-code` | `amp` (auto-determined or explicit)
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

Explicitly dispatches a task to a named agent (Factory, Claude Code, Amp, or another configured agent). This is the generic dispatch intent — use `implement` or `review` for specific workflows.

**Keyword patterns:**

| Pattern | Confidence | Example |
|---------|:----------:|---------|
| `dispatch to factory` | 1.0 | `@Claude dispatch CIA-234 to factory` |
| `send to factory` | 1.0 | `@Claude send CIA-234 to factory` |
| `dispatch to claude-code` | 1.0 | `@Claude dispatch CIA-234 to claude-code` |
| `dispatch to amp` | 1.0 | `@Claude dispatch CIA-234 to amp` |
| `delegate CIA-XXX` | 0.8 | `@Claude delegate CIA-234` |

**Routing:** `dispatch` intent → target agent specified in parameters.

**Parameters extracted:**
- `dispatch_target`: Target agent name (required for dispatch intent)
- `target_issue`: Issue to dispatch

### `unknown` — Unrecognized Intent

Returned when the comment body doesn't match any known intent pattern. The handler should respond with a help message listing available intents.

### `status` — Issue Status Report

Reports current status, blockers, and recent activity for an issue. Already live via the alteri webhook (PR #402 merged).

**Keyword patterns:**

| Pattern | Confidence | Example |
|---------|:----------:|---------|
| `status CIA-XXX` | 1.0 | `@Claude status CIA-234` |
| `what's happening` | 0.8 | `@Claude what's happening with CIA-234?` |
| `update on` | 0.8 | `@Claude update on CIA-234` |
| `where are we` | 0.7 | `@Claude where are we on this?` |

**Routing:** `status` intent -> status handler (posts comment with current issue state, assignee, blockers, recent activity).

**Pre-conditions:** None. Any issue can be queried for status.

**Parameters extracted:**
- `target_issue`: Extracted from `CIA-XXX` pattern or inferred from context

### `expand` — Flesh Out Issue Details

Expands an issue's description with additional detail, acceptance criteria, or technical breakdown. Already live via the alteri webhook (PR #402 merged).

**Keyword patterns:**

| Pattern | Confidence | Example |
|---------|:----------:|---------|
| `expand CIA-XXX` | 1.0 | `@Claude expand CIA-234` |
| `flesh out` | 0.9 | `@Claude flesh out this issue` |
| `add detail` | 0.8 | `@Claude add detail to CIA-234` |
| `elaborate` | 0.8 | `@Claude elaborate on the requirements` |

**Routing:** `expand` intent -> expand handler (reads current description, enriches with AC, technical notes, edge cases).

**Pre-conditions:** None. Works on any issue in any state.

**Parameters extracted:**
- `target_issue`: Extracted from `CIA-XXX` pattern or inferred from context

### `help` — List Available Commands

Returns a help message listing all available intents and their syntax. Already live via the alteri webhook (PR #402 merged).

**Keyword patterns:**

| Pattern | Confidence | Example |
|---------|:----------:|---------|
| `help` | 1.0 | `@Claude help` |
| `what can you do` | 0.9 | `@Claude what can you do?` |
| `commands` | 0.8 | `@Claude commands` |
| `?` | 0.7 | `@Claude ?` |

**Routing:** `help` intent -> help response (posts comment with available intent syntax and examples).

**Pre-conditions:** None.

**Parameters extracted:** None required.

### `close` — Close/Complete an Issue

Marks an issue as Done after validating completion criteria (merged PR, deploy green). Maps to the state-based inference from CIA-575: when an issue has a merged PR and deployment is verified, the close intent can be triggered explicitly or inferred.

**Keyword patterns:**

| Pattern | Confidence | Example |
|---------|:----------:|---------|
| `close CIA-XXX` | 1.0 | `@Claude close CIA-234` |
| `mark done` | 0.9 | `@Claude mark CIA-234 done` |
| `complete this` | 0.8 | `@Claude complete this` |
| `ship it` | 0.8 | `@Claude ship it` |

**Routing:** `close` intent -> close handler (validates merged PR + deploy green, transitions status to Done, posts closure comment with evidence).

**Pre-conditions:**
- Issue must have a merged PR linked (`has_merged_pr: true`)
- Deployment must be verified (CI green)
- Follows DONE = MERGED rule from CCC methodology

**Parameters extracted:**
- `target_issue`: Issue to close

### `spike` — Trigger Research Spike

Launches a research spike for the target issue. Maps to `type:spike` issues from CIA-575 state-based inference.

**Keyword patterns:**

| Pattern | Confidence | Example |
|---------|:----------:|---------|
| `spike CIA-XXX` | 1.0 | `@Claude spike CIA-234` |
| `research CIA-XXX` | 0.9 | `@Claude research CIA-234` |
| `investigate` | 0.8 | `@Claude investigate this` |
| `explore options` | 0.7 | `@Claude explore options for CIA-234` |

**Routing:** `spike` intent -> spike handler (executes research per the spike execution mode, updates issue with GO/NO-GO recommendation).

**Pre-conditions:**
- Issue should have `type:spike` label (handler will warn if missing)

**Parameters extracted:**
- `target_issue`: Issue to research
- `flags`: May include research dimensions (e.g., "technical-feasibility", "cost-analysis")

### `spec-author` — Draft a Spec

Initiates spec authoring for a feature issue. Maps to `spec:draft` + `type:feature` state from CIA-575 state-based inference.

**Keyword patterns:**

| Pattern | Confidence | Example |
|---------|:----------:|---------|
| `draft spec CIA-XXX` | 1.0 | `@Claude draft spec CIA-234` |
| `write spec` | 0.9 | `@Claude write spec for CIA-234` |
| `author spec` | 0.9 | `@Claude author spec` |
| `spec this` | 0.8 | `@Claude spec this` |

**Routing:** `spec-author` intent -> spec-author agent (drafts spec per PR/FAQ methodology, attaches to issue as Linear document).

**Pre-conditions:**
- Issue should have `spec:draft` label (handler will add it if missing)
- Issue should have a type label (`type:feature`, `type:chore`, etc.)

**Parameters extracted:**
- `target_issue`: Issue to draft spec for

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

## State-Based Intent Inference

When no comment text is available (delegateId or assignee triggers), intent must be inferred from the issue's current state. This is the key CIA-580 addition: the mechanism router fetches issue metadata from the Linear API and applies the inference table below.

### State Inference Table

| Issue State | Inferred Intent | Confidence | Matched Rule |
|-------------|----------------|:----------:|--------------|
| `spec:draft` + `type:feature` | spec-author | 0.9 | state:spec_draft_feature |
| `spec:ready` + no review findings | review | 0.9 | state:spec_ready_no_review |
| `spec:review` + findings exist + unresolved | gate2 | 0.9 | state:spec_review_findings |
| `spec:implementing` + `exec:*` + AC defined | implement | 0.9 | state:spec_implementing |
| Merged PR + deploy green + `spec:implementing` | close | 0.8 | state:merged_pr_deployed |
| `type:spike` | spike | 0.9 | state:type_spike |
| None match | unknown | 0.0 | state:no_match |

**Confidence rationale:** State-based rules use 0.8-0.9 confidence (not 1.0) because the intent is inferred, not explicitly stated. The 0.1 gap acknowledges that the user might have intended something else. The `close` intent gets 0.8 (lower than others) because deployment verification is an external check that may be stale.

### Unified Parse Flow

The mechanism router unifies comment-based and state-based parsing into a single flow:

```
function parseUnifiedIntent(event):
  if event has comment body:
    mechanism = "mention"
    -> Use existing comment-based parser (above)
    -> Set trigger.mechanism = "mention", trigger.auto = false

  if event is AgentSessionEvent without comment:
    mechanism = "delegateId"
    -> Fetch issue state from Linear API
    -> Apply state inference table
    -> Set trigger.mechanism = "delegateId", trigger.auto = (check if template-dispatched)

  if event is poll result (no webhook):
    mechanism = "assignee"
    -> Fetch issue state (same as delegateId)
    -> Apply state inference table
    -> Set trigger.mechanism = "assignee", trigger.auto = false

  -> Return ParsedIntent with trigger block populated
```

### State Fetch Requirements

When applying state-based inference, the following data must be fetched from the Linear API:

1. **Issue labels** — all labels on the issue (for spec, exec, type label extraction)
2. **Issue status** — current workflow state
3. **Review findings** — check for linked review comments with unresolved findings
4. **Linked PRs** — check for merged PRs via GitHub integration
5. **Linked documents** — check for spec documents attached to the issue

This data populates the `parameters.issue_state` block in the `ParsedIntent` schema, providing full context for the handler even when there is no comment body to parse.

### Disambiguation

When multiple state rules could match (e.g., an issue has both `spec:implementing` and a merged PR), apply in table order — the first match wins. The table is ordered by specificity: later rules (like `type:spike`) are more general and should only match when more specific rules don't.

## Routing Table

The routing table maps parsed intents to handler agents, dispatch surfaces, and eligible agents per CIA-575 section 7.1.

| Intent | Handler Agent | Dispatch Surface | Pre-conditions | Eligible Agents |
|--------|--------------|-----------------|----------------|-----------------|
| `review` | reviewer (or persona) | Claude Code interactive | Issue has spec:ready or spec:review label | Claude |
| `review` (security) | reviewer-security-skeptic | Claude Code interactive | Same as above | Claude |
| `review` (performance) | reviewer-performance-pragmatist | Claude Code interactive | Same as above | Claude |
| `review` (architecture) | reviewer-architectural-purist | Claude Code interactive | Same as above | Claude |
| `review` (ux) | reviewer-ux-advocate | Claude Code interactive | Same as above | Claude |
| `implement` | implementer | Factory (if eligible) or Claude Code | Issue has spec:ready + gate2 passed | Claude, Factory, Cursor, Codex, Amp |
| `gate2` | gate2-handler | Inline response (comment) | Issue exists | Claude |
| `dispatch` | named agent | Per dispatch_target | Varies by target | Claude, Factory, Amp |
| `status` | status-handler | Inline response (comment) | None | Claude |
| `expand` | expand-handler | Inline response (comment) | None | Claude |
| `help` | help-handler | Inline response (comment) | None | Claude |
| `close` | close-handler | Inline response (comment) | Merged PR + deploy green | Claude |
| `spike` | spike-handler | Claude Code interactive | `type:spike` label | Claude, Factory |
| `spec-author` | spec-author agent | Claude Code interactive | `spec:draft` label | Claude |
| `unknown` | none | Help response (comment) | None | Claude |

### Factory Eligibility for `implement`

The `implement` intent routes to Factory only when ALL conditions are met:

1. Issue has `exec:quick` or `exec:tdd` label
2. Target repo has a Factory Cloud Template configured (see `factory-dispatch` skill)
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

**Current deployment:** n8n workflow at `cianos.app.n8n.cloud`.

### Factory Integration

For `implement` intents routed to Factory:

1. Intent parser extracts `target_issue` and resolves issue details from Linear API
2. Handler delegates via Linear assignee field (Factory's native Linear integration picks up automatically)
3. Factory reads the issue description, clones repo using Cloud Template, and executes
4. Factory posts a comment with the PR link when complete

### Claude Code Integration

For intents routed to Claude Code interactive sessions:

1. Intent parser extracts `target_issue` and parameters
2. Handler prepares a session prompt (equivalent to `/ccc:go` or `/ccc:review`)
3. Handler creates a Claude Code session (via API or manual handoff)
4. Handler posts a comment indicating a session has been initiated

**Note:** Claude Code session creation from a webhook is not yet fully automated. Current flow: webhook posts a comment with the structured intent, human launches the session manually.

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
- **Budget:** Factory dispatch is flat-rate ($16/mo); no per-task credit tracking needed

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

### Example 2: Implement with Factory

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
    "dispatch_target": "factory"
  },
  "meta": {
    "parsed_at": "2026-02-18T10:05:00.000Z",
    "confidence": 1.0,
    "matched_rule": "exact_keyword:implement"
  }
}
```

**Route:** implementer agent via Factory (issue is exec:tdd, repo has Cloud Template).

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

### Example 5: State-Based Inference (delegateId, no comment)

**Trigger:** Issue CIA-567 is delegated to Claude via Linear's delegateId field. No comment body is present. The issue has labels `spec:ready`, `type:feature`, and `exec:tdd`. No adversarial review findings exist.

**Parsed intent (v2 schema):**
```json
{
  "intent": "review",
  "target_issue": "CIA-567",
  "source_comment": null,
  "trigger": {
    "mechanism": "delegateId",
    "initiated_by": "user-uuid-xyz",
    "delegate_id": "dd0797a4-3dd2-4ae9-add5-36a691825dc4",
    "auto": false
  },
  "parameters": {
    "raw_body": null,
    "triggered_by": "user-uuid-xyz",
    "flags": [],
    "issue_state": {
      "status": "Todo",
      "labels": ["spec:ready", "type:feature", "exec:tdd"],
      "spec_label": "spec:ready",
      "exec_label": "exec:tdd",
      "type_label": "type:feature",
      "has_review_findings": false,
      "has_merged_pr": false,
      "has_linked_spec": true
    }
  },
  "meta": {
    "parsed_at": "2026-02-19T14:30:00.000Z",
    "confidence": 0.9,
    "matched_rule": "state:spec_ready_no_review"
  }
}
```

**Route:** Reviewer agent via Claude Code interactive session. The state inference table matched `spec:ready` + no review findings -> `review` intent at 0.9 confidence. The `trigger` block records that this came via delegateId (not a comment), and the `issue_state` snapshot provides full context for the handler.

## Cross-Skill References

- **mechanism-router** skill — Unified entry point for all Linear agent dispatch mechanisms. Consumes the `ParsedIntent` schema defined here and routes to handlers via the canonical dispatch hierarchy (delegateId > @mention > assignee). The mechanism-router is the runtime consumer of this skill's definitions.
- **factory-dispatch** skill — Dispatch patterns for Factory (native Linear delegation, Cloud Templates). Used when `implement` intent routes to Factory.
- **issue-lifecycle** skill — Defines issue status transitions triggered by intent handlers (e.g., moving to In Progress after implement, adding spec:review after review starts).
- **adversarial-review** skill — Defines the review taxonomy and process triggered by `review` intents. Review type selection (A-H options) maps to `parameters.review_type`.
- **platform-routing** skill — Decision tree for choosing between Claude Code, Factory, Cowork, and @mention surfaces. This skill adds the @mention surface's intent layer. Includes the Agent Dispatch via @mention section referencing this skill.
- **execution-modes** skill — Determines whether `implement` routes to Factory (exec:quick/tdd) or Claude Code (exec:pair/checkpoint). Mode lookup is a pre-condition for implement routing.
- **parallel-dispatch** skill — When multiple `implement` intents arrive for related issues, the parallel dispatch protocol handles coordination and conflict avoidance.
