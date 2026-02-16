---
name: parallel-session-dispatch
description: |
  Rules for dispatching and coordinating multiple parallel Claude Code sessions from a master plan. Covers the decision tree for parallel vs. sequential phasing, session mode mapping, dispatch prompt templates, naming conventions, feedback routing, and coordination protocol.
  Use when launching parallel sessions from a master plan, deciding whether phases can run concurrently, writing dispatch prompts for new sessions, or coordinating outputs across concurrent sessions.
  Trigger with phrases like "dispatch parallel sessions", "can these phases run in parallel", "launch sessions from master plan", "session dispatch template", "parallel vs sequential", "coordinate multiple sessions", "multi-session dispatch".
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
- Maximum recommended parallelism: **3 sessions**. Beyond 3, human coordination overhead exceeds the parallelism gain. Proven in composed-crunching-raven (3-way parallel, all completed successfully) and luminous-meandering-zephyr (3-way Batch 1 dispatch).
- **Batch dispatching:** When a master plan has more than 3 parallelizable phases, group them into batches of 2-3. Complete Batch 1 before launching Batch 2. This keeps the human's monitoring load manageable and creates natural checkpoints for course correction between batches.

## 2. Session Mode Mapping

Each dispatched session needs a **UI launch mode** — the permission level selected when starting the Claude Code session. The mapping depends on two factors: the `exec:*` label AND whether the task produces code changes.

### Primary mapping (tasks that produce code/file changes)

| Exec Mode | Launch As | Agent Options | Rationale |
|-----------|-----------|---------------|-----------|
| `quick` | Bypass permissions | Claude Code, cto.new, Copilot | Well-defined, no ambiguity, just execute |
| `tdd` | Bypass permissions | Claude Code, Cursor, Cyrus | Red-green-refactor is autonomous once started |
| `pair` | Plan mode | Claude Code | Explore + get human input, then implement after approval |
| `checkpoint` | Ask permissions | Claude Code | Pauses at gates, human approves each step |
| `swarm` | Bypass permissions | Claude Code (Tembo Phase 3) | Subagent orchestration is autonomous |
| `spike` | Bypass permissions | Claude Code, cto.new | Exploration that produces artifacts (files, docs) |

### Override: analysis-only tasks

If the deliverable is a **recommendation, evaluation, or decision** (no code/file changes to the repo), Plan mode is counterproductive — the plan IS the deliverable, leaving nothing to do after approval.

| Task Type | Launch As | Rationale |
|-----------|-----------|-----------|
| Analysis/evaluation spike | Bypass permissions | Writing the analysis is the work; no implementation phase follows |
| A/B comparison (no code) | Bypass permissions | Scenario evaluation is autonomous |
| Investigation with code changes | Plan mode | Plan the approach, then implement |

### How to decide

```
Does the session produce code/file changes to the repo?
|
+-- NO (analysis, evaluation, recommendation)
|   +-- Always: Bypass permissions
|
+-- YES
    +-- Is the approach well-defined? --> Bypass permissions (quick, tdd, swarm)
    +-- Does it need human input on approach? --> Plan mode (pair)
    +-- Does it need approval at milestones? --> Ask permissions (checkpoint)
```

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

Use this template when launching each parallel session. Every field in braces is required.

```
{Action verb} on {ISSUE_ID} ({PHASE_NAME}) from master plan {MASTER_ISSUE}.
{PLUGIN_REPO_OR_PROJECT}: {REPO_PATH}
Full plan at {PLAN_FILE_PATH}

Context:
- {3-5 bullet points with essential context}
- {Link to prior session if resuming}
- {Cost/resource constraints if any}

Execution mode: {quick|tdd|pair|checkpoint|swarm|spike} | Launch as: {Bypass permissions|Plan mode|Ask permissions}

Tasks:
1. {Numbered task list}

Deliverable: {What "done" looks like}. Update {ISSUE_ID} with results.
```

**Required additions** (learned from composed-crunching-raven and luminous-meandering-zephyr):

- **Cost estimation:** Include `Estimate cost before execution. If >$10 and cost profile is not unlimited, checkpoint.`
- **Session confirmation:** Include `Reply with 'Session started' before beginning work.`
- **Exit protocol:** Include `Update Linear issue status to Done/In Review. Write session summary to plan file.`

> See [references/dispatch-examples.md](references/dispatch-examples.md) for real-world dispatch prompt examples from prior sessions.

## 5. Plan File Naming Convention

Replace Claude-generated random names (e.g., `composed-crunching-raven`) with structured names:

**Format:** `{YYYY-MM-DD}-{project-short}-{topic}.md`

**Project shorts:**

| Project | Short |
|---------|-------|
| claude-command-centre | `sdd` |
| alteri | `alteri` |
| prototypes | `proto` |
| ObsidianVault | `vault` |

**Examples:**
- `2026-02-15-sdd-preferences-expansion.md`
- `2026-02-13-alteri-agent-orchestration.md`

**Where to apply:** When creating a plan file during `/go` planning phase or when writing a master plan issue's session plan. The random session name still exists (Claude Code assigns it) but the plan file uses the structured name.

## 6. Session Naming

