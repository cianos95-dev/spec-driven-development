---
name: adversarial-review
description: |
  Adversarial spec review methodology with multiple reviewer perspectives and architecture options for automated review pipelines.
  Use when a spec needs critical evaluation before implementation, when you want structured pushback on assumptions, or when setting up automated multi-perspective review.
  Trigger with phrases like "review my spec", "adversarial review", "challenge this proposal", "devil's advocate analysis", "security review of spec", "is this spec ready for implementation".
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

Six options for running adversarial reviews, ordered by automation level. Options A-D are the original architectures. Options E-F extend the review methodology with persona-based and debate-driven approaches, validated by A/B testing (CIA-395).

Options A-D trigger on spec file merge to `docs/specs/` on the main branch of your ~~version-control~~ repository. Options E-F are session-triggered.

### Option A: CI Agent (Free)

GitHub Actions detects spec merge and assigns a review issue to a CI-tier coding agent (e.g., `@copilot`).

| Dimension | Rating |
|-----------|--------|
| Monthly cost | $0 additional |
| Automation level | Full |
| Review model quality | Good (Sonnet-tier) |
| Multi-model capability | No (single model) |
| Setup effort | Low (Actions workflow + issue template) |
| Hands-off score | 8/10 |

The agent receives the spec content, the three reviewer perspective prompts, and outputs a structured review as a ~~version-control~~ issue or PR comment. Quality is solid for catching gaps and ambiguities but may miss subtle architectural concerns.

### Option B: Premium Agents

GitHub Actions assigns review to premium coding agents (e.g., `@claude`, `@codex`) that have access to stronger models.

| Dimension | Rating |
|-----------|--------|
| Monthly cost | ~$40/mo (agent subscription) |
| Automation level | Full |
| Review model quality | Very Good |
| Multi-model capability | Limited (single premium model) |
| Setup effort | Low (Actions workflow + agent config) |
| Hands-off score | 9/10 |

Same trigger mechanism as Option A but routes to a premium agent. Better at catching architectural issues and generating meaningful Devil's Advocate alternatives. The subscription cost covers unlimited or high-volume reviews.

### Option C: API + Actions

GitHub Actions triggers an API-based review pipeline with configurable model selection.

| Dimension | Rating |
|-----------|--------|
| Monthly cost | Variable (API costs, typically $2-10/review) |
| Automation level | Full |
| Review model quality | Best (Opus-tier configurable) |
| Multi-model capability | Yes (different model per perspective) |
| Setup effort | Medium (Actions workflow + API integration + secret management) |
| Hands-off score | 9/10 |

This is the most flexible option. Each reviewer perspective can use a different model -- for example, Opus for Devil's Advocate (requires creative reasoning), Sonnet for Challenger (pattern matching against requirements), and a security-specialized model for Security Reviewer. Results are aggregated by a synthesizer call.

### Option D: In-Session Subagents

Manual trigger during a coding session. The developer runs the review command, which spawns subagent-based reviewers.

| Dimension | Rating |
|-----------|--------|
| Monthly cost | $0 additional |
| Automation level | Manual (developer-triggered) |
| Review model quality | Very Good (session model) |
| Multi-model capability | Yes (subagent model mixing) |
| Setup effort | None (works in any coding session) |
| Hands-off score | 6/10 |

Best for reviewing specs before they are even committed. The developer runs the review in their coding tool, gets immediate feedback, and iterates on the spec before pushing. This is the fastest feedback loop but requires the developer to remember to trigger it.

### Option E: Persona Panel (Free, Validated)

4-persona panel review using dedicated persona agents, each with domain-specific expertise. Validated by A/B test (CIA-395): persona panel scored higher on specificity (4.6 vs 4.0) and actionability (4.6 vs 3.8) vs generic reviewer across 5 specs.

