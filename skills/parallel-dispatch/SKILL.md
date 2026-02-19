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

### Research Track Dispatch

When all phases are read-only research tracks with no shared file output, the following relaxed constraints apply.

**Session cap: 5 research sessions maximum.** This covers the standard pipeline (3 discovery sources + supplementary + Zotero review) and matches CIA-509's observed maximum (4 tracks + 1 synthesis). Beyond 5 requires explicit justification in the dispatch table. The standard 3-session cap remains the default for implementation sessions — the relaxed cap applies only when every dispatched session is purely read-only research.

**Research Sufficiency Assessment.** After all tracks complete, evaluate before proceeding to synthesis:

- **Evidence convergence:** Do 2+ tracks cite the same findings independently? This is a strong signal that the evidence base is solid.
- **Coverage:** Are all research questions from the spike issue addressed by at least one track?
- **Contradictions:** Do any tracks produce conflicting evidence? Conflicting evidence requires human resolution before synthesis can proceed.

Outcome: **SUFFICIENT** (proceed to synthesis) or **INSUFFICIENT** (specify which gaps remain and dispatch targeted follow-up tracks). This assessment is performed by the dispatching session, not by the research tracks themselves.

**Cross-skill boundaries.** Output format and merge semantics for research tracks are owned by the **research-pipeline** skill. Evidence criteria (what counts as adequate grounding, citation standards, Evidence Object format) are owned by the **research-grounding** skill. Parallel-dispatch owns *when* to dispatch and *how many* tracks — it does not define what constitutes sufficient evidence in isolation.

**Cost model note.** Research tracks consume 2-4x more MCP calls than implementation sessions due to multi-source discovery (S2, arXiv, OpenAlex, HuggingFace, Zotero). Factor this into cost estimates in the dispatch table.

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

**Dispatch prompts live as Linear sub-issue descriptions**, not local files. Each dispatch prompt is the description of a sub-issue under the master plan issue.

### Sub-Issue Structure

- **Title:** `Batch {N}{Letter}: {Focus}` (e.g., "Batch 1A: Session exit skill")
- **Description:** The full dispatch prompt (template below)
- **Labels:** `type:chore` (or `type:spike`), appropriate `exec:*` mode
- **Estimate:** From the dispatch prompt's cost estimate (Fibonacci)
- **Parent:** The master plan issue
- **Assignee:** Target agent (Claude, Tembo) or unassigned for human pickup

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

**Required additions** (learned from composed-crunching-raven and luminous-meandering-zephyr):

- **Cost estimation:** Include `Estimate cost before execution. If >$10 and cost profile is not unlimited, checkpoint.`
- **Session confirmation:** Include `Reply with 'Session started' before beginning work.`
- **Exit protocol:** Include `Update Linear issue status to Done/In Review.`
- **Worktree:** Set `Worktree: yes` when this session runs in parallel with other sessions against the same repo. Set `no` for sequential/solo sessions. Worktree sessions get isolated checkouts — no merge conflicts with the main working directory.

> See [references/dispatch-examples.md](references/dispatch-examples.md) for real-world dispatch prompt examples from prior sessions.

## 5. Plan File Naming Convention

Replace Claude-generated random names (e.g., `composed-crunching-raven`) with structured names:

**Format:** `{YYYY-MM-DD}-{project-short}-{topic}.md`

**Project shorts:**

