---
name: review-response
description: |
  Spec-drift-aware review feedback handling for CCC Stage 6. When receiving PR review
  comments or adversarial review findings, cross-references each item against the active
  spec's acceptance criteria to determine if feedback is in-scope, represents drift, or
  reveals a legitimate spec gap. Follows the READ-UNDERSTAND-VERIFY-EVALUATE-RESPOND-IMPLEMENT
  protocol. Integrates with adversarial-review output and .ccc-state.json task context.
  Use when receiving code review comments, adversarial review findings, PR feedback,
  or any post-implementation critique that may require code changes.
  Trigger with phrases like "handle review feedback", "respond to review", "PR comments",
  "review findings", "is this feedback in scope", "spec drift from review",
  "adversarial review response", "triage review comments", "reviewer suggests".
---

# Review Response

Spec-drift-aware protocol for handling review feedback during CCC Stage 6. This skill is the _receiving_ counterpart to the `adversarial-review` skill: adversarial-review defines how to _give_ structured feedback; review-response defines how to _receive, triage, and act on_ it.

## The Problem

Review feedback is the most common source of uncontrolled scope creep. Without a spec-aware triage protocol:

- **Every suggestion feels mandatory.** Reviewers have authority, so their suggestions get implemented without evaluating whether they're in-scope.
- **Drift accumulates silently.** Each "small improvement" from review moves the implementation further from the spec until the spec is descriptive (documents what was built) rather than prescriptive (defines what to build).
- **Good feedback gets lost.** Legitimate spec gaps discovered by reviewers get mixed in with stylistic preferences and nice-to-haves. Without triage, everything gets the same priority.
- **Defensive implementation.** Without a framework for pushback, the response to every finding is "fix it immediately" — including findings that would require scope changes the spec doesn't authorize.

## The RUVERI Protocol

Every piece of review feedback passes through six stages:

```
READ → UNDERSTAND → VERIFY-AGAINST-SPEC → EVALUATE → RESPOND → IMPLEMENT
```

No stages may be skipped. In particular, VERIFY-AGAINST-SPEC must happen _before_ EVALUATE — you cannot assess whether feedback is worth implementing until you know whether it's in-scope.

### Stage 1: READ — Ingest the Feedback

**Goal:** Capture the reviewer's complete intent without interpretation.

**Process:**

1. **Read the full comment.** Not just the suggestion — the context, the reasoning, the severity.

2. **Identify the feedback type.** Review feedback falls into categories:

   | Type | Signal | Example |
   |------|--------|---------|
   | **Defect** | "This is broken" | "This will crash when input is null" |
   | **Specification** | "This doesn't match the spec" | "AC says 20 per page but this returns all results" |
   | **Enhancement** | "This could be better" | "Consider adding caching here" |
   | **Style** | "This should look different" | "Rename this variable to be more descriptive" |
   | **Question** | "I don't understand" | "Why was this approach chosen over X?" |
   | **Architecture** | "This should be structured differently" | "Extract this into a separate service" |

3. **Note the severity if provided.** Adversarial review findings use the CCC severity format:

   | Severity | Meaning | Default Action |
   |----------|---------|----------------|
   | **P1 — Critical** | Blocks acceptance. The implementation does not meet the spec. | Must fix before merge |
   | **P2 — Important** | Significant issue but doesn't block the core acceptance criteria. | Should fix, justify if not |
   | **P3 — Consider** | Nice-to-have improvement. The implementation is correct without it. | Evaluate ROI, may defer |

   External review comments (GitHub PRs, etc.) won't use this format — assign a severity during the EVALUATE stage.

### Stage 2: UNDERSTAND — Parse the Intent

**Goal:** Translate the reviewer's comment into a concrete, actionable statement.

**Process:**

1. **Restate the feedback** in your own words. If you can't restate it, you don't understand it — ask for clarification.

