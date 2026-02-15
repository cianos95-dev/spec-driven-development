# Structured Debate Synthesis — CIA-396

**Spec:** Prototype tool capture hooks for spec conformance
**Date:** 2026-02-15
**Participants:** Security Skeptic (Red), Performance Pragmatist (Orange), Architectural Purist (Blue), UX Advocate (Green)

---

## Executive Summary

Four reviewers conducted independent analysis followed by cross-examination of CIA-396. The spec proposes a PostToolUse hook that compares file changes against active spec acceptance criteria to detect drift at write-time. All reviewers identified critical gaps but disagreed on architecture: Performance Pragmatist advocates for batch processing at session end (efficiency), while UX Advocate insists on real-time availability (usability). Architectural Purist escalated this as a product decision requiring human input. Consensus emerged on four requirements: cached spec parsing, pull-model feedback (query command), suppression mechanism for false positives, and minimal prototype scope. The debate revealed that per-write checking creates unacceptable latency (2-10 seconds per session), adversarial learning risks, and cognitive overload. Recommendation: REVISE with asynchronous architecture (log writes, check later) and pull-model feedback.

---

## Codebase Context

The repository already has PostToolUse hook infrastructure (`hooks/post-tool-use.sh`) with ownership enforcement (protected branch detection, uncommitted file counting) and a circuit breaker for error loop detection (`hooks/scripts/circuit-breaker-post.sh`). The spec proposes EXTENDING this with spec conformance checking. However, codebase scan revealed:

**Existing capabilities:**
- Tool I/O parsing patterns (jq-based JSON extraction)
- State file patterns (`.sdd-circuit-breaker.json`)
- Git integration primitives (`git diff`, `git status`)
- Environment variable configuration (`SDD_SPEC_PATH`, `SDD_STRICT_MODE`)

**Missing capabilities:**
- Spec parsing (markdown to acceptance criteria extraction)
- Acceptance criteria matching against file changes
- False positive rate measurement
- Test harness for 10-issue sample validation

**Related skills:**
- `drift-prevention` skill provides REACTIVE session-boundary anchoring via `/sdd:anchor`
- `hook-enforcement` skill documents hook patterns but does not implement conformance checking
- Competitive analysis shows drift detection as a HIGH-PRIORITY gap (gmickel/flow-next has re-anchoring, cc-spec-driven has runtime hook enforcement)

---

## Reconciled Findings

### UNANIMOUS (4/4 Agreement)

| Finding | Severity | Personas | Summary |
|---------|----------|----------|---------|
| **Spec parsing must be cached** | HIGH | All | Parsing 500-line markdown on every write adds 50-500ms latency. Cache at SessionStart, read from cache in PostToolUse. Security Skeptic warns: validate cache against hash, not mtime (invalidation attacks). |
| **No conformance matching algorithm defined** | HIGH | AP, SS, PP, UX | "Compared against" is undefined. Without specifying keyword search, regex, or semantic matching, performance and security are unknowable. Consensus: use keyword substring matching for prototype. |
| **False positive threshold needs tuning** | MEDIUM | All | 10% is too high (alert fatigue). UX and PP recommend <5%. SS recommends per-criterion thresholds (1% for security-critical, 20% for docs). |
| **10-issue sample is necessary** | MEDIUM | All | Empirical validation before adoption is the right approach. All reviewers endorse this gate. |

---

### MAJORITY (3/4 Agreement)

| Finding | Severity | Personas (Y/N) | Summary |
|---------|----------|----------------|---------|
| **Separate hook for conformance checking** | HIGH | AP, PP (+), SS (-), UX (-) | AP and PP argue for separation of concerns. SS argues bundling prevents selective disabling (security risk). UX argues separation adds configuration complexity. **Resolution:** Logically separate code, but configure together. |
| **Fail-soft error handling** | MEDIUM | PP, UX, AP (+), SS (-) | Log error, allow write, warn user. SS concerned this creates security bypass. Consensus: fail-soft for prototype, harden for production if validated. |
| **Tool output schema validation** | MEDIUM | SS, AP, PP (+), UX (-) | Define expected JSON structure from PostToolUse. UX considers this out of scope for prototype. Consensus: document schema, validate in v2. |

---

### SPLIT (2/2 Disagreement)

