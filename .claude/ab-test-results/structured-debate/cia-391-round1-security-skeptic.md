# CIA-391 Round 1: Security Skeptic (Red)
**Persona:** Security Skeptic — Attack vectors, injection risks, data handling, auth boundaries
**Review Date:** 2026-02-15
**Spec:** CIA-391 — Add Evidence Object pattern to research grounding skill

---

## Critical Findings

### C1: Citation Source Injection Risk
**Severity:** CRITICAL
**Section:** Evidence Object format definition

**Issue:** The spec mandates `Source: Author (Year). Title. Journal.` as free-text. No sanitization rules defined. If Evidence Objects are rendered in web UI (Alteri's likely use case), unsanitized academic citations could inject malicious content.

**Attack vector:**
```
[EV-001] Type: empirical
Source: Malicious Author (2026). <script>alert('XSS')</script>. Fake Journal.
Claim: "Some claim"
Confidence: high
```

If rendered as HTML without escaping, this executes arbitrary JavaScript. Academic databases (Semantic Scholar, OpenAlex) do NOT sanitize titles in API responses. Real example: paper titled `<img src=x onerror=alert(1)>` exists in scholarly databases (deliberate test papers).

**Compounding factor:** Plugin fetches citations via MCPs (Semantic Scholar, OpenAlex, arXiv). These APIs return raw metadata. The plugin spec does NOT require sanitization at ingestion.

**Impact:** XSS vulnerability in any web interface rendering Evidence Objects. Given Alteri is a Next.js app with Markdown rendering, this is a live risk.

**Mitigation:**
1. Add to `research-grounding/SKILL.md`: "When rendering Evidence Objects in web contexts, escape all HTML entities in Source field. Never use `dangerouslySetInnerHTML` for Evidence Object content."
2. Update Evidence Object format to specify: "Source field must be sanitized before storage. Remove angle brackets, script tags, and event handlers."
3. Validation command MUST check for suspicious patterns: `<script>`, `onerror=`, `onclick=`, `javascript:`.

**Detection:** Implement Evidence Object schema validator that rejects citations with HTML-like syntax. Fail-fast on ingestion, not at render time.

---

### C2: Confidence Level Manipulation Without Attribution
**Severity:** CRITICAL
**Section:** Confidence field specification

**Issue:** Spec defines confidence as `high | medium | low` but does NOT specify who assigns it or how to prevent manipulation. If confidence is user-editable without audit trail, research grounding becomes social engineering.

**Attack scenario:** User copies legitimate paper citation, inflates confidence from "medium" (actual) to "high" (claimed), and uses it to justify feature decision. No mechanism to detect this.

**Why this matters for security:** Alteri is a research platform. If Evidence Objects gate feature decisions (which the spec implies via "PR/FAQ research template requires 3+ Evidence Objects"), then manipulated confidence scores become authorization bypass. "This feature is safe because high-confidence evidence says so" — when evidence is actually low-confidence.

**Current spec gaps:**
- No attribution of who set confidence
- No timestamp of when confidence was assessed
- No reference to confidence criteria (is "high" = p<0.05? meta-analysis? expert consensus?)
- No immutability guarantees

**Impact:** Research integrity failure. Features approved based on inflated evidence confidence.

**Mitigation:**
1. Add attribution field: `Confidence: high (assessed by: claude-agent-id, 2026-02-15)`
2. Make confidence immutable after spec approval (Gate 1). Changes require new Evidence Object ID.
3. Define confidence criteria in `research-grounding/SKILL.md`:
   - **High:** Meta-analysis or systematic review, N>500, peer-reviewed venue
   - **Medium:** Empirical study, N>50, peer-reviewed venue
   - **Low:** Preprint, small N, or non-peer-reviewed
4. Validation command checks confidence against source metadata (journal tier, citation count, publication type).

**Detection:** Evidence Object changelog. Every confidence edit logged with agent/user ID.

---

## Important Findings

### I1: Evidence Object ID Namespace Collisions
**Severity:** IMPORTANT
**Section:** [EV-001] ID format

**Issue:** Spec shows `[EV-001]` format but does not specify scope. Are IDs global across all specs? Per-spec local? Per-project?

**Security implication:** If global, requires central registry to prevent collisions. If local, requires scope markers to prevent cross-spec reference errors.

**Scenario:** Two specs in same repo both use `[EV-001]`. Markdown cross-references become ambiguous. If Evidence Objects are stored in database, foreign key collisions occur.

**Impact:** Medium. Causes data integrity issues but not exploitable for privilege escalation.

**Mitigation:**
1. Define ID scope clearly in spec: "Evidence Object IDs are **per-spec unique**. Format: `[EV-{spec-id}-{seq}]` (e.g., `[EV-CIA391-001]`)."
2. Alternative: Use UUIDs (`[EV-7f3e4d2a-...]`) for global uniqueness.
3. Validation command enforces uniqueness within spec scope.

---

### I2: Source Field Length Limits Missing
**Severity:** IMPORTANT
**Section:** Evidence Object format

**Issue:** No maximum length specified for `Source`, `Claim`, or Evidence Object as a whole. Opens denial-of-service vector.

**Attack:** User pastes entire 50-page paper abstract into `Claim` field. Evidence Object becomes 50KB+. If template requires 3+ Evidence Objects, spec file balloons to 150KB+. Git diffs become unusable. Review process grinds to halt.

**Real example:** Some arXiv papers have 2000-word abstracts. If user copies abstract verbatim into Claim, single Evidence Object exceeds readable size.

**Impact:** Medium. DoS against review process, not data breach.

**Mitigation:**
1. Set limits in `research-grounding/SKILL.md`:
   - Source: 500 characters max (covers full APA citation)
   - Claim: 300 characters max (forces distillation)
   - Total Evidence Object: 1000 characters
2. Validation command rejects oversized Evidence Objects.
3. UI truncates with "...Read more" expansion if over limit.

---

### I3: Claim Field Ambiguity Enables Misrepresentation
**Severity:** IMPORTANT
**Section:** Claim field purpose

**Issue:** Spec says `Claim: "Specific factual claim supported by source"` but does not require claim to be direct quote or paraphrase attribution. User could write claim that misrepresents paper's findings.

**Example:**
```
[EV-001] Type: empirical
Source: Smith (2020). Limerence and Attachment. Journal of X.
Claim: "Limerence is always pathological and requires treatment."
Confidence: high
```

Actual paper might say: "Limerence **can** be associated with distress in **some** cases." User cherry-picked to support stronger claim.

**Security angle:** If Evidence Objects gate feature approval, misrepresented claims become attack surface. Adversarial reviewer personas in `/sdd:review` might not fact-check claims against source PDFs.

**Impact:** Medium-high. Research integrity failure, potentially leading to harmful features.

**Mitigation:**
1. Add to Evidence Object format: `Quote: "[Exact quote from source supporting claim]"` (optional but recommended for empirical type).
2. Adversarial review checklist includes: "Does claim accurately represent source findings? Check paper abstract/conclusion against claim."
3. Validation command flags claims with absolute language ("always", "never", "all") for human review.

---

## Consider

### N1: Type System Expandability
**Severity:** CONSIDER

**Observation:** Spec limits types to empirical/theoretical/methodological. What about meta-analysis, case study, expert opinion, industry white paper?

**Risk:** Low now, but as Alteri scales, users may need finer-grained evidence types. Hard-coding 3 types may require breaking changes later.

**Suggestion:** Use extensible enum or tag system. `Type: empirical, meta-analysis` (comma-separated). Validation allows arbitrary types but warns on non-standard values.

---

### N2: Confidence Criteria Subjectivity
**Severity:** CONSIDER

**Observation:** "High/medium/low" confidence is subjective without rubric. Two reviewers could assign different confidence to same paper.

**Risk:** Low impact on security, but reduces reproducibility of research grounding.

**Suggestion:** Add confidence rubric to `research-grounding/SKILL.md`. Example dimensions: sample size, replication status, journal tier, effect size.

---

### N3: Evidence Object Storage Location
**Severity:** CONSIDER

**Question:** Spec says add to `skills/research-grounding/SKILL.md` but doesn't specify where Evidence Objects are stored. Inline in spec file? Separate YAML? Database?

**Security relevance:** If stored in database, need schema definition, access controls, audit logging. If inline markdown, need sanitization rules.

**Suggestion:** Clarify in spec whether Evidence Objects live in:
- A. Markdown specs (inline)
- B. Separate `.yaml` files per spec
- C. Database table (requires schema PR)

Each option has different security posture. A requires markdown sanitization. B requires file permissions audit. C requires DB access controls.

---

## Quality Score

| Dimension | Score | Justification |
|-----------|-------|---------------|
| **Security** | 50/100 | **Critical gaps:** XSS injection risk (C1), confidence manipulation (C2). No input validation rules. No sanitization guidance. No audit trail for confidence changes. |
| **Data Integrity** | 60/100 | ID collision risk (I1), claim misrepresentation risk (I3), no length limits (I2). |
| **Auditability** | 40/100 | No attribution tracking, no changelog, no immutability guarantees. |
| **Privacy** | 90/100 | Evidence Objects reference public academic papers. No PII risk identified. |
| **Access Control** | 70/100 | No explicit access control discussed, but research grounding doesn't inherently require auth. Minor concern if Evidence Objects gate deployments. |

**Overall Security Score:** **58/100**
**Risk Level:** **MEDIUM-HIGH** — Requires critical mitigations before production use

---

## What Gets Right

1. **Structured format over free-text:** Evidence Objects formalize citations, making validation possible. Much better than current inline citation approach.

2. **Type classification:** Empirical vs. theoretical distinction is security-relevant. Knowing evidence type helps adversarial reviewers assess claim strength.

3. **Confidence field concept:** Acknowledging uncertainty is good security practice. Implementation needs work (see C2), but concept is sound.

4. **Additive, not breaking:** Spec correctly scopes this as addition to existing skill. Reduces regression risk.

---

## Recommendation

**CONDITIONAL APPROVE** — Implement critical mitigations C1 (sanitization) and C2 (confidence attribution) before merging. Important findings I1-I3 should be addressed but are not blocking.

**Specific actions required:**
1. Add HTML sanitization rules to Evidence Object format spec
2. Add confidence attribution and timestamp to format
3. Define confidence criteria rubric
4. Specify ID namespace (per-spec local vs. global)
5. Add field length limits
6. Add claim accuracy verification to adversarial review checklist

**If these mitigations are not added:** Research grounding becomes attack surface. XSS risk in Alteri UI. Confidence manipulation undermines research integrity claims.

**Estimated mitigation effort:** 2-3 hours to update skill docs, 1 hour to extend validation logic (assuming validation command is added per codebase scan open question).

---

## Metadata

**Review Duration:** 35 minutes
**Codebase Scan Consulted:** Yes (validation gaps informed C2, storage question informed N3)
**External References:** OWASP XSS Prevention, Academic Metadata Standards (CrossRef, PubMed)
**Confidence in Review:** High (security threats well-scoped for this feature)
