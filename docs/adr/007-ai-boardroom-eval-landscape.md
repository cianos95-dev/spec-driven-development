# ADR-007: AI Boardroom Concept & Eval Platform Landscape

**Status:** Accepted
**Date:** 2026-02-24
**Issue:** CIA-686
**Author:** Tembo (automated research spike)

## Context

CCC implements a multi-persona adversarial review system with 4 specialized reviewer agents (Security Skeptic, Performance Pragmatist, Architectural Purist, UX Advocate), a debate-synthesizer, and 8 review architecture options. This spike investigated whether the "AI Boardroom" pattern or adjacent multi-agent deliberation frameworks offer improvements worth adopting.

## Research Areas

### 1. Ali Miller's AI Boardroom Concept

The term "AI Boardroom" does not refer to a specific named framework by Ali Miller. The closest match is **"The Artificially Intelligent Boardroom"** — a Stanford research paper by Larcker, Seru, Tayan & Yoler (March 2025, Rock Center Working Paper CL110) examining how AI reshapes corporate board governance.

**Key contribution to CCC:** The concept of **"epistemic capture"** — where decision-makers cede knowledge authority to AI outputs, eroding information heterogeneity. This is the theoretical grounding for why multi-model diversity (Option G) matters: single-model personas risk algorithmic groupthink despite different prompts.

**Verdict:** Governance framework, not a multi-agent architecture. Most useful as theoretical backing for existing Option G design.

### 2. AI Council Pattern — Multi-Agent Deliberation

Six open-source implementations were found, all sharing a 3-phase architecture:

1. **Independent elicitation** — agents respond in isolation
2. **Cross-examination** — agents critique each other (anonymized in best implementations)
3. **Synthesis** — separate agent consolidates output

CCC already implements this pattern via Option F (structured debate). Two gaps identified:

- **"Fresh Eyes" validation** (from AI Council Framework): a context-free agent reviews synthesis output to catch groupthink. Low-effort, high-value addition.
- **Debate round limits**: "Talk Isn't Always Cheap" (Wynn et al., 2025) shows extended debate decreases accuracy. CCC's 2-round limit is stricter than the recommended 3-round cap — this is actually a strength.

### 3. Value Realization Framework

CCC has strong output quality metrics (42% unique finding rate, 4.6/5 specificity, 5.4% false positive rate) but lacks:

- **Process efficiency metrics** — token cost, time to Gate 2
- **Downstream impact metrics** — defect escape rate from Gate 2 → Gate 3

### 4. PersonaGym and Similar Frameworks

PersonaGym (EMNLP 2025) measures persona *adherence*, not persona *effectiveness*. Wrong fit for CCC.

Most relevant frameworks:
- **ReviewerToo** — AI peer review with reviewer personas (81.8% accuracy vs 83.9% human)
- **ChatEval** (ICLR 2024) — multi-agent debate improves eval accuracy by 6.2-16.3%
- **PersonaMatrix DCI** — Diversity-Coverage Index for measuring inter-persona diversity

## Decision

**CONDITIONAL GO** — Adopt selectively, don't rebuild.

### Adopt (low-effort, high-value)

1. **"Fresh Eyes" validation step** — post-synthesis check by context-free agent
2. **Token/cost instrumentation** — track per-review resource consumption
3. **Downstream defect escape tracking** — link Gate 2 findings to Gate 3 findings

### Do NOT adopt

1. **PersonaGym** — measures adherence, not effectiveness
2. **Full AI Council Framework** — CCC's architecture is already more sophisticated
3. **Anonymized cross-examination** — named personas serve traceability purpose

### Evaluate further

1. **ReviewerToo methodology** — benchmark CCC personas against human reviewers
2. **PersonaMatrix DCI metric** — quantify persona diversity
3. **ChatEval communication strategies** — monitor prompt diversity maintenance

## Consequences

- No architectural changes required
- Three low-effort improvements identified for backlog
- Theoretical grounding established for multi-model diversity (Option G)
- Measurement gaps identified for future instrumentation work

## Sources

- [The Artificially Intelligent Boardroom — Stanford/Harvard Law](https://corpgov.law.harvard.edu/2025/04/08/the-artificially-intelligent-boardroom/)
- [AI Council Framework — GitHub](https://github.com/focuslead/ai-council-framework)
- [LLM Council — Karpathy/GitHub](https://github.com/karpathy/llm-council)
- [Talk Isn't Always Cheap — arXiv 2509.05396](https://arxiv.org/abs/2509.05396)
- [PersonaGym — EMNLP 2025](https://arxiv.org/abs/2407.18416)
- [ChatEval — ICLR 2024](https://arxiv.org/abs/2308.07201)
- [ReviewerToo — arXiv 2510.08867](https://arxiv.org/abs/2510.08867)
- [PersonaMatrix — arXiv 2509.16449](https://arxiv.org/html/2509.16449v1)
- [LLM-Deliberation — NeurIPS 2024](https://github.com/S-Abdelnabi/LLM-Deliberation)
- [AI Value Realization Framework — GitHub](https://github.com/srivatsan88/AI-Value-Realization-Framework)
