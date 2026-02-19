---
name: outcome-validation
description: |
  Layer 6 business outcome validation using sequential persona passes. Evaluates whether a completed
  feature actually delivered its intended business outcome before closure. Four personas — Customer
  Advocate, CFO Lens, Product Strategist, and Skeptic — each produce an independent sub-verdict with
  evidence. The final consolidated verdict (ACHIEVED / PARTIALLY_ACHIEVED / NOT_ACHIEVED /
  UNDETERMINABLE) feeds into quality-scoring and appears in the closing comment.
  Integration point: runs between Stage 7 (Verification) and Stage 7.5 (Closure) in /ccc:close.
  Automatically skipped for type:chore, type:spike, --quick flag, and exec:quick issues <=2pt.
  Use when closing a feature or bug issue that went through the full CCC funnel.
  Trigger with phrases like "outcome validation", "business outcome check", "did this achieve its goal",
  "Layer 6 validation", "persona review", "outcome verdict", "validate business outcome".
---

# Outcome Validation

Outcome validation is the practice of evaluating whether a completed issue actually delivered its intended business outcome, not just whether it was implemented correctly. Quality scoring (the existing CCC skill) answers "was it built well?" — outcome validation answers "was the right thing built?"

This is Layer 6 of the CCC quality model. It sits between Stage 7 (Verification — deployment confirmed, tests passing) and Stage 7.5 (Closure — issue marked Done). By the time outcome validation runs, we already know the code works. The question is whether it matters.

## Why This Exists

Quality scoring measures three dimensions: test coverage, acceptance criteria coverage, and review resolution. All three are inward-facing — they verify the implementation against its own spec. None of them ask whether the spec itself was aimed at the right target.

A feature can score 100/100 on quality and still be a waste if:
- The user problem it claims to solve doesn't actually exist
- The cost of building it exceeds the value it delivers
- It conflicts with the product's strategic direction
- The claimed benefits rest on unexamined assumptions

Outcome validation catches these failures by applying four distinct business lenses to the completed work. Each lens has a different concern, a different failure mode it detects, and a different set of evidence it examines.

## When to Run

Outcome validation runs as part of the `/ccc:close` workflow. It is invoked automatically — you do not need to call it separately.

### Trigger Conditions

Outcome validation **runs** when ALL of these are true:
1. The issue has `type:feature` or `type:bug` label
2. The `--quick` flag was NOT used during the `/ccc:go` invocation
3. The issue is NOT `exec:quick` with an estimate of 2 points or less

Outcome validation is **skipped** when ANY of these are true:

| Condition | Reason | Skip Message |
|-----------|--------|--------------|
| `type:chore` label | Chores are maintenance tasks without business outcomes | `Outcome validation: Skipped (type:chore)` |
| `type:spike` label | Spikes produce knowledge, not deliverable outcomes | `Outcome validation: Skipped (type:spike)` |
| `--quick` flag was used | Quick mode minimizes ceremony for small changes | `Outcome validation: Skipped (--quick mode)` |
| `exec:quick` AND estimate <= 2pt | Too small to warrant business outcome analysis | `Outcome validation: Skipped (exec:quick, estimate <=2pt)` |
| `exec:quick` AND no estimate | Unestimated defaults to 1pt per workspace config | `Outcome validation: Skipped (exec:quick, unestimated)` |

**Edge case — `exec:quick` with 3pt+:** These issues DO run outcome validation. A 3-point quick issue is large enough that its business outcome should be verified, even if the implementation approach was straightforward.

**Edge case — `type:bug` issues:** Bugs always run outcome validation (unless another skip condition applies). The outcome being validated is "the bug is actually fixed and the user's problem is resolved," not just "a code change was made."

### Skip Detection Logic

```
function shouldRunOutcomeValidation(issue, quickFlag):
  # Skip conditions (check in order)
  if quickFlag == true:
    return SKIP("--quick mode")

  if issue.labels contains "type:chore":
    return SKIP("type:chore")

  if issue.labels contains "type:spike":
    return SKIP("type:spike")

  if issue.labels contains "exec:quick":
    estimate = issue.estimate ?? 1  # unestimated counts as 1pt
    if estimate <= 2:
      return SKIP("exec:quick, estimate <=" + estimate + "pt")

  # No skip conditions met — run validation
  return RUN
```

## The Four Persona Passes

Outcome validation uses four sequential business personas. Each persona reads the same inputs but evaluates them through a different lens. The order matters — later personas build on earlier ones.

### Inputs (Same for All Personas)

Before starting the persona passes, collect these inputs:

1. **The original PR/FAQ or spec** — specifically the Press Release section (the claimed customer benefit) and the FAQ section (the anticipated concerns)
2. **The acceptance criteria** — what the spec said "done" looks like
3. **The quality score** — the test/coverage/review scores from quality-scoring
4. **The actual deliverables** — PRs merged, files changed, deployment status
5. **Any review findings** — adversarial review findings that were addressed or carried forward

### Pass 1: Customer Advocate

**Perspective:** Represents the end user. Evaluates whether the delivered feature actually solves the user's problem as described in the spec's press release.

**Evaluates:**
- Does the implementation address the user pain point stated in the PR/FAQ?
- Would a real user notice and benefit from this change?
- Are there usability gaps between what was specified and what was delivered?
- Does the delivered experience match the press release's promise?

**Failure modes this persona catches:**
- Feature is technically correct but solves the wrong problem
- Feature addresses a developer concern, not a user concern
- The claimed user benefit is theoretical, not practical
- User-facing experience degraded by implementation shortcuts

**Sub-verdict format:**
```markdown
### Customer Advocate
**Verdict:** [ACHIEVED | PARTIALLY_ACHIEVED | NOT_ACHIEVED | UNDETERMINABLE]
- [Evidence line 1: specific observation about user impact]
- [Evidence line 2: reference to spec promise vs delivered reality]
- [Evidence line 3: (optional) gap or recommendation]
```

**Verdict criteria:**
| Verdict | When |
|---------|------|
| ACHIEVED | The delivered feature clearly solves the stated user problem |
| PARTIALLY_ACHIEVED | The core user problem is addressed but significant gaps remain |
| NOT_ACHIEVED | The delivered feature does not solve the stated user problem |
| UNDETERMINABLE | Insufficient information to assess user impact (e.g., no PR/FAQ, no clear user story) |

### Pass 2: CFO Lens

**Perspective:** Represents resource stewardship. Evaluates whether the investment (time, complexity, operational cost) was proportionate to the value delivered.

**Evaluates:**
- Is the implementation complexity proportionate to the problem's importance?
- Does this introduce ongoing operational costs (monitoring, maintenance, infrastructure)?
- Could the same outcome have been achieved with significantly less effort?
- Are there hidden costs (technical debt, coupling, performance overhead)?

**Failure modes this persona catches:**
- Gold-plated solution for a minor problem
- Feature that creates ongoing maintenance burden disproportionate to its value
- Over-engineered implementation when a simpler approach would suffice
- Resource allocation that trades short-term convenience for long-term cost

**Sub-verdict format:**
```markdown
### CFO Lens
**Verdict:** [ACHIEVED | PARTIALLY_ACHIEVED | NOT_ACHIEVED | UNDETERMINABLE]
- [Evidence line 1: cost/value proportionality assessment]
- [Evidence line 2: ongoing cost or maintenance implications]
- [Evidence line 3: (optional) efficiency observation]
```

**Verdict criteria:**
| Verdict | When |
|---------|------|
| ACHIEVED | Implementation cost is proportionate; no concerning ongoing costs |
| PARTIALLY_ACHIEVED | Outcome delivered but at higher cost than necessary, or with notable ongoing costs |
| NOT_ACHIEVED | Cost clearly exceeds value; significant waste or over-engineering |
| UNDETERMINABLE | Cannot assess cost proportionality (e.g., exploratory work, no estimate) |

### Pass 3: Product Strategist

**Perspective:** Represents strategic alignment. Evaluates whether the delivered feature advances the product's direction and creates leverage for future work.

**Evaluates:**
- Does this feature align with the product roadmap and current priorities?
- Does it create positive leverage (enables future features, reduces future cost)?
- Does it conflict with or duplicate existing functionality?
- Does it position the product well competitively?

**Failure modes this persona catches:**
- Feature that is locally valuable but strategically misaligned
- Missed opportunity to build reusable infrastructure
- Duplication of existing capability under a different name
- Feature that locks the product into a suboptimal architectural direction

**Sub-verdict format:**
```markdown
### Product Strategist
**Verdict:** [ACHIEVED | PARTIALLY_ACHIEVED | NOT_ACHIEVED | UNDETERMINABLE]
- [Evidence line 1: alignment with product direction]
- [Evidence line 2: leverage or compounding effect]
- [Evidence line 3: (optional) strategic risk or opportunity]
```

