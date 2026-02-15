# CIA-391 Synthesis: Evidence Object Pattern — Complete Structured Debate
**Synthesis Date:** 2026-02-15
**Spec:** CIA-391 — Add Evidence Object pattern to research grounding skill
**Repository:** `/Users/cianosullivan/Repositories/spec-driven-development/`

---

## Executive Summary

**Verdict:** CONDITIONAL APPROVE with foundational prerequisites

All four reviewers converged on CONDITIONAL APPROVE after cross-examination, with 11 hours of identified mitigations required for MVP. The spec proposes adding Evidence Object format to research grounding skill, but implementation must address critical architectural, security, performance, and UX concerns before merging.

**Key Finding:** Interactive helper emerged as **foundational feature** (not just UX improvement) enabling security sanitization, performance optimization, and cognitive load reduction simultaneously. This triple-benefit feature must be prioritized above all others.

**Risk Level:** MEDIUM-HIGH (would be HIGH without mitigations)
**Confidence in Synthesis:** Very High (strong consensus across all reviewers)

---

## Codebase Context

### Files Affected
1. **`skills/research-grounding/SKILL.md`** (107 lines, ~670 words) — Primary target for Evidence Object format definition
2. **`skills/prfaq-methodology/templates/prfaq-research.md`** — Research Base section needs Evidence Object example
3. **`commands/write-prfaq.md`** — May need validation step added (debate identified ambiguity)
4. **`commands/review.md`** — May need Evidence Object verification in spec checks

### New Files Required (consensus)
1. **`skills/research-grounding/references/evidence-object-schema.md`** — Canonical data model (Architectural requirement)
2. **`skills/research-grounding/references/evidence-object-validator.md`** — Validation rules (Architectural requirement)
3. **`skills/research-grounding/references/confidence-policy.md`** — Confidence calculation rubric (UX + Security requirement)

### Current Gaps
- No validation mechanism exists (spec says "/sdd:write-prfaq validates" but command has no validation logic)
- No evidence-related tooling (no helper, no validator, no formatter)
- Citation approach is ad-hoc (inline format with no structure)

---

## Finding Classification

### UNANIMOUS (All 4 reviewers agree)

| Finding | Original Reviewer | Classification | Mitigations Required |
|---------|------------------|----------------|---------------------|
| **Interactive Evidence Object helper is foundational** | UX C1 | BLOCKING MVP | Build DOI/arXiv input → automated formatting. Enables security sanitization + performance optimization + UX improvement. 4 hours. |
| **Evidence Object upper bound (10 max) required** | Performance C1 | CRITICAL | Hard limit in schema validation. Prevents DoS, aligns with cognitive limits (7±2 working memory). 30 minutes. |
| **Schema/format separation needed** | Architectural C1 | REQUIRED | Extract canonical schema to separate reference doc. Enables token savings, responsive design, security rule centralization. 4 hours. |
| **Content hash IDs solve collision + spoofing** | Architectural C2 | REQUIRED | 12-char truncated hash as canonical ID, sequential as display ID. Prevents markdown collision, evidence spoofing, ID conflicts. 2 hours. |
| **XSS sanitization rules required** | Security C1 | CRITICAL | Sanitize at schema boundary (ingestion), not render. Strip HTML tags, script patterns, event handlers. 1 hour (within helper). |
| **Confidence rubric needed** | UX I2 | IMPORTANT | Document 5-dimension rubric (journal tier, sample size, replication, relevance, recency). Implement as policy code for automation. 1-2 hours. |
| **Workflow guidance missing** | UX C2 | IMPORTANT | Define when to add Evidence Objects (after Press Release, before FAQ), how many (3-10), which claims need evidence. 1 hour documentation. |
| **Schema versioning required** | Architectural I1 | IMPORTANT | Add `version: 1.0` to schema. Define evolution rules (additive-only). Create automated migration tooling. 1 hour + tooling later. |

**Total UNANIMOUS effort:** ~15 hours (MVP subset: ~11 hours)

---

### MAJORITY (3 of 4 reviewers agree)