2. **Identify the concrete change** the reviewer is suggesting. "This could be better" is not actionable. "Extract the validation logic into a validateInput() function" is actionable.

3. **Separate the observation from the suggestion.** Sometimes the reviewer identifies a real problem but suggests the wrong fix. Evaluate both independently:
   ```
   OBSERVATION: "The error handling here swallows exceptions silently"
   SUGGESTION: "Add a global error handler"

   The observation may be correct (spec says errors should be surfaced).
   The suggestion may be out of scope (global error handler is a separate feature).
   ```

### Stage 3: VERIFY-AGAINST-SPEC — Check Alignment

**Goal:** Determine whether the feedback relates to the active spec's acceptance criteria.

**Process:**

1. **Read the active spec.** Open the PR/FAQ or issue description linked in `.ccc-state.json`. Load the acceptance criteria checklist.

2. **Classify the feedback:**

   | Classification | Definition | Action |
   |----------------|------------|--------|
   | **IN-SCOPE** | Feedback directly relates to an acceptance criterion | Proceed to EVALUATE |
   | **SPEC-GAP** | Feedback reveals a legitimate gap in the spec — the spec should have covered this but doesn't | Flag for spec update |
   | **DRIFT** | Feedback would move the implementation beyond what the spec authorizes | Pushback with spec reference |
   | **UNRELATED** | Feedback is about code not covered by this spec (e.g., adjacent module) | Defer to a new issue |

3. **For each classification, cite the evidence:**
   ```
   FEEDBACK: "Add rate limiting to this endpoint"
   CLASSIFICATION: DRIFT
   EVIDENCE: Spec AC does not mention rate limiting. No acceptance criterion
   requires it. AC #1-#5 are all functional requirements for the search feature.
   Rate limiting is a cross-cutting concern that belongs in a separate spec.
   ```

### Stage 4: EVALUATE — Assess Impact and Priority

**Goal:** For IN-SCOPE and SPEC-GAP feedback, determine priority and implementation effort.

**Process:**

1. **Assign severity** (if not already provided by the reviewer):

   - **P1 — Critical:** The implementation does not meet an acceptance criterion. The fix is mandatory.
   - **P2 — Important:** The implementation meets the acceptance criterion but has a significant quality issue. The fix is strongly recommended.
   - **P3 — Consider:** The implementation is correct and meets the criterion. The suggestion would improve quality but is not required.

2. **Estimate effort:** How much work is the fix?
   - **Trivial** (< 15 min): One-line fix, rename, add a check
   - **Small** (15-60 min): New function, additional test, refactored logic
   - **Medium** (1-4 hours): New component, significant refactor, integration change
   - **Large** (4+ hours): Architectural change, multiple file refactor

3. **Apply the decision matrix:**

   | Severity | Effort: Trivial | Effort: Small | Effort: Medium | Effort: Large |
   |----------|----------------|---------------|----------------|---------------|
   | **P1** | Fix immediately | Fix immediately | Fix immediately | Fix (schedule if needed) |
   | **P2** | Fix immediately | Fix in this PR | Discuss with reviewer | Create follow-up issue |
   | **P3** | Fix if convenient | Create follow-up issue | Create follow-up issue | Defer |

4. **For DRIFT items:** Do not evaluate effort. Drift items are rejected with a spec reference, not deferred for later.

5. **For SPEC-GAP items:** Propose a spec update before implementing. The spec update must be approved before the implementation changes.

### Stage 5: RESPOND — Communicate the Decision

**Goal:** Acknowledge every piece of feedback with a clear response.

**Response templates by classification:**

**IN-SCOPE — Will Fix:**
```
Agreed — this conflicts with AC #[N] ("[criterion text]"). Fixing in [commit/next push].
```

**IN-SCOPE — Will Defer:**
```
Valid point. This is P3 and medium effort — creating [ISSUE-ID] to address in a
follow-up. Not blocking this PR as AC #[N] is satisfied by the current implementation.
```