**Verdict criteria:**
| Verdict | When |
|---------|------|
| ACHIEVED | Feature advances product strategy and creates positive leverage |
| PARTIALLY_ACHIEVED | Aligns with strategy but misses leverage opportunities |
| NOT_ACHIEVED | Feature conflicts with product direction or creates strategic debt |
| UNDETERMINABLE | No clear product strategy context available to evaluate against |

### Pass 4: Skeptic

**Perspective:** Adversarial challenge to the prior three verdicts. Specifically looks for blind spots, unfounded assumptions, and groupthink across the earlier passes.

**Evaluates:**
- Are the prior verdicts well-supported by evidence, or based on assumptions?
- What could go wrong that no one has considered?
- Are there implicit assumptions in the spec that were never validated?
- Would a reasonable person disagree with any of the prior verdicts?

**Failure modes this persona catches:**
- Confirmation bias across the first three personas
- Unexamined assumptions that all personas shared
- Risks that the positive framing of earlier passes obscured
- Evidence gaps that were glossed over rather than flagged

**Sub-verdict format:**
```markdown
### Skeptic
**Verdict:** [ACHIEVED | PARTIALLY_ACHIEVED | NOT_ACHIEVED | UNDETERMINABLE]
- [Evidence line 1: assessment of prior verdict quality]
- [Evidence line 2: identified blind spots or unexamined assumptions]
- [Evidence line 3: (optional) risk flag or dissent]
```

**Verdict criteria:**
| Verdict | When |
|---------|------|
| ACHIEVED | Prior verdicts are well-supported; no significant blind spots found |
| PARTIALLY_ACHIEVED | Prior verdicts are mostly sound but rest on 1-2 unverified assumptions |
| NOT_ACHIEVED | Prior verdicts are poorly supported; significant blind spots or unfounded assumptions |
| UNDETERMINABLE | Cannot adequately assess prior verdicts due to insufficient evidence in the spec or deliverables |

## Final Verdict Consolidation

After all four passes complete, produce a consolidated final verdict.

### Consolidation Rules

The final verdict is determined by the distribution of sub-verdicts:

| Sub-Verdict Distribution | Final Verdict |
|--------------------------|---------------|
| 4/4 ACHIEVED | **ACHIEVED** |
| 3/4 ACHIEVED, 1/4 PARTIALLY_ACHIEVED | **ACHIEVED** |
| 3/4 ACHIEVED, 1/4 NOT_ACHIEVED | **PARTIALLY_ACHIEVED** |
| 2/4 ACHIEVED, 2/4 PARTIALLY_ACHIEVED | **PARTIALLY_ACHIEVED** |
| Any majority NOT_ACHIEVED (3+/4) | **NOT_ACHIEVED** |
| Any majority UNDETERMINABLE (3+/4) | **UNDETERMINABLE** |
| Skeptic verdict is NOT_ACHIEVED | Downgrade final by one level (ACHIEVED → PARTIALLY_ACHIEVED) |
| Mixed with no clear majority | Use the median severity: ACHIEVED > PARTIALLY > NOT > UNDETERMINABLE |

**Skeptic override:** If the Skeptic's verdict is more severe than the other three personas' consensus, the Skeptic's concerns carry extra weight. Specifically, if the Skeptic returns NOT_ACHIEVED while the other three return ACHIEVED, the final verdict is downgraded to PARTIALLY_ACHIEVED. This prevents the Skeptic from being outvoted by three personas who may share the same blind spot.

### Output Format

```markdown
## Outcome Validation — [Issue ID]

### Customer Advocate
**Verdict:** [VERDICT]
- [evidence line 1]
- [evidence line 2]

### CFO Lens
**Verdict:** [VERDICT]
- [evidence line 1]
- [evidence line 2]

### Product Strategist
**Verdict:** [VERDICT]
- [evidence line 1]
- [evidence line 2]

### Skeptic
**Verdict:** [VERDICT]
- [evidence line 1]
- [evidence line 2]

### Final Verdict: [CONSOLIDATED VERDICT]
Confidence: [N]/4 ACHIEVED, [N]/4 PARTIALLY_ACHIEVED, [N]/4 NOT_ACHIEVED, [N]/4 UNDETERMINABLE
```

## Integration with Quality Scoring

The outcome validation verdict feeds into the quality-scoring skill as a score adjustment. This ensures that business outcome is reflected in the overall quality grade.

### Score Adjustment Table

| Final Verdict | Score Adjustment | Rationale |
|---------------|-----------------|-----------|
| ACHIEVED | +0 | No adjustment — outcome met expectations |
| PARTIALLY_ACHIEVED | -5 | Minor shortfall; still closeable but noted |
| NOT_ACHIEVED | -15 | Significant shortfall; likely blocks auto-close |
| UNDETERMINABLE | -10 | Evidence gap; should not auto-close without clarity |

