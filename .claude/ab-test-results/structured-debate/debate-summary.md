# Structured Debate Protocol: Cross-Spec Summary

**Date:** 2026-02-15
**Protocol:** 4-persona structured adversarial debate (2 rounds + synthesis)
**Specs reviewed:** 5
**Total files generated:** 50 (5 specs x 10 files each)
**Issue:** CIA-394 (from master plan CIA-423: SDD Plugin v2.0 Review & Dispatch)

---

## Protocol Overview

Each spec passes through a 4-phase pipeline:

1. **Codebase Scan** -- Pre-review analysis of existing files, conflicts, and implementation state
2. **Round 1 (Independent)** -- 4 persona agents review the spec independently
3. **Round 2 (Cross-Examination)** -- Each persona reads all Round 1 outputs and responds using the 6-category taxonomy (AGREE, COMPLEMENT, CONTRADICT, PRIORITY, SCOPE, ESCALATE)
4. **Synthesis** -- debate-synthesizer agent reconciles all 8 reviews into a unified report with consensus levels, confidence intervals, and escalations

---

## Results Summary

| Spec | Score | CI | Recommendation | Unanimous | Majority | Split | Minority | Position Changes | Debate Value |
|------|------:|:--:|----------------|----------:|---------:|------:|---------:|-----------------:|:------------:|
| CIA-303 | 1.8/5 | 1.2-2.4 | REVISE | 7 | 5 | 4 | 4 | 16 | HIGH |
| CIA-396 | 2.6/5 | 1.8-3.4 | REVISE | 4 | 3 | 2 | 3 | 4 | HIGH |
| CIA-391 | 63/100 | 58-68 | CONDITIONAL APPROVE | 8 | 4 | 4 | 11 | 4 | HIGH |
| CIA-426 | 2.3/5 | 1.8-2.8 | BLOCK | 4 | 3 | 1 | 4 | 8 | HIGH |
| CIA-308 | 45.5/100 | 39-52 | APPROVE (w/ mitigations) | 5 | 4 | 2 | 4 | 9 | HIGH |

**Note:** Scoring scales varied (some /5, some /100) because synthesis agents applied different normalization. All confidence intervals use the same widening/narrowing formula (base +0.3/SPLIT, -0.1/UNANIMOUS beyond 2nd).

---

## Cross-Spec Patterns

### 1. No spec passed without conditions

Zero APPROVE recommendations without caveats. Even the strongest spec (CIA-308) required 7 CRITICAL mitigations. This validates that multi-perspective review catches gaps that single-reviewer analysis misses.

### 2. Round 2 consistently changed outcomes

| Spec | Key Round 2 Shift |
|------|-------------------|
| CIA-303 | PP moved CONDITIONAL APPROVE -> REVISE (false positive prevented) |
| CIA-396 | SS escalated REVISE -> RETHINK; UX upgraded REVISE -> REVISE-WITH-OPTIMISM |
| CIA-391 | AP moved REJECT -> CONDITIONAL APPROVE (most dramatic shift) |
| CIA-426 | PP moved REVISE -> CONDITIONAL APPROVE; AP softened REJECT -> BLOCK |
| CIA-308 | 5 findings elevated Important -> CRITICAL via cross-examination |

Without Round 2, PP would have approved CIA-303 prematurely and AP would have rejected CIA-391 unnecessarily. The debate format prevented both false positives and false negatives.

### 3. Escalations surface product decisions

Across all 5 specs, **13 findings were escalated** to require human decision. These are architectural/product choices that technical review cannot resolve:

- CIA-303: Circuit breaker ownership, boundary splitting approach, monotonic vs bidirectional thresholds, references metric visibility
- CIA-396: Per-write vs batch processing, minimal vs principled prototype scope
- CIA-391: Confidence immutability enforcement, validation location, attribution format
- CIA-426: Philosophy change (methodology vs tooling), maintenance commitment, user preference research
- CIA-308: Analytics blocking vs async (resolved via timeout compromise)

### 4. Codebase scans prevent blind spots

All 5 codebase scans identified pre-existing conflicts that were independently discovered by at least 2 personas. This validates the A/B test finding (CIA-395) that codebase awareness improves review quality.

### 5. Unanimous findings cluster around security and architecture

The most common UNANIMOUS Critical findings:
- Missing input validation/sanitization (4/5 specs)
- Undefined ownership/responsibility boundaries (3/5 specs)
- Documentation accuracy gaps (3/5 specs)
- Schema versioning absent (3/5 specs)

---

## Debate Value Assessment

**Verdict: HIGH across all 5 specs.**

Evidence:
- **41 position changes** across 40 reviews (avg 1.0 per review)
- **13 escalations** requiring human decision (would have been buried without structured debate)
- **1 false positive prevented** (CIA-303 PP would have approved prematurely)
- **1 false negative prevented** (CIA-391 AP would have rejected unnecessarily)
- **100% disagreement resolution rate** on CIA-391 (4/4 SPLIT findings resolved)
- Cross-examination consistently revealed second-order concerns invisible to single-perspective analysis

### Round 2 Value-Add Quantified

| Metric | Round 1 Only | After Round 2 | Delta |
|--------|-------------|---------------|-------|
| Total CRITICAL findings | Varies by spec | +4-7 elevated per spec | Significant |
| False positive risk | PP approved CIA-303 | PP revised to REVISE | Prevented |
| False negative risk | AP rejected CIA-391 | AP conditionally approved | Prevented |
| Severity recalibrations | 0 | 10+ per spec | Substantial |
| Root cause discovery | Surface symptoms | Circular coupling, shared foundations | Deeper |

---

## Artifacts

### Per-Spec Files (10 each)

```
.claude/ab-test-results/structured-debate/
  cia-{id}-codebase-scan.md        # Pre-review scan
  cia-{id}-round1-security-skeptic.md
  cia-{id}-round1-performance-pragmatist.md
  cia-{id}-round1-architectural-purist.md
  cia-{id}-round1-ux-advocate.md
  cia-{id}-round2-security-skeptic.md
  cia-{id}-round2-performance-pragmatist.md
  cia-{id}-round2-architectural-purist.md
  cia-{id}-round2-ux-advocate.md
  cia-{id}-synthesis.md            # Reconciled debate output
```

### Agent Created

- `agents/debate-synthesizer.md` -- 5th reconciliation agent (registered in marketplace.json)

### Protocol Design

- 6-category response taxonomy: AGREE, COMPLEMENT, CONTRADICT, PRIORITY, SCOPE, ESCALATE
- 4 consensus levels: UNANIMOUS (4/4), MAJORITY (3/4), SPLIT (2/2), MINORITY (1/4)
- Confidence interval formula: base CI +/-0.3, widened by SPLIT/ESCALATE, narrowed by excess UNANIMOUS
- Position change tracking as primary signal of debate value

---

## Conclusion

The structured debate protocol delivers HIGH value over independent review. Cross-examination:
1. Prevents false positives (premature approvals) and false negatives (unnecessary rejections)
2. Surfaces product decisions that technical review alone cannot resolve
3. Discovers root causes by connecting findings across perspectives
4. Calibrates severity through multi-perspective challenge

The protocol is ready for integration into the SDD adversarial review pipeline as Option F.
