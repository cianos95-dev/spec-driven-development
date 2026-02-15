# Round 2 Review — Architectural Purist (Blue)

**Spec:** CIA-396 — Prototype tool capture hooks for spec conformance
**Reviewer:** Architectural Purist
**Date:** 2026-02-15
**Context:** Cross-examination after reading Security Skeptic, Performance Pragmatist, and UX Advocate Round 1 reviews

---

## Responses to Other Personas

### Security Skeptic Findings

#### SS-C1: Arbitrary Code Execution via Spec Injection

**AGREE**

Spec injection is a real threat. However, Security Skeptic's proposed mitigations (whitelist characters, sanitization) are ARCHITECTURAL concerns:
- Whitelisting requires a validation layer
- Sanitization requires a parsing abstraction
- Safe parsing requires decoupling hook logic from parsing implementation

This reinforces my C2 finding (tight coupling to spec format). If we had a spec adapter interface, we could swap in a sandboxed parser without rewriting the hook.

**Architectural lesson:** Security concerns validate the need for proper abstraction layers.

---

#### SS-C2: Tool Output Tampering

**COMPLEMENT**

Security Skeptic identifies JSON schema validation as necessary. This is an ARCHITECTURAL concern: we need a defined contract for tool output structure.

This aligns with my C3 finding (no conformance matching contract). If we had defined:
```typescript
interface ToolOutput {
  tool_name: string;
  tool_result: {
    file_path: string;
    diff: string;
    is_error: boolean;
  }
}
```

Then schema validation is straightforward. Without a contract, every implementer will parse tool output differently, creating security and consistency problems.

---

#### SS-R2: Separate Hook Recommendation (Round 2)

**CONTRADICT**

Security Skeptic now argues that conformance checking should be in the SAME hook as ownership enforcement, for security reasons (users might disable conformance but keep ownership).

I disagree: this is confusing CONFIGURATION with IMPLEMENTATION. You can have:
- **Separate implementation** (separate .sh files, separate logic)
- **Unified configuration** (both hooks enabled by default, disabled together)

The implementation should be separate (Single Responsibility Principle). The configuration can enforce bundling if security requires it.

**Counter-argument:** If conformance and ownership must be bundled, create a WRAPPER hook that calls both:
```bash
hooks/enforcement.sh:
  bash hooks/ownership.sh
  bash hooks/conformance.sh
```

This preserves separation of concerns while ensuring they're always enabled together.

---

### Performance Pragmatist Findings

#### PP-C1: Unbounded Latency on Every Write Operation

**AGREE**

Performance Pragmatist's O(writes × criteria × matching) analysis is correct. This is an ARCHITECTURAL failure: the hook is synchronous and blocking.

**Architectural solution:** Make the hook ASYNCHRONOUS. PostToolUse hook should:
1. Log write to a queue (non-blocking, <1ms)
2. Return immediately (no conformance check inline)
3. Background process consumes queue and checks conformance offline

This decouples conformance checking from the write path, solving both performance and architectural concerns.

---

#### PP-C2: Spec Parsing on Hot Path

**AGREE**

Caching is correct, but Performance Pragmatist does not address CACHE ARCHITECTURE:
- Where is the cache stored? (in-memory? file-based?)
- How is it invalidated? (mtime? hash? manual?)
- Is it session-scoped or persistent?

Without answering these questions, "caching" is not a solution, it's a placeholder. The spec needs a caching architecture.

**Recommendation:** Use a session-scoped in-memory cache (stored in `.sdd-session-state.json`), populated at SessionStart hook, invalidated at Stop hook.

---

#### PP-R2-I2: Per-Write is the Wrong Granularity

**AGREE** (ESCALATE to human decision)

Performance Pragmatist argues for BATCH processing at session end instead of per-write checking. This is a FUNDAMENTAL ARCHITECTURAL CHANGE from what the spec proposes.

The spec says "PostToolUse hook captures file changes" (per-write). Performance Pragmatist proposes "Stop hook processes queue of writes" (batch).

These are different architectures with different trade-offs:
- **Per-write:** Immediate feedback, high overhead, tight coupling
- **Batch:** Delayed feedback, low overhead, loose coupling

This is not something reviewers can decide. It's a product decision: does the user want REAL-TIME drift detection or POST-SESSION drift detection?

**ESCALATE:** Human must choose: per-write (responsive) or batch (efficient)?

---

### UX Advocate Findings

#### UX-C1: Invisible Feedback Loop

**AGREE**

UX Advocate is right that feedback is missing from the spec. However, the proposed solution (inline feedback) violates INTERFACE SEGREGATION:

Different users need different feedback:
- Agent: Inline, per-write, actionable
- Human: Summary, post-session, audit trail

Designing ONE feedback mechanism that serves both users poorly is worse than designing SEPARATE mechanisms for each.

**Architectural solution:**
1. Hook logs conformance results to `.sdd-conformance-log.jsonl` (structured, machine-readable)
2. Agent can query log via `/sdd:conformance-status` command (pull model, not push)
3. Stop hook produces human-readable summary report

This separates concerns: logging (hook), querying (agent), reporting (human).

---

#### UX-C2: No Error Recovery Path

**AGREE**

Error recovery is an architectural concern. UX Advocate proposes actionable error messages, but the ARCHITECTURE must support error contexts:

If spec parsing fails, the hook needs to know:
- Which spec file failed?
- Which line failed?
- Was it a syntax error or a file-not-found error?