**SPEC-GAP — Proposing Update:**
```
Good catch — the spec doesn't cover [scenario]. Proposing an AC addition:
"[new criterion text]". If approved, I'll implement in this PR / a follow-up.
```

**DRIFT — Pushback:**
```
This would add functionality beyond the current spec scope. The active spec
(AC #1-#[N]) covers [scope summary]. [Suggestion] is a valuable enhancement
that should be specced separately. Created [ISSUE-ID] to track it.

Happy to discuss if you believe this should be in-scope for this spec.
```

**UNRELATED — Redirect:**
```
This relates to [module/feature] which is outside the scope of [ISSUE-ID].
Created [NEW-ISSUE-ID] to address it properly.
```

**Question — Clarify:**
```
[Direct answer to the question with reference to spec or design decision]
```

**Every feedback item gets a response.** Unreplied feedback signals that it was ignored, not that it was evaluated and deferred.

### Stage 6: IMPLEMENT — Execute Approved Changes

**Goal:** Implement fixes in priority order, maintaining spec alignment throughout.

**Process:**

1. **Fix P1s first.** Critical findings block merge — address them before anything else.

2. **Batch P2 fixes by area.** If multiple P2 findings affect the same file/function, fix them together to avoid repeated context switches.

3. **Run the test suite after each fix batch.** Ensure no regressions. If a fix breaks a test, the fix is wrong or the test needs updating — enter the debugging-methodology loop.

4. **Update the coverage table.** If using TDD enforcement, new fixes may require new tests (RED → GREEN → REFACTOR for each fix).

5. **Respond to the reviewer** on each resolved item with the commit SHA or file:line reference.

6. **For SPEC-GAP approved updates:** Update the spec (PR/FAQ or issue description) _before_ implementing. The spec drives the implementation, not the reverse.

## Adversarial Review Integration

When feedback comes from the CCC adversarial review process (via `/ccc:review` or the reviewer agents), additional structure is available:

### Finding Format

Adversarial review produces findings in this format:

```markdown
### [SEVERITY] [Finding Title]

**Category:** [Security | Performance | Architecture | UX | Correctness]
**Spec Reference:** [AC #N or "none"]

[Description of the finding]

**Recommendation:** [Specific suggested fix]
```

### Structured Debate Output

When the full 4-persona debate runs, findings are pre-classified:

- **UNANIMOUS:** All 4 reviewers agree. Treat as P1 regardless of stated severity.
- **MAJORITY (3/4):** Strong signal. Treat as stated severity.
- **SPLIT (2/2):** Genuine disagreement. Evaluate both positions against the spec. The spec is the tiebreaker.
- **ESCALATED:** Reviewers flagged this for human decision. Do not resolve — pass to the human.

### Handling Contradictory Findings

When two reviewers suggest opposite changes (e.g., Performance says "add caching" but Security says "caching creates staleness risk"):

1. Check the spec. Does it specify a preference? If yes, follow the spec.
2. If the spec is silent, evaluate which finding more directly supports an acceptance criterion.
3. If both are equally valid, ESCALATE to the human with both positions clearly stated.
4. Never implement a finding that contradicts another finding without resolution. Contradictions must be resolved before code changes.

## State Management

### .ccc-state.json Integration

```json
{
  "current_task": "CIA-123",
  "execution_mode": "tdd",
  "review_state": {
    "source": "adversarial-review",
    "findings_total": 8,
    "findings_resolved": 5,
    "findings_deferred": 1,
    "findings_rejected": 2,
    "pending": [
      {
        "id": "F3",
        "severity": "P2",
        "classification": "IN-SCOPE",
        "status": "implementing"
      }
    ]
  }
}
```

### Session Boundary Protocol

At the end of a session with unresolved review feedback:

