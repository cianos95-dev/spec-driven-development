# Round 2 Review — UX Advocate (Green)

**Spec:** CIA-396 — Prototype tool capture hooks for spec conformance
**Reviewer:** UX Advocate
**Date:** 2026-02-15
**Context:** Cross-examination after reading Security Skeptic, Performance Pragmatist, and Architectural Purist Round 1 reviews

---

## Responses to Other Personas

### Security Skeptic Findings

#### SS-R2: Adversarial Learning Risk (Round 2)

**CONTRADICT**

Security Skeptic argues that inline feedback to agents creates adversarial learning risk: "agents could use conformance feedback to iteratively craft malicious writes that pass checks."

This is a theoretical risk, but I dispute its practical relevance for TWO reasons:

1. **Agent intent:** Claude agents are not adversarial by design. They're trying to implement specs correctly, not evade detection. The threat model (malicious agent) does not match the actual use case (collaborative agent).

2. **Learning window:** Adversarial learning requires ITERATION. In a typical session, the agent writes a file once or twice, not 50 times. There's no opportunity to "learn" the conformance logic through trial and error.

**Counter-argument:** If we're worried about adversarial agents, the solution is not to remove feedback — it's to AUDIT agent behavior. A malicious agent that's hiding feedback learning would also be hiding other malicious behavior.

**UX stance:** Do not sacrifice useful feedback for a theoretical threat that doesn't match the actual threat model.

---

#### SS-C3: False Positive Punishment

**COMPLEMENT**

Security Skeptic identifies alert fatigue as a security problem (ignored warnings → missed real drift). I agree, and add a UX dimension:

Alert fatigue creates LEARNED HELPLESSNESS. If users see many false positive warnings and can't do anything about them (because the conformance logic is a black box), they learn to ignore ALL warnings, not just false positives.

