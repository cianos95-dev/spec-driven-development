# Retry Budget

The execution engine enforces the CCC retry budget at the task level.

## Per-task iteration tracking

Each time the stop hook restarts a session for the same task (because `TASK_COMPLETE` was not found in the transcript), it increments `taskIteration`.

| Iteration | What Happens |
|-----------|-------------|
| 1 | First attempt. Normal execution. |
| 2 | Second attempt. Agent should try a different approach. |
| 3 | Third attempt. Agent has exhausted the CCC retry budget of 2 failed approaches. The continue prompt includes a warning: "Two approaches have failed. Document failures in progress log and try a fundamentally different strategy." |
| 4 | Fourth attempt. Escalation warning injected: "This is your last attempt before the task is blocked. If you cannot complete it, add to Blocked / Flagged in the progress log." |
| 5 (maxTaskIterations) | Hook blocks with an error. The loop stops. A message tells the user to fix the task manually, then resume with `/ccc:go`. |

## What counts as an "iteration"

An iteration is one complete session for a single task. If the agent crashes mid-task, that counts as an iteration (the stop hook increments regardless of why the session ended without `TASK_COMPLETE`).

## Budget reset

`taskIteration` resets to 1 when the task advances (i.e., `TASK_COMPLETE` is found and `taskIndex` increments). The budget is per-task, not cumulative.
