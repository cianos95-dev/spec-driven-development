# Round 1: Architectural Purist Review — CIA-303

**Reviewer:** Architectural Purist (Blue)
**Round:** 1 (Independent Review)
**Date:** 2026-02-15

---

## Architectural Purist Review: CIA-303

**Structural Summary:** The spec proposes a feedback loop architecture (insights -> adaptation -> behavior change) but fails to define clear boundaries between observation, decision-making, and enforcement layers. The attempt to merge five disparate issues has created a conceptually overloaded component with unclear ownership of adaptive behavior.

---

### Critical Findings

- **Boundary Violation: Insights as Both Data Source and Decision Engine**
  - **Impact:** The spec conflates `/insights` (observability data) with the adaptive logic that should consume it. "insights-integration skill" has no defined interface--does it emit structured events, maintain state, or directly mutate thresholds?
  - **Refactoring:** Separate concerns into three components:
    1. `insights-collector` (skill): Parse `/insights` HTML, emit normalized events to stdout (JSON-LD or structured markdown)
    2. `adaptive-policy-engine` (skill): Subscribe to events, evaluate rules, emit threshold updates
    3. `threshold-registry` (new data file): Single source of truth for all dynamic thresholds (drift limits, quality gates, escalation triggers)
  - **Rationale:** Current design creates circular coupling--hooks depend on thresholds, thresholds depend on insights, insights depend on hook execution. Break the cycle with unidirectional data flow.

- **Conflict #1: Circuit Breaker Escalation Has No Owner**
  - **Impact:** `circuit-breaker-post.sh` references exec-mode escalation logic not documented in `execution-modes` skill. Ghost dependency--if execution-modes changes, circuit breaker breaks silently.
  - **Refactoring:**
    1. Create `execution-modes/escalation-policy.json` schema (complexity thresholds -> mode recommendations)
    2. Circuit breaker calls `/sdd:recommend-mode` command (owned by execution-modes skill)
    3. Document escalation contract in both `execution-modes/SKILL.md` and `hooks/hooks.json`

- **Conflict #2: Drift Thresholds Fragmented Across Three Locations**
  - **Impact:** Hook says 20 files, skill says 30 min OR 50% context, spec proposes "dynamic thresholds from insights." Which wins? Drift prevention becomes non-deterministic.
  - **Refactoring:** Consolidate into `config/adaptive-thresholds.json` with source attribution and timestamps. Hook reads this file (single source of truth). Adaptive engine writes updates. Drift-prevention skill documents thresholds as references, not duplicates.

---

### Important Findings

- **Conflict #3: Quality Score Closure Eligibility vs Ownership Precedence Undefined**
  - **Long-term Consequence:** Quality scoring skill says "80+ eligible for closure," ownership rules say "never auto-close Cian's issues." Which layer enforces this?
  - **Approach:** Define responsibility layers: quality-scoring OWNS score calculation, EMITS closure eligibility signal, DOES NOT OWN authorization (ownership check) or action (Linear API call). Add explicit "eligibility != authorization" comment to any closure logic.

- **Conflict #4: PreToolUse Hook is a Stub--Scope Validation Non-Functional**
  - **Long-term Consequence:** The spec proposes "adaptive hooks" that adjust thresholds dynamically, but the pre-execution hook (where scope validation should happen) is a placeholder. Adaptive behavior will only trigger reactively (post-failure), never preventively.
  - **Approach:** Define PreToolUse contract in hooks.json with scope validator implementation. Check estimated output size against available context budget. Emit JSON: `{"allow": false, "suggestion": "Delegate to Task subagent"}`.

- **Naming Inconsistency: "insights-integration" vs "insights-pipeline"**
  - **Long-term Consequence:** Two skills with overlapping names. Developers will confuse them, documentation will diverge, future specs will reference the wrong one.
  - **Approach:** Rename `insights-pipeline` -> `insights-parser` (focuses responsibility: parse /insights HTML -> structured data). Keep new skill as `insights-adapter` (clearer role: adapt methodology rules based on parsed insights).

---

### Consider

- **Extension Point: Insights Event Bus**
  - **Rationale:** Current design assumes single consumer (adaptive engine). Future: observability-patterns Layer 3, external dashboards, retrospective automation. Make `insights-parser` emit to a pub/sub model allowing new consumers without modifying parser.

- **Coupling Risk: Retrospective Automation Depends on Linear Closure Protocol**
  - **Rationale:** Spec says "correlate friction with Linear outcomes"--but Linear closure is governed by ownership rules (CLAUDE.md Stage 7.5). Retrospective skill will need to understand when auto-close succeeded vs. was blocked by human assignment.

- **Missing Abstraction: Threshold Update Protocol**
  - **Rationale:** Adaptive engine will update thresholds, but who validates updates? What if insights suggest "set drift threshold to 5 files" (too aggressive)? Define validation layer with min/max bounds per threshold.

---

### Quality Score (Architecture Lens)

| Dimension | Score (1-5) | Notes |
|-----------|-------------|-------|
| **Coupling** | 2/5 | Insights, hooks, skills, and thresholds are tightly coupled with no clear interfaces. Circular dependencies between adaptive logic and enforcement mechanisms. |
| **Cohesion** | 3/5 | Merging five issues created conceptual overload--"insights-integration" does too many things. Should be three focused components. |
| **API contracts** | 2/5 | No defined contracts for insights -> adapter communication, circuit breaker -> execution-modes escalation, or quality-scoring -> closure authorization. Ghost dependencies. |
| **Extensibility** | 3/5 | Hardcoded HTML parsing limits insights source flexibility. No pub/sub model for future consumers. Threshold schema is extensible, but validation layer missing. |
| **Naming clarity** | 3/5 | "insights-integration" collides with existing "insights-pipeline." "Adaptive hooks" conflates two concepts. Otherwise clear. |

**Overall Architecture Score: 2.6/5** -- Needs significant refactoring to separate concerns and define explicit contracts before implementation.

---

### What the Spec Gets Right (Architecture)

- **Three-Layer Monitoring Stack:** Correctly identifies that structural (cc-plugin-eval), runtime (/insights), and adaptive (this issue) are distinct concerns.

- **Threshold Registry Concept:** Implicitly proposed via "dynamic thresholds from insights data." The idea of a single source of truth for configurable limits is architecturally sound--just needs to be made explicit.

- **Retrospective Automation Coupling to Outcomes:** The insight to correlate friction metrics with Linear issue lifecycle stages shows understanding that methodology effectiveness is measured by outcomes, not just activity.

- **Hook-Based Interception Points:** Reusing existing hook infrastructure rather than creating a parallel notification system avoids duplication.

- **HTML Parsing Pragmatism:** Accepting that `/insights` outputs HTML and building a parser skill rather than waiting for upstream CLI changes is architecturally realistic.

---

**Recommendation**: **REVISE** -- Define explicit contracts and separate concerns before implementation.
