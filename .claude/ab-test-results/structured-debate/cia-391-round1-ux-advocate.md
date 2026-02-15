# CIA-391 Round 1: UX Advocate (Green)
**Persona:** UX Advocate — User journey, error experience, cognitive load, discoverability
**Review Date:** 2026-02-15
**Spec:** CIA-391 — Add Evidence Object pattern to research grounding skill

---

## Critical Findings

### C1: Evidence Object Format Has High Cognitive Load
**Severity:** CRITICAL
**Section:** 5-line Evidence Object format

**Issue:** Users must remember and correctly format 5 distinct fields every time they add evidence. Format is verbose and error-prone:

```
[EV-001] Type: empirical
Source: Author (Year). Title. Journal.
Claim: "Specific factual claim supported by source"
Confidence: high
```

**User friction points:**
1. **Line order matters** — Type before Source before Claim before Confidence. If user writes Source first (natural when copying from paper), format is invalid. Must reorder.
2. **Capitalization inconsistent** — `[EV-001]` is uppercase, `Type:` is capitalized, `empirical` is lowercase. Easy to mistype.
3. **Punctuation fiddly** — Source requires exact format `Author (Year). Title. Journal.` with specific periods and parentheses. If user writes `Author, Year, Title, Journal` (common in BibTeX), format is invalid.
4. **Confidence is subjective** — High/medium/low with no rubric. Two users assign different confidence to same paper. Inconsistency across specs.
5. **Quote marks required** — Claim must be quoted. If user forgets quotes, validation error (unclear from spec).

**Real-world usability scenario:** User is drafting spec. Finds good paper. Copies title and authors from Semantic Scholar. Pastes into spec. Format doesn't match. Spends 2 minutes reformatting. Loses flow. Repeats for every paper. After 5 papers, user is frustrated and writes shorter citations to save time (quality degrades).

**Comparison to current inline format:** `(Author, Year; DOI)` is simpler. 3 fields, flexible order, no line breaks. User can copy-paste from paper and be done. Evidence Objects trade simplicity for structure.

**Why this is critical:** If format is too hard to write, users will:
- Skip adding Evidence Objects (fails 3+ requirement)
- Use wrong format (validation fails, breaks flow)
- Copy-paste from previous spec without updating (stale citations)

**Mitigation:**
1. **Provide template snippet** in `research-grounding/SKILL.md`:
   ```markdown
   <!-- Copy this template for each Evidence Object -->
   [EV-XXX] Type: [empirical|theoretical|methodological]
   Source: [Author (Year). Title. Journal.]
   Claim: "[Quote or paraphrase from source]"
   Confidence: [high|medium|low]
   ```
2. **Add format validation with helpful errors:**
   - Missing `Type:` → "Evidence Object EV-001 is missing Type field. Add 'Type: empirical' on line 2."
   - Wrong Source format → "Source should be 'Author (Year). Title. Journal.' Found: 'Smith et al., 2020, Paper Title'. Fix format on line 3."
3. **Create interactive helper** in `/sdd:write-prfaq`:
   ```
   Agent: "Add Evidence Object? [y/n]"
   User: "y"
   Agent: "Paste DOI or arXiv ID:"
   User: "10.1080/00224490802400129"
   Agent: [fetches metadata from Semantic Scholar]
   Agent: "Found: Wakin & Vo (2008). Love-Variant: The Wakin-Vo I.D.R. Model of Limerence. Sexual and Relationship Therapy."
   Agent: "What claim does this support?"
   User: "Limerence correlates with attachment anxiety"
   Agent: "Confidence? [h]igh, [m]edium, [l]ow"
   User: "h"
   Agent: [writes formatted Evidence Object to spec]
   ```
   User never touches format manually. Agent handles formatting.
4. **Consider WYSIWYG editor** for Alteri UI. User fills form, Evidence Object generates automatically.

**Detection:** Usability testing. Give spec template to 3 users unfamiliar with format. Ask them to add Evidence Object from a paper. Time to completion and error rate reveal friction.

---

### C2: No Guidance on When to Add Evidence Objects
**Severity:** CRITICAL
**Section:** Research grounding workflow

**Issue:** Spec says PR/FAQ research template "requires 3+ Evidence Objects" but doesn't tell user:
- When to add them (while drafting? after FAQ? during review?)
- Which claims need Evidence Objects (all claims? only controversial ones?)
- How to choose between competing sources (if 5 papers say different things, which 3 to cite?)

**User confusion scenarios:**

