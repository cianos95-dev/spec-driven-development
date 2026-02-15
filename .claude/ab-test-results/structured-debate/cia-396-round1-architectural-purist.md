# Round 1 Review — Architectural Purist (Blue)

**Spec:** CIA-396 — Prototype tool capture hooks for spec conformance
**Reviewer:** Architectural Purist
**Date:** 2026-02-15

## Review Lens

Coupling, cohesion, API contracts, naming, extensibility, boundary violations.

---

## Critical Findings

### C1: Blurs Hook Responsibilities

**Severity:** HIGH

The spec proposes adding spec conformance checking to PostToolUse hook. But PostToolUse already has TWO distinct responsibilities:

1. **Existing:** Ownership boundary enforcement (circuit breaker, protected branch detection, uncommitted file counting)
2. **Proposed:** Spec conformance checking (acceptance criteria comparison)

These are orthogonal concerns:
- Ownership enforcement: "Did the agent violate process rules?"
- Conformance checking: "Did the change align with the spec's intent?"

Mixing them in one hook violates Single Responsibility Principle and makes the hook hard to configure (users might want ownership enforcement but NOT conformance checking, or vice versa).

**Mitigation:**
1. Create a separate hook script: `hooks/spec-conformance.sh`
2. Register it as a THIRD PostToolUse hook in hooks.json
3. Allow independent enabling/disabling via hook matchers

---

### C2: Tight Coupling to Spec Format

**Severity:** MEDIUM-HIGH

The spec assumes acceptance criteria are markdown checklists in a PR/FAQ document. This couples the conformance hook to:
- Markdown parsing
- Checklist format (`- [ ] Criterion text`)
- PR/FAQ structure (where criteria are located in the document)

If the project uses a different spec format (e.g., YAML, TOML, structured JSON), the hook breaks. This limits reusability and makes the hook brittle to spec format changes.

**Mitigation:**
1. Define a spec adapter interface: `extract_criteria(spec_path) -> list[string]`
2. Implement markdown adapter as default, allow custom adapters
3. Or require specs to export a machine-readable criteria file (e.g., `.sdd-criteria.json`) that the hook consumes

---

### C3: No Conformance Matching Contract

**Severity:** HIGH

The spec says "Changes compared against active spec acceptance criteria" but does not define:
- What "compared" means (regex match? semantic similarity? keyword search?)
- What the input to the comparison is (full file? diff hunks? changed lines only?)
- What the output is (boolean match? confidence score? matched criterion ID?)

Without a defined contract, every implementer will interpret this differently, making it impossible to test, reuse, or extend.

**Mitigation:**
1. Define a conformance matcher interface:
   ```
   match_conformance(criterion: string, changes: Diff) -> ConformanceResult
   ```
2. Specify ConformanceResult schema:
   ```json
   {
     "matched": bool,
     "confidence": float,
     "evidence": string  // which line/hunk matched
   }
   ```
3. Prototype with a simple keyword matcher, document extensibility for semantic matchers later

---

## Important Findings

### I1: Unclear Boundary with drift-prevention Skill

**Severity:** MEDIUM

The codebase already has a `drift-prevention` skill that compares implementation against spec via manual `/sdd:anchor` command. This skill:
- Re-reads spec acceptance criteria
- Compares git state against criteria
- Produces a drift report

CIA-396 proposes AUTOMATIC drift detection via PostToolUse hook. The boundary between these is unclear:
- When should users use `/sdd:anchor` vs relying on the hook?
- Do they produce the same output format?
- Does the hook replace the skill, or complement it?

**Mitigation:**
1. Document relationship: "Hook is PROACTIVE (per-write), skill is REACTIVE (session boundary)"
2. Ensure hook output format aligns with anchor output format (reuse same schema)
3. Consider: hook writes to log, `/sdd:anchor` reads log and produces summary report

---

### I2: Naming Confusion

**Severity:** LOW-MEDIUM

