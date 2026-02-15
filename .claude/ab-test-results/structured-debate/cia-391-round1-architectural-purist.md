# CIA-391 Round 1: Architectural Purist (Blue)
**Persona:** Architectural Purist — Coupling, cohesion, API contracts, naming, extensibility
**Review Date:** 2026-02-15
**Spec:** CIA-391 — Add Evidence Object pattern to research grounding skill

---

## Critical Findings

### C1: Tight Coupling Between Citation Format and Storage Layer
**Severity:** CRITICAL
**Section:** Evidence Object format definition

**Issue:** The spec defines Evidence Object format as presentational markdown structure (5-line format) but does NOT separate concerns between data model and view layer. This conflates three responsibilities:

1. **Data schema** (what fields exist)
2. **Serialization** (how data is stored)
3. **Presentation** (how data renders to users)

**Architectural smell:** If Evidence Objects are stored exactly as the 5-line markdown format, changing presentation requires data migration. Example: Adding a new field `DOI:` requires updating every existing Evidence Object in every spec file.

**Coupling chain identified:**
- `research-grounding/SKILL.md` defines format → `prfaq-research.md` template uses format → User writes spec with format → Validation checks format → Alteri renders format
- **Five layers coupled to single format definition.** Brittle.

**Comparison to current approach:** Inline citations `(Author, Year; DOI)` are also coupled, but they're **display format only**. No tooling parses them. Evidence Objects are machine-parseable, so coupling has operational consequences.

**Why this is critical:** Evidence Object schema WILL evolve. Security Skeptic wants attribution tracking. Performance Pragmatist wants compact format. Adding fields or alternative formats requires touching 5+ files and migrating data.

**Mitigation:**
1. **Separate schema from format.** Define canonical data model in `skills/research-grounding/references/evidence-object-schema.md`:
   ```yaml
   EvidenceObject:
     id: string (required, unique within spec)
     type: enum(empirical, theoretical, methodological) (required)
     source: object (required)
       authors: string[]
       year: integer
       title: string
       venue: string
       doi: string (optional)
     claim: string (required, max 300 chars)
     confidence: enum(high, medium, low) (required)
     metadata: object (optional, extensible)
       created_by: string
       created_at: timestamp
       confidence_basis: string
   ```
2. **Define multiple views.** Markdown 5-line format is **one rendering** of canonical schema. Also support:
   - Compact YAML (for agents)
   - JSON (for API endpoints)
   - HTML (for Alteri UI)
3. **Tooling operates on schema, not format.** Validation parses Evidence Objects into schema, validates schema, re-serializes to format. Format changes don't break validation logic.

**Detection:** If adding a field requires editing validation logic, schema is coupled to format. Fix: Validation operates on schema objects, not raw strings.

---

### C2: Evidence Object ID Format Violates Single Responsibility
**Severity:** CRITICAL
**Section:** [EV-001] ID format

**Issue:** Spec shows `[EV-001]` format but this format serves two purposes:

1. **Unique identifier** (for cross-references, deduplication)
2. **Presentational marker** (markdown rendering)

**Architectural problem:** Square brackets `[]` are markdown link syntax. Using `[EV-001]` means Evidence Object IDs collide with markdown link parsing. If user writes:

```markdown
As discussed in [EV-003], limerence shows...
```

Markdown parser treats `[EV-003]` as potential link reference. If Evidence Objects are stored in separate file, link resolution breaks.

**Compounding issue:** ID format embeds sequence number (`001`). This assumes:
- Linear ordering (what if Evidence Objects are added/removed during review?)
- Padding semantics (why 001 not 1? Is padding significant?)
- Max 999 Evidence Objects (what happens at 1000?)

**Why this is critical:** ID format is load-bearing. It appears in:
- Spec markdown (user-facing)
- Validation logic (machine-readable)
- Cross-references within spec (structural)
- Potentially database primary key (if stored in DB)

If ID format needs to change (e.g., to avoid markdown collision), every layer breaks.

**Mitigation:**
1. **Separate logical ID from display ID.** Canonical ID = UUID or content hash (collision-free). Display ID = `[EV-001]` (human-friendly). Maintain bidirectional mapping.
2. **Use HTML comments for logical IDs:**
   ```markdown
   [EV-001] <!-- id: 7f3e4d2a-1234-5678-9abc-def012345678 -->
   Type: empirical
   Source: ...
   ```
   User sees `[EV-001]`, tooling uses UUID.
3. **Alternative: Use definition list syntax** (no markdown collision):
   ```markdown
   EV-001
   : Type: empirical
   : Source: Author (Year). Title.
   : Claim: "Claim text"
   : Confidence: high
   ```
   Markdown-native, semantically clear, no link syntax collision.

**Detection:** Try parsing spec markdown with Evidence Objects using standard markdown parser (e.g., `remark`). If link resolution emits warnings, ID format has collision.

---

## Important Findings

### I1: Evidence Object Format Not Versioned
**Severity:** IMPORTANT
**Section:** Schema evolution strategy

