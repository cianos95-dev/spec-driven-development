# Phase 1: Codebase Scan — CIA-426

**Spec:** Build native SDD skills to replace superpowers dependency (Tier 3 reversal)

**Scan Date:** 2026-02-15

---

## Repository Structure

**Root:** `/Users/cianosullivan/Repositories/spec-driven-development/`

**Layout:** v1.3.0 follows Anthropic plugin-dev standard
- `.claude-plugin/` — plugin manifest + marketplace metadata
- `agents/` — 7 agents (spec-author, reviewer, implementer, 4 adversarial personas)
- `commands/` — 12 commands including `/sdd:write-prfaq`, `/sdd:review`, `/sdd:decompose`, `/sdd:start`, `/sdd:close`
- `skills/` — 21 skill directories (24 total including platform-routing, session-exit, ship-state-verification, observability-patterns per ls output)
- `hooks/` — Runtime enforcement hooks
- `examples/` — Sample outputs

---

## Key Files Related to This Spec

### 1. COMPANIONS.md (89 lines)

**Current Content:**
- Documents 13 companion plugins across 5 categories (Process, Domain, Output, SaaS, Meta)
- **superpowers** listed under Process: "Git worktrees, parallel agent dispatch, systematic debugging, brainstorming, code review request/response discipline"
- **Tier 3 Overlap Evaluation** section (lines 76-88):
  - Evaluated 5 skills: `systematic-debugging`, `brainstorming`, `requesting-code-review`, `receiving-code-review`, `code-review-excellence`
  - **All 5 concluded as "Companion"** with explicit rationale
  - Summary: "All 5 evaluated as companions. SDD operates at spec/methodology layer; these skills operate at code/process layer. They complement rather than conflict."
- **Stage mapping** (lines 44-74) shows where each companion fits in the funnel
  - Stage 3: `superpowers:brainstorming` feeds into `/sdd:write-prfaq`
  - Stage 6: `superpowers:systematic-debugging`, `requesting-code-review`, `receiving-code-review`, `code-review-excellence`

**Implications:**
- Will need full rewrite of Tier 3 section
- Funnel mapping must be updated to show SDD-native skills
- superpowers entry must be removed or moved to "superseded" section

---

### 2. marketplace.json (87 lines)

**Current Content:**
- Plugin name: `spec-driven-development`
- Version: `1.3.0`
- Skills array (lines 62-84): Lists 21 skill directories
  - adversarial-review
  - codebase-awareness
  - context-management
  - drift-prevention
  - execution-engine
  - execution-modes
  - hook-enforcement
  - insights-pipeline
  - issue-lifecycle
  - prfaq-methodology
  - project-cleanup
  - quality-scoring
  - research-grounding
  - research-pipeline
  - spec-workflow
  - zotero-workflow
  - parallel-dispatch
  - platform-routing
  - session-exit
  - ship-state-verification
  - observability-patterns

**Implications:**
- Must add 4 new skill directories: `debugging-methodology`, `ideation`, `pr-dispatch`, `review-response`
- Version bump required (1.3.0 → 1.4.0 or 2.0.0 given "full funnel" claim)

---

### 3. README.md (528 lines)

**Current Content:**
- Comprehensive plugin overview with design philosophy
- "Recommended Companion Plugins" section (lines 88-105)
  - Lists superpowers first in table with "Process" category
  - Adds: "Debugging methodology, brainstorming, code review discipline, parallel agents"
- Cross-references COMPANIONS.md for "funnel mapping and overlap evaluation details" (line 105)

**Implications:**
- Companion table must be updated to remove superpowers or note it as superseded
- Design philosophy section may need strengthening to justify "full funnel ownership"

---

### 4. Existing Skill Directories (24 skills)

**Structure Pattern:** Each skill is a directory with:
- `SKILL.md` — frontmatter + main content
- `references/` subdirectory (optional) — supporting materials, protocols, anti-patterns