| Dimension | Rating |
|-----------|--------|
| Monthly cost | $0 (Claude Max subscription) |
| Automation level | Manual (session-triggered via `/review`) |
| Review model quality | Best (4 specialized perspectives) |
| Multi-model capability | No (single model, 4 personas) |
| Setup effort | None (persona agents registered in marketplace) |
| Hands-off score | 7/10 |

**Persona agents** (in `agents/` directory):

| Agent | Domain | What it catches that others miss |
|-------|--------|--------------------------------|
| `reviewer-security-skeptic` | Attack vectors, auth boundaries, data exposure, compliance | Credential ACLs, webhook signature gaps, least-privilege violations |
| `reviewer-performance-pragmatist` | Cost projections, scaling limits, context budgets | API cost models, free tier cliffs, event volume calculations |
| `reviewer-architectural-purist` | Coupling, contracts, dependency direction, extension points | Implicit contracts, dependency inversion, thin handler violations |
| `reviewer-ux-advocate` | Verification mechanisms, migration paths, discoverability | Progressive adoption sequences, dry-run previews, error message quality |

**Protocol:**
1. Each persona reviews the spec independently (parallel subagents)
2. Each finding MUST cite the specific spec section it refers to (evidence-based argumentation)
3. Findings are severity-rated: Critical / Important / Consider
4. A combined panel summary categorizes findings by consensus level:
   - **Unanimous** (4/4 agree): Confirmed finding
   - **Majority** (3/4): Likely finding
   - **Split** (2/2): Flagged for human decision
   - **Minority** (1/4): Noted view, not actionable unless escalated

**When to use Option E vs generic (Option D):**
- Complex specs with multi-system integration → Option E
- Specs with cross-cutting concerns (security + performance + UX) → Option E
- Simple, well-scoped specs (single feature, clear boundaries) → Option D is sufficient
- Routing heuristic: if the spec touches 3+ systems or has security implications, use Option E

**Known limitation:** Persona panel has weaker codebase awareness than the generic reviewer. The generic reviewer caught "this file already exists with 207 lines" in CIA-270 while the panel assumed greenfield. Mitigate by running a pre-review codebase scan or pairing Option E with the base reviewer's existing-artifact checklist.

### Option F: Structured Debate (Free, Experimental)

2-round debate protocol where persona agents don't just review independently -- they argue. Surfaces disagreements that independent reviews miss.

| Dimension | Rating |
|-----------|--------|
| Monthly cost | $0 (Claude Max subscription) |
| Automation level | Manual (session-triggered) |
| Review model quality | Best (deliberative reasoning) |
| Multi-model capability | Optional (add external model as 5th voice via OpenRouter) |
| Setup effort | Low (debate coordinator agent) |
| Hands-off score | 5/10 (requires checkpoint review between rounds) |

**2-Round Debate Protocol:**

**Round 1 — Independent Review:**
Each persona reviews the spec independently (same as Option E). Output is written to per-persona files.

**Round 2 — Cross-Examination:**
Each persona reads ALL other personas' Round 1 findings and responds with one of:

| Response | Meaning | Example |
|----------|---------|---------|
| **AGREE** | Concur, with optional addition | "Security Skeptic's auth finding is valid. I'd add: the token rotation gap also affects the caching layer." |
| **COMPLEMENT** | Both valid, additive not contradictory | "Performance Pragmatist's cost concern and my architectural concern are both real but address different risks." |
| **CONTRADICT** | Direct disagreement with counter-argument | "The proposed auth overhead is acceptable for the security gain. Performance cost is <2ms per request." |
| **PRIORITY** | Agree on the issue, disagree on severity | "This is Important, not Critical — the blast radius is limited to a single tenant." |
| **SCOPE** | Finding is valid but belongs in a different spec | "Rate limiting is a platform concern, not specific to this feature. Create a separate issue." |
| **ESCALATE** | Cannot resolve — needs human decision | "Security requires encryption-at-rest, Architecture says the performance cost is prohibitive. Human must choose." |