**Issue:** Evidence Object format will evolve (add fields, change constraints). Spec does NOT include version field. How does system handle mixed-version Evidence Objects?

**Scenario:** Today's format has 4 required fields (type, source, claim, confidence). Next year, format adds `methodology` field (required). Old specs have Evidence Objects without `methodology`. Do they become invalid?

**Architectural pattern missing:** Schema versioning. Common solutions:
- **Explicit version field:** `version: 1.0`
- **Format detection:** Infer version from field presence
- **Migration tooling:** `migrate-evidence-objects --from 1.0 --to 2.0`

**Why this matters:** Plugin claims to be "only plugin with academic citation discipline." As research standards evolve, Evidence Object schema MUST evolve. Without versioning, evolution breaks backward compatibility.

**Mitigation:**
1. Add `version: 1.0` to Evidence Object schema (canonical model from C1).
2. Validation checks version, applies version-specific rules.
3. Create `/sdd:migrate-evidence-objects` command for schema migrations.
4. Document deprecation policy: Old versions supported for 2 plugin releases, then migration required.

---

### I2: No Abstraction Between Research Grounding Skill and PR/FAQ Template
**Severity:** IMPORTANT
**Section:** Integration with prfaq-research.md

**Issue:** Spec says "Update `skills/research-grounding/SKILL.md` with Evidence Object pattern" AND "PR/FAQ research template requires 3+ Evidence Objects." This creates tight coupling:

**Dependency direction:**
```
prfaq-research.md (template)
    ↓ depends on
research-grounding/SKILL.md (skill definition)
    ↓ defines
Evidence Object format
```

**Problem:** Template change requires skill change, and vice versa. If someone wants to use Evidence Objects in a different template (e.g., `prfaq-feature` for empirically-grounded product feature), they must duplicate Evidence Object format definition.

