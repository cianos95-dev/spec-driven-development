# Round 2: UX Advocate — Cross-Examination (CIA-426)

**Review Complete.** Read Security, Performance, and Architecture Round 1 findings.

---

## Responses to Other Perspectives

### Security Skeptic

**C1: Shell script injection** → **COMPLEMENT with user safety**

Security flags find-polluter.sh as a code execution risk. From UX perspective: **Users don't understand shell script risks.**

**User mental model:**
- User: "Help me debug this flaky test"
- Agent: Runs debugging-methodology skill
- Under the hood: Executes find-polluter.sh with test name as input
- User sees: Debug analysis (no indication a script ran)

**If script fails (bad input, missing dependency, permission error):**
- User gets cryptic error: "bash: grep: command not found"
- User has no context: "What's bash? What's grep? I just asked for debugging help"

**Security's Python rewrite solves this:**
- Python bundled with Claude Code → fewer missing dependency errors
- Better error messages: "Unable to analyze test execution order. Please verify test names."
- Fallback is in-process → user still gets guidance even if automation fails

**UX endorsement:** Security's mitigation improves error experience, not just security.

---

**C2: Cross-ref namespace collision** → **AGREE + USER IMPACT**

Security frames as skill substitution attack. UX framing: **Users experience this as "Claude is broken."**

**User scenario:**
1. User (Week 1): "Review my spec for the auth feature" → adversarial-review fires, provides multi-perspective stress test
2. User (Week 2): "Review the spec for the payment flow" → pr-review-dispatch fires (wrong skill!), asks for PR URL
3. User: "Wait, it worked last week. Why is it asking for a PR now?"

**User blames the tool, not their prompt.** They don't understand that "review the spec" vs "review this spec" (subtle article difference) might trigger different skills.

**Command-based mitigation** (`/sdd:review` vs `/sdd:pr-review`) gives users a reliable mental model:
- Commands = explicit, predictable
- Natural language = fuzzy, best-effort

**Recommendation:** Document the reliability difference:
```markdown
## When to Use Commands vs Natural Language

**Commands** (`/sdd:review`, `/sdd:pr-review`):
- Guaranteed to fire the right skill
- Fast (no skill matching overhead)
- Preferred for automation, scripts, repeated workflows

**Natural Language** ("review my spec", "help me debug"):
- Convenient for exploration
- May be ambiguous if phrasing overlaps multiple skills
- Agent will ask for clarification if unclear
```

This sets user expectations correctly.

---

**C3: Agent registration bypass** → **PRIORITY (trust implication)**

Security's concern: Isolation and sandboxing. UX concern: **User trust in subagents.**

**User mental model:**
When `/sdd:pr-review` spawns code-reviewer subagent:
- User expects: Isolated review context, structured findings
- If embedded in skill: May inherit parent context, informal tone

**Trust factor:** Users must trust that subagent reviews are unbiased (not influenced by user's own biases in the session). Proper agent isolation reinforces this trust.

**UX endorsement:** Security's mitigation (register in agents/) improves user trust in review quality.

---

### Performance Pragmatist

**C1: Skill matching latency (+19%)** → **AGREE + QUANTIFY USER PAIN**

Performance measures 200-500ms disambiguation overhead. User impact:

**User perception thresholds:**
- <100ms: Instant (user perceives no delay)
- 100-300ms: Perceptible but acceptable
- 300-1000ms: Sluggish (user notices, starts to doubt tool)
- >1000ms: Broken (user assumes hang, hits Ctrl+C)

**Performance's 200-500ms is in the "sluggish" zone.** Repeated across many prompts, this erodes user satisfaction.

**Worse:** Users can't distinguish "skill matching is slow" from "Claude is thinking." They just know "Claude Code feels slower after I upgraded."

**Mitigation:** Performance's latency budget (<100ms p95) must be a user-facing commitment:
```markdown
## Performance Commitment

SDD v2.0 commits to:
- Skill matching completes in <100ms (95th percentile)
- If disambiguation required, user sees progress indicator
- Commands bypass matching for instant invocation
```

This manages expectations and provides an escape hatch (commands).

---

**C2: Plugin size bloat (+23%)** → **PRIORITY (perceived installation friction)**

Performance quantifies size increase. User impact: **Installation feels heavier.**

**User mental model:**
- Small plugin = lightweight, low-commitment, easy to try
- Large plugin = heavyweight, complex, "do I really need all this?"

**Even though size doesn't affect runtime** (Performance's progressive loading handles it), users perceive size as complexity.

