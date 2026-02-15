# Round 1: UX Advocate Review — CIA-303

**Reviewer:** UX Advocate (Green)
**Round:** 1 (Independent Review)
**Date:** 2026-02-15

---

## UX Advocate Review: CIA-303

**User Impact Summary:** This spec introduces powerful adaptive capabilities but creates a **multi-headed hydra** where the same user concern (e.g., "my session is sprawling") can be addressed by 3 different systems (hooks, commands, manual checks) with unclear precedence and no unified mental model. The spec adds 4 new commands and 3 automatic interventions without explaining how a user knows which tool to reach for when.

---

### Critical Findings

- **Circuit breaker auto-escalates exec mode without user consent**: Circuit breaker auto-escalates exec mode on errors, but this behavior isn't documented in the exec-modes skill that users read to understand exec modes.
  - **User impact:** User selects `quick` mode, gets automatic escalation to `checkpoint` mid-session, doesn't understand why their workflow changed.
  - **Suggested improvement:** Either document escalation in exec-modes skill OR make escalation opt-in with a `/sdd:escalate` command and a clear prompt: "3 errors detected. Recommend checkpoint mode. Switch? [Y/n]"

- **Drift detection fires from two different signals with no unified view**: Drift detection fires at 20+ files (hook) vs 30 min / 50% context (skill). These are different signals (uncommitted changes vs time/context pressure) but both address "session sprawl" concern.
  - **User impact:** User gets two different warnings about the same feeling of being overwhelmed. Doesn't know which metric to trust or what action to take.
  - **Suggested improvement:** Unify into a single "Session Health" indicator with composite score. Show: `Session Health: Warning 68% (uncommitted: 23 files, time: 42 min, context: 38%)`. One warning, clear actionable threshold.

- **Quality score vs ownership rules precedence invisible**: Quality score 80+ required for closure, but spec doesn't clarify precedence vs ownership rules (Cian's issues never auto-close, even at 100 score).
  - **User impact:** User sees CIA-123 at Quality: 92, expects auto-close, but it stays open because it's assigned to Cian. No feedback explaining why.
  - **Suggested improvement:** When `/sdd:close` is blocked, show: `Cannot auto-close CIA-123 (Quality: 92): Issue assigned to human owner. See ownership rules: /sdd:config show ownership`

- **`/sdd:insights` 4 modes with no guidance on when to use each**: `/sdd:insights` has 4 modes (archive, review, trend, suggest) but spec doesn't explain when a user would choose each mode.
  - **User impact:** User types `/sdd:insights` and sees 4 options. Guesses wrong, gets irrelevant output, loses trust in the tool.
  - **Suggested improvement:** Add mode descriptions in command help with timing guidance (archive = session end, review = when stuck, trend = weekly, suggest = quarterly).

- **Insights archive has no schema version**: If `/insights` output format changes, old archives become unreadable.
  - **User impact:** User runs `/sdd:insights trend` after a Claude Code update, gets cryptic parsing errors, loses historical data.
  - **Suggested improvement:** Add `schema_version: 1` to archive JSON. On parse, check version. If mismatch: `Archive format outdated. Re-run /sdd:insights archive to refresh.`

---

### Important Findings

- **PreToolUse hook will block without proactive guidance**: PreToolUse hook is a stub that "will eventually block scope violations" but spec doesn't say how users will know they're about to violate scope.
  - **Usability concern:** User starts typing a tool call, PreToolUse fires, blocks it with no warning. User repeats, gets blocked again, frustrated.
  - **Suggested improvement:** Show proactive guidance before block: `Warning: Tool call may violate spec scope (updating CIA-303 but spec is for CIA-299). Continue? [Y/n]`. If user confirms 3x, log drift but allow.