**UX solution:** Make warnings actionable:
```
[SDD Conformance] ⚠ File auth.ts does not match criterion "Implement authentication"
Action: Add a comment `// Implements CIA-123 criterion 2` to silence this warning
```

If users can SUPPRESS false positives explicitly, they won't ignore warnings — they'll engage with them.

---

### Performance Pragmatist Findings

#### PP-R2-I2: Per-Write is the Wrong Granularity

**CONTRADICT**

Performance Pragmatist proposes batch processing at session end instead of per-write checking. I disagree: this BREAKS the feedback loop.

The VALUE of conformance checking is REAL-TIME correction:
1. Agent writes code
2. Hook checks conformance
3. Agent sees "⚠ No criterion matched" immediately
4. Agent adjusts the next write to align with spec

If feedback is DELAYED until session end, the agent has already finished and moved on. The warning is too late to be useful.

**Analogy:** This is like a compiler that only shows errors AFTER you've written all your code. Yes, it's faster. But it's useless for guiding development.

**UX stance:** Batch processing optimizes for performance at the expense of usability. For a prototype, prioritize learning (real-time feedback) over efficiency (batch processing).

---

#### PP-R2: Batched Feedback (Round 2)

**PRIORITY**

Performance Pragmatist argues that 50 inline messages (one per write) is overwhelming and proposes batched summary at session end.

I partially agree: 50 messages IS too many. But the solution is not to batch ALL feedback — it's to FILTER feedback:
- Show HIGH-SEVERITY warnings inline (no criterion matched)
- Suppress LOW-SEVERITY info inline (criterion matched)
- Provide summary at session end (statistics)

This gives the agent immediate feedback on PROBLEMS while avoiding noise on SUCCESSES.

**Revised UX design:**
- Inline: `[SDD] ⚠ auth.ts drift detected (no matching criterion)` — only on drift
- Silent: Conformance passed — no message
- Session end: `[SDD] 45/50 writes matched criteria. 5 drift warnings issued.`

---

### Architectural Purist Findings

#### AP-C1: Blurs Hook Responsibilities

**SCOPE**

Architectural Purist wants separate hooks for ownership and conformance. From a UX perspective, this is a CONFIGURATION COMPLEXITY problem:

If the two hooks are separate, users need to:
1. Understand the difference between ownership and conformance
2. Configure both hooks independently
3. Debug hook interactions (what if they conflict?)

**UX preference:** Keep ONE hook with CLEAR PURPOSE ("SDD enforcement hook") rather than two hooks with overlapping concerns. Simpler mental model, easier configuration.

---

#### AP-C2: Tight Coupling to Spec Format

**AGREE**

Architectural Purist's adapter layer proposal is good for extensibility, but BAD for discoverability:

If specs can be markdown, YAML, JSON, or custom format, users don't know which format to use. The flexibility creates decision paralysis.

**UX recommendation:** Support ONLY markdown for the prototype. Document "future: adapter layer for custom formats" but don't implement it yet. Fewer choices = better onboarding.

---

#### AP-R2: Interface Segregation (Round 2)

**AGREE**

Architectural Purist's proposal for SEPARATE feedback mechanisms (log for machine, summary for human) is correct. This is what I should have proposed in Round 1.

**Revised feedback design:**
1. **Hook logs to `.sdd-conformance-log.jsonl`** — structured, machine-readable, complete
2. **Agent queries log via `/sdd:conformance-status`** — pull model, agent controls when to check
3. **Stop hook produces summary report** — human-readable, session-level statistics

This satisfies:
- Performance Pragmatist: no 50-message flood
- Security Skeptic: no inline adversarial learning
- Me: agent still gets feedback (via query command)

---

## Position Changes from Round 1

### Changed: Inline Feedback is Not the Only Option

**Round 1:** I argued for inline feedback on every write.

**Round 2:** After reading Performance Pragmatist's noise concern and Architectural Purist's interface segregation argument, I see that a PULL MODEL (agent queries log) is better than a PUSH MODEL (hook spams messages).

---

### Strengthened: Real-Time Still Necessary

**Round 1:** I argued for real-time feedback.

**Round 2:** Performance Pragmatist's batch processing proposal makes me MORE convinced that real-time matters. Delayed feedback is useless for guiding behavior.

**Clarification:** Real-time doesn't mean INLINE (pushed to agent). It means AVAILABLE (queryable by agent). The log is written in real-time, the agent queries it when needed.

---

### New: Actionable Warnings

**Round 1:** I did not propose a solution for false positives.

**Round 2:** Security Skeptic's alert fatigue concern clarifies that warnings must be ACTIONABLE. Users need a way to suppress false positives explicitly (e.g., via source code comments or .sdd-suppress.json).

---

## New Insights from Cross-Examination

### Insight 1: Feedback is Not Binary

I initially thought feedback was either:
- **ON:** Agent sees every conformance result
- **OFF:** Agent sees nothing

But there's a spectrum:
- **Verbose:** Every conformance result inline (bad: 50 messages)
- **Filtered:** Only warnings inline, successes silent (better: ~5 messages)
- **Pull:** Log results, agent queries on demand (best: 0-N messages, agent chooses)
- **Batch:** Single summary at session end (worst: too late to guide behavior)

The PULL model (query command) is the sweet spot: real-time availability, user-controlled volume.

---

### Insight 2: Suppressions are a UX Requirement

Every reviewer raised false positives as a concern. The ONLY way to make false positives tolerable is to allow users to suppress them.

Without suppressions:
- False positive → warning → user investigates → determines it's false → frustrated
- Same false positive triggers 10 more times in the session → user disables hook

With suppressions:
- False positive → warning → user adds suppression comment → warning silenced
- User stays engaged with the hook because they have control

**Recommendation:** Add suppression mechanism to acceptance criteria:
```markdown
- [ ] Users can suppress false positives via `// sdd:suppress criterion-id` comments
```

---

### Insight 3: Prototype Scope Creep

Looking at all reviewers' suggestions:
- Security Skeptic: sandboxed parser, schema validation, sanitization
- Performance Pragmatist: caching, batch processing, timeout handling
- Architectural Purist: adapter layer, matching taxonomy, structured errors
- Me: suppression mechanism, query command, actionable messages

We've collectively proposed a 5x larger system than the original spec. This is SCOPE CREEP.

**For a prototype**, the goal is to answer ONE QUESTION: "Is write-time conformance checking valuable?"

We don't need to answer: "Is it secure, fast, extensible, and production-ready?"

**Recommendation:** Strip the prototype to the MINIMUM VIABLE TEST:
1. Cached markdown parsing (simplest)
2. Keyword substring matching (good enough)
3. Log results to JSONL (structured but simple)
4. 10-issue sample test (validates value)
5. Manual false positive review (no automation)

If the 10-issue test shows value (catches real drift, <10% FP), THEN invest in production features. If not, the prototype is rejected and no effort was wasted on security, performance, or architecture.

---

## Revised Score

| Dimension | Round 1 | Round 2 | Change | Rationale |
|-----------|---------|---------|--------|-----------|
| **User Journey** | 2 | 3 | +1 | Pull model (query command) solves feedback problem without noise |
| **Error Experience** | 2 | 3 | +1 | Fail-soft + actionable errors (from PP and AP) improve experience |
| **Cognitive Load** | 2 | 4 | +2 | Pull model + filtered feedback eliminates 50-message flood |
| **Discoverability** | 2 | 3 | +1 | Query command (`/sdd:conformance-status`) makes feature discoverable |
| **Mental Model** | 3 | 3 | 0 | Still needs "how this works" documentation |

**Overall:** 2.2 → **3.2 / 5.0** (significant increase)

Score increased significantly because the PULL MODEL (log + query command) solves most UX concerns raised in Round 1.

---

## Recommendation

**REVISE** (upgraded from REVISE to REVISE-WITH-OPTIMISM)

After cross-examination, I'm more optimistic about this spec. The pull model architecture solves the feedback problem elegantly.

**Required changes:**
1. **Add query command:** `/sdd:conformance-status` to view recent conformance log
2. **Filter inline feedback:** Only HIGH-SEVERITY drift warnings, suppress successes
3. **Add suppression mechanism:** `// sdd:suppress <criterion-id>` comments to silence false positives
4. **Document mental model:** "Hook logs conformance, agent queries log, human reviews summary"

**Optional for prototype** (save for v2 if validated):
- Adapter layer (Architectural Purist)
- Sandboxed parser (Security Skeptic)
- Batch processing (Performance Pragmatist)

**Fundamental insight:** The value question ("Is this useful?") is separate from the quality question ("Is this well-built?"). The prototype should answer the VALUE question first. If the answer is yes, invest in quality. If no, kill it fast.

**10-issue sample is the key:** If the sample shows real drift detection with <10% FP, the concept is validated. If not, no amount of architecture will save it.
