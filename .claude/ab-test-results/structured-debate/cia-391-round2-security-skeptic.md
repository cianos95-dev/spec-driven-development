# CIA-391 Round 2: Security Skeptic (Red) — Cross-Examination
**Review Date:** 2026-02-15
**Reviewed:** Performance Pragmatist, Architectural Purist, UX Advocate Round 1 findings

---

## Responses to Other Reviewers

### Performance Pragmatist

#### C1: No Evidence Object Count Upper Bound
**Response Type:** AGREE + COMPLEMENT

**Agreement:** Unlimited Evidence Objects = performance risk AND security risk. Performance identified validation latency (10s for 50 EV). I add: **denial-of-service attack vector**.

**Complementary concern:** Attacker submits spec with 1000 Evidence Objects, each with maximum-length fields (500 char Source, 300 char Claim). Total payload = 800KB. If validation fetches metadata for each, 1000 API calls launched. Two impacts:

1. **Rate limit exhaustion:** Semantic Scholar free tier = 100 req/5min. Single malicious spec consumes entire team's quota. Legitimate users' validations fail.
2. **Validation timeout:** If validation has 30s timeout (reasonable for CI), 1000 EV × 300ms = 5 minutes. Timeout triggers, validation never completes, spec merges without review.

**ESCALATE:** This is not just performance, it's **availability attack**. Recommend stricter limit than Performance's suggestion. I propose:
- **Hard limit: 10 Evidence Objects** (align with Performance)
- **Validation quota: Max 20 Evidence Objects validated per user per hour** (prevents quota exhaustion)
- **Fail-fast on oversized fields:** Reject before fetching metadata

**New mitigation (security angle):**
```yaml
Evidence Object limits (enforced before validation):
- Count: ≤10 per spec (error at 11)
- Source: ≤500 chars (reject longer)
- Claim: ≤300 chars (reject longer)
- Total size: ≤10KB per spec's Evidence Objects combined
- Validation quota: 20 EV per user per hour (rate limiting)
```

---

#### C2: Source Metadata Fetching Creates Validation Bottleneck
**Response Type:** CONTRADICT (on solution)

**Disagreement:** Performance recommends parallel fetching + caching + graceful degradation. This **weakens security** of confidence validation.

**Problem with graceful degradation:**
> "If metadata fetch fails, validation continues with warning"

This creates bypass: User assigns `Confidence: high`, metadata fetch fails (or is blocked), validation passes with warning. User ignores warning. Inflated confidence ships to production.

**Problem with caching:**
> "Cache source metadata for 7 days"

Stale data attack: Paper gets retracted on day 1. Cache serves non-retracted metadata for 6 more days. Evidence Object claims "high confidence" based on retracted paper.

**PRIORITY:** Security > performance here. Confidence validation must be reliable or not exist.

**Alternative approach:**
1. **Make confidence validation optional but blocking when enabled:**
   - Default: User-assigned confidence, no metadata check (fast, insecure)
   - Flag: `--validate-confidence` runs metadata check (slow, secure)
   - Production CI: Always uses `--validate-confidence`
2. **Cache with short TTL:**
   - 24 hours max, not 7 days
   - Cache invalidation on retraction notifications (via CrossRef API)
3. **No graceful degradation for production:**
   - Dev: Validation warns on fetch failure
   - CI: Validation fails on fetch failure (blocks merge)

**Revised scoring:** Performance scores evidence validation as pure latency problem. I score it as **security-performance trade-off** requiring different thresholds for dev vs. prod.

---

### Architectural Purist

#### C1: Tight Coupling Between Citation Format and Storage Layer
**Response Type:** AGREE + SCOPE

**Agreement:** Schema/format separation is architecturally sound. Evidence Objects WILL evolve. Coupling prevents evolution.

**Security angle:** Architectural coupling creates **security technical debt**. When C1 XSS vulnerability needs fixing (sanitize Source field), tight coupling means:

1. Update format definition (research-grounding SKILL.md)
2. Update validation logic (wherever it lives)
3. Update rendering (Alteri UI)
4. Migrate existing Evidence Objects (data migration)

If schema were separate, sanitization rule changes in one place. **Coupling increases time-to-patch for security vulns.**