**How the adjustment applies:**

1. Quality scoring calculates its base score: `(test * 0.40) + (coverage * 0.30) + (review * 0.30)`
2. Outcome validation runs and produces its verdict
3. The verdict adjustment is applied: `final_score = base_score + outcome_adjustment`
4. The adjusted score determines the closure action (auto-close, propose, block)

**Example:** A feature scores 88 (Strong, ★★★★) on quality. Outcome validation returns PARTIALLY_ACHIEVED (-5). Adjusted score: 83 (still Strong, ★★★★). The feature is still auto-close eligible, but the closing comment notes the partial achievement.

**Example:** A feature scores 72 (Acceptable, ★★★). Outcome validation returns NOT_ACHIEVED (-15). Adjusted score: 57 (Inadequate, ★). Closure is blocked. The issue returns to In Progress with specific outcome gaps listed.

### Score Adjustment in Closing Comment

When outcome validation applies a non-zero adjustment, include it in the quality score display:

```markdown
## Quality Score — CIA-XXX

| Dimension | Grade | Evidence |
|-----------|-------|----------|
| Test (40%) | ★★★★ | 8/10 criteria tested, all passing |
| Coverage (30%) | ★★★★★ | All acceptance criteria met |
| Review (30%) | ★★★★ | All findings resolved |
| **Outcome (adj)** | **-5** | **PARTIALLY_ACHIEVED — strategic gaps noted** |

**Overall: ★★★★ Strong (83/100, adjusted from 88)** — Auto-close eligible
```

## Integration with /ccc:close

Outcome validation inserts into the `/ccc:close` workflow between the existing steps:

```
Step 1: Fetch Issue Metadata       ← existing
Step 2: Evaluate Closure Conditions ← existing
Step 2.5: Outcome Validation        ← NEW (this skill)
Step 3: Compose Closing Comment     ← existing (now includes outcome verdict)
Step 4: Execute                     ← existing
Step 5: Update Labels               ← existing
```

### Step 2.5: Outcome Validation

After evaluating closure conditions (Step 2) and before composing the closing comment (Step 3):

1. **Check skip conditions.** Read the issue's labels and estimate. Check if `--quick` was used (from `.ccc-state.json` or command flags). Apply the skip detection logic.

2. **If skipped:** Log the skip message and proceed directly to Step 3. Include the skip message in the closing comment under a brief "Outcome validation: Skipped ([reason])" line.

3. **If running:** Collect the inputs (PR/FAQ, acceptance criteria, quality score, deliverables, review findings). Execute the four persona passes sequentially. Consolidate the final verdict. Calculate the score adjustment.

4. **Apply score adjustment.** Pass the adjustment to quality scoring. The quality score displayed in Step 3's closing comment reflects the adjusted total.

5. **Include verdict in closing comment.** The outcome validation section appears in the closing comment between "Verification Evidence" and "What Was Delivered."

### Closing Comment Integration

The closing comment template from close.md gains a new section:

```markdown
## Closure Summary

**Status:** [Auto-closing | Proposing closure | Blocked]
**Reason:** [Which closure rule applies]

### Deliverables
- PR: [link] — [title] ([merged/open])

### Deployment
- Deploy status: [green/pending/failed/not configured]

### Verification Evidence
- [x] All acceptance criteria addressed
- [x] Tests passing
- [x] Build green

### Outcome Validation
[Full outcome validation output — 4 personas + final verdict]
[OR: "Outcome validation: Skipped ([reason])"]

### What Was Delivered
[2-3 sentence summary]
```

## Anti-Patterns

**Rubber-stamping.** Running the four personas but giving every one ACHIEVED without genuine evaluation. Each persona must cite specific evidence from the deliverables and spec. Generic statements like "the feature looks good" are not valid evidence.

**Skipping the Skeptic.** The temptation to treat the Skeptic as optional because the first three personas agreed. The Skeptic exists precisely for when the first three agree — consensus without challenge is the highest-risk scenario.

**Outcome-washing.** Retroactively redefining the outcome to match what was delivered instead of evaluating what was delivered against the original outcome. The press release section of the PR/FAQ is the baseline — not a post-hoc rationalization of what was built.

**Over-applying.** Running outcome validation on trivial changes that clearly don't need it. The skip conditions exist for a reason. A 1-point dependency update does not need four business personas to evaluate it.