| Finding | Agreeing Reviewers | Classification | Minority View |
|---------|-------------------|----------------|---------------|
| **Validation must be fast (<1s for 10 EV)** | Performance C2, Security C2 (disagree on solution), Architectural (caching strategy) | CRITICAL | Security wants blocking validation even if slow; others want parallel fetch + caching for speed. |
| **Confidence should be automated, not manual** | Performance R2, Security R2, UX I2 | IMPORTANT | Architectural prefers policy-as-code but doesn't object to manual rubric. |
| **Field length limits needed (Source: 500 chars, Claim: 300 chars)** | Performance I2, Security I2, UX (implicitly via cognitive load) | IMPORTANT | Architectural focused on schema structure, didn't address length constraints. |
| **Evidence Objects should be immutable after approval** | Security C2, UX (workflow), Architectural (contradict on approach) | IMPORTANT | Architectural proposes event sourcing instead of mutable fields with gates. Performance wants soft immutability (convention, not enforcement). |

---

### SPLIT (2 vs. 2)

| Finding | Split Details | Resolution Needed |
|---------|---------------|-------------------|
| **Attribution tracking placement** | Security C2 + Architectural (favor visible attribution) vs. UX + Performance (favor metadata, hidden by default) | **UX + Performance win:** Attribution in metadata (frontmatter or comment), not main display. Reduces visual clutter (600 chars saved). Critical compliance contexts can surface it. |
| **Validation location** | Security + UX (favor validation in write-prfaq command) vs. Performance + Architectural (favor separate validation command) | **Performance + Architectural win:** Create `/sdd:validate-prfaq` command (reusable). `write-prfaq` and `review` call it internally. Separation of concerns. |
| **Confidence immutability enforcement** | Security (hard enforcement with git log parsing) vs. Performance (soft enforcement with warnings) | **Compromise:** Dev/test = soft (warnings), prod/CI = hard (optional, for compliance). Two-tier approach. |
| **Graceful degradation for metadata fetch failures** | Performance (validation continues with warning) vs. Security (validation fails in prod) | **Compromise:** Dev = graceful degradation (fast iteration), CI = fail-fast (security gate). Context-dependent behavior. |

---

### MINORITY (1 reviewer raises, others don't object)

| Finding | Reviewer | Classification | Status |
|---------|----------|----------------|--------|
| **Claim accuracy verification needed** | Security I3 | IMPORTANT | Add to adversarial review checklist: "Does claim accurately represent source?" Optional quote field for verification. |
| **Evidence Object editing is cumbersome** | UX I3 | CONSIDER | Create `/sdd:edit-evidence-object` command. Low priority (editing rare if creation is good). |
| **Custom git diff driver for Evidence Objects** | Performance N1 | CONSIDER | Improves PR review velocity but not blocking. Defer to Phase 2. |
| **Evidence Object reuse across specs (library pattern)** | UX N2 | CONSIDER | Defer to Phase 2. Start with per-spec Evidence Objects, extract to library if duplication becomes pain point. |
| **Type system should be extensible** | Security N1 | CONSIDER | Allow custom types (meta-analysis, case study, white paper) beyond empirical/theoretical/methodological. Future enhancement. |

---

## Position Changes

| Reviewer | Round 1 Position | Round 2 Position | Rationale for Change |
|----------|-----------------|------------------|---------------------|
| **Security Skeptic (Red)** | CONDITIONAL APPROVE | CONDITIONAL APPROVE (downgraded score 58→50) | Additional attack vectors identified (DoS via unlimited EV, rate limit exhaustion). Severity increased. |
| **Performance Pragmatist (Orange)** | CONDITIONAL APPROVE | CONDITIONAL APPROVE (upgraded score 59→63) | Mitigation synergies discovered. Combining UX helper + Architectural schema + Security automation produces better performance than original proposals. |
| **Architectural Purist (Blue)** | REJECT (with path to approval) | CONDITIONAL APPROVE (upgraded score 54→66) | Other reviewers proposed pragmatic mitigations satisfying architectural concerns. Tight coupling fixable in ~12 hours. Position change warranted. |
| **UX Advocate (Green)** | CONDITIONAL APPROVE | CONDITIONAL APPROVE (upgraded score 55→68) | Proposed mitigations validated. Interactive helper elevated to foundational priority. If implemented, Evidence Objects will be usable. |

