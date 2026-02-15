# CIA-391 Round 1: Performance Pragmatist (Orange)
**Persona:** Performance Pragmatist — Scaling limits, caching, resource budgets, latency
**Review Date:** 2026-02-15
**Spec:** CIA-391 — Add Evidence Object pattern to research grounding skill

---

## Critical Findings

### C1: No Evidence Object Count Upper Bound
**Severity:** CRITICAL
**Section:** Acceptance criteria - "3+ Evidence Objects" requirement

**Issue:** Spec mandates minimum 3 Evidence Objects but no maximum. If user adds 50 Evidence Objects to a single spec (not unreasonable for a literature review-heavy feature), performance degrades across multiple surfaces:

**Impact areas:**
1. **Git operations:** Evidence Object format is verbose (5 lines minimum per object). 50 EV = 250+ lines in spec file. Git diff becomes painful. PR review velocity drops.
2. **Markdown rendering:** Alteri renders specs in Next.js. 50 Evidence Objects × ~800 bytes each = 40KB of rendered content. Page load time increases. Mobile performance suffers.
3. **Validation latency:** If validation runs on every Evidence Object (checking confidence against source metadata, claim length, etc.), 50 objects = 50 validation calls. If each call takes 200ms (reasonable for external API check), total validation time = 10 seconds.
4. **Context window consumption:** When agent re-reads spec during `/sdd:anchor`, Evidence Objects consume tokens. 50 EV × 150 tokens = 7500 tokens. For reference, entire `research-grounding/SKILL.md` is ~2000 tokens.

**Real-world scenario:** Meta-analysis research feature. User cites 30 papers (common in psychology meta-analyses). Each paper = 1 Evidence Object. Spec becomes unreadable, validation times out, agent context blows up.

**Why no current mitigation exists:** Codebase scan shows `research-grounding/SKILL.md` says "3+ citations" without upper limit. No pagination, no chunking, no lazy loading mentioned anywhere.

**Mitigation:**
1. Set pragmatic upper limit: **10 Evidence Objects per spec**. Rationale: Forces distillation (good research practice), keeps validation under 2 seconds, preserves git diff readability.
2. If more evidence needed, use tiered approach:
   - **Core evidence (in spec):** 3-10 Evidence Objects for primary claims
   - **Supporting evidence (linked):** Separate markdown file or Zotero collection for extended bibliography
3. Update validation: Warn at 8 EV, error at 11 EV.
4. Add to `research-grounding/SKILL.md`: "Evidence Objects distill the strongest evidence, not comprehensive bibliography. Use linked reference documents for full literature review."

**Detection:** Validation command counts Evidence Objects, fails with actionable message: "Spec has 15 Evidence Objects. Max is 10. Distill to core findings or move extended citations to docs/literature-review.md."

---

