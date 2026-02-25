# Multi-Model Consensus Protocol

When using multiple model tiers for adversarial review, follow this validated consensus process. Experimentally validated on 5 specs (CIA-297, n=222 raw findings, 105 deduplicated). See `.claude/ab-test-results/multi-model-comparison.md` for full data.

## Model Tier Roles

| Tier | Role | When |
|------|------|------|
| Haiku | Scan, classify, surface-level triage | Phase 1 scan, Phase 2 haiku-tier reviews |
| Sonnet | Deep adversarial review | Phase 2 sonnet-tier reviews |
| Opus | Synthesize, deduplicate, reconcile | Phase 3 synthesis |

## Consensus Scoring (Validated, 8 Reviewers = 4 Personas x 2 Tiers)

| Level | Threshold | Action |
|-------|-----------|--------|
| CRITICAL | 6+/8 reviewers | Must address before implementation |
| HIGH | 4-5/8 reviewers | Should address before implementation |
| MODERATE | 2-3/8 reviewers | Should consider |
| MINORITY | 1/8 reviewers | Note -- do not dismiss (may represent specialist expertise) |

## Tier Tagging

Each unified finding is tagged:
- `convergent` -- found by both sonnet AND haiku tier (highest confidence, ~44% of findings)
- `sonnet-only` -- found only by sonnet tier (~45% of findings, mostly integration/quantitative analysis)
- `haiku-only` -- found only by haiku tier (~11% of findings, mostly user confusion/strategic identity)

## Structured Exchange Format

When passing findings between models, use structured JSON to prevent misinterpretation and enable programmatic reconciliation.

```json
{
  "finding_id": "SS1",
  "persona": "security-skeptic",
  "model_tier": "sonnet",
  "severity": "critical",
  "spec_section": "3.2 Authentication",
  "description": "Token stored in localStorage is vulnerable to XSS",
  "evidence": "Spec says 'store auth token client-side' without specifying storage mechanism",
  "mitigation": "Use httpOnly secure cookies or server-side session storage"
}
```

**Finding ID convention:** Two-letter code = persona initial + tier initial. SS = Security Sonnet, SH = Security Haiku, PS = Performance Sonnet, PH = Performance Haiku, AS = Architecture Sonnet, AH = Architecture Haiku, US = UX Sonnet, UH = UX Haiku.

## Synthesis Step

After independent reviews, a dedicated synthesizer model (opus) reads all outputs and produces a unified review. The synthesizer must NOT add new concerns -- only consolidate, deduplicate, tag tiers, and reconcile. When using Option F (structured debate), the synthesizer is a separate agent (`debate-synthesizer`) rather than one of the reviewing personas, to avoid conflicts of interest.

## What Each Tier Finds (Validated Patterns)

| Sonnet excels at | Haiku excels at |
|------------------|-----------------|
| Integration/dependency analysis | "Does this confuse a new reader?" |
| Quantitative risk (latency, cost, sample size) | Identity confusion (prototype vs production) |
| Architecture coherence and coupling | Source attribution and traceability |
| Edge cases and failure modes | "What does the user DO?" questions |
| Cross-file/cross-system implications | Over-engineering detection |

## User Decision Log

During adversarial review, maintain an explicit log of user decisions to prevent re-proposing rejected ideas.

**Format:**
| Round | Proposal | User Decision | Verbatim Reason |
|-------|----------|:------------:|-----------------|
| 1 | "Use Redis for caching" | REJECTED | "Too complex for personal tool" |
| 2 | "Add retry middleware" | ACCEPTED | "Makes sense for reliability" |

**Rules:**
- Log EVERY user decision (accept, reject, defer, modify)
- Record the reason VERBATIM -- do not paraphrase or interpret
- Before proposing anything in subsequent rounds, check the log for prior rejections
- If a previously rejected idea is reconsidered, explicitly acknowledge: "This was rejected in Round N because [reason]. Has the context changed?"
- Anti-pattern: "proposal amnesia" -- re-proposing rejected ideas without acknowledging the prior rejection
