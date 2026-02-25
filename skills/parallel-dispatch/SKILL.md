---
name: parallel-session-dispatch
description: |
  Rules for dispatching and coordinating multiple parallel Claude Code sessions from a master plan. Covers the decision tree for parallel vs. sequential phasing, session mode mapping, dispatch prompt templates, naming conventions, feedback routing, and coordination protocol.
  Use when launching parallel sessions from a master plan, deciding whether phases can run concurrently, writing dispatch prompts for new sessions, or coordinating outputs across concurrent sessions.
  Trigger with phrases like "dispatch parallel sessions", "can these phases run in parallel", "launch sessions from master plan", "session dispatch template", "parallel vs sequential", "coordinate multiple sessions", "multi-session dispatch".
compatibility:
  surfaces: [code, cowork, desktop]
  tier: degraded-cowork
  degradation_notes: "Git worktrees and branch management unavailable in Cowork; dispatch via Linear sub-issue assignment only"
---

# Parallel Session Dispatch

This skill governs how a master plan's phases are dispatched as concurrent Claude Code sessions. It sits between **execution-modes** (how to run one session) and **context-management** (how to manage context within a session) -- addressing how to run multiple sessions in parallel.

## 1. Dispatch Decision Tree

Not all phases can run concurrently. Evaluate each phase pair against these criteria before dispatching in parallel:

```
Can Phase B run in parallel with Phase A?
|
+-- Does B read A's output (files, schema, API)?
|   +-- YES --> SEQUENTIAL (B waits for A)
|   +-- NO  --> continue
|
+-- Do both touch the same files or directories?
|   +-- YES --> Can they work on separate branches?
|   |   +-- YES --> PARALLEL with branch strategy
|   |   +-- NO  --> SEQUENTIAL
|   +-- NO  --> continue
|
+-- Do both modify shared infrastructure (DB schema, CI config)?
|   +-- YES --> SEQUENTIAL (merge conflicts are expensive)
|   +-- NO  --> PARALLEL OK
```

**Guardrails that always apply:**
- Each parallel session has an independent context window. No shared memory between sessions.
- Linear MCP access is shared (OAuth session). Concurrent writes to the same issue will race -- assign exactly one issue per session.
- Git branches must not conflict. Use `{agent}/{issue-id}-{slug}` naming per session.
- Maximum recommended parallelism: **3 sessions**. Beyond 3, human coordination overhead exceeds the parallelism gain.
- **Batch dispatching:** When a master plan has more than 3 parallelizable phases, group them into batches of 2-3. Complete Batch 1 before launching Batch 2.

### Research Track Dispatch

When all phases are read-only research tracks with no shared file output:

- **Session cap: 5 research sessions maximum.** The standard 3-session cap remains the default for implementation sessions — the relaxed cap applies only when every dispatched session is purely read-only research.
- **Research Sufficiency Assessment:** After all tracks complete, evaluate evidence convergence, coverage, and contradictions. Outcome: SUFFICIENT (proceed to synthesis) or INSUFFICIENT (dispatch targeted follow-up tracks).
- **Cross-skill boundaries:** Output format owned by **research-pipeline**. Evidence criteria owned by **research-grounding**. Parallel-dispatch owns *when* to dispatch and *how many* tracks.
- **Cost model note:** Research tracks consume 2-4x more MCP calls than implementation sessions. Factor this into cost estimates.

## 2. Session Mode Mapping

Each dispatched session needs a launch mode based on `exec:*` label and whether the task produces code changes.

**Quick reference:** Code-producing sessions use Bypass (quick, tdd, swarm, spike), Plan mode (pair), or Ask permissions (checkpoint). Analysis-only tasks always use Bypass permissions.

> See [references/dispatch-operations.md](references/dispatch-operations.md) for the full mode mapping tables and decision tree.

Include this in every dispatch prompt as a **"Launch as:"** field:
```
**Exec mode:** pair | **Launch as:** Plan mode
**Exec mode:** spike (analysis-only) | **Launch as:** Bypass permissions
```

## 3. Adversarial Review Integration

Review gates interact with parallel dispatch at four points. See the **adversarial-review** skill for full gate definitions (Options A-D).

| Timing | When to Apply | Pattern |
|--------|---------------|---------|
| **Pre-dispatch** | Complex features where the spec needs validation before any work begins | Run `/review` on the master spec. All sessions block until review passes Gate 2. |
| **In-session** | Checkpoint-mode sessions with high-risk changes | Option D: in-session subagent review at each checkpoint. |
| **Post-session** | Standard PR-level review after each session produces a PR | Options A-C: async review on the session's PR before merge. |
| **Cross-session** | Parallel sessions produce conflicting approaches or overlapping changes | Human arbitration required. Flag in Linear, halt affected sessions until resolved. |

**Multi-model consensus** (from adversarial-review): When reviewing outputs from parallel sessions that must be reconciled, apply the 2/3 agreement threshold for inclusion, 3/3 for critical findings.

