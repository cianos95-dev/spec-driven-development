# Structured Debate Synthesis — CIA-426

**Spec:** Build native SDD skills to replace superpowers dependency (Tier 3 reversal)

**Debate Participants:** Security Skeptic (Red), Performance Pragmatist (Orange), Architectural Purist (Blue), UX Advocate (Green)

**Synthesis Date:** 2026-02-15

---

## Executive Summary

The structured adversarial debate on CIA-426 reveals a spec with **sound strategic intent** (user convenience, supply chain control) but **critical implementation gaps** (trigger phrase collisions, agent architecture undefined, no migration guidance).

**Unanimous agreement:** Trigger phrase namespace collision is a blocker affecting security (routing attacks), performance (disambiguation latency), architecture (non-determinism), and UX (unpredictable behavior).

**Split decision:** Architectural Purist rejects on philosophical grounds ("methodology over tooling" violation). Other three perspectives conditionally approve IF documentation, testing, and architectural specs are added.

**Escalated to human:** Philosophy change (is SDD v2.0 still a "methodology plugin"?), maintenance commitment (can Cian keep pace with superpowers updates?), and user preference research (one plugin vs two?).

---

## Codebase Context

**Repository:** `/Users/cianosullivan/Repositories/spec-driven-development/` (v1.3.0)

**Current State:**
- 21 skill directories (24 after recent additions per ls)
- COMPANIONS.md lists superpowers under Process category with Tier 3 overlap evaluation concluding "Companion" for all 5 skills
- marketplace.json v1.3.0 registers 21 skills
- README.md positions SDD as "methodology plugin" with "methodology over tooling" principle
- 7 agents registered in agents/ directory

**Scope:** Absorb 4 superpowers skills → 4 new SDD skill directories + supporting materials (~1,200-1,400 lines) + agent template (code-reviewer.md) + 3 core doc updates (COMPANIONS.md, marketplace.json, README.md)

---

## Finding Consolidation

### UNANIMOUS (All 4 Agree)

| Finding | Perspectives | Severity | Summary |
|---------|-------------|----------|---------|
| **Trigger phrase namespace collision** | Security I1, Performance C1, Architect C2/I1, UX C2 | CRITICAL | adversarial-review vs pr-dispatch ("review"), prfaq-methodology vs ideation ("brainstorm") create non-deterministic skill resolution. Impacts: security (routing attacks), performance (200-500ms disambiguation latency), architecture (composability broken), UX (unpredictable mental models). **Blocker.** |
| **Agent architecture unspecified** | Security C3, Architect C3, UX C3, Performance (via Security) | CRITICAL | code-reviewer.md placement, registration, invocation contract, isolation boundaries all undefined. Risk: agent embedded in skill (bypasses sandboxing), or dead code (registered but never invoked). **Blocker.** |
| **Migration guidance required** | Security (Round 2 C4), Performance I3, Architect (Round 2), UX C1 | CRITICAL | Users don't know: keep superpowers or remove? Dual-plugin scenario creates skill collisions + performance degradation. Migration guide is security control, performance control, AND UX necessity. **Blocker.** |
| **Cross-reference remapping essential** | Security C2, Architect I2, UX (Round 2 via Architect) | HIGH | systematic-debugging references `superpowers:test-driven-development` (line 179) and `superpowers:verification-before-completion` (line 288). Broken refs → skill failures → user trust erosion. Must map to SDD equivalents before absorption. |

**Unanimous recommendation:** These 4 findings must be resolved before implementation begins.

---

### MAJORITY (3 of 4 Agree)