| Finding | Personas For | Personas Against | Core Disagreement |
|---------|-------------|------------------|-------------------|
| **Per-write vs batch processing** | UX, SS (real-time feedback) | PP, AP (performance, loose coupling) | UX: "Delayed feedback is useless for guiding behavior." PP: "Per-write adds 2-10 seconds latency per session, unusable." |
| **Inline vs pull-model feedback** | UX R1 (inline) | SS, PP, AP (pull) | SS: "Inline feedback enables adversarial learning." UX R2: "Pull model is acceptable compromise." Position converged in R2. |
| **Prototype scope (minimal vs principled)** | PP (minimal: keyword matching, no security hardening) | AP (principled: adapters, contracts, extension points) | PP: "Validate concept first, harden later." AP: "Poor architecture in prototype becomes production debt." |

---

### MINORITY (1/4)

| Finding | Persona | Summary | Other Responses |
|---------|---------|---------|-----------------|
| **Adversarial learning via feedback** | SS | Inline feedback teaches agents how to evade conformance checks | UX: "Agents are collaborative, not adversarial. Threat model doesn't match reality." PP: "Out of scope for prototype." AP: "Audit agent behavior, don't remove feedback." |
| **Bundled configuration (ownership + conformance)** | SS | Users might disable conformance but keep ownership, creating security gap | AP: "Solve with wrapper hook, not monolithic implementation." UX: "Configuration complexity hurts onboarding." PP: "Irrelevant if batch processing used." |

---

## Position Changes (Round 1 → Round 2)

### Security Skeptic

- **Recommendation escalated:** REVISE → RETHINK
- **Score decreased:** 3.0 → 2.2
- **Key change:** Adversarial learning risk (R2-new) and timeout handling (missed in R1) make security posture worse than initially assessed
- **Position shift:** Now advocates for bundled configuration (ownership + conformance) to prevent selective disabling

### Performance Pragmatist

- **Recommendation unchanged:** REVISE → REVISE
- **Score unchanged:** 2.8 → 2.8
- **Key change:** Proposed batch processing at session end (R2-new insight) as architectural alternative to per-write checking
- **Position shift:** Now advocates for MINIMAL prototype (strip security and architecture features) to validate concept faster

### Architectural Purist

- **Recommendation unchanged:** RETHINK → REVISE (with escalation)
- **Score increased:** 2.2 → 2.4
- **Key change:** Recognized asynchronous architecture (log + background processing) solves responsibility blur concern
- **Escalation:** Identified per-write vs batch as a PRODUCT DECISION requiring human input, not technical decision

### UX Advocate

- **Recommendation upgraded:** REVISE → REVISE-WITH-OPTIMISM
- **Score increased significantly:** 2.2 → 3.2
- **Key change:** Shifted from inline feedback (R1) to pull model (R2) after recognizing 50-message flood problem
- **New insight:** Suppressions (via source comments) are critical for false positive tolerance

---

## Disagreement Deep-Dives

### 1. Per-Write vs Batch Processing (SPLIT 2/2)

**FOR per-write (UX, SS):**
- Real-time feedback allows agent to course-correct immediately
- Delayed feedback (session end) is too late to guide development
- Value of conformance checking IS real-time drift detection

**AGAINST per-write (PP, AP):**
- 50 writes × 20 criteria × 10ms = 10 seconds added latency per session
- Synchronous blocking on every write creates unacceptable user experience
- Asynchronous batch processing (log writes, check offline) solves performance without losing functionality

**Round 2 developments:**
- UX shifted position: "Real-time doesn't require inline. Log in real-time, agent queries when needed (pull model)."
- PP: "Batch at session end still better. Single summary report, no per-write overhead."
- AP escalated: "This is a product decision. Users need to choose: responsive (per-write) or efficient (batch)."

**Unresolved:** Do users value IMMEDIATE drift detection (worth the latency cost) or POST-SESSION drift summary (efficient but delayed)?

---

### 2. Minimal vs Principled Prototype (SPLIT 2/2)

**FOR minimal (PP, UX):**
- Goal of prototype: validate the CONCEPT ("Is conformance checking valuable?"), not build production system
- Adding adapters, sandboxed parsers, and extension points delays validation
- If 10-issue sample shows low value, all that infrastructure was wasted
- "Answer the value question first. If yes, invest in quality. If no, kill it fast."