**Synthesis Phase:**
A dedicated debate-synthesizer (not one of the 4 personas) reads all Round 1 + Round 2 outputs and produces:
- Reconciled findings by consensus level (unanimous / majority / split / minority)
- Disagreement table with both sides' arguments
- Escalation list for human decision
- Quality score with confidence interval

**When to use Option F:**
- High-stakes specs where the cost of a missed issue justifies 2 rounds
- Specs with genuine tension between domains (security vs performance, flexibility vs safety)
- Architecture decision records where trade-off analysis is the deliverable

**State persistence:** Each round's output is written to checkpoint files (`round-1-{persona}.md`, `round-2-{persona}.md`, `synthesis.md`). If a session crashes mid-debate, it can resume from the last completed round.

### Comparison Summary

| Dimension | A: CI | B: Premium | C: API | D: In-Session | E: Persona | F: Debate |
|-----------|-------|------------|--------|---------------|------------|-----------|
| Monthly cost | $0 | ~$40 | Variable | $0 | $0 | $0 |
| Automation | Full | Full | Full | Manual | Manual | Manual |
| Model quality | Good | Very Good | Best | Very Good | Best | Best |
| Multi-model | No | Limited | Yes | Yes | No | Optional |
| Setup effort | Low | Low | Medium | None | None | Low |
| Hands-off | 8/10 | 9/10 | 9/10 | 6/10 | 7/10 | 5/10 |
| Unique finding rate | ~23% | ~25% | ~30% | ~23% | ~42% | TBD |

## Hybrid Combinations

Options are not mutually exclusive. Effective combinations include:

**Option A + D (Zero-cost full coverage):** Use Option D during spec drafting for immediate feedback, then Option A on merge for a second automated pass. Two review rounds at zero additional cost.

**Option A + C (Tiered quality):** Option A for routine specs (bug fixes, small features). Option C for high-impact specs (new systems, security-sensitive features). Route based on spec template type or labels.

**Option A for review + ~~remote-dispatch~~ for implementation:** Use free CI agents for the review stage, then dispatch implementation to a remote coding agent. This separates the review cost (free) from the implementation cost (agent session).

**Option D as pre-commit gate + Option B on merge:** Developer reviews locally before pushing, premium agent reviews after merge. Catches different classes of issues at different stages.

**Option D + E (Tiered persona review):** Generic reviewer first for codebase awareness and existing-artifact detection, then persona panel for domain-specific depth. Catches the panel's blind spot (greenfield assumption) while getting the panel's 42% unique finding rate.

**Option E + F (Escalating depth):** Persona panel (Option E) for routine complex specs. If the panel surfaces 2+ splits (2/2 persona disagreements), escalate to structured debate (Option F) to resolve. This reserves the expensive 2-round protocol for specs that genuinely need it.

**Option F + C (Debate + external model):** Structured debate with 4 Claude personas in Rounds 1-2, plus 1 external model (via OpenRouter) as a 5th voice in Round 2 only. The external model reads all Round 1 outputs and provides cross-examination from a genuinely different reasoning architecture. Adds ~$0.10-0.50 per review depending on model choice.

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

## Review Findings Storage

Store adversarial review findings in a persistent, version-controlled location so they can be referenced during implementation and closure.

**Recommended pattern:** Create a `REVIEW-GATE-FINDINGS.md` file at the root of the feature branch (or in `docs/reviews/`). This file captures the full synthesis output and tracks resolution status.

```markdown
# Review Gate Findings: [Spec Title]

**Review date:** YYYY-MM-DD
**Recommendation:** APPROVE / REVISE / RETHINK
**Spec:** [link to spec or issue]

## Critical
- [ ] C1: [Finding description] — [Resolution status]

## Important
- [ ] I1: [Finding description] — [Resolution status]

## Consider
- [ ] R1: [Finding description] — [Resolution status]

## Carry-Forward Items
Items deferred to future issues (with issue links):
- I3: [Description] → [CIA-XXX]
```

