---
name: branch-finish
description: |
  Complete a CCC development branch with Linear integration at Stage 6-7.5.
  Handles commit, PR creation, Linear issue closure, spec status update, and
  session-exit protocol. Use when finishing implementation work in the CCC workflow.
  Supports 4 completion modes (merge, PR, park, abandon) with pre-completion
  verification and evidence-based closing comments on the project tracker.
  Trigger with phrases like "finish branch", "branch done", "wrap up branch",
  "complete this branch", "merge and close", "create PR and close", "park branch",
  "abandon branch", "branch cleanup", "finish implementation", "ready to merge",
  "ship this branch", "close out the work", "branch-finish", "Stage 7.5 closure".
---

# Branch Finish

Branch finish is the CCC Stage 6-to-7.5 bridge that connects code completion to project management closure. Where basic git workflows end at "push and create PR," CCC branch finish extends through Linear issue status updates, spec status transitions, evidence-based closing comments, task context archival, and session-exit protocol triggers. It is the last mile of the implementation lifecycle — the transition from "code is done" to "issue is closed with proof."

## Why Branch Finish Exists

The gap between "code is complete" and "issue is properly closed" is where most AI agent workflows fail. The failure modes are predictable:

**Orphaned branches.** The implementation is done, tests pass, but the branch was never merged or PR'd. The code exists but is not delivered. No one knows it's there.

**Phantom closures.** The issue is marked Done but the branch was never merged. The project tracker says "delivered" but the codebase doesn't have the changes. Ship-state verification catches this, but branch-finish prevents it.

**Evidence-free closure.** The issue is closed with no record of what was delivered, which files changed, which tests were added, or whether the spec was fully satisfied. Future audits cannot verify the closure.

**Stale spec status.** The spec label stays at `spec:implementing` even after all acceptance criteria are met and the PR is merged. Downstream workflows that gate on spec status are blocked.

**Lost context.** The `.ccc-state.json` task context for the branch is never archived. When the branch is deleted, the execution history (mode, criteria addressed, review state) is lost.

Branch finish solves all of these by executing a deterministic sequence: verify, complete, update, archive, summarize.

## The Four Completion Modes

Every branch finish begins with selecting a completion mode. The mode determines how the code enters the main branch and what happens to the feature branch afterward.

### Mode 1: Merge — Direct Merge to Base Branch

**When to use:**
- Small changes (1-3 commits)
- Single contributor
- No review required (already reviewed, or changes are trivial)
- Base branch is your own development branch (not shared main)

**Sequence:**
1. Verify pre-completion checks (see below)
2. Switch to base branch and pull latest
3. Merge the feature branch (fast-forward if possible, merge commit if not)
4. Push the updated base branch
5. Delete the feature branch (local and remote)
6. Execute post-completion protocol

**Git operations:**
```bash
# Verify clean state
git status --porcelain  # Must be empty
git diff --cached --quiet  # No staged changes

# Merge
git checkout main
git pull origin main
git merge --no-ff feature-branch -m "Merge CIA-XXX: [title]"
git push origin main

# Cleanup
git branch -d feature-branch
git push origin --delete feature-branch
```

### Mode 2: PR — Create Pull Request for Review

**When to use:**
- Changes need review before merge (most common)
- Multiple contributors or stakeholders
- CI/CD pipeline runs on PRs
- Compliance or audit requirements

**Sequence:**
1. Verify pre-completion checks
2. Push the feature branch to remote
3. Create a pull request with structured description
4. Link the PR to the Linear issue
5. Execute post-completion protocol (partial — issue stays In Progress until PR merges)

**PR description structure:**
```markdown
## Summary
[1-3 bullet points describing the changes]

## Spec Reference
- Issue: [CIA-XXX](linear-url)
- Acceptance Criteria: [N/N addressed]

## Changes
- [File or module]: [What changed and why]

## Verification
- Tests: [PASS — N tests, N passing]
- Lint: [CLEAN]
- Build: [SUCCESS]

## Test Plan
- [ ] [Specific test steps for reviewers]
```

### Mode 3: Park — Preserve Branch for Later

**When to use:**
- Work is blocked by an external dependency
- Scope changed mid-implementation and the approach needs rethinking
- Session is ending but work is not complete
- Need to context-switch to a higher-priority task

**Sequence:**
1. Commit all work-in-progress (WIP commit is acceptable for parking)
2. Push the branch to remote (preservation)
3. Add a parking comment to the Linear issue explaining why and what remains
4. Update issue status to reflect the blocked/parked state
5. Do NOT delete the branch — it will be resumed