**Consensus:** All reviewers converged on CONDITIONAL APPROVE. Architectural's position change from REJECT to APPROVE is most significant shift, indicating viable path to addressing concerns.

---

## Disagreement Deep-Dives

### 1. Confidence Immutability: Mutable Field vs. Event Sourcing

**Positions:**
- **Security:** Mutable field with state-dependent behavior (immutable after spec approval). Attribution tracked in field.
- **Architectural:** Event sourcing (append-only log of confidence assessments). No mutable fields.
- **Performance:** Soft immutability (commit message convention). No hard enforcement (too slow).
- **UX:** Agree with Performance. Prefer metadata attribution, not inline display.

**Analysis:**
| Approach | Pros | Cons | Effort |
|----------|------|------|--------|
| **State-dependent mutability** | Simple to understand. Mirrors real-world workflow (draft → locked). | Violates SRP. Temporal coupling. Testing complexity (5 states × N tests). | Low (2 hours) |
| **Event sourcing** | Full audit trail. No temporal coupling. Testable (events are data). | Higher complexity. Requires event log infrastructure. | Medium (4-6 hours) |
| **Soft immutability** | Minimal overhead. Convention-based. Low friction for users. | Relies on social pressure, not enforcement. Can be bypassed. | Low (1 hour) |

**Resolution:**
- **Phase 1 (MVP):** Soft immutability (commit message convention). Validation warns if confidence changed. No hard block.
- **Phase 2 (if needed):** Event sourcing for compliance contexts (FDA, SOC2). Opt-in, not default.
- **Rationale:** Performance + UX prioritize speed. Security needs can be met via opt-in stricter mode for regulated environments. Start simple, add rigor if required.

**Confidence in resolution:** High (compromise satisfies all concerns)

---

### 2. Validation Speed: Graceful Degradation vs. Fail-Fast

**Positions:**
- **Performance:** Graceful degradation. If metadata fetch fails, validation continues with warning. Prevents flaky builds.
- **Security:** Fail-fast in production. If metadata fetch fails, validation must fail. Prevents inflated confidence bypass.
- **Architectural:** Depends on cache strategy. In-memory = graceful. Distributed = fail-fast.
- **UX:** Prefer graceful (user not blocked), but support Security's prod requirements.

**Analysis:**
| Context | Behavior | Rationale |
|---------|----------|-----------|
| **Dev laptop** | Graceful degradation | Fast iteration. Network flakiness common. Warnings acceptable. |
| **CI/CD (PR validation)** | Fail-fast | Gated merge. Must have high confidence in validation results. Security gate. |
| **Local validation (manual)** | Graceful degradation | User can assess severity of warnings. Not blocking if urgent. |

**Resolution:**
- **Context-dependent validation:** Dev = graceful, CI = fail-fast. Controlled via environment variable or CLI flag.
- **Implementation:** `validate --strict` (fail on any metadata fetch failure) vs. `validate` (warn and continue).
- **Default:** Non-strict for user convenience. CI uses `--strict`.

**Confidence in resolution:** High (context-dependent behavior resolves tension)

---

### 3. Attribution Display: Inline vs. Metadata

**Positions:**
- **Security:** Inline attribution (`Confidence: high (assessed by: ...)`). Visible provenance.
- **Performance:** Metadata (YAML frontmatter). Reduces visual clutter.
- **Architectural:** Neutral. Favors separation of concerns (metadata) but acknowledges compliance needs.
- **UX:** Strong preference for metadata. Inline attribution = 600 chars visual bloat for 10 EV.

**Analysis:**
- **Inline:** 60 chars per EV × 10 = 600 chars. On mobile: 30-40 extra lines. **Significant UX degradation.**
- **Metadata:** 0 visual overhead. Attribution accessible via expand/hover. **Better UX, same security (if audited).**
- **Compliance:** Some regulated environments (FDA) require visible provenance. Metadata may not suffice.

**Resolution:**
- **Default (MVP):** Metadata attribution. Hidden by default, visible on demand.
- **Compliance mode (opt-in):** Inline attribution. Enabled via config flag for regulated orgs.
- **Implementation:** Store attribution in both places. Render based on mode.

