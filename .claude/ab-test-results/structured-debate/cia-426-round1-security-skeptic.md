# Round 1: Security Skeptic (Red Team) — CIA-426

**Persona:** Security Skeptic — Attack vectors, injection risks, data handling, auth boundaries

**Stance:** Trust nothing. Assume malice. Prove safety.

---

## Critical Findings

### C1. Unaudited shell script absorption (find-polluter.sh) creates command injection surface

**Severity:** CRITICAL

The systematic-debugging skill includes `find-polluter.sh`, a shell script for test pollution tracing. The spec says "absorb/rewrite" but provides zero security review criteria. Shell scripts that manipulate test execution or file discovery are prime injection targets — if this script accepts unsanitized input (test names, file paths, environment variables), it becomes a code execution vector.

**Attack scenario:**
1. User asks agent to "debug why test `'; rm -rf /; echo '` is flaky"
2. Agent invokes absorbed find-polluter.sh with unsanitized test name
3. Command injection executes arbitrary commands

The spec must mandate:
- Shell script security audit before absorption (input sanitization, path validation, no eval/exec)
- If script is unsafe, rewrite in Python/TypeScript or drop entirely
- Document all script invocation points and input sources

**Mitigation:** Add acceptance criterion: "All shell scripts security-reviewed for injection vectors. Unsafe scripts replaced with memory-safe implementations."

---

### C2. Cross-reference remapping creates skill resolution forgery risk

**Severity:** CRITICAL

The spec requires remapping internal superpowers cross-references (e.g., `superpowers:test-driven-development` → SDD equivalent). This is a **skill resolution attack surface**. If the remapping is incomplete or points to non-existent skills, the agent's skill resolution system may:

1. Fail silently and skip critical verification steps
2. Resolve to an unintended skill with similar name
3. Execute outdated/deprecated skill content if old versions remain in cache

Worse: If superpowers plugin remains installed (the spec says "can be disabled" not "must be disabled"), there's a namespace collision. When the agent sees `systematic-debugging` in absorbed content, does it resolve to `sdd:debugging-methodology` or `superpowers:systematic-debugging`?

**Attack scenario:**
1. Attacker convinces user to keep superpowers installed "for other features"
2. New SDD skill references "systematic-debugging" assuming local resolution
3. Agent resolves to superpowers version (plugin resolution is typically lexical by load order)
4. Superpowers version has different security properties (e.g., executes unverified scripts)
5. Security boundary violated

**Mitigation:**
- Mandate explicit namespace prefixes in all remapped cross-refs (`sdd:debugging-methodology`, never bare `debugging-methodology`)
- Add acceptance criterion: "All cross-references use explicit `sdd:` namespace. Zero bare skill names."
- Add runtime check: `/sdd:self-test` must detect ambiguous skill names and fail loudly

---

### C3. Agent directory registration bypass enables subagent prompt injection

**Severity:** CRITICAL

The requesting-code-review skill includes `code-reviewer.md` agent template. The spec does not mention agents/ directory or marketplace.json agent registration. If the code-reviewer template is embedded in the skill file instead of properly registered:

1. The template bypasses Claude Code's agent sandboxing
2. Subagent dispatch becomes prompt injection (agent content passed as user message)
3. Malicious skill updates can modify subagent behavior without version gating

Claude Code's agent system (per plugin-dev standards) provides isolation and version tracking. Embedding agents in skills circumvents this.

**Mitigation:**
- Add acceptance criterion: "code-reviewer.md registered in marketplace.json agents array and placed in agents/ directory"
- Verify agent follows standard frontmatter format with security properties
- Document subagent spawn boundaries

---

## Important Findings

### I1. Trigger phrase collision enables skill substitution attacks

**Severity:** HIGH

The codebase scan identifies two collision risks:
1. adversarial-review ("review my spec") vs pr-dispatch ("review this PR")
2. prfaq-methodology (ideation-to-spec) vs ideation ("help me brainstorm")

If trigger phrases overlap, an attacker can craft input that routes to the wrong skill, bypassing security controls.

**Example:**
- User: "Review this spec before I implement"
- Intended: adversarial-review (Stage 4, multi-perspective stress test)
- Attacker goal: Route to pr-dispatch (Stage 6, assumes implementation exists)
- Result: Spec bypasses adversarial review, ships with unvetted assumptions

This is a **workflow integrity attack** — the funnel's gate system depends on skills firing in the correct order.

**Mitigation:**
- Define non-overlapping trigger phrase namespaces (e.g., "review spec" vs "review PR", "brainstorm" vs "draft PR/FAQ")
- Update existing adversarial-review description to exclude ambiguous phrases
- Add test: Prompt each skill with 10 variations, verify correct routing

---

### I2. "Absorb/rewrite" is a license compliance black hole

