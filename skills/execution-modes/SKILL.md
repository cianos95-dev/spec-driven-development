---
name: execution-mode-routing
description: |
  Taxonomy of 5 execution modes for AI-assisted development. Provides a decision heuristic for selecting the right mode based on scope clarity, risk level, parallelizability, and testability. Covers model routing for subagent delegation.
  Use when deciding how to implement a task, choosing between TDD and direct coding, routing work to subagents, or determining if a task needs human-in-the-loop pairing.
  Trigger with phrases like "what execution mode should I use", "should I use TDD or quick mode", "how should I implement this task", "is this a swarm task", "pair programming setup", "which model for subagents".
compatibility:
  surfaces: [code, cowork, desktop]
  tier: universal
---

# Execution Mode Routing

Every task entering implementation should be tagged with exactly one execution mode. The mode determines ceremony level, review cadence, agent autonomy, and model routing. Apply the `exec:*` label to the issue in `~~project-tracker~~` before starting work.

## The 5 Modes

### `exec:quick` -- Direct Implementation

**When:** Small, well-understood changes with obvious implementation paths. No ambiguity in requirements, no risk of breaking adjacent systems.

**Behavior:** Implement directly with minimal ceremony. No explicit test-first step (though existing tests must still pass). Commit and move on.

**Examples:** Fix a typo, update a dependency version, add a config flag, adjust a UI string, rename a variable across files.

**Guard rail:** If implementation takes longer than 30 minutes or reveals unexpected complexity, upgrade to `exec:tdd` or `exec:pair`.

---

### `exec:tdd` -- Test-Driven Development

**When:** Well-defined acceptance criteria that can be expressed as automated tests. The requirements are clear enough to write a failing test before writing implementation code.

**Behavior:** Strict red-green-refactor cycle:
1. Write a failing test that captures the acceptance criterion
2. Write the minimum code to make it pass
3. Refactor while keeping tests green
4. Repeat for each criterion

**Examples:** API endpoint with defined request/response contract, business logic with edge cases, data transformation pipeline, utility function with known inputs/outputs.

**Guard rail:** If you cannot express the requirement as a test, the scope is not well-defined enough for TDD. Drop to `exec:pair` to clarify requirements first.

---

### `exec:pair` -- Human-in-the-Loop Pairing

**When:** Complex logic where the scope is uncertain, requirements need exploration, or the task involves a learning opportunity. The agent acts as navigator; the human acts as driver (or vice versa).

**Behavior:** Iterative exploration with frequent check-ins. The agent proposes approaches, the human validates direction. Use Plan Mode or equivalent to establish shared understanding before committing to implementation.

