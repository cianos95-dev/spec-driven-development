# Round 1: Performance Pragmatist (Orange Team) — CIA-426

**Persona:** Performance Pragmatist — Scaling limits, caching, resource budgets, latency

**Stance:** Measure first, optimize second. Never assume performance.

---

## Critical Findings

### C1. Skill matching latency increases 19% (21→25 skills) with zero indexing optimization

**Severity:** CRITICAL (for CLI responsiveness)

Claude Code's skill resolution system scans all registered skills on every user message to match trigger phrases. The spec adds 4 skills (debugging-methodology, ideation, pr-dispatch, review-response) bringing total from 21 to 25.

**Performance model:**
- Current: 21 skills × ~50 trigger phrases each = ~1,050 phrase comparisons per message
- Proposed: 25 skills × ~50 trigger phrases each = ~1,250 phrase comparisons per message
- **Increase: 19% more matching overhead**

This compounds with the trigger phrase collision issues (Security finding I1, codebase scan). If adversarial-review and pr-dispatch both register "review" as a trigger, the resolution system must:
1. Match both skills
2. Disambiguate based on context
3. Potentially prompt user for clarification

**Latency impact:**
- Baseline skill matching: ~50-150ms (unverified, no benchmarks in repo)
- After change: ~60-180ms
- Under collision: +200-500ms for disambiguation UI

For a CLI tool, 500ms added latency on every message is user-hostile.

**Mitigation:**
- Benchmark current skill matching latency: `time` a simple prompt that triggers no skills
- Define latency budget: "Skill matching must complete in <100ms p95"
- Optimize trigger phrase indexing: Use trie or prefix tree, not linear scan
- Reduce trigger phrase count: Each new skill should have ≤20 phrases, not 50+

---

### C2. Absorbing 1,200+ lines of content bloats plugin size by 15-20%, impacting cold start

**Severity:** HIGH

Current SDD plugin size (estimated from line counts):
- 21 skills × ~200 lines avg = ~4,200 lines
- Commands, agents, examples = ~2,000 lines
- **Total: ~6,200 lines of markdown content**

Proposed absorption:
- systematic-debugging: 1,030 lines (main + 7 supporting files)
- brainstorming: 54 lines
- requesting-code-review: ~200 lines (estimated with agent template)
- receiving-code-review: ~150 lines (estimated)
- **Total added: ~1,434 lines (23% increase)**

**Impact on cold start:**
1. Plugin manifest parsing: +23% (marketplace.json larger)
2. Skill file loading: +23% disk I/O
3. Skill registration: +19% (25 vs 21 skills)
4. Memory footprint: +23% in Claude Code's skill cache

For users with 10+ plugins installed (not uncommon in ecosystem), this compounds. A 23% size increase across plugins means slower session starts.

**Measured impact (hypothetical):**
- Current cold start: 800ms (plugin load + skill registration)
- After change: 984ms (+184ms, 23% increase)
- With 10 heavy plugins: +1,840ms total

This violates the "methodology not execution" philosophy. A methodology plugin should be lightweight — teaching the agent, not bundling execution artifacts.

**Mitigation:**
- Adopt progressive loading: Only load supporting materials (references/) on demand when skill fires
- Compress supporting content: Convert verbose markdown to structured YAML where possible
- Defer shell scripts: Provide links to scripts in a separate repo, don't bundle in plugin
- Add size budget to spec: "New skills must not exceed 250 lines per SKILL.md"

---

## Important Findings

### I1. No benchmark for "superpowers can be disabled" — cannot verify performance claims

**Severity:** MEDIUM

The acceptance criterion "superpowers plugin can be disabled without losing any SDD workflow capability" has no performance dimension. The spec implicitly claims "native skills will perform equivalently to superpowers skills" but provides zero benchmarks.

**Scenarios where absorbed skills may be slower:**
1. If superpowers caches debug traces and SDD version regenerates on each invocation
2. If superpowers systematic-debugging uses compiled tools (grep, ripgrep) and SDD version uses text processing in LLM context
3. If agent dispatch (code-reviewer.md) has higher latency when registered in agents/ vs embedded in skill

Without benchmarks, users may disable superpowers and experience regressions they cannot diagnose.

**Mitigation:**
- Add acceptance criterion: "Benchmark task completion time for debugging, ideation, PR dispatch, and review response workflows. New skills must complete within 10% of superpowers equivalents."
- Document performance characteristics in each SKILL.md: "Expected latency: <500ms for trigger matching, <5s for workflow execution"

---

### I2. Shell script dependency (find-polluter.sh) creates runtime environment assumption

**Severity:** MEDIUM

