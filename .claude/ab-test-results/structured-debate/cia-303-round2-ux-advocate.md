# Round 2: UX Advocate Cross-Examination — CIA-303

**Reviewer:** UX Advocate (Green)
**Round:** 2 (Cross-Examination)
**Date:** 2026-02-15

---

## Responses to Security Skeptic

### SS-C1: HTML Parsing Attack Surface
**Response: SCOPE**
Injection vectors are genuine security concern but don't degrade UX unless exploited. Security hardening should happen in implementation, not block the spec.

### SS-C2: Insights Archive Poisoning
**Response: SCOPE**
HMAC signing is implementation detail. Users trust the filesystem -- if attacker has write access, they already own the session. Spec correctly focuses on legitimate data quality.

### SS-C3: Dynamic Threshold Manipulation
**Response: AGREE**
Genuinely critical from UX perspective. If attacker can train system to lower thresholds, legitimate users experience degraded guidance. Hard caps (never >2x default) directly protect UX quality. Elevating to own findings.

### SS-C4: No Authentication on /sdd:insights
**Response: SCOPE**
Path sanitization is security implementation concern. UX impact minimal -- attacker already has repo access.

### SS-I1: Secrets in Tool Parameters
**Response: COMPLEMENT**
UX blind spot missed in Round 1: if insights logging captures API keys, users lose trust in the system. Even perception that "Claude is logging my secrets" destroys adoption. Redaction essential for user confidence.

### SS-I2: Drift Detection False Positives
**Response: CONTRADICT**
"Never weaken, only tighten" would make system progressively unusable -- legitimate outlier projects hit false positives indefinitely. UX failure mode is rigidity, not escalation. Drift detection should adapt bidirectionally with hard caps.

### SS-I3: References/ as Reconnaissance
**Response: SCOPE**
Theoretical attack vector with no UX impact. Revealing aspirational vs enforced methodology is transparency, not vulnerability.

### SS-I4: No Rate Limiting
**Response: PRIORITY**
Agree on finding, disagree on severity. If rate limiting is added, must be high enough to be invisible to normal users (e.g., 100/minute, not 10).

---

## Responses to Performance Pragmatist

### PP-C1: HTML Parsing as Primary Path
**Response: AGREE**
O(n) overhead + no caching = laggy responses, degrading "instant feedback" UX promise. Session-scoped cache essential.

### PP-C2: References/ Unbounded
**Response: AGREE**
10K correlation records impacts UX -- insights queries timeout, adaptive thresholds fail to compute, users see stale guidance. Should have been in Round 1 Critical list.

### PP-C3: Adaptive Threshold Recomputation
**Response: AGREE**
50 queries/session = 2-5 second latency per insights call. Violates sub-second feedback UX requirement. Session-start pre-computation is correct fix.

### PP-C4: Retrospective Query Explosion
**Response: COMPLEMENT**
If retrospectives take 30+ seconds (Linear API joins without indexes), users abandon the command. Local SQLite index is a must. Adding to revised findings.

### PP-I1: No Quality Score Budget
**Response: AGREE**
Timeout = partial or stale quality scores. Sampling preserves UX insight while avoiding timeout failure mode.

### PP-I2: Schema-Less Archive
**Response: PRIORITY**
Agree on finding, disagree on severity. Schema changes infrequent; UX impact limited to version migration pain. Important, not Critical.

### PP-I3: Hook Trigger Mismatch
**Response: AGREE**
Mismatch = broken mental model. Trivial to fix, high UX impact.

### PP-I4: PreToolUse Stub
**Response: AGREE**
Only proactive guidance point. Stub = broken feedback loop.

---

## Responses to Architectural Purist

### AP-C1: Boundary Violation
**Response: CONTRADICT**
3-component split (collector/policy-engine/registry) adds architectural purity at cost of UX complexity. Users see `/sdd:insights` as unified interface -- splitting into 3 tools fragments mental model. Current design is discoverable. Over-engineering trades clarity for correctness.

### AP-C2: Circuit Breaker No Owner
**Response: ESCALATE**
Genuine ownership gap with severe UX consequences. If circuit breaker auto-escalates to execution-modes skill with no spec defining handoff, users experience ghost behavior. Requires human decision: should circuit-breaker-post.sh invoke execution-modes or just recommend it?

### AP-C3: Drift Thresholds Fragmented
**Response: AGREE**
Fragmented config = users can't reason about why thresholds changed. Single source of truth improves trust and debuggability.

### AP-I1: Quality Score vs Ownership
**Response: AGREE**
"Eligibility != authorization" is critical UX distinction missed in Round 1. Users see confusing rejections when quality score alone doesn't determine outcomes. Precedence must be explicit.

### AP-I2: PreToolUse Stub
**Response: AGREE**
Duplicate of Round 1 finding. Broken feedback loop.

### AP-I3: Naming Inconsistency
**Response: PRIORITY**
Agree on finding, disagree on severity. Creates minor doc confusion, doesn't block users. Important, not Critical.

---

## Position Changes from Round 1

1. **Elevating SS-C3 (Dynamic Threshold Manipulation) to Critical**: Hard caps on adaptive thresholds directly protect UX from degradation.
2. **Elevating PP-C2 (References/ Unbounded) to Critical**: 10K records = query timeouts = broken insights.
3. **Adding PP-C4 (Retrospective Query Explosion) as Critical**: 30-second Linear API joins make retrospectives unusable.
4. **Softening on AP-C1 (Boundary Violation)**: Unified insights interface is more discoverable. Over-engineering would fragment UX.
5. **Escalating AP-C2 (Circuit Breaker Ownership) to Human Decision**: Critical handoff undefined -- needs Cian's input.

## New Insights from Cross-Examination

1. **Secrets Logging destroys trust** (SS-I1): Even perception that insights capture secrets undermines adoption. Redaction is foundational.
2. **Latency kills feedback loops** (PP findings): Every performance finding is also a UX finding. Should have led with this framing in Round 1.
3. **Architectural complexity can harm discoverability** (AP-C1): UX sometimes favors pragmatic coupling over clean separation.
4. **Ownership gaps = ghost behavior** (AP-C2): Pattern of "spec defines behavior, doesn't define owner" recurs across multiple findings.

**Revised Overall Score: 2.0/5 (down from 2.4/5, REVISE)**

**Revised Critical Issues (8 total):**
1. HTML parsing overhead (PP-C1)
2. References/ unbounded growth (PP-C2)
3. Adaptive threshold recomputation cost (PP-C3)
4. Retrospective query explosion (PP-C4)
5. Dynamic threshold manipulation (SS-C3)
6. Circuit breaker ownership gap (AP-C2) -- ESCALATE
7. Drift threshold fragmentation (AP-C3)
8. Secrets in tool parameters (SS-I1)
