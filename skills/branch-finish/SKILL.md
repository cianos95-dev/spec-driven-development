---
name: branch-finish
description: |
  Complete a CCC development branch with git operations and pre-completion verification.
  Handles 4 completion modes (merge, PR, park, abandon) with 8 pre-completion checks.
  Merge mode marks "closure-ready" — actual issue closure is handled by `/close`.
  Use when finishing implementation work and transitioning from code to project management.
  Trigger with phrases like "finish branch", "branch done", "wrap up branch",
  "complete this branch", "merge and close", "create PR and close", "park branch",
  "abandon branch", "branch cleanup", "finish implementation", "ready to merge",
  "ship this branch", "close out the work", "branch-finish".
---

# Branch Finish

Branch finish owns the **git operations** side of completing a CCC development branch. It verifies code readiness, executes the chosen completion mode (merge/PR/park/abandon), and hands off to `/close` for project management closure. Branch finish does NOT directly close issues — it produces the evidence and state that `/close` consumes.

## Why Branch Finish Exists

The gap between "code is complete" and "issue is properly closed" is where most AI agent workflows fail. The failure modes are predictable:

**Orphaned branches.** Implementation is done, tests pass, but the branch was never merged or PR'd. The code exists but is not delivered.

**Phantom closures.** The issue is marked Done but the branch was never merged. The project tracker says "delivered" but the codebase doesn't have the changes.

**Evidence-free closure.** The issue is closed with no record of what was delivered. Future audits cannot verify the closure.

**Stale spec status.** The spec label stays at `spec:implementing` even after all acceptance criteria are met.

**Lost context.** The `.ccc-state.json` task context is never archived. Execution history is lost.

Branch finish prevents these by executing a deterministic sequence: **verify → complete → handoff**.

## The Four Completion Modes

Every branch finish begins with selecting a completion mode.

### Mode 1: Merge — Direct Merge to Base Branch

**When to use:**
- Small changes (1-3 commits)
- Single contributor
- No review required (already reviewed, or changes are trivial)
- Base branch is your own development branch (not shared main)

**Sequence:**
1. Run all 8 pre-completion checks
2. Switch to base branch and pull latest
3. Merge the feature branch (fast-forward if possible, merge commit if not)
4. Push the updated base branch
5. Delete the feature branch (local and remote)
6. Mark issue as **closure-ready** (see Post-Completion Handoff)

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
1. Run all 8 pre-completion checks
2. Push the feature branch to remote
3. Create a pull request with structured description
4. Link the PR to the Linear issue
5. Issue stays In Progress until PR merges

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
- Scope changed mid-implementation
- Session is ending but work is not complete
- Need to context-switch to a higher-priority task

**Sequence:**
1. Commit all work-in-progress (WIP commit is acceptable)
2. Push the branch to remote (preservation)
3. Add a parking comment to the Linear issue
4. Do NOT delete the branch — it will be resumed

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
- The approach was wrong and should not continue
- The spec was cancelled or fundamentally changed
- A spike that produced knowledge but no shippable code

**Sequence:**
1. Verify there is no salvageable work (check with the human)
2. Document what was learned (especially for spikes)
3. Delete the branch locally and remotely
4. Update the Linear issue with an abandonment comment

**Abandonment comment format:**
```markdown
## Abandoned

**Reason:** [Why the branch is being abandoned]
**What was learned:**
- [Key insight from the attempt]
- [What didn't work and why]

**Recommendation:** [What the next approach should be, if any]
```

## Pre-Completion Verification (8 Checks)

Before any completion mode executes, verify all 8 conditions. Failed verification blocks completion. Evidence requirements follow `references/evidence-mandate.md` — no rationalization allowed.

### Check 1: Tests Pass

```bash
npm test  # or project-specific test runner
```

**Pass criterion:** Zero failures. Skipped tests acceptable only if documented in spec. Pending tests are not acceptable.

**If tests fail:** Fix them. Do not complete with failing tests. If failure is in unrelated code, isolate and document, but confirm spec-related tests pass.

### Check 2: No Uncommitted Changes

```bash
git status --porcelain
```

**Pass criterion:** Empty output. All changes committed. Uncommitted changes are invisible to reviewers and lost on branch deletion.

### Check 3: Branch Is Up-to-Date

```bash
git fetch origin main
git log HEAD..origin/main --oneline
```

**Pass criterion:** No commits on base branch missing from feature branch. Rebase or merge before completing.

### Check 4: Acceptance Criteria Addressed

Review each AC from the spec with evidence references:

```
AC #1: [criterion] — ADDRESSED (file:line reference)
AC #2: [criterion] — ADDRESSED (test name reference)
AC #3: [criterion] — ADDRESSED (commit SHA reference)
```

**Pass criterion:** All ACs have evidence. "I believe this is addressed" is not evidence — a file path, test name, or commit SHA is.

### Check 5: No TODO/FIXME/HACK Markers

```bash
git diff main..HEAD | grep -i "TODO\|FIXME\|HACK"
```

**Pass criterion:** No new markers introduced by this branch. Existing markers in untouched code are acceptable.

### Check 6: README Consistency

If the branch modifies skills, commands, or agents, verify README counts match the filesystem:

```bash
readme_skills=$(grep -oE '[0-9]+ skills' README.md | head -1 | grep -oE '[0-9]+')
actual_skills=$(find skills -name "SKILL.md" -maxdepth 2 | wc -l | tr -d ' ')
echo "README: $readme_skills | Filesystem: $actual_skills"
```