**AGAINST minimal (AP, SS):**
- Poorly architected prototypes get promoted to production without refactoring
- Hook runs on EVERY write operation — architecture matters even for prototypes
- Cost of proper abstractions: 2-3 extra implementation days
- Benefit: prototype that can evolve into production without a rewrite

**Round 2 developments:**
- UX recognized scope creep: reviewers collectively proposed 5x larger system than original spec
- PP: "Strip to minimum: cached parsing, keyword matching, log to JSONL, 10-issue test."
- AP: "Invest in architecture NOW. The cost is small, the debt is large."
- SS: "Security hardening can wait, but spec validation and sanitization cannot."

**Unresolved:** Should the prototype prioritize LEARNING (fast validation) or QUALITY (production-ready foundation)?

---

### 3. Inline vs Pull-Model Feedback (CONVERGED in R2)

**Round 1 split:**
- UX advocated inline feedback: "Agent sees conformance result after every write."
- SS, PP, AP opposed: "50 messages = noise. Adversarial learning risk. Performance overhead."

**Round 2 convergence:**
- UX shifted: "Pull model is acceptable. Log results, agent queries via `/sdd:conformance-status` command."
- All reviewers agreed: Write log in real-time, agent queries on demand, Stop hook produces summary.

**Resolution:** UNANIMOUS in Round 2. Pull model (query command) is the consensus architecture.

---

## Escalation List

### E1: Per-Write vs Batch Processing (Architectural Purist)

**Decision needed:** Should conformance checking happen:
- **Option A:** Per-write (PostToolUse hook checks each write individually, logs result)
- **Option B:** Batch at session end (PostToolUse logs writes to queue, Stop hook processes queue and checks all writes)

**Tradeoffs:**
| Dimension | Per-Write | Batch |
|-----------|-----------|-------|
| Latency | 10ms per write = 500ms/session | 1 second at session end |
| Feedback timing | Real-time (queryable immediately) | Delayed (available at session end only) |
| Complexity | Simple (one hook) | Medium (hook + queue + processor) |
| Adversarial learning | Risk: agent sees results inline | Safe: no inline feedback |

**Recommendation from debate:** Architectural Purist states this is a PRODUCT DECISION requiring user input on whether real-time availability is worth the latency cost.

---

### E2: Minimal vs Principled Prototype Scope (Performance Pragmatist vs Architectural Purist)

**Decision needed:** Should the prototype:
- **Option A:** Minimal (keyword matching, no adapters, no security hardening, no extension points)
- **Option B:** Principled (adapter layer, structured errors, sandboxed parser, extension points)

**Tradeoffs:**
| Dimension | Minimal | Principled |
|-----------|---------|------------|
| Implementation time | 2-3 days | 5-7 days |
| Validates concept | Yes | Yes |
| Production-ready | No (requires rewrite) | Yes (requires tuning) |
| Security posture | Weak (acceptable for prototype) | Strong |

**Recommendation from debate:** Performance Pragmatist argues for minimal (validate concept first). Architectural Purist argues for principled (avoid technical debt). No consensus reached.

---

## Severity Calibration

All reviewers used the same severity scale (HIGH/MEDIUM/LOW) but applied it differently:

| Finding | SS | PP | AP | UX | Calibrated |
|---------|----|----|----|----|------------|
| Spec parsing not cached | MED | HIGH | MED | LOW | **HIGH** (performance killer) |
| No matching algorithm | HIGH | MED | HIGH | LOW | **HIGH** (unknowable perf + security) |
| Per-write latency | LOW | HIGH | MED | MED | **HIGH** (10 sec/session unusable) |
| No feedback loop | LOW | LOW | MED | HIGH | **MEDIUM** (pull model solves) |
| Spec injection risk | HIGH | LOW | MED | LOW | **MEDIUM** (prototype acceptable) |
| False positive threshold | MED | MED | LOW | HIGH | **MEDIUM** (tune to 5%) |

**Calibration notes:**
- Security Skeptic over-indexed on security (scored injection as HIGH, but consensus: acceptable for prototype)
- Performance Pragmatist correctly identified latency as critical (10 sec overhead is unusable)
- UX Advocate under-indexed on technical concerns (scored matching algorithm as LOW, but consensus: HIGH)
- Architectural Purist balanced view (most severity ratings matched consensus)