**Parking comment format:**
```markdown
## Parked

**Reason:** [Why the branch is being parked]
**Progress:** [What was completed before parking]
**Remaining:**
- [ ] [What still needs to be done]
- [ ] [Blockers that must be resolved]

**Branch:** `feature-branch-name` (pushed to remote)
**Resume with:** `/ccc:start CIA-XXX`
```

### Mode 4: Abandon — Discard the Branch

**When to use:**
- The approach was wrong and the work should not be continued
- The spec was cancelled or fundamentally changed
- A spike that produced knowledge but no shippable code

**Sequence:**
1. Verify there is no salvageable work (check with the human)
2. Document what was learned (especially for spikes)
3. Delete the branch locally and remotely
4. Update the Linear issue with an abandonment comment
5. Transition the issue to Cancelled (or back to Backlog if the work will be re-approached differently)

**Abandonment comment format:**
```markdown
## Abandoned

**Reason:** [Why the branch is being abandoned]
**What was learned:**
- [Key insight from the attempt]
- [What didn't work and why]

**Recommendation:** [What the next approach should be, if any]
```

## Pre-Completion Verification

Before any completion mode executes, verify these conditions. Failed verification blocks completion — do not skip checks by claiming "it's fine."

### Check 1: Tests Pass

```bash
# Run the full test suite
npm test  # or your test runner
```

**Pass criterion:** Zero failures. Skipped tests are acceptable only if documented in the spec as out of scope. Pending tests are not acceptable — they indicate incomplete implementation.

**If tests fail:** Fix them. Do not complete the branch with failing tests. If the failure is in unrelated code, isolate and document it, but confirm that all tests related to the current spec pass.

### Check 2: No Uncommitted Changes

```bash
git status --porcelain
```

**Pass criterion:** Empty output. All changes are committed. If there are uncommitted changes, either commit them or discard them explicitly (with justification).

**Why this matters:** The branch state at completion is the state that will be merged or PR'd. Uncommitted changes are invisible to reviewers and lost on branch deletion.

### Check 3: Branch Is Up-to-Date

```bash
git fetch origin main
git log HEAD..origin/main --oneline
```

**Pass criterion:** No commits on the base branch that are not in the feature branch. If the base has moved ahead, rebase or merge before completing.

**Why this matters:** Merge conflicts discovered during PR review waste the reviewer's time. Resolve them before dispatching.

### Check 4: Acceptance Criteria Addressed

Review each acceptance criterion from the spec and confirm it is addressed:

```
AC #1: [criterion] — ADDRESSED (file:line reference)
AC #2: [criterion] — ADDRESSED (test name reference)
AC #3: [criterion] — ADDRESSED (commit SHA reference)
```

**Pass criterion:** All acceptance criteria have an evidence reference. "I believe this is addressed" is not evidence — a file path, test name, or commit SHA is evidence.

### Check 5: No TODO/FIXME/HACK Markers

```bash
git diff main..HEAD | grep -i "TODO\|FIXME\|HACK"
```

**Pass criterion:** No new TODO/FIXME/HACK markers introduced by this branch. Existing markers in untouched code are acceptable. New markers indicate incomplete work.

## Post-Completion Protocol

After the completion mode executes successfully, run the post-completion protocol. This is the project management side of branch finish — where "code is merged" becomes "issue is closed with evidence."

### Step 1: Update Linear Issue Status

Transition the issue to Done (for merge mode) or the appropriate status (for other modes):

| Completion Mode | Linear Status | Notes |
|----------------|---------------|-------|
| Merge | Done | Auto-close if agent assignee + single PR + merged |
| PR | In Progress | Stays In Progress until PR merges |
| Park | In Progress | Add blocking relationship if applicable |
| Abandon | Cancelled | Or Backlog if re-approach is planned |

**Closure protocol (merge mode):**
- **Auto-close** if: agent assignee AND single PR AND merged AND deploy green AND quality score >= 80
- **Propose close** if: any condition missing. Comment with evidence and ask for confirmation.
- **Never auto-close** if: human assignee OR `needs:human-decision` label

### Step 2: Write Evidence-Based Closing Comment

For merge and PR modes, add a closing comment to the Linear issue:

```markdown
## Completed

**Evidence:**
- PR: [link] (merged / open for review)
- Branch: `feature-branch-name`
- Commits: [N commits, SHA range]
- Files: [key files created or modified]
- Tests: [PASS — N tests, N passing, coverage delta]

**Acceptance Criteria:**
- [x] AC #1: [criterion] — [evidence reference]
- [x] AC #2: [criterion] — [evidence reference]
- [x] AC #3: [criterion] — [evidence reference]

**Summary:** [1-2 sentences describing what was delivered]
```

