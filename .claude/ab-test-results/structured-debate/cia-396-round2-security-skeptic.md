# Round 2 Review — Security Skeptic (Red)

**Spec:** CIA-396 — Prototype tool capture hooks for spec conformance
**Reviewer:** Security Skeptic
**Date:** 2026-02-15
**Context:** Cross-examination after reading Performance Pragmatist, Architectural Purist, and UX Advocate Round 1 reviews

---

## Responses to Other Personas

### Performance Pragmatist Findings

#### PP-C1: Unbounded Latency on Every Write Operation

**AGREE**

The performance concern is valid AND has security implications. If the hook is slow, users will disable it or set aggressive timeouts, which defeats the security purpose. A security control that is disabled because it's too slow is not a security control.

**Additional security angle:** Timeout handling is itself a security concern. If the hook times out mid-check, does it:
- Fail open (allow write)? → Security bypass
- Fail closed (block write)? → Denial of service

This needs to be specified.

---

#### PP-C2: Spec Parsing on Hot Path

**AGREE**

Caching the parsed spec at SessionStart is correct from both performance and security perspectives. HOWEVER, Performance Pragmatist did not address cache invalidation attacks:

If an attacker can trigger spec cache invalidation (e.g., by touching the spec file's mtime), they could force expensive re-parsing on every write, creating a DoS condition.

**Recommendation:** Cache validation should check file hash, not just mtime. Or lock the cache for the session duration.

---

#### PP-I1: False Positive Measurement is O(n²)

**COMPLEMENT**

The O(n²) complexity makes false positive measurement not just slow, but also creates an attack surface: if an attacker can influence the test sample (e.g., by submitting malicious issues to the 10-issue sample), they could craft pathological cases that make measurement infeasibly slow, preventing adoption.

**Security mitigation:** Test sample should be curated by trusted maintainers, not sourced from untrusted contributors.

---

### Architectural Purist Findings

#### AP-C1: Blurs Hook Responsibilities

**CONTRADICT**

I initially agreed that conformance checking should be a separate hook, but after reading Architectural Purist's argument, I see a security counterargument:

If conformance checking is a SEPARATE hook, users can disable it independently. This creates a security risk: users might disable conformance (because it's noisy) while keeping ownership enforcement (because it's critical). The result is drift without detection.

**Alternative:** Keep conformance checking in the SAME hook as ownership enforcement, but make it togglable via environment variable:
```bash
SDD_CONFORMANCE_ENABLED=true
```

This makes the tradeoff explicit: you get ownership enforcement AND conformance, or neither.

---

#### AP-C2: Tight Coupling to Spec Format

**AGREE**

Tight coupling to markdown creates a security risk: if the markdown parser has vulnerabilities (e.g., ReDoS in regex, or injection via malformed markdown), the hook becomes an attack vector.

**Stronger mitigation than proposed:** Use a sandboxed parser (run in a separate process with restricted permissions) rather than trusting markdown parsing libraries.

---

#### AP-C3: No Conformance Matching Contract

**AGREE**

The lack of a defined matching contract is both an architectural AND security problem. If "compared against" is undefined, implementers will make unsafe choices:
- Naive regex matching → ReDoS attacks
- Eval-based matching → code injection
- Semantic matching via LLM → prompt injection

The contract MUST specify: "Matching is done via safe substring search only, no regex or eval."

---

### UX Advocate Findings

#### UX-C1: Invisible Feedback Loop

**PRIORITY**

UX Advocate is right that users need feedback, but I disagree on the severity. From a security perspective, silent logging is SAFER than inline feedback:

If conformance results are surfaced to the agent inline, a malicious agent could use that feedback to learn the conformance logic and craft adversarial writes that pass checks while implementing malicious behavior.

**Security-conscious UX:** Provide feedback to HUMANS (post-session audit), but NOT to agents (inline). This prevents adversarial learning.

---

#### UX-C2: No Error Recovery Path

**AGREE**

UX Advocate's proposed error message format is good, but needs a security constraint:

```
[SDD Conformance] ERROR: Could not parse spec at .sdd-spec.md
Reason: Markdown parsing failed at line 42
```

The "line 42" disclosure reveals internal state that could aid an attacker in crafting a spec that causes specific parser failures. Error messages should be INFORMATIVE to legitimate users but NOT leak exploitable details.

**Recommendation:** Log detailed errors to a secure audit log (owner-read-only), surface generic errors to users.

---

#### UX-C3: False Positive Punishment

**COMPLEMENT**

False positives are not just a UX problem, they're a security problem: if users learn to ignore warnings due to alert fatigue, they'll also ignore TRUE positives (real drift). This is a classic security failure mode.

The 10% false positive threshold is too high from a security perspective. For security-critical criteria, the threshold should be <1%.

**Recommendation:** Allow per-criterion false positive thresholds. Security-critical criteria (e.g., "Implement authentication") have strict thresholds, non-critical criteria have relaxed thresholds.

---

## Position Changes from Round 1

### Changed: Separate Hook Recommendation

**Round 1:** I implicitly assumed conformance checking should extend the existing PostToolUse hook.

**Round 2:** After Architectural Purist's argument, I see the separation-of-concerns benefit. HOWEVER, I now believe the separation should be LOGICAL (separate code paths) but not CONFIGURATIONAL (user cannot disable one without the other, for security reasons).

---

### Strengthened: Timeout Handling

**Round 1:** I did not consider timeout handling.

**Round 2:** Performance Pragmatist's latency concern makes timeout handling a critical security requirement. Fail-open is a security bypass, fail-closed is a DoS. The spec MUST define timeout behavior.

---

### New: Adversarial Learning Risk

**Round 1:** I did not consider feedback-based adversarial learning.

**Round 2:** UX Advocate's inline feedback proposal creates a new attack vector: agents could use conformance feedback to iteratively craft malicious writes that pass checks. Feedback should be post-session only.

---

## New Insights from Cross-Examination

### Insight 1: Performance and Security are Coupled

Performance concerns are not just about latency — they affect security posture:
- Slow hooks get disabled → security controls bypassed
- Timeouts create fail-open/fail-closed dilemma → security tradeoff
- O(n²) measurement creates DoS attack surface → availability risk

Security review must consider performance as a security requirement, not just a UX requirement.

---

### Insight 2: False Positive Threshold is Context-Dependent

The 10% threshold is too blunt. Different criteria have different security criticality:
- "Implement authentication" — 1% FP threshold (high criticality)
- "Update documentation" — 20% FP threshold (low criticality)

The spec should allow per-criterion thresholds, not a global 10%.

---

### Insight 3: Feedback Design is a Security Control

How and when feedback is provided affects adversarial learning:
- Inline feedback → agent learns conformance logic → crafts adversarial writes
- Post-session feedback → agent cannot adapt → safer

UX and security have conflicting goals here. The spec must choose: optimize for agent UX or security?

---

## Revised Score

| Dimension | Round 1 | Round 2 | Change | Rationale |
|-----------|---------|---------|--------|-----------|
| **Security** | 2 | 1 | -1 | Adversarial learning risk, timeout handling, and false positive threshold issues are more severe than initially assessed |
| **Robustness** | 3 | 2 | -1 | Timeout and cache invalidation attacks are critical gaps |
| **Clarity** | 4 | 4 | 0 | Still clear, but now clear that security implications are underspecified |
| **Testability** | 4 | 3 | -1 | Testing false positives with 10-issue sample is insufficient for security validation |
| **Completeness** | 2 | 1 | -1 | Missing timeout behavior, adversarial learning mitigation, per-criterion thresholds |

**Overall:** 3.0 → **2.2 / 5.0** (decreased)

---

## Recommendation

**RETHINK** (escalated from REVISE)

After cross-examination, I am more skeptical than in Round 1. The security gaps are deeper than initially apparent:

1. **Timeout handling is undefined** — fail-open is a bypass, fail-closed is a DoS
2. **Adversarial learning via feedback** — inline feedback teaches agents how to evade detection
3. **Performance-induced security bypass** — slow hooks get disabled, defeating the purpose
4. **False positive threshold too high** — 10% causes alert fatigue and missed real drift

**Critical additions:**
- Define timeout behavior (fail soft with logging)
- Restrict feedback to post-session audit (no inline agent feedback)
- Add per-criterion false positive thresholds
- Add cache invalidation protection

**Fundamental question:** Is write-time conformance checking the right approach? If performance makes it unusable, and security requires post-session-only feedback, maybe session-boundary checking (like existing `/sdd:anchor`) is the better architecture.
