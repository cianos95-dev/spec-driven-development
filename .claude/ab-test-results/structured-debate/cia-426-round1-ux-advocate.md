# Round 1: UX Advocate (Green Team) — CIA-426

**Persona:** UX Advocate — User journey, error experience, cognitive load, discoverability

**Stance:** If users can't find it, it doesn't exist. If users don't understand it, it's broken.

---

## Critical Findings

### C1. Zero migration guidance creates abandoned workflow state for existing users

**Severity:** CRITICAL (user trust)

The spec says superpowers "can be disabled" but provides no user-facing documentation for the migration path. Users who currently rely on superpowers will experience:

**Migration Day Zero:**
1. User upgrades SDD from 1.3.0 to 2.0.0 (or 1.4.0)
2. COMPANIONS.md no longer recommends superpowers (spec: "remove Tier 3 entries")
3. User is unsure: Should I uninstall superpowers? Will my workflows break?

**Without guidance:**
- User keeps both plugins installed → dual-plugin scenario, skill collisions, 2x matching cost (Performance I3)
- User uninstalls superpowers → fears losing worktree management and parallel dispatch features (non-absorbed superpowers content)
- User does nothing → confusion when "review" prompt sometimes fires adversarial-review, sometimes pr-dispatch

**What's missing:**
- **Migration checklist** — "Before disabling superpowers: verify you don't use X, Y, Z features"
- **Compatibility matrix** — Table showing which superpowers skills are absorbed vs still needed
- **Rollback procedure** — If issues arise, how to revert to 1.3.0 + superpowers
- **Version-specific docs** — COMPANIONS.md should say "For SDD v1.x, install superpowers. For SDD v2.x, superpowers Tier 3 skills are built-in."

**User impact:**
This is a breaking change disguised as a feature addition. Users don't know it's breaking until after upgrade.

**Mitigation:**
Add user-facing migration guide:
```markdown
## Migration Guide: SDD v2.0

### What Changed
SDD v2.0 absorbs 4 superpowers skills natively:
- systematic-debugging → sdd:debugging-methodology
- brainstorming → sdd:ideation
- requesting-code-review → sdd:pr-dispatch
- receiving-code-review → sdd:review-response

### Should You Keep superpowers?
**Keep if you use:**
- Git worktrees (sdd:worktree-create)
- Parallel agent dispatch (sdd:parallel-agents)

**Uninstall if you only used:**
- Debugging, brainstorming, PR dispatch/response
- You can now disable superpowers without losing these capabilities

### How to Migrate
1. Upgrade SDD: `claude plugins update spec-driven-development`
2. Test workflows: Try "debug this issue", "help me brainstorm", "review this PR"
3. If all work: `claude plugins remove superpowers` (optional)
4. If issues: Report to GitHub, reinstall superpowers as temporary workaround
```

This goes in README.md "Upgrading" section or a new `MIGRATION.md` file.

---

### C2. Trigger phrase collision creates unpredictable skill resolution — users cannot build mental models

**Severity:** CRITICAL (learnability)

Users learn tools by building mental models: "When I say X, Y happens." Skill matching collisions break this.

**Scenario 1: Review collision**
- User (Week 1): "Review this spec" → adversarial-review fires (Stage 4, pre-implementation)
- User (Week 2): "Review this PR" → pr-dispatch fires (Stage 6, post-implementation)
- User (Week 3): "Review this code" → ??? (ambiguous, could match either)

**Scenario 2: Brainstorm collision**
- User: "Help me brainstorm this feature"
- Could match: prfaq-methodology (structured PR/FAQ) OR ideation (divergent exploration)
- User doesn't know which will fire until after the agent responds

**Why this is a UX failure:**
Users cannot predict behavior. They resort to trial-and-error ("let me try asking differently"). This is learned helplessness, not learned mastery.

**The root cause:** Generic trigger phrases like "review", "brainstorm", "debug" are claimed by multiple skills without namespace discipline.

**Mitigation:**
Teach users explicit commands:
- Stage 4: `/sdd:review` (spec review) — never collides
- Stage 6: `/sdd:pr-review` (new command, unambiguous)
- Stage 0: `/sdd:brainstorm` (new command) vs `/sdd:write-prfaq` (structured spec)

Natural language remains available but is explicitly non-deterministic. Power users learn commands for precision.

