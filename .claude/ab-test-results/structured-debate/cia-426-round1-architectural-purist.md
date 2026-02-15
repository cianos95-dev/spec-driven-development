# Round 1: Architectural Purist (Blue Team) — CIA-426

**Persona:** Architectural Purist — Coupling, cohesion, API contracts, naming, extensibility

**Stance:** Every line of code is a liability. Every abstraction is a promise. Keep promises or don't make them.

---

## Critical Findings

### C1. "Absorb/rewrite" violates the stated design philosophy: "Methodology over tooling"

**Severity:** CRITICAL (conceptual integrity)

The README.md (lines 47-55) establishes SDD's design identity:

> "This is a **methodology plugin**, not an execution plugin... Methodology plugins teach the agent *how to work*... The methodology transfers across tools."

The spec now proposes absorbing 4 execution-level skills:
- **debugging-methodology** — root cause tracing, test pressure, condition-based waiting (execution tactics)
- **pr-dispatch** — subagent spawning, code-reviewer agent template (tooling automation)
- **review-response** — verify-before-implement, YAGNI pushback (tactical patterns)

Only **ideation** is methodology (facilitation process). The other 3 are tactical skills that teach specific debugging techniques, PR workflow automation, and code review response patterns — all execution-level concerns.

**The contradiction:**
- Philosophy: "Methodology plugins... not execution plugins... portable practices that survive platform changes"
- Spec: Absorb skills that depend on git PRs (pr-dispatch), test runners (debugging-methodology), and specific code review tools

**This undermines SDD's positioning.** If systematic-debugging belongs in SDD because "users shouldn't need to install a separate plugin for debugging during Stage 5-6," then by the same logic, SQL optimization (developer-essentials) belongs in SDD because users shouldn't need a separate plugin for database work during Stage 6.

The line between "methodology" and "execution" collapses. SDD becomes a general-purpose development plugin, not a spec-driven development methodology plugin.

**Mitigation:**
Either:
1. **Preserve philosophy** — Reverse this spec. Keep Tier 3 skills external. Update COMPANIONS.md to strengthen the integration story (e.g., superpowers skills auto-fire during Stage 5-6 if installed).
2. **Revise philosophy** — Acknowledge in README that SDD v2.0 is a "full-funnel development plugin" not a "methodology plugin." Remove the "methodology over tooling" language. Accept the maintenance burden of keeping debugging tactics, PR workflows, and code review patterns current.

**I vote for option 1.** The design philosophy is SDD's competitive advantage. Throwing it away to avoid a plugin dependency is strategically unsound.

---

### C2. Skill naming is inconsistent with SDD's existing taxonomy

**Severity:** CRITICAL (discoverability)

Current SDD skill names follow a pattern:

| Category | Examples | Pattern |
|----------|----------|---------|
| **Workflow stages** | spec-workflow, execution-engine, issue-lifecycle | Noun phrases describing system components |
| **Methodologies** | prfaq-methodology, adversarial-review, quality-scoring | Noun + method descriptor |
| **Operational concerns** | drift-prevention, context-management, hook-enforcement | Noun + action |