### Step 3: Update Spec Status

If the issue has a parent spec (PR/FAQ or epic), update the spec status label:

| Current Spec Status | New Status | Condition |
|--------------------|-----------|-----------|
| `spec:implementing` | `spec:complete` | All sub-issues for this spec are Done |
| `spec:implementing` | `spec:implementing` | Other sub-issues remain In Progress |

Only transition to `spec:complete` when ALL implementation tasks under the spec are closed. A single completed sub-issue does not complete the spec.

For the issue's own spec frontmatter (if it has embedded spec YAML), update:
```yaml
status: complete
updated: [current timestamp]
```

### Step 4: Archive Task Context

If `.ccc-state.json` contains context for this task, archive it:

```json
{
  "archived_tasks": [
    {
      "task_id": "CIA-XXX",
      "completion_mode": "merge",
      "execution_mode": "tdd",
      "completed_at": "2026-02-16T22:00:00Z",
      "acceptance_criteria_total": 5,
      "acceptance_criteria_addressed": 5,
      "review_findings_total": 3,
      "review_findings_resolved": 3,
      "commits": ["abc1234", "def5678"],
      "pr": "https://github.com/owner/repo/pull/42"
    }
  ]
}
```

Remove the task from the `current_task` field. The archived data preserves execution history for retrospective analysis and pattern aggregation.

### Step 5: Trigger Session-Exit Protocol

If this is the last task of the session, trigger the full session-exit protocol (see session-exit skill):

1. Inventory all affected issues
2. Normalize statuses
3. Write closing comments (already done in Step 2)
4. Post daily project update
5. Present session summary tables
6. Assess context budget

If more tasks remain in the session, skip the session-exit protocol and proceed to the next task via `/ccc:start --next` or `/ccc:go`.

## Integration with Anthropic's commit-commands Plugin

Anthropic's `commit-commands` plugin provides `/commit-push-pr` which handles:
- Staging and committing changes
- Pushing to remote
- Creating a pull request

CCC's branch-finish builds on top of this by adding:
- Pre-completion verification (5-check protocol)
- 4 completion modes (not just PR)
- Linear issue status updates
- Spec status transitions
- Evidence-based closing comments
- Task context archival
- Session-exit protocol integration

The two are complementary. Use `commit-commands` for the git mechanics; use `branch-finish` for the project management lifecycle that wraps around them.

## Anti-Patterns

**Merge without verification.** Skipping pre-completion checks because "I just ran the tests 10 minutes ago." Tests can break from concurrent changes, cached state, or environment drift. Run them immediately before completion.

**Evidence-free closure.** Marking the issue Done with "completed." No PR link, no file references, no test results. Future audits cannot verify the closure. Every closure needs evidence.

**Partial spec completion.** Transitioning the parent spec to `spec:complete` when only one of three sub-issues is done. The spec is complete when ALL sub-issues are closed, not when one is.

**Abandoning without learning.** Deleting a branch with no record of what was attempted and why it failed. Even failed approaches produce valuable knowledge. Document it.

**Parking without resumption path.** Parking a branch with no note about what remains, what's blocked, or how to resume. The next session must rediscover the state from scratch.

**Status batching.** Waiting until the end to update Linear. Mark In Progress when work starts, not when it ends. Branch-finish handles the final transition; mid-session transitions happen in real time.

## Cross-Skill References

- **session-exit** -- Branch finish triggers session-exit protocol for the final task. Session-exit handles status normalization and summary tables.
- **ship-state-verification** -- After branch finish (merge mode), ship-state verification confirms all claimed artifacts exist before release.
- **pr-dispatch** -- For PR completion mode, pr-dispatch handles the review phase. Branch-finish handles pre- and post-review.
- **issue-lifecycle** -- Closure rules matrix (auto-close, propose-close, never-close) governs Step 1 of the post-completion protocol.
- **quality-scoring** -- Quality score gates closure. Branch-finish reads the score to determine whether auto-close or propose-close applies.
- **drift-prevention** -- Pre-completion AC verification is a final drift check. If acceptance criteria are not addressed, the implementation has drifted.
- **review-response** -- If review findings were received during Stage 6, branch-finish verifies all findings are resolved before completing.
- **execution-engine** -- Task context archival preserves execution history for pattern aggregation and retrospective analysis.