**COMPLEMENT:** Architectural debt becomes security debt when vulns are discovered. I propose:

**Security-driven architecture requirement:**
```yaml
Evidence Object security properties (must be schema-level, not format-level):
- input_sanitization: [rules for HTML/script removal]
- field_validation: [length limits, character whitelist]
- attribution_tracking: [who created, who modified, when]
- immutability_policy: [which fields can be edited after approval]
```

These properties live in canonical schema (Architectural's `evidence-object-schema.md`), not 5-line markdown format. Decoupling protects security invariants during format evolution.

**Recommendation:** Adopt Architectural's layered approach specifically to enable security rule centralization.

---

#### C2: Evidence Object ID Format Violates Single Responsibility
**Response Type:** AGREE + SECURITY IMPLICATION

**Agreement:** `[EV-001]` conflates logical ID with display ID. Markdown collision risk confirmed.

**Security angle:** ID format ambiguity enables **reference injection**. If user writes:

```markdown
As discussed in [EV-003], limerence correlates with attachment anxiety.

Later, user adds:

[EV-003] Type: empirical
Source: Malicious (2026). Fake Paper.
Claim: "Limerence is cured by product we're building"
Confidence: high
```

Markdown renders `[EV-003]` in prose as link to Evidence Object with fake claim. If reviewers skim (likely), fake evidence passes review.

**Why this is exploitable:** Adversarial reviewer personas check for research grounding but may not **verify claim accuracy against source**. If Evidence Object exists and has `Confidence: high`, reviewers assume it's legitimate.

**ESCALATE:** ID collision is not just markdown parsing issue. It's **evidence spoofing vector**.

**Mitigation (combines Architectural + Security concerns):**
1. **Logical ID = content hash:**
   ```
   ID: sha256(type + source + claim)[:8]
   Display: [EV-001] <!-- canonical-id: 7f3e4d2a -->
   ```
   Content-addressable IDs prevent spoofing. Changing claim changes ID.
2. **Validation checks:**
   - No duplicate IDs (content hash ensures this)
   - All references `[EV-XXX]` resolve to existing Evidence Object
   - All Evidence Objects are referenced at least once (dead code detection)

---

#### I1: Evidence Object Format Not Versioned
**Response Type:** AGREE

**Agreement:** Schema versioning is required. When security vulnerabilities are patched (sanitization rules added), old Evidence Objects must be flagged for review.

**Security versioning requirement:**
```yaml
version: 2.0
security_patch_level: 2024-Q2  # tracks when sanitization rules were applied
```

Validation checks: "Evidence Object v1.0 predates XSS sanitization rules. Requires migration."

---

### UX Advocate

#### C1: Evidence Object Format Has High Cognitive Load
**Response Type:** COMPLEMENT

**Agreement:** High cognitive load = users make mistakes. Mistakes = security vulnerabilities slip through.

**Security-UX intersection:** When format is hard to use, users:
1. Copy-paste from previous Evidence Objects without updating (stale citations, wrong confidence)
2. Skip validation to save time (bypassing security checks)
3. Use shortest valid format (minimal content, loses context for security review)

**Example:** User wants to add paper quickly. Copies EV-001, changes Source, forgets to update Claim. Now EV-002 has mismatched Source/Claim. Adversarial review doesn't catch it (too much cognitive load to cross-check).

**UX's interactive helper solves security problem:** If agent formats Evidence Objects after fetching metadata, **agent controls sanitization**. User never touches raw format = no injection opportunity.

**PRIORITY SHIFT:** UX's interactive helper is not just nice-to-have. It's **security hardening**. User input goes through agent sanitizer before becoming Evidence Object.

**Revised mitigation for my C1 (XSS):**
- Short-term: Document sanitization rules (as I originally said)
- Long-term: Agent-formatted Evidence Objects (as UX suggested) = automatic sanitization

**New position:** **UX C1 mitigation enables Security C1 mitigation.** Recommend implementing UX interactive helper as security feature, not just UX feature.

---

#### C2: No Guidance on When to Add Evidence Objects
**Response Type:** AGREE + SECURITY WORKFLOW

**Agreement:** Workflow ambiguity = users add Evidence Objects at wrong stage. Security implication: If Evidence Objects added after spec approval (Gate 1), they bypass review.

**Scenario:**
1. User writes spec, adds 3 Evidence Objects
2. Spec approved (Gate 1)
3. User realizes claim needs stronger evidence
4. User adds EV-004 with `Confidence: high`
5. EV-004 never reviewed (added post-approval)

**Immutability violation:** My C2 mitigation required confidence immutability after approval. But UX correctly identifies: **workflow doesn't specify when approval happens relative to Evidence Object drafting**.

**COMPLEMENT UX's workflow guidance with security gates:**
```markdown
## Evidence Object Lifecycle

1. **Draft Phase** (status: spec:draft)
   - User adds Evidence Objects freely
   - Confidence is mutable
   - Validation warnings, not errors

2. **Review Phase** (status: spec:review)
   - Evidence Objects frozen for review
   - Adversarial reviewers check confidence accuracy
   - Changes require re-review

3. **Approved Phase** (status: spec:ready)
   - Evidence Objects immutable
   - Adding new EV requires spec status → draft (triggers re-review)
   - Confidence changes require human justification (tracked in git commit message)
```

**This workflow prevents post-approval evidence tampering.**

---

#### I2: Confidence Field Lacks User Guidance
**Response Type:** AGREE + AUTOMATE

**Agreement:** Confidence rubric needed. UX's 5-dimension rubric is thorough but **manual assessment is error-prone**.

**Security improvement:** Automate confidence calculation using metadata:

```python
def calculate_confidence(source_metadata):
    score = 0
    # Source quality (from journal API)
    if source_metadata.impact_factor > 5: score += 1
    elif source_metadata.impact_factor > 2: score += 0.5

    # Sample size (from paper metadata)
    if source_metadata.sample_size > 500: score += 1
    elif source_metadata.sample_size > 50: score += 0.5

    # Replication (from citation network)
    if source_metadata.replication_count > 1: score += 1

    # Relevance (user input, required)
    relevance = user_input("Relevance? [direct/related/tangential]")
    if relevance == "direct": score += 1
    elif relevance == "related": score += 0.5

    # Recency
    if (current_year - source_metadata.year) < 5: score += 1
    elif (current_year - source_metadata.year) < 10: score += 0.5

    # Map score to confidence
    if score >= 3.5: return "high"
    elif score >= 2: return "medium"
    else: return "low"
```

**Security benefit:** Algorithm-assigned confidence is auditable and reproducible. User can't inflate without justification. Validation checks: "User assigned high, algorithm calculated medium. Justification required."

**Combines UX's rubric + Performance's metadata fetching + my attribution tracking.**

---

## Position Changes

### Original Position: CONDITIONAL APPROVE
**New Position:** CONDITIONAL APPROVE (unchanged)

**Reasoning:** Cross-examination revealed:
1. **Performance concerns amplify security risks** (DoS via unlimited EV, rate limit exhaustion)
2. **Architectural coupling increases time-to-patch** for security vulns
3. **UX friction creates security bypass opportunities** (copy-paste errors, skipping validation)

All three reviewers' concerns **strengthen my security case** rather than weaken it. No position change needed, but **priority escalations**:

- My C1 (XSS) → Implement via UX's interactive helper (automatic sanitization)
- My C2 (confidence manipulation) → Automate using Performance's metadata fetching
- My I1 (ID collision) → Adopt Architectural's content-addressable IDs

---

## New Insights

### 1. Security-UX Convergence
Interactive Evidence Object helper is both:
- **UX improvement:** Reduces cognitive load
- **Security hardening:** Centralizes sanitization, prevents injection

Recommend building helper with security as primary driver, UX as secondary benefit.

---

### 2. Performance Limits Are Security Controls
Upper bounds on Evidence Object count and field lengths are not just performance optimizations. They're **security controls** preventing:
- DoS via payload bloat
- Rate limit exhaustion
- Validation timeout bypass

Recommend framing Performance's C1 mitigation as security requirement, not performance suggestion.

---

### 3. Architectural Debt Becomes Security Debt
Tight coupling between schema/format (Architectural C1) means:
- Security patches touch multiple layers
- Rollout is slow and error-prone
- Vulnerability window extends

Recommend prioritizing Architectural's schema separation specifically for security maintainability.

---

### 4. Confidence Validation Is Optional Security Feature
All three reviewers (Performance, UX, me) discussed confidence validation but from different angles:
- **Performance:** It's slow, cache it, make it optional
- **UX:** It's subjective, provide rubric
- **Security:** It prevents manipulation, must be reliable

**Synthesis:** Confidence validation should be:
- **Optional in dev** (fast feedback loop)
- **Mandatory in CI** (security gate)
- **Automated via rubric** (reduces subjectivity + manipulation risk)
- **Cached with short TTL** (balances performance + freshness)

This satisfies all three concerns.

---

## Revised Scoring

| Dimension | Original | Revised | Change Rationale |
|-----------|----------|---------|------------------|
| **Security** | 50/100 | 45/100 | ↓ Cross-examination revealed DoS vectors (Performance C1) not in original review. Additional attack surface identified. |
| **Data Integrity** | 60/100 | 55/100 | ↓ Evidence spoofing via ID collision (Architectural C2) is more severe than originally assessed. |
| **Auditability** | 40/100 | 50/100 | ↑ UX's workflow guidance + my lifecycle gates improve auditability vs. original spec. |

**Overall Security Score:** 50/100 (was 58/100)
**Risk Level:** HIGH (was MEDIUM-HIGH)

**Reasoning for downgrade:** Additional attack vectors identified during cross-examination. DoS + evidence spoofing + rate limit exhaustion are cumulative risks, not isolated. Must address before production.

---

## Escalations

### ESCALATE 1: Performance C1 (Evidence Object Upper Bound) Is Security-Critical
**Original classification:** Performance CRITICAL
**Security reclassification:** Security CRITICAL

**Rationale:** Unlimited Evidence Objects enable DoS (validation timeout) and rate limit exhaustion (quota consumption). These are availability attacks, not just performance degradation.

**Recommendation:** Implement hard limit (10 EV) and validation quota (20 EV/user/hour) in schema, not just documentation.

---

### ESCALATE 2: Architectural C2 (ID Format) Enables Evidence Spoofing
**Original classification:** Architectural CRITICAL (coupling concern)
**Security reclassification:** Security CRITICAL (spoofing vector)

**Rationale:** Ambiguous ID format allows fake Evidence Objects to masquerade as legitimate citations in prose.

**Recommendation:** Content-addressable IDs (hash-based) prevent spoofing. Prioritize this over display-only concerns.

---

## Disagreements

### Performance's Graceful Degradation (Metadata Fetch Failures)

**Performance says:** "If metadata fetch fails, validation continues with warning"

**I say:** This creates security bypass. Production validation must fail, not warn.

**Resolution needed:** Two validation modes (dev vs. prod) as I proposed in "Responses to Performance C2."

---

## Recommendation (Updated)

**CONDITIONAL APPROVE** — Original position maintained, but **escalate 2 findings to security-critical**:

1. Evidence Object upper bound (10 max) + validation quota (DoS prevention)
2. Content-addressable IDs (evidence spoofing prevention)
3. Adopt UX's interactive helper (automatic sanitization)
4. Adopt Architectural's schema separation (security maintainability)
5. Implement dev vs. prod validation modes (balance performance + security)

**If escalations not addressed:** System is vulnerable to availability attacks (DoS via unlimited EV, rate limit exhaustion) and data integrity attacks (evidence spoofing via ID collision). These are production-blocking security issues.

**Estimated effort for escalated mitigations:**
- Upper bound + quota: 1 hour (schema validation)
- Content-addressable IDs: 2 hours (ID generation + migration plan)
- Interactive helper: 4 hours (UX estimation, reuse for security)
- Schema separation: 4 hours (Architectural estimation, reuse for security rules)
**Total: 11 hours** (overlaps reduced by reusing others' solutions)

---

## Metadata

**Cross-Examination Duration:** 40 minutes
**Reviews Consulted:** Performance Pragmatist, Architectural Purist, UX Advocate (all Round 1)
**Position Changed:** No (CONDITIONAL APPROVE maintained)
**Score Changed:** Yes (58→50, downgrade due to additional attack vectors)
**Escalations:** 2 (Performance C1, Architectural C2)
**Agreements:** 6 | Complements: 4 | Contradictions: 1 | Priority Shifts: 2
