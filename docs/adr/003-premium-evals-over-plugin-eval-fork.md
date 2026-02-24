# ADR-003: Premium Eval Tools vs cc-plugin-eval Fork

**Status:** Proposed
**Date:** 2026-02-20
**Context:** CIA-647
**Related:** CIA-632 (persona-aware observability stack), CIA-413 (cc-plugin-eval integration), CIA-573 (EVAL-0 baseline), CIA-610 (Agent SDK nesting guard spike)

## Research Question

For evaluating the CCC plugin: do we need the cc-plugin-eval fork at all if we adopt the premium observability stack (Langfuse + Portkey + Braintrust) from CIA-632 and related issues?

## TL;DR

**No, the premium stack cannot replace cc-plugin-eval.** The tools solve different problems. cc-plugin-eval answers "do plugin components trigger correctly?" while the premium stack answers "how well do they perform once triggered?" The recommendation is to **keep cc-plugin-eval upstream (no fork needed)** and use the premium stack for complementary observability and scoring layers.

---

## 1. What cc-plugin-eval Does (That Nothing Else Does)

cc-plugin-eval is purpose-built for Claude Code plugin validation. Its 4-stage pipeline does something no general-purpose eval tool replicates:

| Stage | What It Does | Unique Value |
|-------|-------------|--------------|
| **1. Analyze** | Parses plugin manifest + YAML to enumerate components, extract trigger descriptions | Domain-specific: understands Claude Code plugin structure |
| **2. Generate** | LLM creates 5+ diverse test prompts per component (direct, paraphrased, edge-case, negative, semantic) | Targeted: generates prompts specifically designed to test trigger accuracy |
| **3. Execute** | Runs prompts via Claude Agent SDK, captures which tools/skills actually fire | Integration: uses SDK tool-capture hooks for programmatic detection |
| **4. Evaluate** | Compares expected vs actual triggers, scores accuracy | Plugin-aware: measures "did the right skill fire?" not just "was the output good?" |

**The core question it answers:** "When a user says X, does skill Y trigger?" This is a **structural discoverability** question, not a quality question.

### What CCC's Static Tests Already Replace

CCC's `tests/test-static-quality.sh` already replaces Stage 1 (structural analysis):
- Manifest-filesystem alignment
- Component counting
- Cross-reference validation
- File naming conventions

This was an intentional design decision (documented in the workflow: "Replaces cc-plugin-eval Stage 1").

### What Remains Unique to Stages 2-4

- **Synthetic prompt generation** targeting specific plugin components
- **Trigger accuracy measurement** (did the right component fire?)
- **Conflict detection** (do two skills fight over the same prompt?)
- **Trigger rate tracking** (are any skills "dormant" — never triggered?)

No premium tool replicates this.

---

## 2. Premium Stack Capabilities Assessment

### Langfuse

**Best at:** Tracing, observability, experiment management, LLM-as-judge scoring

| Capability | Relevant to Plugin Eval? | Notes |
|-----------|-------------------------|-------|
| Trace collection | Yes (Layer 2 runtime) | Records which skills fire in real sessions |
| LLM-as-judge | Partially | Can score output quality, but can't assess trigger correctness |
| Dataset management | Partially | Can store generated test cases, but can't generate them |
| Experiment comparison | Yes | Track eval results over time |
| Custom scores API | Yes | Write back any metric (accuracy, trigger rate) |
| Component-aware analysis | **No** | Has no concept of plugin structure |
| Synthetic prompt generation | **No** | No built-in generator for plugin-specific prompts |

**Verdict:** Strong complement for Layers 2-3 (runtime observability, quality scoring). Cannot replace Stages 2-4 (trigger accuracy testing).

### Braintrust

**Best at:** Evaluation execution, CI/CD integration, LLM-as-judge with rich scorers

| Capability | Relevant to Plugin Eval? | Notes |
|-----------|-------------------------|-------|
| `Eval()` framework | Yes | Can run test prompts and score results |
| Autoevals library | Partially | Factuality, faithfulness, etc. — not trigger accuracy |
| Custom scorers | Yes | Could build trigger-accuracy scorer |
| CI/CD GitHub Action | Yes | PR comments with eval results |
| Dataset management | Yes | Store and version test datasets |
| Experiment tracking | Yes | Compare eval runs over time |
| Loop (synthetic data) | Partially | General-purpose, not plugin-structure-aware |
| Component-aware analysis | **No** | Cannot parse plugin YAML |
| Trigger detection | **No** | No tool-capture hook integration |

