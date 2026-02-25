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

Eight options for running adversarial reviews, ordered by automation level. Options A-D are the original architectures. Options E-G extend the review methodology with persona-based, debate-driven, and multi-model approaches, validated by A/B testing (CIA-395, CIA-297). Option H routes reviews to external Linear-connected agents.

Options A-D trigger on spec file merge to `docs/specs/` on the main branch of your ~~version-control~~ repository. Options E-G are session-triggered. Option H is Linear assignment-triggered (async).

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

### Option G: Multi-Model Tier Diversity (Free, Validated)

Extends Option E (Persona Panel) by running each persona at TWO model tiers — deep (sonnet) and surface (haiku) — then synthesizing with opus. The two tiers find genuinely different things: sonnet excels at integration analysis and quantitative risk; haiku catches user confusion and strategic identity issues.

| Dimension | Rating |
|-----------|--------|
| Monthly cost | $0 (Claude Max subscription) |
| Automation level | Manual (session-triggered) |
| Review model quality | Best (cross-tier validation) |
| Multi-model capability | Yes (native Claude Code model routing) |
| Setup effort | Low (same 4 persona agents + framing modifiers) |
| Hands-off score | 6/10 (8 reviews + synthesis) |

**3-Phase Pipeline:**

**Phase 1 — Scan (haiku):**
Quick structural scan extracts: spec sections, risk areas, testable claims, integration points, unstated assumptions. Focuses subsequent reviews.

**Phase 2 — Review (4 personas × 2 tiers = 8 reviews):**
- **Sonnet tier:** Full adversarial review per persona (5-11 findings each)
- **Haiku tier:** Framing-modified quick triage per persona (1-3 findings each)

Haiku framing modifiers (validated):
| Persona | Framing | Avg Findings | Agreement Rate |
|---------|---------|-------------|---------------|
| Security Skeptic | "Junior security engineer, first review, focus obvious high-impact" | 2.6 | 56% |
| Performance Pragmatist | "15-minute triage meeting, top 3 risks only" | 2.8 | 60% |
| Architectural Purist | "5 minutes, one critical coupling/boundary violation" | 2.0 | 62% |
| UX Advocate | "You are a user receiving this spec — what confuses you?" | 3.4 | 53% |

**Phase 3 — Synthesize (opus):**
Deduplicate findings across all 8 reviews. Tag each as `convergent` (both tiers), `sonnet-only`, or `haiku-only`. Score consensus: 6+/8 = CRITICAL, 4-5/8 = HIGH, 2-3/8 = MODERATE, 1/8 = MINORITY.

**Validated metrics (n=5 specs, 222 raw findings, 105 deduplicated):**
| Metric | Mean | Range |
|--------|------|-------|
| Sonnet-only findings | 45% | 29-65% |
| Haiku-only findings | 10.6% | 9-13% |
| Convergent findings | 44% | 25-62% |
| False positive rate | 5.4% | 5-15% |
| Dedup rate | 52% | 45-64% |

**Routing heuristic:**
- High complexity (merged issues, multi-system, >500 words): Full 8-review pipeline
- Medium complexity (single feature, some TBDs): 6-review (4 sonnet + UX haiku + Security haiku)
- Low complexity (single file, clear scope): 5-review (4 sonnet + UX haiku only)

**When to use Option G:**
- Any spec where Option E would be used and additional validation coverage is desired at near-zero marginal cost
- Specs where "obvious user confusion" insights are as valuable as deep technical analysis
- When you want cross-tier consensus scoring (convergent findings are highest-confidence)

**Known limitation:** Haiku Architectural Purist is consistently undertriggered (avg 2.0 findings). The "5 minutes, one critical violation" framing is too restrictive for abstract architectural reasoning. Consider expanding or dropping haiku for this persona on simpler specs.

### Option H: Linear Agent Dispatch (Free/Paid, Experimental)

Routes adversarial review to external Linear-connected agents (cto.new, Codex, Amp) instead of in-session Claude subagents. The review runs asynchronously — the agent picks up the issue, reviews the spec, and posts findings as a Linear comment or PR review.