| Finding | For | Against | Severity | Summary |
|---------|-----|---------|----------|---------|
| **Shell script security audit** | Security C1, Performance (complement), Architect (via Security) | UX (deferred to Security) | CRITICAL | find-polluter.sh requires input sanitization audit. Mitigation: rewrite in Python (improves security + performance + error messages). |
| **Skill naming inconsistency** | Architect C2, Performance (agree), UX (agree) | Security (not domain) | HIGH | Proposed names (`debugging-methodology`, `ideation`, `pr-dispatch`, `review-response`) break existing taxonomy. Should be: `root-cause-workflow`, `ideation-facilitation`, `pr-review-dispatch`, `pr-review-response`. |
| **Performance benchmarks required** | Performance I1, Architect (Round 2), UX (Round 2 user acceptance) | Security (not domain) | HIGH | Acceptance criterion "superpowers can be disabled without losing capability" is untestable without benchmarks. Need: latency ±10%, output quality ≥100%. |
| **Progressive loading for size control** | Performance C2, Architect (agree), UX (framing benefit) | Security (not domain) | MEDIUM | +23% plugin size manageable IF supporting materials (references/) load on-demand. Current SDD skills follow this pattern. |

---

### SPLIT (2 vs 2)

| Finding | For | Against | Core Disagreement |
|---------|-----|---------|-------------------|
| **"Methodology over tooling" violation** | Security (supply chain win), Performance (maintenance concern acknowledged), UX (user convenience) | Architect (philosophical purity), Architect (maintenance burden) | **Is consolidation a strategic win (fewer dependencies, easier onboarding) or an identity crisis (SDD becomes general-purpose plugin)?** Architect votes REJECT on principle. Others vote CONDITIONAL APPROVE if philosophy change documented. |

**This is the central tension of the spec.** Requires human decision.

---

### MINORITY (1 Advocates)

| Finding | Advocate | Severity | Why Others Deferred |
|---------|----------|----------|---------------------|
| **Tone-policing content in review-response** | Security S1 | LOW | User privacy concern. Others agree to strip but don't consider it blocking. |
| **Skill type system (foundation vs tactical)** | Architect I3 | MEDIUM | Good idea but out of scope for CIA-426. Defer to follow-up issue. |
| **Brainstorming → ideation renaming loses familiarity** | UX I3 | MEDIUM | Others accept "ideation" as design jargon. Not blocking if trigger phrases include "brainstorm". |

---

## Position Changes Across Rounds

### Security Skeptic
- **C2 (namespace collision):** Important → CRITICAL (after Performance quantified latency, Architect showed non-determinism)
- **New C4 (migration guide):** Discovered in Round 2 via UX — now a security control
- **Verdict shift:** BLOCK (Round 1) → BLOCK (Round 2, but with more specific gates)

### Performance Pragmatist
- **C1 (skill matching latency):** CRITICAL → CRITICAL (confirmed by all perspectives)
- **I1 (no benchmarks):** MEDIUM → HIGH (UX + Architect showed user acceptance test needed)
- **Verdict shift:** REVISE (Round 1) → CONDITIONAL APPROVE (Round 2, if criteria added)

