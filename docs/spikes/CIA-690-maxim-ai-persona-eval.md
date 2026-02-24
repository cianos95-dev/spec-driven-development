# Spike: Maxim AI Eval for Persona Adherence (CIA-690)

**Status:** Complete
**Date:** 2026-02-24
**Issue:** CIA-690
**Related:** CIA-632 (observability stack), ADR-003 (premium evals vs plugin-eval fork)

## Problem Statement

CCC's adversarial review system uses 4 specialized personas (Security Skeptic, Architectural Purist, Performance Pragmatist, UX Advocate) that produce structured review outputs with domain-specific quality scores, severity-rated findings, and Review Decision Records. We need an eval platform to measure whether these personas stay in character and produce high-quality, domain-specific reviews.

### What "Persona Adherence" Means for CCC

Persona adherence is measurable across several dimensions:

1. **Domain focus** — Does the Security Skeptic only raise security concerns, or does it drift into architecture?
2. **Finding specificity** — Are findings evidence-based with spec section citations (per SKILL.md requirement)?
3. **Severity calibration** — Are Critical/Important/Consider ratings appropriately applied?
4. **Output structure compliance** — Does the review follow the mandated format (Quality Score table, RDR, recommendation)?
5. **Behavioral rules** — Does each persona follow its defined anti-patterns (e.g., "never be vague," "quantify where possible")?
6. **Cross-persona independence** — Do 4 personas produce genuinely distinct findings, or do they converge on the same issues?

### Scale

- ~50-100 evals/week (review outputs to score)
- 4 personas × each review = 4 outputs to evaluate per spec
- Quality scores are 1-5 per dimension (5 dimensions per persona)

---

## Platform Comparison

### Evaluation Criteria

| # | Criterion | Weight |
|---|-----------|--------|
| 1 | Can it score persona adherence (stay-in-character)? | Critical |
| 2 | Custom rubrics/scorers support? | Critical |
| 3 | Integration path for Claude Code plugin output? | Important |
| 4 | Pricing at our scale (~50-100 evals/week)? | Important |
| 5 | API key injection via LiteLLM proxy vs direct model access? | Important |

---

### 1. Maxim AI