| Project | Short |
|---------|-------|
| claude-command-centre | `ccc` |
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
| Session Name | Issue | Phase | Agent | Worktree | Branch | Status |
|--------------|-------|-------|-------|----------|--------|--------|
| lucid-euler | [CIA-540](https://linear.app/claudian/issue/CIA-540) | 1A | Claude Code | yes | claude/lucid-euler | Done |
| (direct main) | [CIA-541](https://linear.app/claudian/issue/CIA-541) | 1B | Claude Code | no | main | Done |
| luminous-meandering-zephyr | [CIA-387](https://linear.app/claudian/issue/CIA-387) | 1B | Claude Code | Active |
```

Update this table when each session starts (session name is visible in the terminal title bar and via `/sessions` command). This is the only reliable way to track which random name maps to which plan phase.

**Best practice:** At session start, the first action should be to record the auto-generated session name in the master plan's session registry. At session end, update the status column. This creates an audit trail linking random names to structured plan phases.

## 7. Cross-System Feedback Routing

Feedback from external agents routes back into the CCC pipeline as follows:

| Source | Feedback Type | Routing |
|--------|---------------|---------|
| Vercel Bot | Deploy preview URL + status | Implementer agent verify step |
| Vercel Comments | UI feedback from stakeholders | v0 feedback loop |
| GitHub Copilot | PR review suggestions | Implementer addresses before merge |
| Sentry | Error alerts post-deploy | New issue via spec-author, or reopen if regression |
| Linear Bot | Issue-PR linking | Automatic, no agent action needed |
| Cursor | Quick fix PRs (<5 lines) | Copilot review, merge, bypass CCC |
| cto.new | Implementation PR or branch | Review via standard PR process; compare with Claude Code output if both assigned |
| Codex | PR code review findings (P1/P2) | Implementer addresses P1 before merge; P2 at discretion |
| Cyrus | Self-verified PR (3 iterations) | Light review — Cyrus self-verifies, but human spot-checks |

For parallel sessions: each session monitors feedback only for its own issue/PR. Cross-session feedback (e.g., Sentry error caused by interaction between two parallel PRs) routes to the human for triage.

## 8. Coordination Protocol

### Before Dispatch

1. **Create dispatch sub-issues** under the master plan issue. Each sub-issue description contains the full dispatch prompt (Section 4 template). Set labels, estimates, and agent assignment.
2. **Enable worktrees for parallel sessions.** When launching 2+ sessions against the same repo, use Claude Code's **worktree** feature (checkbox in Desktop Code UI, or `--worktree` in CLI). Each session gets an isolated checkout on its own branch — no conflicts with the main working directory or other parallel sessions. Worktrees are the recommended default for all parallel dispatch.
3. **Present the parallel dispatch table** to the human for approval before launching:

```markdown
| Session | Issue | Focus | Mode | Est. Cost | Agent | Worktree |
|---------|-------|-------|------|-----------|-------|----------|
| S-A | [CIA-413](https://linear.app/claudian/issue/CIA-413) | Review gates | pair | ~$5 | Claude Code | yes |
| S-B | [CIA-387](https://linear.app/claudian/issue/CIA-387) | Dispatch rules | pair | ~$3 | Tembo | n/a |
| S-C | [CIA-414](https://linear.app/claudian/issue/CIA-414) | Insights v2 | tdd | ~$8 | Claude Code | yes |
```

> **Worktree column:** `yes` for parallel Claude Code sessions (isolated checkout, auto-branch). `no` for single sequential sessions. `n/a` for Tembo/external agents (they use their own sandboxes).

### During Execution

- **Worktrees:** Each worktree session operates in an isolated checkout (e.g., `~/.claude/worktrees/claude-command-centre-cia-541/`). The main working directory at `~/Repositories/claude-command-centre/` remains untouched. When complete, the session's branch is merged via PR.
- **Branch naming:** `{agent}/{issue-id}-{slug}` (e.g., `claude/cia-387-dispatch-rules`). Worktree sessions auto-create branches.
- **Linear status:** Each session marks its issue In Progress immediately on start
- **No cross-talk:** Sessions do not read each other's branches or issue comments during execution
- **Merge order:** Define merge order in the dispatch table if sessions touch adjacent code. First-merged session's branch becomes the base for subsequent merges.

### Session Exit

Each session must, on completion:

1. Mark its Linear issue Done or In Review
2. Write a session summary to the plan file (see context-management session exit tables)
3. Update the session registry table in the master plan
4. If merge conflicts are anticipated, flag in a Linear comment on the master plan issue -- human resolves

### Merging Completed Sessions (Desktop Code UI)

When a session finishes, the Desktop Code UI presents merge controls at the bottom of the session:

| Session type | UI shows | What to do |
|-------------|----------|------------|
| **Worktree session** | `main ← claude/{session-name}` + **"Commit changes"** | Click to push branch and create PR. Review diff in GitHub, then merge. This is the standard path. |
| **Non-worktree on main** | `main ← main` + **"Create PR"** | Do NOT click "Create PR" (main→main PR is meaningless). Instead, push main directly via terminal when ready: `git push`. |
| **Tembo / external agent** | N/A (managed by agent platform) | Tembo auto-creates PR. Review and merge in GitHub. |

**Worktree sessions are preferred** precisely because they produce clean PRs with reviewable diffs. The "Commit changes" button is the expected exit action for worktree dispatch sessions.

**Session name tracking:** The Desktop Code UI assigns each worktree session a name (e.g., `lucid-euler`). Record this in the session registry table alongside the issue ID — it identifies the branch (`claude/{session-name}`) and helps trace which session produced which PR.

### Conflict Resolution

- **File-level conflicts:** Human resolves manually. The session that finished second rebases onto the first.
- **Semantic conflicts** (both sessions made valid but incompatible design decisions): Escalate to human. Do not auto-resolve. Document both approaches in the master plan issue so the human has full context for the decision.
- **Linear race conditions:** If two sessions update the same issue, the later write wins. Avoid by assigning one issue per session.
- **Failed sessions:** If a parallel session fails or is abandoned, update its status in the session registry to "Failed" with a brief reason. The next batch should not depend on failed session outputs without human review.

## Agent-Aware Dispatch

When dispatching parallel sessions to different agents, additional constraints apply:

- **One agent per session.** Do not assign the same issue to multiple agents simultaneously. Linear assignment is exclusive.
- **Branch conventions differ.** Claude Code uses `claude/{issue-id}-{slug}`. External agents use their own conventions (Cursor: `cursor/{issue-id}`, Copilot: auto-named). Document the branch in the session registry.
- **Only Claude Code sessions have full CCC awareness.** External agents (cto.new, Cursor, Codex) do not read CCC skill files. Provide essential context (acceptance criteria, constraints) in the issue description, not in skill references. Use the Dispatch Issue Template from CONNECTORS.md § Agent Dispatch Protocol.
- **Feedback reconciliation.** If two agents produce PRs for related issues, follow the Feedback Reconciliation Protocol in **CONNECTORS.md § Agent Dispatch Protocol**. External agents do not have cross-session awareness.

> For agent adoption status, routing tables, the selection decision tree, and dispatch architecture, see **CONNECTORS.md § Agent Connectors**.

## 8.5 Deprecation: Local Dispatch Files

Local dispatch files (`batch*-dispatch-prompts.md`, `multi-agent-dispatch-prompts.md`, `linear-mastery-*-prompts.md`) are **deprecated**. Existing files are retained for historical reference but **all new dispatch prompts must be Linear sub-issues**.

| Old Pattern (Deprecated) | New Pattern |
|--------------------------|------------|
| Write dispatch prompt to `~/.claude/plans/batch1-dispatch-prompts.md` | Create sub-issue under master plan issue |
| Human copy-pastes from local file | Human reads sub-issue or delegates to Tembo |
| Post-batch results appended to file bottom | Close sub-issue with evidence comment |
| No lifecycle tracking | Full Linear lifecycle (Todo → Done) |

## 9. @mention Feedback for Review Findings

When an adversarial review produces findings that need agent implementation (see `review-response/SKILL.md` Section 7: Review Finding Dispatch):

1. **RDR posted as Linear comment** on the reviewed issue
2. **Human fills Decision column** (agree / override / defer / reject)
3. **For each `agreed` finding:** Create a sub-issue under the reviewed issue with the finding details as description
4. **Agent dispatch via @mention:** Post a comment on the sub-issue: `@tembo Implement: [finding description]` (for trivial/small findings) or assign to a Claude Code session (for medium+ findings)
5. **Agent implements**, opens PR, sub-issue moves to Done

**Constraint:** Max 1 app user @mention per Linear comment. Multiple findings requiring different agents → multiple separate comments.

**Tembo integration:** For sub-issues delegated to Tembo, the dispatch is fully automatic — Tembo picks up the delegated issue, runs in sandbox, and opens a PR.

## Relationship to Agent Teams

Claude Code's native **Agent Teams** (`TeamCreate`, `SendMessage`, `TaskUpdate`, shared task lists) provides in-session parallelism — multiple agents working concurrently within a single Claude Code instance. CCC parallel-dispatch provides cross-session parallelism — independent Claude Code sessions on separate branches.

**Agent Teams is the preferred approach for in-session multi-agent work.** When work can be accomplished within one session and one repo without branch conflicts, use Agent Teams rather than launching separate sessions. This avoids the overhead of worktree setup, session coordination, and merge reconciliation.

| Factor | Use Agent Teams | Use Parallel-Dispatch |
|--------|----------------|----------------------|
| Same repo, no file conflicts | Yes | Overkill |
| Research fan-out (multiple sources) | Yes | Only if each track needs its own session context |
| Multi-issue implementation | Only if issues share a branch | Yes (one branch per issue) |
| CI-gated work (each unit needs green CI) | No | Yes |
| Different repositories | No | Yes |
| Needs persistent branch per unit of work | No | Yes |

**Coexistence:** Agent Teams and parallel-dispatch can coexist. A parallel-dispatch session may itself use Agent Teams internally for its own subagent fan-out. The dispatch protocol (Sections 1-9 above) governs the cross-session layer; Agent Teams governs the within-session layer. See `exec:swarm` in the **execution-modes** skill for the in-session decision guide.

## Cross-Skill References

- **execution-modes** -- `exec:swarm` for 5+ independent subagent tasks within a single session; parallel dispatch is for multiple independent _sessions_. See also the **Agent Selection** section for mode-to-agent routing.
- **context-management** -- Session exit summary tables, subagent return discipline, context budget protocol
- **adversarial-review** -- Multi-model consensus protocol for reconciling parallel session outputs; Options A-H for review timing
- **execution-engine** -- State persistence across session boundaries via `.ccc-state.json` and `.ccc-progress.md`
- **spec-workflow** -- Master plan pattern governs the phase decomposition that feeds dispatch decisions