The spec title is "Prototype tool capture hooks" but "tool capture" is ambiguous:
- Does it mean capturing tool invocations (which tools were called)?
- Does it mean capturing tool outputs (what files changed)?
- Does it mean capturing spec conformance (which criteria were met)?

The codebase uses "tool capture" in the context of cc-plugin-eval (capturing which plugin components trigger), not file changes. Using the same term for a different concept creates confusion.

**Mitigation:**
- Rename to "Prototype spec conformance hooks" or "Prototype acceptance criteria verification hook"

---

### I3: No Extension Points

**Severity:** MEDIUM

The spec is a prototype, but provides no guidance on how to extend or customize conformance matching logic. If the default matcher produces too many false positives, users have no path to improve it without forking the hook.

**Mitigation:**
1. Design for extensibility: allow conformance matchers to be pluggable
2. Document extension points: "To customize matching logic, implement a matcher script at `hooks/matchers/custom.sh`"
3. Or use a plugin architecture where matchers are discovered dynamically

---

## Consider

### S1: State Management

The hook will need to track conformance results over time (for false positive rate calculation). Where should this state live?
- `.sdd-conformance-log.jsonl` (proposed) — works, but no schema validation or rotation policy
- `.sdd-state.json` (existing state file) — centralizes state, but adds clutter
- Separate database (SQLite?) — overkill for a prototype, but necessary if this becomes production

Recommend: Start with JSONL, document migration path to structured state if adopted.

---

### S2: Hook Orchestration

With THREE PostToolUse hooks (main, circuit-breaker, conformance), execution order matters:
1. Circuit breaker should run FIRST (block destructive ops before conformance check)
2. Main hook (ownership) should run SECOND (check boundaries)
3. Conformance hook should run THIRD (check spec alignment)

Current hooks.json does not specify ordering. If Claude Code executes hooks in array order, this works. If execution order is undefined, we have a problem.

**Recommendation:** Document execution order dependency or make conformance hook check for circuit breaker state before proceeding.

---

### S3: API Versioning

If this hook is adopted, the conformance checking API (input/output contracts) should be versioned. Breaking changes to the matcher interface would break custom matchers. Suggest adding a version field to ConformanceResult schema.

---

## What the Spec Gets Right

1. **Prototype scope** — Not committing to full production deployment before validating the concept is architecturally sound.

2. **Measurable success criteria** — "<10% false positives" and "2+ drift instances detected per 10 issues" are concrete.

3. **Decision gate** — Acknowledges this might not work. Prevents premature commitment.

4. **Explicit risk callout** — "May over-constrain agent creativity" shows awareness of tradeoffs.

---

## Quality Score

| Dimension | Score (1-5) | Rationale |
|-----------|-------------|-----------|
| **Cohesion** | 2 | Mixes conformance checking with existing ownership enforcement |
| **Coupling** | 2 | Tightly coupled to markdown spec format, no adapter layer |
| **Extensibility** | 2 | No defined extension points or matcher interface |
| **Contract Clarity** | 2 | "Compared against" is undefined, no input/output schema |
| **Naming** | 3 | "Tool capture" is ambiguous, but spec is otherwise clear |

**Overall:** 2.2 / 5.0

---

## Recommendation

**RETHINK**

The core idea — automatic conformance checking at write time — is interesting, but the spec is architecturally unsound:

1. **Responsibility violation:** Conformance checking belongs in a separate hook, not mixed with ownership enforcement.
2. **Undefined contract:** Without a defined matcher interface and result schema, this cannot be implemented consistently.
3. **Format coupling:** Tight coupling to markdown makes the hook non-reusable.

**Required changes for REVISE:**
1. Create separate `hooks/spec-conformance.sh` (do not extend existing PostToolUse hook)
2. Define matcher interface: `match_conformance(criterion, diff) -> ConformanceResult`
3. Define ConformanceResult schema with version field
4. Document relationship to existing drift-prevention skill
5. Add adapter layer for spec format parsing

**Alternative approach:** Instead of a hook, make this a SKILL that wraps PostToolUse. Skill provides the conformance logic, hook provides the execution trigger. This decouples the concerns and makes testing easier.