**Website:** [getmaxim.ai](https://www.getmaxim.ai/)

| Criterion | Assessment | Score |
|-----------|-----------|-------|
| Persona adherence scoring | **Strong.** Custom LLM-as-judge evaluators with user-defined criteria. Agent simulation can test personas across diverse scenarios. Style evaluators can check tone/voice adherence. | 4/5 |
| Custom rubrics/scorers | **Excellent.** Supports LLM-as-judge, statistical, programmatic, and human evaluators. Pre-built evaluator store + fully custom evaluators. No-code UI for non-technical users. | 5/5 |
| Integration path | **Good.** SDKs in Python, TypeScript, Java, Go. CI/CD integration (GitHub Actions, Jenkins). REST API. Framework-agnostic — works with Claude, OpenAI, etc. Would require wrapping review output capture. | 4/5 |
| Pricing (50-100 evals/week) | **Affordable.** Free tier: 3 seats, 10K logs/mo. Professional: $29/seat/mo. At 50-100 evals/week (~200-400/mo), likely fits within Professional plan for 2-3 seats = **$58-87/mo**. | 4/5 |
| LiteLLM proxy compatibility | **Mixed.** Maxim has its own Bifrost gateway (OpenAI-compatible, faster than LiteLLM). For eval judge models, Maxim likely uses its own model access. May require Maxim API key + model provider key, not routing through LiteLLM. | 3/5 |

**Standout:** Agent simulation feature can generate synthetic review scenarios to test personas at scale. Multi-turn conversation eval is native. Bifrost gateway is open-source (Apache 2.0) and could replace our LiteLLM proxy if needed.

**Concern:** Bifrost competes with our existing LiteLLM proxy rather than integrating through it. Dual-gateway complexity.

---

### 2. Braintrust

**Website:** [braintrust.dev](https://www.braintrust.dev/)

| Criterion | Assessment | Score |
|-----------|-----------|-------|
| Persona adherence scoring | **Strong.** LLM-as-judge with custom rubrics. Conditional scoring (different scorers per persona). Loop generates custom scorers from natural language. | 4/5 |
| Custom rubrics/scorers | **Excellent.** 25+ built-in scorers + custom code-based + LLM-as-judge + AI-generated (Loop). Open-source autoevals library. Playground for testing scorers. | 5/5 |
| Integration path | **Good.** Native GitHub Action for PR comments. `Eval()` function in Python/TypeScript. Custom providers for any model endpoint. Already evaluated in ADR-003 for Layer 5 (Quality Benchmarking). | 4/5 |
| Pricing (50-100 evals/week) | **Free tier sufficient.** Free: 1M trace spans/mo, 10K eval runs. At 200-400 evals/mo, well within free tier. Pro: $249/mo if you need advanced features. | 5/5 |
| LiteLLM proxy compatibility | **Excellent.** Native LiteLLM integration (`litellm.callbacks = ["braintrust"]`). Custom provider configuration supports any OpenAI-compatible endpoint. Can route judge models through LiteLLM proxy. | 5/5 |

**Standout:** Already evaluated in ADR-003 as part of the premium stack (Layer 5). Free tier is generous enough for our scale. LiteLLM integration is first-class. Custom providers mean we can point eval judge calls through our LiteLLM proxy.

**Concern:** No native agent simulation. Less focused on persona/character evaluation — it's a general eval platform. Would need to build persona-adherence scorers from scratch.

---

### 3. Patronus AI

**Website:** [patronus.ai](https://www.patronus.ai/)

| Criterion | Assessment | Score |
|-----------|-----------|-------|
| Persona adherence scoring | **Moderate.** GLIDER model (3B params) supports custom criteria. Judge evaluators with natural-language pass criteria. Style evaluators for tone/voice. But designed more for safety/compliance than persona adherence. | 3/5 |
| Custom rubrics/scorers | **Good.** GLIDER + Judge evaluators with custom rubrics. Evaluator Playground for testing. Active learning improves judges over time. Python SDK with `@evaluator()` decorator. 8K context window on GLIDER may limit long review outputs. | 4/5 |
| Integration path | **Moderate.** Python/TypeScript SDKs. Integrations with LangChain, LlamaIndex, LiteLLM, Dify. API-first (`/v1/evaluate` endpoint). No native CI/CD GitHub Action found. | 3/5 |
| Pricing (50-100 evals/week) | **Moderate.** Pay-per-call: $10-20/1K API calls. At 200-400 evals/mo with ~4 evaluator calls each = 800-1,600 calls/mo = **$8-32/mo**. $5 free credits to start. | 4/5 |
| LiteLLM proxy compatibility | **Good.** Native LiteLLM integration documented. But GLIDER and Judge are Patronus-hosted models — the eval judge itself doesn't route through your proxy. You'd need Patronus API keys separately. | 3/5 |

**Standout:** GLIDER is a specialized evaluation model (not generic LLM-as-judge), potentially more consistent for scoring. Active learning lets you improve evaluators with thumbs up/down over time. Percival agent debugger could complement persona eval.

**Concern:** 8K context window on GLIDER is tight for full review outputs (our debate synthesis outputs can be 3-5K tokens). More focused on safety/hallucination than persona adherence. Less ecosystem integration than Braintrust.

---

### 4. LangSmith

**Website:** [langchain.com/langsmith](https://www.langchain.com/langsmith)

| Criterion | Assessment | Score |
|-----------|-----------|-------|
| Persona adherence scoring | **Moderate.** LLM-as-judge with custom criteria. Pairwise comparison for A/B testing persona quality. Human annotation queues. But no native persona/character concept. | 3/5 |
| Custom rubrics/scorers | **Good.** Code-based, LLM-as-judge, heuristic, and human evaluators. UI-based evaluator setup (no-code). Pre-built: Hallucination, Correctness, Conciseness. Few-shot learning. Custom prompts with variable mapping. | 4/5 |
| Integration path | **Moderate.** Framework-agnostic (doesn't require LangChain). Python/TypeScript SDKs. UI-based dataset management. But strongest when used within LangChain/LangGraph ecosystem, which CCC doesn't use. | 3/5 |
| Pricing (50-100 evals/week) | **Moderate-Expensive.** Free: 5K traces/mo. Plus: 10K traces/mo + $2.50-5.00/1K additional traces. At 200-400 evals/mo, likely free tier. But extended retention is $5/1K traces, adds up at scale. | 3/5 |
| LiteLLM proxy compatibility | **Limited.** LangSmith is an observability/eval platform, not a model gateway. Eval judge models use LangChain's LLM abstractions. Can configure custom LLM providers but not as seamless as Braintrust's LiteLLM callback. | 2/5 |

**Standout:** Strongest observability features (tracing). Good for debugging why a persona drifted. Human annotation queues useful for building ground-truth persona-adherence datasets. Pairwise comparison useful for A/B testing prompt changes.

**Concern:** Ecosystem gravity pulls toward LangChain/LangGraph, which CCC doesn't use. Pricing gets complex at scale with trace tiers. LiteLLM proxy integration is not first-class.

---

### 5. Arize Phoenix

**Website:** [phoenix.arize.com](https://phoenix.arize.com/)

| Criterion | Assessment | Score |
|-----------|-----------|-------|
| Persona adherence scoring | **Moderate.** Custom LLM-as-judge with categorical and numeric classification. Eval Hub for reusable evaluators with version history. But no simulation or persona-specific features. | 3/5 |
| Custom rubrics/scorers | **Good.** LLM-as-judge rubrics in plain language. Categorical (pass/fail) and numeric (1-10) classification. Custom prompt templates. Python/TypeScript. Pre-built templates for RAG eval. | 4/5 |
| Integration path | **Good.** Fully open-source (Apache 2.0), self-hostable. OpenTelemetry-native. Supports Claude/Anthropic as evaluation judge model. Framework-agnostic. MLflow integration. Docker deployment. | 4/5 |
| Pricing (50-100 evals/week) | **Cheapest.** Self-hosted: $0 (just infra costs). Cloud free: 25K spans/mo. Cloud paid: $50/mo. At our scale, self-hosted is free. | 5/5 |
| LiteLLM proxy compatibility | **Excellent.** Native LiteLLM provider support. Self-hosted means full control — can point eval judge calls at any endpoint. No vendor lock-in on model access. Supports Anthropic, OpenAI, Bedrock, etc. directly. | 5/5 |

**Standout:** Zero vendor lock-in. Self-hosted means complete data sovereignty. Cheapest option by far. OpenTelemetry-native means it integrates with any observability stack. Version-controlled evaluators in Eval Hub.

**Concern:** Less polished UI than commercial offerings. No agent simulation. Community support only on free tier. Requires self-hosting effort. No CI/CD GitHub Action out of the box (would need custom wrapper).

---

## Scoring Summary

| Platform | Persona Score | Custom Rubrics | Integration | Pricing | LiteLLM Compat | **Total** |
|----------|:---:|:---:|:---:|:---:|:---:|:---:|
| **Maxim AI** | 4 | 5 | 4 | 4 | 3 | **20** |
| **Braintrust** | 4 | 5 | 4 | 5 | 5 | **23** |
| **Patronus AI** | 3 | 4 | 3 | 4 | 3 | **17** |
| **LangSmith** | 3 | 4 | 3 | 3 | 2 | **15** |
| **Arize Phoenix** | 3 | 4 | 4 | 5 | 5 | **21** |

---

## Recommendation

### Primary: Braintrust (Score: 23/25)

**Rationale:**

1. **Already in the architecture.** ADR-003 positions Braintrust as Layer 5 (Quality Benchmarking) in the recommended eval stack. Adopting it for persona adherence eval avoids adding a new vendor.

2. **Free tier covers our scale.** 10K eval runs/month on the free tier is 25-50x what we need (200-400/month). We won't pay anything until we significantly scale up.

3. **Best LiteLLM integration.** Native `litellm.callbacks = ["braintrust"]` means eval judge calls can route through our existing LiteLLM proxy. Custom providers let us point to any model endpoint. No new API gateway needed.

4. **Custom scorers are flexible enough.** We'd build 4 persona-adherence scorers (one per persona) using LLM-as-judge with rubrics that check:
   - Domain focus (does the finding match the persona's domain?)
   - Output structure (Quality Score table present? RDR format correct?)
   - Evidence citation (does each finding cite a spec section?)
   - Severity calibration (are ratings appropriate?)
   - Behavioral rule compliance (persona-specific anti-patterns)

5. **CI/CD integration is native.** GitHub Action posts eval results on PRs. `Eval()` function integrates into scripts.

### Runner-up: Arize Phoenix (Score: 21/25)

If cost and data sovereignty are top priorities, Phoenix is the better choice. Self-hosted, open-source, zero vendor lock-in. But it requires more setup effort and lacks the CI/CD GitHub Action and Loop (AI-generated scorers) that Braintrust provides.

### Not recommended for this use case:

- **Maxim AI** — Strong platform but introduces a competing gateway (Bifrost) alongside our LiteLLM proxy. The $58-87/mo cost is unnecessary when Braintrust's free tier suffices.
- **Patronus AI** — GLIDER's 8K context window is a concern for long review outputs. More focused on safety/compliance than persona adherence. Less ecosystem integration.
- **LangSmith** — Best when used within LangChain ecosystem, which CCC doesn't use. LiteLLM integration is weakest. Pricing structure is complex.

---

## Implementation Path (Braintrust)

### Phase 1: Scorer Design

Define 4 persona-adherence scorers as LLM-as-judge evaluators:

```python
# Example: Security Skeptic adherence scorer
security_skeptic_rubric = """
Score this review output from 1-5 on Security Skeptic persona adherence:

5 (Excellent): All findings are security-related (auth, data protection, input
   validation, attack surface, compliance). Quality Score covers all 5 security
   dimensions. Findings cite specific spec sections. No drift into architecture
   or performance concerns.

4 (Good): 90%+ findings are security-focused. Minor drift into adjacent domains
   is justified (e.g., architecture concern with security implications).

3 (Acceptable): 70-90% findings are security-focused. Some unjustified drift.
   Quality Score may miss a security dimension.

2 (Weak): <70% findings are security-focused. Significant persona drift.
   Output structure incomplete.

1 (Failed): Generic review with no security focus. Could have been written
   by any persona.
"""
```

### Phase 2: Dataset Creation

Build a ground-truth dataset from existing reviews:
- `docs/reviews/CIA-533-debate-synthesis.md` (real debate output)
- `examples/sample-review-findings.md` (sample review)
- Run 10-20 reviews through the 4 personas, manually score adherence

### Phase 3: CI Integration

Wire `braintrust eval` into the review workflow:
1. After `/ccc:review` runs 4 personas, capture outputs
2. Run persona-adherence eval via Braintrust `Eval()` function
3. Post adherence scores back to the review output or Linear issue
4. Flag if any persona scores below threshold (e.g., <3/5)

### Phase 4: Tracking & Iteration

Use Braintrust experiments to:
- Compare persona prompt changes (A/B testing via experiments)
- Track adherence scores over time (regression detection)
- Identify which persona drifts most (targeted prompt improvement)

---

## Open Questions

1. **Judge model selection:** Should the persona-adherence judge be the same model as the reviewer (Claude), or a different model to avoid self-evaluation bias? Braintrust custom providers make it easy to test both.

2. **Ground truth bootstrapping:** How many manually scored examples do we need before the LLM-as-judge scorer is reliable? Literature suggests 30-50 examples for calibration.

3. **Cross-persona scoring:** Should we also measure cross-persona independence (do 4 personas produce distinct findings), or is per-persona adherence sufficient?

---

## References

- [Braintrust Documentation](https://www.braintrust.dev/docs)
- [Braintrust Autoevals (GitHub)](https://github.com/braintrustdata/autoevals)
- [Braintrust Pricing](https://www.braintrust.dev/pricing)
- [Braintrust + LiteLLM Integration](https://docs.litellm.ai/docs/observability/braintrust)
- [Maxim AI Platform](https://www.getmaxim.ai/)
- [Maxim AI Pricing](https://www.getmaxim.ai/pricing)
- [Patronus AI Evaluators](https://www.patronus.ai/blog/patronus-evaluators)
- [LangSmith Evaluation](https://www.langchain.com/langsmith/evaluation)
- [LangSmith Pricing](https://www.langchain.com/pricing)
- [Arize Phoenix (GitHub)](https://github.com/Arize-ai/phoenix)
- [Phoenix Pricing](https://phoenix.arize.com/pricing/)
- [Phoenix Custom Evaluators](https://arize.com/docs/phoenix/evaluation/how-to-evals/custom-llm-evaluators)
- ADR-003: Premium Eval Tools vs cc-plugin-eval Fork (`docs/adr/003-premium-evals-over-plugin-eval-fork.md`)