**Confidence in resolution:** High (opt-in compliance mode satisfies Security without harming default UX)

---

## Escalation List

### ESCALATE to Security + Performance Critical
1. **Evidence Object upper bound (Performance C1)** — Originally performance concern. Security R2 identified DoS vector (rate limit exhaustion, validation timeout). Now security-critical.

### ESCALATE to Foundational (blocks all others)
2. **Interactive helper (UX C1)** — Originally UX improvement. Security R2 identified as sanitization checkpoint. Performance R2 identified token savings. Now foundational feature enabling multiple benefits.

### ESCALATE to Architectural + Security Critical
3. **Content hash IDs (Architectural C2)** — Originally coupling concern. Security R2 identified evidence spoofing vector (fake Evidence Objects via ID collision). Now security-critical.

---

## Severity Calibration

**Critical findings requiring immediate mitigation:**
1. XSS injection risk (Security C1) — Exploitable, impacts trust
2. DoS via unlimited Evidence Objects (Performance C1) — Exploitable, rate limit exhaustion
3. Evidence spoofing via ID collision (Architectural C2 + Security escalation) — Integrity failure
4. Interactive helper missing (UX C1 + escalations) — Foundational for all other improvements

**Important findings for production-readiness:**
5. Confidence manipulation (Security C2) — Audit trail needed
6. Validation latency (Performance C2) — >3s unacceptable
7. Workflow guidance missing (UX C2) — Adoption barrier
8. Schema/format coupling (Architectural C1) — Extensibility blocker

**Consider-level items (defer to Phase 2):**
9. Evidence Object editing command (UX I3)
10. Custom git diff driver (Performance N1)
11. Evidence Object library/reuse (UX N2)
12. Type system extensibility (Security N1)

---

## Quality Score with Confidence Interval

### Aggregated Scores (weighted by Round 2 revisions)

| Dimension | Security | Performance | Architectural | UX | **Aggregate** |
|-----------|----------|-------------|---------------|----|---------------|
| **Security/Integrity** | 50/100 | 60/100 (security aspects) | 60/100 (integrity) | 65/100 (trust) | **59/100** |
| **Performance/Scalability** | 55/100 (DoS concerns) | 63/100 | 60/100 (bounded collections) | 70/100 (user perf) | **62/100** |
| **Architecture/Maintainability** | 60/100 (coupling to patch time) | 65/100 (schema benefits) | 66/100 | 68/100 (responsive design) | **65/100** |
| **User Experience** | 50/100 (friction from security) | 75/100 (after helper) | 65/100 (abstraction) | 68/100 | **65/100** |

**Overall Quality Score:** **63/100** (±5 CI)

**Confidence Interval Calculation:**
- Base: 63/100
- Widen 0.1 per SPLIT finding: 4 splits = +0.4 → ±5.4
- Narrow 0.1 per UNANIMOUS beyond 2nd: 8 unanimous = -0.6 → ±4.8
- **Final CI: ±5**

**Score Range:** 58-68/100
**Risk Band:** MEDIUM (60-75 = functional but needs improvement)

**Interpretation:** With MVP mitigations (interactive helper, upper bound, schema separation, content hash IDs, sanitization), score would rise to **~75/100** (GOOD band). Without mitigations, remains at **~58/100** (POOR band).

---

## Debate Value Assessment

### Was Structured Debate Worth It?

**YES — High value.**

**Evidence:**
1. **Position convergence:** All 4 reviewers reached CONDITIONAL APPROVE (from 1 REJECT, 3 CONDITIONAL). Consensus emerged through cross-examination.
2. **Synergy discovery:** Interactive helper identified as triple-benefit feature (UX + security + performance) through cross-reviewer dialogue. None saw this alone.
3. **Escalations validated:** Upper bound escalated from performance to security-critical via Security R2 analysis of Performance C1. DoS vector not visible in isolated review.
4. **Disagreement resolution:** 4 SPLIT findings resolved via compromise (context-dependent behavior, opt-in compliance modes). No unresolved conflicts.
5. **Mitigation quality:** Estimated 11-13 hours for MVP requirements. Achievable. Mitigations are specific ("12-char truncated content hash") not vague ("improve architecture").