**Pass criterion:** Documented counts exactly match filesystem counts. Also check that every skill/command/agent on disk appears in the README tables.

### Check 7: Frontmatter Validation

All commands must have `description` and `argument-hint` in YAML frontmatter. All skills must have `name` and `description`.

```bash
# Command frontmatter
for f in commands/*.md; do
  name=$(basename "$f" .md)
  has_desc=$(head -20 "$f" | grep -c "^description:")
  has_hint=$(head -20 "$f" | grep -c "^argument-hint:")
  if [ "$has_desc" -eq 0 ] || [ "$has_hint" -eq 0 ]; then
    echo "FAIL: $name (desc=$has_desc, hint=$has_hint)"
  fi
done

# Skill frontmatter
for f in skills/*/SKILL.md; do
  name=$(basename $(dirname "$f"))
  has_name=$(head -20 "$f" | grep -c "^name:")
  has_desc=$(head -20 "$f" | grep -c "^description:")
  if [ "$has_name" -eq 0 ] || [ "$has_desc" -eq 0 ]; then
    echo "FAIL: $name (name=$has_name, desc=$has_desc)"
  fi
done
```

**Pass criterion:** All frontmatter fields present. Missing metadata degrades Claude's ability to match skills to user intent.

### Check 8: Cross-Reference Validation

Verify that cross-references between skills resolve:

- Cross-Skill References sections reference skills that exist
- See-also links point to valid paths
- `references/` file references point to existing files

```bash
# Check for references to deleted skills
grep -rn "ship-state-verification" skills/*/SKILL.md commands/*.md references/*.md 2>/dev/null
```

**Pass criterion:** No dangling cross-references to nonexistent skills or files.

## Post-Completion Handoff

After the completion mode executes, branch-finish hands off to the appropriate next step. Branch-finish does **NOT** directly close issues or update Linear status to Done.

### Merge Mode → Closure-Ready

After a successful merge:

1. **Archive task context** in `.ccc-state.json`:
```json
{
  "archived_tasks": [{
    "task_id": "CIA-XXX",
    "completion_mode": "merge",
    "execution_mode": "tdd",
    "completed_at": "2026-02-19T22:00:00Z",
    "acceptance_criteria_total": 5,
    "acceptance_criteria_addressed": 5,
    "commits": ["abc1234", "def5678"],
    "pr": "https://github.com/owner/repo/pull/42"
  }]
}
```

2. **Output closure-ready prompt:**
```
✓ Branch merged and verified. Issue is closure-ready.
  Next: Run `/close CIA-XXX` to evaluate and execute closure.
  Or: Run `/ccc:go` to continue (session-exit will handle closure).
```

Branch-finish marks the issue as closure-ready but delegates the closure decision (auto-close vs propose vs block) to `/close`, which applies `references/closure-rules.md`.

### PR Mode → In Progress

After PR creation:
- Issue stays In Progress until PR merges.
- Archive task context with `"completion_mode": "pr"`.
- Output: suggest `pr-dispatch` for review management.

### Park Mode → Parked

After parking:
- Issue stays In Progress with parking comment.
- Branch preserved on remote.
- Output: suggest `/ccc:start CIA-XXX` to resume.

### Abandon Mode → Cancelled

After abandonment:
- Issue transitions to Cancelled (or Backlog if re-approach planned).
- Branch deleted.
- Archive task context with `"completion_mode": "abandon"`.

## Integration with `/close`

Branch-finish and `/close` are complementary halves of the completion lifecycle:

| Concern | Owner |
|---------|-------|
| Git operations (merge, push, branch cleanup) | `branch-finish` |
| Pre-completion verification (8 checks) | `branch-finish` |
| Task context archival | `branch-finish` |
| PR creation and description | `branch-finish` |
| Closure evaluation (auto/propose/block) | `/close` |
| Quality scoring | `/close` |
| Outcome validation | `/close` |
| Linear status transition to Done | `/close` |
| Closing comment with evidence | `/close` |
| Spec label transition | `/close` |
| Parent issue cascade | `/close` |

## Anti-Patterns

**Merge without verification.** Skipping pre-completion checks because "I just ran the tests 10 minutes ago." Run them at the completion boundary.

**Direct issue closure from branch-finish.** Branch-finish marks closure-ready; `/close` evaluates and executes. Never bypass `/close` by setting Done directly from branch-finish.

**Evidence-free completion.** Every completion mode requires evidence in the archived context and any comments posted.

**Partial spec completion.** Transitioning parent spec to `spec:complete` when only one sub-issue is done. The spec is complete when ALL sub-issues are closed.

**Abandoning without learning.** Deleting a branch with no record of what was attempted. Document it.

**Parking without resumption path.** Park comments must include remaining work, blockers, and resume command.

## Cross-Skill References

- **`/close`** — Universal closure entry point. Branch-finish hands off to `/close` after merge mode.
- **session-exit** — Triggers `/close` for each closure-ready issue during session wind-down.
- **pr-dispatch** — Manages the review lifecycle for PR completion mode.
- **issue-lifecycle** — Ownership and status transition rules. `/close` references `closure-rules.md`.
- **quality-scoring** — Quality score is computed by `/close`, not branch-finish.
- **drift-prevention** — Pre-completion AC verification (Check 4) is a final drift check.
- **review-response** — Branch-finish verifies all review findings are resolved before completing.
- **execution-engine** — Task context archival preserves execution history.
- **references/evidence-mandate.md** — Evidence rules for all completion claims.
- **references/closure-rules.md** — Canonical closure matrix referenced by `/close`.