**Model routing:** Use **opusplan** (`/model opusplan`) as the default. Opus handles the planning and approach discussions; Sonnet handles implementation after approval. See [Native Model Routing](#native-model-routing-opusplan).

**Examples:** Architectural decisions, novel integrations, unfamiliar APIs, research-heavy features, first implementation of a new pattern.

**Guard rail:** Define exit criteria up front. Pair sessions without clear goals degenerate into exploration without convergence. If the task becomes well-defined during pairing, upgrade to `exec:tdd`.

---

### `exec:checkpoint` -- Milestone-Gated Implementation

**When:** High-risk changes where mistakes are expensive or irreversible. Security-sensitive code, data migrations, breaking API changes, infrastructure modifications.

**Behavior:** Implementation proceeds in defined phases. At each milestone, the agent pauses for explicit human review and approval before continuing. No "I'll just finish this part" -- the checkpoint is a hard stop.

**Model routing:** Use **opusplan** (`/model opusplan`) as the default. Opus reasons through gate decisions and risk assessment; Sonnet executes implementation between gates. See [Native Model Routing](#native-model-routing-opusplan).

**Checkpoints to define up front:**
- After schema/migration design, before execution
- After security-sensitive logic, before deployment
- After breaking change implementation, before merge
- After data transformation logic, before running on production data

**Session handoff at gates:** At each checkpoint gate, run `/ccc:checkpoint` to capture task state, persist progress to `.ccc-progress.md`, and update the Linear issue in place before pausing for review. This ensures the session can be resumed cleanly if the review spans a context boundary. See [commands/checkpoint.md](../../commands/checkpoint.md) and the [checkpoint protocol reference](../../skills/session-exit/references/checkpoint-protocol.md).

**Examples:** Database migration, auth system changes, payment integration, API versioning, infrastructure provisioning, data backfill scripts.

**Guard rail:** If a checkpoint reveals the approach is wrong, do not proceed. Revert to planning. Sunk cost is not a reason to continue a flawed approach.

---

### `exec:swarm` -- Multi-Agent Orchestration

**When:** 5 or more independent tasks that can be executed in parallel with no dependencies between them. The overhead of coordination is justified by the parallelism gain.

**Behavior:** Decompose the work into independent units. Dispatch each to a subagent. Collect results. Reconcile any conflicts. The orchestrating agent manages the fan-out/fan-in lifecycle.

**Examples:** Updating 10 configuration files with a consistent change, implementing 6 independent API endpoints, applying a code pattern across 8 modules, bulk research across multiple sources.

**Guard rail:** If tasks have dependencies, they are not suitable for swarm. Sequence dependent tasks; only parallelize truly independent work. If fewer than 5 tasks, the coordination overhead of swarm mode exceeds its benefit -- use a simpler mode.

#### Agent Teams vs CCC Parallel-Dispatch

Two parallelism mechanisms exist. They solve different problems:

| | Agent Teams | CCC Parallel-Dispatch |
|---|---|---|
| **Scope** | In-session parallelism | Cross-session worktree parallelism |
| **Primitives** | `TeamCreate`, `SendMessage`, `TaskUpdate`, shared task lists | Independent Claude Code sessions on separate branches |
| **Coordination** | Real-time messaging between agents within one Claude Code instance | No cross-talk; sessions are fully isolated |
| **Best for** | Research, review, multi-file changes in the same repo | Multi-issue implementation, CI-gated work, different repos |
| **Branch model** | Single branch (agents share the working tree) | One branch per session (worktree isolation) |
| **Context** | Shared — agents can read each other's task list and send messages | Independent — each session has its own context window |

**Decision guide:**

```
Is the work within one session and one repo?
|
+-- YES --> Can agents share a working tree without conflicts?
|           |
|           +-- YES --> Agent Teams (TeamCreate + SendMessage)
|           +-- NO  --> Parallel-Dispatch (worktree sessions)
|
+-- NO --> Does work span branches, repos, or need CI isolation?
           |
           +-- YES --> Parallel-Dispatch
           +-- NO  --> Agent Teams
```

**When to use Agent Teams within `exec:swarm`:** Agent Teams is the preferred mechanism for in-session multi-agent work. Use it when dispatching 5+ independent subagent tasks that all operate within the current session — research fan-out, parallel file edits, bulk review. The orchestrating agent creates a team, spawns teammates, assigns tasks via the shared task list, and collects results via messages.

**When to escalate to parallel-dispatch:** If the work requires separate Git branches (conflicting file edits), CI pipeline validation per unit of work, or spans multiple repositories, use CCC parallel-dispatch instead. See the **parallel-dispatch** skill for the full dispatch protocol.

---

### `exec:spike` -- Research-First Exploration

**When:** The task requires investigation before implementation can begin. The primary output is knowledge (a document, analysis, or recommendation), not code. Spikes answer "should we?" and "how should we?" before "build it."

**Behavior:** Time-boxed exploration with a defined deliverable. The agent investigates, surveys, or evaluates, then produces a structured artifact (Linear document, research brief, gap analysis). No implementation code is written during a spike -- the output informs subsequent implementation issues.

**Examples:** Competitive landscape survey, library evaluation, architecture feasibility study, API compatibility assessment, pattern extraction from external repos, configuration surface research.

**Guard rail:** Spikes must be time-boxed (default: 1 session). If a spike needs more time, split it into focused sub-spikes rather than extending. Every spike ends with a concrete recommendation, even if "needs more investigation" -- in which case, create a follow-up spike with a narrower scope.

**Key principle: Research spikes run before their dependent implementation issues.** When an implementation issue references research that hasn't been done, the spike takes priority. This prevents building on assumptions that haven't been validated.

---

## Decision Heuristic

Use this tree to select the appropriate mode. Start at the root and follow the branches:

```
Is this exploration/investigation (output is knowledge, not code)?
|
+-- YES --> exec:spike
|
+-- NO --> Is the scope well-defined with clear acceptance criteria?
           |
           +-- YES --> Are there 5+ independent tasks?
           |           |
           |           +-- YES --> exec:swarm
           |           |
           |           +-- NO --> Is it testable (can you write a failing test)?
           |                      |
           |                      +-- YES --> exec:tdd
           |                      |
           |                      +-- NO --> exec:quick
           |
           +-- NO --> Is it high-risk (security, data, breaking changes)?
                      |
                      +-- YES --> exec:checkpoint
                      |
                      +-- NO --> exec:pair
```

When in doubt, prefer `exec:pair`. It is the safest default because it keeps a human in the loop while the scope crystallizes. Modes can be upgraded mid-task (pair to tdd, quick to checkpoint) but should not be downgraded without justification.

### Research-First Sequencing Rule

When dispatching a batch of work, apply this ordering:

1. **Spikes first.** Any `exec:spike` or `type:spike` issue runs before implementation issues that depend on its findings.
2. **Parallel spikes.** Independent spikes run concurrently. A spike blocks only issues that reference it as input.
3. **Implementation after intel.** Do not begin `exec:tdd`, `exec:quick`, or `exec:checkpoint` on a feature whose design was informed by an unresolved spike.

This prevents "build then discover" -- the most expensive failure mode in multi-session plans. When a master plan has both research and implementation phases, research phases run first by default. The human can override this ordering with explicit justification.

## Native Model Routing (opusplan)

Claude Code provides a built-in model routing mode called **opusplan**. It uses Opus for planning and Sonnet for execution — matching the cognitive profile of CCC's `exec:pair` and `exec:checkpoint` modes where high-quality reasoning matters during design but raw throughput matters during implementation.

**Activating opusplan:** Run `/model opusplan` in a Claude Code session. This sets the model routing for the remainder of the session.

**Recommended defaults by execution mode:**

| Exec Mode | Recommended Model Routing | Rationale |
|-----------|--------------------------|-----------|
| `exec:quick` | Default (single model) | No planning phase; overhead of model switching is not justified |
| `exec:tdd` | Default (single model) | Red-green-refactor is implementation-heavy; consistent model avoids context switching |
| `exec:pair` | **opusplan** | Opus handles the interactive planning and approach discussions; Sonnet handles file edits and implementation after approval |
| `exec:checkpoint` | **opusplan** | Opus reasons through gate decisions and risk assessment; Sonnet executes between gates |
| `exec:swarm` | Default (single model) | Subagent model routing (see below) handles the tier mix; the orchestrator stays on one model |
| `exec:spike` | Default (single model) | Research is primarily reading and synthesis — consistent model produces more coherent analysis |

**Why opusplan over custom model switching:** CCC previously documented manual model tier selection for subagents (see below). opusplan replaces the need for custom model switching in the *orchestrating session itself* for pair and checkpoint modes. Subagent model routing (fast/balanced/highest-quality tiers) still applies when delegating to Task subagents — opusplan governs the main session's own model, not subagent models.

## Model Routing for Subagents

When delegating subtasks to subagents, match the model tier to the cognitive demand:

| Model Tier | Use For | Characteristics |
|------------|---------|-----------------|
| **Fast/cheap** (e.g., haiku) | File scanning, data retrieval, simple search, bulk reads | Lowest cost, highest throughput. Use for Tier 1 delegation. |
| **Balanced** (e.g., sonnet) | Code review synthesis, PR summaries, test analysis | Good quality-to-cost ratio. Use for review and analysis tasks. |
| **Highest quality** (e.g., opus) | Critical implementation, complex reasoning, architectural decisions | Highest quality, highest cost. Reserve for tasks where correctness matters most. |

**Routing by execution mode:**

- `exec:quick` -- Direct execution, no subagent needed
- `exec:tdd` -- Fast model for test scaffolding, highest quality for implementation logic
- `exec:pair` -- Highest quality for all interactions (human is watching)
- `exec:checkpoint` -- Highest quality for implementation, balanced for review summaries
- `exec:swarm` -- Fast model for independent leaf tasks, balanced for reconciliation
- `exec:spike` -- Balanced model for research, fast model for bulk reads (repo scanning, API surveys)

## Integration with Issue Labels

Apply the execution mode label when transitioning an issue from spec-ready to implementation:

1. During planning or triage, evaluate the task against the decision heuristic
2. Apply the appropriate `exec:*` label in `~~project-tracker~~`
3. The label informs session planning: `exec:swarm` tasks need longer sessions; `exec:quick` tasks can be batched; `exec:checkpoint` tasks need human availability windows
4. If the mode changes mid-implementation, update the label and document why

The execution mode also informs estimation. Quick tasks are typically under 1 hour. TDD tasks are 1-4 hours. Pair sessions are 1-2 hours per sitting. Checkpoint tasks span multiple sessions. Swarm tasks vary by fan-out count but each leaf should be quick or tdd-sized. Spike tasks are 1-2 sessions (time-boxed) with deliverable = document, not code.

## T1-T4 Issue Classification

Before selecting an execution mode, classify the issue by its relationship to agent architecture. This tier determines implementation priority, phasing, and which execution modes are appropriate.

| Tier | Name | Definition | Implementation Priority |
|------|------|-----------|------------------------|
| **T1** | Agent-native | Features that ARE the agent system -- cannot exist without multi-agent orchestration | Phase 0-1 (core agent features) |
| **T2** | Agent-enhanced | Features that exist independently but are significantly better with agent augmentation | Phase 2-3 (augmentation layer) |
| **T3** | Agent-adjacent | Features with minor agent convenience but work fine without agents | Phase 3+ (optional agent convenience) |
| **T4** | Non-agent | Traditional CRUD/UI/infra with zero agent dependency | Any phase (traditional implementation) |

**T1 examples:** Agent orchestration engine, tool routing, multi-agent coordination protocol, safety monitor, agent memory system.

**T2 examples:** Literature review (works manually, dramatically better with agent-driven search and synthesis), data pipeline (runnable without agents, but agent augmentation enables adaptive routing).

**T3 examples:** Form auto-fill suggestions, smart defaults in settings, notification grouping -- all work fine without agents, agents add minor polish.

**T4 examples:** User authentication, database schema, static page layout, dependency updates, CI/CD configuration.

### Three-Question Promotion Test

When an issue seems like it could be a higher tier than initially classified, apply this test sequentially:

```
1. "Does this feature REQUIRE multi-agent coordination to function at all?"
   --> YES = T1 (agent-native)
   --> NO  = continue

2. "Would agent augmentation change the fundamental user experience?"
   --> YES = T2 (agent-enhanced)
   --> NO  = continue

3. "Could an agent add minor convenience without changing the core feature?"
   --> YES = T3 (agent-adjacent)
   --> NO  = T4 (non-agent)
```

**Common misclassification:** Features that use AI (LLM calls, embeddings) are not automatically T1. A feature that calls an LLM to summarize text is T2 or T3 -- it does not require multi-agent orchestration. Only features that require agents coordinating with each other belong in T1.

### Tier-to-Mode Mapping

The classification tier constrains which execution modes are appropriate:

| Tier | Recommended Modes | Rationale |
|------|-------------------|-----------|
| **T1** | `exec:pair`, `exec:checkpoint` | High complexity, architectural risk, needs human-in-the-loop validation at design and implementation |
| **T2** | `exec:tdd` | Enhancement layer with clear interfaces -- testable acceptance criteria at the augmentation boundary |
| **T3** | `exec:quick`, `exec:tdd` | Straightforward features with optional agent integration; TDD if the agent convenience path has edge cases |
| **T4** | `exec:quick` | Traditional implementation with no agent dependency; fast and well-understood |

This mapping is a default, not a mandate. A T4 database migration is still `exec:checkpoint` if it touches production data. The tier narrows the search space; the decision heuristic (above) makes the final call.

## Retry Budget

Every implementation attempt has a retry budget. The budget prevents brute-force debugging loops and ensures escalation happens before context is exhausted.

**Rules:**

1. **Maximum 2 failed approaches before escalation.** An "approach" is a distinct strategy for solving the problem, not a single command retry.
2. **After first failure:** Try a different approach. Document what failed and why in a comment on the issue or in the session plan. The documentation must include: what was attempted, what the failure symptom was, and why the approach did not work.
3. **After second failure:** STOP. Escalate to a human with evidence of both approaches tried. Present the two failure reports and ask for direction. Do not attempt a third approach without explicit human approval.

**Anti-patterns:**

- **Brute force retry** -- Trying the same approach 3+ times hoping for different results. If the same command or strategy failed twice, a third attempt without a changed variable is wasted context.
- **Approach amnesia** -- Not documenting what was tried before trying something new. Without a failure log, the agent (or a future session) may repeat the same dead-end approach. Always write down what failed before pivoting.

**Budget applies per-issue, not per-session.** If a session ends mid-retry, the next session inherits the retry count. Document retry state in the issue comment so it survives session boundaries.

## Agent Selection

Agent routing, adoption status, the selection decision tree, and the free tier bundle are maintained in **CONNECTORS.md** (Agent Connectors section). That file is the single source of truth for which agents are available, how they are dispatched via Linear delegation, and their cost/reactivity profiles.

When selecting an agent for an execution mode, consult CONNECTORS.md § Agent Routing by Execution Mode after determining the execution mode using the decision heuristic above.

## Effort Level Mapping

The CCC stop handler automatically injects `CLAUDE_CODE_EFFORT_LEVEL` based on the active execution mode. This controls reasoning depth in the continued session — users do not set it manually when using CCC execution modes.

| Execution Mode | Effort Level | Rationale |
|----------------|-------------|-----------|
| `exec:quick` | `low` | Small, obvious changes — minimize latency |
| `exec:tdd` | `medium` | Structured implementation with test cycles |
| `exec:spike` | `medium` | Research and exploration — balanced depth |
| `exec:pair` | `high` | Human watching — maximum reasoning quality |
| `exec:checkpoint` | `high` | High-risk changes — thoroughness over speed |
| `exec:swarm` | `high` | Orchestration complexity — full reasoning |

**Interaction with `/fast` toggle:** The `/fast` toggle in Claude Code controls output speed (same model, faster output). It is independent of effort level. A session can be `/fast` ON with `high` effort — the model reasons deeply but streams faster. The two settings are orthogonal: effort level controls reasoning depth, `/fast` controls output latency.

**Injection mechanism:** The stop handler reads `executionMode` from `.ccc-state.json`, maps it to an effort level, and includes `CLAUDE_CODE_EFFORT_LEVEL` in the block response's `env` field. The next session inherits this environment variable automatically.

## Cross-Skill References

- **CONNECTORS.md** -- Agent catalog, dispatch protocol, routing tables, adoption status, selection decision tree, free tier bundle, feedback reconciliation
- **parallel-dispatch** -- When a master plan has 2+ independent phases, use parallel dispatch rules to launch concurrent sessions. `exec:swarm` handles parallelism _within_ a session via subagents; parallel dispatch handles parallelism _across_ sessions.
