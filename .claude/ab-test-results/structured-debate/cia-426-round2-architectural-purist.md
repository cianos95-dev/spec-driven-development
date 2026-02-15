# Round 2: Architectural Purist — Cross-Examination (CIA-426)

**Review Complete.** Read Security, Performance, and UX Round 1 findings.

---

## Responses to Other Perspectives

### Security Skeptic

**C1: Shell script injection** → **AGREE + ELEVATE**

Security's injection attack vector is valid. My concern: **Shell scripts in a plugin violate "everything is markdown" convention** (my S2).

**Architectural principle:** A plugin's directory structure is its API contract. Users expect:
- `.claude-plugin/` → JSON metadata
- `skills/` → Markdown documentation
- `hooks/` → Shell automation
- `examples/` → Markdown samples

If `skills/debugging-methodology/find-polluter.sh` appears, this breaks the contract. Skills are knowledge, not executables.

**Synthesis with Security:** Security wants Python rewrite for safety. I want no executables in skills/ for architectural purity. **Our mitigations converge:**
- Rewrite find-polluter.sh in Python (Security's mitigation)
- Place in `hooks/scripts/` not `skills/` (my S2)
- Skill markdown references it via relative path

This preserves both security and architectural clarity.

---

**C2: Cross-ref namespace collision** → **ESCALATE to shared blocker**

Security frames as skill substitution attack. I frame as non-deterministic resolution. We're describing the same architectural flaw.

**New insight from cross-examination:** Performance quantifies the disambiguation cost (200-500ms). This means the collision isn't just a correctness issue — it's a **user-perceptible failure mode**.

**Architectural implication:** Skills are meant to be composable. If skill A can unintentionally invoke skill B instead of skill C, the composition is broken. This violates the **substitution principle** — skills with similar trigger phrases should be substitutable, not collision-prone.

**Revised severity:** This is a **critical architectural flaw**, not just "important." The spec must design the trigger phrase namespace BEFORE implementing any skills.

**Gate proposal:** Pre-implementation Phase 0:
1. Audit all 21 existing skills' trigger phrases (export to CSV)
2. Design namespace taxonomy (verb families per stage)
3. Allocate trigger phrases to new skills (zero overlap with existing)
4. Update existing skills if collisions detected
5. Document namespace rules in `skills/README.md` (new file)

Only after this gate completes can implementation begin.

---

**C3: Agent registration bypass** → **AGREE + SPECIFY INTERFACE**

Security identifies isolation risk. I identify modularity gap. Combined:

**Agent architecture specification (missing from spec):**

```markdown
## Agent Integration

### code-reviewer Subagent

**Purpose:** Conduct PR-level code review when pr-review-dispatch skill is invoked.

**Location:**
- File: `agents/code-reviewer.md`
- Registration: `marketplace.json` agents array

**Invocation Contract:**
```yaml
input:
  pr_url: string
  focus_areas: string[] # e.g., ["security", "performance"]
output:
  findings: Finding[]
  severity_summary: { critical: int, high: int, medium: int, low: int }
```

**Isolation:**
- Subagent runs in isolated context (no access to parent session state)
- Findings returned as structured JSON, not free text
- Parent skill (pr-review-dispatch) formats findings for user presentation

**Lifecycle:**
- Spawned: When user provides PR URL to pr-review-dispatch
- Terminated: After findings returned
- No persistent state between invocations
```

This spec section should exist BEFORE implementation. Without it, the implementer guesses at the contract.

---

### Performance Pragmatist

**C1: Skill matching latency (+19%)** → **AGREE + PROPOSE ARCHITECTURAL FIX**

Performance quantifies the O(n) skill matching problem. Architectural solution: **Lazy skill loading**.

**Current model (assumed):**
1. Plugin loads → all 25 skills registered → all trigger phrases indexed
2. User message → match against 1,250 phrases → O(n)

**Proposed model:**
1. Plugin loads → only foundation skills registered (spec-workflow, execution-engine, etc.)
2. User message → match against foundation skills (~500 phrases) → O(n/2)
3. If no match → load tactical skills on-demand → match again → O(n/2)

**Benefit:**
- Cold start faster (fewer skills to register)
- Skill matching faster (smaller search space initially)
- Collision risk reduced (foundation skills have well-defined triggers, tactical skills loaded only when needed)

**Implementation:** Requires skill type system (my I3). Foundation skills vs tactical skills. This is out of scope for CIA-426 but should be noted as future work.

**For this spec:** Accept the +19% cost as technical debt, add follow-up issue for lazy loading.

---

**C2: Plugin size bloat (+23%)** → **AGREE**

Performance's progressive loading mitigation (defer references/) is correct. I'll add: This aligns with SDD's existing convention.

**Audit of current skills:**
- execution-engine: SKILL.md + 3 references (replan-protocol, retry-budget, configuration)
- adversarial-review: SKILL.md + 3 references (github-action-copilot, github-action-api, multi-model-runtime)

**Pattern:** Main SKILL.md ~200-250 lines, references ~150-200 lines each.

**Proposed for absorbed skills:**
- debugging-methodology: SKILL.md ≤250 lines, references/root-cause-tracing.md, references/test-pressure.md, etc.
- ideation: SKILL.md ≤200 lines (thin skill, per review), minimal references
- pr-review-dispatch: SKILL.md ≤200 lines, agents/code-reviewer.md (separate file)
- pr-review-response: SKILL.md ≤200 lines, references/yagni-discipline.md

**Size estimate:** ~800 lines SKILL.md + ~600 lines references = 1,400 lines (matches Performance's estimate). But with progressive loading, only ~800 lines loaded initially.

**Conclusion:** Performance's concern is valid but mitigated by existing architecture. Not a blocker.

---

**I1: No benchmarks** → **AGREE + SPECIFY TEST PROCEDURE**

Performance wants benchmarks. I want acceptance criteria. Combined:

**Acceptance criterion (new):**
```
Benchmark each absorbed skill against superpowers equivalent:
- debugging-methodology vs superpowers:systematic-debugging
- ideation vs superpowers:brainstorming
- pr-review-dispatch vs superpowers:requesting-code-review
- pr-review-response vs superpowers:receiving-code-review

Test procedure:
1. Create identical test prompt for each pair (e.g., "help me debug flaky test")
2. Time from prompt to first response (p50, p95, p99)
3. Measure output quality (LOC, specificity, actionability)
4. Verify SDD version is ±10% latency, ≥100% quality

If SDD version is >10% slower or <100% quality, document gaps in COMPANIONS.md.
```

This makes "can be disabled without losing capability" testable.

---

### UX Advocate

**C1: Zero migration guidance** → **AGREE + STRUCTURE**

UX provides an excellent migration guide template. I'll add architectural structure:

**Migration guide should be versioned:**
- `MIGRATION-v1-to-v2.md` (this change)
- Future: `MIGRATION-v2-to-v3.md`

**Contents:**
1. What Changed (UX's template)
2. **Compatibility Matrix** (my addition):
   ```
   | Configuration | Supported? | Performance | Notes |
   |---------------|-----------|-------------|-------|
   | SDD v2.0 only | Yes | Optimal | Recommended |
   | SDD v2.0 + superpowers (all) | No | Degraded | Skill collisions |
   | SDD v2.0 + superpowers (Tier 1-2 only) | Yes | Acceptable | Keep only if you use worktrees/parallel-agents |
   | SDD v1.3.0 + superpowers | Yes | Baseline | Downgrade if issues |
   ```
3. Migration Checklist (UX's template)
4. **Rollback Procedure** (my addition):
   ```bash
   # If v2.0 causes issues:
   claude plugins remove spec-driven-development
   claude plugins add spec-driven-development@1.3.0
   claude plugins add superpowers@superpowers-marketplace
   ```

This gives users a clear escape path.

---

**C2: Trigger phrase collision** → **AGREE (already covered in Security C2)**

UX's command-based mitigation is excellent. Architectural benefit: Commands are explicit contracts. Skills are implicit heuristics. **Power users should prefer commands.**

I endorse adding:
- `/sdd:pr-review` — PR-level review dispatch
- `/sdd:brainstorm` — divergent ideation
- Existing: `/sdd:review` — spec-level adversarial review (Stage 4)

This creates a **command namespace** parallel to the skill namespace. No collisions possible.

---

**C3: No onboarding** → **COMPLEMENT**

UX wants examples. I want API contracts. Combined:

**Each new skill needs:**
1. Frontmatter (name, description, triggers)
2. **Contract section** (my addition):
   ```markdown
   ## Invocation Contract
   **Input:** User prompt containing "debug", "flaky test", or test failure message
   **Output:** Structured debug plan with hypothesis, reproduction steps, verification criteria
   **Dependencies:** execution-engine (task loop), quality-scoring (acceptance criteria)
   ```
3. Examples (UX's request): `examples/sample-debugging-session.md`

This documents both how to invoke (UX) and what to expect (architecture).

---

**I2: COMPANIONS.md superseded section** → **AGREE + GENERALIZE**

UX wants a "Superseded" section for superpowers. I'll generalize:

**COMPANIONS.md structure (revised):**
```markdown
# Companion Plugins

## Active Companions
[Current recommendations]

## Superseded Companions
[Plugins whose functionality is now built-in]

## Incompatible Companions
[Plugins known to conflict with SDD]
```

This creates a template for future deprecations and incompatibilities.

---

## Position Changes

### Initial Position
- C1 ("methodology over tooling" violation): REJECT — this is an identity crisis
- C2 (skill naming inconsistency): CRITICAL — harms discoverability
- C3 (agent architecture unspecified): CRITICAL — missing contract

### After Cross-Examination
- **C1 softened to BLOCK:** Security's supply chain consolidation argument is compelling. I still believe this violates SDD's philosophy, but I acknowledge the security benefit. **New position: BLOCK until philosophy change is documented in README.**
- **C2 escalated:** Trigger phrase collision is now shared critical with Security and Performance. This is a **pre-implementation blocker**.
- **C3 unchanged:** Still critical, now have specific contract template to add to spec.

**New blocking concern:**
- **Maintenance commitment** (from Performance): If SDD can't keep pace with superpowers updates, the architectural benefit of consolidation (single source of truth) becomes an architectural liability (stale source of truth).

---

## New Insights

1. **Security + Performance convergence:** My architectural concerns (non-determinism, coupling) align with Security's attack vectors and Performance's latency models. The trigger collision is a **compound flaw** affecting all three dimensions.

2. **Command namespace as escape hatch:** UX's command mitigation is architecturally sound. It creates an explicit contract layer above the implicit skill matching layer. This is the right pattern for power users and automation.

3. **Migration guide as architectural documentation:** UX's migration guide isn't just user-facing — it documents the plugin's version history and compatibility constraints. This is architectural metadata that should be versioned.

---

## Revised Quality Score

| Dimension | Round 1 Score | Round 2 Score | Change |
|-----------|--------------|---------------|--------|
| Cohesion | 2 | 1.5 | **Worsened** — philosophy violation confirmed, not resolved |
| Coupling | 2 | 1.5 | **Worsened** — cross-ref remapping is more complex than initially assessed |
| Naming | 2 | 2.5 | **Improved** — UX's command namespace reduces ambiguity |
| Extensibility | 3 | 3 | No change — skill type system still deferred |
| Contracts | 2 | 2 | No change — agent contract still missing |

**Revised Aggregate:** 2.1/5 (was 2.2) — **Slightly worse**

**Reason:** Philosophy violation (C1) is a deeper issue than I initially assessed. Security's argument doesn't resolve the architectural concern — it just reframes it as a tradeoff. Coupling (C2) is worse after seeing Performance's maintenance burden analysis.

---

## Disagreement Deep-Dive

**With Security on C1 (philosophy violation as security win):**

Security argues consolidation improves security by reducing supply chain dependencies. I argue it violates SDD's core design principle and increases maintenance burden.

**Where we agree:**
- External dependencies are a risk (supply chain attacks)
- Consolidation gives SDD more control

**Where we disagree:**
- Security: Control = security win → APPROVE (if maintained)
- Me: Control = maintenance burden + philosophy violation → REJECT (or document tradeoff)

**Proposed resolution:**
The spec must acknowledge both perspectives. Add to README.md:

```markdown
## Design Philosophy Evolution (v2.0)

SDD v1.x positioned itself as a "methodology plugin" — teaching agents *how to work* without bundling execution tactics. This preserved a clean separation: SDD orchestrates, companion plugins execute.

SDD v2.0 absorbs execution-level skills (debugging, PR workflows) for these reasons:

**Pros:**
- Reduces external dependencies (security benefit)
- Simplifies installation (UX benefit)
- Ensures SDD owns the full funnel (product positioning)

**Cons:**
- Increases maintenance burden (must track superpowers updates)
- Blurs methodology/execution boundary (architectural tradeoff)
- May conflict with "methodology over tooling" principle

**Decision:** The strategic benefit (single-plugin convenience, supply chain control) outweighs the architectural cost. SDD v2.0 commits to maintaining absorbed skills at parity with their origins.

**For users who prefer the v1.x model:** Continue using SDD v1.3.0 + superpowers. This configuration remains supported.
```

This makes the tradeoff explicit. Future contributors understand *why* SDD v2.0 differs from v1.x.

---

## Escalation Items

**To Human Decision:**

1. **Philosophy change approval** — Does Cian accept that SDD v2.0 redefines "methodology plugin" to include execution tactics? If yes, README must be updated. If no, this spec should be rejected.

2. **Maintenance commitment** — Is Cian willing to commit to a specific SLA (e.g., "absorbed skills updated within 2 weeks of superpowers releases")? Without this, the consolidation becomes technical debt.

3. **Skill type system** — Should SDD v2.0 introduce a foundation/tactical skill taxonomy? This is out of scope for CIA-426 but affects long-term architecture. Needs roadmap decision.

---

## Final Recommendation

**BLOCK until philosophy change is documented, then CONDITIONAL APPROVE.**

Required changes:
1. **README.md update:** Document the v2.0 philosophy shift (methodology → methodology+execution)
2. **Trigger phrase namespace:** Complete Phase 0 gate (audit existing, design taxonomy, allocate phrases)
3. **Agent architecture:** Add contract specification for code-reviewer subagent
4. **Maintenance commitment:** Add to spec or COMPANIONS.md

**After changes:** Conditional APPROVE with architectural gates:
- Gate 1: After debugging-methodology + ideation, verify no trigger collisions with existing skills
- Gate 2: After pr-review-dispatch + pr-review-response, verify agent integration works as specified

**Alternative:** If Cian rejects the philosophy change or can't commit to maintenance, I vote REJECT and recommend reverting to CIA-425's "Companion" decision.

**My vote if forced today:** BLOCK (philosophy change must be acknowledged)

**Rationale:** I cannot approve a spec that contradicts SDD's stated design principles without those principles being revised. Either change the principles or change the spec — don't ship the contradiction.
