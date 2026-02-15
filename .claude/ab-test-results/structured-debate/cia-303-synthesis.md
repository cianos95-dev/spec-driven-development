# Debate Synthesis: CIA-303 -- Insights-Powered Adaptive Methodology

**Review date:** 2026-02-15
**Personas:** Security Skeptic, Performance Pragmatist, Architectural Purist, UX Advocate
**Rounds:** 2 (Independent + Cross-Examination)

## Executive Summary

CIA-303 proposes a feedback loop architecture (insights extraction, adaptive thresholds, retrospective correlation) that closes the gap between observed Claude Code behavior and SDD methodology recommendations. All four reviewers agree the concept is sound but the spec is not implementation-ready. Cross-examination revealed that multiple independently-identified findings share a common root cause: circular coupling between insights data, adaptive thresholds, and hook enforcement. The Architectural Purist's Round 2 insight -- that the spec tries to be three things (monitoring system, adaptive safety system, autonomous agent) simultaneously -- emerged as the central structural critique. Consensus recommendation is **REVISE** with emphasis on splitting concerns, defining explicit contracts, adding resource budgets, and resolving two escalated ownership questions requiring human decision.

## Codebase Context

The SDD plugin has a three-layer monitoring stack. Layer 1 (structural validation via cc-plugin-eval CI pipeline) and Layer 2 (runtime observation via `/sdd:insights` command with 4 modes) are fully implemented. Layer 3 (adaptive methodology loop) exists only as architecture documentation -- CIA-303's scope is to design and implement this layer. The codebase scan identified five pre-existing conflicts: (1) circuit breaker escalation undocumented in execution-modes skill, (2) drift thresholds misaligned between hook (20 files) and skill (30 min/50% context), (3) quality score closure eligibility vs ownership precedence undefined, (4) PreToolUse hook is a stub with incomplete logic, and (5) insights archive format lacks schema validation. All five conflicts were independently discovered by at least two reviewers, validating the scan's accuracy.

## Reconciled Findings

### UNANIMOUS (all 4 agree)

| # | Finding | Severity | Spec Section | Key Evidence |
|---|---------|----------|-------------|--------------|
| U1 | **PreToolUse hook is a non-functional stub** -- no preventive adaptive behavior exists; all checks are reactive (PostToolUse only) | Critical | Hook Enforcement | SS: no preventive controls; PP: prevents expensive ops before start; AP: dead interface / contract incompleteness; UX: broken feedback loop. 3 personas elevated to Critical in R2. |
| U2 | **Drift thresholds fragmented across 3 locations** (hook: 20 files, skill: 30 min/50% context, spec: dynamic from insights) -- non-deterministic behavior | Critical | Drift Prevention | SS: security policy enforcement failure; PP: triples reconciliation cost; AP: raised as own C3; UX: users can't reason about behavior. |
| U3 | **Adaptive threshold recomputation cost unbounded** -- 50+ insights queries per session from PostToolUse hooks with no caching or rate limiting | Critical | Adaptive Loop | SS: DoS vector (agrees with PP-C3); PP: raised as own C3, escalated in R2; AP: agrees, mandates rate-limited recomputation; UX: 2-5s latency violates feedback UX. |
| U4 | **Insights archive lacks schema versioning** -- format changes break historical data parsing with no migration path | Important | Insights Integration | SS: no forward compatibility for security patches; PP: migration cost concern; AP: forward compatibility failure; UX: cryptic parse errors. |
| U5 | **Quality score vs ownership precedence undefined** -- closure eligibility and authorization conflated with no user-facing explanation | Critical | Quality Scoring / Ownership | SS: authorization confusion (COMPLEMENT on privilege separation); PP: SCOPE but agrees with consistency concern; AP: elevated to Critical in R2 (silent failure mode, auditability violation); UX: invisible rejections. PP marked SCOPE but agreed on the underlying concern. Treated as 4/4 on the finding existing, with PP dissenting only on relevance to their lens. |
| U6 | **Dynamic threshold manipulation attack** -- adaptive thresholds can be trained to lower safety limits without hard caps or human approval gates | Critical | Adaptive Loop | SS: raised as own C3, upgraded in R2; PP: agrees ("training guard to sleep"); AP: COMPLEMENT (monotonic safety property needed); UX: elevated to Critical in R2 (degrades guidance quality). |
| U7 | **Secrets exposure in tool parameters** -- insights pipeline may persist API keys, tokens, or credentials passed as tool call arguments | Important | Insights Integration | SS: raised as own I1; PP: COMPLEMENT (reference volume = severity multiplier); AP: agrees (sanitization layer needed at boundary); UX: COMPLEMENT (destroys user trust, perception alone kills adoption). |

