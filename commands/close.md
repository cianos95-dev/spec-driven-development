---
description: |
  Evaluate and execute evidence-based issue closure following the agent ownership protocol.
  Universal closure entry point — called by humans, session-exit, branch-finish (via closure-ready flag), webhooks, and Factory.
  Use when implementation is complete and you need to close an issue, verify closure conditions are met, or check if an issue qualifies for auto-close vs requires human confirmation.
  Trigger with phrases like "close this issue", "is this ready to close", "mark as done", "closure evidence for", "can I auto-close this", "wrap up this task".
argument-hint: "<issue ID>"
allowed-tools: Read, Grep, Bash
platforms: [cli, cowork]
---

# Close Issue

Evaluate whether an issue meets closure conditions and execute the appropriate closure action based on the agent ownership protocol. This is the **single entry point** for all closure — human-initiated, session-exit, branch-finish handoff, webhook, or Factory dispatch.

## Pre-Step: Gather Issue Context Bundle

Before executing this command, gather the issue context bundle (see `issue-lifecycle/references/issue-context-bundle.md`). Before closure evaluation, read comments for evidence that contradicts or supports closure — prior dispatch results, scope changes, re-open history, and unresolved questions all affect the closure decision.

## Step 1: Fetch Issue & PR Metadata

Retrieve the issue from the connected project tracker and collect:

- **Assignee** — Is this assigned to the agent or to a human?
- **Labels** — Check for `exec:*`, `spec:*`, `needs:human-decision`, `type:*`, and any other relevant labels.
- **Current status** — What state is the issue in?
- **Parent issue** — Is this a sub-task of a larger epic?
- **Comments** — Review recent comments for any unresolved discussion.

### PR Status Check

Query the linked repository for PR status. This determines which closure path applies:

| PR State | Meaning | Closure Impact |
|----------|---------|---------------|
| **Merged** | Code is in main branch | Proceed with closure evaluation |
| **Approved + CI green** | Ready to merge but not yet merged | Suggest: `gh pr merge <PR#> --squash` then re-run `/close` |
| **CI failing** | PR has failing checks | **BLOCK** — recovery: `gh pr checks <PR#>` to identify failures |
| **Changes requested** | Review feedback pending | **BLOCK** — recovery: `gh pr view <PR#> --comments` to see feedback |
| **No PR linked** | Non-code task or missing PR | Check issue type (see closure rules) |
| **Draft** | PR not ready for review | **BLOCK** — PR must be marked ready first |

If PR status cannot be determined (no GitHub integration, private repo, etc.), treat as "no PR linked" and note this in the closing comment.

### Deployment Status

If a deployment pipeline is connected, check whether the latest deploy is green. If not checkable, treat as "no deploy pipeline configured."

## Step 2: Evaluate Closure Conditions

Apply the closure rules from `references/closure-rules.md`. The rules determine one of three outcomes:

- **AUTO-CLOSE** — Agent proceeds to close the issue with evidence.
- **PROPOSE** — Agent posts evidence and asks for human confirmation.
- **BLOCK** — Agent posts blockers and recovery commands. Issue stays open.

### Quality Gate

Before applying the closure matrix, calculate the quality score:

```
total = (test_score * W_test) + (coverage_score * W_coverage) + (review_score * W_review)
```

Default weights: `W_test = 0.40`, `W_coverage = 0.30`, `W_review = 0.30`.

Check `.ccc-preferences.yaml` for project-level overrides:

```yaml
quality:
  weights:
    test: 0.50      # Override test weight
    coverage: 0.30
    review: 0.20
  thresholds:
    auto_close: 90   # Stricter threshold
    propose: 70
```

Apply threshold actions:

| Score | Action |
|-------|--------|
| >= `auto_close` threshold (default 80) | Auto-close eligible — apply closure matrix |
| >= `propose` threshold (default 60) | Propose closure regardless of matrix result |
| Below `propose` threshold | Block closure — list specific deficiencies |

If `.ccc-preferences.yaml` defines custom thresholds, use those values instead of the defaults.

If no review was conducted (e.g., `exec:quick` mode), the review dimension defaults to 70.

### Conflict Resolution

If the quality gate and the closure matrix disagree, use the most restrictive action: `BLOCK > PROPOSE > AUTO-CLOSE`.

## Step 2.5: Outcome Validation

Run the **outcome-validation** skill to evaluate whether the completed work achieved its intended business outcome.

### Skip Check