Claude Code session names (e.g., `composed-crunching-raven`) are **not programmatically controllable** as of February 2026. There is no CLI flag, environment variable, or hook to set them. (Tracked upstream: [anthropics/claude-code#17188](https://github.com/anthropics/claude-code/issues/17188).)

**Workaround -- Session Identity Mapping:**

Maintain a mapping table in the master plan issue or plan file:

```markdown
## Session Registry
| Session Name | Issue | Phase | Plan File | Status |
|--------------|-------|-------|-----------|--------|
| composed-crunching-raven | CIA-413 | 1A | 2026-02-12-sdd-review-dispatch.md | Done |
| luminous-meandering-zephyr | CIA-387 | 1B | 2026-02-15-sdd-parallel-dispatch.md | Active |
```

Update this table when each session starts (session name is visible in the terminal title bar and via `/sessions` command). This is the only reliable way to track which random name maps to which plan phase.

**Best practice:** At session start, the first action should be to record the auto-generated session name in the master plan's session registry. At session end, update the status column. This creates an audit trail linking random names to structured plan phases.

## 7. Cross-System Feedback Routing

Feedback from external agents routes back into the SDD pipeline as follows:

| Source | Feedback Type | Routing |
|--------|---------------|---------|
| Vercel Bot | Deploy preview URL + status | Implementer agent verify step |
| Vercel Comments | UI feedback from stakeholders | v0 feedback loop |
| GitHub Copilot | PR review suggestions | Implementer addresses before merge |
| Sentry | Error alerts post-deploy | New issue via spec-author, or reopen if regression |
| Linear Bot | Issue-PR linking | Automatic, no agent action needed |
| Cursor | Quick fix PRs (<5 lines) | Copilot review, merge, bypass SDD |
| cto.new | Implementation PR or branch | Review via standard PR process; compare with Claude Code output if both assigned |
| Codex | PR code review findings (P1/P2) | Implementer addresses P1 before merge; P2 at discretion |
| Cyrus | Self-verified PR (3 iterations) | Light review — Cyrus self-verifies, but human spot-checks |

For parallel sessions: each session monitors feedback only for its own issue/PR. Cross-session feedback (e.g., Sentry error caused by interaction between two parallel PRs) routes to the human for triage.

## 8. Coordination Protocol

### Before Dispatch

Present a **parallel dispatch table** to the human for approval before launching:

```markdown
| Session | Issue | Focus | Mode | Est. Cost | Branch |
|---------|-------|-------|------|-----------|--------|
| S-A | CIA-413 | Review gates | pair | ~$5 | claude/cia-413-review-gates |
| S-B | CIA-387 | Dispatch rules | pair | ~$3 | claude/cia-387-dispatch-rules |
| S-C | CIA-414 | Insights v2 | tdd | ~$8 | claude/cia-414-insights-v2 |
```

### During Execution

- **Branch naming:** `{agent}/{issue-id}-{slug}` (e.g., `claude/cia-387-dispatch-rules`)
- **Linear status:** Each session marks its issue In Progress immediately on start
- **No cross-talk:** Sessions do not read each other's branches or issue comments during execution
- **Merge order:** Define merge order in the dispatch table if sessions touch adjacent code. First-merged session's branch becomes the base for subsequent merges.

### Session Exit

Each session must, on completion:

1. Mark its Linear issue Done or In Review
2. Write a session summary to the plan file (see context-management session exit tables)
3. Update the session registry table in the master plan
4. If merge conflicts are anticipated, flag in a Linear comment on the master plan issue -- human resolves

### Conflict Resolution

- **File-level conflicts:** Human resolves manually. The session that finished second rebases onto the first.
- **Semantic conflicts** (both sessions made valid but incompatible design decisions): Escalate to human. Do not auto-resolve. Document both approaches in the master plan issue so the human has full context for the decision.
- **Linear race conditions:** If two sessions update the same issue, the later write wins. Avoid by assigning one issue per session.
- **Failed sessions:** If a parallel session fails or is abandoned, update its status in the session registry to "Failed" with a brief reason. The next batch should not depend on failed session outputs without human review.

## Agent-Aware Dispatch

When dispatching parallel sessions to different agents, additional constraints apply:

- **One agent per session.** Do not assign the same issue to multiple agents simultaneously. Linear assignment is exclusive.
- **Branch conventions differ.** Claude Code uses `claude/{issue-id}-{slug}`. External agents use their own conventions (Cursor: `cursor/{issue-id}`, Copilot: auto-named). Document the branch in the session registry.
- **Only Claude Code sessions have full SDD awareness.** External agents (cto.new, Cursor, Codex) do not read SDD skill files. Provide essential context (acceptance criteria, constraints) in the issue description, not in skill references. Use the Dispatch Issue Template from CONNECTORS.md § Agent Dispatch Protocol.
- **Feedback reconciliation.** If two agents produce PRs for related issues, follow the Feedback Reconciliation Protocol in **CONNECTORS.md § Agent Dispatch Protocol**. External agents do not have cross-session awareness.

> For agent adoption status, routing tables, the selection decision tree, and dispatch architecture, see **CONNECTORS.md § Agent Connectors**.

## Cross-Skill References

- **execution-modes** -- `exec:swarm` for 5+ independent subagent tasks within a single session; parallel dispatch is for multiple independent _sessions_. See also the **Agent Selection** section for mode-to-agent routing.
- **context-management** -- Session exit summary tables, subagent return discipline, context budget protocol
- **adversarial-review** -- Multi-model consensus protocol for reconciling parallel session outputs; Options A-H for review timing
- **execution-engine** -- State persistence across session boundaries via `.sdd-state.json` and `.sdd-progress.md`
- **spec-workflow** -- Master plan pattern governs the phase decomposition that feeds dispatch decisions