### MAJORITY (3/4 agree)

| # | Finding | Severity | Dissenter | Dissent Reason |
|---|---------|----------|-----------|----------------|
| M1 | **Circuit breaker escalation has no owner** -- exec-mode escalation logic is a ghost dependency distributed across 3 components | Critical | PP (PRIORITY) | PP: Only critical from performance perspective if handoff fails causing retries. SS, AP, UX all agree this is Critical. AP escalated from Important to Critical in R2. Both SS and UX formally ESCALATED for human decision. |
| M2 | **HTML parsing as primary data path with no caching** -- O(n) parsing overhead per session, no streaming alternative, no TTL cache | Critical | SS (partially; CONTRADICT from AP) | AP contradicts SS-C1 injection claim (system-generated data, not user content). However AP COMPLEMENTS PP-C1 (mandate event bus, HTML as fallback). SS COMPLEMENTS PP-C1 (DoS multiplier). UX agrees (laggy responses). 3/4 agree on performance criticality; injection risk is a SPLIT (see below). |
| M3 | **References/ read-through metric unbounded** -- 10K+ correlation records with no retention policy, query budget, or compaction strategy | Critical | SS (ESCALATE for retention policy) | PP raised as C2; AP elevated to Critical in R2 (resource management failure); UX elevated to Critical in R2 (query timeouts break insights). SS ESCALATEs on retention policy as human decision. |
| M4 | **Retrospective correlation query explosion** -- joining unstructured insights with paginated Linear API, no index strategy, 30+ second latencies | Critical | SS (COMPLEMENT, not disagree) | PP raised as C4; AP COMPLEMENT (materialized view needed); UX added as Critical in R2 (30s = abandoned command); SS COMPLEMENT (timing side channels). All effectively agree; no dissenter. Classified MAJORITY because SS framed as COMPLEMENT to own findings rather than explicit AGREE. |
| M5 | **Hook trigger threshold mismatch** (20 files vs 30 min/50% context) -- ambiguous precedence creates broken mental model | Important | SS (CONTRADICT on framing) | SS frames as privilege escalation vector, not performance. PP raised as I3. AP agrees (non-deterministic behavior from C3). UX agrees (broken mental model). All agree the finding exists; disagreement is on *why* it matters. |

### SPLIT (2/2 -- genuine disagreement)

| # | Finding | Side A (Personas) | Side A Argument | Side B (Personas) | Side B Argument |
|---|---------|-------------------|-----------------|-------------------|-----------------|
| S1 | **Insights boundary: 3-component split vs unified interface** | AP, SS | Circular coupling (hooks -> insights -> thresholds -> hooks) creates confused deputy vulnerability, second-order poisoning, and performance bottlenecks. Must separate collector, policy engine, and threshold registry. | UX, PP | 3-component split fragments user mental model. Unified `/sdd:insights` is more discoverable. Over-engineering trades clarity for correctness. Performance fixes (caching, rate limiting) don't require architectural split. |
| S2 | **HTML injection attack surface from /insights parsing** | SS, PP | HTML parsing without validation = injection vector. If parsed content enters insights archives, malicious formatting weaponizes parsing cost (DoS multiplier). Timing attacks possible. | AP, UX | Insights are system-generated execution records, not user content. If injection exists, it's in the tool execution layer (out of scope). Security hardening belongs in implementation, not spec. |
| S3 | **Drift detection: "never weaken" monotonic safety vs bidirectional adaptation** | SS, AP | Thresholds should only tighten without human approval (monotonic safety property). Bidirectional adaptation enables adversarial training to lower defenses. | UX, PP (implicit) | "Never weaken, only tighten" makes system progressively unusable. Legitimate outlier projects hit permanent false positives. Adaptation should be bidirectional with hard caps. |
| S4 | **References/ metric: surface to users vs keep internal** | AP, UX | Metric should be exposed to users to close feedback loop. Hidden metrics can't drive user behavior. Feedback loop incompleteness. | PP, SS | Surfacing references invites gaming (artificially reference more files), increasing tracking overhead. Metric should remain internal. Exposing methodology enforcement gaps enables reconnaissance. |

