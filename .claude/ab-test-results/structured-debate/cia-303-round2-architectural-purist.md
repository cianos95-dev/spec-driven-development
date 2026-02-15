# Round 2: Architectural Purist Cross-Examination — CIA-303

**Reviewer:** Architectural Purist (Blue)
**Round:** 2 (Cross-Examination)
**Date:** 2026-02-15

---

## Responses to Security Skeptic

### SS-C1: HTML Parsing Attack Surface
**Response: CONTRADICT**
Spec states insights are extracted from execution records (system-generated), not user-provided content. If there's an injection vector, it's in the tool execution layer (out of scope). However, if insights are displayed via `/sdd:insights`, XSS becomes relevant but that's a UI concern, not architectural.

### SS-C2: Insights Archive Poisoning
**Response: AGREE**
Boundary violation concern. Insights archive sits outside the monorepo boundary with no authentication or integrity verification. An attacker with filesystem access can inject malformed JSON to manipulate adaptive behavior. Violates the principle that external state requires explicit validation gates.

### SS-C3: Dynamic Threshold Manipulation
**Response: COMPLEMENT**
Extends C3 finding (drift thresholds fragmented). Lack of unified threshold manager means attacker could train individual signals independently. Adaptive behavior requires a **monotonic safety property**: thresholds can only tighten, never loosen, without explicit human approval. Spec lacks this invariant.

### SS-C4: No Authentication on /sdd:insights
**Response: PRIORITY**
Valid but severity downgrade. Spec describes insights as project-scoped within authenticated session context. If `/sdd:insights` is a CLI command, it inherits filesystem permissions. This is implementation detail, not architectural flaw.

### SS-I1: Secrets in Tool Parameters
**Response: AGREE**
Tool parameters are first-class data in insights schema. If API keys are passed as parameters, they'll be persisted. Requires sanitization layer at boundary between execution records and insights storage.

### SS-I2: Drift Detection False Positives
**Response: SCOPE**
Behavioral security concern (ML adversarial robustness), not architectural. Spec's responsibility is to define drift signal interface, not guarantee immunity to adversarial training. However, lack of quarantine mechanism is an architectural gap.

### SS-I3: References/ as Reconnaissance
**Response: PRIORITY**
Valid but not actionable at this layer. If attacker has read access to observe references, they also have direct access to methodology files. Filesystem ACL concern, not spec architecture issue. Downgrade to Minor.

### SS-I4: No Rate Limiting
**Response: PRIORITY**
Agree but responsibility ambiguous. If insights extraction triggered by PostToolUse hooks, rate limiting belongs in hook manager, not insights component. Spec should clarify interface contract.

---

## Responses to Performance Pragmatist

### PP-C1: HTML Parsing as Primary Path
**Response: COMPLEMENT**
Reinforces C1 finding (monitoring should not be primary execution path). HTML parsing is O(n) with no caching. Spec should mandate event bus (PostToolUse emits structured JSON) with HTML parsing as fallback for legacy compatibility.

### PP-C2: References/ Unbounded
**Response: AGREE**
Resource management failure. No retention policy means unbounded storage and O(n^2) query cost. Requires sliding window and compaction strategy. Elevate to Critical.

### PP-C3: Adaptive Threshold Recomputation
**Response: AGREE**
50 insights queries/session from PostToolUse hooks with no caching is a performance boundary violation. Spec should mandate rate-limited recomputation with cached values served between updates.

### PP-C4: Retrospective Query Explosion
**Response: COMPLEMENT**
Extends Linear API boundary concern. Requires materialized view -- local cache of Linear issue states updated incrementally, not queried on-demand. Without this, fundamentally unscalable.

### PP-I1: No Quality Score Budget
**Response: AGREE**
Coverage calculation iterates all spec elements with no complexity bound. Should state: "Quality score computation MUST complete within T seconds or return partial score."

### PP-I2: Schema-Less Archive
**Response: CONTRADICT**
Spec describes a JSON schema (timestamp, tool, outcome, context). Concern about "arbitrary changes" is schema evolution, an implementation detail. However, lack of version field is a gap -- elevate to Important.

### PP-I3: Hook Trigger Mismatch
**Response: AGREE**
Precedence ambiguity flagged in C3. System behavior is non-deterministic depending on which threshold is checked first.

### PP-I4: PreToolUse Stub
**Response: AGREE**
Dead interface creates maintenance debt. Spec should either provide concrete use case or remove the hook.

---

## Responses to UX Advocate

### UX-C1: Circuit breaker auto-escalation
**Response: PRIORITY**
Severity depends on interpretation. If "escalate" means "prompt user to switch" -- correct behavior. If "silently override user's mode selection" -- Critical authority violation. Spec is ambiguous. Require clarification: "Adaptive mode transitions MUST present user with justification and confirmation prompt."

### UX-C2: Dual drift signals
**Response: COMPLEMENT**
Reinforces C3 (drift thresholds fragmented). Two independent components compute drift signals without unified observability layer. Spec should mandate DriftCoordinator component that aggregates signals.

### UX-C3: Quality vs ownership invisible
**Response: AGREE**
Spec provides no user-facing explanation mechanism. Requires justification trace: when issue doesn't auto-close despite high quality, emit structured reason.

### UX-C4: 4 modes no guidance
**Response: SCOPE**
Documentation gap, not architectural flaw. Spec should state computational cost of each mode so users make informed choices.

### UX-C5: No schema version
**Response: AGREE**
Forward compatibility failure. Every serialized format crossing system boundary must include version identifier.

### UX-I1: PreToolUse blocks without guidance
**Response: AGREE**
PreToolUse should return structured validation result with actionable fix suggestions. Contract completeness issue.

### UX-I2: Invisible threshold changes
**Response: AGREE**
No change audit log. Requires ThresholdChangeEvent emitted to audit log with justification. Accountability requirement.

### UX-I3: Retrospective scope undefined
**Response: AGREE**
Capability boundary failure. Spec should enumerate allowed and prohibited actions. Without this, component authority is unbounded.

### UX-I4: References/ hidden from user
**Response: AGREE**
If metric isn't exposed, it can't drive user behavior. Feedback loop incompleteness.

---

## Position Changes from Round 1

1. **C2 (Circuit Breaker No Owner) -> Escalated to Critical.** Cross-examination revealed circuit breaker logic distributed across 3 components with no coordinator. Worse than initially assessed.

2. **I1 (Quality Score vs Ownership) -> Elevated to Critical.** UX-C3 reveals this isn't just precedence ambiguity -- it's a silent failure mode. Violates principle that system decisions must be auditable.

3. **I3 (Naming Inconsistency) -> Downgraded to Minor.** Cosmetic compared to deeper architectural flaws.

## New Insights from Cross-Examination

1. **Adaptive Behavior as Attack Surface** (from SS): Adaptive thresholds require monotonic safety invariant -- can only tighten without human approval.
2. **Performance Boundaries as First-Class Architecture** (from PP): Resource boundaries (cache layers, rate limits, retention) are architectural requirements, not implementation details.
3. **Observability as Cross-Cutting Concern** (from UX): Every stateful decision must emit justification trace. Spec describes computations but not their observability.
4. **"Retrospective Automation" Pandora's Box** (from UX-I3): Adding autonomous agent capability without defining scope or authority is a fundamental architectural mistake.

**Revised Overall Score: 1.8/5 (down from 2.6/5)**

**Revised Recommendation: MAJOR REVISION REQUIRED.** Spec attempts to be three things (monitoring system, adaptive safety system, autonomous agent) with different boundary requirements. Path forward: split into three specs.
