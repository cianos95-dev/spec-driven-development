---
name: adversarial-review
description: |
  Adversarial spec review methodology with multiple reviewer perspectives and architecture options for automated review pipelines.
  Use when a spec needs critical evaluation before implementation, when you want structured pushback on assumptions, or when setting up automated multi-perspective review.
  Trigger with phrases like "review my spec", "adversarial review", "challenge this proposal", "devil's advocate analysis", "security review of spec", "is this spec ready for implementation".
compatibility:
  surfaces: [code, cowork, desktop]
  tier: universal
---

# Adversarial Spec Review

Every spec that passes through this funnel receives structured adversarial review before implementation begins. The review is not editorial -- it stress-tests the spec for gaps that would become bugs, security incidents, or wasted effort.

## Reviewer Perspectives

All review architectures use the same three reviewer perspectives plus a synthesizer. These are not optional -- every review must include all three.

### 1. Challenger

Find gaps, ambiguities, contradictions, and unstated assumptions. Be adversarial.

- What requirements are vague enough to be implemented two different ways?
- What edge cases are not addressed?
- Where does the spec contradict itself?
- What assumptions are made but never stated?
- What happens when inputs are empty, null, extremely large, or malformed?
- Are success criteria measurable and unambiguous?

### 2. Security Reviewer

Identify attack vectors, data handling risks, privacy concerns, and compliance gaps.

- What data flows through this feature and who can access it?
- Where could injection, escalation, or exfiltration occur?
- Are authentication and authorization boundaries clearly defined?
- What PII or sensitive data is involved and how is it stored/transmitted?
- Does this introduce new attack surface area?
- Are there regulatory or compliance implications (GDPR, SOC2, HIPAA)?

### 3. Devil's Advocate

Challenge the fundamental approach. Propose completely different alternatives. Question core assumptions.

- Why this solution and not a fundamentally different one?
- What if the core premise is wrong?
- Could this be solved with zero new code?
- What would a competitor do differently?
- Is this solving the right problem, or a symptom of a deeper issue?
- What would make this entire approach obsolete in 6 months?

### Synthesizer

After all three perspectives have been applied, the synthesizer consolidates findings into a prioritized action list.

**Critical** -- Must address before implementation. These are blockers: security vulnerabilities, contradictory requirements, missing error handling for likely scenarios.

**Important** -- Should address before implementation. These improve quality significantly: ambiguous acceptance criteria, missing edge cases, questionable architectural choices.

**Consider** -- Nice to have. These are improvements worth discussing: alternative approaches, performance optimizations, future extensibility concerns.

The synthesizer also flags any disagreements between reviewers and notes where the Challenger and Devil's Advocate reached opposing conclusions.

## Architecture Options

Eight options for running adversarial reviews. Select based on automation needs, cost tolerance, and review depth required.

| Option | Name | Cost | Automation | Depth | Key Trait |
|--------|------|------|------------|-------|-----------|
| **A** | CI Agent | $0 | Full | Medium | Free async via GitHub Actions |
| **B** | Premium Agents | ~$40/mo | Full | High | Premium model, async |
| **C** | API + Actions | Variable | Full | Best | Multi-model, configurable |
| **D** | In-Session Subagents | $0 | Manual | High | Immediate feedback, no setup |
| **E** | Persona Panel | $0 | Manual | Best | 4 specialized personas, validated |
| **F** | Structured Debate | $0 | Manual | Best | 2-round cross-examination |
| **G** | Multi-Model Tier | $0 | Manual | Best | Cross-tier validation, ~55% unique findings |
| **H** | Linear Agent Dispatch | $0-20 | Full | Variable | Async external agents, cross-model-family |

**Option routing:**
- Simple specs (single feature, clear scope) -> Option D
- Complex specs (3+ systems, cross-cutting concerns) -> Option E
- High-stakes or domain-tension specs -> Option F
- Maximum coverage desired -> Option G
- Async/cross-model-family diversity -> Option H
- CI automation needed -> Option A (free) or C (configurable)

> Full option descriptions, tradeoff tables, and hybrid combinations: `references/adversarial-review/architecture-options.md`

## Review Output Format

Regardless of architecture option, the review output follows this structure:

```
## Adversarial Review: [Spec Title]

### Challenger Findings
- [Finding with severity: Critical/Important/Consider]

### Security Review
- [Finding with severity: Critical/Important/Consider]

### Devil's Advocate
- [Alternative approach or fundamental challenge]

### Synthesis
**Critical (must address):**
1. ...

**Important (should address):**
1. ...

**Consider (nice to have):**
1. ...

### Recommendation
[APPROVE / REVISE / RETHINK]
```

The recommendation is one of:
- **APPROVE** -- Spec is ready for implementation with minor adjustments
- **REVISE** -- Spec needs significant changes to address Critical findings
- **RETHINK** -- Fundamental approach is questioned; consider alternative solutions

## Review Decision Record (RDR)

Every review synthesis must end with an RDR table -- the artifact Gate 2 operates on. It transforms implicit approval into explicit, traceable decisions on each finding.

**Decision values:** `agreed` | `override` (with rationale) | `deferred` (with issue link) | `rejected` (with explanation)

**Gate 2 passes when:** All Critical + Important rows have a Decision value.

**ID convention:** Severity-initial + sequential number: `C1`, `C2`, `I1`, `I2`, `N1`, `N2`.

**Inline decision shorthand:** `"agree all"` | `"agree all except C2, I3"` | `"agree C1-C3, override I2: [reason], defer I3 to CIA-456"`

**Where RDR lives:** Primary: project tracker comment on the parent issue. Secondary: `REVIEW-GATE-FINDINGS.md` at feature branch root for repo audit trail.

> Full RDR format specification, table variants, and decision vocabulary: `references/adversarial-review/rdr-specification.md`
> Finding normalization (Option H), storage patterns, and fix-forward summary: `references/adversarial-review/finding-normalization.md`

## When to Review Liberally

Not every spec needs the full adversarial ceremony. Match review depth to issue type and risk level.

| Issue Type | Review Depth | Rationale |
|-----------|-------------|-----------|
| Feature (3+ pt) | Full adversarial (Option D-H) | Enough complexity to justify multi-perspective review |
| Feature (1-2pt) | Single-pass Option D | Generic 3-reviewer pass; persona panel is overkill |
| Spike | Scope-only single reviewer | Focus on research question scoping, GO/NO-GO criteria, time box |
| Bug fix | Regression-focused single reviewer | Verify root cause and regression risk |
| Chore | Static quality checks only | `bash tests/test-static-quality.sh` is sufficient |
| Docs-only | Challenger only (accuracy check) | Skip Security Reviewer and Devil's Advocate |

### Mandatory Full Review Triggers

Escalate to full adversarial review (Option D-H) when any of these apply, regardless of issue type:

1. **Cross-session handoffs** -- spec being handed to another session (Factory dispatch, Agent Teams)
2. **Hook or stop-handler changes** -- modifications to hooks, stop handler, or execution engine
3. **High-dependency specs** -- 3+ downstream dependents (check `blockedBy`/`blocks` relations)
4. **Security-sensitive changes** -- authentication, authorization, credential handling, data exposure
5. **Pre-launch phase** -- during milestone pushes, default to reviewing rather than skipping

## Multi-Model Consensus

When using multiple model tiers (Option G), findings are tagged by tier agreement:
- `convergent` -- found by both sonnet AND haiku (~44% of findings, highest confidence)
- `sonnet-only` -- found only by sonnet (~45%, mostly integration/quantitative analysis)
- `haiku-only` -- found only by haiku (~11%, mostly user confusion/strategic identity)

Consensus scoring: 6+/8 = CRITICAL, 4-5/8 = HIGH, 2-3/8 = MODERATE, 1/8 = MINORITY.

> Full multi-model consensus protocol, exchange format, and tier analysis: `references/adversarial-review/multi-model-consensus.md`

## Implementation References

GitHub Actions workflow files for Options A-C: `skills/adversarial-review/references/`

## Reference Index

All extracted reference material for this skill:

| Reference | Contents |
|-----------|----------|
| `references/adversarial-review/architecture-options.md` | Full Options A-H descriptions, tradeoff tables, hybrid combinations |
| `references/adversarial-review/rdr-specification.md` | RDR format, decision vocabulary, inline collection, storage |
| `references/adversarial-review/finding-normalization.md` | Finding normalization (Option H), review storage, fix-forward summary |
| `references/adversarial-review/multi-model-consensus.md` | Multi-model consensus, tier tagging, exchange format, user decision log |