Outcome validation is **skipped** when any of these conditions is true:

- Issue has `type:chore` label
- Issue has `type:spike` label
- `--quick` flag was used (check `.ccc-state.json` or command flags)
- Issue has `exec:quick` label AND estimate is 2 points or less (unestimated counts as 1pt)

If skipped, log the reason (e.g., "Outcome validation: Skipped (type:chore)") and proceed to Step 3.

### Run Validation

If not skipped, execute the four sequential persona passes defined in the outcome-validation skill:

1. **Customer Advocate** — Does the delivered feature solve the user's problem?
2. **CFO Lens** — Was the investment proportionate to the value?
3. **Product Strategist** — Does this advance the product direction?
4. **Skeptic** — Are the prior verdicts well-supported?

Each persona produces a sub-verdict: `ACHIEVED`, `PARTIALLY_ACHIEVED`, `NOT_ACHIEVED`, or `UNDETERMINABLE`.

The consolidated final verdict feeds a score adjustment into quality scoring:
- `ACHIEVED` → +0 adjustment
- `PARTIALLY_ACHIEVED` → -5 adjustment
- `NOT_ACHIEVED` → -15 adjustment
- `UNDETERMINABLE` → -10 adjustment

Include the full outcome validation output in the closing comment (Step 3).

## Step 3: Compose Closing Comment

Write a structured closing comment following the evidence mandate (`references/evidence-mandate.md`). All claims must be backed by verification output, not predictions or assumptions.

```
## Closure Summary

**Status:** [Auto-closing | Proposing closure | Blocked]
**Reason:** [Which closure rule applies — cite rule # from closure-rules.md]
**Quality:** [★ rating] ([score]/100)

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

### Outcome Validation
[Outcome validation output — 4 persona verdicts + final consolidated verdict]
[OR: "Outcome validation: Skipped ([reason])"]

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
- List the specific blockers.
- **Include recovery commands** for each blocker:

| Block Reason | Recovery |
|-------------|----------|
| PR not merged | `gh pr merge <PR#> --squash` (if approved + CI green) |
| PR failing CI | `gh pr checks <PR#>` — identify and fix failures |
| Changes requested | `gh pr view <PR#> --comments` — address review feedback |
| Unresolved comments | Review and resolve each thread, then re-run `/close` |
| Quality score < 60 | Run `/ccc:review` to identify gaps |
| Quality score 60-79 | List gaps; fix or get user confirmation to proceed |
| Draft PR | `gh pr ready <PR#>` to mark ready for review |

## Step 5: Update Labels

After closure (or proposed closure):

1. **Spec lifecycle** — If the issue has `spec:implementing`, transition to `spec:complete`.
2. **Research readiness** — If applicable, verify the research label reflects the current state. Do NOT auto-transition to `expert-reviewed` (that always requires human decision).
3. **Parent issue** — Check if all sub-tasks of the parent epic are now closed. If so, propose closing the parent epic using the same closure protocol.
4. **Clean up** — Remove any transient labels that are no longer relevant (e.g., `auto:implement` if the implementation is complete).

## Next Step

After the issue is closed or closure is proposed:

```
✓ Issue closure evaluated. Evidence posted.
  Next: Run `/ccc:go` to continue → will check for remaining work
  Or: Run `/ccc:go --next` to pick up the next unblocked task
  Or: Run `/ccc:go --status` to see the full project status
```

## What If

| Situation | Response |
|-----------|----------|
| **PR is approved but not merged** | Suggest merging: `gh pr merge <PR#> --squash`. Do not auto-merge without user confirmation. After merge, re-run `/close`. |
| **PR CI is failing** | BLOCK. Show `gh pr checks <PR#>` output. List failing checks. Do not close with failing CI. |
| **Deployment status cannot be checked** | Treat as "no deploy pipeline configured." Auto-close is still permitted for agent-assigned single-PR issues, but note in the closing comment. |
| **No PRs are linked to the issue** | Check issue type. Agent-owned spikes/chores with all ACs checked → AUTO-CLOSE with deliverable summary. Agent-owned features/bugs with no PR → PROPOSE. Human-owned → always PROPOSE. |
| **Issue was re-opened after a previous closure** | Acknowledge the premature closure. Review what was missed, address it, and do not re-close until the reason for re-opening has been fully resolved. |
| **User confirms closure despite BLOCK/PROPOSE** | User override is valid per `references/evidence-mandate.md`. Record "Closed per user confirmation" as evidence. Proceed to close. |