**Mitigation:** Marketing copy should emphasize lightweight core:
```markdown
## Installation

SDD is a lightweight methodology plugin (~800 lines core, ~600 lines optional references).
Supporting materials load on-demand — you only pay for what you use.
```

This frames size positively (comprehensive) rather than negatively (bloated).

---

**I1: No benchmarks** → **AGREE (user validation)**

Performance wants technical benchmarks. UX wants user-facing validation: **Can users tell the difference?**

**User acceptance test:**
1. Give user a debugging task with superpowers installed
2. Note time-to-resolution and user satisfaction
3. Switch to SDD v2.0 (superpowers disabled)
4. Repeat same task
5. Verify: Time ±10%, satisfaction ≥ baseline

This is a **user-centered benchmark** complementing Performance's technical benchmarks.

---

### Architectural Purist

**C1: "Methodology over tooling" violation** → **CONTRADICT (user-centered view)**

Architect argues this violates SDD's philosophical purity. UX perspective: **Users don't care about philosophy — they care about getting work done.**

**User journey (current state with superpowers):**
1. Install SDD for spec-driven workflow
2. Hit Stage 6 (implementation), need debugging help
3. Read COMPANIONS.md: "Install superpowers for debugging"
4. Install superpowers
5. Learn superpowers commands/triggers
6. Use both plugins in parallel

**User journey (proposed state with absorbed skills):**
1. Install SDD for spec-driven workflow
2. Hit Stage 6, need debugging help
3. Say "help me debug" → SDD handles it natively
4. Continue working (no context switch)

**User preference:** Fewer plugins, fewer install steps, fewer commands to learn.

**Architect's "maintenance burden" concern is valid** — but that's Cian's problem, not users'. From a user perspective, consolidation is a clear win.

**Counterpoint to Architect:** The "methodology plugin" identity is internal framing. Users see SDD as "the plugin that helps me ship features." Whether it's philosophically pure or pragmatically comprehensive doesn't matter to them.

**Recommendation:** If Cian chooses user convenience over architectural purity, that's a valid product decision. Document it, but don't block it.

---

**C2: Skill naming inconsistency** → **AGREE + USER DISCOVERY**

Architect wants consistent taxonomy. UX benefit: **Predictable naming helps users build mental models.**

**Example:**
- Current: adversarial-review, execution-engine, quality-scoring (noun + descriptor pattern)
- Proposed: debugging-methodology, ideation, pr-dispatch, review-response (mixed patterns)

**User confusion:**
- Is `ideation` a noun (the concept) or a verb (the action)?
- Is `pr-dispatch` an abbreviation (like URL) or a compound word (like "checksum")?

**Architect's proposed names** (`root-cause-workflow`, `ideation-facilitation`, `pr-review-dispatch`, `pr-review-response`) are more consistent and more discoverable.

**UX endorsement:** Consistent naming reduces cognitive load. I support Architect's proposed names.

---

**C3: Agent architecture unspecified** → **AGREE + USER TRANSPARENCY**

Architect wants a formal contract spec. UX wants: **Users should know when a subagent is invoked.**

**User experience guideline:**
When pr-review-dispatch spawns code-reviewer:
- Show visual indicator: "Dispatching code review subagent..."
- Show when subagent completes: "Code review complete. Findings below."
- Explain subagent role: "The code-reviewer subagent provides isolated, unbiased PR review."

This transparency builds trust and helps users understand what's happening.

---

**I2: Cross-ref remapping** → **PRIORITY (broken links = broken trust)**

Architect identifies cross-ref dependencies. UX impact: **If links break, users lose confidence in the tool.**

**User scenario:**
1. User triggers debugging-methodology
2. Skill references `superpowers:test-driven-development` (cross-ref)
3. Cross-ref fails (superpowers disabled)
4. Skill fails with: "Unable to load referenced skill"
5. User: "This is broken. I'm going back to v1.3.0"

**Users don't forgive broken links.** They assume the whole plugin is unreliable.

**Mitigation:** Architect's acceptance criterion (map all cross-refs before absorption) should include a user-facing test:
- Disable superpowers
- Trigger all 4 new skills
- Verify zero "referenced skill not found" errors
- Verify graceful fallback if optional references missing

---

## Position Changes

### Initial Position
- C1 (zero migration guidance): CRITICAL — users abandoned mid-upgrade
- C2 (trigger collision): CRITICAL — unpredictable behavior breaks mental models
- C3 (no onboarding): HIGH — users don't know features exist