**Why a separate file:** Review findings are implementation guidance, not spec content. Keeping them in a dedicated file prevents spec bloat and gives the implementer a checklist to work through. The file is committed to the feature branch and merged with the PR, preserving the review trail.

## Fix-Forward Summary

When adversarial review findings are partially resolved during implementation (some fixed, some deferred), document the resolution in a **fix-forward summary** as a PR comment or issue comment at Stage 7.5 closure.

```markdown
## Fix-Forward Summary

**Review:** [link to REVIEW-GATE-FINDINGS.md or review comment]

### Resolved in this PR
| ID | Finding | Resolution |
|----|---------|------------|
| C1 | [Critical finding] | Fixed in [commit/file] |
| I1 | [Important finding] | Addressed by [approach] |

### Carry-Forward (separate issues created)
| ID | Finding | Deferred To | Rationale |
|----|---------|-------------|-----------|
| I3 | [Important finding] | CIA-XXX | [Why deferred — scope, risk, dependency] |

### Accepted Risks
| ID | Finding | Decision |
|----|---------|----------|
| R2 | [Consider finding] | Accepted — [rationale] |
```

This pattern ensures no review findings are silently dropped. Every finding gets one of three dispositions: resolved, deferred (with tracking issue), or explicitly accepted.

## Implementation References

GitHub Actions workflow files and issue templates for Options A, B, and C are located in the `references/` subdirectory. Adapt these to your ~~ci-cd~~ platform if not using GitHub Actions.

## User Decision Log

During adversarial review, maintain an explicit log of user decisions to prevent re-proposing rejected ideas.

**Format:**
| Round | Proposal | User Decision | Verbatim Reason |
|-------|----------|:------------:|-----------------|
| 1 | "Use Redis for caching" | REJECTED | "Too complex for personal tool" |
| 2 | "Add retry middleware" | ACCEPTED | "Makes sense for reliability" |

**Rules:**
- Log EVERY user decision (accept, reject, defer, modify)
- Record the reason VERBATIM — do not paraphrase or interpret
- Before proposing anything in subsequent rounds, check the log for prior rejections
- If a previously rejected idea is reconsidered, explicitly acknowledge: "This was rejected in Round N because [reason]. Has the context changed?"
- Anti-pattern: "proposal amnesia" — re-proposing rejected ideas without acknowledging the prior rejection

### Multi-Model Consensus Protocol

When using multiple models for adversarial review, follow this structured consensus process.

**Configuration:**
- Minimum 2 models, recommended 3 for tie-breaking
- Each model gets the SAME prompt independently (no shared context)
- Model mixing tiers: haiku (scan/classify), sonnet (review/analyze), opus (synthesize/decide)

**Consensus questions (ask each model independently):**
1. "What are the top 3 risks in this spec?"
2. "What is missing from the acceptance criteria?"
3. "Rate the spec's completeness 1-5 with justification"

**Agreement threshold:**
- 2/3 agreement on a risk → include in review
- 3/3 agreement → flag as critical
- 0/3 agreement → discard (likely noise)

**Structured exchange format:** When passing findings between models (especially across different model providers), use a structured JSON format rather than free text. This prevents misinterpretation and enables programmatic reconciliation.

```json
{
  "finding_id": "S1",
  "persona": "security-skeptic",
  "severity": "critical",
  "spec_section": "3.2 Authentication",
  "description": "Token stored in localStorage is vulnerable to XSS",
  "evidence": "Spec says 'store auth token client-side' without specifying storage mechanism",
  "mitigation": "Use httpOnly secure cookies or server-side session storage"
}
```

**Synthesis step:** After independent reviews, a dedicated synthesizer model reads all outputs and produces a unified review. The synthesizer must NOT add new concerns — only consolidate and reconcile. When using Option F (structured debate), the synthesizer is a separate agent (`debate-synthesizer`) rather than one of the reviewing personas, to avoid conflicts of interest.