### MINORITY (1/4 -- unique concern)

| # | Finding | Persona | Severity | Why Others Disagree |
|---|---------|---------|----------|---------------------|
| N1 | **Timing side channels in retrospective correlation** -- query response time variance leaks project structure information | SS | Important | PP: SCOPE (no perf impact). AP: not raised. UX: not raised. Theoretical attack vector requiring sophisticated adversary with session-level timing observation. |
| N2 | **References/ as reconnaissance signal** -- reveals which methodology docs are enforced vs aspirational | SS | Minor (downgraded by AP) | PP: SCOPE. AP: PRIORITY->Minor (filesystem ACL concern, not spec issue). UX: SCOPE (transparency, not vulnerability). |
| N3 | **Compliance implications (GDPR/CCPA) of session metadata storage** | SS | Consider | Not raised by others. Valid long-term concern but outside spec scope. |
| N4 | **Spec should split into 3 separate specs** (monitoring, adaptive safety, autonomous agent) | AP | Structural | PP: doesn't address. SS: doesn't address. UX: CONTRADICT (fragments UX). Novel R2 insight from AP; no cross-examination opportunity. |

## Position Changes (Round 1 -> Round 2)

| Persona | Finding | Round 1 Position | Round 2 Position | What Changed Their Mind |
|---------|---------|-----------------|-----------------|------------------------|
| SS | SS-C3 (Dynamic Threshold Manipulation) | Critical | Critical (UPGRADED severity) | PP-C3 evidence: 50+ recalculations/session with no rate limiting makes threshold manipulation easier than originally assessed |
| SS | SS-I2 (Drift False Positives -> Privilege Escalation) | Important | Minor (DOWNGRADED) | UX-C2 reframed drift noise as alert fatigue, not a direct security vulnerability |
| SS | New: Second-order poisoning | Not identified | Critical | AP-C1 circular coupling reveals gradual amplification of initial poison over multiple sessions |
| PP | PP-C3 (Threshold Recomputation) | Critical | Critical (ESCALATED) | AP-C3 revealed fragmentation across 3 locations triples reconciliation cost; SS added adversarial training dimension |
| PP | PreToolUse Stub | Important (PP-I4) | Critical | 3 personas flagged independently; cross-cutting impact across security, architecture, and UX |
| PP | Overall recommendation | CONDITIONAL APPROVE (2.2/5) | REVISE (2.0/5) | Cumulative weight of cross-examination evidence; circular coupling as root cause of multiple bottlenecks |
| AP | AP-C2 (Circuit Breaker No Owner) | Critical | Critical (ESCALATED further) | Cross-examination revealed logic distributed across 3 components with no coordinator; worse than initially assessed |
| AP | AP-I1 (Quality Score vs Ownership) | Important | Critical (ELEVATED) | UX-C3 revealed silent failure mode where users see confusing rejections; violates auditability principle |
| AP | AP-I3 (Naming Inconsistency) | Important | Minor (DOWNGRADED) | Cosmetic compared to deeper architectural flaws uncovered in cross-examination |
| AP | Overall score | 2.6/5 | 1.8/5 | New insight: spec conflates 3 different boundary requirements; needs major structural revision |
| UX | SS-C3 (Threshold Manipulation) | Not in own findings | Critical (ELEVATED) | Hard caps on adaptive thresholds directly protect UX guidance quality |
| UX | PP-C2 (References/ Unbounded) | Not in own findings | Critical (ELEVATED) | 10K records = query timeouts = broken insights experience |
| UX | PP-C4 (Retrospective Query Explosion) | Not in own findings | Critical (ADDED) | 30+ second Linear API joins make retrospectives completely unusable |
| UX | AP-C1 (Boundary Violation / 3-way split) | Not addressed R1 | CONTRADICT | Unified interface is more discoverable; over-engineering harms UX |
| UX | AP-C2 (Circuit Breaker Ownership) | Related to own UX-C1 | ESCALATE | Ownership gap causes ghost behavior; needs Cian's input |
| UX | Overall score | 2.4/5 | 2.0/5 | Performance findings are also UX findings; latency kills feedback loops |

## Disagreement Deep-Dives

### S1: Insights Boundary -- 3-Component Split vs Unified Interface