**Architectural principle violated:** DRY (Don't Repeat Yourself). Evidence Object format should be defined ONCE, referenced by multiple consumers.

**Better architecture:**
```
evidence-object-schema.md (canonical schema)
    ↑ referenced by
research-grounding/SKILL.md (research workflow)
    ↑ referenced by
prfaq-research.md (template)
    ↑ and potentially
prfaq-feature.md (template, optional EV support)
```

**Mitigation:**
1. Create `skills/research-grounding/references/evidence-object-schema.md` as single source of truth.
2. Update `research-grounding/SKILL.md` to reference schema, not define it inline.
3. Update `prfaq-research.md` to reference schema for format details.
4. Enable Evidence Objects in other templates via optional Research Base section.

---

### I3: Validation Logic Location Unclear
**Severity:** IMPORTANT
**Section:** Acceptance criteria - "/sdd:write-prfaq validates"

**Issue:** Spec says validation happens in `/sdd:write-prfaq` command but codebase scan shows this command has no validation logic. Architectural question: Where does validation logic live?

**Options:**
1. **In command** (`commands/write-prfaq.md`) — Validation embedded in workflow. High coupling.
2. **In skill** (`skills/research-grounding/SKILL.md`) — Validation defined as methodology. No executable code.
3. **Separate command** (`/sdd:validate-prfaq`) — Validation as independent operation. Reusable.
4. **Hook** (`PostToolUse` hook) — Validation as runtime constraint. Automatic enforcement.

**Architectural concern:** Skills define "what and why," commands define "do this." Validation is imperative ("check this"), so belongs in command or hook, not skill. But spec puts Evidence Object definition in skill, validation in command. **Misaligned layers.**

**Recommended architecture:**
- **Skill** (`research-grounding/SKILL.md`): Defines Evidence Object schema, citation standards, confidence criteria (declarative)
- **Validation library** (`skills/research-grounding/references/evidence-object-validator.md`): Validation rules as reusable logic (imperative, but library not command)
- **Command** (`/sdd:validate-prfaq`): Invokes validation library, formats results for user (imperative)
- **Other commands** (`write-prfaq`, `review`): Call `/sdd:validate-prfaq` internally (composition)

**Mitigation:** Create validation library reference document. Commands invoke library, don't reimplement logic.

---

## Consider

### N1: Evidence Object as First-Class Entity
**Severity:** CONSIDER

**Observation:** Evidence Objects are embedded in spec files. They're not first-class entities (no dedicated storage, no API endpoints, no cross-spec queries).

**Architectural trade-off:**
- **Embedded** (current spec): Simple, no infrastructure, git-trackable, but no cross-spec analysis.
- **First-class** (alternative): Database-backed, queryable, but higher complexity, needs migration.

**For current scope:** Embedded is correct choice. But as Evidence Objects accumulate, may need extraction. Suggest: Keep embedded for v1, design extraction path for v2.

---

### N2: Evidence Object Composition Unclear
**Severity:** CONSIDER

**Question:** Can Evidence Objects reference other Evidence Objects? E.g., `[EV-001]` is primary study, `[EV-002]` is meta-analysis that includes `[EV-001]`.

**Architectural relevance:** If composition is allowed, Evidence Objects form a graph not a list. Validation must check for cycles. Cross-references must be resolvable.

**Recommendation:** Explicitly forbid composition in v1. Keep Evidence Objects flat. Revisit in v2 if use case emerges.

---

### N3: Confidence Calculation as Derived Property
**Severity:** CONSIDER

**Observation:** Spec treats confidence as user-assigned field. Security Skeptic wants it derived from source metadata (journal tier, citation count). Performance Pragmatist worries about fetch latency.

**Architectural perspective:** Confidence could be **calculated property** not **stored field**. Schema stores raw metadata (DOI, citation count, publication year). Confidence computed on-demand using rubric.

**Benefits:** No stale confidence values. Rubric changes apply retroactively. No manual assignment errors.

**Costs:** Requires metadata fetching (Performance concern C2). More complex validation.

**Recommendation:** Hybrid approach. Store both:
- `confidence_assigned: high` (user's assessment)
- `confidence_calculated: medium` (algorithm's assessment)
Validation warns if mismatch. User must justify discrepancy.

---

## Quality Score

| Dimension | Score | Justification |
|-----------|-------|---------------|
| **Separation of Concerns** | 45/100 | Critical: Schema coupled to presentation (C1). No abstraction between skill and template (I2). Validation logic misplaced (I3). |
| **Extensibility** | 50/100 | Critical: ID format not future-proof (C2). No schema versioning (I1). Adding fields requires data migration. |
| **Reusability** | 55/100 | Evidence Object format defined once but tightly coupled to research template. Not easily reusable in other contexts. |
| **Maintainability** | 60/100 | 5-line format is readable. YAML-parseable. But format evolution is brittle (C1, I1). |
| **Testability** | 70/100 | Structured format enables validation testing. But validation logic location unclear (I3). |

**Overall Architecture Score:** **54/100**
**Risk Level:** **HIGH** — Core abstractions missing. Tight coupling will hinder evolution.

---

## What Gets Right

1. **Structured format:** Evidence Objects are machine-parseable. Huge improvement over inline citations. Enables tooling and validation.

2. **Type classification:** Empirical/theoretical/methodological types are domain-relevant. Good semantic modeling.

3. **Required fields:** Type, source, claim, confidence are correct minimum viable schema. Not over-engineered.

4. **Additive feature:** Doesn't break existing functionality. Can be adopted gradually. Low-risk integration.

---

## Recommendation

**REJECT (with path to approval)** — Current spec has architectural debt that will compound. Must fix C1 (schema/format separation) and C2 (ID format) before implementation. These are design-level issues, not tweaks.

**Required refactoring:**
1. Extract Evidence Object schema to separate reference document (C1, I2)
2. Redesign ID format to avoid markdown collision and enable evolution (C2)
3. Add schema versioning field (I1)
4. Define validation library as reusable component (I3)

**Path to approval:**
1. Create `skills/research-grounding/references/evidence-object-schema.md` with canonical data model
2. Update `research-grounding/SKILL.md` to reference schema and define usage standards
3. Update `prfaq-research.md` to show example Evidence Objects rendered from schema
4. Create `skills/research-grounding/references/evidence-object-validator.md` with validation rules
5. Update spec acceptance criteria to reflect layered architecture

**If shipped without refactoring:** Technical debt accumulates. First schema change requires painful migration. Multiple formats emerge (team uses different conventions). Validation logic duplicates across commands.

**Estimated refactoring effort:** 3-4 hours to separate schema/format/validation into layered architecture. 1 hour to update spec acceptance criteria. Not blocking for timeline but blocking for quality.

---

## Counterargument to My Own Review

**Devil's advocate:** Is this over-engineering? Spec is for a markdown-based citation format. Not building a database schema. Maybe tight coupling to 5-line markdown format is fine?

**Response:** Fair point for short-term scope. But spec explicitly says "/sdd:write-prfaq validates minimum Evidence Object count." Validation requires parsing. Parsing requires schema. If schema is implicit (just "5 lines of markdown"), validation becomes brittle string matching. Better to make schema explicit now than refactor later when 50 specs depend on format.

**Compromise position:** Ship v1 with 5-line format as both schema and presentation. Document known coupling. Add GitHub issue for schema extraction. Revisit when 10+ specs use Evidence Objects (empirical threshold for refactoring). This balances pragmatism (ship now) with discipline (acknowledge debt).

**I maintain REJECT recommendation but acknowledge compromise position is defensible.**

---

## Metadata

**Review Duration:** 40 minutes
**Codebase Scan Consulted:** Yes (validation location informed I3, skill/template coupling informed I2)
**Architecture Patterns Referenced:** DRY, Separation of Concerns, Schema Versioning, Content-Addressable Storage
**Confidence in Review:** High (architectural issues clearly identified)
**Bias Disclosure:** I favor layered architecture over expedient coupling. May be over-valuing abstraction given small initial scope.