- **Dynamic thresholds change behavior invisibly**: Dynamic thresholds change behavior over time (e.g., drift detection threshold adjusts based on user's session patterns). No UI indicates that thresholds have changed.
  - **Usability concern:** User gets drift warning at 15 files this week, but got it at 25 files last week. Thinks plugin is buggy.
  - **Suggested improvement:** When threshold changes, notify: `Drift threshold adjusted to 15 files (was 25) based on your 7-day pattern of smaller sessions. See /sdd:insights trend for details.`

- **"Retrospective automation" scope undefined**: Spec says "retrospective automation" but doesn't define what gets automated vs what requires human reflection.
  - **Usability concern:** User expects plugin to write full retrospective, gets a 3-bullet skeleton, feels let down.
  - **Suggested improvement:** Clarify scope: "Plugin generates data-driven scaffolding (blockers, tools used, exec mode switches). Human writes interpretation and decisions."

- **References/ read-through metric doesn't surface to user**: References/ read-through metric designed to track if specs are actually being read. But if Claude reads spec, user doesn't know if they need to read it too.
  - **Usability concern:** User assumes Claude handles spec, skips reading it, later confused when implementation doesn't match their mental model.
  - **Suggested improvement:** Add "Spec Status" indicator on `/sdd:start` showing who has read the spec and when.

---

### Consider

- **12 commands is overwhelming**: 12 commands in marketplace.json. For new users, this is overwhelming. No progressive disclosure.
  - **UX enhancement rationale:** Add `/sdd:help` tiers: Tier 1 (Start here: start, go, close), Tier 2 (Spec quality: review, write-prfaq), Tier 3 (Debugging: insights, hygiene, self-test).

- **Quality score breakdown invisible**: Quality score shown as numeric (80+) but rubric dimensions aren't visible to user.
  - **UX enhancement rationale:** Show breakdown: `Quality: 85 (completeness: 90, testability: 80, clarity: 85)`. User knows what to improve.

- **Circuit breaker rules not auditable**: Circuit breaker blocks destructive operations but spec doesn't define what's "destructive."
  - **UX enhancement rationale:** Document breaker rules in `/sdd:config show circuit-breaker`. User can audit and propose exceptions.

- **No temporary hook bypass for emergencies**: Adaptive hooks fire automatically. User has no way to temporarily disable a hook during emergency hotfix.
  - **UX enhancement rationale:** Add `/sdd:hooks pause [hook-name] --for=30m` for temporary bypass with auto-resume.

---

### Quality Score (UX Lens)

| Dimension | Score (1-5) | Notes |
|-----------|-------------|-------|
| User journey | 2 | Multiple overlapping systems (hooks, commands, manual checks) with unclear precedence. No "Session Health" unified view. |
| Error experience | 2 | Circuit breaker blocks without proactive guidance. Archive parse errors lose historical data. No graceful degradation. |
| Cognitive load | 2 | 12 commands, 4 insights modes, 3 drift signals, 5 quality dimensions -- no progressive disclosure or decision tree. |
| Discoverability | 3 | Commands are namespaced (`/sdd:*`) which is good, but no in-tool onboarding or "Start here" guidance. |
| Accessibility | 3 | Text-based commands are screen-reader friendly, but quality scores and thresholds are numeric-only (no semantic labels like "Good" / "Needs work"). |

**Overall UX Score: 2.4/5** -- Powerful but overwhelming. Needs consolidation, clearer mental models, and better feedback loops.

---

### What the Spec Gets Right (UX)

- Using `/insights` data to inform methodology is brilliant -- closes the loop between "what Claude actually does" and "what the plugin recommends."
- Retrospective automation scaffolding respects human judgment while reducing toil.
- Circuit breaker concept is sound -- prevents catastrophic mistakes during high-context sessions.
- Quality scoring makes "good enough to close" objective vs subjective.
- References/ read-through metric tackles the "spec written but never consulted" anti-pattern.

---

**Recommendation**: **REVISE** -- Consolidate drift signals, document circuit breaker escalation, add progressive disclosure.
