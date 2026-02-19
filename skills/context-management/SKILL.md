---
name: context-window-management
description: |
  Context window management strategies for multi-tool AI agents. Covers a 3-tier delegation model for controlling what enters the main conversation, context budget thresholds, subagent return discipline, and model mixing recommendations. Prevents context exhaustion during complex sessions.
  Use when planning subagent delegation, managing long sessions, deciding what to delegate vs handle directly, or choosing model tiers for subtasks.
  Trigger with phrases like "context is getting long", "should I delegate this", "subagent return format", "model mixing strategy", "context budget", "session splitting", "when to use haiku vs opus".
---

# Context Window Management

The context window is a finite, non-renewable resource within a session. Every token consumed by tool output, file content, or verbose responses reduces the agent's capacity for reasoning about the actual task. Disciplined context management is the difference between completing a complex task in one session and hitting compaction mid-flight.

## Core Principle

**Never let raw tool output flow into the main conversation when a summary will do.** The main context is for reasoning, planning, and communicating with the human. Data retrieval, scanning, and bulk operations belong in subagents that return concise summaries.

## 3-Tier Delegation Model

Every tool call should be evaluated against these tiers before execution:

### Tier 1: Always Delegate

Any tool call expected to return more than ~1KB of content must be delegated to a subagent. The subagent processes the output and returns a summary to the main conversation.

| Operation | Why Delegate |
|-----------|-------------|
| Web page scrapes | Pages routinely produce 10-50KB of markdown |
| File reads (large files) | Source files can be thousands of lines |
| PR diffs and file change lists | Diffs scale with change size |
| Bulk search results | Search returns multiple full-text matches |
| API responses with nested data | JSON payloads from list endpoints are large |
| Documentation lookups | Library docs pages are content-heavy |

**Rule of thumb:** If the tool is _reading_ something, it probably belongs in Tier 1.

### Tier 2: Delegate for Bulk

Single-item operations are fine in the main context. But when the operation fans out to multiple items, delegate.

| Operation | Direct OK | Delegate |
|-----------|-----------|----------|
| Issue lookup | Single issue by ID | List of 10+ issues |
| Project items | Single project metadata | All items in a project |
| Collection contents | Single item metadata | Full collection listing |
| Commit history | Latest commit | Full branch history |
| User lookups | Single user | Team member listing |

**Threshold:** If the list endpoint could return more than 10 items, delegate. When using list operations directly, always set explicit limits (e.g., `limit: 10`).

### Tier 3: Direct in Main Context

Small-output operations that return structured, predictable responses. These are safe to execute directly.

| Operation | Typical Output Size |
|-----------|-------------------|
| Create/update operations | Confirmation + ID (~100 bytes) |
| Metadata lookups | Single object (~200-500 bytes) |
| Single item get | One issue/page/document (~500 bytes-1KB) |
| Status checks | Boolean or enum (~50 bytes) |
| Label operations | Confirmation (~100 bytes) |

## Context Budget Protocol

Monitor context usage throughout the session and take action at defined thresholds:

### Under 50%: Normal Operation

Work freely. Use subagents for Tier 1 and Tier 2 operations. Keep tool output concise.

### 50% to 70%: Caution Zone

- **Warn the human.** Explicitly state context usage level and remaining capacity.
- **Consider checkpointing.** If the task has natural break points, suggest splitting the session.
- **Tighten delegation.** Move Tier 2 operations into subagents even for smaller counts.
- **Summarize aggressively.** Reduce inline explanations. Reference previous context instead of restating.

### Above 70%: Critical Zone

- **Insist on session split.** Do not continue hoping it will fit. Tell the human clearly that context is running low and a new session is needed.
- **Never silently let compaction happen.** Compaction loses context in unpredictable ways. A deliberate session split with a handoff note preserves continuity.
- **Write a handoff file** if splitting: summarize current state, remaining tasks, decisions made, and open questions. The next session starts by reading this file.

### Compaction Prevention

If compaction is imminent and cannot be avoided:
1. Write all in-progress work to files immediately
2. Summarize the session state in a handoff note
3. Tell the human what was saved and where
4. The next session reads the handoff to resume

> See [references/session-economics.md](references/session-economics.md) for the full session economics framework including context budget allocation table, checkpoint decision rules at 30/50/56/70%, authoring session detection, and subagent output caps.

## Native Autocompact Integration

Claude Code provides a native autocompact mechanism via `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`. When context usage reaches the configured percentage, Claude Code automatically triggers `/compact` to summarize older conversation turns and free context space. This is a **safety net**, not a replacement for CCC's advisory thresholds.

### Threshold Relationship

CCC thresholds and native autocompact are **complementary, not competing**:

| Threshold | Mechanism | Behavior | Type |
|-----------|-----------|----------|------|
| **50%** | CCC (advisory) | Warn user, suggest checkpointing, tighten delegation | Proactive — human decides |
| **70%** | CCC (blocking) | Insist on session split, write handoff file | Proactive — agent enforces |
| **80%** | Native autocompact | Automatically triggers `/compact` | Reactive — safety net |

The 10% gap between CCC's 70% "insist" threshold and the 80% autocompact trigger gives CCC time to fire its session-split protocol before autocompact kicks in. If CCC's warnings are heeded, autocompact never fires. If they are ignored (or if context grows faster than expected), autocompact catches it before the context window is exhausted.

### Recommended Configuration

Set `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=80` in your shell environment:

```bash
# In ~/.zshrc or ~/.bashrc
export CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=80
```

**Why 80%, not lower:**
- Below 70% would conflict with CCC's "insist on session split" — autocompact would fire before CCC has a chance to recommend a deliberate split with a handoff file
- At 70% exactly, autocompact and CCC would race, producing unpredictable behavior
- At 80%, CCC's 70% threshold fires first with structured session handoff; autocompact at 80% is a backstop for sessions that continue past the warning

**Why 80%, not higher:**
- The default (~95%) leaves almost no buffer before context exhaustion
- At 90%+, there may not be enough context remaining for autocompact to produce a useful summary
- 80% provides a generous 10% buffer above CCC's intervention point while still leaving 20% of the window for the compact operation itself

### Session Start Checklist

Verify this environment variable is set at the beginning of each session:

```
✓ CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=80 (check: echo $CLAUDE_AUTOCOMPACT_PCT_OVERRIDE)
```

If unset, the native autocompact defaults to ~95%, which provides no meaningful safety net above CCC's thresholds. The session-start hook (`hooks/scripts/ccc-session-start.sh`) can validate this and warn if the variable is missing or misconfigured.

### Interaction with `/compact` and `/resume`

- **Manual `/compact`**: Always available. Use proactively before hitting any threshold.
- **Autocompact at 80%**: Automatic. Summarizes older turns. May lose nuance but preserves session continuity.
- **CCC session split at 70%**: Writes a structured handoff file with full context. The next session reads this file via `/resume` or `/ccc:go`.
- **`/ccc:checkpoint`**: CCC-layer complement that captures task state, Linear statuses, and continuation prompt before splitting. See the session-exit skill for the full checkpoint protocol.

## Subagent Return Discipline

Subagents must follow strict output constraints. Unbounded subagent returns defeat the purpose of delegation.

### Return Format Rules

- **Summary length:** 3-5 sentences, maximum 200 words
- **Structure:** Lead with the answer, follow with supporting details
- **Tables:** Use markdown tables for structured data (compact, scannable)
- **No raw content:** Never return raw scraped markdown, full file contents, or unprocessed API responses
- **Large content:** Write to a file and return the file path, not the content itself

### Example: Good vs. Bad Returns

**Bad return** (wastes context):
> Here is the full content of the page... [2000 words of scraped markdown]

**Good return** (preserves context):
> The documentation page covers 3 authentication methods: API key, OAuth 2.0, and JWT. API key is recommended for server-to-server. OAuth is required for user-facing flows. JWT is supported but deprecated. Key setup steps are in the "Getting Started" section. Full content written to `/tmp/auth-docs.md`.

**Bad return** (unstructured dump):
> Issue 1: Title is "Fix login bug", status is In Progress, assigned to... Issue 2: Title is "Update API docs"...

**Good return** (structured summary):
> Found 8 open issues in the project. 3 are In Progress, 5 are Todo. Summary:
>
> | ID | Title | Status | Assignee |
> |----|-------|--------|----------|
> | ~~PREFIX-101~~ | Fix login bug | In Progress | Agent |
> | ~~PREFIX-102~~ | Update API docs | Todo | Unassigned |
> | ... | ... | ... | ... |

## Subagents as Context Management

Subagents are primarily a tool for _context management_, not just parallelism. Use subagents whenever you have a self-contained unit of work that doesn't require user input or advanced permissions. The main session stays lean while context-hungry operations run in isolated windows. For example, writing N section files in parallel via N subagents consumes minimal main-session context versus writing them sequentially inline. Source: Pierce Lamb Deep Trilogy — identified subagents as the key abstraction for protecting the main session's context budget.

## Model Mixing for Subagents

Not all subagent tasks require the same reasoning capability. Match the model tier to the cognitive demand of the subtask:

| Model Tier | Characteristics | Best For |
|------------|----------------|----------|
| **Fast/cheap** (e.g., haiku) | Lowest cost, highest throughput, adequate for structured tasks | File scanning, data retrieval, search queries, bulk reads, simple transformations |
| **Balanced** (e.g., sonnet) | Good quality-to-cost ratio, strong analysis | Code review synthesis, PR summaries, test analysis, documentation review, multi-source reconciliation |
| **Highest quality** (e.g., opus) | Maximum reasoning capability, highest cost | Critical implementation, architectural decisions, complex debugging, spec writing, adversarial review |

### Routing Guidelines

- **Default to fast/cheap** for read-only operations. Most data retrieval does not need deep reasoning.
- **Use balanced** when the subagent needs to synthesize, compare, or evaluate across multiple inputs.
- **Reserve highest quality** for tasks where incorrect output has high cost (wrong implementation, missed security issue, flawed architecture).
- **Never use highest quality for scanning.** It is wasteful and slower. A fast model reading 20 files and returning summaries is better than an expensive model reading 3 files deeply.

## Practical Integration

When working in a multi-tool environment with ~~project-tracker~~, ~~version-control~~, and web tools:

1. **Before any tool call,** classify it by tier
2. **Tier 1 calls** go to a subagent with explicit return format instructions
3. **Tier 2 calls** with small counts execute directly; large counts get delegated
4. **Tier 3 calls** execute directly in the main context
5. **After every major section of work,** mentally assess context usage
6. **At 50%,** tell the human and adjust strategy
7. **At 70%,** stop and plan a session split

This discipline compounds. A session that delegates properly can accomplish 3-5x more work than one that lets raw output flood the context window.

### Natural Breakpoint Resets

For long-horizon tasks that span many context-consuming steps, recommend context resets at natural workflow breakpoints (e.g., between planning and implementation phases, after completing a major subtask). This is preferable to auto-compaction, which loses context unpredictably. The agent should have solid recovery mechanisms (file-based state, progress logs) so that restarting from a clean context is cheap. Source: Pierce Lamb Deep Trilogy — recommended `/clear` at key workflow transitions to manage finite context windows proactively.

## Tool-Specific Output Discipline

These rules control the most common sources of context bloat. They are **behavioral rules**, not reference material — follow them on every tool call.

### ~~project-tracker~~ Output Discipline

- **NEVER** `list_issues` without explicit `limit` (default returns 100KB+ JSON). Always `limit: 10` or less.
- **NEVER** `list_issues` in main context — always delegate to a subagent returning a markdown table.
- **Single `get_issue`** OK directly. 2+ issues → subagent.
- **Collection list operations** (e.g., Zotero `get_collection_items`): same rules.

Subagent return format for issues:

```markdown
| ID | Title | Status | Assignee | Priority |
|----|-------|--------|----------|----------|
```

No descriptions, no full metadata dumps, no nested JSON. Main context uses this table for decisions; call `get_issue` on specific IDs for depth.

### Web Scraping Discipline

- **Prefer lightweight fetch** for single-page reads. Only use batch scraping tools for multi-page operations.
- **Always set:** `onlyMainContent: true`, `formats: ["markdown"]`, `removeBase64Images: true`
- **Never** return raw scraped markdown to main context. Summarize in 2-3 bullets or write to file.

### MCP-First Principle

When choosing between an MCP tool and a custom script: **prefer MCP.** MCPs account for only ~6.5% of session tool calls. Scripts only when no MCP exists or the MCP can't reach the operation. Never create new scripts if an MCP can accomplish the task.

## Pilot Batch Pattern

Before any operation involving 10+ items:

1. Run a **pilot batch of 3 items** first
2. Verify the output format, error handling, and item correctness
3. Only then proceed with the full batch

This pattern caught errors in URL formatting, sync storms, and MCP path issues before they affected 40+ items (EventKit Canvas Sync, Feb 8 2026).

## Session Exit Summary Tables

At the end of every working session, present structured summaries:

### Issues Table

```markdown
| Title | Status | Assignee | Milestone | Priority | Estimate | Blocking | Blocked By |
```

- Title = `[Issue title](linear-url)` (linked, opens in desktop app)
- Populate all fields from `get_issue(includeRelations: true)`. Use `--` for empty.
- Verify accuracy before presenting.

### Documents Table

```markdown
| Title | Project |
```

- Title = `[Doc title](linear-url)` (linked)
- Include only documents created or modified during the session.

## Cross-Skill References

- **execution-engine** -- Fresh context on each task iteration reduces per-task context pressure
- **issue-lifecycle** -- Session exit protocol defines what status normalization is required
- **spec-workflow** -- Master plan pattern governs multi-session work splitting
- **parallel-dispatch** -- Extends context management to multi-session scenarios. Each parallel session has independent context; session exit tables and handoff files enable coordination across sessions.