| Dimension | Rating |
|-----------|--------|
| Monthly cost | $0 (cto.new) to $20/mo (Codex) |
| Automation level | Full (Linear assignment trigger) |
| Review model quality | Variable (depends on agent) |
| Multi-model capability | Yes (different agents use different model families) |
| Setup effort | Low (enable agent in Linear, assign issue) |
| Hands-off score | 9/10 |

**How it works:**
1. Create a review sub-issue with the spec content in the description
2. Assign to an external agent (cto.new for free, Codex for GPT perspective)
3. Agent reviews asynchronously and posts findings
4. Human or Claude synthesizes findings from multiple agent reviews

**Agent-specific review strengths:**
| Agent | Review Strength | Weakness |
|-------|----------------|----------|
| **cto.new** | Multi-LLM auto-router; wide model diversity for free | No structured review format; findings may lack severity ratings |
| **Codex** | Structured PR code review with P1/P2 findings; unique GPT perspective | Requires $20/mo; no spec-level review (PR-level only) |
| **Amp** | Claude Opus 4.6; high-quality reasoning for spec review | Free ($15/day grant); no native Linear integration |

**When to use Option H:**
- When you want cross-model-family diversity at zero/low cost (GPT via Codex + Claude via Amp + multi-LLM via cto.new)
- When review can be asynchronous (no immediate feedback needed)
- When Options E-G feel heavyweight for the spec complexity

**When NOT to use Option H:**
- When structured persona-based review is needed (agents don't support CCC's persona framework)
- When the spec requires codebase awareness (external agents may not have full repo context)
- When immediate feedback is needed (async turnaround varies from minutes to hours)

**Replaces:** Options A and B (GitHub Actions → CI/premium agent). Option H achieves the same async agent review via Linear assignment instead of GitHub Actions YAML, which is simpler to configure and maintain.

> For the canonical agent dispatch architecture (reactivity model, adoption status, dispatch-by-stage, routing tables), see **CONNECTORS.md § Agent Dispatch Protocol**. For finding normalization from external agent output, see the Finding Normalization Protocol below.

### Comparison Summary

| Dimension | A: CI | B: Premium | C: API | D: In-Session | E: Persona | F: Debate | G: Tier Diversity | H: Agent Dispatch |
|-----------|-------|------------|--------|---------------|------------|-----------|-------------------|-------------------|
| Monthly cost | $0 | ~$40 | Variable | $0 | $0 | $0 | $0 | $0-20 |
| Automation | Full | Full | Full | Manual | Manual | Manual | Manual | Full |
| Model quality | Good | Very Good | Best | Very Good | Best | Best | Best | Variable |
| Multi-model | No | Limited | Yes | Yes | No | Optional | Yes (native) | Yes (cross-family) |
| Setup effort | Low | Low | Medium | None | None | Low | Low | Low |
| Hands-off | 8/10 | 9/10 | 9/10 | 6/10 | 7/10 | 5/10 | 6/10 | 9/10 |
| Unique finding rate | ~23% | ~25% | ~30% | ~23% | ~42% | TBD | ~55% | TBD |

## Hybrid Combinations

Options are not mutually exclusive. Effective combinations include:

**Option A + D (Zero-cost full coverage):** Use Option D during spec drafting for immediate feedback, then Option A on merge for a second automated pass. Two review rounds at zero additional cost.

**Option A + C (Tiered quality):** Option A for routine specs (bug fixes, small features). Option C for high-impact specs (new systems, security-sensitive features). Route based on spec template type or labels.

**Option A for review + ~~remote-dispatch~~ for implementation:** Use free CI agents for the review stage, then dispatch implementation to a remote coding agent. This separates the review cost (free) from the implementation cost (agent session).

**Option D as pre-commit gate + Option B on merge:** Developer reviews locally before pushing, premium agent reviews after merge. Catches different classes of issues at different stages.

**Option D + E (Tiered persona review):** Generic reviewer first for codebase awareness and existing-artifact detection, then persona panel for domain-specific depth. Catches the panel's blind spot (greenfield assumption) while getting the panel's 42% unique finding rate.

**Option E + F (Escalating depth):** Persona panel (Option E) for routine complex specs. If the panel surfaces 2+ splits (2/2 persona disagreements), escalate to structured debate (Option F) to resolve. This reserves the expensive 2-round protocol for specs that genuinely need it.

