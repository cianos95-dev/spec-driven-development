# CIA-391 Codebase Scan
## Evidence Object Pattern Addition to Research Grounding Skill

**Scan Date:** 2026-02-15
**Spec:** CIA-391 — Add Evidence Object pattern to research grounding skill
**Repository:** `/Users/cianosullivan/Repositories/spec-driven-development/`

---

## Scan Methodology

Searched for all files related to:
- Research grounding functionality
- Evidence and citation patterns
- PR/FAQ templates (especially research template)
- Validation and enforcement mechanisms
- Command implementations

**Search patterns used:**
- `**/*research*`, `**/*evidence*`, `**/*prfaq*`, `**/*citation*`
- `skills/*/SKILL.md`, `commands/*.md`
- Grep for "evidence", "validation", "PR/FAQ" across all markdown files

---

## Key Files Identified

### 1. Primary Target File
**`skills/research-grounding/SKILL.md`** (107 lines, ~670 words)
- **Current content:** Research readiness label progression, citation standards for PR/FAQs, discovery workflow using MCPs
- **Word count:** ~670 words (well under 2000-word limit mentioned in spec)
- **Room available:** Substantial capacity for Evidence Object pattern addition
- **Style:** Imperative, structured with tables and checklists
- **Integration points:**
  - Lines 47-69: PR/FAQ Research Base Requirements section
  - Lines 62-68: Citation Format subsection (currently uses inline DOI format)
  - Lines 101-106: Integration with Other Skills section

