# CIA-391 Round 2: Performance Pragmatist (Orange) — Cross-Examination
**Review Date:** 2026-02-15
**Reviewed:** Security Skeptic, Architectural Purist, UX Advocate Round 1 findings

---

## Responses to Other Reviewers

### Security Skeptic

#### C1: Citation Source Injection Risk (XSS)
**Response Type:** AGREE + PRIORITY

**Agreement:** XSS vulnerability is real. Academic databases DO return unsanitized metadata. Performance impact: **XSS prevention adds latency**.

**Sanitization cost analysis:**
```
Per Evidence Object:
- Regex for HTML tag detection: ~1ms
- Entity escaping (<, >, ", '): ~0.5ms
- Script pattern matching: ~2ms
Total: ~3.5ms per EV

For 10 Evidence Objects: 35ms (acceptable)
For 50 Evidence Objects: 175ms (if no upper bound, compounds validation latency from my C2)
```

**COMPLEMENT Security's mitigation with performance constraint:**
- Sanitization MUST happen at ingestion (when user adds EV), not at render time
- Reason: Ingestion is one-time cost. Rendering happens every page load. If sanitizing on every render, 10 EV × 3.5ms × 100 page views/day = 3.5 seconds cumulative latency/day.

**Revised architecture:**
```
User adds Evidence Object → Agent fetches metadata → Agent sanitizes → Stores sanitized EV → Render (no sanitization needed)
```

This aligns with UX's interactive helper proposal. **Agent-mediated input = sanitization checkpoint + UX improvement + performance optimization (sanitize once, render many times).**

---

#### C2: Confidence Level Manipulation
**Response Type:** CONTRADICT (on implementation)

**Disagreement:** Security proposes attribution tracking and immutability for confidence field. Performance cost:

**Attribution overhead:**
```yaml
Confidence: high (assessed by: claude-agent-id, 2026-02-15)
```
- Additional 50 characters per Evidence Object
- 10 EV × 50 chars = 500 bytes metadata overhead
- Not huge, but compounds with my I1 concern (format bloat)

**Immutability enforcement:**
- Requires version history (git log parsing or database audit table)
- Git log parsing for every validation = slow (100-500ms for repo with 1000 commits)
- Database audit table = infrastructure dependency (was pure markdown feature, now needs DB)

**ALTERNATIVE:** Soft immutability via convention, not enforcement.
- After spec approval, confidence changes require new commit with justification in message
- Validation warns if confidence changed between commits: "⚠️  EV-003 confidence changed (medium → high). Review commit message for justification."
- No hard block, but visible in review. **Social pressure > technical enforcement** for confidence integrity.

**Trade-off:** Security wants reliability. I want low latency. Compromise:
- Dev: No immutability checks (fast iteration)
- Review: Confidence change warnings (catches most manipulation)
- Prod: Full audit if org requires SOC2 compliance (but off by default)

---

#### I1: Evidence Object ID Namespace Collisions
**Response Type:** AGREE + PERFORMANCE IMPLICATION

**Agreement:** ID collision is risk. Security notes reference injection. I add: **collision detection is expensive**.

**Performance analysis of ID schemes:**

**Option 1: Sequential per-spec ([EV-001])**
- Collision check: O(n) scan of existing IDs (10 EV = 10 comparisons, fast)
- Cost: ~5ms for 10 Evidence Objects
- Problem: Renumbering on deletion (if EV-003 deleted, EV-004 becomes EV-003? Or skip ID?)

**Option 2: UUID ([EV-7f3e4d2a-...])**
- Collision check: None needed (128-bit UUID = astronomically unlikely collision)
- Cost: 0ms
- Problem: Ugly ID (Security + Architectural agreed on this), hard to reference in prose