Proposed names break this:
- **debugging-methodology** — Inconsistent suffix. Should be `debug-workflow` or `root-cause-analysis` (existing skills don't use "-methodology" except prfaq)
- **ideation** — Bare noun, no descriptor. Should be `ideation-workflow` or `ideation-facilitation`
- **pr-dispatch** — Acronym + verb. Should be `pr-review-dispatch` (explicit) or `code-review-routing`
- **review-response** — Ambiguous. Response to spec review or PR review? Should be `pr-review-response`

**Impact on discoverability:**
1. Users browse `skills/` directory — naming inconsistency reduces scannability
2. Trigger phrase matching — generic terms like "ideation" may fire unintentionally
3. Future contributors — no clear naming convention to follow

**Mitigation:**
Standardize names:
- `debugging-methodology` → `root-cause-workflow` (aligns with "workflow" family)
- `ideation` → `ideation-facilitation` (clarifies what it does)
- `pr-dispatch` → `pr-review-dispatch` (removes acronym ambiguity)
- `review-response` → `pr-review-response` (clarifies review type)

---

### C3. Agent template absorption has no architectural specification

**Severity:** CRITICAL (modularity)

The requesting-code-review skill includes `code-reviewer.md` agent template. The spec mentions this once ("ships a code-reviewer.md agent template") then never addresses:

1. **Where does it go?** Spec says "4 new skill files" but agent is not a skill
2. **How is it registered?** marketplace.json has `agents` array — must register there?
3. **What's the invocation contract?** Does pr-dispatch skill spawn this agent? Via what mechanism?
4. **What's the agent's scope?** Current SDD agents (reviewer, implementer, spec-author) are full workflow agents. Is code-reviewer a subagent (narrow scope, single invocation)?

**Without architectural clarity:**
- Implementer may embed agent content in skill (wrong — violates separation of concerns)
- Agent may be registered but never invoked (dead code)
- Agent may conflict with existing `reviewer.md` (naming collision)

**Mitigation:**
Add architectural spec section:
```
## Agent Architecture

pr-review-dispatch skill spawns code-reviewer.md subagent for PR-level review.

**Invocation contract:**
- Trigger: User provides PR URL or git diff
- Dispatch: `pr-review-dispatch` skill constructs code-reviewer agent prompt
- Execution: Subagent runs in isolated context, returns structured findings
- Integration: pr-review-dispatch formats findings as PR comment or Linear update

**Registration:**
- File: `agents/code-reviewer.md`
- marketplace.json: Add to `agents` array
- Frontmatter: Standard agent schema with `scope: subagent`
```

---

## Important Findings

### I1. Trigger phrase collisions create non-deterministic skill resolution

**Severity:** HIGH (predictability)

Security raised this as a security issue. I see it as an architectural flaw: **skill matching should be deterministic and composable**.

Current collision risks:
1. adversarial-review ("review my spec") vs pr-dispatch ("review this PR") — both may match "review"
2. prfaq-methodology (ideation-to-spec) vs ideation ("help me brainstorm") — both may match "brainstorm"

**Why this is architectural, not just UX:**
- If skill A's trigger overlaps with skill B, and both fire, which one executes?
- Does Claude Code prompt user to choose? (adds latency, breaks automation)
- Does it pick based on load order? (non-deterministic)
- Does it use context to disambiguate? (requires NLP, adds complexity)

**The root cause:** SDD lacks a **trigger phrase namespace design**. Skills should use distinct verb families:
- Spec operations: `draft spec`, `review spec`, `approve spec`
- Implementation: `start task`, `debug issue`, `test code`
- PR operations: `dispatch PR`, `review PR`, `respond to PR`
- Ideation: `brainstorm`, `explore`, `diverge`

**Mitigation:**
- Design trigger phrase taxonomy before adding skills
- Audit all 21 existing skills for overlaps
- Reserve verb families per workflow stage (Stage 0-3 verbs, Stage 4 verbs, Stage 5-6 verbs)
- Document in `skills/README.md` (currently does not exist)

---

### I2. Cross-reference remapping is a breaking change to skill composition

**Severity:** HIGH (backward compatibility)

Systematic-debugging internally references:
- `superpowers:test-driven-development` (line 179)
- `superpowers:verification-before-completion` (line 288)

The spec says to remap these to SDD equivalents. But:

1. **What if SDD equivalents don't exist?** SDD has `execution-modes` (which includes TDD mode) but no standalone `test-driven-development` skill. Does the remapping point to execution-modes? If so, does that skill cover the same content?

2. **What if the equivalents are semantically different?** Superpowers' TDD skill may teach red-green-refactor at the code level. SDD's execution-modes teaches when to use TDD mode vs other modes. Different abstraction layers.

3. **What happens to users' existing prompts?** If a user has been saying "use the TDD approach from superpowers" and that phrase is embedded in their CLAUDE.md, it breaks when superpowers is disabled.

**This is a skill composition problem.** Skills should be loosely coupled — if skill A references skill B, and B is replaced, A should degrade gracefully (point to new B, or fallback to generic guidance).

**Mitigation:**
- Map all internal cross-refs before absorption:
  ```
  superpowers:test-driven-development → sdd:execution-modes (TDD section)
  superpowers:verification-before-completion → sdd:quality-scoring OR sdd:ship-state-verification
  ```
- Add acceptance criterion: "All cross-refs mapped to SDD equivalents. If no equivalent exists, cross-ref replaced with inline summary (≤3 sentences)."
- Test by disabling superpowers and running `/sdd:self-test` — zero broken refs

---

### I3. No abstraction layer for methodology vs tactics — skills are untyped

**Severity:** MEDIUM (extensibility)

SDD treats all skills equally. But they're not:
- **spec-workflow** — foundational (all other skills reference it)
- **execution-modes** — categorical (defines task routing taxonomy)
- **debugging-methodology** (proposed) — tactical (specific debug techniques)

If all skills have the same weight, how does the agent prioritize when multiple skills match? How does a user discover which skills are "core methodology" vs "optional tactics"?

**Proposed: Skill type system**
```yaml
---
name: spec-workflow
type: foundation
dependencies: []
---

---
name: debugging-methodology
type: tactical
dependencies: [execution-engine, quality-scoring]
---
```

This enables:
1. **Dependency resolution** — Load foundation skills first
2. **Discovery** — Users can list "foundation skills" separately from "tactical skills"
3. **Overrides** — Users can disable tactical skills without breaking core methodology

**Mitigation:** Out of scope for this issue, but CIA-426 should acknowledge the typing gap and recommend a follow-up issue for skill taxonomy design.

---

## Consider

### S1. The reversal rationale is product strategy, not architecture

**Severity:** LOW (documentation gap)

The spec says:
> "Different abstraction layer" is intellectually clean but practically wrong for a methodology plugin

This is a product positioning argument, not a technical one. CIA-425's analysis was correct on technical grounds (different abstraction layers, no conflicts). The reversal is a strategic choice: "We want SDD to own the full funnel."

Fine. But the spec should separate technical rationale from strategic rationale. Future maintainers need to know: Is this a technical necessity (broken abstraction) or a strategic preference (market positioning)?

**Mitigation:** Add a "Strategic Context" section explaining the product vision (SDD as single-plugin solution) vs technical reality (CIA-425's analysis was sound). This helps future contributors understand *why* SDD absorbed these skills, not just *what* was absorbed.

---

### S2. Shell script in skills/ directory violates "everything is markdown" pattern

**Severity:** LOW (convention drift)

Current SDD structure:
- `.claude-plugin/` — JSON metadata
- `skills/` — Markdown only (SKILL.md + references/*.md)
- `hooks/` — Shell scripts
- `examples/` — Markdown samples

Proposed: `skills/debugging-methodology/find-polluter.sh`

This breaks the pattern. Skills directory should be documentation. Executable artifacts go in `hooks/` or a separate `scripts/` directory.

**Mitigation:** Place find-polluter.sh in `hooks/scripts/` (already exists per codebase scan). debugging-methodology/SKILL.md references it via relative path: `../../hooks/scripts/find-polluter.sh`

---

## Quality Score

| Dimension | Score (1-5) | Justification |
|-----------|-------------|---------------|
| **Cohesion** | 2 | Methodology + execution skills mixed. Philosophy vs implementation conflict. |
| **Coupling** | 2 | Cross-ref remapping creates tight coupling. Agent architecture unspecified. |
| **Naming** | 2 | Inconsistent with existing taxonomy. Acronyms and ambiguous terms. |
| **Extensibility** | 3 | No skill type system. Trigger phrase collisions limit composability. |
| **Contracts** | 2 | Agent invocation contract missing. Cross-ref semantics undefined. |

**Aggregate Architecture Score:** 2.2/5 (Below Acceptable — conceptual integrity threatened)

---

## What This Spec Gets Right

1. **Scope boundary** — Deferring code-review-excellence prevents scope creep
2. **Stage mapping** — Each skill positioned in funnel (even if positioning is flawed)
3. **Relationship tracing** — Clear lineage to CIA-425, CIA-423

---

## Recommendation

**REJECT and reopen CIA-425.**

The spec violates SDD's core design philosophy ("methodology over tooling") without justifying the tradeoff. If SDD absorbs execution-level skills, it becomes a general-purpose development plugin, losing its differentiation in the marketplace.

**Alternative paths:**

1. **Strengthen companion integration** — Update COMPANIONS.md to show how superpowers skills auto-fire during SDD funnel stages. Position SDD as an orchestrator, superpowers as an executor. Preserve separation of concerns.

2. **Create a new plugin** — If Cian wants single-plugin convenience, create `sdd-essentials` (execution complement to SDD methodology). Keeps SDD pure, provides one-click install for users who want batteries-included.

3. **Implement companion auto-install** — CLI command `/sdd:setup` installs recommended companions automatically. Users get convenience without SDD absorbing off-philosophy content.

**If the spec proceeds despite this objection**, at minimum:
- Rename skills to match taxonomy
- Specify agent architecture
- Design trigger phrase namespace
- Acknowledge philosophy change in README
- Add skill type system (foundation vs tactical)

I vote **REJECT** on architectural grounds.
