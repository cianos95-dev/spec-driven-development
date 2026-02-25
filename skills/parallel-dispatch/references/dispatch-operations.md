# Dispatch Operations Reference

Operational details for parallel session dispatch. The parent SKILL.md contains the core decision framework, dispatch template, and coordination overview. This file has the detailed procedures.

## Session Mode Mapping

Each dispatched session needs a **UI launch mode** — the permission level selected when starting the Claude Code session. The mapping depends on two factors: the `exec:*` label AND whether the task produces code changes.

### Primary mapping (tasks that produce code/file changes)

| Exec Mode | Launch As | Agent Options | Rationale |
|-----------|-----------|---------------|-----------|
| `quick` | Bypass permissions | Claude Code, Factory, cto.new, Copilot | Well-defined, no ambiguity, just execute |
| `tdd` | Bypass permissions | Claude Code, Cursor, Amp | Red-green-refactor is autonomous once started |
| `pair` | Plan mode | Claude Code | Explore + get human input, then implement after approval |
| `checkpoint` | Ask permissions | Claude Code | Pauses at gates, human approves each step |
| `swarm` | Bypass permissions | Claude Code, Factory | Subagent orchestration is autonomous |
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

## Plan File Naming Convention

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

## Session Naming

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

## Cross-System Feedback Routing

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
| Factory | Implementation PR (4 Droids: Knowledge, Code, Reliability, Product) | Review via standard PR process; native Linear integration |
| Amp | Implementation PR or branch | Review via standard PR process; CLI/desktop only |

For parallel sessions: each session monitors feedback only for its own issue/PR. Cross-session feedback (e.g., Sentry error caused by interaction between two parallel PRs) routes to the human for triage.

## Coordination Protocol: During Execution

- **Worktrees:** Each worktree session operates in an isolated checkout (e.g., `~/.claude/worktrees/claude-command-centre-cia-541/`). The main working directory at `~/Repositories/claude-command-centre/` remains untouched. When complete, the session's branch is merged via PR.
- **Branch naming:** `{agent}/{issue-id}-{slug}` (e.g., `claude/cia-387-dispatch-rules`). Worktree sessions auto-create branches.
- **Linear status:** Each session marks its issue In Progress immediately on start
- **No cross-talk:** Sessions do not read each other's branches or issue comments during execution
- **Merge order:** Define merge order in the dispatch table if sessions touch adjacent code. First-merged session's branch becomes the base for subsequent merges.

## Coordination Protocol: Session Exit

Each session must, on completion:

1. Mark its Linear issue Done or In Review
2. Write a session summary to the plan file (see context-management session exit tables)
3. Update the session registry table in the master plan
4. If merge conflicts are anticipated, flag in a Linear comment on the master plan issue -- human resolves

## Merging Completed Sessions (Desktop Code UI)

When a session finishes, the Desktop Code UI presents merge controls at the bottom of the session:

| Session type | UI shows | What to do |
|-------------|----------|------------|
| **Worktree session** | `main <- claude/{session-name}` + **"Commit changes"** | Click to push branch and create PR. Review diff in GitHub, then merge. This is the standard path. |
| **Non-worktree on main** | `main <- main` + **"Create PR"** | Do NOT click "Create PR" (main->main PR is meaningless). Instead, push main directly via terminal when ready: `git push`. |
| **Factory / external agent** | N/A (managed by agent platform) | Factory auto-creates PR. Review and merge in GitHub. |

**Worktree sessions are preferred** precisely because they produce clean PRs with reviewable diffs. The "Commit changes" button is the expected exit action for worktree dispatch sessions.

**Session name tracking:** The Desktop Code UI assigns each worktree session a name (e.g., `lucid-euler`). Record this in the session registry table alongside the issue ID — it identifies the branch (`claude/{session-name}`) and helps trace which session produced which PR.

## Conflict Resolution

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

## Deprecation: Local Dispatch Files

Local dispatch files (`batch*-dispatch-prompts.md`, `multi-agent-dispatch-prompts.md`, `linear-mastery-*-prompts.md`) are **deprecated**. Existing files are retained for historical reference but **all new dispatch prompts must be Linear sub-issues**.

| Old Pattern (Deprecated) | New Pattern |
|--------------------------|------------|
| Write dispatch prompt to `~/.claude/plans/batch1-dispatch-prompts.md` | Create sub-issue under master plan issue |
| Human copy-pastes from local file | Human reads sub-issue or delegates to Factory |
| Post-batch results appended to file bottom | Close sub-issue with evidence comment |
| No lifecycle tracking | Full Linear lifecycle (Todo -> Done) |

## @mention Feedback for Review Findings

When an adversarial review produces findings that need agent implementation (see `review-response/SKILL.md` Section 7: Review Finding Dispatch):

1. **RDR posted as Linear comment** on the reviewed issue
2. **Human fills Decision column** (agree / override / defer / reject)
3. **For each `agreed` finding:** Create a sub-issue under the reviewed issue with the finding details as description
4. **Agent dispatch via @mention:** Post a comment on the sub-issue: `@factory Implement: [finding description]` (for trivial/small findings) or assign to a Claude Code session (for medium+ findings)
5. **Agent implements**, opens PR, sub-issue moves to Done

**Constraint:** Max 1 app user @mention per Linear comment. Multiple findings requiring different agents -> multiple separate comments.

**Factory integration:** For sub-issues delegated to Factory, the dispatch is fully automatic — Factory picks up the delegated issue via native Linear integration, runs with its 4 Droids (Knowledge, Code, Reliability, Product), and opens a PR.

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

**Coexistence:** Agent Teams and parallel-dispatch can coexist. A parallel-dispatch session may itself use Agent Teams internally for its own subagent fan-out. The dispatch protocol governs the cross-session layer; Agent Teams governs the within-session layer. See `exec:swarm` in the **execution-modes** skill for the in-session decision guide.
