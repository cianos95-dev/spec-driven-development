# Configuration & Operations

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SDD_STATE_FILE` | `.ccc-state.json` | Override state file path (relative to project root) |
| `SDD_PROGRESS_FILE` | `.ccc-progress.md` | Override progress file path (relative to project root) |
| `SDD_MAX_TASK_ITER` | `5` | Maximum iterations per task before blocking |
| `SDD_MAX_GLOBAL_ITER` | `50` | Maximum total iterations before hard stop |

## Hook registration

The execution engine stop hook is registered in the project's hooks configuration:

```json
{
  "hooks": {
    "Stop": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": ".claude/hooks/ccc-execution-stop.sh"
      }]
    }]
  }
}
```

This hook coexists with the general hygiene stop hook defined in hook-enforcement. The execution engine hook runs first (checks for `TASK_COMPLETE` and decides whether to block or allow), then the hygiene hook runs if the session is actually ending (status normalization, closing comments).

## Resuming After Interruption

The execution engine is designed to survive interruptions gracefully.

### Interruption scenarios

| Scenario | State Preserved | Resume Behavior |
|----------|----------------|-----------------|
| Agent crashes mid-task | `.ccc-state.json` points to current task, `taskIteration` not yet incremented | `/ccc:go` resumes from current task. Work since last commit is lost. |
| Manual stop (Ctrl+C) | Same as crash | Same as crash |
| Context exhaustion | Stop hook fires, increments `taskIteration` | `/ccc:go` resumes, retrying current task with fresh context |
| Machine restart | State files persist on disk | `/ccc:go` resumes from last known position |

### Resume protocol

1. Run `/ccc:go` in the project directory.
2. The command reads `.ccc-state.json` and determines the current position.
3. If `awaitingGate` is set, it tells the user which gate is needed.
4. If `taskIteration >= maxTaskIterations`, it tells the user the task is blocked.
5. Otherwise, it resumes execution from the current `taskIndex`.
6. The new session reads `.ccc-progress.md` for context from prior tasks.

### No work is lost

The stop hook only advances `taskIndex` after verifying `TASK_COMPLETE` in the transcript. This means:

- Crashes leave state pointing at the incomplete task
- The task is retried, not skipped
- Committed work from prior tasks is safe in git
- The progress log preserves all learnings from prior sessions

## Linear Status Syncing

The execution engine keeps the Linear issue in sync with loop state.

| Loop Event | Linear Update |
|------------|---------------|
| `/ccc:go` starts execution | Status to In Progress, label to `spec:implementing` |
| Task completes | Comment: "Task N/M complete: [description] -- [commit hash]" |
| Gate reached | Comment: "Awaiting Gate N: [gate description]" |
| Task blocked (retry exhausted) | Comment: "Task N blocked after M attempts. Manual intervention needed." |
| All tasks complete | Comment: "All N tasks complete. Opening PR for Gate 3 review." |
| Execution resumes after interruption | Comment: "Resuming execution from task N/M." |

Comments are brief status updates per the issue content discipline rules. Detailed evidence goes in `.ccc-progress.md`, not in issue comments.

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| Loop does not start | No `.ccc-state.json` exists | Run `/ccc:go` or `/ccc:start` to create state from the decomposed task list |
| Loop does not advance | Agent did not output `TASK_COMPLETE` | Ensure the agent outputs the exact string `TASK_COMPLETE` after finishing the task |
| Task keeps retrying | Task fails verification (tests, lint, build) | Fix the underlying issue. If stuck, increase `SDD_MAX_TASK_ITER` or fix manually and resume. |
| Loop stops unexpectedly | `pair` or `swarm` execution mode | These modes disable the loop by design. This is expected behavior, not a bug. |
| State file corrupt | Failed write during hook execution | Delete `.ccc-state.json` and re-run `/ccc:go` to recreate from the task list |
| Fresh context not working | Stop hook not registered | Verify `hooks/hooks.json` includes the execution engine stop hook configuration |
| Progress file missing | Deleted or moved | `/ccc:go` creates a new one, but learnings from prior sessions are lost. Check git history. |
| Global iteration cap hit | Many task retries consuming the budget | Review which tasks are failing. Fix root causes rather than increasing the cap. |
| Gate blocking unexpectedly | `awaitingGate` set in state | Complete the gate review, then clear `awaitingGate` and run `/ccc:go` |