**Side A (AP + SS):** The circular coupling (hooks depend on thresholds, thresholds depend on insights, insights depend on hook execution) is the root cause of multiple critical findings: PP-C3 (recomputation cost), SS-C3 (threshold manipulation), and SS's new second-order poisoning vector. Breaking the cycle requires explicit separation: collector (parse), engine (decide), registry (store thresholds). AP proposes unidirectional data flow with event bus. SS adds that the confused deputy vulnerability only resolves with clear privilege boundaries between components.

**Side B (UX + PP):** Architectural purity comes at UX cost. Users interact with `/sdd:insights` as a single concept. Three tools ("which one do I use?") fragments the mental model. PP notes that caching and rate limiting address the performance bottlenecks without requiring architectural restructuring. UX emphasizes discoverability: one command is always easier to learn than three.

**Synthesis recommendation:** The underlying concern (circular coupling causing performance and security issues) is valid and acknowledged by all sides. The disagreement is about the solution architecture, not the problem diagnosis. Recommend **internal separation** (three components) with **unified external interface** (single `/sdd:insights` command that delegates internally). This preserves UX discoverability while enabling clean internal contracts. Flag for spec revision with both perspectives documented.

### S2: HTML Injection Attack Surface

**Side A (SS + PP):** HTML parsing without validation creates injection risk. Even if insights data is system-generated, tool call parameters can contain user-controlled content (file paths with special characters, commit messages with HTML entities). PP adds that the parsing cost itself becomes a DoS multiplier under adversarial conditions.

**Side B (AP + UX):** Insights are extracted from Claude Code execution records, which are system-generated. If there's an injection vector, it's in the upstream tool execution layer, not in the insights parser. Security hardening (input sanitization) is an implementation concern, not a spec-level architectural flaw.

**Synthesis recommendation:** Both sides have merit. The injection risk is **real but bounded** -- it depends on whether tool parameters are reflected verbatim in parsed HTML. Spec should mandate **allowlist-only HTML parsing** as a defensive measure without requiring full threat modeling at spec level. Classify as Important (not Critical) since the attack requires upstream conditions.

### S3: Monotonic Safety vs Bidirectional Adaptation

**Side A (SS + AP):** Thresholds should never loosen without human approval. Monotonic tightening is a safety invariant that prevents adversarial training. AP notes this is a fundamental safety property of any adaptive system.

**Side B (UX + PP implicit):** Monotonic tightening makes the system progressively more restrictive over time, eventually becoming unusable for legitimate work. False positives accumulate permanently. Users abandon the tool.

**Synthesis recommendation:** Both positions identify real failure modes. The solution is **bidirectional adaptation with hard floors**: thresholds can loosen, but never below a defined minimum (e.g., no less than 50% of default). Tightening beyond 2x default requires human approval. This preserves safety while preventing rigidity. Escalate the specific hard floor values as a human decision.

### S4: References/ Metric Visibility

**Side A (AP + UX):** Hidden metrics can't drive user behavior. If reference read-through correlates with quality, users should know.

**Side B (PP + SS):** Surfacing the metric invites gaming. Users artificially reference more files to inflate scores. SS adds that revealing which docs are enforced enables reconnaissance.

**Synthesis recommendation:** Show **aggregate** read-through metrics (e.g., "70% of relevant references consulted") without per-file breakdown. This closes the feedback loop (UX) without enabling gaming (PP) or reconnaissance (SS). Implementation detail -- no spec change needed.

## Escalation List (Requires Human Decision)