### Architectural Purist
- **C1 (philosophy violation):** REJECT → BLOCK (softened after Security's supply chain argument, but still requires README update)
- **C2 (trigger collision):** Important → CRITICAL (escalated to shared blocker)
- **Verdict shift:** REJECT (Round 1) → BLOCK (Round 2, acknowledges tradeoff but demands documentation)

### UX Advocate
- **Score improvement:** 2.2 → 2.9 (other perspectives' mitigations improve UX)
- **C1 (migration guide):** CRITICAL → CRITICAL (reinforced by Security + Performance as technical control)
- **Verdict shift:** REVISE (Round 1) → APPROVE (Round 2, if docs added)

**Trend:** Perspectives converged on blockers (trigger collision, agent architecture, migration guide) but diverged on philosophy question.

---

## Disagreement Deep-Dives

### 1. Philosophy vs Pragmatism (Architect REJECT, Others CONDITIONAL APPROVE)

**Architect's position:**
- SDD's identity is "methodology over tooling" (README line 47)
- Absorbing execution tactics (debugging techniques, PR automation) violates this principle
- Maintenance burden (tracking superpowers updates) is a long-term liability
- Recommendation: REJECT spec, strengthen companion integration instead

**Others' counter-arguments:**

**Security:**
- Consolidation reduces supply chain risk (one plugin to trust, not two)
- External dependencies are attack vectors
- IF SDD maintains absorbed skills, security posture improves

**Performance:**
- Dual-plugin scenario (user keeps both) creates 2x skill matching cost
- Consolidation eliminates this IF migration guide prevents dual installs
- Maintenance burden is real but manageable with commitment

**UX:**
- Users prefer fewer install steps, fewer plugins, unified workflow
- "Methodology plugin" is internal framing — users see "the plugin that helps me ship features"
- User convenience > philosophical purity

**Where they agree:**
- This changes SDD's scope
- README must be updated to acknowledge the shift
- Maintenance commitment is required

**Where they disagree:**
- Architect: Change violates core principle → REJECT or document tradeoff explicitly
- Others: Change serves users → APPROVE if documented

**Resolution path:**
Add to README.md "Design Philosophy Evolution (v2.0)" section (Architect Round 2 template) explaining the tradeoff. This satisfies Architect's documentation requirement without blocking the spec.

---

### 2. Execution Mode: Quick vs Checkpoint (Minor Disagreement)

**Security + Performance + Architect:** Recommend `exec:checkpoint` (high-risk, cross-cutting, requires gates)

**UX:** Acknowledges complexity but notes execution mode is human-set, not spec-controlled

**Resolution:** This is editorial (issue metadata) not technical. Human decision.

---

## New Insights from Cross-Examination

1. **Compound critical findings:** Trigger phrase collision affects ALL four dimensions (security, performance, architecture, UX). This is not just an implementation detail — it's a **fundamental design gap** that must be addressed in Phase 0 before any skills are written.

2. **Mitigation synergy:** Security's "rewrite shell script in Python" improves security (no injection), performance (no external deps), architecture (executable placement), and UX (better error messages). Rare four-way win.

3. **Migration guide as multi-domain control:** Initially framed as UX issue, revealed to be security control (prevents unsupported dual-plugin state), performance control (prevents 2x matching cost), and architectural documentation (version compatibility matrix).

4. **Command namespace as escape hatch:** Commands (`/sdd:review`, `/sdd:pr-review`) provide deterministic invocation for power users and automation, bypassing skill matching ambiguity. This is a user segmentation strategy (novices use natural language, experts use commands).

5. **User-centered benchmark:** Performance wants technical latency tests. UX wants user acceptance tests ("can users tell the difference?"). Both are needed — technical benchmarks prove performance parity, user tests prove functional equivalence.

---

## Escalation List (Requires Human Decision)

1. **Philosophy change approval** (Architect C1 escalation)
   - Decision: Does Cian accept that SDD v2.0 redefines "methodology plugin" to include execution tactics?
   - If YES: Update README.md per Architect's template
   - If NO: Reject spec, revert to CIA-425's "Companion" decision

2. **Maintenance commitment** (Performance + Architect escalation)
   - Decision: Is Cian willing to commit to maintaining absorbed skills at parity with superpowers?
   - Suggested SLA: "Absorbed skills updated within 2 weeks of superpowers releases"
   - If NO commitment: Performance + Architect recommend REJECT (maintenance drift will force users to reinstall superpowers)

3. **Shell script policy** (Security C1 escalation)
   - Decision: Should SDD adopt "no shell scripts in skills/" policy?
   - If YES: Rewrite find-polluter.sh in Python, place in hooks/scripts/
   - If NO: Define security audit procedure for shell scripts

4. **Dual-plugin support policy** (Security Round 2 escalation)
   - Decision: Is "SDD v2.0 + superpowers Tier 3" a supported configuration?
   - If YES: Must test and document skill resolution precedence
   - If NO (recommended): Migration guide must explicitly state unsupported

5. **User preference research** (UX Round 2 escalation)
   - Question: Do existing SDD users prefer one plugin (convenience) or two plugins (separation of concerns)?
   - Method: Survey users before v2.0 ships
   - If 80%+ prefer one plugin: Validates spec decision. If <50%: Reconsider.

---

## Severity Calibration

**Across all perspectives, consistent severity ratings:**

| Severity | Count | Examples |
|----------|-------|----------|
| CRITICAL | 7 | Trigger collision (unanimous), Agent architecture (unanimous), Migration guide (unanimous), Shell script (majority) |
| HIGH | 5 | Skill naming (majority), Cross-ref remapping (unanimous), Benchmarks (majority) |
| MEDIUM | 6 | Progressive loading, Dual-plugin overhead, License compliance, Environment dependencies |
| LOW | 4 | Tone-policing, Skill type system, Version bump impact, Shell script placement |

**No severity inflation detected.** Perspectives agree on what's critical vs important vs consider.

---

## Quality Score with Confidence Interval

**Aggregate scores across 4 perspectives:**

| Perspective | Round 1 | Round 2 | Change |
|-------------|---------|---------|--------|
| Security | 2.2/5 | 2.0/5 | -0.2 (worsened) |
| Performance | 2.4/5 | 2.3/5 | -0.1 (slight worse) |
| Architecture | 2.2/5 | 2.1/5 | -0.1 (slight worse) |
| UX | 2.2/5 | 2.9/5 | +0.7 (improved) |

**Mean:** 2.18/5 (Round 1) → 2.33/5 (Round 2)

**Calculation:**
- Base CI: ±0.3 (4 perspectives, diverse domains)
- SPLIT on philosophy (1 major disagreement): +0.1 widening
- Multiple ESCALATIONS (5 items): +0.2 widening
- UNANIMOUS on 4 critical blockers: -0.1 narrowing (high agreement)

**Final CI:** ±0.5

**Quality Score: 2.3 ± 0.5 (90% CI: 1.8-2.8)**

**Interpretation:** Below acceptable threshold (3.0). Spec has **critical gaps** that must be resolved.

---

## Debate Value Assessment

**Process effectiveness:**

1. **Round 1 (independent reviews):** Each perspective identified 3-7 critical/important findings. Little overlap initially (Security focused on injection, Performance on latency, Architect on philosophy, UX on migration).

2. **Round 2 (cross-examination):** Perspectives discovered:
   - Trigger collision is a compound critical (all 4 affected)
   - Migration guide is a multi-domain control (not just UX)
   - Mitigations have synergy (Python rewrite helps all 4 domains)
   - Philosophy disagreement is irreconcilable without human decision

3. **Emergent insights:** 5 new insights not present in any single perspective's Round 1 review (see section above).

**Value delivered:**
- **Identified 4 unanimous blockers** that were not in the original spec's acceptance criteria
- **Revealed central tension** (philosophy vs pragmatism) requiring strategic decision
- **Proposed specific mitigations** with cross-domain validation (e.g., Python rewrite)
- **Quantified risks** (19% latency increase, 23% size increase, 200-500ms disambiguation)

**Process improvements for next debate:**
- Phase 0.5 (pre-debate): Extract source material (actual superpowers plugin content) for more accurate line counts and cross-ref mapping
- Round 2.5 (optional): Allow perspectives to propose joint mitigations after seeing agreement

---

## Recommendation

### Consolidated Verdict

**BLOCK until 4 unanimous critical findings resolved:**

1. **Trigger phrase namespace design** (Phase 0 gate before implementation)
   - Audit all 21 existing skills' trigger phrases
   - Design namespace taxonomy (verb families per stage)
   - Allocate trigger phrases to 4 new skills (zero overlap)
   - Update existing skills if collisions detected
   - Document namespace rules in `skills/README.md` (new file)

2. **Agent architecture specification**
   - Add to spec: code-reviewer.md placement (agents/ directory)
   - Add to spec: marketplace.json registration (agents array)
   - Add to spec: Invocation contract (input/output schema, isolation boundaries)
   - Add to spec: User transparency (visual indicators when subagent spawns)

3. **Migration guide publication**
   - Create `MIGRATION-v1-to-v2.md` with:
     - What Changed (feature list)
     - Compatibility Matrix (supported/unsupported configurations)
     - Migration Checklist (step-by-step)
     - Rollback Procedure (downgrade steps)
   - Add to COMPANIONS.md: "Superseded" section for superpowers Tier 3
   - Add performance note: dual-plugin increases overhead 19%

4. **Cross-reference remapping table**
   - Map: `superpowers:test-driven-development` → `sdd:execution-modes` (TDD section)
   - Map: `superpowers:verification-before-completion` → `sdd:quality-scoring` OR `sdd:ship-state-verification`
   - Test: Disable superpowers, trigger all 4 new skills, verify zero "referenced skill not found" errors
   - Acceptance criterion: "All cross-refs use explicit `sdd:` namespace. Zero bare skill names."

**After resolution, 3 perspectives (Security, Performance, UX) vote CONDITIONAL APPROVE with gates:**
- Gate 1: After first 2 skills (debugging-methodology, ideation), verify no trigger collisions, run benchmarks
- Gate 2: After remaining 2 skills (pr-review-dispatch, pr-review-response), verify agent integration, run user acceptance test

**Architect votes BLOCK pending human decision on philosophy change.**

---

### Implementation Plan (if approved)

**Phase 0 (Pre-Implementation):**
- [ ] Complete trigger phrase namespace design (3-5 days)
- [ ] Write agent architecture spec (1 day)
- [ ] Draft migration guide (1 day)
- [ ] Map cross-references (2 days)
- [ ] Human decision on 5 escalation items (blocking)

**Phase 1 (High-Priority Skills):**
- [ ] Implement debugging-methodology (rewrite in Python, place in hooks/scripts/)
- [ ] Implement ideation (thin skill, minimal references)
- [ ] Gate 1: Benchmark + collision test

**Phase 2 (Medium-Priority Skills):**
- [ ] Implement pr-review-dispatch (register code-reviewer agent)
- [ ] Implement pr-review-response (strip tone rules)
- [ ] Gate 2: User acceptance test

**Phase 3 (Documentation):**
- [ ] Update COMPANIONS.md (remove Tier 3, add superseded section)
- [ ] Update marketplace.json (register 4 skills, 1 agent, bump version)
- [ ] Update README.md (philosophy section if human approves)
- [ ] Create 4 example files

**Estimated effort:** 15-20 days (if `exec:checkpoint` with gates). Original estimate: 8 points at `exec:quick` was underestimated.

---

## Final Notes

**Debate consensus:** This spec has strategic merit (user convenience, supply chain control) but implementation readiness is low (7 critical findings, 5 human decisions required).

**Key insight:** The spec reverses CIA-425's "Companion" decision based on product positioning ("SDD should own the full funnel") but does not address the architectural, security, and performance implications of that reversal. The debate surfaced these gaps.

**Next step:** Human decision on 5 escalation items, particularly:
1. Philosophy change (is SDD v2.0 still a "methodology plugin"?)
2. Maintenance commitment (can Cian keep pace with superpowers?)

**If human approves both:** Proceed with Phase 0 (namespace design, agent spec, migration guide). Re-estimate as 15-20 days, `exec:checkpoint`.

**If human rejects either:** Revert to CIA-425's "Companion" decision. Update COMPANIONS.md to strengthen integration story (how superpowers skills auto-fire during SDD stages).

**Debate outcome:** BLOCK pending human decisions. Implementation cannot proceed without resolving 4 unanimous critical findings + 5 escalated questions.
