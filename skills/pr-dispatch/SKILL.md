---
name: pr-dispatch
description: |
  CCC Stage 6 PR review dispatch with spec context injection and code-reviewer agent orchestration.
  Gathers git SHAs, spec acceptance criteria, and .ccc-state.json task context, then dispatches the
  CCC code-reviewer agent with a structured, spec-aware review prompt. Replaces generic code review
  dispatch by anchoring every review to the active spec's acceptance criteria and detecting drift.
  Use when implementation is complete and ready for review in the CCC workflow.
  Trigger with phrases like "dispatch review", "request code review", "PR review", "send to reviewer",
  "review my changes", "stage 6 review", "spec-aware review", "run code review", "review dispatch",
  "CCC review", "is this ready for review", "pre-merge review".
---

# PR Dispatch

PR dispatch is the CCC Stage 6 practice of sending completed implementation work through a spec-aware review process before merge. Unlike generic code review dispatch (which sends a diff to a reviewer with no context about what the diff is supposed to achieve), CCC PR dispatch gathers the spec's acceptance criteria, the current task context, and the implementation evidence, then packages all of it into a structured prompt for the CCC code-reviewer agent. The reviewer evaluates the implementation against the spec, not just against general code quality heuristics.

## Why Spec-Aware Review Dispatch Matters

Generic code review asks: "Is this code good?" Spec-aware review asks: "Does this code deliver what the spec promised?" The distinction is critical because:

**Good code that misses the spec is a failure.** A beautifully refactored module that doesn't satisfy acceptance criterion #3 is not done. Generic review will approve it. Spec-aware review will catch the gap.

