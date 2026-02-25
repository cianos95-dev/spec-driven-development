# Maintenance Protocol (absorbed from project-cleanup)

One-time structural normalization of a project's issues, documents, and metadata. This is distinct from ongoing hygiene (`/ccc:hygiene`) which audits health, and the main issue-lifecycle skill which governs day-to-day ownership. Cleanup handles destructive and structural changes that hygiene explicitly avoids.

## When to Use

- Project has accumulated convention debt (bracket prefixes, missing type labels, inconsistent naming)
- Non-actionable content stored as issues (research notes, decisions, session learnings)
- Onboarding an existing project to CCC conventions for the first time
- Reclaiming issue tracker slots by converting reference material to documents

## Content Classification Matrix

The core question: **Can someone mark this "Done"?** If yes, it's an issue. If no, it's a document.

| Content Type | Container | Test | Examples |
|---|---|---|---|
| Actionable work with verb + done state | **Issue** | Has a completable action | "Build X", "Fix Y", "Evaluate Z" |
| Research notes, literature reviews | **Document** (`Research:` prefix) | Reference material only | Survey results, paper summaries, literature maps |
| Architectural/methodology decisions | **Document** (`Decision:` prefix) | Choice record, not action | "Use Yjs over Automerge", "Choose JWT over sessions" |
| Session learnings, retrospectives | **Document** (`Session:` prefix) | Historical reference | Post-session notes, debug trails |
| Dataset inventories, instrument specs | **Document** (living, no prefix) | Evolves without completing | Measurement battery, API inventory, dataset catalog |
| Templates, plans (non-actionable) | **Document** (`Template:` or `Plan:` prefix) | Reusable artifact | PR/FAQ templates, session plan archives |

**Edge case:** A research issue that contains BOTH reference material AND a residual action ("still need to evaluate X") should be split: create a Document for the reference content, and a new verb-first issue for the residual action linking to the document.

## Type Label Taxonomy

Every issue MUST have exactly one `type:*` label. No exceptions.

| Label | Use For | Edge Cases |
|---|---|---|
| `type:feature` | New capability, UI component, API endpoint | Safety/compliance features count as features |
| `type:bug` | Defect fix | Performance regressions are bugs |
| `type:chore` | Maintenance, config, docs, infra, cleanup | Security config, dependency updates, CI/CD |
| `type:spike` | Time-boxed exploration, evaluation, prototyping | Competitive analysis, library evaluations, research spikes |

**Assignment heuristic:**
- Title starts with "Build/Implement/Add/Create/Ship" --> likely `type:feature`
- Title starts with "Fix/Resolve/Patch" --> likely `type:bug`
- Title starts with "Configure/Set up/Migrate/Update/Audit" --> likely `type:chore`
- Title starts with "Evaluate/Survey/Explore/Investigate/Compare" --> likely `type:spike`

## Deprecated Label Migration

Remove these labels on sight and replace with the correct equivalent:

| Deprecated Label | Replacement | Rationale |
|---|---|---|
| `research` (generic) | `research:needs-grounding` | Use the graded research progression hierarchy |
| `documentation` | Remove; convert issue to Document if non-actionable, or `type:chore` if actionable | Documentation is a content type, not a workflow label |
| `module:3-research` | Remove (no replacement) | Module labels replaced by project structure |
| `module:1-infra` | Remove (no replacement) | Module labels replaced by project structure |
| `exploratory` | `type:spike` | Exploratory work is a spike |

## Deletion Protocol

When removing issues (e.g., reclaiming free-tier slots or clearing non-actionable content):

1. **Read** the issue description fully -- check for substantive content
2. **Preserve** valuable content as a Linear Document with appropriate category prefix
3. **Create residual issue** if an actionable item exists beyond the reference content (verb-first title, link to document)
4. **Delete** the original issue via GraphQL `issueDelete` mutation (Linear MCP has no delete operation)
5. **Track** deletions: record original issue ID, new document title, and new issue ID (if created) in a session summary

## Execution Phases

Apply in strict sequence -- each phase depends on the previous:

1. **Audit** -- Read all issues, classify each as keep / rename / relabel / convert-to-doc / delete
2. **Delete** -- Remove non-actionable issues first (reclaims slots for new documents if on free tier)
3. **Convert** -- Create Documents from valuable non-actionable issues, then delete originals
4. **Rename** -- Fix bracket prefixes and non-verb-first titles
5. **Relabel** -- Add missing `type:*` labels, migrate deprecated labels
6. **Structure** -- Create missing structural documents (Key Resources, Decision Log, etc.)
7. **Verify** -- Full sweep confirming: every issue has `type:*` label, verb-first title, no deprecated labels, assigned to project

**Batching:** Process issues in batches of 10-15 per subagent. Split by operation type (delete batch, relabel batch), not by issue.

## Consolidation Protocol

Periodic backlog consolidation prevents issue sprawl. Run before each milestone boundary.

**Cadence:**
- Before milestone start: full backlog sweep
- Weekly during active milestone: quick dedup check on new issues
- Before project review: consolidation audit

**Process:**
1. Sort all open issues by title similarity
2. For each cluster of similar issues: pick the most complete spec as the survivor, merge acceptance criteria from others, cancel duplicates with link to survivor
3. Track net issue delta: `created - cancelled = net change`. Target: net-negative or net-zero per consolidation pass
4. Document consolidation results as a Linear comment on the milestone issue

> See [do-not-rules.md](do-not-rules.md) for the 10 hard-won anti-patterns from production cleanup sessions.