**Severity:** MEDIUM (legal, not technical)

Superpowers is Apache-2.0. Legal copying is permitted. But "absorb/rewrite" with no definition creates a gray area:

- **Scenario A:** Implementer copies 80% of systematic-debugging, renames headers, adjusts cross-refs. Is this a derivative work requiring attribution?
- **Scenario B:** Implementer reads superpowers, writes from scratch, produces functionally identical content. Is this clean-room rewrite or copyright violation?

The spec says "not copy" but does not define the line. This creates legal risk for SDD's distribution.

**Mitigation:**
- Add acceptance criterion: "Each absorbed skill includes attribution comment: 'Methodology inspired by superpowers:X under Apache-2.0, rewritten for SDD integration'"
- Define substantive rewrite test: "If all SDD-specific references (stages, commands, state files) are removed, the skill should be <30% similar to superpowers source"
- Document lineage in skill frontmatter or references/

---

### I3. No rollback strategy if absorption creates regressions

**Severity:** MEDIUM

The spec positions this as a Tier 3 reversal (overruling CIA-425's "Companion" decision). If the absorption introduces bugs, skill resolution failures, or user confusion, what's the rollback path?

- Users who upgrade to 1.4.0/2.0.0 and encounter issues cannot easily revert to 1.3.0 + superpowers
- Skill cache may contain mixed versions
- COMPANIONS.md update is irreversible without git history

**Mitigation:**
- Version bump to 2.0.0 (major change signals breaking potential)
- Add COMPANIONS.md "Superseded" section: "superpowers Tier 3 skills absorbed in v2.0. Users experiencing issues should report to GitHub Issues, not revert to superpowers."
- Document feature flag: `SDD_USE_NATIVE_DEBUGGING=false` to disable new skills and fall back to superpowers if installed

---

## Consider

### S1. Tone-policing content in receiving-code-review is a user privacy leak

**Severity:** LOW

The prior review notes receiving-code-review includes personality directives ("NEVER say 'You're absolutely right!'"). If these are absorbed literally into SDD, the plugin is embedding user behavior rules that should live in CLAUDE.md.

This is not a security issue in isolation, but it's a privacy anti-pattern: a methodology plugin should not dictate agent personality. Users may have conflicting tone preferences in their global config.

**Mitigation:** Strip all tone rules from absorbed content. Focus on methodology (verify-before-implement, YAGNI pushback). Add note in review-response SKILL.md: "Tone preferences configured via user's CLAUDE.md"

---

### S2. Execution mode mismatch creates schedule pressure attack surface

**Severity:** LOW

The spec uses `exec:quick` for an 8-point, cross-cutting change affecting 4 skills + 3 core docs. Quick mode implies single-sitting implementation with no review gates. If the implementer rushes to meet the "quick" expectation:

1. Security audits (shell script, cross-refs) may be skipped
2. Test coverage (trigger phrase collisions, skill resolution) may be minimal
3. Attribution/licensing may be copy-pasted without review

This is an indirect attack: the execution mode incentivizes corner-cutting.

**Mitigation:** Upgrade to `exec:checkpoint` with explicit gates: "After first 2 skills implemented, run `/sdd:self-test` and verify no regressions before continuing"

---

## Quality Score

| Dimension | Score (1-5) | Justification |
|-----------|-------------|---------------|
| **Attack Surface** | 2 | Shell script injection, cross-ref forgery, agent registration bypass, trigger collision — 4 critical/high vectors |
| **Defense Depth** | 2 | No security review criteria, no test procedures, no rollback strategy |
| **Input Validation** | 1 | Zero mention of input sanitization, trigger phrase validation, namespace enforcement |
| **Isolation** | 3 | Agent directory structure exists but not leveraged. Skill sandboxing unclear. |
| **Auditability** | 3 | Git history and version bump enable tracking, but no explicit audit trail for absorbed content |

**Aggregate Security Score:** 2.2/5 (Below Acceptable — multiple critical gaps)

---

## What This Spec Gets Right

1. **Explicit scope boundary** — Deferring code-review-excellence limits the attack surface expansion
2. **Priority split** — High vs Medium gives implementer permission to cut scope if under time pressure
3. **Relationship tracing** — Links to CIA-425 enable reviewers to understand the policy reversal context

---

## Recommendation

**BLOCK until Critical findings addressed.**

The shell script injection (C1), cross-reference namespace collision (C2), and agent registration bypass (C3) are showstoppers. These must be resolved before implementation begins.

Required changes:
- Add security audit criteria for shell scripts
- Mandate explicit `sdd:` namespace in all cross-refs
- Require agent directory registration
- Define trigger phrase boundaries to prevent routing attacks
- Add attribution/licensing guidance

Once addressed, upgrade execution mode to `exec:checkpoint` and proceed with security review gates after each absorbed skill.