**Bad code that satisfies the spec is fixable.** A messy implementation that hits every acceptance criterion can be cleaned up in a follow-up. Generic review may reject it prematurely; spec-aware review distinguishes between "wrong" (doesn't meet spec) and "could be better" (meets spec but has quality issues).

**Drift is invisible without a reference point.** After hours of implementation, the agent's mental model of "what we're building" may have drifted from the spec. The review dispatch forces a re-read of the spec before the review, catching drift at the last possible moment before merge.

## When to Dispatch

PR dispatch triggers at a specific moment in the CCC funnel:

```
Stage 5: Implementation complete
   ↓
Stage 6: PR Dispatch ← YOU ARE HERE
   ↓
   Review feedback received
   ↓
   Review response (see review-response skill)
   ↓
Stage 7: Verification
```

**Dispatch when ALL of these are true:**
1. All acceptance criteria from the spec have been addressed (implementation complete)
2. Tests pass locally (no point reviewing code that doesn't work)
3. No uncommitted changes (the diff the reviewer sees must match what you tested)
4. The branch is up-to-date with the base branch (no merge conflicts pending)

**Do NOT dispatch when:**
- Implementation is partial ("review what I have so far" is a pair session, not a review)
- Tests are failing ("I think the tests will pass in CI" is rationalization -- run them)
- You haven't re-read the spec since starting implementation (drift risk is too high)

## The Dispatch Protocol

### Phase 1: Gather Context

Before dispatching the reviewer, assemble all context the reviewer needs. Missing context forces the reviewer to guess, leading to false positives (flagging correct behavior as wrong) and false negatives (missing actual issues because they didn't understand the intent).

#### 1.1 Git Context

```bash
# Current branch and base
git branch --show-current
git log --oneline main..HEAD  # or your base branch

# Full diff for review
git diff main..HEAD --stat
git diff main..HEAD

# Verify clean working tree
git status --porcelain
```

Capture the commit SHAs, branch name, and diff stats. The reviewer needs to know the scope of changes (how many files, how many lines) to calibrate their review depth.

#### 1.2 Spec Context

Load the active spec from the issue description or linked PR/FAQ document. Extract:

1. **Acceptance criteria** -- The numbered list of conditions that define "done." Each criterion becomes a review checklist item.
2. **Scope boundaries** -- What the spec explicitly excludes. The reviewer should not flag missing functionality that is intentionally out of scope.
3. **Open questions** -- Any unresolved spec ambiguities. The reviewer should flag if the implementation made assumptions about these.
4. **Non-functional requirements** -- Performance targets, security constraints, accessibility standards mentioned in the spec.

#### 1.3 Task Context

If `.ccc-state.json` exists, load the current task state:

```json
{
  "current_task": "CIA-XXX",
  "execution_mode": "tdd",
  "spec_status": "implementing",
  "acceptance_criteria_addressed": [1, 2, 3, 4],
  "acceptance_criteria_total": 5,
  "review_state": null
}
```

The task context tells the reviewer which execution mode was used (TDD reviews check for test-first discipline), which criteria the implementer believes are addressed, and whether any previous review cycles have occurred.

#### 1.4 Evidence Snapshot

Collect verification evidence that accompanies the review request:

```bash
# Test results
npm test 2>&1 | tail -20  # or your test runner

# Lint status
npm run lint 2>&1 | tail -10  # or your linter

# Build status
npm run build 2>&1 | tail -10  # or your build command

# Type check (if applicable)
npx tsc --noEmit 2>&1 | tail -10
```

Including verification output in the dispatch prevents the reviewer from re-running these checks and lets them focus on logic, architecture, and spec alignment.

### Phase 2: Construct the Review Prompt

The review prompt is the structured message sent to the CCC code-reviewer agent. It must contain everything the reviewer needs to evaluate the implementation without reading the entire codebase.

**Review prompt structure:**

```markdown
## Review Request: [Issue ID] — [Issue Title]

### Spec Context
**Acceptance Criteria:**
1. [AC #1 text] — Implementer claims: ADDRESSED
2. [AC #2 text] — Implementer claims: ADDRESSED
3. [AC #3 text] — Implementer claims: ADDRESSED

**Scope Boundaries:** [What's explicitly out of scope]
**Open Questions:** [Any unresolved spec ambiguities]

### Implementation Summary
**Branch:** [branch-name]
**Commits:** [N commits, SHAs]
**Files Changed:** [N files, +X/-Y lines]
**Execution Mode:** [quick/tdd/pair/checkpoint/swarm]

### Changes Overview
[Brief description of the implementation approach — 3-5 sentences max]

### Key Files
- `path/to/main-change.ts` — [What changed and why]
- `path/to/test-file.test.ts` — [What's tested]
- `path/to/config.ts` — [Configuration changes]

### Verification Evidence
- Tests: [PASS/FAIL — N tests, N passing]
- Lint: [CLEAN/WARNINGS — details]
- Build: [SUCCESS/FAILURE — details]
- Type check: [CLEAN/ERRORS — details]

### Review Focus
[Specific areas where the implementer wants reviewer attention]
[Known trade-offs or decisions that may warrant discussion]

### Diff
[Full or key sections of the diff]
```

### Phase 3: Dispatch the CCC Code-Reviewer Agent

The CCC code-reviewer agent is dispatched via the Task tool. The agent type is `claude-command-centre:code-reviewer` — CCC's own code-reviewer agent that understands spec-driven development, acceptance criteria verification, and the CCC stage model.

**Dispatch configuration:**

```
Task tool invocation:
  subagent_type: claude-command-centre:code-reviewer
  description: "Review [Issue ID] implementation"
  prompt: [The constructed review prompt from Phase 2]
```

**What the code-reviewer agent does:**
1. Reads each acceptance criterion and verifies the diff addresses it
2. Flags any criteria that appear unaddressed or partially addressed
3. Checks for spec drift — changes that go beyond what the acceptance criteria require
4. Evaluates code quality within the scope of the spec (not arbitrary improvements)
5. Produces structured findings in the CCC severity format (P1/P2/P3)

### Phase 4: Process the Review Response

When the code-reviewer agent returns findings, transition to the review-response skill for structured triage. The handoff:

1. **Update `.ccc-state.json`** with the review state:
   ```json
   {
     "review_state": {
       "source": "code-reviewer",
       "findings_total": N,
       "findings_resolved": 0,
       "findings_deferred": 0,
       "findings_rejected": 0,
       "pending": [...]
     }
   }
   ```

2. **Present findings summary** to the human before implementing fixes:
   ```
   Review complete: N findings
   - P1 (Critical): X — must fix before merge
   - P2 (Important): Y — should fix, justify if not
   - P3 (Consider): Z — evaluate ROI, may defer
   ```

3. **Route to review-response** for RUVERI protocol triage of each finding.

## Drift Detection Integration

PR dispatch includes an implicit drift check. During Phase 1 (Gather Context), re-reading the spec and comparing it against the implementation is itself a drift detection step. If the implementer discovers during context gathering that the implementation has diverged from the spec, the dispatch should be paused:

**Drift detected — do not dispatch:**
```
DRIFT DETECTED: Implementation includes [X] which is not in any acceptance criterion.
Options:
  1. Remove the out-of-scope changes before dispatching
  2. Propose a spec amendment to include [X], then dispatch
  3. Create a follow-up issue for [X] and revert to spec scope
```

This is the last line of defense against drift. If drift makes it past dispatch and into the review, the reviewer will catch it — but it's more efficient to catch it before the review starts.

## Multi-Perspective Dispatch

For high-stakes reviews (8+ point issues, architectural changes, security-sensitive code), dispatch can target multiple reviewer perspectives. Instead of a single code-reviewer agent, dispatch to the adversarial review panel:

```
Dispatch to: reviewer-security-skeptic
Dispatch to: reviewer-performance-pragmatist
Dispatch to: reviewer-architectural-purist
Dispatch to: reviewer-ux-advocate
```

Then use the debate-synthesizer agent to reconcile findings across perspectives. This is the CCC Stage 4 adversarial review architecture applied to code review (Stage 6) rather than spec review.

**When to use multi-perspective dispatch:**
- Issue estimate >= 8 points
- Changes touch authentication, authorization, or data access
- Changes introduce new architectural patterns
- Changes modify public APIs or user-facing behavior

**When single-perspective is sufficient:**
- Issue estimate <= 3 points
- Changes are internal refactoring with no behavioral change
- Changes add tests or documentation only
- Changes fix bugs with clear reproduction and fix

## Common Failure Modes

### 1. Dispatching Without Verification

**Symptom:** Review findings include "tests don't pass" or "build is broken." The reviewer spent time on a non-functional codebase.

**Fix:** Phase 1 requires verification evidence. If tests or build fail, fix them before dispatching. The evidence snapshot is not optional — it's the proof that the implementation is ready for review.

### 2. Missing Spec Context

**Symptom:** Reviewer flags correct behavior as wrong because they didn't know it was required by the spec. False positives waste review cycles.

**Fix:** The review prompt must include all acceptance criteria with explicit claims about which are addressed. If the reviewer has to guess what the spec requires, the dispatch is incomplete.

### 3. Over-Scoped Diff

**Symptom:** The diff includes changes unrelated to the current task (formatting fixes, dependency updates, unrelated refactoring). Reviewer spends time on noise.

**Fix:** Before dispatch, review the diff yourself. If changes are unrelated to the acceptance criteria, extract them to a separate commit or branch. The review should focus on spec-related changes only.

### 4. Dispatching Partial Implementation

**Symptom:** "Review what I have so far" with 2 of 5 acceptance criteria addressed. The reviewer can't evaluate completeness because the implementation isn't complete.

**Fix:** PR dispatch is for complete implementations. For feedback during implementation, use the pair execution mode with human-in-loop instead.

### 5. Skipping the Review

**Symptom:** "This change is too small to review." Small changes are where bugs hide — an off-by-one error doesn't need a large diff to be catastrophic.

**Fix:** All implementations go through review dispatch. The review depth scales with the change size (a 5-line fix gets a lighter review than a 500-line feature), but the dispatch protocol always runs. For trivially small changes, the review may take 30 seconds — but it still runs.

## Relationship to Other Review Mechanisms

PR dispatch complements but does not replace other review mechanisms:

| Mechanism | When | What It Catches |
|-----------|------|----------------|
| **PR dispatch (this skill)** | Before merge | Spec alignment, acceptance criteria gaps, drift |
| **Adversarial review (Stage 4)** | Before implementation | Spec weaknesses, missing requirements, design flaws |
| **TDD enforcement** | During implementation | Regression, missing edge cases, untested paths |
| **Ship-state verification** | Before release | Phantom deliverables, manifest errors, README accuracy |

PR dispatch is specifically about the implementation-to-review transition. It does not replace pre-implementation spec review or post-merge release verification.

## Cross-Skill References

- **review-response** -- The receiving counterpart. PR dispatch _sends_ the review; review-response defines how to _handle_ the findings that come back.
- **adversarial-review** -- Defines the multi-perspective reviewer panel and finding severity format. PR dispatch can escalate to the full panel for high-stakes reviews.
- **drift-prevention** -- The re-anchoring protocol that PR dispatch triggers during context gathering. Drift detected during dispatch pauses the review.
- **references/evidence-mandate.md** -- Evidence requirements for all completion claims. After review findings are resolved and the PR is approved, the evidence mandate enforces verification before merge.
- **execution-engine** -- Task state management. PR dispatch reads from and writes to `.ccc-state.json` to maintain review state across sessions.
- **tdd-enforcement** -- For TDD-mode tasks, the code-reviewer checks for test-first discipline (tests committed before implementation) as part of the spec alignment review.
- **quality-scoring** -- Review completeness (findings addressed vs. total) feeds into the quality score that gates closure at Stage 7.5.