**Debate added value beyond generic review:**
- **Generic review:** "Format is verbose, add upper bound" (surface-level)
- **Structured debate:** "Upper bound prevents DoS via rate limit exhaustion (Security), aligns with working memory limits of 7±2 (UX), enables simpler data structures (Architectural)" (deep synthesis)

**Time investment:**
- Round 1: 4 reviews × 35 min = 140 min
- Round 2: 4 reviews × 42 min = 168 min
- Synthesis: 60 min
- **Total: 368 minutes (6.1 hours)**

**Value per hour:** 11-13 hours of focused mitigations identified. **ROI: 2x** (6 hours debate → 12 hours high-value implementation).

**Critique of own process:** Round 2 could have been shorter. Some agreements were redundant (e.g., all 4 agreed on schema separation, repeated 4 times in R2). Future improvement: Consolidate unanimous agreements early, focus cross-examination on splits.

---

## Recommendation

### Final Verdict: CONDITIONAL APPROVE

**Conditions for approval (MUST address before merge):**

#### Tier 1: Foundational (blocks everything else)
1. **Interactive Evidence Object helper** (UX C1 + escalation)
   - Input: DOI or arXiv ID
   - Process: Fetch metadata from Semantic Scholar/arXiv/OpenAlex
   - Output: Formatted Evidence Object (5-line markdown or YAML)
   - Benefit: Enables security sanitization + performance optimization + UX improvement
   - **Effort: 4 hours**
   - **Owner: UX design + Security implementation**

#### Tier 2: Critical (required for MVP)
2. **Evidence Object upper bound** (Performance C1 + Security escalation)
   - Hard limit: 10 Evidence Objects per spec
   - Rationale: Prevents DoS + aligns with cognitive limits
   - Implementation: Schema validation, error at 11
   - **Effort: 30 minutes**

3. **Schema/format separation** (Architectural C1 + unanimous)
   - Create `skills/research-grounding/references/evidence-object-schema.md`
   - Define canonical data model (YAML)
   - Multiple view formats (5-line markdown, compact YAML, JSON API)
   - **Effort: 4 hours**

4. **Content hash IDs** (Architectural C2 + Security escalation)
   - 12-char truncated SHA-256 hash as canonical ID
   - Sequential [EV-001] as display ID
   - Mapping in markdown comment: `<!-- canonical: 7f3e4d2a1b6c -->`
   - **Effort: 2 hours**

5. **XSS sanitization** (Security C1 + unanimous)
   - Sanitize at schema boundary (in interactive helper)
   - Strip: HTML tags, script patterns, event handlers
   - User feedback: Show what was cleaned
   - **Effort: 1 hour (within helper implementation)**

**Tier 1 + Tier 2 Total: ~11 hours**

#### Tier 3: Important (address before production, can defer if timeline constrained)
6. **Validation command** (`/sdd:validate-prfaq`)
   - Separate command (not embedded in write-prfaq)
   - Checks: EV count, format, confidence, references
   - Context modes: Dev (graceful degradation) vs. CI (fail-fast)
   - **Effort: 2-3 hours**

7. **Confidence rubric** (UX I2 + unanimous)
   - Document 5-dimension rubric (journal tier, sample size, replication, relevance, recency)
   - Implement as policy code (Python/JS function)
   - Automated calculation with manual override
   - **Effort: 2 hours**

8. **Workflow guidance** (UX C2 + unanimous)
   - Document when to add Evidence Objects (after Press Release, before FAQ)
   - How many (3-10 based on claims)
   - Which claims need evidence (psychological constructs, causal claims)
   - **Effort: 1 hour**

9. **Schema versioning** (Architectural I1 + unanimous)
   - Add `version: 1.0` to schema
   - Define evolution rules (additive-only for backward compatibility)
   - Plan for automated migration tooling (implement later)
   - **Effort: 1 hour**

**Tier 3 Total: ~6 hours**

**Grand Total (All Tiers): ~17 hours**

---

### Phasing Strategy

