---
description: |
  Evaluate and execute evidence-based issue closure following the agent ownership protocol.
  Use when implementation is complete and you need to close an issue, verify closure conditions are met, or check if an issue qualifies for auto-close vs requires human confirmation.
  Trigger with phrases like "close this issue", "is this ready to close", "mark as done", "closure evidence for", "can I auto-close this", "wrap up this task".
argument-hint: "<issue ID>"
---

# Close Issue

Evaluate whether an issue meets closure conditions and execute the appropriate closure action based on the agent ownership protocol.

## Step 1: Fetch Issue Metadata

Retrieve the issue from the connected project tracker and collect:

- **Assignee** — Is this assigned to the agent or to a human?
- **Labels** — Check for `exec:*`, `spec:*`, `needs:human-decision`, and any other relevant labels.
- **Linked PRs** — How many PRs are linked? Are they merged?
- **Current status** — What state is the issue in?
- **Deployment status** — If a deployment pipeline is connected, check whether the latest deploy is green.
- **Parent issue** — Is this a sub-task of a larger epic?
- **Comments** — Review recent comments for any unresolved discussion.

## Step 2: Evaluate Closure Conditions

Apply the closure rules matrix to determine the appropriate action:

| Condition | Action |
|-----------|--------|
| Agent assignee + single PR + PR merged + deploy green | **AUTO-CLOSE** |
| Agent assignee + single PR + PR merged + no deploy pipeline | **AUTO-CLOSE** with note |
| Agent assignee + multiple PRs + all merged | **PROPOSE** closure with PR summary |
| Agent assignee + PR open (not merged) | **BLOCK** — cannot close, PR still in review |
| Human assignee (any condition) | **NEVER** auto-close — propose only |
| `needs:human-decision` label present | **PROPOSE** — always require human confirmation |
| `exec:pair` label present | **PROPOSE** with evidence — paired work needs human sign-off |
| No PR linked | **PROPOSE** with deliverable summary — explain what was done without a PR |
| Unresolved comments or discussion | **BLOCK** — flag unresolved threads |

If multiple conditions apply, use the **most restrictive** action.

## Step 3: Compose Closing Comment

Write a structured closing comment that includes all relevant evidence:

```
## Closure Summary

**Status:** [Auto-closing | Proposing closure | Blocked]
**Reason:** [Which closure rule applies]

### Deliverables
- PR: [link] — [title] ([merged/open])
- PR: [link] — [title] ([merged/open])  <!-- if multiple -->

### Deployment
- Deploy status: [green/pending/failed/not configured]
- Deploy URL: [link if available]

### Verification Evidence
- [ ] All acceptance criteria addressed
- [ ] Tests passing
- [ ] Build green
- [ ] No unresolved review comments

### What Was Delivered
[2-3 sentence summary of what this issue accomplished]
```

## Step 4: Execute

Based on the evaluation from Step 2:

### AUTO-CLOSE
- Post the closing comment on the issue.
- Transition the issue status to "Done" in the project tracker.
- No further action needed.

### PROPOSE
- Post the closing comment on the issue.
- Explicitly state: "This issue is ready for closure. Please confirm to close, or note any remaining concerns."
- Do NOT change the issue status. Wait for human confirmation.
- If the user confirms in the current session, proceed to close.

### BLOCK
- Post a comment explaining why the issue cannot be closed yet.
- List the specific blockers (open PR, unresolved comments, etc.).
- Suggest next steps to unblock.

## Step 5: Update Labels

After closure (or proposed closure):

1. **Spec lifecycle** — If the issue has `spec:implementing`, transition to `spec:complete`.
2. **Research readiness** — If applicable, verify the research label reflects the current state. Do NOT auto-transition to `expert-reviewed` (that always requires human decision).
3. **Parent issue** — Check if all sub-tasks of the parent epic are now closed. If so, propose closing the parent epic using the same closure protocol.
4. **Clean up** — Remove any transient labels that are no longer relevant (e.g., `auto:implement` if the implementation is complete).

## What If

| Situation | Response |
|-----------|----------|
| **Deployment status cannot be checked** | Treat as "no deploy pipeline configured." Auto-close is still permitted for agent-assigned single-PR issues, but add a note in the closing comment that deployment was not verified. |
| **No PRs are linked to the issue** | This is a research, design, or planning task. Use the PROPOSE path with a deliverable summary explaining what was produced (document, decision, analysis) instead of PR evidence. |
| **Issue was re-opened after a previous closure** | Acknowledge the premature closure. Review what was missed, address it, and do not re-close until the reason for re-opening has been fully resolved. |