**Scenario 1: Where do Evidence Objects go?**
- User writes Press Release. Makes claim about limerence. Needs evidence now? Or later?
- Spec shows Evidence Objects in "Research Base" section (line 86+ of prfaq-research.md). But Press Release comes first (line 20+). Does user write Press Release without evidence, then backfill later? Or draft Research Base first (Working Backwards in reverse)?

**Scenario 2: Redundant citations**
- Press Release mentions limerence. FAQ Q1 mentions limerence. Research Base has limerence Evidence Object. Does user cite 3 times? Or write `[EV-001]` reference in Press Release linking to Research Base Evidence Object?
- If references, how does user know which EV number to use before Evidence Objects are written?

**Scenario 3: Coverage ambiguity**
- Spec says "3+ Evidence Objects." For entire spec? Per claim? Per FAQ answer?
- Press Release makes 5 claims. Does user need 5 Evidence Objects (1 per claim)? Or 3 total (covering strongest claims)?

**Why this is critical:** Without workflow guidance, users will:
- Add Evidence Objects in wrong order (breaks drafting flow)
- Over-cite (10+ Evidence Objects to be safe, hits Performance concern C1)
- Under-cite (3 Evidence Objects for 10 claims, weak grounding)
- Cite wrong claims (Evidence Objects for obvious statements, not controversial ones)

**Mitigation:**
1. **Add Evidence Object workflow to `research-grounding/SKILL.md`:**
   ```markdown
   ## When to Add Evidence Objects

   Add Evidence Objects during PR/FAQ drafting in this sequence:

   1. **After Problem Statement** — Identify claims requiring evidence (psychological constructs, causal relationships, measurement approaches)
   2. **During Research Base section** — Draft 3-5 Evidence Objects for core claims
   3. **While writing FAQ** — Reference Evidence Objects as `[EV-001]` when answering questions
   4. **During Pre-Mortem** — Add Evidence Object if citing research about failure modes

   ### Coverage Rule
   - 1 Evidence Object per major claim (psychological construct, causal mechanism, intervention effect)
   - Minimum 3, maximum 10 per spec
   - Prioritize: Novel claims > Controversial claims > Common knowledge
   ```

2. **Update `prfaq-research.md` template with inline prompts:**
   ```markdown
   ## Press Release
   **Problem:** [Describe pain point. If referencing psychological constructs, mark with `*` for evidence needed]

   ...later in template...

   ## Research Base
   <!-- For each `*` marked claim in Press Release/FAQ, add Evidence Object here -->
   ```

3. **Add examples to `research-grounding/SKILL.md`:**
   ```markdown
   ### Example: Well-Grounded vs. Under-Grounded Claim

   **Under-grounded:**
   > "Limerence causes obsessive thinking, emotional dependency, and intrusive thoughts."

   **Well-grounded:**
   > "Limerence is characterized by obsessive thinking [EV-001], emotional dependency [EV-002], and intrusive thoughts [EV-003]."

   Research Base section then contains:
   [EV-001] Type: empirical
   Source: Wakin & Vo (2008). Love-Variant: The Wakin-Vo I.D.R. Model of Limerence. Sexual and Relationship Therapy.
   Claim: "Limerence involves intrusive thinking about the limerent object, occurring on average 85% of waking hours in acute cases"
   Confidence: high
   ```

**Detection:** Task analysis. Watch user draft spec with Evidence Objects. Note when they pause, reread instructions, or ask questions. Pauses = missing guidance.

---

## Important Findings

### I1: Evidence Object Discoverability Is Poor
**Severity:** IMPORTANT
**Section:** Research grounding skill integration

**Issue:** How does user discover that Evidence Objects exist? Spec says add to `research-grounding/SKILL.md` (skill doc, rarely read) and `prfaq-research.md` (template, only seen when drafting). No in-command prompts.

**User journey analysis:**

**Path 1: User starting new research feature**
1. User runs `/sdd:write-prfaq`
2. Command asks scope questions, selects `prfaq-research` template
3. Command generates template
4. User sees Research Base section with Evidence Object format example
5. **First encounter with Evidence Objects** — 4 steps into workflow

**Path 2: User converting existing spec to research spec**
1. User has spec with inline citations `(Author, Year; DOI)`
2. User learns about Evidence Objects from teammate or docs
3. User manually reformats citations to Evidence Object format
4. No tooling support, no migration guide