**Option F + C (Debate + external model):** Structured debate with 4 Claude personas in Rounds 1-2, plus 1 external model (via OpenRouter) as a 5th voice in Round 2 only. The external model reads all Round 1 outputs and provides cross-examination from a genuinely different reasoning architecture. Adds ~$0.10-0.50 per review depending on model choice.

**Option E + G (Tiered persona review):** Run Option G's 3-phase pipeline as the primary review pass. Use the tier diversity to identify convergent findings (highest confidence) and tier-exclusive findings (surface vs depth insights). The sonnet-only findings provide deep technical coverage; the haiku-only findings catch user-facing confusion and strategic identity issues at near-zero marginal cost.

**Option E + H (Persona + external agent):** Run the persona panel (Option E) for CCC-native review, then dispatch to cto.new or Codex (Option H) for cross-model-family perspective. The external agent finds issues that all-Claude reviews miss. Synthesize both sets of findings manually. Best for high-impact specs where model diversity is worth the extra review cycle.

**Option H as A/B replacement:** For teams currently using Options A or B (GitHub Actions-triggered CI/premium agent review), Option H achieves the same async review pattern with simpler setup — Linear assignment instead of YAML workflows. Migration path: disable the GitHub Actions workflow, enable the agent in Linear, update the dispatch template to assign review issues to the agent.

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

Every review synthesis output (regardless of Option A-H) must end with a **Review Decision Record** table. The RDR is the artifact that Gate 2 operates on -- it transforms implicit approval ("I ran `/decompose` so I guess I approve") into explicit, traceable decisions on each finding.

This format extends the Decision/Response column pattern from CIA-378 (triage tables) to adversarial review findings.

### RDR Table Format

The RDR table has two variants depending on the `style.explanatory` preference:

**Standard format** (`terse` or `balanced`):

```markdown
## Review Decision Record

**Issue:** CIA-XXX | **Review date:** YYYY-MM-DD | **Option:** D/E/F/G/H
**Reviewers:** [names/agents] | **Recommendation:** APPROVE / REVISE / RETHINK

| ID | Severity | Finding | Reviewer | Decision | Response |
|----|----------|---------|----------|----------|----------|
| C1 | Critical | [Finding description] | Challenger | | |
| C2 | Critical | [Finding description] | Security | | |
| I1 | Important | [Finding description] | Devil's Advocate | | |
| I2 | Important | [Finding description] | Security | | |
| N1 | Consider | [Finding description] | Challenger | | |

**Decision values:** `agreed` (will address) | `override` (disagree, see Response) | `deferred` (valid, tracked as new issue) | `rejected` (not applicable)
**Response required for:** override, deferred (with issue link), rejected
**Gate 2 passes when:** All Critical + Important rows have a Decision value
```

**Accessible format** (`detailed` or `educational`):

```markdown
## Review Decision Record

**Issue:** CIA-XXX | **Review date:** YYYY-MM-DD | **Option:** D/E/F/G/H
**Reviewers:** [names/agents] | **Recommendation:** APPROVE / REVISE / RETHINK

| ID | Severity | Finding | Plain English | Reviewer | Decision | Response |
|----|----------|---------|---------------|----------|----------|----------|
| C1 | Critical | [Finding description] | [One-sentence user-facing translation] | Challenger | | |
| C2 | Critical | [Finding description] | [One-sentence user-facing translation] | Security | | |
| I1 | Important | [Finding description] | [One-sentence user-facing translation] | Devil's Advocate | | |
| N1 | Consider | [Finding description] | [One-sentence user-facing translation] | Challenger | | |

**Decision values:** `agreed` (will address) | `override` (disagree, see Response) | `deferred` (valid, tracked as new issue) | `rejected` (not applicable)
**Response required for:** override, deferred (with issue link), rejected
**Gate 2 passes when:** All Critical + Important rows have a Decision value
```

The "Plain English" column translates each finding into a single sentence that a non-technical project owner can understand. Focus on user-visible consequences, not implementation details. Example:
- Finding: "Env var export from session-start.sh cannot reach ccc-stop-handler.sh — separate process invocations, no shared env"
- Plain English: "The detection result gets lost between steps — like writing a note that gets thrown away before anyone reads it"

### Decision Vocabulary