---

## Quality Score with Confidence Interval

| Dimension | SS R1 | SS R2 | PP R1 | PP R2 | AP R1 | AP R2 | UX R1 | UX R2 | Mean | Std Dev | CI (95%) |
|-----------|-------|-------|-------|-------|-------|-------|-------|-------|------|---------|----------|
| Overall | 3.0 | 2.2 | 2.8 | 2.8 | 2.2 | 2.4 | 2.2 | 3.2 | 2.6 | 0.39 | **2.3 - 2.9** |

**Base CI:** ±0.3 (standard)
**Widening factors:**
- +0.1 for each SPLIT beyond first (2 SPLITs = +0.1)
- +0.2 for each ESCALATE (2 ESCALATEs = +0.4)
**Total widening:** +0.5
**Final CI:** ±0.8

**95% Confidence Interval:** 2.6 ± 0.8 = **1.8 - 3.4 / 5.0**

**Interpretation:** Moderate-to-low quality. High uncertainty due to unresolved product decisions (per-write vs batch) and scope disagreements (minimal vs principled). The spec cannot be scored definitively until these are resolved.

---

## Debate Value Assessment

### Position Changes

**4 significant position changes across 8 reviews:**
1. Security Skeptic escalated recommendation (REVISE → RETHINK) after recognizing adversarial learning and timeout handling gaps
2. UX Advocate shifted from inline feedback to pull model after recognizing cognitive load problem
3. Architectural Purist shifted from synchronous to asynchronous architecture after recognizing latency impact
4. Performance Pragmatist proposed batch processing as new alternative architecture

**Value:** HIGH — reviewers discovered new concerns and refined positions substantially

---

### New Insights

**8 new insights emerged in Round 2:**
1. Security + Performance coupling (SS): Slow hooks get disabled, defeating security purpose
2. Per-write is wrong granularity (PP): All personas identified problems with per-write checking
3. Architecture drives all concerns (AP): Security, performance, and UX problems trace to architectural decisions
4. Feedback spectrum, not binary (UX): Pull model is middle ground between inline (noisy) and batch (delayed)
5. Adversarial learning risk (SS): Inline feedback could teach agents to evade checks
6. Cache invalidation attacks (SS): Spec mtime manipulation could force expensive re-parsing
7. Prototype scope creep (UX): Reviewers collectively proposed 5x larger system than original spec
8. False positive threshold is context-dependent (SS): Security-critical criteria need <1% FP, docs need 20%

**Value:** HIGH — debate surfaced concerns not present in Round 1, particularly around granularity and architecture

---

### Severity Recalibrations

**3 findings recalibrated between rounds:**
1. Spec parsing moved from MEDIUM → HIGH after Performance Pragmatist quantified 25-second waste without caching
2. Adversarial learning (new finding in R2) rated HIGH by Security Skeptic, LOW by others — calibrated to MEDIUM
3. Separate hook responsibility rated HIGH by Architectural Purist, consensus rated MEDIUM (logically separate, configure together)

**Value:** MODERATE — some recalibration, but no major severity shifts

---

### Findings Missed Without Debate

**4 critical findings only emerged through cross-examination:**
1. **Per-write vs batch architecture** — no reviewer proposed batch processing in Round 1. Performance Pragmatist proposed it in Round 2 after reading other reviews.
2. **Pull-model feedback** — UX Advocate proposed inline in R1, shifted to pull model in R2 after reading Performance Pragmatist's noise concern and Architectural Purist's interface segregation argument.
3. **Adversarial learning risk** — Security Skeptic only identified this after reading UX Advocate's inline feedback proposal.
4. **Cache invalidation attacks** — Security Skeptic only identified this after reading Performance Pragmatist's caching proposal.

**Value:** HIGH — debate generated architectural alternatives and cross-domain concerns that single-reviewer analysis missed

---

### Value Verdict

**Debate value: HIGH**

The structured debate process delivered significant value:
- **Position changes:** 4/4 reviewers refined their positions, 2 changed recommendations
- **New insights:** 8 insights emerged that were not present in Round 1
- **Cross-domain learning:** Security reviewer learned from performance concerns, UX reviewer learned from architectural concerns
- **Architectural alternatives:** Batch processing and pull-model feedback only emerged through debate
- **Convergence:** Inline vs pull feedback split in R1 converged to consensus in R2