**Path 3: User validating spec**
1. User runs `/sdd:review` (or `/sdd:write-prfaq` validation)
2. Validation fails: "Spec requires 3+ Evidence Objects. Found: 0."
3. User has never heard of Evidence Objects
4. Error message doesn't link to documentation
5. User searches codebase, finds `research-grounding/SKILL.md`, reads 107 lines
6. **First encounter with Evidence Objects** — via error message (bad UX)

**Comparison:** Other spec requirements (Press Release, FAQ, Pre-Mortem) are surfaced by template structure. Evidence Objects hidden in template comment or skill doc.

**Why important:** Discoverability affects adoption. If users don't know Evidence Objects exist, they won't use them. Feature fails silently.

**Mitigation:**
1. **Add Evidence Object prompt to `/sdd:write-prfaq`:**
   ```
   Step 4: Research Base (for research template)

   This spec requires research grounding. You'll need 3+ Evidence Objects.
   Evidence Objects formalize citations with type, claim, and confidence.

   Format:
   [EV-001] Type: empirical
   Source: Author (Year). Title. Journal.
   Claim: "Specific claim from source"
   Confidence: high

   Would you like help adding Evidence Objects? [y/n]
   ```

2. **Improve validation error messages:**
   ```
   ❌ Validation failed: Research spec requires 3+ Evidence Objects

   Found: 0 Evidence Objects
   Expected: 3+

   Evidence Objects document research support for claims.
   See format guide: skills/research-grounding/SKILL.md
   Example: [EV-001] Type: empirical | Source: ... | Claim: "..." | Confidence: high

   Add Evidence Objects in Research Base section and re-run validation.
   ```

3. **Add "Quick Start" section to `research-grounding/SKILL.md`:**
   ```markdown
   ## Quick Start: Adding Your First Evidence Object

   1. Find a paper supporting your feature (use Semantic Scholar or arXiv)
   2. Copy this template:
      [EV-001] Type: empirical
      Source: [Author (Year). Title. Journal.]
      Claim: "[Key finding from paper]"
      Confidence: [high|medium|low]
   3. Replace bracketed fields with paper details
   4. Add to Research Base section of your spec
   5. Repeat for 2 more papers (3 total minimum)
   ```

---

### I2: Confidence Field Lacks User Guidance
**Severity:** IMPORTANT
**Section:** Confidence: high | medium | low

**Issue:** User must assign confidence but spec provides no rubric. What makes evidence "high" confidence vs. "medium"?

**User confusion points:**
- Is confidence about **source quality** (journal tier, peer review status)?
- Or about **claim strength** (effect size, replication status)?
- Or about **relevance** (how directly paper supports this feature)?
- Or about **user's certainty** (subjective assessment)?

**Example ambiguity:**
- Paper: Nature journal (prestigious), N=50 (small sample), non-replicated (single study), tangentially related to feature.
- Is this high confidence (Nature journal) or low (small N, no replication, tangential)?

**Two users, two assessments:**
- User A (biologist): "Nature = high confidence"
- User B (psychologist): "N=50, non-replicated = medium confidence"

**Inconsistency across specs.** Confidence field becomes meaningless if criteria vary by user.

**Why important:** Confidence field is load-bearing. Security Skeptic wants to validate it against source metadata. Performance Pragmatist wants to filter by it. If subjective, both uses fail.

**Mitigation:**
1. **Add confidence rubric to `research-grounding/SKILL.md`:**
   ```markdown
   ## Confidence Assignment Rubric

   Assign confidence based on **cumulative strength** across these dimensions:

   | Dimension | High | Medium | Low |
   |-----------|------|--------|-----|
   | **Source quality** | Peer-reviewed journal, IF >5 | Peer-reviewed, IF 2-5 | Preprint or non-peer-reviewed |
   | **Sample size** | N > 500 or meta-analysis | N = 50-500 | N < 50 |
   | **Replication** | Replicated in 2+ studies | Single study | No replications |
   | **Relevance** | Directly studies construct/intervention | Related construct or population | Tangential or analogical |
   | **Recency** | Published within 5 years | 5-10 years | 10+ years |

   **Scoring:**
   - All dimensions High → Confidence: high
   - 3+ dimensions High, rest Medium → Confidence: high
   - Mix of High/Medium → Confidence: medium
   - Any dimension Low → Confidence: medium or low (depending on severity)
   - 2+ dimensions Low → Confidence: low

   **Example:**
   - Nature journal (High), N=5000 meta-analysis (High), replicated (High), direct relevance (High), recent (High) → **high**
   - PLoS ONE (Medium), N=75 (Medium), single study (Medium), related construct (Medium), recent (High) → **medium**
   - arXiv preprint (Low), N=30 (Low), pilot study (Low), tangential (Low), recent (High) → **low**
   ```