| Value | Meaning | Response Required? | Gate 2 Effect |
|-------|---------|-------------------|---------------|
| `agreed` | Will address before implementation | No (optional clarification) | Passes |
| `override` | Disagree with finding, proceeding anyway | Yes (explain rationale) | Passes |
| `deferred` | Valid finding, tracked as separate issue | Yes (include issue link) | Passes |
| `rejected` | Finding is not applicable to this context | Yes (explain why) | Passes |
| (empty) | No decision yet | N/A | **Blocks Gate 2** (Critical/Important only) |

### ID Convention

Severity-initial + sequential number: `C1`, `C2`, `I1`, `I2`, `N1`, `N2`. This matches the existing convention in `sample-review-findings.md` and is stable across re-reviews.

### Inline Decision Collection

When presenting the RDR in-session, offer the human a natural language shorthand:

```
Gate 2 requires decisions on all Critical and Important findings.
Quick options:
  "agree all" — accept all findings
  "agree all except C2, I3" — selective override
  "agree C1-C3, override I2: [reason], defer I3 to CIA-456"

Syntax: commas = list (C1, C3), hyphens = range (C1-C3)
```

Parse the human's response, update the RDR table, and re-post the updated table to the project tracker.

### Where the RDR Lives

**Primary: Project tracker comment on the parent issue.** External agents (Option H) already post findings as comments. The human can reply or edit in-place. The `/decompose` command reads the latest RDR comment via the project tracker API.

**Secondary: `REVIEW-GATE-FINDINGS.md`** at feature branch root or in `docs/reviews/`. Committed for repo audit trail after decisions are filled. This preserves the version-controlled record for future reference.

**Why the tracker comment is primary:** (1) External agents already post to the tracker as comments. (2) The human reviewer works in the tracker, not in the IDE. (3) `/decompose` can verify Gate 2 by reading comments. (4) Comments preserve edit history for audit trail.

### Finding Normalization Protocol (Option H)

When external agents (cto.new, Codex, Amp, Copilot) post review findings, their output is unstructured -- they do not follow the CCC severity format. The normalization protocol converts agent findings into RDR rows:

1. **Read** the agent's comment on the review sub-issue
2. **Extract** distinct findings (look for bullet points, numbered items, or paragraph-level concerns)
3. **Classify** each finding by severity (Critical / Important / Consider) based on content
4. **Assign** the agent name to the Reviewer column
5. **Append** normalized rows to the parent issue's RDR table
6. **Deduplicate** against existing RDR rows (same finding from different reviewers = note both in Reviewer column, keep higher severity)

When multiple external agents review the same spec, run the normalizer after each agent completes. The final RDR table is the union of all agent findings plus any in-session review findings.

## Review Findings Storage

The Review Decision Record (above) is the primary findings format. For repo audit trail, also store findings in a version-controlled file:

**Pattern:** Create a `REVIEW-GATE-FINDINGS.md` file at the root of the feature branch (or in `docs/reviews/`). This file captures the RDR table with decisions filled in after Gate 2 passes.

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

## When to Review Liberally

Not every spec needs the full adversarial ceremony. Use this routing table to match review depth to issue type and risk level.

### Review Depth by Issue Type

| Issue Type | Labels | Review Depth | Rationale |
|-----------|--------|-------------|-----------|
| Feature (3+ pt) | `type:feature`, `exec:tdd`+ | Full adversarial (Option D-H) | Enough complexity to justify multi-perspective review |
| Feature (1-2pt) | `type:feature`, `exec:quick` | Single-pass Option D | Generic 3-reviewer pass; persona panel is overkill |
| Spike | `type:spike` | Scope-only single reviewer | Focus on: is the research question well-scoped? Are success/failure criteria defined? Is the time box appropriate? |
| Bug fix | `type:bug` | Regression-focused single reviewer | Verify the fix addresses root cause, check for regression risk |
| Chore | `type:chore` | Static quality checks only | `bash tests/test-static-quality.sh` is sufficient |
| Docs-only | Any | Challenger only (accuracy check) | Skip Security Reviewer and Devil's Advocate; check factual accuracy and internal consistency |

### Mandatory Full Review Triggers

Even if the issue type suggests a lighter review, escalate to full adversarial review (Option D-H) when any of these conditions apply:

1. **Cross-session handoffs** -- any spec being handed to another session (Factory dispatch, Agent Teams teammate, session-split). The receiving context has no implicit understanding of trade-offs.
2. **Hook or stop-handler changes** -- any spec that modifies hooks, the stop handler, or the execution engine. These are core safety mechanisms; a gap here cascades silently.
3. **High-dependency specs** -- any spec with 3+ downstream dependents (check `blockedBy`/`blocks` relations). Downstream issues inherit any gaps undetected.
4. **Security-sensitive changes** -- any spec that touches authentication, authorization, credential handling, or data exposure boundaries.
5. **Pre-launch phase** -- during milestone pushes (v1.0, M0 completion), default to reviewing rather than skipping. The cost of a missed finding compounds with every subsequent issue that builds on it.

### Spike Review Protocol

Spikes deserve special treatment. A spike is time-boxed research, not an implementation. Full adversarial review of a spike wastes the time box on ceremony instead of research.

**For spikes, review only:**
- Is the research question specific and answerable within the time box?
- Are the GO/NO-GO criteria defined before research begins?
- Are the research dimensions independent enough for parallel dispatch?
- Does the spike have a clear output artifact (ADR, Linear document, issue comment)?

**Do not review:** Implementation details, error handling, edge cases, or security posture. These belong in the follow-up implementation issues that the spike will produce.

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

When using multiple model tiers for adversarial review, follow this validated consensus process. Experimentally validated on 5 specs (CIA-297, n=222 raw findings, 105 deduplicated). See `.claude/ab-test-results/multi-model-comparison.md` for full data.

**Model tier roles:**
| Tier | Role | When |
|------|------|------|
| Haiku | Scan, classify, surface-level triage | Phase 1 scan, Phase 2 haiku-tier reviews |
| Sonnet | Deep adversarial review | Phase 2 sonnet-tier reviews |
| Opus | Synthesize, deduplicate, reconcile | Phase 3 synthesis |

**Consensus scoring (validated, 8 reviewers = 4 personas × 2 tiers):**
| Level | Threshold | Action |
|-------|-----------|--------|
| CRITICAL | 6+/8 reviewers | Must address before implementation |
| HIGH | 4-5/8 reviewers | Should address before implementation |
| MODERATE | 2-3/8 reviewers | Should consider |
| MINORITY | 1/8 reviewers | Note — do not dismiss (may represent specialist expertise) |

**Tier tagging:** Each unified finding is tagged:
- `convergent` — found by both sonnet AND haiku tier (highest confidence, ~44% of findings)
- `sonnet-only` — found only by sonnet tier (~45% of findings, mostly integration/quantitative analysis)
- `haiku-only` — found only by haiku tier (~11% of findings, mostly user confusion/strategic identity)

**Structured exchange format:** When passing findings between models, use structured JSON to prevent misinterpretation and enable programmatic reconciliation.

```json
{
  "finding_id": "SS1",
  "persona": "security-skeptic",
  "model_tier": "sonnet",
  "severity": "critical",
  "spec_section": "3.2 Authentication",
  "description": "Token stored in localStorage is vulnerable to XSS",
  "evidence": "Spec says 'store auth token client-side' without specifying storage mechanism",
  "mitigation": "Use httpOnly secure cookies or server-side session storage"
}
```

**Finding ID convention:** Two-letter code = persona initial + tier initial. SS = Security Sonnet, SH = Security Haiku, PS = Performance Sonnet, PH = Performance Haiku, AS = Architecture Sonnet, AH = Architecture Haiku, US = UX Sonnet, UH = UX Haiku.

**Synthesis step:** After independent reviews, a dedicated synthesizer model (opus) reads all outputs and produces a unified review. The synthesizer must NOT add new concerns — only consolidate, deduplicate, tag tiers, and reconcile. When using Option F (structured debate), the synthesizer is a separate agent (`debate-synthesizer`) rather than one of the reviewing personas, to avoid conflicts of interest.

**What each tier finds (validated patterns):**
| Sonnet excels at | Haiku excels at |
|------------------|-----------------|
| Integration/dependency analysis | "Does this confuse a new reader?" |
| Quantitative risk (latency, cost, sample size) | Identity confusion (prototype vs production) |
| Architecture coherence and coupling | Source attribution and traceability |
| Edge cases and failure modes | "What does the user DO?" questions |
| Cross-file/cross-system implications | Over-engineering detection |
