# Replan Protocol

## Disposable Plan Principle

The task decomposition produced by `/ccc:decompose` is a hypothesis, not a contract. During execution, the agent discovers things the planner could not have known: existing utilities, unexpected dependencies, acceptance criteria already met by prior tasks.

### Authority Hierarchy

When sources of truth conflict during execution, resolve in this order (highest authority first):

| Priority | Source | Reasoning |
|----------|--------|-----------|
| 1 (highest) | `.ccc-progress.md` | Reflects what was actually built and learned |
| 2 | Code state (git) | The ground truth of what exists |
| 3 | Spec (acceptance criteria) | The "what", not the "how" |
| 4 | Task list (decomposition) | A plan that may already be stale |
| 5 (lowest) | Linear sub-issues | Administrative artifacts, not execution authority |

### When to Replan

The agent should signal `REPLAN` (instead of `TASK_COMPLETE`) when:

- **2+ remaining tasks are invalid** — the codebase already has the functionality, or a dependency makes them unnecessary
- **An existing solution was discovered** — a utility, library, or pattern that renders planned work redundant
- **An unseen dependency emerged** — remaining tasks cannot proceed in the planned order

The agent should NOT replan when:

- Only 1 task needs minor adjustment (adapt and complete it)
- The current task is simply hard (that is what the retry budget is for)
- Cosmetic differences from the plan (naming, file locations) exist but the intent is met

### Replan Protocol

When `REPLAN` is enabled in preferences and the agent signals `REPLAN`:

1. The stop hook detects `REPLAN` in the transcript (checked before `TASK_COMPLETE`)
2. State is updated: `replanCount` increments, phase set to `replan`
3. A new session starts with a planning-specific prompt: re-read the spec and `.ccc-progress.md`, compare completed work against acceptance criteria, and regenerate remaining tasks
4. After replanning, the phase returns to `execution` and the loop continues with the new task list

Replan is capped at `max_replans_per_session` (default: 2) to prevent infinite loops.

### Linear Sync After Replan

After a replan, sub-issues in Linear are updated only after the replanned tasks are committed to `.ccc-progress.md` and `.ccc-state.json`. This ensures Linear reflects reality, not optimistic plans.

## The REPLAN Signal

The agent outputs `REPLAN` (exact string, case-sensitive) when the task decomposition is no longer valid and remaining tasks need to be regenerated.

### Pre-signal checklist

Before outputting `REPLAN`, the agent must:

1. **Document the reason** in `.ccc-progress.md` under Learnings: what was discovered, why the plan is invalid, what the codebase already provides.
2. **Commit any completed work.** Partial progress from the current task should be committed before replanning.
3. **Do NOT output `TASK_COMPLETE` in the same session.** `REPLAN` and `TASK_COMPLETE` are mutually exclusive. The stop hook checks for `REPLAN` first.

### What happens when REPLAN is signaled

1. The stop hook detects `REPLAN` in the transcript
2. If replan is disabled in preferences or max replans reached, the signal is ignored (task continues as incomplete)
3. If allowed: `replanCount` increments, `phase` set to `replan`, `globalIteration` increments
4. A new session starts with a planning-specific prompt (re-read spec + progress, compare against acceptance criteria, regenerate tasks)
5. The agent updates `.ccc-state.json` (set phase back to `execution`, update `totalTasks` and `taskIndex`)
6. Execution continues with the new task list

### Replan limits

| Setting | Default | Source |
|---------|---------|--------|
| `replan.enabled` | `true` | `.ccc-preferences.yaml` |
| `replan.max_replans_per_session` | `2` | `.ccc-preferences.yaml` |

When max replans is reached, the loop halts with a message directing the user to review `.ccc-progress.md` and adjust tasks manually.
