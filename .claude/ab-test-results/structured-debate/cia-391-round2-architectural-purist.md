# CIA-391 Round 2: Architectural Purist (Blue) — Cross-Examination
**Review Date:** 2026-02-15
**Reviewed:** Security Skeptic, Performance Pragmatist, UX Advocate Round 1 findings

---

## Responses to Other Reviewers

### Security Skeptic

#### C1: Citation Source Injection Risk (XSS)
**Response Type:** AGREE + ARCHITECTURAL IMPLICATION

**Agreement:** XSS risk is real. Architectural perspective: **Sanitization logic placement matters for maintainability.**

**Three placement options:**

**Option 1: Sanitize in presentation layer (Alteri UI)**
```tsx
function EvidenceObject({ source }) {
  return <div dangerouslySetInnerHTML={{ __html: sanitize(source) }} />
}
```
- **Problem:** Sanitization coupled to React components. If Evidence Objects render in CLI (markdown preview), Markdown emails (spec distribution), or API responses (future), sanitization must be reimplemented in each context. Tight coupling, violates DRY.

**Option 2: Sanitize in data layer (at storage)**
```python
def create_evidence_object(source):
  sanitized_source = sanitize(source)
  return EvidenceObject(source=sanitized_source)
```
- **Benefit:** Sanitization happens once, all consumers get clean data. Single source of truth.
- **Problem:** If sanitization rules change (new XSS vector discovered), must migrate stored data. Schema evolution issue (my I1).

**Option 3: Sanitize at schema boundary (input validation layer)**
```python
class EvidenceObjectSchema:
  source: str = Field(..., pre_validators=[sanitize])
```
- **Benefit:** Sanitization is **schema constraint**, not storage or presentation concern. Survives format changes (my C1), rendering changes, storage changes.
- **Best architectural pattern:** Input validation at schema boundary.

**Recommendation:** Security's sanitization rules belong in canonical schema (`evidence-object-schema.md`), not format definition or rendering logic.

**This requires my C1 (schema separation).** Can't implement proper sanitization without decoupling schema from format.

---

#### C2: Confidence Level Manipulation Without Attribution
**Response Type:** CONTRADICT (on implementation)

**Disagreement:** Security wants confidence immutability after spec approval. This creates **temporal coupling**—field behavior depends on workflow state.

**Architectural smell:**
```python
# Confidence is mutable UNTIL spec status changes
if spec.status == "draft":
    evidence_object.confidence = new_value  # OK
elif spec.status == "ready":
    raise ImmutableFieldError  # Not OK
```

**Problems:**
1. **State-dependent behavior violates single responsibility.** Evidence Object model must know about spec lifecycle. Tight coupling between domain objects.
2. **Testing complexity.** Must test Evidence Object behavior in every spec state (draft, review, ready, implementing, complete). 5 states × N tests.
3. **Brittleness.** If workflow adds new state ("pending-stakeholder-review"), must update Evidence Object immutability logic.

**Alternative: Event sourcing pattern**
```python
# Evidence Objects are immutable value objects
# Changes create new version with provenance

ConfidenceAssessed(
  evidence_id="EV-001",
  confidence="high",
  assessed_by="claude-agent",
  assessed_at="2026-02-15T10:30:00Z",
  reason="Meta-analysis, N=5000, replicated"
)

ConfidenceRevised(
  evidence_id="EV-001",
  previous_confidence="high",
  new_confidence="medium",
  revised_by="human-reviewer",
  revised_at="2026-02-15T14:30:00Z",
  reason="Sample had selection bias"
)
```