## 4. Dispatch Prompt Template

**Dispatch prompts live as Linear sub-issue descriptions**, not local files. Each dispatch prompt is the description of a sub-issue under the master plan issue.

### Sub-Issue Structure

- **Title:** `Batch {N}{Letter}: {Focus}` (e.g., "Batch 1A: Session exit skill")
- **Description:** The full dispatch prompt (template below)
- **Labels:** `type:chore` (or `type:spike`), appropriate `exec:*` mode
- **Estimate:** From the dispatch prompt's cost estimate (Fibonacci)
- **Parent:** The master plan issue
- **Assignee:** Target agent (Claude, Factory) or unassigned for human pickup

### Dispatch Prompt (sub-issue description content)

Every field in braces is required. All issue references must use linked format (see [plan-format.md](../planning-preflight/references/plan-format.md)).

```
{Action verb} on [{ISSUE_ID}: {TITLE}](https://linear.app/claudian/issue/{ISSUE_ID})
({PHASE_NAME}) from master plan [{MASTER_ISSUE}: {MASTER_TITLE}](https://linear.app/claudian/issue/{MASTER_ISSUE}).
{PLUGIN_REPO_OR_PROJECT}: {REPO_PATH}
Launch from: {REPO_PATH} (required — repo-specific sessions must launch from the repo directory)

Context:
- {3-5 bullet points with essential context}
- {Link to prior session if resuming}
- {Cost/resource constraints if any}
- Review findings to address: {link to RDR comment, if applicable}

Execution mode: {quick|tdd|pair|checkpoint|swarm|spike} | Launch as: {Bypass permissions|Plan mode|Ask permissions} | Worktree: {yes|no}

Tasks:
1. {Numbered task list}

Deliverable: {What "done" looks like}. Update [{ISSUE_ID}](url) with results.
```

**Required additions:**
- **Cost estimation:** Include `Estimate cost before execution. If >$10 and cost profile is not unlimited, checkpoint.`
- **Session confirmation:** Include `Reply with 'Session started' before beginning work.`
- **Exit protocol:** Include `Update Linear issue status to Done/In Review.`
- **Worktree:** Set `yes` for parallel sessions, `no` for sequential/solo sessions.

> See [references/dispatch-examples.md](references/dispatch-examples.md) for real-world dispatch prompt examples.

## 5. Naming Conventions

**Plan files:** Use `{YYYY-MM-DD}-{project-short}-{topic}.md` instead of Claude-generated random names. **Session names:** Not programmatically controllable — maintain a session registry mapping table in the master plan issue.

> See [references/dispatch-operations.md](references/dispatch-operations.md) for naming details, project shorts table, and session registry template.

## 6. Coordination Protocol

### Before Dispatch

1. **Create dispatch sub-issues** under the master plan issue with full dispatch prompts.
2. **Enable worktrees for parallel sessions.** Each session gets an isolated checkout on its own branch.
3. **Present the parallel dispatch table** to the human for approval:

```markdown
| Session | Issue | Focus | Mode | Est. Cost | Agent | Worktree |
|---------|-------|-------|------|-----------|-------|----------|
| S-A | [CIA-413](url) | Review gates | pair | ~$5 | Claude Code | yes |
| S-B | [CIA-387](url) | Dispatch rules | pair | ~$3 | Factory | n/a |
```

> **Worktree column:** `yes` for parallel Claude Code sessions, `no` for sequential, `n/a` for Factory/external agents.

### During Execution, Session Exit, Merging, and Conflict Resolution

> See [references/dispatch-operations.md](references/dispatch-operations.md) for the full coordination protocol covering execution rules, session exit checklist, Desktop Code UI merge controls, and conflict resolution procedures.

## 7. Feedback Routing and Agent-Aware Dispatch

External agent feedback (Vercel, Copilot, Sentry, Factory, etc.) routes into the CCC pipeline per agent type. Agent-aware dispatch adds constraints for multi-agent sessions: one agent per session, branch conventions differ by agent, and only Claude Code sessions have full CCC awareness.

> See [references/dispatch-operations.md](references/dispatch-operations.md) for the full feedback routing table, agent-aware dispatch rules, @mention feedback protocol, and the Agent Teams vs. parallel-dispatch decision guide.

## Cross-Skill References

- **execution-modes** -- `exec:swarm` for 5+ independent subagent tasks within a single session; parallel dispatch is for multiple independent _sessions_. See also the **Agent Selection** section for mode-to-agent routing.
- **context-management** -- Session exit summary tables, subagent return discipline, context budget protocol
- **adversarial-review** -- Multi-model consensus protocol for reconciling parallel session outputs; Options A-H for review timing
- **execution-engine** -- State persistence across session boundaries via `.ccc-state.json` and `.ccc-progress.md`
- **spec-workflow** -- Master plan pattern governs the phase decomposition that feeds dispatch decisions