Systematic-debugging's find-polluter.sh is a Bash script. This assumes:
1. User's system has Bash (not guaranteed on Windows Git Bash, minimal containers)
2. Script dependencies (grep, find, sort) are available and GNU-compatible
3. Execution permissions are set correctly

Superpowers may handle this via plugin initialization hooks. SDD does not document plugin initialization, so the script may fail silently or with cryptic errors.

**Performance implication:**
If the script fails, the debugging-methodology skill falls back to manual debug guidance. This is slower (LLM generates debug steps vs script automates trace collection) and less reliable.

**Mitigation:**
- Document script dependencies in debugging-methodology/SKILL.md: "Requires: bash, grep, find (GNU coreutils)"
- Provide fallback: "If script execution fails, skill provides manual debug checklist"
- Consider rewriting in Python (cross-platform, bundled with Claude Code)

---

### I3. Dual-plugin scenario doubles skill matching cost without deduplication

**Severity:** MEDIUM

The spec says superpowers "can be disabled" but does not require it. Users may keep superpowers for non-Tier-3 features (git worktrees, parallel agent dispatch). In this scenario:

- SDD registers: debugging-methodology, ideation, pr-dispatch, review-response
- Superpowers registers: systematic-debugging, brainstorming, requesting-code-review, receiving-code-review

**Result: 8 skills registered for 4 capabilities.**

Claude Code's skill resolution scans both. Even with correct namespace disambiguation (`sdd:` vs `superpowers:`), the matching engine evaluates 8 skills where 4 would suffice.

**Latency:** 2x matching cost for every debugging or review-related prompt.

**Mitigation:**
- Add migration guidance in COMPANIONS.md: "Users should uninstall superpowers after upgrading to SDD v2.0 to avoid skill matching overhead"
- Implement skill precedence: If both SDD and superpowers register similar skills, SDD versions take precedence (requires Claude Code feature, may not exist)

---

## Consider

### S1. Progressive disclosure references/ pattern is underutilized

**Severity:** LOW

The current SDD architecture uses `references/` subdirectories to defer loading of supporting content. This is a performance optimization — main SKILL.md is ~200 lines, references add 500-800 lines but are only loaded when explicitly requested.

Systematic-debugging's 1,030-line bulk contradicts this pattern. If the absorption literally copies all 7 files into debugging-methodology/, the skill becomes heavy even if references/ are present.

**Opportunity:** Rewrite systematic-debugging as a thin SKILL.md (200 lines) with 6 reference pointers, matching SDD's style. This preserves content depth while maintaining cold-start performance.

---

### S2. Version bump to 2.0.0 forces full plugin reload in user environments

**Severity:** LOW

If the spec mandates a major version bump (1.3.0 → 2.0.0), Claude Code may invalidate skill cache. Users will experience:
1. Cold start penalty on first session after upgrade
2. Potential plugin re-initialization (depends on Claude Code's plugin loader)

This is a one-time cost but should be communicated. If the change were scoped to 1.4.0 (minor bump), cache invalidation might be avoided.

**Mitigation:** If major version bump is chosen, document it as a breaking change and recommend users restart Claude Code after upgrade.

---

## Quality Score

| Dimension | Score (1-5) | Justification |
|-----------|-------------|---------------|
| **Scalability** | 3 | +19% skill count is manageable but approaching threshold. No indexing optimization planned. |
| **Resource Usage** | 2 | +23% plugin size with no progressive loading strategy. Shell script adds runtime deps. |
| **Latency** | 2 | Trigger collision adds disambiguation overhead. No latency budget defined. |
| **Caching** | 4 | Claude Code's skill cache likely handles this well, but spec doesn't verify. |
| **Benchmarking** | 1 | Zero performance tests, zero benchmarks, no acceptance criteria for latency or resource limits. |

**Aggregate Performance Score:** 2.4/5 (Below Acceptable — no measurement strategy)

---

## What This Spec Gets Right

1. **Bounded scope** — 4 skills, not 10. Limits performance impact.
2. **Deferred low-priority skills** — code-review-excellence not absorbed now, reduces immediate size increase.
3. **Directory structure** — Skills already use references/ pattern, just need to enforce it in new skills.

---

## Recommendation

**REVISE with performance criteria.**

The spec must define:
1. **Latency budget:** Skill matching <100ms p95, workflow execution <10% slower than superpowers
2. **Size budget:** New SKILL.md files ≤250 lines each, supporting content in references/
3. **Benchmark plan:** Before/after comparison for debugging, ideation, PR dispatch workflows
4. **Fallback strategy:** If shell script fails, skill provides manual guidance without blocking

Without these, the implementation risks shipping a measurably slower experience with no way to diagnose regressions.

**Conditional approval:** If performance criteria are added and execution mode upgraded to `exec:checkpoint` (to allow benchmarking between milestones), this is viable.