**Verdict:** Could serve as the execution backend for Stages 3-4 if you build a custom wrapper for Stages 1-2. But at that point, you're building most of cc-plugin-eval yourself.

### Portkey

**Best at:** API gateway, routing, fallbacks, rate limiting

| Capability | Relevant to Plugin Eval? | Notes |
|-----------|-------------------------|-------|
| Guardrails | Minimally | Boolean safety checks, not quality scoring |
| Multi-provider routing | No | Plugin eval targets Claude specifically |
| Caching | No | Eval runs should not be cached |
| Rate limiting | Marginally | Budget control during eval runs |

**Verdict:** Not relevant to plugin evaluation. Portkey is infrastructure, not eval tooling.

---

## 3. Gap Analysis: What the Premium Stack Cannot Do

The premium stack has a **fundamental blind spot** for plugin evaluation:

```
Premium Stack Capabilities:
  ✅ "Was the LLM output high quality?"
  ✅ "Did the response satisfy the rubric?"
  ✅ "How does this run compare to the baseline?"
  ✅ "What's the cost per evaluation?"

cc-plugin-eval Capabilities:
  ✅ "Did the correct skill/agent/command trigger?"
  ✅ "Are any components dormant (never triggered)?"
  ✅ "Do components conflict (multiple trigger for same prompt)?"
  ✅ "What's the trigger accuracy across all components?"
```

These are **orthogonal concerns**. Quality scoring (premium stack) and trigger accuracy (cc-plugin-eval) answer different questions about plugin health.

### The Hypothetical "Build It on Braintrust" Path

Could you replicate cc-plugin-eval's functionality using Braintrust as the execution layer?

**Yes, technically, but the effort is prohibitive:**

1. You'd need to write a **plugin manifest parser** (Stage 1) — custom code
2. You'd need a **component-aware prompt generator** (Stage 2) — custom code using LLM
3. You'd need **Claude Agent SDK tool-capture integration** (Stage 3) — custom code
4. You'd need a **trigger-accuracy scorer** (Stage 4) — achievable with Braintrust custom scorers
5. You'd wire it all together as a Braintrust `Eval()` pipeline

This is essentially rebuilding cc-plugin-eval from scratch and using Braintrust only for the scoring/tracking layer. The ROI is negative — cc-plugin-eval already exists, is MIT-licensed, and is actively maintained.

---

## 4. Do We Need a Fork?

**No.** The case for forking was based on three assumptions that don't hold:

| Assumed Need | Reality |
|-------------|---------|
| "We need CCC-specific test scenarios" | cc-plugin-eval already generates component-specific scenarios from YAML trigger descriptions. CCC's SKILL.md files provide rich trigger context. |
| "We need Linear integration" | This belongs in CI workflow glue code, not in the eval tool itself. Post-eval actions (labeling, commenting) are workflow concerns. |
| "We need execution-mode-aware routing" | This is an evaluation *criteria* question (add a custom scorer), not a structural eval tool concern. |

### What We Should Do Instead

1. **Use cc-plugin-eval upstream** — pin version in CI, update periodically
2. **Enrich SKILL.md trigger descriptions** — better inputs = better generated scenarios (already planned in CIA-572)
3. **Add a post-eval CI step** that reads cc-plugin-eval output and takes action (label skills, comment on PRs, flag dormant components)
4. **Use Langfuse for Layer 2** runtime observability (complementary, not competing)
5. **Use Braintrust for PR quality scoring** if/when it replaces the current gpt-4o-mini L2 eval (optional upgrade)

---

## 5. What We Can Learn from cc-plugin-eval

Even though we don't need a fork, the tool's architecture validates several CCC patterns and surfaces useful design insights:

### Validated Patterns