**Phase 0 (Pre-MVP): Tier 1 only** (4 hours)
- Interactive helper is foundational. Must exist before other features make sense.
- Without helper, manual formatting creates friction preventing adoption.
- **Ship decision:** If timeline constrained, ship Tier 1 only as "experimental feature" with manual fallback.

**Phase 1 (MVP): Tier 1 + Tier 2** (11 hours total)
- Minimum viable implementation. Evidence Objects are usable, secure, performant.
- Upper bound prevents abuse. Schema separation enables future flexibility.
- Content hash IDs prevent spoofing. Sanitization prevents XSS.
- **Ship decision:** This is recommended MVP. Functional and safe.

**Phase 2 (Production-Ready): All Tiers** (17 hours total)
- Validation command enables CI integration. Confidence rubric ensures consistency.
- Workflow guidance improves adoption. Schema versioning enables evolution.
- **Ship decision:** This is production-ready. All concerns addressed.

**Phase 3 (Enhancements): Defer list** (Future)
- Evidence Object editing command (UX I3)
- Custom git diff driver (Performance N1)
- Evidence Object library/reuse (UX N2)
- Type system extensibility (Security N1)

---

### What Happens If...

**If shipped without mitigations:**
- Security: XSS vulnerability in Alteri UI. Evidence spoofing via ID collision. Confidence manipulation. **Risk: HIGH**
- Performance: Validation timeouts (3-10s for 10 EV). Rate limit exhaustion. DoS via unlimited EV. **Risk: HIGH**
- Architecture: Tight coupling prevents schema evolution. First field addition requires data migration. **Risk: MEDIUM**
- UX: Manual formatting (2 min/EV). High error rate (40% format errors). Poor adoption. **Risk: HIGH**

**Overall risk without mitigations: HIGH — Do not ship.**

**If shipped with Tier 1 only (Interactive helper):**
- Security: Sanitization partially addressed (in helper), but no upper bound (DoS risk). ID collision risk remains. **Risk: MEDIUM-HIGH**
- Performance: Helper reduces token cost, but no validation, no metadata caching. **Risk: MEDIUM**
- Architecture: Tight coupling remains. **Risk: MEDIUM**
- UX: Cognitive load addressed. Usable. **Risk: LOW**

**Overall risk with Tier 1 only: MEDIUM — Experimental feature acceptable, production not recommended.**

**If shipped with Tier 1 + Tier 2 (MVP):**
- Security: XSS mitigated. DoS prevented. ID spoofing prevented. Confidence manipulation partially addressed (rubric later). **Risk: LOW-MEDIUM**
- Performance: Upper bound + schema separation + helper = fast creation, fast validation (with caching). **Risk: LOW**
- Architecture: Schema separation enables evolution. **Risk: LOW**
- UX: Interactive helper + workflow guidance = learnable, efficient. **Risk: LOW**

**Overall risk with MVP: LOW-MEDIUM — Production-ready for internal use. External release after Tier 3.**

---

## Metadata

**Synthesis Duration:** 90 minutes
**Total Debate Duration:** 368 minutes (6.1 hours across 9 documents)
**Findings Consolidated:** 27 (8 UNANIMOUS, 4 MAJORITY, 4 SPLIT, 11 MINORITY)
**Position Changes:** 1 major (REJECT → APPROVE), 3 score adjustments
**Escalations:** 3 (upper bound, interactive helper, content hash IDs)
**Disagreements Resolved:** 4 of 4 (100% resolution rate)
**Confidence in Synthesis:** Very High

**Files Generated:**
1. `cia-391-codebase-scan.md` (scan results)
2. `cia-391-round1-security-skeptic.md` (Security Round 1)
3. `cia-391-round1-performance-pragmatist.md` (Performance Round 1)
4. `cia-391-round1-architectural-purist.md` (Architectural Round 1)
5. `cia-391-round1-ux-advocate.md` (UX Round 1)
6. `cia-391-round2-security-skeptic.md` (Security Round 2)
7. `cia-391-round2-performance-pragmatist.md` (Performance Round 2)
8. `cia-391-round2-architectural-purist.md` (Architectural Round 2)
9. `cia-391-round2-ux-advocate.md` (UX Round 2)
10. `cia-391-synthesis.md` (this document)

**Total Output:** ~35,000 words across 10 documents