### After Cross-Examination
- **C1 elevated:** Security + Performance both frame migration guide as a technical control (not just UX). This is now a **compound critical** affecting security, performance, and UX.
- **C2 elevated:** Security + Performance + Architect all agree trigger collision is a blocker. Command-based mitigation is the solution.
- **C3 unchanged:** Still high, but Architect's contract spec + examples address it.

**New concern:**
- **Philosophy vs user convenience** (from Architect C1): I disagree with Architect's rejection on philosophical grounds. Users prefer convenience. This is a **strategic decision** for Cian, not an architectural flaw.

---

## New Insights

1. **Error experience is security UX:** Security's Python rewrite improves both security (no injection) and error messages (clearer failure modes). Good security often means good UX.

2. **Command namespace as power user feature:** Performance and Architect both endorse commands for precision. This is a **user segmentation strategy** — novices use natural language, experts use commands. Document this in README.

3. **Trust through transparency:** Agent isolation (Security C3) + user-facing transparency (my addition) = trust. Users trust tools they understand.

---

## Revised Quality Score

| Dimension | Round 1 Score | Round 2 Score | Change |
|-----------|--------------|---------------|--------|
| Learnability | 2 | 2.5 | **Improved** — command namespace clarifies intent |
| Discoverability | 2 | 3 | **Improved** — Architect's contract specs + examples help discovery |
| Error Recovery | 1 | 2 | **Improved** — migration guide + rollback procedure added |
| Cognitive Load | 3 | 3.5 | **Improved** — consistent naming reduces mental model complexity |
| Feedback | 3 | 3.5 | **Improved** — subagent transparency, error messages, examples |

**Revised Aggregate:** 2.9/5 (was 2.2) — **Significantly improved**

**Reason:** Cross-examination revealed that other perspectives' mitigations (Python rewrite, command namespace, agent transparency) all improve UX. The spec is better than I initially assessed IF these mitigations are adopted.

---

## Disagreement Deep-Dive

**With Architect on C1 (philosophy violation):**

Architect rejects on principle: "Methodology plugins shouldn't bundle execution tactics." I counter: "Users don't care about plugin philosophy — they want fewer steps to get work done."

**Where we agree:**
- This changes SDD's scope
- Maintenance burden increases

**Where we disagree:**
- Architect: Purity matters, scope expansion is wrong → REJECT
- Me: User convenience matters, philosophy is secondary → APPROVE (if user-facing docs are good)

**User data to resolve this:**
Survey existing SDD users:
1. "Would you prefer one plugin (SDD with built-in debugging/PR tools) or two plugins (SDD + superpowers)?"
2. "Does it matter to you whether SDD is philosophically 'pure' or pragmatically comprehensive?"

**Prediction:** 80%+ users prefer one plugin. Philosophy doesn't resonate with users.

**Recommendation:** Let user preference guide the decision, not architectural purity.

---

## Escalation Items

**To Human Decision:**

1. **User convenience vs architectural purity** — Is Cian willing to sacrifice some philosophical coherence for user convenience? This is a product positioning question, not a technical one.

2. **Command namespace publicity** — Should commands be the "official" way to invoke skills, with natural language as a convenience fallback? Or vice versa? This affects docs and marketing.

3. **Subagent transparency level** — How much should users see of subagent operations? (Silent, indicator, full transcript?) This affects trust and debugging.

---

## Final Recommendation

**APPROVE with comprehensive user-facing documentation.**

Required additions:
1. **Migration guide** (my C1 template)
2. **Command namespace docs** (my C2 mitigation)
3. **Superseded section** in COMPANIONS.md (my I2)
4. **Onboarding section** in README (my C3)
5. **Examples** for all 4 new skills (my S2)

**User-centered gates:**
- Gate 1: After first 2 skills, test with 3 users (can they trigger skills correctly?)
- Gate 2: After all 4 skills, user acceptance test (are they as good as superpowers?)

**My vote if forced today:** APPROVE (with docs)

**Rationale:** The spec improves user experience (fewer plugins, fewer install steps, unified workflow). The technical concerns (security, performance, architecture) are valid but solvable. **User convenience wins.**

**Dissent from Architect's REJECT:** I respect the philosophical concern but prioritize user needs. SDD's value is in helping users ship features, not in maintaining architectural purity. If consolidation serves users better, that's the right call.
