# CIA-391 Round 2: UX Advocate (Green) — Cross-Examination
**Review Date:** 2026-02-15
**Reviewed:** Security Skeptic, Performance Pragmatist, Architectural Purist Round 1 findings

---

## Responses to Other Reviewers

### Security Skeptic

#### C1: Citation Source Injection Risk (XSS)
**Response Type:** AGREE + UX BENEFIT

**Agreement:** XSS risk exists. UX perspective: **Security vulnerability creates bad user experience.**

**User impact of XSS:**
1. **Trust erosion:** If Alteri renders malicious scripts, users lose confidence in platform. "My research platform got hacked" = existential threat to adoption.
2. **Data loss:** XSS enables session hijacking. User's spec drafts, Evidence Objects, research data could be stolen. Recovery UX is terrible (password resets, data audits, incident reports).
3. **Reputation damage:** If Alteri becomes known for security issues, researchers avoid it. Network effects work in reverse.

**Security's mitigation (sanitization rules) is UX improvement:** Preventing XSS = preserving trust = good UX.

**COMPLEMENT Security with UX-aware sanitization feedback:**

**Bad sanitization UX:**
```
Error: Evidence Object EV-001 contains invalid characters. Rejected.
```
User sees error, doesn't know what's invalid, has to guess.

**Good sanitization UX:**
```
⚠️  Evidence Object EV-001 cleaned:
- Removed: <script> tag
- Removed: onerror attribute
- Source field sanitized: "Author (2026). <script>alert(1)</script> Title." → "Author (2026). Title."

Evidence Object saved. Review cleaned version for accuracy.
```
User knows what changed, can verify correctness.

**Recommendation:** Security's sanitization rules + UX feedback = secure + transparent system.

---

#### C2: Confidence Level Manipulation Without Attribution
**Response Type:** CONTRADICT (on complexity)

**Disagreement:** Security wants attribution tracking (`Confidence: high (assessed by: claude-agent-id, 2026-02-15)`). UX concern: **Attribution clutters display.**

**Visual comparison:**

**With attribution (Security proposal):**
```
[EV-001] Type: empirical
Source: Wakin & Vo (2008). Love-Variant: The Wakin-Vo I.D.R. Model of Limerence. Sexual and Relationship Therapy.
Claim: "Limerence involves intrusive thinking about the limerent object, occurring on average 85% of waking hours in acute cases"
Confidence: high (assessed by: claude-agent-dd0797a4, 2026-02-15T10:30:00Z)
```

**Without attribution (original spec):**
```
[EV-001] Type: empirical
Source: Wakin & Vo (2008). Love-Variant: The Wakin-Vo I.D.R. Model of Limerence. Sexual and Relationship Therapy.
Claim: "Limerence involves intrusive thinking about the limerent object, occurring on average 85% of waking hours in acute cases"
Confidence: high
```

**Difference:** 60 characters. Multiply by 10 Evidence Objects = 600 chars. On mobile, this is 3-4 extra lines per Evidence Object = 30-40 lines total. **Significant visual bloat.**

**Alternative: Separate attribution from display**

**Display (human-readable):**
```
[EV-001] Type: empirical
Source: Wakin & Vo (2008)...
Claim: "..."
Confidence: high
```

**Metadata (machine-readable, hidden by default):**
```yaml
# In spec frontmatter or separate metadata file
evidence_audit:
  EV-001:
    confidence_history:
      - value: high
        assessed_by: claude-agent-dd0797a4
        assessed_at: 2026-02-15T10:30:00Z
        reason: Meta-analysis, N=5000, replicated
```

**User sees clean Evidence Object. Auditors (or curious users) expand metadata. Best of both worlds.**

**PRIORITY:** Security need (audit trail) + UX need (clean display) = separate attribution from presentation.

---

### Performance Pragmatist

#### C1: No Evidence Object Count Upper Bound
**Response Type:** AGREE + UX JUSTIFICATION

**Agreement:** Upper bound needed. Performance identified latency. I add: **Cognitive load increases non-linearly with count.**