| # | Issue | Why Escalated | Personas Requesting Escalation | Suggested Decision Framework |
|---|-------|--------------|-------------------------------|------------------------------|
| E1 | **Circuit breaker ownership: invoke vs recommend?** | Should `circuit-breaker-post.sh` directly invoke execution-modes escalation (silent override) or present a recommendation requiring user confirmation? Distributed across 3 components with no coordinator. | SS (ESCALATE), UX (ESCALATE), AP (Critical) | Decide based on failure consequence: if wrong escalation is cheap to undo, invoke directly. If expensive (loses work), recommend only. Consider: what happens if user ignores recommendation during genuine emergency? |
| E2 | **References/ data retention policy** | Unbounded storage creates data governance liability. Retention window (30 days? 90 days? per-project?) affects both utility of trend analysis and storage/compliance risk. | SS (ESCALATE) | Balance: shorter retention = less useful trends but lower risk. Recommended starting point: 90 days with automatic aggregation (daily summaries after 30 days, weekly summaries after 60 days). |
| E3 | **Adaptive threshold hard floor values** | Bidirectional adaptation needs minimum values to prevent both adversarial training (SS) and progressive rigidity (UX). Specific floor values require domain knowledge. | Implicit from S3 synthesis | Define per-threshold: drift detection minimum 10 files (never lower), maximum 50 files (never higher without human approval). Quality score minimum 60 (never auto-close below). Context warning minimum 40% (never suppress warnings above). |
| E4 | **Spec scope: single spec vs three specs** | AP argues CIA-303 conflates monitoring, adaptive safety, and autonomous agent -- three different boundary requirements. UX argues splitting fragments user mental model. | AP (R2 new insight) | Evaluate: can the spec be implemented in a single PR with clear internal boundaries? If yes, keep unified. If implementation naturally splits into 3+ PRs with different review requirements, split the spec. |

## Severity Calibration

| Finding | Lowest Rating | Highest Rating | Synthesized Rating | Condition for Re-evaluation |
|---------|--------------|----------------|-------------------|---------------------------|
| PreToolUse stub (U1) | Important (PP R1, UX R1) | Critical (SS, AP, PP R2, UX) | **Critical** | Re-evaluate if PreToolUse is descoped from CIA-303 (becomes its own issue) |
| Drift thresholds fragmented (U2) | Important (implicit in hook scan) | Critical (all R2) | **Critical** | Re-evaluate if single threshold config file is added before implementation |
| Threshold recomputation (U3) | Important (initial PP assessment) | Critical (all R2) | **Critical** | Re-evaluate if session-start pre-computation with caching is specified |
| Schema versioning (U4) | Important (PP, UX) | Critical (SS framing) | **Important** | Elevate to Critical if Claude Code `/insights` format changes are announced |
| Quality vs ownership (U5) | Important (AP R1) | Critical (AP R2, UX, SS) | **Critical** | Re-evaluate if explicit precedence rules are added to spec |
| Threshold manipulation (U6) | Critical (SS R1) | Critical-UPGRADED (SS R2) | **Critical** | Re-evaluate if hard caps and human approval gates are specified |
| Secrets exposure (U7) | Important (SS R1) | Important (all) | **Important** | Elevate to Critical if tool parameter logging is confirmed to persist verbatim |
| Circuit breaker ownership (M1) | Important (PP) | Critical-ESCALATED (SS, AP, UX) | **Critical (ESCALATED)** | Resolved when ownership decision is made (E1) |
| HTML parsing (M2) | Important (AP frames as implementation) | Critical (PP, UX, SS) | **Critical** | Re-evaluate if event bus / structured JSON alternative is specified |
| References/ unbounded (M3) | Important (PP R1) | Critical (AP R2, UX R2) | **Critical** | Re-evaluate if retention policy and compaction strategy are added |
| Retrospective explosion (M4) | Critical (PP R1) | Critical (all) | **Critical** | Re-evaluate if local SQLite index with max lookback window is specified |
| Hook threshold mismatch (M5) | Important (PP) | Important (all, SS frames differently) | **Important** | Resolves alongside U2 (drift threshold consolidation) |
| Boundary split (S1) | N/A (solution dispute) | N/A | **Critical (problem) / SPLIT (solution)** | Resolved by E4 decision |
| HTML injection (S2) | Important (AP, UX) | Critical (SS) | **Important** | Elevate if tool parameters confirmed to contain user-controlled content |
| Monotonic vs bidirectional (S3) | N/A (approach dispute) | N/A | **Critical (problem) / SPLIT (approach)** | Resolved by E3 decision |
| References visibility (S4) | Minor (PP) | Important (AP, UX) | **Minor** | Implementation detail; aggregate display resolves both sides |

## Quality Score

