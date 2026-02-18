# Dispatch Prompt Examples

Real-world examples from parallel dispatch sessions, annotated with what worked and what needed improvement.

## Example 1: composed-crunching-raven S1 (CIA-413) — Local File Pattern (Deprecated)

**Context:** 3-way parallel dispatch from master plan [CIA-379](https://linear.app/claudian/issue/CIA-379). Phase 1A focused on review gate expansion. This used the **old local-file dispatch pattern** (deprecated — see Section 8.5 of parallel-dispatch/SKILL.md).

```
Implement CIA-413 from master plan CIA-379 (Phase 1A: Review Gate Expansion).
CCC plugin repo: ~/Repositories/claude-command-centre/
Full plan at ~/.claude/plans/2026-02-12-sdd-review-dispatch.md

Context:
- CIA-413 expands adversarial review with Options C and D
- Current review skill only has Options A and B
- No dependency on Phase 1B or 2A — safe to run in parallel
- Cost profile: standard (checkpoint at $10)

Execution mode: pair

Tasks:
1. Read current adversarial-review/SKILL.md
2. Design Option C (API + Actions) and Option D (in-session subagent)
3. Add hybrid combination patterns
4. Update SKILL.md with new sections
5. Update CIA-413 with results

Deliverable: Expanded adversarial-review/SKILL.md with Options C, D, and hybrid combinations. CIA-413 closed.
```

**Result:** Session completed successfully. Paused at cost checkpoint correctly. Prompt structure worked well.

**Lesson:** Cost estimation line was critical -- session would have overrun without it.

## Example 2: composed-crunching-raven S2 (CIA-410 + CIA-405)

**Context:** Same 3-way dispatch. Phase 1B combined two related issues.

```
Implement CIA-410 and CIA-405 from master plan CIA-379 (Phase 1B: Preferences & Config).
CCC plugin repo: ~/Repositories/claude-command-centre/

Context:
- CIA-410: Preferences/config system for CCC plugin
- CIA-405: User preference expansion (review frequency, model routing)
- These two issues share the same config surface area
- No dependency on Phase 1A or 2A

Execution mode: tdd

Tasks:
1. Design preferences schema
2. Create config command
3. Wire preferences into execution-modes routing
4. Update both issues with results

Deliverable: Working /ccc:config command with preferences. CIA-410 and CIA-405 closed.
```

**Result:** Session did not start -- user did not see confirmation. Session sat idle.

**Lesson:** Added "Reply with 'Session started' before beginning work" to the template. Without explicit confirmation, there is no way to know if the session is running.

## Example 3: luminous-meandering-zephyr Batch 1 (3-way)

**Context:** CIA-423 master plan, 3-way parallel dispatch for CCC Plugin v2.0.

**Dispatch table presented before launch:**

```markdown
| Session | Issue | Focus | Mode | Est. Cost |
|---------|-------|-------|------|-----------|
| S-A | CIA-386 | Adversarial review formalization | pair | ~$5 |
| S-B | CIA-387 | Parallel dispatch rules | pair | ~$4 |
| S-C | CIA-389 | Insights pipeline v2 | tdd | ~$8 |
```

**Lesson:** Dispatch table format proved essential for human coordination. Without it, the human cannot track which terminal window corresponds to which plan phase.

## Example 4: Linear Sub-Issue Dispatch Pattern (Current)

**Context:** The current recommended pattern. Each dispatch prompt is the description of a Linear sub-issue under the master plan issue.

**Master plan issue:** [CIA-XXX](https://linear.app/claudian/issue/CIA-XXX) — "Master Plan: Planning Capabilities"

**Sub-issue created:** Title: "Batch 1A: Update parallel-dispatch skill"

**Sub-issue description (the dispatch prompt):**

```
Implement [CIA-YYY: Update parallel-dispatch skill](https://linear.app/claudian/issue/CIA-YYY)
(Phase 1A: Skill Updates) from master plan [CIA-XXX: Master Plan](https://linear.app/claudian/issue/CIA-XXX).
CCC plugin repo: ~/Repositories/claude-command-centre/

Context:
- Updates parallel-dispatch/SKILL.md with linked issue formats and Linear-native dispatch pattern
- No dependency on other Batch 1 tracks — safe to run in parallel
- Existing dispatch-examples.md needs a new example for the sub-issue pattern
- Cost profile: standard (checkpoint at $10)

Execution mode: quick | Launch as: Bypass permissions | Worktree: yes

Tasks:
1. Read current parallel-dispatch/SKILL.md
2. Update Section 4 template with linked issue format
3. Update Section 6 session registry with linked format
4. Update Section 8 dispatch table with linked format
5. Add Section 8.5 deprecation notice for local dispatch files
6. Update dispatch-examples.md with sub-issue pattern example
7. Update [CIA-YYY](url) status to Done

Deliverable: Updated parallel-dispatch/SKILL.md and dispatch-examples.md. CIA-YYY closed.
```

**Labels:** `type:chore`, `exec:quick` | **Estimate:** 2pt | **Assignee:** Claude Code (or Tembo for background)

**Benefits over local file:**
- Sub-issue status tracks progress (Todo → In Progress → Done)
- Delegatable to Tembo for automatic background execution
- Visible as child of master plan issue — no stale files
- Batch gating: "Are all Batch 1 sub-issues Done?" instead of manual tracking

## Anti-Patterns

### 1. Dispatch Without Dependency Analysis

Launching all phases in parallel without checking for data dependencies. Phase 2A reads Phase 1A's output? Sequential, not parallel.

### 2. More Than 3 Concurrent Sessions

Human attention becomes the bottleneck. Terminal switching, issue monitoring, and merge coordination degrade rapidly beyond 3 sessions.

### 3. Shared File Modification

Two parallel sessions editing the same file guarantees merge conflicts. Either use branch strategy with defined merge order, or sequence the sessions.

### 4. Missing Exit Protocol

Sessions that complete without updating Linear or writing a summary leave the human guessing about status. Always include the exit protocol in the dispatch prompt.