1. **Component-level testing is essential** — CCC's 38 skills create a combinatorial trigger space. Without structured eval, dormant/conflicting skills are invisible.
2. **Programmatic detection > LLM judgment** — cc-plugin-eval uses tool-capture hooks first, LLM judgment second. This is more reliable than pure LLM-as-judge approaches.
3. **Cost gating works** — The $50 budget cap and batched session strategy keep eval costs practical (~$15-25 per full run for CCC's scale).
4. **Stage isolation enables incremental CI** — Running Stage 1 on every PR (free) and Stages 2-4 on main only (paid) is a good cost/coverage tradeoff.

### Design Insights to Adopt

1. **Structured trigger taxonomy** — cc-plugin-eval works better with well-defined trigger descriptions. CIA-572 (boundary definitions) directly improves eval quality.
2. **Conflict detection matters** — 38 skills sharing domain vocabulary (meta-tooling) means conflicts are likely. The eval's conflict count metric should feed into CIA-618 (trigger optimization).
3. **Dormant skill detection** — Skills with 0% trigger rate across eval runs are candidates for removal or rewrite. This feeds CIA-617 directly.

---

## 6. Recommended Architecture

```
Layer 0: Static Quality (CI, every PR)
  Tool: tests/test-static-quality.sh
  Cost: $0
  Answers: "Is the plugin structurally valid?"

Layer 1: Trigger Accuracy (CI, main branch + manual)
  Tool: cc-plugin-eval (upstream, no fork)
  Cost: ~$15-25/run
  Answers: "Do components trigger correctly?"

Layer 2: PR Quality (CI, every PR)
  Tool: pr-eval.yml (L1 static + L2 AC adherence)
  Cost: ~$0.05/PR (gpt-4o-mini)
  Answers: "Does this PR satisfy acceptance criteria?"

Layer 3: Runtime Observability (production)
  Tool: Langfuse (from CIA-632 stack)
  Cost: $0-49/mo (self-hosted to cloud)
  Answers: "What happens in real sessions?"

Layer 4: Persona Routing & Multi-Model (production)
  Tool: Portkey gateway (from CIA-632 stack)
  Cost: $0-59/mo
  Answers: "How should requests be routed?"

Layer 5: Quality Benchmarking (periodic, optional)
  Tool: Braintrust (from CIA-632 stack)
  Cost: $0-249/mo
  Answers: "How does output quality trend over time?"
```

Each layer is independent. The premium stack (Layers 3-5) complements but does not replace the eval pipeline (Layers 0-2).

---

## Decision

1. **Do not fork cc-plugin-eval.** Use upstream, pin version.
2. **Do not attempt to replicate cc-plugin-eval with premium tools.** The effort exceeds the value.
3. **Adopt the premium stack (CIA-632) for its intended purpose:** observability, routing, and quality benchmarking — not plugin structural evaluation.
4. **Improve eval inputs** via CIA-572 (boundary definitions) and CIA-618 (trigger optimization) to get better results from cc-plugin-eval without modifying the tool.
5. **Add CI glue** between cc-plugin-eval output and Linear/GitHub for automated issue labeling and PR comments.

## Consequences

- cc-plugin-eval remains a third-party dependency (sjnims/cc-plugin-eval). Monitor for breaking changes via upstream-monitoring.md.
- The premium stack (Langfuse + Portkey + Braintrust) proceeds independently under CIA-632 scope.
- No custom eval tool development needed. Engineering effort redirects to improving skill trigger descriptions (CIA-572) and running the EVAL-0 baseline (CIA-573).
- The CLAUDECODE=1 nesting guard question (CIA-610) remains relevant for running cc-plugin-eval from within Claude Code sessions, independent of this decision.

## References

- [cc-plugin-eval](https://github.com/sjnims/cc-plugin-eval) — MIT licensed, 4-stage plugin eval pipeline
- CIA-632: Build persona-aware observability and routing stack
- CIA-413: Integrate cc-plugin-eval for automated plugin trigger validation
- CIA-573: Run cc-plugin-eval full pipeline against CCC v1.8.3
- CIA-610: Spike: Evaluate Agent SDK for cc-plugin-eval nesting guard
- CIA-572: Add boundary definitions and uncertainty guidance to all 36 CCC skills
- CIA-618: Optimize skill trigger descriptions from conflict data
- CIA-617: Address dormant skills from EVAL-0 and PostHog data