2. **Interactive confidence helper in `/sdd:write-prfaq`:**
   ```
   Agent: "Assign confidence for this Evidence Object."
   Agent: "Is source peer-reviewed? [y/n]" → y = +1 point
   Agent: "Sample size?" → >500 = +1, 50-500 = +0.5, <50 = 0
   Agent: "Has this been replicated?" → y = +1, n = 0
   Agent: "Relevance to feature?" [direct/related/tangential] → direct = +1, related = +0.5, tangential = 0
   [Calculate total points]
   3.5+ points → high, 2-3 points → medium, <2 points → low
   Agent: "Calculated confidence: medium. Accept? [y/n]"
   ```

3. **Show confidence distribution in validation:**
   ```
   ✓ Spec has 5 Evidence Objects

   Confidence distribution:
   - High: 2 (40%)
   - Medium: 2 (40%)
   - Low: 1 (20%)

   Recommendation: Strengthen low-confidence evidence or remove.
   ```

---

### I3: Evidence Object Editing Is Cumbersome
**Severity:** IMPORTANT
**Section:** Evidence Object lifecycle

**Issue:** User writes Evidence Object during drafting. During review, reviewer says "Confidence should be medium, not high." User must:
1. Open spec file
2. Find specific Evidence Object (scroll through 5-10 objects)
3. Change `Confidence: high` to `Confidence: medium`
4. Save, commit, re-run validation

For multi-round review (3 reviewers × 2 rounds), user edits Evidence Objects 6+ times. High friction.

**Comparison to other spec edits:** FAQ answer change = edit one section. Evidence Object change = find object by ID, edit specific field, maintain formatting.

**Why important:** If editing is painful, users avoid updates. Stale Evidence Objects persist. Research grounding quality degrades.

**Mitigation:**
1. **Add Evidence Object index to spec file:**
   ```markdown
   ## Research Base

   **Evidence Objects:** [EV-001](#ev-001) | [EV-002](#ev-002) | [EV-003](#ev-003)

   <a id="ev-001"></a>
   [EV-001] Type: empirical
   ...
   ```
   Clickable navigation. User clicks `[EV-001]` in index, jumps to object.

2. **Create `/sdd:edit-evidence-object` command:**
   ```
   User: "/sdd:edit-evidence-object CIA-391 EV-001 confidence medium"
   Agent: [finds EV-001 in CIA-391 spec, changes confidence to medium, saves]
   Agent: "Updated EV-001 confidence: high → medium"
   ```

3. **Structured edit UI in Alteri:**
   - Render Evidence Objects as editable cards
   - Click "Edit" button, fields become text inputs
   - Save changes, markdown updates automatically

---

## Consider

### N1: Evidence Object Preview in Validation
**Severity:** CONSIDER

**Idea:** When validation reports "Found 5 Evidence Objects," also show preview:
```
✓ Found 5 Evidence Objects

[EV-001] Wakin & Vo (2008) — "Limerence involves intrusive thinking..." (empirical, high)
[EV-002] Tennov (1979) — "Limerence is characterized by..." (theoretical, high)
[EV-003] Fisher (2016) — "Romantic love shows overlap..." (empirical, medium)
[EV-004] Hatfield (2008) — "Passionate love shares features..." (empirical, medium)
[EV-005] Acevedo (2012) — "Long-term relationships can maintain..." (empirical, medium)
```

**Benefit:** User sees at-a-glance what evidence exists. Can spot gaps ("No methodological type!") or redundancy ("Two papers say same thing").

**Cost:** Verbose validation output. May overwhelm user.

**Recommendation:** Add `--verbose` flag to validation. Default = count only. Verbose = preview.

---

### N2: Evidence Object Reuse Across Specs
**Severity:** CONSIDER

**Scenario:** User writes 2 specs for Alteri features. Both cite Wakin & Vo (2008) limerence paper. User must format Evidence Object twice.

**Idea:** Create Evidence Object library. User adds paper once, references from multiple specs:
```yaml
# .evidence-objects/library.yaml
EV-GLOBAL-001:
  type: empirical
  source: "Wakin & Vo (2008). Love-Variant: The Wakin-Vo I.D.R. Model of Limerence. Sexual and Relationship Therapy."
  doi: "10.1080/00224490802400129"
```

Spec references: `[EV-GLOBAL-001]` instead of duplicating format.

**Benefits:** DRY, consistent formatting, single-source updates (if paper details change).