| Dimension | Score (1-5) | Confidence | Notes |
|-----------|-------------|------------|-------|
| Security posture | 1.5 | +/-0.3 | No input validation, no authentication boundaries, no integrity checks on archives, dynamic thresholds exploitable. SS 1.4, AP (security lens) ~2.0. |
| Performance readiness | 2.0 | +/-0.3 | Unbounded parsing, no caching, no query budgets, no resource limits. Sound architecture but zero guardrails. PP 2.0. |
| Architectural clarity | 2.0 | +/-0.4 | Circular coupling, ghost dependencies, no explicit contracts. Concept is sound but boundaries undefined. AP 1.8. Wider CI due to S1 split. |
| UX coherence | 2.0 | +/-0.3 | Multiple overlapping systems, invisible behavior changes, no progressive disclosure. UX 2.0. |
| Spec completeness | 2.0 | +/-0.3 | PreToolUse stub, retrospective scope undefined, ownership precedence missing, no resource budgets. |
| **Overall** | **1.8** | **CI: 1.2-2.4** | Median of revised persona scores: SS 1.4, PP 2.0, AP 1.8, UX 2.0. CI base +/-0.3, widened +0.2 for S1 SPLIT, +0.2 for S2 SPLIT, +0.1 for S3 SPLIT, +0.1 for S4 SPLIT, narrowed -0.1 for U1 beyond 2nd UNANIMOUS, -0.1 for U2, -0.1 for U3, -0.1 for U4, -0.1 for U5, -0.1 for U6. Net adjustment: +0.6 - 0.5 = +0.1. Widened by +0.2 for E1 ESCALATE, +0.2 for E2 ESCALATE. Final width: 0.3 + 0.1 + 0.4 = 0.8. Narrowed by consensus: 0.8 - 0.2 = 0.6. **CI: 1.2-2.4.** |

## Debate Value Assessment

- **Position changes:** 16 (SS: 3, PP: 3, AP: 4, UX: 6)
- **New insights from cross-examination:** 12 (SS: 4, PP: 4, AP: 4, UX: 4 -- many overlapping but independently articulated)
- **Severity recalibrations:** 10 (6 upgrades, 3 downgrades, 1 lateral reframe)
- **Findings missed without debate:** 4 -- second-order poisoning from circular coupling (SS via AP-C1), latency as UX killer (UX via PP findings), performance boundaries as architectural requirements (AP via PP), secrets perception destroying trust (UX via SS-I1)
- **Key debate dynamics:**
  - PP moved from CONDITIONAL APPROVE to REVISE -- the only recommendation change, triggered by cumulative cross-examination evidence
  - AP's score dropped most dramatically (2.6 -> 1.8) after recognizing that performance boundaries are architectural requirements
  - UX absorbed 3 Critical findings from PP that were not in their Round 1 analysis, demonstrating that performance and UX concerns are deeply coupled
  - SS's injection concern (SS-C1) was the most contested finding -- AP and UX pushed back on threat model assumptions, producing a genuine SPLIT
- **Value verdict:** **HIGH** -- Round 2 genuinely changed the outcome. Without cross-examination: (a) PP would have CONDITIONAL APPROVED, creating a false sense of readiness; (b) the circular coupling root cause connecting PP-C3, SS-C3, and AP-C1 would not have been identified; (c) 4 severity recalibrations (3 upgrades, 1 downgrade) directly improved the accuracy of prioritization; (d) 2 escalations requiring human decision would have been buried as architectural concerns.

## Recommendation

**REVISE** (unanimous across all 4 personas after Round 2; PP shifted from CONDITIONAL APPROVE).

The spec must address the following before implementation, in priority order:

1. **Break circular coupling** -- Define unidirectional data flow from insights collection through policy evaluation to threshold updates. Internal 3-component separation with unified external interface (synthesis of S1).

2. **Add resource budgets** -- Every data path needs cardinality limits, retention policies, caching strategies, and timeout budgets. Currently zero resource guardrails exist.

3. **Resolve circuit breaker ownership** (E1) -- Human decision required on invoke-vs-recommend behavior and which component owns the escalation contract.

4. **Consolidate drift thresholds** -- Single `config/adaptive-thresholds.json` as source of truth with hard floors and ceilings (E3 values needed).

5. **Implement PreToolUse contract** -- Define scope validation interface with structured rejection responses. Currently a dead stub that 4/4 personas flagged.

6. **Add schema versioning** -- All serialized formats crossing system boundaries must include version identifiers with migration paths.

7. **Define retrospective scope** -- Enumerate allowed/prohibited operations, max lookback window, and local index strategy to prevent unbounded Linear API queries.

8. **Add input sanitization layer** -- Allowlist-only HTML parsing, tool parameter secret redaction, insights archive integrity validation.

Consider splitting into 2-3 specs if implementation scope exceeds a single PR (E4 decision).