### 2. PR/FAQ Research Template
**`skills/prfaq-methodology/templates/prfaq-research.md`** (150 lines)
- **Current research base:** Lines 86-106 contain Research Base section with:
  - Theoretical Framework subsection (prose)
  - Key Sources table (# | Source | Finding | Methodology | Relevance)
  - Methodological Notes (bullet list format)
- **Acceptance criteria:** Line 139 requires "Research base section cites 3+ peer-reviewed sources with DOIs"
- **No Evidence Object format currently defined**
- **Integration opportunity:** Replace or augment Key Sources table with Evidence Object format

### 3. PR/FAQ Methodology Skill
**`skills/prfaq-methodology/SKILL.md`** (218 lines)
- **Lines 168-192:** Research Grounding section
  - References research frontmatter field progression
  - Requires 3+ citations in Research Base section
  - No mention of Evidence Object format or validation rules
- **Lines 186-192:** Mandatory Non-Goals and Solution-Scale Constraint sections
  - Example of structured constraint enforcement in methodology

### 4. Command Files
**`commands/write-prfaq.md`** (136 lines)
- **Lines 36-43:** Gather Context step includes research library search for `prfaq-research` template
- **No validation logic** — command focuses on interactive drafting, not enforcement
- **Lines 100-106:** Frontmatter step includes `research:` field but no validation
- **Lines 119-127:** Next Step section mentions `/sdd:go` routing to Gate 1 (spec approval)

**`commands/review.md`** (129 lines)
- **Lines 19-22:** Spec verification checks for required sections before review
- **No Evidence Object validation** — could be extended to validate EV count
- **Lines 68-104:** Synthesis section consolidates findings by severity
- **Integration opportunity:** Reviewer personas could check Evidence Object requirements

### 5. Related Examples
**`examples/sample-prfaq.md`** — No research-specific example found in scan

---

## Current Citation Approach

### Inline Citation Format (research-grounding SKILL.md, lines 62-68)
```markdown
Limerence has been associated with attachment anxiety (Wakin & Vo, 2008; DOI:10.1080/00224490802400129)
and shows overlap with obsessive-compulsive symptomatology (Willmott & Bentley, 2015; DOI:10.1556/2006.4.2015.028).
```
- **Style:** Narrative inline with APA-style author-year
- **Metadata:** Author, year, DOI only
- **No structured claim extraction**

### Key Sources Table (prfaq-research template, lines 93-97)
```markdown
| # | Source | Finding | Methodology | Relevance |
|---|--------|---------|-------------|-----------|
| 1 | [Author (Year). Title. DOI: xxx] | [Key finding] | [Study design, N=] | [How it informs this feature] |
```
- **Structured but not machine-readable**
- **No type classification** (empirical/theoretical/methodological)
- **No confidence assessment**
- **No unique identifiers** (numbering is local to table)

---

## Gaps Identified

### 1. **No Evidence Object Schema**
- Neither `research-grounding/SKILL.md` nor `prfaq-research.md` define Evidence Object format
- Spec requires: ID, type, source, claim, confidence
- Current approach mixes narrative inline citations with unstructured tables

### 2. **No Validation Mechanism**
- `commands/write-prfaq.md` has no validation logic
- `commands/review.md` verifies section presence, not Evidence Object count
- Spec requires: `/sdd:write-prfaq` validates minimum Evidence Object count
- **No command currently performs structured validation**

### 3. **Type System Missing**
- Spec requires 3 types: empirical, theoretical, methodological
- Current citation approach has no type classification
- Research template's "Methodology" column in Key Sources table describes study design, not evidence type

### 4. **Confidence Assessment Absent**
- Spec requires confidence levels: high | medium | low
- No current mechanism for capturing or displaying confidence
- Research grounding skill mentions "psychometric properties" but not confidence in claim support

### 5. **ID Scheme Undefined**
- Spec shows `[EV-001]` format
- No guidance on: global vs. per-spec IDs, collision prevention, reference lookup

---

## Implementation Surface Area

### Required Changes

1. **`skills/research-grounding/SKILL.md`** (PRIMARY)
   - Add Evidence Object format definition (30-50 lines estimated)
   - Update PR/FAQ Research Base Requirements to mandate Evidence Objects
   - Preserve existing citation format as alternative or deprecated approach
   - Maintain imperative style, table-heavy formatting

2. **`skills/prfaq-methodology/templates/prfaq-research.md`**
   - Replace or extend Key Sources table with Evidence Object format
   - Update acceptance criteria line 139 to require 3+ Evidence Objects
   - Provide example Evidence Object in template

3. **`commands/write-prfaq.md`** (CONDITIONAL)
   - Spec says "/sdd:write-prfaq validates minimum Evidence Object count"
   - Current command has no validation step
   - **Decision needed:** Add validation to write-prfaq command, or create separate validation command?

4. **`commands/review.md`** (OPTIONAL)
   - Extend Step 1 spec verification to check Evidence Object count
   - Add to reviewer persona focus areas (lines 43-56)

### Optional Extensions

5. **Create `skills/research-grounding/references/evidence-object-schema.md`**
   - Extract detailed schema if Evidence Object format is complex
   - Aligns with plugin-dev v1.3.0 guidance: keep SKILL.md under 2000 words
   - Reference files for detailed specifications

6. **Update `skills/prfaq-methodology/SKILL.md`**
   - Lines 168-192: Research Grounding section
   - Add Evidence Object requirement to this methodology overview

---

## Dependency Analysis

### Direct Dependencies
- **None.** Evidence Object pattern is additive. Does not break existing functionality.

### Integration Points
1. **MCP Discovery Workflow** (research-grounding lines 70-78)
   - Semantic Scholar, OpenAlex, arXiv, Zotero
   - Evidence Objects will reference sources discovered via these MCPs
   - No changes required to MCP workflow

2. **Research Label Progression** (research-grounding lines 17-45)
   - Transition from `needs-grounding` to `literature-mapped` requires "3+ peer-reviewed papers cited"
   - With Evidence Objects, this becomes "3+ Evidence Objects with peer-reviewed sources"
   - **Minor update needed** to transition criteria language

3. **Spec Frontmatter** (prfaq-methodology lines 99-117)
   - `research:` field already exists
   - No changes required

4. **Adversarial Review** (commands/review.md)
   - Reviewers could validate Evidence Object quality
   - Optional extension, not blocking

### Anti-Dependencies
- **Citation format diversity risk:** Two citation approaches (inline + Evidence Objects) may confuse users
- **Validation location ambiguity:** Unclear whether validation belongs in write-prfaq, review, or separate command

---

## File Size Constraints (Plugin-dev v1.3.0)

| File | Current Size | Limit | Headroom |
|------|-------------|-------|----------|
| `skills/research-grounding/SKILL.md` | ~670 words | ~2000 words | ~1330 words |
| `skills/prfaq-methodology/SKILL.md` | ~1500 words (est) | ~2000 words | ~500 words |
| `skills/prfaq-methodology/templates/prfaq-research.md` | Template (no limit) | N/A | N/A |

**Assessment:** Substantial headroom in `research-grounding/SKILL.md`. If Evidence Object schema exceeds 400-500 words, extract to `skills/research-grounding/references/evidence-object-schema.md`.

---

## Architectural Observations

### 1. **Skill vs. Command Distinction**
- **Skills** define "what" and "why" (methodology, standards, patterns)
- **Commands** define "do this now" (imperative workflows)
- Evidence Object format belongs in **skill** (`research-grounding`)
- Evidence Object validation belongs in **command** (`write-prfaq` or `review`)

### 2. **Template vs. Skill Content**
- Templates show format by example
- Skills provide rules and rationale
- Evidence Object format should appear in **both**:
  - `research-grounding/SKILL.md`: definition and rules
  - `prfaq-research.md`: example and structure

### 3. **Validation Enforcement Gaps**
- Plugin has **no dedicated validation command**
- `write-prfaq` is interactive drafting, not validation
- `review` performs adversarial critique, not format checks
- **Design question:** Should Evidence Object validation be:
  - A. Added to `write-prfaq` as Step 7.5 (between Step 7 and current next step)?
  - B. A new command `validate-prfaq`?
  - C. Added to `review` Step 1 (spec verification)?
  - D. A PostToolUse hook that runs automatically?

### 4. **Research Grounding as Disciplinary Advantage**
- Spec correctly identifies: "Only plugin with academic citation discipline"
- Evidence Objects formalize what is currently ad-hoc
- Aligns with Alteri positioning (research platform, methodology rigor)

---

## Risk Factors

### High Risk
- **Validation location ambiguity:** Spec says "/sdd:write-prfaq validates" but command has no validation logic. Requires design decision.
- **Two citation formats:** Inline citations + Evidence Objects may create inconsistency unless one is deprecated or clearly scoped.

### Medium Risk
- **User adoption friction:** Evidence Objects add structure (good) but also ceremony (potentially bad). Requires clear benefit articulation.
- **Retro-compatibility:** Existing specs use inline citations. Migration path undefined.

### Low Risk
- **Word count:** Plenty of headroom in target files.
- **Integration:** Evidence Objects are additive, not breaking.
- **Type system complexity:** Only 3 types (empirical, theoretical, methodological) — manageable.

---

## Questions for Round 1 Reviewers

1. **Where should validation live?** write-prfaq step, review step, separate command, or hook?
2. **Should inline citations be deprecated?** Or coexist with Evidence Objects for different use cases?
3. **ID collision strategy?** Global registry, per-spec local IDs, or UUID-based?
4. **Confidence assessment guidance:** Who assigns confidence? What criteria? Can it be automated from source metadata?
5. **Backward compatibility:** Do existing specs need migration, or do Evidence Objects apply only to new specs?

---

## Scan Completeness

**Files reviewed:** 15 markdown files
**Files modified (estimated):** 2-4 (research-grounding SKILL, prfaq-research template, possibly write-prfaq command, possibly review command)
**References created (estimated):** 0-1 (evidence-object-schema.md if schema is complex)

**Confidence in scan completeness:** High. Covered skills, commands, templates, examples. No additional evidence-related files found beyond those analyzed.