**Example: execution-engine/**
- `SKILL.md` (296+ lines per earlier analysis)
- `references/replan-protocol.md`
- `references/retry-budget.md`
- `references/configuration.md`
- Potentially more (directory contains 5 items per ls count)

**Frontmatter Pattern:**
```yaml
---
name: execution-engine
description: |
  [Multi-line description with triggers]
---
```

**Implications:**
- New skills must follow this directory + frontmatter convention
- `SKILL.md` must include trigger phrases in description
- Supporting materials should go in `references/` not inline

---

## superpowers Plugin Content Audit

**Source:** Referenced in COMPANIONS.md but not present in SDD repo. Need to audit from external source.

**Known Skills to Absorb:**
1. **systematic-debugging**
   - Prior review (cia-426-generic.md lines 15-17): "1,030 lines across 7 files"
   - Main SKILL.md: 296 lines
   - 6 reference files + 1 shell script (find-polluter.sh)
   - References: root-cause-tracing, defense-in-depth, condition-based-waiting, test-pressure scenarios
   - Internal cross-refs: `superpowers:test-driven-development` (line 179), `superpowers:verification-before-completion` (line 288)

2. **brainstorming**
   - Prior review (cia-426-generic.md line 32): "54 lines"
   - Generic facilitation advice: "ask one question at a time, propose 2-3 approaches, present design in sections"
   - No SDD-specific content
   - Potential overlap with prfaq-methodology (217 lines)

3. **requesting-code-review**
   - Includes agent template: `code-reviewer.md` (subagent prompt)
   - Dispatches PR-level reviews (not spec-level)
   - Internal cross-refs to other superpowers skills unknown

4. **receiving-code-review**
   - Prior review (cia-426-generic.md line 56): Contains tone rules ("NEVER say 'You're absolutely right!'")
   - Core methodology: verify-before-implement, YAGNI pushback
   - Personality directives should be stripped for SDD version

**Gaps:**
- No direct access to superpowers repo in current scan
- Line counts and file structures are from prior review findings
- Cannot verify current superpowers version or recent changes

---

## Potential Skill Name Collisions

**Trigger Phrase Analysis:**

1. **adversarial-review vs. new pr-dispatch**
   - Current adversarial-review description: "review my spec", "is this spec ready"
   - New pr-dispatch will need: "review this code", "review this PR"
   - **Collision risk:** Generic "review" phrase is ambiguous
   - **Resolution needed:** Sharpen trigger phrases, possibly rename to `pr-review-dispatch`

2. **prfaq-methodology vs. new ideation**
   - prfaq-methodology: 217 lines, covers ideation-to-spec conversion
   - New ideation: "Stage 0 pre-spec" but unclear handoff boundary
   - **Collision risk:** User says "help me brainstorm" — which skill fires?
   - **Resolution needed:** Define explicit handoff (ideation → feeds into `/sdd:write-prfaq`)

---

## Agent Directory (Not Mentioned in Spec)

**Current agents/ contents:**
- spec-author.md
- reviewer.md
- implementer.md
- reviewer-security-skeptic.md
- reviewer-performance-pragmatist.md
- reviewer-architectural-purist.md
- reviewer-ux-advocate.md

**Implication from requesting-code-review:**
- Source skill includes `code-reviewer.md` agent template
- Spec does not address where to place this
- Should go in `agents/` directory, not embedded in skill
- marketplace.json has an `agents` array (lines 53-61) — must register there

---

## Cross-Reference Dependencies

**Known Internal superpowers References:**
1. systematic-debugging → `superpowers:test-driven-development` (line 179)
2. systematic-debugging → `superpowers:verification-before-completion` (line 288)

**Unknown:**
- What other internal cross-refs exist in requesting-code-review, receiving-code-review, brainstorming?
- Do any reference external plugins (developer-essentials, etc.)?

**SDD Equivalents to Map:**
- `test-driven-development` → likely `execution-modes` (TDD mode) or standalone TDD content
- `verification-before-completion` → likely `quality-scoring` or `ship-state-verification`

---

## Acceptance Criteria Gap Analysis

**Spec says:**
- [ ] 4 new skill files in `skills/`
- [ ] Each skill positioned in SDD funnel with stage reference
- [ ] Registered in marketplace.json
- [ ] COMPANIONS.md updated to remove superpowers Tier 3 entries
- [ ] superpowers plugin can be disabled without losing SDD workflow capability

**Codebase reveals:**
- "4 new skill files" should be "4 new skill **directories**" (each with SKILL.md + references/)
- No test procedure defined for "can be disabled without losing capability"
- No mention of agents/ directory for code-reviewer.md template
- No version bump specified (currently 1.3.0)
- No migration guidance for users with both plugins installed

---

## Supporting Material Inventory Required

**Systematic-debugging (1,030 lines):**
- SKILL.md (296 lines)
- root-cause-tracing (?)
- defense-in-depth (?)
- condition-based-waiting (?)
- test-pressure scenarios (?)
- find-polluter.sh (shell script)
- Unknown: 2 more files to reach 7 total

**Requesting-code-review:**
- SKILL.md (? lines)
- code-reviewer.md agent template (? lines)

**Brainstorming:**
- SKILL.md (54 lines)
- No supporting materials

**Receiving-code-review:**
- SKILL.md (? lines)
- Unknown if supporting materials exist

**Total Content Estimate:** ~1,200+ lines of source material across 4 skills + agent template + shell script

---

## Test Strategy Gaps

**Acceptance criterion:** "superpowers plugin can be disabled without losing any SDD workflow capability"

**No test procedure defined. Suggested:**
1. Grep entire `skills/` for `superpowers:` — zero results
2. Run `/sdd:self-test` — confirm no skill resolution failures
3. Attempt Stage 0-8 workflow with superpowers disabled
4. Verify all 4 new skills fire on appropriate trigger phrases

**Current self-test command:** Listed in commands array but implementation unknown

---

## Execution Mode Inconsistency

**Spec:** `exec:quick` with 8-point estimate

**Reality Check:**
- 4 skill directories to create
- 1,200+ lines of source material to absorb/rewrite
- Trigger phrase deconfliction across 21 existing skills
- marketplace.json + COMPANIONS.md + README.md updates
- Cross-reference remapping
- Agent directory registration
- Version bump + migration strategy

**Analysis:** This is `exec:checkpoint` territory (high-risk, milestone-gated). Quick mode assumes single-sitting implementation with no verification pauses. The cross-cutting nature (modifying 3 core docs + creating 4 new skills + potential agent registration) warrants gating.

---

## Summary

**What exists:**
- 24 skill directories following standard pattern (SKILL.md + references/)
- marketplace.json v1.3.0 with 21 registered skills
- COMPANIONS.md with Tier 3 evaluation concluding "Companion" for all 5
- 7 agents registered, directory structure present
- Comprehensive README with companion table

**What's missing from spec:**
- Supporting file audit (1,030 lines systematic-debugging alone)
- Trigger phrase deconfliction plan
- Agent directory handling (code-reviewer.md placement)
- Test procedure for "disabled without loss" criterion
- Cross-reference remapping table (superpowers:* → SDD equivalents)
- Version bump strategy (1.4.0 vs 2.0.0)
- Migration guidance for dual-plugin scenarios

**Risk areas:**
1. Skill name collisions (adversarial-review vs pr-dispatch, prfaq-methodology vs ideation)
2. Thin rewrite risk (brainstorming is only 54 lines, mostly generic)
3. Supporting material scope explosion (systematic-debugging has 7 files)
4. Internal cross-reference breakage if not mapped
5. Execution mode underestimate (quick vs checkpoint for cross-cutting change)

**Recommendations for debate:**
- Security: Cross-reference auditing, skill resolution breakage
- Performance: No runtime impact, but maintenance surface doubles
- Architecture: Skill matching collisions, agent directory structure, trigger phrase namespace
- UX: User migration path, dual-plugin scenarios, skill discoverability