**Option 3: Content hash (Architectural + Security proposal)**
- Collision check: None needed (cryptographic hash = collision-resistant)
- Cost: Hash generation = 2-5ms per EV (SHA-256)
- Benefit: Content-addressable (changing claim changes ID = automatic deduplication)
- Problem: Hash is long (64 hex chars). Truncating to 8 chars (Architectural's suggestion) reintroduces collision risk at scale.

**Performance recommendation:** **Content hash with 12-char truncation**
- Collision probability: ~1 in 16 trillion (acceptable for <10k Evidence Objects)
- ID length: Manageable (`[EV-7f3e4d2a1b6c]`)
- Deduplication: Preserved (same claim = same ID)
- Performance: One-time 5ms cost at creation

**This satisfies Security (spoofing prevention) + Architectural (decoupling) + me (low latency) + UX (reasonable ID length).**

---

### Architectural Purist

#### C1: Tight Coupling Between Citation Format and Storage Layer
**Response Type:** AGREE + PERFORMANCE BENEFIT

**Agreement:** Schema/format separation is architecturally correct. Performance bonus: **Separation enables multiple formats optimized for different use cases.**

**Format optimization by context:**

**Context 1: User drafting (in write-prfaq command)**
- Use: Verbose 5-line format (human-readable)
- Token cost: 150 tokens per EV (expensive but one-time)

**Context 2: Agent re-reading spec (in anchor command)**
- Use: Compact YAML format (token-efficient)
- Token cost: 50 tokens per EV (3x more efficient)
- Impact: 10 EV saves 1000 tokens = $0.003 per spec read (at $3/M tokens for Claude Opus)

**Context 3: Alteri rendering (in Next.js)**
- Use: JSON API response (pre-computed HTML)
- Latency: 0ms (no markdown parsing)
- Rendering cost: Eliminated (markdown → HTML happens once at save, cached forever)

**Architectural's schema separation enables this multi-format strategy.** Single canonical schema (`evidence-object-schema.md`), multiple serializations. This is **standard practice in high-performance systems** (Protobuf, gRPC use this pattern).

**PRIORITY SHIFT:** What Architectural framed as architectural purity, I reframe as **performance optimization**. Separation isn't just clean code—it's 3x token savings + zero-latency rendering.

**Recommendation:** Implement schema separation in Phase 1, not Phase 2. Performance gains justify upfront investment.

---

#### C2: Evidence Object ID Format Violates Single Responsibility
**Response Type:** AGREE (already addressed in Security response)

Covered above in "Security I1" response. Content hash with 12-char truncation solves this.

---

#### I1: Evidence Object Format Not Versioned
**Response Type:** AGREE + MIGRATION PERFORMANCE

**Agreement:** Versioning required. Performance concern: **Schema migration is high-latency operation**.

**Migration scenarios:**

**Scenario 1: Add optional field (backward-compatible)**
- Old EV: 4 fields (type, source, claim, confidence)
- New EV: 5 fields (adds `methodology`)
- Migration: None needed. Old EV valid in new schema (optional field defaults to null)
- Performance: 0ms

**Scenario 2: Add required field (breaking change)**
- Old EV: 4 fields
- New EV: 5 fields (requires `methodology`)
- Migration: ALL old Evidence Objects must be updated
- If 50 specs × 5 EV/spec = 250 Evidence Objects to migrate
- Human input needed (methodology not inferrable)
- Performance: Not automated = human bottleneck (days to weeks)

**Scenario 3: Change field constraints (breaking change)**
- Old: `Confidence: [any value]`
- New: `Confidence: [high|medium|low]` (enum constraint)
- Migration: Validate all old Evidence Objects against new constraint
- Auto-fixable if old values map cleanly (e.g., "High" → "high")
- Performance: 250 EV × 10ms validation = 2.5 seconds (acceptable)

**Performance principle for schema evolution:** **Favor additive changes (optional fields) over breaking changes (required fields or constraint tightening).** This keeps migration cost low.

**Recommendation:** Document in `evidence-object-schema.md`:
```yaml
Schema Evolution Rules:
1. New fields MUST be optional (backward-compatible)
2. Existing fields CANNOT become required (breaking change)
3. Constraints CAN be loosened, not tightened (e.g., 300 → 500 char max is OK, reverse is breaking)
4. Version bump: +0.1 for additive, +1.0 for breaking
```

**This is infrastructure-level performance optimization** (minimize human bottleneck).

---

### UX Advocate

#### C1: Evidence Object Format Has High Cognitive Load
**Response Type:** AGREE + PERFORMANCE-UX SYNERGY

**Agreement:** Manual formatting is slow (cognitive load) and error-prone (validation failures). Both are **performance bottlenecks from user's perspective**.

**User performance metrics:**
- Manual formatting: 2 min/EV (UX estimate) × 10 EV = 20 minutes
- Interactive helper: 30 sec/EV (paste DOI, agent fetches metadata) × 10 EV = 5 minutes
- **15 minutes saved per spec = 75% time reduction**

This is **user-facing performance**, not system performance, but equally important. If spec drafting takes 2 hours instead of 30 minutes, users will:
1. Write fewer specs (lower adoption)
2. Cut corners (fewer Evidence Objects to save time)
3. Skip validation (to avoid re-doing formatting)

**All three degrade research grounding quality.**

**UX's interactive helper is performance feature disguised as UX feature.** It's also security feature (as Security noted in Round 2). Triple benefit: UX + security + performance.

**PRIORITY:** Elevate UX C1 interactive helper from "nice-to-have" to **required for MVP**. Without it, Evidence Objects are too slow to use at scale.

---

#### C2: No Guidance on When to Add Evidence Objects
**Response Type:** AGREE

**Agreement:** Workflow ambiguity = wasted effort (performance cost). If user adds Evidence Objects at wrong stage, they redo work.

**Example:**
1. User writes Press Release with 5 claims
2. User doesn't know to add Evidence Objects yet
3. User completes FAQ, Pre-Mortem
4. Validation fails: "Need 3+ Evidence Objects"
5. User goes back to Press Release, identifies claims needing evidence
6. User adds Evidence Objects
7. **30 minutes wasted** on rework

**Incremental validation (my I2) solves this.** After each section:
- After Press Release: "Found 3 claims referencing psychological constructs. Add Evidence Objects now? [y/n]"
- After FAQ: "Evidence Objects: 2/3 minimum. Add 1 more before continuing."

**This is performance optimization** (fail-fast, reduce rework).

**Combine UX's workflow documentation + my incremental validation = zero rework.**

---

#### I2: Confidence Field Lacks User Guidance
**Response Type:** COMPLEMENT

**Agreement:** Rubric needed. Performance angle: **Manual confidence assessment is slow + inconsistent = performance + quality issue**.

**Assessment time by approach:**

**Manual (no rubric):**
- User reads paper abstract, methods, results
- User makes subjective judgment
- Time: 5-10 minutes per paper
- Consistency: Low (varies by user background)

**Rubric-guided (UX proposal):**
- User looks up journal impact factor
- User checks sample size in paper
- User counts replication studies (via citation search)
- User scores 5 dimensions, sums score
- Time: 3-5 minutes per paper (faster but still slow)
- Consistency: High

**Automated (Security's Round 2 proposal + my C2 concern):**
- Agent fetches paper metadata from Semantic Scholar
- Agent extracts: journal tier, citation count, sample size (from paper text), publication year
- Agent calculates confidence score using rubric formula
- Agent presents to user: "Calculated confidence: medium. Override? [y/n]"
- Time: 30 seconds per paper (mostly waiting for API)
- Consistency: Perfect (algorithm is deterministic)

**Performance winner: Automated.** But requires solving my C2 (metadata fetching bottleneck).

**Synthesis:**
1. Implement UX's rubric as **algorithm** (not manual checklist)
2. Use Security's Round 2 formula for scoring
3. Use my C2 mitigation (parallel fetch + caching) to keep latency low
4. Present calculated confidence to user as default, allow override with justification

**This satisfies UX (reduces cognitive load), Security (prevents manipulation), me (low latency via caching), and improves consistency.**

---

#### I3: Evidence Object Editing Is Cumbersome
**Response Type:** AGREE + AVOID EDITING

**Agreement:** Editing Evidence Objects in markdown is slow. Performance perspective: **Best performance is no editing.**

**Observation:** If Evidence Objects are well-formed at creation (via interactive helper), editing is rare. When does editing happen?

**Edit triggers:**
1. Reviewer says "Confidence should be medium, not high"
2. Paper gets retracted (source needs removal)
3. User finds better paper (source replacement)
4. Claim wording needs clarification

**Frequency:** Rare if Evidence Objects are correct initially. If interactive helper fetches metadata automatically, Source + Claim are accurate. Confidence is algorithm-assigned (harder to dispute). Only user-error edits remain.

**Performance recommendation:** Optimize creation (interactive helper), not editing. If editing is cumbersome but rare, acceptable trade-off.

**That said:** UX's `/sdd:edit-evidence-object` command is reasonable. Estimated latency: <100ms (find-and-replace in markdown file). Not a performance concern.

---

## Position Changes

### Original Position: CONDITIONAL APPROVE
**New Position:** CONDITIONAL APPROVE (unchanged)

**Reasoning:** Cross-examination confirmed my performance concerns and found synergies:
1. **UX's interactive helper** enables performance optimization (agent-mediated sanitization, one-time formatting cost)
2. **Architectural's schema separation** enables token savings (compact format for agents)
3. **Security's attribution** has acceptable overhead if implemented as soft constraint

**No position change, but elevated priorities:**
- My C1 (upper bound) → ESCALATE (Security confirmed DoS vector)
- UX C1 (interactive helper) → REQUIRED (not nice-to-have)
- Architectural C1 (schema separation) → Phase 1 (not Phase 2)

---

## New Insights

### 1. Triple-Benefit Features
Interactive helper (UX C1) provides:
- **UX benefit:** Reduces cognitive load
- **Security benefit:** Centralizes sanitization
- **Performance benefit:** Agent formats once, renders many times

Recommend prioritizing features with triple benefits over single-benefit features.

---

### 2. User Performance = System Performance
UX concerns about slow manual formatting are **user-facing performance issues**. If Evidence Objects take 20 minutes to write, users avoid them. Feature fails regardless of system latency.

Expand performance lens to include **user time**, not just system time.

---

### 3. Schema Separation Is Performance Optimization
Architectural purity (schema/format decoupling) enables:
- Token savings (compact format for agents)
- Rendering optimization (pre-computed HTML)
- Multi-format support (YAML for APIs, markdown for humans)

**Architectural discipline = performance wins.** Not just clean code.

---

### 4. Confidence Automation Solves Three Problems
Automated confidence calculation:
- **Performance:** Faster than manual assessment (30s vs. 5min)
- **Security:** Prevents manipulation
- **UX:** Reduces cognitive load

Single feature solves multiple reviewer concerns. High ROI.

---

## Revised Scoring

| Dimension | Original | Revised | Change Rationale |
|-----------|----------|---------|------------------|
| **Scalability** | 55/100 | 60/100 | ↑ Upper bound (10 EV max) + schema separation (token savings) improve scalability vs. unbounded format |
| **Latency** | 50/100 | 55/100 | ↑ Parallel fetch + caching + content hash (O(1) collision check) improve latency vs. sequential API calls |
| **User Experience** | 65/100 | 75/100 | ↑ Interactive helper + automated confidence + incremental validation significantly improve user-facing performance |

**Overall Performance Score:** 63/100 (was 59/100)
**Risk Level:** MEDIUM (was MEDIUM, unchanged)

**Reasoning for upgrade:** Cross-examination revealed mitigation synergies. Combining UX helper + Architectural schema + Security automation produces better performance than my original proposals alone.

---

## Escalations

### ESCALATE: C1 (Evidence Object Upper Bound) Is Security + Performance Critical
**Original classification:** Performance CRITICAL
**New classification:** Security + Performance CRITICAL

**Rationale:** Security confirmed DoS vector (rate limit exhaustion, validation timeout). This is not just slow—it's exploitable.

**Recommendation:** Hard limit (10 EV) enforced in schema validation, not documentation.

---

## Agreements

### Architectural C1 (Schema Separation)
Agree + elevate to Phase 1 for performance reasons (token savings, rendering optimization).

### Security C1 (XSS Risk)
Agree + mitigation cost is acceptable (3.5ms per EV). Sanitize at ingestion, not render.

### UX C1 (Interactive Helper)
Agree + elevate to MVP requirement. 75% time savings justifies priority.

### UX C2 (Workflow Guidance)
Agree + combine with my I2 (incremental validation) for fail-fast approach.

### UX I2 (Confidence Rubric)
Agree + implement as algorithm, not manual checklist. Automation satisfies performance + security + UX.

---

## Contradictions

### Security C2 (Confidence Immutability)
**Security says:** Hard immutability with attribution tracking and git log parsing.

**I say:** Soft immutability (commit message convention) is sufficient. Hard enforcement adds 100-500ms latency per validation.

**Resolution proposal:** Two-tier approach:
- **Dev:** No immutability checks (fast)
- **Prod (optional):** Full audit if compliance required (SOC2, FDA, etc.)

Most orgs don't need hard immutability. Those that do can opt in.

---

## Recommendation (Updated)

**CONDITIONAL APPROVE** — Original position maintained, with **elevated priorities**:

### Required for MVP (not nice-to-have):
1. **Evidence Object upper bound** (10 max) — Prevents DoS, improves scalability
2. **Interactive helper** (UX C1) — 75% time savings, enables sanitization, required for adoption
3. **Schema separation** (Architectural C1) — Enables token savings (3x) + rendering optimization
4. **Parallel metadata fetch + caching** (my C2) — Reduces validation latency from 3s to <1s
5. **Content hash IDs** (Architectural + Security C2) — Prevents spoofing, O(1) collision check

### Defer to Phase 2 (important but not blocking):
- Confidence automation (implement rubric manually first, automate later)
- Edit command (editing is rare if creation is good)
- Custom git diff driver (nice-to-have for review velocity)

**If MVP requirements not met:** Evidence Objects are too slow/cumbersome to use. Adoption fails. Research grounding advantage doesn't materialize.

**Estimated effort for MVP requirements:**
- Upper bound: 30 minutes (validation rule)
- Interactive helper: 4 hours (UX estimate, reuse)
- Schema separation: 4 hours (Architectural estimate, reuse)
- Parallel fetch + caching: 2 hours (implement)
- Content hash IDs: 2 hours (Security estimate, reuse)
**Total: 12-13 hours** (overlaps reduce total)

**Performance impact if shipped with MVP requirements:**
- Evidence Object creation: 30 seconds (was 2 minutes)
- Validation latency: <1 second (was 3-10 seconds)
- Token cost: 50 tokens/EV (was 150 tokens)
- Spec drafting time: 30 minutes (was 2 hours)

**75% time savings, 3x token savings, 10x latency improvement.** MVP requirements justify effort.

---

## Metadata

**Cross-Examination Duration:** 45 minutes
**Reviews Consulted:** Security Skeptic, Architectural Purist, UX Advocate (all Round 1)
**Position Changed:** No (CONDITIONAL APPROVE maintained)
**Score Changed:** Yes (59→63, upgrade due to mitigation synergies)
**Escalations:** 1 (C1 upper bound to security-critical)
**Agreements:** 6 | Complements: 2 | Contradictions: 1 | Priority Shifts: 3
