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

## Methodology vs. Runtime

This skill defines the **methodology** — how to review (perspectives, severity, output format, RDR). The **runtime** is Agent Teams at `~/.claude/agents/` — 7 named persona agents dispatched via Linear delegation. Reviews run via Agent Teams dispatch, NOT in interactive Code sessions (established Feb 19 retro). This separation is a deliberate architectural decision, not a transitional state.

## Reviewer Personas (7)

Reviews use specialized persona agents, each with a defined scope. Select 3+ personas per review based on spec type (see selection guide below). All 7 live at `~/.claude/agents/` and are dispatched via Agent Teams.

### architectural-purist (Blue)

System design, coupling, abstraction boundaries, and long-term maintainability.

- Is coupling accidental (never acceptable) or pragmatic (acceptable with documentation)?
- Do abstraction boundaries align with domain boundaries?
- Are API contracts stable under extension?
- Does single responsibility hold at module, class, and function level?

### security-skeptic (Red)

Attack vectors, auth boundaries, data handling, and compliance. Every finding must describe a concrete attack scenario.

- What data flows through this feature and who can access it?
- Where could injection, escalation, or exfiltration occur?
- Are authentication and authorization boundaries clearly defined?
- Does this introduce new attack surface area?

### performance-pragmatist (Orange)

Scaling cliffs, resource bottlenecks, and operational cost. Always quantify — "slow" is not a finding.

- What is the cardinality at which this design breaks?
- Where are the N+1 queries, unbounded loops, or missing pagination?
- What is the caching strategy and invalidation model?
- What are the concrete failure/recovery paths?

### ux-advocate (Green)

User journey (end users, developers, operators), error experience, cognitive load, and accessibility.

- Can the user recover from every error state?
- Is cognitive load under the 5-7 option threshold?
- Are destructive actions guarded with confirmation?
- Does this meet keyboard, contrast, and screen reader requirements?

### ops-realist (Yellow)

Deployment topology, CI/CD gaps, environment configuration, rollback strategy, and infrastructure cost.

- What does the on-call engineer see when this fails?
- Are new secrets, env vars, or build steps documented?
- What is the rollback strategy?
- What is the concrete per-platform cost impact?

### supply-chain-auditor (Cyan)

Dependency health, version compatibility, breaking change impact, license drift, and supply chain risk.

- What is the bus factor and maintenance status of new dependencies?
- Are versions pinned or using ranges? What is the `pnpm update` risk?
- Is this tracked in `monitored-repos.yml` at the right tier?
- Are there copyleft or license compatibility risks?

### observability-eval (Purple)

Instrumentation coverage, metric selection, alerting gaps, and verification evidence.

- Can each acceptance criterion be verified in production (not just tests)?
- Which tool covers this: PostHog, Sentry, Honeycomb, or Vercel Analytics?
- What baseline metrics exist for comparison?
- Is the eval pipeline configured for AI/LLM features?

### Persona Selection by Spec Type

| Spec Type | Recommended Personas (minimum 3) |
|-----------|----------------------------------|
| Feature (user-facing) | ux-advocate, security-skeptic, architectural-purist |
| Infrastructure/CI | ops-realist, security-skeptic, supply-chain-auditor |
| Research/data pipeline | observability-eval, performance-pragmatist, architectural-purist |
| Integration/API | architectural-purist, security-skeptic, performance-pragmatist |
| Full adversarial (complex, 5+ pt) | All 7 (via structured debate, Option F) |

### Synthesizer

After all selected personas have reviewed, the synthesizer consolidates findings into a prioritized action list.

**Critical** -- Must address before implementation. These are blockers: security vulnerabilities, contradictory requirements, missing error handling for likely scenarios.

**Important** -- Should address before implementation. These improve quality significantly: ambiguous acceptance criteria, missing edge cases, questionable architectural choices.

**Consider** -- Nice to have. These are improvements worth discussing: alternative approaches, performance optimizations, future extensibility concerns.

The synthesizer flags disagreements between personas and notes where they reached opposing conclusions.

## Architecture Options

Eight options for running adversarial reviews. Select based on automation needs, cost tolerance, and review depth required.

| Option | Name | Cost | Automation | Depth | Key Trait |
|--------|------|------|------------|-------|-----------|
| **A** | CI Agent | $0 | Full | Medium | Free async via GitHub Actions |
| **B** | Premium Agents | ~$40/mo | Full | High | Premium model, async |
| **C** | API + Actions | Variable | Full | Best | Multi-model, configurable |
| **D** | In-Session Subagents | $0 | Manual | High | Immediate feedback, no setup |
| **E** | Persona Panel | $0 | Manual | Best | 7 specialized personas via Agent Teams |
| **F** | Structured Debate | $0 | Manual | Best | 2-round cross-examination |
| **G** | Multi-Model Tier | $0 | Manual | Best | Cross-tier validation, ~55% unique findings |
| **H** | Linear Agent Dispatch | $0-20 | Full | Variable | Async external agents, cross-model-family |

**Option routing:**
- Simple specs (single feature, clear scope) -> Option D (in-session subagents)
- Complex specs (3+ systems, cross-cutting concerns) -> Option E (7 persona Agent Teams)
- High-stakes or domain-tension specs -> Option F (structured debate with personas)
- Maximum coverage desired -> Option G (multi-model tier)
- **Async dispatch (canonical path)** -> Option H (Linear Agent Teams dispatch — preferred for all non-trivial reviews)
- CI automation needed -> Option A (free) or C (configurable)

> Full option descriptions, tradeoff tables, and hybrid combinations: `references/adversarial-review/architecture-options.md`

## Review Output Format

Regardless of architecture option, the review output follows this structure:

```
## Adversarial Review: [Spec Title]

### [persona-name] Findings
- [Finding with severity: Critical/Important/Consider]
(Repeat for each persona in the review panel)

### Synthesis
**Critical (must address):**
1. [C1] ...

**Important (should address):**
1. [I1] ...

**Consider (nice to have):**
1. [N1] ...

### Recommendation
[APPROVE / REVISE / RETHINK]
```

Example with 3 personas:
```
### architectural-purist Findings
- [C1] API contract breaks backward compatibility (Critical)

### security-skeptic Findings
- [I1] Missing rate limiting on public endpoint (Important)

### ux-advocate Findings
- [N1] Error message could be more actionable (Consider)
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