1. **Update the issue comment** with the RUVERI status for each finding.
2. **Commit implemented fixes** with references to the finding IDs.
3. **Create follow-up issues** for deferred items (do not leave deferred items in comments only).
4. **Note the remaining findings** in `.ccc-state.json` so the next session can continue.

## Common Failure Modes

### 1. Implement Everything

**Symptom:** Every reviewer suggestion gets implemented immediately. The PR grows by 40% in the review cycle.

**Fix:** VERIFY-AGAINST-SPEC before EVALUATE. Drift items and P3 items get deferred, not implemented. The PR scope is defined by the spec, not by the review.

### 2. Reject Everything

**Symptom:** Every reviewer suggestion is pushed back as "out of scope." The reviewer feels unheard.

**Fix:** Distinguish between DRIFT (genuinely out of scope) and SPEC-GAP (the spec should have covered this). Spec gaps are the spec's fault, not the reviewer's. Acknowledge the gap even as you defer the fix.

### 3. Silent Deferral

**Symptom:** Creating follow-up issues but not telling the reviewer. The reviewer checks back and finds their feedback "unresolved."

**Fix:** Every feedback item gets an explicit response. Deferred items include the follow-up issue ID. Rejected items include the spec reference justifying rejection.

### 4. Review-Driven Design

**Symptom:** Major architectural changes suggested in review get implemented without spec update. The implementation drifts from the spec because "the reviewer said to."

**Fix:** Reviewer authority does not override spec authority. Architectural suggestions that change the design go through the spec amendment process: propose the change, get approval, update the spec, then implement.

### 5. Severity Inflation

**Symptom:** Treating every finding as P1. Everything is "critical," so nothing is prioritized.

**Fix:** Use the severity definitions strictly. P1 = blocks acceptance criterion. If the current implementation satisfies the acceptance criterion, the finding is P2 at most. Reserve P1 for genuine spec violations.

### 6. Scope Creep via P3 Accumulation

**Symptom:** 15 P3 findings each take "just 5 minutes." Total: 75 minutes of unplanned work on nice-to-haves.

**Fix:** Apply the effort threshold. P3 + Small effort = follow-up issue. P3 + Trivial = fix if convenient (defined as: requires no additional test, no additional file, no architectural change). "Convenient" does not mean "I could do it."

## Guard Rails

1. **No implementation before VERIFY-AGAINST-SPEC.** The natural instinct is to start fixing immediately. Resist. Classification first.

2. **Drift rejection requires a spec reference.** Do not push back with "I don't think this is in scope." Push back with "AC #1-#5 cover [summary]; this suggestion adds [X] which is not in any AC."

3. **Every deferred item becomes an issue.** If feedback is valid but deferred, it must exist as a tracked issue, not a mental note. If it's worth deferring, it's worth tracking.

4. **Spec gaps are not the reviewer's problem.** When the reviewer finds a legitimate gap, thank them. The gap is the spec's fault. Propose the update promptly.

5. **Contradictions block implementation.** When findings conflict, the resolution is a decision, not a code change. Escalate contradictions to the human.

## Cross-Skill References

- **adversarial-review** — The _giving_ counterpart. Defines the finding format (P1/P2/P3), persona panel, structured debate, and RDR output that this skill consumes.
- **drift-prevention** — Provides the anchoring protocol that review-response uses for VERIFY-AGAINST-SPEC. The same spec re-read process applies.
- **tdd-enforcement** — When implementing review fixes, follow TDD discipline: write a failing test for the fix, then implement. This prevents review fixes from introducing regressions.
- **debugging-methodology** — When investigating review findings that report incorrect behavior, use the 4-phase debugging loop. The reviewer's finding statement replaces "ACTUAL behavior" in the debugging SCOPE phase.
- **quality-scoring** — Review response completeness (% of findings addressed, deferred with tracking, or rejected with evidence) feeds into the quality score.
- **execution-modes** — The retry budget applies to review-triggered fixes. If two approaches to fix a P1 finding fail, escalate per the standard retry protocol.
