# Document Type Taxonomy

Canonical reference for all Linear document types managed by the CCC workflow. This is the **single source of truth** for document classification. Other skills (e.g., `project-cleanup`'s Content Classification Matrix) should reference this file rather than maintaining their own copy.

## Type Definitions

| Type | Staleness Threshold | Naming Pattern | Required Per Project | Description |
|------|---------------------|----------------|---------------------|-------------|
| Key Resources | 14 days | `Key Resources` | Yes (all projects) | Links to repos, specs, external references, deployment URLs, methodology docs |
| Decision Log | 14 days | `Decision Log` | Yes (all projects) | Table of decisions: Decision \| Status \| Date \| Context. Append-only; rotates at 50 entries |
| Project Update | No staleness | `Project Update — YYYY-MM-DD` | No (informational) | Daily status: what changed, what's next, health signal. Created per-session, not audited for staleness |
| Research Library Index | 30 days | `Research Library Index` | Alteri only | Categorized links to all research documents. Only for research-heavy projects |
| ADR | 60 days | `ADR: [Decision Title]` | As needed | Architectural Decision Record. Created when significant technical choices are made |
| Living Document | Configurable (project-level) | Varies | As needed | Project-specific evolving references (e.g., Instrument Battery, Dataset Catalog, API Inventory) |

## Classification Rules

**Is it a document or an issue?** Apply the "Can someone mark this Done?" test:
- **Yes** -> It's an issue (actionable work with verb + done state)
- **No** -> It's a document (reference material, decisions, evolving content)

## Staleness Thresholds

Staleness thresholds define when a document should be flagged in hygiene reports. The thresholds above are defaults:

- **14 days** (Key Resources, Decision Log): These are actively maintained project artifacts. Staleness suggests the project description or decision tracking has drifted.
- **30 days** (Research Library Index): Research indexes update less frequently. Monthly freshness is sufficient.
- **60 days** (ADR): ADRs change infrequently after initial creation. Quarterly review is appropriate.
- **No staleness** (Project Update): Each update is a point-in-time snapshot. Old updates are not "stale" -- they are historical.
- **Configurable** (Living Document): Threshold set per-document in the project description's hygiene protocol section.

## Naming Patterns

Naming patterns are enforced during structural document creation and staleness detection. The patterns above are exact-match for required types and prefix-match for ADRs:

- `Key Resources` -- exact match (one per project)
- `Decision Log` -- exact match (one active per project; archives use `Decision Log Archive — [Year]`)
- `Project Update — YYYY-MM-DD` -- prefix match on `Project Update`
- `Research Library Index` -- exact match (one per project)
- `ADR: ` -- prefix match (multiple per project)
- Living Documents -- no enforced pattern (project-specific)

## Required vs Optional

| Category | Types | Hygiene Label |
|----------|-------|---------------|
| **Required** | Key Resources, Decision Log | `[Required]` |
| **Optional** | Project Update, Research Library Index, ADR, Living Document | `[Optional]` |

Required documents are checked during `/ccc:hygiene --fix` and created if missing (unless project opts out via `<!-- no-auto-docs -->`). Optional documents are reported in hygiene output but never auto-created.

## Cross-References

- `project-cleanup` SKILL.md -- Content Classification Matrix should reference this file (CIA-540)
- `issue-lifecycle` references/project-hygiene.md -- Project artifact cadence aligns with these types
- `hygiene` command -- Structural checklist and staleness detection use this taxonomy