Without the debate, the spec would have been assessed from four isolated perspectives with conflicting recommendations and no synthesis. The cross-examination revealed that per-write checking is architecturally questionable (all personas identified problems) and that batch processing + pull-model feedback is a viable alternative.

**Cost:** 8 reviews × ~1000 words = 8000 words of analysis
**Benefit:** Identified 2 unresolved product decisions requiring human input, converged on 4 unanimous requirements, and proposed an alternative architecture (batch + pull) that solves concerns from all four domains

---

## Recommendation

**REVISE** (with ESCALATION on 2 decisions)

The spec has conceptual merit but is not implementable as written. Requires architectural clarification and product decisions before implementation.

### Required Changes (UNANIMOUS)

1. **Add caching requirement:**
   - Spec parsed once at SessionStart, cached in `.sdd-session-state.json`
   - PostToolUse reads cached criteria, not raw spec file
   - Cache invalidated at Stop hook or when spec file hash changes

2. **Define matching algorithm:**
   - Prototype uses keyword substring matching: all keywords from criterion must appear in file diff
   - Document extension points for regex or semantic matching in v2

3. **Add query command:**
   - `/sdd:conformance-status` shows recent conformance log entries
   - Agent uses pull model (query when needed) instead of inline push (message on every write)

4. **Add suppression mechanism:**
   - `// sdd:suppress <criterion-id>` source comments silence false positives
   - Reduces alert fatigue and keeps users engaged with hook

### Product Decisions Required (ESCALATE to human)

**E1: Per-Write vs Batch Processing**

Choose architecture:
- **Option A (per-write):** PostToolUse checks conformance on each write, logs result. Agent can query log immediately. Higher latency (10ms/write), real-time availability.
- **Option B (batch):** PostToolUse logs writes to queue, Stop hook processes all writes at session end. Lower latency (1ms/write), delayed feedback.

**Recommendation from debate:** All reviewers agree batch is more efficient. UX Advocate prefers per-write for real-time feedback, but accepted pull model as compromise. **Lean toward batch** unless real-time agent feedback is critical product requirement.

---

**E2: Minimal vs Principled Prototype**

Choose scope:
- **Option A (minimal):** Keyword matching, no adapters, fail-soft errors, no security hardening. Fast to build (2-3 days), validates concept, not production-ready.
- **Option B (principled):** Adapter layer, structured errors, sandboxed parser, extension points. Slower to build (5-7 days), production-ready if validated.

**Recommendation from debate:** Performance Pragmatist and UX Advocate argue for minimal (validate concept first). Architectural Purist argues for principled (avoid debt). **Lean toward minimal** — answer the value question first (10-issue sample), invest in architecture only if validated.

---

### Optional for Prototype (Defer to v2)

- Adapter layer for non-markdown specs (Architectural Purist)
- Sandboxed spec parser for security (Security Skeptic)
- Per-criterion false positive thresholds (Security Skeptic)
- Schema validation for tool output (Security Skeptic, Architectural Purist)

---

### Final Acceptance Criteria (Revised)

Original spec had 5 criteria. Revised spec should have 9:

1. [ ] PostToolUse hook logs file writes to `.sdd-conformance-queue.jsonl` (O(1) per write, <1ms)
2. [ ] Stop hook processes queue and checks conformance (batch processing)
3. [ ] Spec parsed once at SessionStart and cached in `.sdd-session-state.json`
4. [ ] Matching uses keyword substring search (all keywords from criterion must appear in diff)
5. [ ] `/sdd:conformance-status` command shows recent conformance log
6. [ ] `// sdd:suppress <criterion-id>` comments silence false positives
7. [ ] 10-issue sample tested for drift detection
8. [ ] False positive rate measured (<5% target, down from 10%)
9. [ ] Decision: adopt, modify, or reject (unchanged)

**Validation criteria unchanged:**
- <5% false positives (tightened from 10%)
- Catches 2+ drift instances per 10-issue sample (unchanged)

**Risk updated:**
- Original: "May over-constrain agent creativity"
- Revised: "Batch processing delays feedback to session end. Agents cannot course-correct in real-time. Acceptable if post-session audit is sufficient."