**Verdict inflation.** Defaulting to ACHIEVED when PARTIALLY_ACHIEVED is more accurate. A feature that delivers 60% of its claimed benefit is PARTIALLY_ACHIEVED, not ACHIEVED with caveats. Caveats belong in the evidence lines, not hidden behind an inflated verdict.

**Ignoring UNDETERMINABLE.** Treating UNDETERMINABLE as "probably fine" rather than as a genuine signal that the spec lacked sufficient business context. UNDETERMINABLE should trigger a conversation about whether the spec needs retroactive enrichment, not silent acceptance.

## Examples

### Example 1: Feature That Achieves Its Outcome

**Issue:** CIA-300 "Add real-time collaboration indicators to the editor"
**PR/FAQ claim:** "Users will see when teammates are editing the same document, reducing conflicts by 70%."

```markdown
## Outcome Validation — CIA-300

### Customer Advocate
**Verdict:** ACHIEVED
- Presence indicators show which teammates are active in the document
- Cursor positions are visible, directly addressing the "editing the same section" conflict scenario
- UX matches the press release promise: users can see and avoid concurrent edits

### CFO Lens
**Verdict:** ACHIEVED
- Implementation uses existing WebSocket infrastructure; no new operational cost
- Complexity is proportionate: ~200 LOC for a high-visibility user feature

### Product Strategist
**Verdict:** ACHIEVED
- Real-time collaboration is a key differentiator on the product roadmap
- Creates leverage: the presence system can be extended to comments, reviews, and notifications

### Skeptic
**Verdict:** PARTIALLY_ACHIEVED
- The "70% conflict reduction" claim in the press release is unverifiable without usage data
- Prior verdicts are sound for the feature itself, but the quantitative benefit is assumed, not proven
- Recommend: add analytics to measure actual conflict reduction post-launch

### Final Verdict: ACHIEVED
Confidence: 3/4 ACHIEVED, 1/4 PARTIALLY_ACHIEVED
```

### Example 2: Feature That Partially Achieves Its Outcome

**Issue:** CIA-350 "Implement automated weekly digest emails"
**PR/FAQ claim:** "Users receive a personalized weekly summary of their project activity, increasing re-engagement by 40%."

```markdown
## Outcome Validation — CIA-350

### Customer Advocate
**Verdict:** PARTIALLY_ACHIEVED
- Weekly digest is sent, but content is generic (same template for all users)
- The press release promised "personalized" summaries; implementation uses project-level aggregation, not user-level
- Users with multiple projects receive a single combined digest, not per-project summaries

### CFO Lens
**Verdict:** ACHIEVED
- Email infrastructure cost is minimal (SendGrid existing plan)
- Implementation is straightforward; no ongoing maintenance concern

### Product Strategist
**Verdict:** PARTIALLY_ACHIEVED
- Digest emails align with re-engagement strategy
- Missing personalization reduces the strategic value — generic digests have historically low open rates
- The foundation is good but needs a Phase 2 for personalization to achieve the claimed 40% lift

### Skeptic
**Verdict:** PARTIALLY_ACHIEVED
- Customer Advocate and Product Strategist correctly identify the personalization gap
- The "40% re-engagement increase" is aspirational with generic content; industry benchmarks suggest 5-10% for non-personalized digests
- CFO Lens verdict stands — cost is reasonable regardless of engagement outcome

### Final Verdict: PARTIALLY_ACHIEVED
Confidence: 1/4 ACHIEVED, 3/4 PARTIALLY_ACHIEVED
```

## Cross-Skill References

- **quality-scoring** — Outcome validation feeds a score adjustment into the quality score. The verdict is consumed by quality-scoring to produce the adjusted final score displayed in the closing comment.
- **close (command)** — Outcome validation is invoked by `/ccc:close` at Step 2.5, between closure condition evaluation and closing comment composition.
- **prfaq-methodology** — The PR/FAQ press release section is the primary input for the Customer Advocate persona. A well-written press release makes outcome validation more precise.
- **adversarial-review** — Stage 4 adversarial review catches spec-level issues before implementation. Outcome validation catches outcome-level issues after implementation. They are complementary gates.
- **references/evidence-mandate.md** — The evidence mandate verifies that artifacts exist and claims are evidenced. Outcome validation verifies that the delivered artifacts achieve their intended purpose.
- **execution-engine** — The execution engine tracks `--quick` flag in `.ccc-state.json`. Outcome validation reads this flag to determine skip conditions.
- **issue-lifecycle** — Outcome validation's final verdict influences whether an issue can be auto-closed (via score adjustment) or requires human review.
