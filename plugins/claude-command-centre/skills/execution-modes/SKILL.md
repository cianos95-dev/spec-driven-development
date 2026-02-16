---
name: execution-mode-routing
description: |
  Taxonomy of 5 execution modes for AI-assisted development. Provides a decision heuristic for selecting the right mode based on scope clarity, risk level, parallelizability, and testability. Covers model routing for subagent delegation.
  Use when deciding how to implement a task, choosing between TDD and direct coding, routing work to subagents, or determining if a task needs human-in-the-loop pairing.
  Trigger with phrases like "what execution mode should I use", "should I use TDD or quick mode", "how should I implement this task", "is this a swarm task", "pair programming setup", "which model for subagents".
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

**Examples:** Architectural decisions, novel integrations, unfamiliar APIs, research-heavy features, first implementation of a new pattern.

**Guard rail:** Define exit criteria up front. Pair sessions without clear goals degenerate into exploration without convergence. If the task becomes well-defined during pairing, upgrade to `exec:tdd`.

---

### `exec:checkpoint` -- Milestone-Gated Implementation

**When:** High-risk changes where mistakes are expensive or irreversible. Security-sensitive code, data migrations, breaking API changes, infrastructure modifications.

**Behavior:** Implementation proceeds in defined phases. At each milestone, the agent pauses for explicit human review and approval before continuing. No "I'll just finish this part" -- the checkpoint is a hard stop.

**Checkpoints to define up front:**
- After schema/migration design, before execution
- After security-sensitive logic, before deployment
- After breaking change implementation, before merge
- After data transformation logic, before running on production data

**Examples:** Database migration, auth system changes, payment integration, API versioning, infrastructure provisioning, data backfill scripts.

**Guard rail:** If a checkpoint reveals the approach is wrong, do not proceed. Revert to planning. Sunk cost is not a reason to continue a flawed approach.

---

### `exec:swarm` -- Multi-Agent Orchestration

**When:** 5 or more independent tasks that can be executed in parallel with no dependencies between them. The overhead of coordination is justified by the parallelism gain.

**Behavior:** Decompose the work into independent units. Dispatch each to a subagent. Collect results. Reconcile any conflicts. The orchestrating agent manages the fan-out/fan-in lifecycle.

**Examples:** Updating 10 configuration files with a consistent change, implementing 6 independent API endpoints, applying a code pattern across 8 modules, bulk research across multiple sources.

**Guard rail:** If tasks have dependencies, they are not suitable for swarm. Sequence dependent tasks; only parallelize truly independent work. If fewer than 5 tasks, the coordination overhead of swarm mode exceeds its benefit -- use a simpler mode.

---

## Decision Heuristic

Use this tree to select the appropriate mode. Start at the root and follow the branches:

```
Is the scope well-defined with clear acceptance criteria?
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

## Integration with Issue Labels

Apply the execution mode label when transitioning an issue from spec-ready to implementation:

1. During planning or triage, evaluate the task against the decision heuristic
2. Apply the appropriate `exec:*` label in `~~project-tracker~~`
3. The label informs session planning: `exec:swarm` tasks need longer sessions; `exec:quick` tasks can be batched; `exec:checkpoint` tasks need human availability windows
4. If the mode changes mid-implementation, update the label and document why

The execution mode also informs estimation. Quick tasks are typically under 1 hour. TDD tasks are 1-4 hours. Pair sessions are 1-2 hours per sitting. Checkpoint tasks span multiple sessions. Swarm tasks vary by fan-out count but each leaf should be quick or tdd-sized.

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

## Cross-Skill References

- **CONNECTORS.md** -- Agent catalog, dispatch protocol, routing tables, adoption status, selection decision tree, free tier bundle, feedback reconciliation
- **parallel-dispatch** -- When a master plan has 2+ independent phases, use parallel dispatch rules to launch concurrent sessions. `exec:swarm` handles parallelism _within_ a session via subagents; parallel dispatch handles parallelism _across_ sessions.