This requires structured error handling:
```typescript
interface ConformanceError {
  type: "spec_parse_error" | "criterion_match_error" | "tool_output_error";
  file_path: string;
  line_number?: number;
  message: string;
  recovery_action: string;
}
```

Without structured errors, we get Security Skeptic's concern: error messages that leak exploitable details. With structured errors, we can log details and surface generic messages.

---

#### UX-C3: False Positive Punishment

**PRIORITY**

UX Advocate identifies alert fatigue as a usability problem. I agree, but it's also an ARCHITECTURAL problem:

If false positives are high, it means the conformance matching logic is TOO BROAD. This is a coupling problem: the matcher is not tightly coupled to the semantics of acceptance criteria.

**Root cause:** The spec says "compared against" without defining what comparison means. Loose matching (substring search) produces false positives. Tight matching (exact string match) produces false negatives.

The solution is not to tune thresholds (UX approach) or to set timeouts (performance approach). The solution is to define a MATCHING TAXONOMY:
- Exact match (criterion text must appear in diff verbatim)
- Keyword match (all keywords from criterion must appear in diff)
- File scope match (criterion mentions file name, and that file was modified)

This makes matching explicit and tunable per criterion.

---

## Position Changes from Round 1

### Changed: Synchronous vs Asynchronous Architecture

**Round 1:** I implicitly assumed the hook runs synchronously (blocks the write path).

**Round 2:** After Performance Pragmatist's latency analysis and UX Advocate's feedback concerns, I now see that ASYNCHRONOUS architecture is necessary. Hook logs writes, separate process checks conformance offline.

---

### Strengthened: Adapter Layer is Critical

**Round 1:** I recommended an adapter layer for spec format decoupling.

**Round 2:** Security Skeptic's injection concerns and Performance Pragmatist's caching concerns both validate this. The adapter layer is not just for extensibility, it's for SECURITY and PERFORMANCE.

---

### New: Matching Taxonomy

**Round 1:** I said "define a conformance matcher interface."

**Round 2:** UX Advocate's false positive concern clarifies that the interface is not enough. We need a TAXONOMY of matching strategies (exact, keyword, file-scope) so that criteria can specify which strategy to use.

---

## New Insights from Cross-Examination

### Insight 1: Architecture Drives All Other Concerns

Every persona's concerns trace back to architectural decisions:
- Security Skeptic's injection risk → lack of parsing abstraction
- Performance Pragmatist's latency → synchronous blocking architecture
- UX Advocate's feedback problems → no interface segregation

If the architecture is right, these problems are tractable. If the architecture is wrong, no amount of mitigation will fix them.

---

### Insight 2: Prototype vs Production Tension

Performance Pragmatist argues for a MINIMAL prototype (no adapter layers, no extension points, no security hardening). I argued for a PRINCIPLED prototype (proper abstractions, contracts, interfaces).

This is a genuine tension:
- Minimal prototype: faster to build, validates concept, but hard to extend
- Principled prototype: slower to build, but easier to production-ize if validated

**My position:** For a hook that will run on EVERY write operation, architecture matters even in a prototype. A poorly-architected prototype that "works" will get promoted to production without refactoring, creating technical debt.

**Recommendation:** Invest in architecture NOW, not later. The cost is 2-3 extra days of implementation. The benefit is a prototype that can evolve into production without a rewrite.

---

### Insight 3: Real-Time vs Batch is a Product Decision

Performance Pragmatist's batch processing proposal solves many technical concerns, but it CHANGES THE PRODUCT:
- **Original intent (per-write):** Agent gets immediate feedback, adjusts behavior in real-time
- **Batch processing (session-end):** Agent gets feedback after work is done, cannot adjust

This is not a technical tradeoff, it's a PRODUCT tradeoff. The user experience is fundamentally different.

**ESCALATE:** This must be a human decision. Reviewers cannot choose between two different products.

---

## Revised Score

| Dimension | Round 1 | Round 2 | Change | Rationale |
|-----------|---------|---------|--------|-----------|
| **Cohesion** | 2 | 3 | +1 | Async architecture + separate hook solves responsibility blur |
| **Coupling** | 2 | 2 | 0 | Still tightly coupled to markdown without adapter layer |
| **Extensibility** | 2 | 2 | 0 | Still no extension points, matching taxonomy missing |
| **Contract Clarity** | 2 | 2 | 0 | Still no defined matching contract or tool output schema |
| **Naming** | 3 | 3 | 0 | Still ambiguous ("tool capture") |

**Overall:** 2.2 → **2.4 / 5.0** (slight increase)

Score increased slightly because asynchronous architecture solves the responsibility blur, but fundamental coupling and contract issues remain.

---

## Recommendation

**REVISE** (unchanged from Round 1, but with ESCALATION)

The spec needs architectural clarification before implementation:

**Required architectural decisions:**
1. **Synchronous or asynchronous?** (per-write check vs batch processing)
2. **Spec adapter layer:** Define interface for pluggable spec parsers
3. **Matching taxonomy:** Define exact/keyword/file-scope matching strategies
4. **Tool output contract:** Define expected JSON schema from PostToolUse
5. **Error handling architecture:** Define structured error types and recovery paths

**ESCALATE to human:** Choice between per-write (real-time feedback) and batch (efficient processing) is a product decision, not a technical decision. Reviewers cannot choose this without user input.

**If per-write chosen:** Accept higher latency cost, invest in caching and async processing.
**If batch chosen:** Accept delayed feedback, use Stop hook instead of PostToolUse.

Without these decisions, the spec is not implementable in a principled way.