**Cognitive science: Working memory limit = 7±2 items (Miller's Law).** Reviewers can hold ~7 Evidence Objects in working memory while evaluating spec. Beyond 7, must re-read previous Evidence Objects to remember what evidence exists. **This is cognitive thrashing.**

**User experience by Evidence Object count:**

| Count | User Experience | Review Quality |
|-------|-----------------|----------------|
| 3-5 | Optimal. User remembers all evidence. Can cross-reference claims easily. | High |
| 6-8 | Acceptable. At edge of working memory. Some re-reading needed. | Medium-high |
| 9-12 | Difficult. Must scroll back frequently to check evidence. Loses flow. | Medium |
| 13+ | Overwhelming. Can't keep track of what evidence exists. Gives up on thorough review. | Low |

**Performance's 10 EV max aligns with cognitive limits (7+3 buffer).** This is not arbitrary—it's **grounded in cognitive psychology.**

**COMPLEMENT Performance with UX guidance:**
```markdown
## Why 10 Evidence Objects Maximum?

Research on working memory (Miller, 1956; Cowan, 2001) shows humans can hold 7±2 items in active memory. Beyond this, cognitive load increases, review quality decreases.

If your feature requires >10 citations:
1. Distill to core findings (3-5 high-impact papers)
2. Move comprehensive literature review to separate document
3. Link to extended bibliography in spec

Evidence Objects are for PRIMARY support, not exhaustive coverage.
```

**This reframes upper bound as UX feature (reduces cognitive load), not just performance constraint.**

---

#### C2: Source Metadata Fetching Creates Validation Bottleneck
**Response Type:** AGREE + ASYNC UX PATTERN

**Agreement:** Validation latency is bad UX. Performance proposed parallel fetch + caching. I add: **Make validation async + progressive.**

**Synchronous validation UX (current):**
```
User: "/sdd:write-prfaq validate"
[10 second wait...]
Agent: "✓ Validation passed. 5 Evidence Objects found."
```
**Problem:** 10-second wait with no feedback. User doesn't know if system is frozen or working. Anxiety increases. May cancel prematurely.

**Async validation UX (better):**
```
User: "/sdd:write-prfaq validate"
Agent: "Starting validation..."
Agent: "✓ Structure check passed (1/4)"
Agent: "✓ Evidence Objects found: 5 (2/4)"
Agent: "⏳ Fetching source metadata... (3/4)"
[Progress bar: ████░░░░░░ 40%]
Agent: "✓ Confidence validated: 3 high, 2 medium (4/4)"
Agent: "✓ Validation complete. Took 8.2 seconds."
```
**Improvements:**
- **Progressive disclosure:** User sees progress, knows system is working
- **Estimated time:** "Fetching metadata" signals potentially slow step
- **Partial results:** If metadata fetch fails for 1 EV, show 4/5 validated (not total failure)

**Performance's parallel fetch reduces latency. Async UX makes remaining latency tolerable.**

---

#### I1: Evidence Object Format Bloats Spec Files
**Response Type:** AGREE

**Agreement:** 5-line format is verbose. UX angle: **Verbose format increases scroll distance, harms scanability.**

**Scanability test:** How fast can user find specific Evidence Object?

**5-line format (verbose):**
```markdown
[EV-001] Type: empirical
Source: Wakin & Vo (2008)...
Claim: "..."
Confidence: high

[EV-002] Type: theoretical
Source: Tennov (1979)...
Claim: "..."
Confidence: high

[EV-003] Type: empirical
Source: Fisher (2016)...
Claim: "..."
Confidence: medium
```
**Scan time:** User must read 5 lines per Evidence Object to understand it. If looking for "Fisher (2016)," must scan 15 lines (3 EV × 5 lines). **Slow.**

**Compact format (Performance proposal):**
```yaml
EV-001: {type: empirical, source: "Wakin & Vo (2008)...", claim: "...", confidence: high}
EV-002: {type: theoretical, source: "Tennov (1979)...", claim: "...", confidence: high}
EV-003: {type: empirical, source: "Fisher (2016)...", claim: "...", confidence: medium}
```
**Scan time:** 3 lines. 5x faster. **Source field is prominent** (easy to spot "Fisher").

**COMPLEMENT Performance with hybrid display:**
- **Editing mode:** 5-line format (human-friendly for writing)
- **Reading mode:** Compact format or table (optimized for scanning)
- **Toggle:** User switches modes based on task

**This is common UX pattern** (Markdown editors show "Edit" and "Preview" modes). Apply to Evidence Objects.

---

### Architectural Purist

#### C1: Tight Coupling Between Citation Format and Storage Layer
**Response Type:** AGREE + UX FLEXIBILITY

**Agreement:** Schema/format separation is good architecture. UX benefit: **Enables multiple presentation formats for different contexts.**

**UX principle:** Present same data differently based on user's context.

**Context 1: Drafting spec (desktop, focused work)**
- Use: 5-line markdown format (spacious, easy to read)
- Screen: Large (24"+ monitor)
- Task: Writing, editing, adding Evidence Objects

**Context 2: Reviewing spec (mobile, commuting)**
- Use: Compact table or cards (space-efficient)
- Screen: Small (6" phone)
- Task: Reading, approving, commenting

**Context 3: Presenting to stakeholders (slide deck)**
- Use: Visual cards with icons (high-level overview)
- Screen: Projector (low resolution, viewed from distance)
- Task: Communicating key evidence, not details

**Without schema separation (Architectural C1), all three contexts use same 5-line format.** Mobile user scrolls excessively. Stakeholder slides are text-heavy.

**With schema separation, each context gets optimized view:**
- Desktop: 5-line markdown
- Mobile: Compact table
- Slides: Visual cards

**This is responsive design for data structures, not just UI.**

**PRIORITY:** Architectural C1 (schema separation) is not just code cleanliness. It's **UX enabler**. Recommend implementing for UX reasons, not just architectural reasons.

---

#### C2: Evidence Object ID Format Violates Single Responsibility
**Response Type:** AGREE + DISPLAY DESIGN

**Agreement:** `[EV-001]` conflates logical ID with display ID. UX perspective: **Display ID should be human-friendly, logical ID should be machine-friendly. Don't make them same thing.**

**Human-friendly ID properties:**
- Short (3-6 chars)
- Sequential (EV-001, EV-002... users understand progression)
- Readable aloud ("E-V-zero-zero-one")

**Machine-friendly ID properties:**
- Collision-resistant (hash or UUID)
- Content-addressable (hash of data)
- Globally unique (not just per-spec)

**These properties are incompatible.** Content hash = 64 chars (not short). Sequential = not collision-resistant.

**Solution: Two-tier ID system**
```
Display ID: [EV-001] (user sees this)
Canonical ID: 7f3e4d2a1b6c (system uses this)
Mapping: Stored in spec frontmatter or metadata
```

**Rendering:**
```markdown
[EV-001] <!-- canonical: 7f3e4d2a1b6c -->
Type: empirical
Source: ...
```

**User sees `[EV-001]` (short, friendly). System uses `7f3e4d2a1b6c` (collision-resistant). Markdown comment preserves mapping.**

**This satisfies Architectural (SRP), Performance (collision check), Security (spoofing prevention), and me (readable).**

---

#### I1: Evidence Object Format Not Versioned
**Response Type:** AGREE + MIGRATION UX

**Agreement:** Versioning needed. UX concern: **Schema migration is painful for users.**

**Bad migration UX:**
```
Error: Evidence Object EV-001 uses schema v1.0. Current schema is v2.0. Update manually.
```
User must:
1. Read v2.0 spec
2. Understand changes
3. Update Evidence Object by hand
4. Repeat for all old Evidence Objects

**Time: 5-10 minutes per Evidence Object.** If user has 50 old Evidence Objects across 10 specs, **8+ hours of manual work.** Unacceptable.

**Good migration UX (automated):**
```
Agent: "Found 5 Evidence Objects using schema v1.0. Migrate to v2.0? [y/n]"
User: "y"
Agent: "Migrating... (1/5) EV-001... ✓"
Agent: "Migrating... (2/5) EV-002... ✓"
...
Agent: "✓ Migration complete. 5/5 Evidence Objects updated. Review changes in git diff."
```

**Time: 30 seconds.** User reviews diff, confirms changes are correct, commits.

**Recommendation:** Architectural's versioning + automated migration tooling. Never ask users to migrate data manually.

---

## Position Changes

### Original Position: CONDITIONAL APPROVE
**New Position:** CONDITIONAL APPROVE (unchanged)

**Reasoning:** Cross-examination strengthened my position:

1. **Security's XSS concern** reinforces my C1 (interactive helper enables automatic sanitization)
2. **Performance's upper bound** aligns with cognitive psychology (7±2 working memory limit)
3. **Architectural's schema separation** enables responsive design (different formats for different contexts)

**My UX concerns are validated by other disciplines.** No position change needed.

**Elevated priorities:**
- Interactive helper: Was "critical," now "BLOCKING" (enables security + UX + performance)
- Schema separation: Was "architectural," now "UX enabler" (responsive design)

---

## New Insights

### 1. Security = UX
XSS vulnerability is not just security issue—it's UX disaster. Trust erosion, data loss, reputation damage all harm user experience. **Security mitigations are UX improvements.**

Reframe to stakeholders: "We're implementing XSS prevention to protect user trust" (UX framing) vs. "We're implementing XSS prevention to prevent code injection" (security framing). Former resonates more with non-technical stakeholders.

---

### 2. Cognitive Load Has Measurable Threshold
Performance's 10 EV upper bound aligns with working memory research (7±2 items). This is not arbitrary constraint—it's **grounded in cognitive science.**

**Recommendation:** Cite cognitive psychology research when justifying upper bounds. "We limit to 10 Evidence Objects based on Miller's Law (1956) regarding working memory capacity" is more persuasive than "10 feels right."

---

### 3. Progressive Disclosure for Latency
Performance's metadata fetching creates 3-10s latency. Can't eliminate, but can make tolerable via progressive disclosure (show validation steps as they complete).

**General UX pattern:** Whenever operation takes >2 seconds, show progress. Users tolerate longer waits if they know system is working.

---

### 4. Schema Separation Enables Responsive Design
Architectural's C1 (schema/format decoupling) enables UX flexibility: Desktop gets verbose format, mobile gets compact, slides get visual. This is **responsive design for data structures**.

**Underappreciated benefit of good architecture:** Enables UX adaptations without data restructuring.

---

### 5. Two-Tier ID System Reconciles Competing Needs
Display ID (short, sequential, human-friendly) + Canonical ID (hash, collision-resistant, machine-friendly) satisfies all reviewers. This pattern generalizes: **When identifier has competing requirements, use two-tier system.**

---

## Revised Scoring

| Dimension | Original | Revised | Change Rationale |
|-----------|----------|---------|------------------|
| **Learnability** | 50/100 | 65/100 | ↑ Interactive helper (my C1) + workflow guidance (my C2) significantly improve learnability |
| **Efficiency** | 55/100 | 70/100 | ↑ Automated confidence (Security R2) + async validation (Performance C2) improve user efficiency |
| **Error Prevention** | 60/100 | 70/100 | ↑ Sanitization feedback + incremental validation (Performance I2) catch errors early |
| **Satisfaction** | 50/100 | 65/100 | ↑ Interactive helper + responsive design (Architectural C1) improve satisfaction |

**Overall UX Score:** 68/100 (was 55/100)
**Risk Level:** MEDIUM (was MEDIUM-HIGH)

**Reasoning for upgrade:** Proposed mitigations from all reviewers address my UX concerns. Interactive helper (my critical request) is validated by Security (sanitization) and Performance (token savings). If implemented, Evidence Objects will be usable.

---

## Agreements

### Security C1 (XSS Risk)
Agree. Add: Security vulnerability is UX disaster (trust erosion). Reframe as UX improvement, not just security hardening.

### Performance C1 (Upper Bound)
Agree + add cognitive psychology justification (7±2 working memory). Upper bound is UX feature, not just performance constraint.

### Performance C2 (Validation Latency)
Agree + complement with async UX (progressive disclosure of validation steps).

### Performance I1 (Format Bloat)
Agree + propose hybrid display (5-line for editing, compact for reading).

### Architectural C1 (Schema Separation)
Agree. Enables responsive design (different formats for desktop/mobile/slides). Reframe as UX enabler.

### Architectural C2 (ID Format SRP)
Agree. Two-tier ID system (display + canonical) satisfies all requirements.

### Architectural I1 (Versioning)
Agree + require automated migration tooling. Never manual migration.

---

## Contradictions

### Security C2 (Confidence Attribution)
**Security says:** Attribution in Evidence Object display (`Confidence: high (assessed by: ...)`).

**I say:** Separate attribution from display. Show attribution in metadata, not main content.

**Reasoning:** Attribution clutters display (60 chars × 10 EV = 600 chars visual bloat). Users who need audit trail can expand metadata. Most users don't need to see who assigned confidence every time they read Evidence Object.

**Resolution:** Display-level attribution for critical compliance contexts (FDA, SOC2). Metadata-level attribution for standard use. Make configurable.

---

## Escalations

### ESCALATE: Interactive Helper (My C1) Is Foundational
**Original classification:** UX CRITICAL
**New classification:** FOUNDATIONAL (blocks all other improvements)

**Rationale:** Interactive helper enables:
- **Security:** Automatic sanitization (Security C1)
- **Performance:** One-time formatting cost, token savings (Performance I1)
- **UX:** Reduces cognitive load by 75% (my C1)

**If interactive helper not built, all three disciplines suffer.** This is not just UX improvement—it's **architectural keystone**.

**Recommendation:** Prioritize interactive helper above all other improvements. Estimated 4 hours effort (my original estimate). Highest ROI feature in entire spec.

---

## Recommendation (Updated)

**CONDITIONAL APPROVE** — Original position maintained, with **escalation of interactive helper to foundational priority.**

**Foundational (blocks other improvements):**
1. **Interactive helper** (my C1) — Enables security + performance + UX benefits. Must be in MVP.

**Critical (required for MVP):**
2. **Evidence Object upper bound** (Performance C1) — 10 max, grounded in cognitive psychology
3. **Workflow guidance** (my C2) — When to add Evidence Objects, how many, which claims need evidence
4. **Confidence rubric** (my I2) — Automated calculation, not manual assessment
5. **Schema separation** (Architectural C1) — Enables responsive design (desktop/mobile/slides formats)

**Important (address before production):**
6. **Async validation UX** (Performance C2 + my complement) — Progressive disclosure of validation steps
7. **Two-tier ID system** (Architectural C2 + my design) — Display ID + canonical ID
8. **Sanitization feedback** (Security C1 + my complement) — Show what was cleaned, not just "rejected"

**Nice-to-have (defer to Phase 2):**
- Hybrid display (5-line editing, compact reading)
- Edit command (rare if creation is good)
- Automated migration tooling (versioning support)

**If foundational + critical items not met:** Evidence Objects are too hard to use. Users will skip them or use incorrectly. Research grounding advantage fails to materialize. Alteri positioning weakens.

**If only foundational item (interactive helper) is built:** Evidence Objects are usable. Other items improve quality but aren't blocking.

**Estimated effort for foundational + critical:**
- Interactive helper: 4 hours
- Upper bound validation: 30 minutes
- Workflow documentation: 1 hour
- Confidence rubric (manual): 1 hour
- Schema separation: 4 hours (Architectural estimate)
**Total: ~11 hours**

**Estimated user impact if shipped with foundational + critical:**
- Evidence Object creation time: 30 seconds (was 2 minutes manual)
- Drafting time per spec: 5 minutes for 5 EV (was 20 minutes)
- Error rate: <10% (was ~40% format errors)
- Cognitive load: Low (interactive, guided)
- Adoption likelihood: High (tool does formatting, user provides data)

**This is strong MVP.** Remaining items are polish, not prerequisites.

---

## Metadata

**Cross-Examination Duration:** 45 minutes
**Reviews Consulted:** Security Skeptic, Performance Pragmatist, Architectural Purist (all Round 1)
**Position Changed:** No (CONDITIONAL APPROVE maintained)
**Score Changed:** Yes (55→68, upgrade due to validated mitigations)
**Escalations:** 1 (Interactive helper to foundational)
**Agreements:** 7 | Contradictions: 1 | Complements: 4