Add to README.md:
```markdown
## Skill vs Command Disambiguation

SDD skills fire automatically on natural language. Commands fire explicitly.

| When | Use This | Not This |
|------|----------|----------|
| You want spec review (Stage 4) | `/sdd:review` or "review my spec" | "review" (ambiguous) |
| You want PR review (Stage 6) | `/sdd:pr-review` or "review this PR" | "review this code" (ambiguous) |
| You want divergent ideation | `/sdd:brainstorm` or "brainstorm ideas" | "help me brainstorm" (may hit prfaq) |
| You want structured spec | `/sdd:write-prfaq` | "brainstorm a spec" (ambiguous) |
```

---

### C3. No onboarding experience for users unfamiliar with superpowers

**Severity:** HIGH (accessibility)

The spec assumes users know what systematic-debugging, brainstorming, requesting-code-review, and receiving-code-review *are*. But:

1. **New SDD users** have never used superpowers → don't know what they're gaining
2. **Existing SDD users** may have skipped superpowers → don't know these skills exist until they accidentally trigger one

**Example: debugging-methodology**
- User hits an obscure bug, spends 30 minutes manually debugging
- User doesn't know `/sdd:debug` exists (if command added) or that saying "help me debug" would fire the skill
- User finally Googles "Claude Code debugging help", finds superpowers plugin (now deprecated), gets confused

**Discoverability gap:**
- No "getting started" that mentions debugging, ideation, PR workflows
- No examples in `examples/` showing these skills in action
- Skills are invisible until user stumbles into trigger phrase

**Mitigation:**
Add to README.md "Getting Started" section:
```markdown
### Stage-by-Stage Workflows

**Stage 0 (Ideation):**
Try: "Help me brainstorm a feature for user authentication"
Skill: `sdd:ideation` surfaces divergent ideas before structured spec writing

**Stage 5-6 (Implementation & Debugging):**
Try: "I have a flaky test, help me debug"
Skill: `sdd:debugging-methodology` guides root cause analysis

**Stage 6 (PR Dispatch):**
Try: "Review this PR: <URL>"
Skill: `sdd:pr-dispatch` coordinates code-level review

**Stage 6 (Review Response):**
Try: "How should I respond to this PR feedback: <comment>"
Skill: `sdd:review-response` teaches verify-before-implement discipline
```

Also add 4 new examples:
- `examples/sample-debug-session.md`
- `examples/sample-ideation-output.md`
- `examples/sample-pr-dispatch.md`
- `examples/sample-review-response.md`

---

## Important Findings

### I1. Skill frontmatter descriptions are user-facing but spec doesn't address clarity

**Severity:** MEDIUM (first impression)

The codebase scan shows skill frontmatter includes a `description` field with trigger phrases. Example from execution-engine:

```yaml
description: |
  Autonomous task execution loop powered by a stop hook...
  Trigger with phrases like "how does the execution loop work", "task loop configuration"...
```

This is user-facing — it appears in skill listings, help text, and potentially IDE autocomplete. The spec says "4 new skill files" but does not specify description quality standards.

**Bad descriptions confuse users:**
- Too technical: "Implements root cause tracing via hypothesis-driven debugging protocol"
- Too vague: "Helps with debugging tasks"
- Wrong triggers: "Debug anything" (overpromises, collides with all debugging contexts)

**Mitigation:**
Add acceptance criterion: "Each skill's frontmatter description must:
1. Start with user benefit (not implementation detail)
2. List 3-5 concrete trigger phrases
3. State which SDD stage it supports
4. Be readable at 8th-grade level (no jargon without definition)"

Example:
```yaml
---
name: debugging-methodology
description: |
  Guides systematic root cause investigation when tests fail or behavior is unexpected.
  Use during Stage 5-6 (Implementation) when stuck on hard-to-reproduce bugs.
  Trigger with: "help me debug", "test is flaky", "unexpected behavior", "root cause analysis"
---
```

---

### I2. COMPANIONS.md "superseded" concept is introduced without precedent

**Severity:** MEDIUM (convention)

The spec says to "remove superpowers Tier 3 entries" from COMPANIONS.md. But the file currently has no "superseded" section. If superpowers row is simply deleted:

1. Users browsing GitHub history won't see why superpowers was removed
2. Search engines indexing old versions will show contradictory advice
3. Users who installed superpowers based on v1.3.0 docs will be confused

**Better UX:** Add a "Superseded Companions" section at the bottom:

```markdown
## Superseded Companions

These plugins were previously recommended but their functionality is now built into SDD.

| Plugin | Was Used For | Now Built-In As | Since Version |
|--------|-------------|----------------|---------------|
| superpowers (Tier 3 skills) | Debugging, ideation, PR dispatch/response | debugging-methodology, ideation, pr-dispatch, review-response | v2.0.0 |

**Note:** superpowers Tier 1-2 skills (worktrees, parallel agents) remain valuable companions if you need those features.
```

This preserves context and helps users understand the transition.

---

### I3. Brainstorming → ideation renaming loses familiar term

**Severity:** MEDIUM (mental model mismatch)

The superpowers skill is called "brainstorming" (common term, familiar to all users). The SDD version is called "ideation" (design jargon, less familiar).

**User impact:**
- User searches documentation for "brainstorm" → finds nothing
- User says "help me brainstorm" → may not match "ideation" trigger phrases if poorly written
- User sees "ideation" in skill list → unclear what it does (brainstorm? plan? design?)

**Alternative naming:**
- `brainstorming-facilitation` — keeps familiar term, adds descriptor
- `divergent-ideation` — clarifies it's pre-spec exploration
- `ideation-workshop` — frames it as a structured activity

**Mitigation:**
Either rename to `brainstorming-facilitation` OR ensure ideation's triggers explicitly include "brainstorm", "brainstorming", "ideation" in skill description.

---

## Consider

### S1. Execution mode `quick` signals "this is easy" but scope is complex

**Severity:** LOW (expectation management)

Users reading the issue will see `exec:quick` and assume:
- This is a simple change
- Agent can do it in one sitting
- No review gates needed

But the scope (4 skills, 3 doc updates, cross-ref remapping, trigger phrase design) suggests `exec:checkpoint` or `exec:tdd`.

**User impact:** If the agent rushes through implementation to meet "quick" expectation, quality suffers. User discovers bugs later (broken cross-refs, skill collisions) and loses trust.

**Mitigation:** Execution mode is set by humans, not the spec. But spec should signal complexity honestly. Add note: "Though marked quick, this requires careful trigger phrase design and cross-ref auditing. Implementer should pause after first 2 skills to verify no regressions."

---

### S2. No examples for absorbed skills creates "show don't tell" gap

**Severity:** LOW (learning curve)

SDD's `examples/` directory shows sample outputs. New skills should have examples too:
- What does debugging-methodology output look like?
- What does ideation produce (bullet list? mermaid diagram? structured table)?
- What does pr-dispatch return (formatted PR comment? Linear update?)?

Without examples, users must experiment to learn. Examples accelerate learning.

**Mitigation:** Add to acceptance criteria: "Create examples/ files for each new skill showing realistic input/output"

---

## Quality Score

| Dimension | Score (1-5) | Justification |
|-----------|-------------|---------------|
| **Learnability** | 2 | Trigger collisions prevent mental model building. No onboarding for new skills. |
| **Discoverability** | 2 | Skills invisible until accidentally triggered. No "getting started" mentions them. |
| **Error Recovery** | 1 | Zero migration guidance. Users don't know how to rollback or troubleshoot. |
| **Cognitive Load** | 3 | Simple skill names, but ambiguous triggers and dual-plugin scenarios add confusion. |
| **Feedback** | 3 | Skill descriptions provide some feedback, but no examples or user testing. |

**Aggregate UX Score:** 2.2/5 (Below Acceptable — poor onboarding and recovery)

---

## What This Spec Gets Right

1. **High/Medium priority split** — Signals which skills matter most to users
2. **Stage mapping in scope table** — Shows users where skills fit in their workflow
3. **Bounded scope** — 4 skills is learnable (not overwhelming)

---

## Recommendation

**REVISE with user-facing documentation.**

The spec is implementer-focused (what to build) but ignores user-facing concerns (how users discover, learn, and recover).

Required additions:
1. **Migration guide** — Checklist for existing superpowers users
2. **Command disambiguation** — `/sdd:pr-review`, `/sdd:brainstorm` for precision
3. **Onboarding section** — Stage-by-stage workflow examples in README
4. **Superseded section** — COMPANIONS.md context preservation
5. **Examples** — Sample outputs for each new skill

Without these, users experience a silent breaking change with no support materials. This erodes trust.

**Conditional approval:** If user-facing docs are added and trigger phrase namespace is designed (with Architect's input), this is viable.