**Benefits:**
- Confidence history is **append-only log**, not mutable field
- No temporal coupling (Evidence Object doesn't know about spec states)
- Full audit trail (Security's requirement) without state checks
- Testable (event log is data, not behavior)

**Trade-off:** More complex than Security's mutable-field-with-gates approach. But architecturally sounder.

**Recommendation:** If audit trail is required (Security C2), use event sourcing. If not required, use immutable value objects (no edits, only replacements). Never use state-dependent mutability.

---

#### I1: Evidence Object ID Namespace Collisions
**Response Type:** AGREE + CONTENT ADDRESSING DETAILS

**Agreement:** ID collision is risk. Performance validated content hash approach. I add: **Content-addressable IDs enable powerful architectural patterns.**

**Benefits of content addressing beyond collision prevention:**

**1. Automatic deduplication**
```
User A adds: [EV-abc123] Source: Wakin & Vo (2008)... Claim: "Limerence involves intrusive thinking"
User B (different spec) adds same paper, same claim
System: "EV-abc123 already exists. Reuse? [y/n]"
```
If yes, both specs reference same canonical Evidence Object. Update claim in one place, both specs reflect change (or warn about divergence). **Reduces redundancy.**

**2. Diff-friendly**
```diff
- [EV-001] Type: empirical...
+ [EV-002] Type: empirical...
```
Sequential IDs make diffs look like addition/removal when it's actually content change. Content hash:
```diff
- [EV-abc123] ...Claim: "Old claim"...
+ [EV-def456] ...Claim: "New claim"...
```
Clearly shows: different content = different ID. **Improves git history semantics.**

**3. Referential integrity**
```
Spec references [EV-abc123] in FAQ section.
Later, user deletes Evidence Object.
Validation: "Broken reference: [EV-abc123] not found in Research Base"
```
Content hash makes references **strongly typed**. Can't accidentally delete Evidence Object that's still referenced. **Prevents dangling pointers.**

**Implementation detail:** Hash collision strategy at scale.

If IDs are 12-char truncated hashes (Performance's recommendation), collision probability:
- 10 Evidence Objects: negligible
- 1,000 Evidence Objects: 1 in 16 trillion (fine)
- 1,000,000 Evidence Objects: ~1 in 16 million (not fine)

**Mitigation:** If collision detected (rare), append collision counter:
```
[EV-7f3e4d2a1b6c] (canonical)
[EV-7f3e4d2a1b6c-1] (collision, different content)
```

At 1M scale, switch to full 64-char hashes or UUIDs. But spec says 10 EV max per spec, so collision is non-issue for foreseeable future.

---

### Performance Pragmatist

#### C1: No Evidence Object Count Upper Bound
**Response Type:** AGREE + ARCHITECTURAL CONSTRAINT

**Agreement:** Unbounded collections are architectural anti-pattern. Performance identified latency. I add: **Bounded collections enable simpler data structures.**

**Architectural benefit of 10 EV max:**

**Without bound:**
- Evidence Objects = dynamic array (resizable)
- Insertion: O(1) amortized (occasionally O(n) when resizing)
- Lookup by ID: O(n) linear search or O(log n) with indexing
- Memory: Unpredictable (could be 1KB or 1MB)

**With bound (10 max):**
- Evidence Objects = fixed array or small map
- Insertion: O(1) always
- Lookup by ID: O(1) with map or O(10) ≈ O(1) with linear search (small constant)
- Memory: Predictable (≤10KB per spec)

**Simpler data structures = simpler code = fewer bugs.**

Also enables **static analysis**. If format spec says "10 max," linter can flag violations before runtime:
```yaml
# In spec frontmatter
evidence_objects:
  - EV-001: {...}
  - EV-002: {...}
  ...
  - EV-011: {...}  # Linter: ERROR - exceeds 10 EV limit
```

**Recommendation:** Encode upper bound in schema (`maxItems: 10`), not just documentation. Enables tools to enforce limit statically.

---

#### C2: Source Metadata Fetching Creates Validation Bottleneck
**Response Type:** AGREE + CACHING ARCHITECTURE

**Agreement:** Sequential API calls = slow. Parallel fetch + caching = faster. Architectural perspective: **Where does cache live?**

**Cache placement options:**

**Option 1: In-memory cache (process-local)**
```python
cache = {}  # dict in Python process
```
- **Lifetime:** Process lifetime (cleared on restart)
- **Concurrency:** Single process only
- **Invalidation:** LRU eviction or TTL
- **Latency:** <1ms (memory access)
- **Problem:** Each validation process (CI worker, dev laptop, agent instance) has separate cache. No sharing.

**Option 2: File-based cache (filesystem)**
```python
cache_dir = ".evidence-cache/"
```
- **Lifetime:** Persistent across processes
- **Concurrency:** Shared within same machine (but needs locking)
- **Invalidation:** File mtime-based or explicit `.cache/metadata.json` with TTL
- **Latency:** 5-10ms (disk I/O)
- **Problem:** Not shared across machines. CI and dev laptop have separate caches.

**Option 3: Distributed cache (Redis, Memcached)**
```python
cache = redis.StrictRedis(...)
```
- **Lifetime:** Persistent, shared across all machines
- **Concurrency:** Thread-safe, supports multiple processes/machines
- **Invalidation:** Native TTL support
- **Latency:** 10-50ms (network + Redis lookup)
- **Problem:** Infrastructure dependency (spec says this is methodology plugin, not execution plugin). Adds complexity.

**Recommendation for this spec (methodology plugin):**
- **Dev:** In-memory cache (fast, simple, no infra)
- **CI:** File-based cache (`.evidence-cache/` committed to repo or restored from CI cache). Shared across CI runs.
- **Future (if becomes execution plugin):** Distributed cache (Redis) for multi-machine environments.

**Performance's 7-day TTL:** Too long (Security's stale data concern). I recommend:
- **Dev:** 24 hours (fast iteration, reasonable freshness)
- **CI:** 7 days (CI runs frequently, caching reduces API costs)

**Architectural principle:** Cache placement should match deployment model. Single-process = in-memory. Multi-process same-machine = file. Multi-machine = distributed.

---

#### I1: Evidence Object Format Bloats Spec Files
**Response Type:** AGREE + THIS IS MY C1

**Agreement:** 5-line format is verbose. Token overhead is significant. This is exactly my C1 concern (schema/format coupling).

**Synergy:** Performance's compact format proposal + my schema separation proposal = same solution.

**Canonical schema (my C1):**
```yaml
# evidence-object-schema.md
EvidenceObject:
  id: string
  type: enum
  source: object
  claim: string
  confidence: enum
```

**Format 1: Verbose markdown (for human drafting)**
```markdown
[EV-001] Type: empirical
Source: Author (Year). Title. Journal.
Claim: "Claim text"
Confidence: high
```

**Format 2: Compact YAML (for agent consumption)**
```yaml
EV-001: {type: empirical, source: "Author (Year). Title.", claim: "Claim text", confidence: high}
```

**Format 3: JSON (for API)**
```json
{"id": "EV-001", "type": "empirical", "source": "Author (Year). Title.", "claim": "Claim text", "confidence": "high"}
```

**All three formats serialize the same canonical schema.** Schema is single source of truth. Formats are views.

**This is textbook separation of concerns:** Model (schema) vs. View (formats) vs. Controller (validation).

**Recommendation:** Implement schema separation (my C1) specifically to enable Performance's compact format. Don't frame as "architectural purity"—frame as "token cost reduction" (more persuasive to pragmatic stakeholders).

---

### UX Advocate

#### C1: Evidence Object Format Has High Cognitive Load
**Response Type:** AGREE + ARCHITECTURAL SOLUTION

**Agreement:** Manual formatting is hard. Interactive helper is good UX. Architectural perspective: **Helper is abstraction layer.**

**Current architecture (no helper):**
```
User → writes markdown → Evidence Object exists
```
**Problem:** User must know format details. High coupling between user and format.

**With helper:**
```
User → provides data → Helper → formats Evidence Object → Evidence Object exists
```
**Benefit:** User is decoupled from format. Helper encapsulates formatting logic. If format changes (e.g., 5-line → YAML), only helper updates. User workflow unchanged.

**This is dependency inversion principle:** User depends on abstraction (helper interface), not concretion (markdown format).

**Architectural implication:** Interactive helper is not just UX feature. It's **abstraction boundary** between user intent and data representation.

**Design principle:** Never let users hand-write structured data. Always provide generator/helper. This principle extends beyond Evidence Objects:
- PR/FAQ templates (generated from answers, not written from scratch)
- Acceptance criteria (derived from FAQ, not invented separately)
- Evidence Objects (generated from DOI, not manually formatted)

**Recommendation:** Make interactive helper **primary input method**, not alternative. Markdown format becomes **output format** (generated by helper), not **input format** (written by user).

**This inverts current design:** Spec shows markdown format, implies user writes it. Better: Spec shows helper commands, format is implementation detail.

---

#### C2: No Guidance on When to Add Evidence Objects
**Response Type:** AGREE + WORKFLOW AS STATE MACHINE

**Agreement:** Workflow ambiguity creates friction. Architectural solution: **Formalize workflow as state machine.**

**State machine for Evidence Object workflow:**

```
States:
1. Problem Identified
2. Claims Extracted
3. Evidence Needed (Claims Flagged)
4. Evidence Gathered
5. Evidence Objects Created
6. Spec Validated

Transitions:
Problem Identified → Claims Extracted (user writes Press Release)
Claims Extracted → Evidence Needed (agent scans for psych constructs)
Evidence Needed → Evidence Gathered (user searches literature)
Evidence Gathered → Evidence Objects Created (helper formats EV)
Evidence Objects Created → Spec Validated (validation runs)
```

**State machine benefits:**
1. **Clear checkpoints:** User knows when they've completed each stage
2. **Incremental validation:** Validation runs at each transition (Performance's I2)
3. **Explicit prerequisites:** Can't validate (state 6) without creating Evidence Objects (state 5)
4. **Progress tracking:** "You're at stage 4/6: Evidence Gathered. Next: Create Evidence Objects."

**Implementation:** State machine encoded in command logic (not just documentation). `/sdd:write-prfaq` tracks current state, prompts for next action.

**Alternative to state machine:** Checklist (simpler but less formal).
```markdown
Evidence Object Workflow:
- [ ] Identify claims needing evidence (Press Release/FAQ)
- [ ] Search for papers (Semantic Scholar/arXiv)
- [ ] Create 3+ Evidence Objects (DOI → helper → formatted EV)
- [ ] Validate (≥3 EV, confidence assigned, references resolved)
```

**Trade-off:** State machine is more rigorous (enforces order). Checklist is more flexible (can do out of order). For research grounding, rigor matters. Recommend state machine.

---

#### I2: Confidence Field Lacks User Guidance
**Response Type:** AGREE + RUBRIC AS POLICY

**Agreement:** Confidence assignment needs guidance. Architectural perspective: **Rubric should be encoded, not documented.**

**Two approaches to rubrics:**

**Approach 1: Documented rubric (UX proposal)**
```markdown
## Confidence Rubric
- High: Journal IF >5, N>500, replicated...
- Medium: ...
```
**Problem:** Documentation can be ignored or misinterpreted. No enforcement.

**Approach 2: Encoded rubric (executable policy)**
```python
class ConfidencePolicy:
  def calculate(self, source_metadata):
    score = 0
    if source_metadata.impact_factor > 5: score += 1
    ...
    return "high" if score >= 3.5 else "medium" if score >= 2 else "low"
```
**Benefit:** Rubric is executable. Can't be misapplied. Consistent across users.

**Architectural principle:** **Policy as code, not documentation.** If behavior must be consistent, encode it. Don't rely on humans to follow written rules correctly.

**This aligns with Security's confidence automation proposal and Performance's latency mitigation.**

**Recommendation:** Implement confidence rubric as Python function (or JavaScript if Alteri is execution context). Store in `skills/research-grounding/references/confidence-policy.py`. Validation calls this function. Documentation explains what function does, but function is source of truth.

---

## Position Changes

### Original Position: REJECT (with path to approval)
**New Position:** CONDITIONAL APPROVE

**Reasoning:** Cross-examination revealed that my REJECT was too harsh. Other reviewers proposed pragmatic mitigations that satisfy my architectural concerns:

1. **C1 (schema/format coupling):** Performance + Security both need schema separation for different reasons (token savings, sanitization placement). Not just architectural purity.
2. **C2 (ID format):** Performance validated content hash approach. Addresses both architectural (SRP) and security (spoofing) concerns.
3. **I1 (versioning):** Performance's additive-only rule is practical versioning strategy.
4. **I2 (skill/template coupling):** UX's helper abstracts format, reducing coupling.
5. **I3 (validation location):** Performance's separate validation command is architecturally sound.

**My original REJECT assumed spec would ship with tight coupling unchanged. Cross-examination shows tight coupling can be fixed with ~12 hours effort (Performance estimate). That's reasonable for architectural correctness.**

**Conditions for APPROVE:**
1. Extract Evidence Object schema to `evidence-object-schema.md` (my C1)
2. Use content hash IDs with 12-char truncation (my C2, Performance validation)
3. Add `version: 1.0` to schema (my I1)
4. Create validation library as reusable component (my I3)
5. Implement interactive helper as primary input method (UX C1, decouples format)

**These conditions are achievable. Position change from REJECT to CONDITIONAL APPROVE is warranted.**

---

## New Insights

### 1. Architecture Enables Other Dimensions
Proper architecture (schema separation, content addressing, abstraction layers) is not orthogonal to performance, security, UX—it **enables** them:

- Schema separation → token savings (performance) + sanitization centralization (security)
- Content hash IDs → deduplication (performance) + spoofing prevention (security)
- Interactive helper → cognitive load reduction (UX) + automatic sanitization (security)

**Architecture is force multiplier, not constraint.**

---

### 2. Methodology Plugin ≠ No Executable Code
Spec says "methodology plugin" (not execution plugin). I interpreted this as "documentation only." Cross-examination shows executable code is needed:

- Validation library (checking Evidence Object count, format, confidence)
- Interactive helper (formatting Evidence Objects from DOI input)
- Confidence policy (calculating confidence from rubric)

**Methodology plugin CAN include executable tooling** as long as tooling enforces methodology, not replaces human judgment.

**Revised understanding:** Methodology = standards + tools to enforce standards. Not just standards alone.

---

### 3. Event Sourcing for Audit Trails
Security's confidence attribution requirement is really **audit trail requirement**. Event sourcing pattern (append-only log of confidence assessments) is architecturally sounder than mutable fields with history tracking.

**Generalizes to other fields:** If any field needs audit trail (not just confidence), use event sourcing. This is architectural pattern worth extracting.

---

### 4. Bounded Collections Enable Static Analysis
Performance's 10 EV upper bound enables **architectural verification**: Can lint specs for over-limit Evidence Objects before runtime. This principle generalizes: Whenever introducing bounded collection, encode bound in schema for tooling support.

---

## Revised Scoring

| Dimension | Original | Revised | Change Rationale |
|-----------|----------|---------|------------------|
| **Separation of Concerns** | 45/100 | 60/100 | ↑ Interactive helper (UX) + validation library (Performance) reduce coupling vs. original spec |
| **Extensibility** | 50/100 | 65/100 | ↑ Content hash IDs + schema versioning + event sourcing (Security) improve extensibility |
| **Reusability** | 55/100 | 65/100 | ↑ Validation library + confidence policy as reusable components |
| **Testability** | 70/100 | 75/100 | ↑ Event sourcing + policy as code improve testability |

**Overall Architecture Score:** 66/100 (was 54/100)
**Risk Level:** MEDIUM (was HIGH)

**Reasoning for upgrade:** Mitigations proposed by other reviewers address my core concerns. With those mitigations, architecture is acceptable (not perfect, but acceptable for v1).

---

## Agreements

### Performance C1 (Upper Bound)
Agree. Bounded collections are architectural best practice. Enables simpler data structures + static analysis.

### Performance C2 (Caching)
Agree + extend with cache placement strategy (in-memory vs. file vs. distributed).

### Performance I1 (Format Bloat)
Agree. This is my C1 (schema/format coupling). Same solution.

### Security C1 (XSS)
Agree + sanitization should be schema constraint (requires my C1 schema separation).

### Security I1 (ID Collision)
Agree + content hash enables powerful patterns (deduplication, referential integrity).

### UX C1 (Cognitive Load)
Agree. Interactive helper is abstraction layer (architectural benefit, not just UX).

### UX C2 (Workflow Ambiguity)
Agree. Formalize as state machine for clarity + enforcement.

### UX I2 (Confidence Rubric)
Agree. Encode rubric as policy (code), not documentation.

---

## Contradictions

### Security C2 (Confidence Immutability)
**Security says:** Mutable field with state-dependent behavior (immutable after approval).

**I say:** Event sourcing (append-only log) or immutable value objects (replacements, not edits).

**Reasoning:** State-dependent mutability violates SRP, increases testing complexity, creates temporal coupling.

**Resolution:** If audit trail is required, use event sourcing. If not, use immutable objects. Avoid state-dependent mutability.

---

## Recommendation (Updated)

**CONDITIONAL APPROVE** — Position changed from REJECT.

**Required architectural refactors:**
1. Create `skills/research-grounding/references/evidence-object-schema.md` (canonical data model)
2. Implement content hash IDs with 12-char truncation
3. Add schema versioning (`version: 1.0`)
4. Extract validation logic to `skills/research-grounding/references/evidence-object-validator.md`
5. Build interactive helper as primary input method (abstracts format from user)

**Estimated effort:** ~12 hours (Performance estimate, validated).

**Priority:** All five refactors should be **Phase 1** (MVP), not Phase 2. They're foundational for extensibility, not polish.

**If shipped without refactors:** Architectural debt accumulates. First schema change requires painful migration. Coupling prevents evolution. **But spec is functional**—just not maintainable long-term.

**Compromise position (if 12 hours not available):** Ship with tight coupling, create GitHub issues for refactors, commit to addressing in Phase 2 before 10+ specs use Evidence Objects. Not ideal, but pragmatic.

**I prefer Phase 1 refactors but acknowledge compromise is defensible given resource constraints.**

---

## Metadata

**Cross-Examination Duration:** 50 minutes
**Reviews Consulted:** Security Skeptic, Performance Pragmatist, UX Advocate (all Round 1)
**Position Changed:** Yes (REJECT → CONDITIONAL APPROVE)
**Score Changed:** Yes (54→66, upgrade due to viable mitigations)
**Agreements:** 8 | Contradictions: 1 | Priority Shifts: 1 (Phase 2 → Phase 1)
**Bias Disclosure:** Position change may indicate over-valuing pragmatism vs. original architectural rigor. Acknowledged.