### C2: Source Metadata Fetching Creates Validation Bottleneck
**Severity:** CRITICAL
**Section:** Confidence validation (implied by Security Skeptic's C2 mitigation)

**Issue:** If validation checks confidence against source metadata (journal tier, citation count, publication type), each Evidence Object requires external API call. With 10 Evidence Objects:

**Latency cascade:**
- Semantic Scholar API: ~300ms per paper lookup
- OpenAlex API: ~200ms per work lookup
- arXiv API: ~150ms per paper lookup

**Total sequential latency:** 10 EV × 300ms = 3 seconds (best case). If any API is slow or rate-limited, validation blocks for 10+ seconds.

**Compounding factors:**
1. **Rate limits:** Semantic Scholar free tier = 100 req/5min. If 10 users validate specs simultaneously, rate limit exhausted. Validation fails intermittently.
2. **Network failures:** If GitHub Actions runs validation in CI, transient network errors cause flaky builds.
3. **Stale metadata:** Citation counts change daily. Caching for 24 hours means confidence validation uses yesterday's data.

**Why this is critical:** Validation is blocking operation in `/sdd:write-prfaq`. If validation takes 10 seconds, user experience degrades. If validation fails due to rate limit, workflow breaks.

**Mitigation:**
1. **Parallel validation:** Fetch all Evidence Object metadata concurrently using `Promise.all()`. Reduces 10 EV validation from 3s to 300ms.
2. **Caching layer:** Cache source metadata for 7 days. Key = DOI/arXiv ID. Invalidate on explicit user request only.
3. **Graceful degradation:** If metadata fetch fails, validation continues with warning: "Could not verify confidence for EV-003. Proceeding with user-assigned confidence." Do NOT block on metadata availability.
4. **Rate limit handling:** Implement exponential backoff. If rate-limited, queue validation and notify user: "Validation queued. Check back in 2 minutes."

**Alternative approach:** Make confidence validation **async and optional**. User submits spec, validation runs in background, posts results as spec comment. Confidence check is advisory, not blocking.

---

## Important Findings

### I1: Evidence Object Format Bloats Spec Files
**Severity:** IMPORTANT
**Section:** Evidence Object format (5-line structure)

**Issue:** Current format requires 5 lines per Evidence Object:
```
[EV-001] Type: empirical
Source: Author (Year). Title. Journal.
Claim: "Specific factual claim supported by source"
Confidence: high
```

With 10 Evidence Objects, that's 50 lines JUST for citations. Add blank lines between objects (formatting convention), you're at 60 lines. For context, entire Press Release section in PR/FAQ template is ~15 lines.

**Impact on performance:**
- **Git blame:** More lines = more potential for conflicts in collaborative editing.
- **Diff readability:** Changing one claim updates one line, but Git shows 5-line context. Diffs get noisy.
- **Token efficiency:** 5 lines × 30 tokens/line = 150 tokens per Evidence Object. Inline citation format (`(Author, Year; DOI)`) = 10 tokens. **15x token overhead.**

**Trade-off:** Structure vs. conciseness. Current format optimizes for human readability at cost of computational efficiency.

**Mitigation:**
1. **Compact format for non-interactive contexts:**
   ```yaml
   [EV-001]: {type: empirical, source: "Author (Year). Title.", claim: "Claim text", confidence: high}
   ```
   Single line, YAML-parseable, 50% token reduction.
2. **Format selection:** Use 5-line format in markdown specs (human-readable), compact format when passing to agents (token-efficient).
3. **Alternative:** Store Evidence Objects in frontmatter YAML block, render in body as `[1]` references. Separates metadata (frontmatter) from narrative (body).

**Recommendation:** Document both formats. Use 5-line for drafting, compact for storage/transmission.

---

### I2: No Incremental Validation Strategy
**Severity:** IMPORTANT
**Section:** Validation in `/sdd:write-prfaq`

**Issue:** Spec says "/sdd:write-prfaq validates minimum Evidence Object count" but doesn't specify WHEN. If validation runs once at end of drafting process:

**Problem:** User spends 20 minutes writing spec, adds 2 Evidence Objects, runs command, validation fails: "Need 3+ Evidence Objects." User must go back, add another, re-run. Wasted iteration.

**Better approach:** Incremental validation. As user drafts:
- After Press Release: Check for problem/solution separation
- After FAQ: Check for 6+ questions
- After Research Base: Check for 3+ Evidence Objects
- After Acceptance Criteria: Final validation

**Performance benefit:** Early feedback = fewer wasted cycles. User knows Evidence Object deficit before investing time in Pre-Mortem.

**Implementation:** If `/sdd:write-prfaq` is interactive (codebase scan shows it is), add validation checkpoints between steps. If batch processing, add `--validate-only` flag for fast checks without full command execution.

---

### I3: Evidence Object Rendering Not Specified
**Severity:** IMPORTANT
**Section:** Integration with Alteri UI

**Issue:** Spec says nothing about how Evidence Objects render in Alteri. If naively converted markdown → HTML:

**Performance concerns:**
1. **CLS (Cumulative Layout Shift):** If Evidence Objects lazy-load, page jumps as content appears. Poor UX score.
2. **Interaction cost:** If user must click each Evidence Object to expand claim, 10 clicks required to read all evidence. High interaction cost.
3. **Mobile rendering:** 5-line format designed for desktop. On mobile, Evidence Objects take 8-10 lines each. 10 EV = 80 lines = excessive scrolling.

**No caching strategy specified:** If Evidence Objects include dynamic data (citation count, journal impact factor), re-fetching on every page load creates unnecessary API traffic.

**Mitigation:**
1. **Render strategy:** Specify in spec whether Evidence Objects are:
   - A. Always expanded (simple, high CLS)
   - B. Collapsed by default, expand on click (lower CLS, higher interaction cost)
   - C. Inline in prose with `[1]` references (most compact, requires reference resolution)
2. **Caching:** Evidence Object metadata cached client-side for session duration. No re-fetch on navigation within same spec.
3. **Mobile optimization:** Compact format on mobile (single line), full format on desktop.

---

## Consider

### N1: Evidence Object Diff Visualization
**Severity:** CONSIDER

**Observation:** 5-line format makes git diffs verbose. Changing confidence from "medium" to "high" produces 5-line diff block for context. In PR with 3 Evidence Object updates, 15 lines of diff noise.

**Performance impact:** Low directly, but affects review velocity (human performance bottleneck).

**Suggestion:** Custom git diff driver for Evidence Objects. Renders diff as:
```
[EV-001] confidence: medium → high
```
Single line, clear change signal. Requires `.gitattributes` config, but improves PR review speed.

---

### N2: Evidence Object Search/Indexing
**Severity:** CONSIDER

**Future scaling question:** As specs accumulate, how do users find "all specs citing Smith et al. 2020"? If Evidence Objects stored in markdown, full-text search required. If stored in database, indexed query possible.

**Performance trade-off:** Markdown = no index overhead, slow cross-spec search. Database = index overhead, fast search.

**Suggestion:** Don't over-engineer for day 1. Start with markdown. If search becomes bottleneck, migrate to SQLite FTS index later.

---

### N3: Validation Command Placement
**Severity:** CONSIDER

**Codebase scan question:** "Should Evidence Object validation be added to write-prfaq, review, or separate command?"

**Performance lens answer:** Separate command (`/sdd:validate-prfaq`) is most flexible. Allows:
- User to validate before review (fast feedback loop)
- CI to validate on PR (automated gate)
- Review to call validate internally (reuse)

Embedding validation in `write-prfaq` couples concerns. If validation becomes slow (C2), write-prfaq becomes slow.

**Recommendation:** Create `/sdd:validate-prfaq` command. Update `write-prfaq` to call it at end. Update `review` to call it at start.

---

## Quality Score

| Dimension | Score | Justification |
|-----------|-------|---------------|
| **Scalability** | 55/100 | No upper bound on Evidence Objects (C1). Format verbose (I1). As spec complexity grows, performance degrades linearly. |
| **Latency** | 50/100 | Validation bottleneck (C2). Sequential API calls create 3-10s latency. No caching strategy. |
| **Resource Efficiency** | 60/100 | Token overhead 15x vs. inline citations (I1). No chunking or pagination for large evidence sets. |
| **User Experience** | 65/100 | Incremental validation missing (I2). No mobile optimization (I3). High interaction cost if Evidence Objects require expansion. |
| **Maintainability** | 75/100 | Format is clear and parseable. YAML-compatible. Diff verbosity is manageable with tooling (N1). |

**Overall Performance Score:** **59/100**
**Risk Level:** **MEDIUM** — Functional but will hit scaling limits with 10+ Evidence Objects or concurrent users

---

## What Gets Right

1. **Structured data format:** YAML-parseable 5-line format enables automated tooling. Much better than inline citations for validation and analysis.

2. **Minimum threshold (3+ EV):** Prevents under-citing. Good research practice. From performance lens, minimum is more important than maximum (though both needed).

3. **Additive feature:** Doesn't break existing functionality. Can be adopted incrementally. Low migration cost.

4. **Confidence field:** Enables filtering/sorting by evidence strength. Future optimization: "Show only high-confidence claims" filter.

---

## Recommendation

**CONDITIONAL APPROVE** — Address C1 (upper bound) and C2 (validation latency) before merging. I1-I3 are important for production but not blocking for initial implementation.

**Critical path items:**
1. Set 10 Evidence Object max per spec (C1)
2. Implement parallel validation with caching (C2)
3. Define rendering strategy for Alteri (I3)

**Nice-to-have (defer to follow-up):**
- Compact YAML format option (I1)
- Incremental validation (I2)
- Custom git diff driver (N1)

**If upper bound not added:** System will work initially but degrade as users add more evidence. Recommend hard limit now, relax later if needed (easier than imposing limit retroactively).

**Estimated performance impact if shipped as-is:** Validation takes 5-10 seconds for 10 Evidence Objects. Acceptable for MVP but not production-ready. Fix with parallel fetch (reduces to <1s).

---

## Metadata

**Review Duration:** 30 minutes
**Codebase Scan Consulted:** Yes (validation location question informed N3)
**Performance Testing:** Not conducted (static analysis only)
**Confidence in Review:** High (scaling/latency issues well-understood for this pattern)
