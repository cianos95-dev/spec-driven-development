---
description: |
  Re-anchor to the active spec by re-reading source artifacts and checking for drift.
  Rebuilds ground truth from the spec, git state, issue state, and review comments rather
  than relying on accumulated session context.
  Use when sessions run long, after context compaction, before resuming paused work, when
  implementation feels misaligned, or before claiming completion.
  Trigger with phrases like "anchor to spec", "re-read the spec", "am I drifting",
  "check alignment", "reload context".
argument-hint: "[issue ID, default is current active issue]"
platforms: [cli]
---

# Anchor to Spec

Re-read all source-of-truth artifacts and produce an alignment check against the active spec.

## Step 1: Identify Active Issue

Determine which issue to anchor against:

- **Explicit issue ID** -- Use the provided ID
- **No ID provided** -- Look for the most recently touched In Progress issue assigned to the agent
- **No In Progress issue found** -- Warn and ask which issue to anchor to

Fetch the full issue details from the project tracker (status, labels, comments, description).

## Step 2: Load Spec

Read the spec linked to the issue:

1. Check the issue description for a `linear:` frontmatter reference or linked PR/FAQ document
2. Read the full spec content, focusing on:
   - **Acceptance criteria** -- The complete checklist
   - **Open questions** -- Unresolved items that might affect implementation
   - **Scope boundaries** -- What's explicitly in-scope and out-of-scope
   - **Execution mode** -- The `exec:*` label dictating implementation approach

If no spec is found, warn that drift checking is limited to git and issue state only.

## Step 3: Check Git State

Assess the current implementation state:

1. `git status` -- Uncommitted changes, staged files
2. `git diff --stat` since last commit -- What's been modified
3. `git log --oneline -5` -- Recent commit history on this branch
4. Check for stashed changes that might be relevant

## Step 4: Check Review State

Look for unresolved feedback:

1. Read adversarial review output if `/sdd:review` was run (check for review document linked to the issue)
2. Check for open PR review comments
3. Check for carry-forward items from the issue-lifecycle protocol

## Step 5: Produce Alignment Summary

Generate the anchor check output:

```markdown
## Anchor Check -- [Issue ID]

**Spec:** [spec title] | **Mode:** [exec mode] | **Status:** [spec status]

### Acceptance Criteria
- [x] Criterion 1 -- implemented in [file:line]
- [ ] Criterion 2 -- not yet started
- [~] Criterion 3 -- partially implemented, [what remains]

### Drift Detected
- [Any misalignment between implementation and spec]
- [Any scope creep beyond acceptance criteria]
- [Any stale assumptions from earlier in the session]

### Open Items
- [Unresolved review comments]
- [Open questions from spec]
- [Carry-forward items]

### Next Action
- [The single most important next step to stay aligned]
```

## Step 6: Act on Findings

Based on the alignment summary:

| Finding | Action |
|---------|--------|
| **No drift detected** | Confirm alignment, continue implementation |
| **Minor drift** | Note the drift, course-correct, continue |
| **Major drift** | Pause implementation. Discuss with user if in `exec:pair` mode. Revert to last aligned state if needed. |
| **Scope creep detected** | Create new issues for out-of-scope work (per carry-forward protocol). Refocus on original acceptance criteria. |
| **All criteria met** | Suggest running `/sdd:close` to evaluate closure |

## What If

| Situation | Response |
|-----------|----------|
| **No spec exists for the issue** | Anchor against the issue description and acceptance criteria only. Warn that drift detection is limited. Suggest running `/sdd:write-prfaq` if the issue is complex enough to warrant a spec. |
| **Multiple issues in progress** | Anchor to the one specified by ID, or if no ID given, anchor to the most recently touched. List all In Progress issues so the user can choose. |
| **Context compaction just occurred** | This is the most critical time to anchor. Run the full protocol and explicitly note what context was lost and rebuilt. |
| **Agent is not the assignee** | Still run the anchor check but note that the agent is not assigned. Do not propose status changes for issues assigned to others. |
