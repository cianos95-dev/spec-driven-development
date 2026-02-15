# Round 2: Security Skeptic — Cross-Examination (CIA-426)

**Review Complete.** Read Performance, Architecture, and UX Round 1 findings.

---

## Responses to Other Perspectives

### Performance Pragmatist

**C1: Skill matching latency (+19%)** → **COMPLEMENT**

Performance correctly identifies the O(n) skill matching problem. I focused on namespace collision as a security issue (skill substitution attacks). Performance quantifies the cost.

**Integration:** My I1 (trigger collision routing attack) + Performance C1 (latency model) = **compound threat**. An attacker can craft prompts that force disambiguation, adding 200-500ms latency (Performance's number) while also potentially routing to wrong skill (my attack vector). The latency itself becomes part of the attack — users experiencing slowdowns may disable security-critical skills to "fix performance."

**New attack scenario:**
1. Attacker convinces user that SDD is slow
2. User investigates, finds adversarial-review adds latency due to collision with pr-dispatch
3. User disables adversarial-review to "speed things up"
4. Attacker's malicious spec bypasses Stage 4 review

**Revised mitigation:** Performance's latency budget (<100ms p95) should be a **security requirement**, not just a performance target. Latency increases are a DoS vector.

---

**C2: Plugin size bloat (+23%)** → **AGREE**

Performance's cold start analysis is sound. I'll add: Larger plugins are harder to audit. A security reviewer scanning 6,200 lines of markdown can mentally map the attack surface. At 7,634 lines (+23%), attention dilutes.

**Security corollary:** As plugin size grows, the probability of unnoticed vulnerabilities increases. A malicious contribution (if SDD accepts external PRs) can hide in the noise of a 1,434-line change.

**Mitigation:** Performance's progressive loading (defer references/ until skill fires) is also a security win — smaller initial attack surface.

---

### Architectural Purist

**C1: "Methodology over tooling" violation** → **CONTRADICT (but respect the concern)**

Architect argues this spec violates SDD's philosophy by absorbing execution-level skills. I disagree that this creates a security issue, but I respect the conceptual integrity concern.

**My position:** From a security perspective, **consolidation can improve security posture**. When SDD depends on external superpowers plugin:
- Two plugin sources to trust (two supply chains)
- Two update cadences (version drift risk)
- Two sets of contributors (larger attack surface)

By absorbing these skills, SDD:
- Reduces external dependencies (fewer supply chain risks)
- Controls the full implementation (easier to audit)
- Can enforce consistent security standards (e.g., all shell scripts reviewed)

**However:** Architect's point about maintenance burden is valid. If SDD now owns debugging tactics and PR workflow automation, it must keep pace with evolving best practices. If SDD falls behind, users may reinstall superpowers, creating the dual-plugin scenario both Performance and UX warned about.

**Synthesis:** The philosophical question ("Is this a methodology plugin?") is not my domain. But security-wise, owning the dependency is better than trusting it externally. **I vote for absorption IF SDD commits to maintaining these skills at parity with superpowers.**

---

**C2: Skill naming inconsistency** → **AGREE**

Architect's naming critique is spot-on. From a security perspective, inconsistent naming increases the risk of typosquatting or name confusion attacks.

**Example:** If the plugin registers `debugging-methodology` but user documentation refers to `debug-methodology` (typo), a malicious plugin author could register `debug-methodology` in a competing marketplace and intercept users' invocations.

**Mitigation:** Architect's proposed names (`root-cause-workflow`, `pr-review-dispatch`) are more explicit and less collision-prone. I endorse this.

---

**C3: Agent architecture unspecified** → **ESCALATE**

Architect identifies that code-reviewer.md agent placement is undefined. I flagged this as C3 (agent registration bypass). This is a **shared critical finding** that must be resolved before implementation.

**The security requirement:** code-reviewer.md MUST be registered in marketplace.json `agents` array and placed in `agents/` directory. Embedding it in a skill file bypasses Claude Code's agent isolation.

**Test procedure:** After implementation, verify:
1. `grep -r "code-reviewer" skills/` → zero results (agent not embedded in skills)
2. `cat agents/code-reviewer.md` → file exists
3. `jq '.plugins[].agents[]' .claude-plugin/marketplace.json | grep code-reviewer` → registered

---

**I1: Trigger phrase collision (non-determinism)** → **AGREE + ESCALATE**

Architect frames this as an architectural flaw (predictability). I framed it as a security flaw (routing attack). We're describing the same problem from different angles.

**Combined view:** Trigger collisions are both:
- **Security vulnerability** (skill substitution, workflow bypass)
- **Architectural debt** (non-deterministic resolution, poor composability)

This is a **compound critical finding** that should block the spec until a trigger phrase namespace design is completed.

**Proposed gate:** Before any skills are implemented, complete:
1. Audit all 21 existing skills' trigger phrases
2. Design namespace taxonomy (Architect's verb families)
3. Allocate phrases to new skills without overlap
4. Update existing skills to remove ambiguous phrases if needed

This is a **Phase -0.5 task** (pre-implementation research). The spec should acknowledge it.

---

### UX Advocate

**C1: Zero migration guidance** → **AGREE + AMPLIFY**

UX correctly identifies that users don't know how to migrate from superpowers. From a security perspective, this creates a **vulnerability window**.

**Attack scenario:**
1. User upgrades SDD to v2.0
2. User is confused about superpowers status (keep or remove?)
3. Attacker publishes blog post: "Fix SDD v2.0 slowness by keeping superpowers installed"
4. User keeps both → dual-plugin scenario → skill collisions → unpredictable routing
5. Attacker's malicious spec exploits routing ambiguity

**The migration guide isn't just UX — it's a security document.** It must clearly state the supported configurations and warn about unsupported ones.

**Mitigation:** UX's proposed migration guide should include:
```markdown
### Security Note
Running SDD v2.0 with superpowers Tier 3 skills enabled is **not a supported configuration**.
Skill name collisions may cause unpredictable routing. Disable superpowers or revert to SDD v1.3.0.
```

---

**C2: Trigger phrase collision** → **AGREE (already covered)**

UX frames this as a learnability issue (users can't build mental models). I frame it as a security issue (routing attacks). Same root cause, different impacts.

UX's command-based mitigation (`/sdd:review` vs `/sdd:pr-review`) is excellent. **I endorse adding explicit commands as a security control** — it removes the ambiguity that attackers exploit.

---

**C3: No onboarding for new skills** → **PRIORITY**

UX identifies that users don't know these skills exist until they stumble into trigger phrases. This is a discoverability issue, not a security issue. **Not my domain.**

But I'll note: If users don't know debugging-methodology exists, they may resort to external tools (ChatGPT for debugging advice, StackOverflow for PR review templates) instead of using the vetted SDD skills. This increases external dependency risk.

**Weak security argument for better onboarding:** If users know SDD's capabilities upfront, they're less likely to mix in external, unvetted workflows.

---

**I1: Skill description quality standards** → **PRIORITY**

UX wants clear, user-facing skill descriptions. I'll add: **Descriptions should not expose implementation details that help attackers.**

**Bad description:**
> "Executes find-polluter.sh to trace test pollution via grep and sort"

This tells an attacker:
- A shell script is involved
- It uses grep and sort (potential injection targets)
- Test names are passed as arguments

**Better description:**
> "Guides root cause investigation for test failures by analyzing test execution order and dependencies"

Vague on implementation, clear on user benefit.

**Mitigation:** Add to acceptance criteria: "Skill descriptions must not expose internal tool names, script paths, or command-line invocation patterns."

---

## Position Changes

### Initial Position
- C1 (shell script injection): CRITICAL, must audit before absorption
- C2 (cross-ref namespace collision): CRITICAL, must use explicit prefixes
- C3 (agent registration bypass): CRITICAL, must register in agents/

### After Cross-Examination
- **C1 unchanged:** Shell script still a critical concern, no new info
- **C2 escalated:** Performance's latency analysis + Architect's non-determinism = compound threat. This is a blocker.
- **C3 confirmed:** Architect agrees on agent placement. This is a shared critical finding.

**New critical finding:**
- **C4: Migration guide is a security control** (from UX C1). Without it, users may operate in unsupported dual-plugin state, creating routing vulnerabilities.

---

## New Insights

1. **Latency as a DoS vector:** Performance's latency model reveals that trigger collisions aren't just routing risks — they're availability risks. Users experiencing 500ms delays may disable skills entirely.

2. **Supply chain consolidation vs maintenance burden:** Architect's point about maintenance burden is valid. Absorbing superpowers reduces external dependency risk BUT increases SDD's maintenance obligations. If SDD can't keep pace, users will reinstall superpowers, creating the exact dual-plugin scenario we're trying to avoid.

3. **User confusion as an attack surface:** UX's migration guide gap is a security issue. Confused users are vulnerable users. Clear documentation is a security control.

---

## Revised Quality Score

| Dimension | Round 1 Score | Round 2 Score | Change |
|-----------|--------------|---------------|--------|
| Attack Surface | 2 | 2 | No change (still 4 critical vectors) |
| Defense Depth | 2 | 1.5 | **Worsened** — migration guide gap is a security hole |
| Input Validation | 1 | 1 | No change |
| Isolation | 3 | 2.5 | **Worsened** — agent architecture still unspecified |
| Auditability | 3 | 3.5 | **Improved** — UX's examples and migration docs help auditing |

**Revised Aggregate:** 2.0/5 (was 2.2) — **Worse after cross-examination**

**Reason:** UX revealed the migration guide gap is a security issue, not just UX. Architect confirmed agent architecture is undefined. Both degrade the security posture.

---

## Disagreement Deep-Dive

**With Architect on C1 (philosophy violation):**

Architect argues absorbing execution skills violates "methodology over tooling" and undermines SDD's positioning. I argue consolidation improves security posture by reducing external dependencies.

**Where we agree:**
- The spec changes SDD's scope
- Maintenance burden increases

**Where we disagree:**
- Architect: This is an architectural purity violation → REJECT
- Me: This is a security improvement IF maintained → CONDITIONAL APPROVE

**Proposed resolution:** The spec should explicitly acknowledge:
1. This is a strategic choice (product positioning) over architectural purity
2. SDD commits to maintaining absorbed skills at parity with superpowers
3. If SDD falls behind, users will reinstall superpowers, creating the dual-plugin risk

This makes the tradeoff explicit and helps future maintainers understand the decision context.

---

## Escalation Items

**To Human Decision:**

1. **Shell script audit procedure** — The spec must define what constitutes a "safe" shell script. Should SDD adopt a "no shell scripts in skills" policy and require Python/TypeScript rewrites?

2. **Dual-plugin support policy** — Is "SDD v2.0 + superpowers Tier 3" a supported configuration or explicitly unsupported? This affects testing, docs, and security surface.

3. **Maintenance commitment** — Is Cian willing to commit to maintaining 4 additional skills (debugging tactics, PR workflows) at parity with superpowers? If superpowers updates and SDD doesn't, users lose features.

---

## Final Recommendation

**BLOCK until 4 critical findings resolved:**

1. Shell script security audit criteria defined (C1)
2. Trigger phrase namespace designed (C2, shared with Architect I1)
3. Agent architecture specified (C3, shared with Architect C3)
4. Migration guide published (new C4, from UX C1)

**After resolution:** Conditional APPROVE with checkpoint gates:
- Gate 1: After first 2 skills, audit for cross-refs and trigger collisions
- Gate 2: After all 4 skills, run `/sdd:self-test` with superpowers disabled

**Alternative:** If human decides architectural concerns (Architect C1) outweigh security benefits of consolidation, I defer to that decision and recommend REJECT.

**My vote if forced today:** BLOCK (too many critical gaps)