**Costs:** Complexity, coupling (specs depend on external file), ID namespace collision risk.

**Recommendation:** Defer to v2. Start with per-spec Evidence Objects. If users complain about duplication after 10+ specs, revisit.

---

### N3: Evidence Object Accessibility
**Severity:** CONSIDER

**Question:** How do screen reader users interact with Evidence Objects? 5-line format without semantic structure may read as:

> "Open bracket E V dash zero zero one close bracket Type colon empirical Source colon Author open paren Year close paren period Title period Journal period Claim colon quote Specific factual claim quote Confidence colon high"

**50+ syllables for one Evidence Object.** Verbose and hard to parse aurally.

**Suggestion:** If rendering to web UI, use semantic HTML:
```html
<article class="evidence-object" aria-labelledby="ev-001-label">
  <h4 id="ev-001-label">Evidence EV-001 (empirical, high confidence)</h4>
  <p><strong>Source:</strong> Wakin & Vo (2008). Love-Variant: The Wakin-Vo I.D.R. Model of Limerence.</p>
  <blockquote><strong>Claim:</strong> Limerence involves intrusive thinking about the limerent object.</blockquote>
</article>
```

Screen reader reads:
> "Evidence EV-001, empirical, high confidence. Source: Wakin and Vo, 2008, Love-Variant... Claim: Limerence involves intrusive thinking..."

**30% fewer syllables, clearer structure.**

---

## Quality Score

| Dimension | Score | Justification |
|-----------|-------|---------------|
| **Learnability** | 50/100 | Critical: Format has high cognitive load (C1). Poor discoverability (I1). No workflow guidance (C2). Users will struggle to adopt. |
| **Efficiency** | 55/100 | Important: Manual formatting is slow (C1). Editing is cumbersome (I3). No automation or shortcuts. |
| **Error Prevention** | 60/100 | Format is strict but errors likely (wrong field order, missing quotes). Validation catches errors but feedback could be clearer (I1). |
| **Satisfaction** | 50/100 | Structured format is polarizing. Researchers may appreciate rigor. Developers may find it tedious. No usability testing yet. |
| **Accessibility** | 70/100 | Markdown is screen-reader friendly. But verbose format (N3) could be improved with semantic HTML rendering. |

**Overall UX Score:** **55/100**
**Risk Level:** **MEDIUM-HIGH** — Adoption friction will limit use. Users may skip Evidence Objects or use incorrectly.

---

## What Gets Right

1. **Structured format enables automation:** Once user provides data, agent can format Evidence Objects, validate them, render them. Good foundation for tooling.

2. **Confidence field acknowledges uncertainty:** Better than binary "cited/not cited." Surfacing uncertainty helps users assess claim strength.

3. **Type classification is user-relevant:** Empirical vs. theoretical distinction makes sense to researchers. Helps users pick right evidence type for claim.

4. **Additive feature:** Users can opt into Evidence Objects gradually. Not forced migration. Low adoption risk.

---

## Recommendation

**CONDITIONAL APPROVE** — Fix C1 (cognitive load) and C2 (workflow guidance) before release. I1 (discoverability) and I2 (confidence rubric) should be addressed for production-readiness but not blocking for MVP.

**Critical UX improvements:**
1. Add interactive Evidence Object helper to `/sdd:write-prfaq` (eliminates manual formatting)
2. Document Evidence Object workflow in `research-grounding/SKILL.md` (when to add, how many, which claims need evidence)
3. Add confidence rubric with examples (reduces subjectivity)
4. Improve validation error messages with format examples and doc links

**Nice-to-have (defer):**
- Evidence Object editing command (I3)
- Verbose validation preview (N1)
- Semantic HTML rendering for accessibility (N3)

**If shipped without UX improvements:** Users will find format intimidating. Adoption will be slow. Evidence Objects become "feature that only power users use" instead of standard practice. Alteri's research grounding advantage diminishes.

**Estimated UX improvement effort:** 2 hours for interactive helper in write-prfaq command, 1 hour for workflow documentation, 1 hour for confidence rubric. Total ~4 hours.

---

## Metadata

**Review Duration:** 35 minutes
**Codebase Scan Consulted:** Yes (workflow integration informed C2, validation messages informed I1)
**User Research Conducted:** No (recommendations based on UX heuristics, not empirical testing)
**Confidence in Review:** Medium-high (UX issues identified but usability testing needed for validation)
**Bias Disclosure:** I favor simplicity and automation over manual structure. May undervalue researchers who prefer explicit formatting control.
