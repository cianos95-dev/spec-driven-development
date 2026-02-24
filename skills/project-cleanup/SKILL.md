---
name: project-cleanup
description: |
  One-time project normalization: reclassify issues vs documents, enforce naming conventions,
  migrate deprecated labels, delete non-actionable items, and create structural project documents.
  Use when onboarding a new project to CCC conventions, after importing issues from another tracker,
  or when a project has accumulated convention debt (wrong issue types, bracket prefixes, missing type labels).
  Trigger with phrases like "clean up this project", "normalize project issues", "apply CCC conventions",
  "convert research notes to documents", "fix bracket prefixes", "project cleanup".
compatibility:
  surfaces: [code, cowork, desktop]
  tier: universal
---

# Project Cleanup

One-time structural normalization of a project's issues, documents, and metadata. This is distinct from ongoing hygiene (`/ccc:hygiene`) which audits health, and issue-lifecycle which governs day-to-day ownership. Cleanup handles destructive and structural changes that hygiene explicitly avoids.

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

## Naming Convention

### Issues: Verb-First, No Brackets

Every issue title must start with an action verb, lowercase after first word. No bracket prefixes.

| Pattern | Correct | Incorrect |
|---|---|---|
| Feature | `Build avatar selection UI component` | `[Feature] Avatar Selection UI` |
| Research | `Survey limerence measurement instruments` | `[Research] Limerence Instruments` |
| Safety | `Design anti-sycophancy monitoring` | `[Safety] Anti-sycophancy monitoring` |
| Infrastructure | `Configure Supabase pgvector` | `[Infrastructure] Supabase pgvector` |
| Compliance | `Implement crisis referral protocol` | `[Compliance] Crisis Referral Protocol` |

**Common verb starters:** Build, Implement, Fix, Add, Create, Evaluate, Survey, Design, Migrate, Configure, Audit, Ship, Set up, Wire up

### Documents: Category Prefix

- `Research: Topic Name`
- `Decision: Choice Description`
- `Literature: Paper or Topic`
- `Session: Date or Theme`
- `Template: Template Name`

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

```bash
# GraphQL deletion (Linear MCP does not support delete)
cd ~/.claude/skills/linear && LINEAR_API_KEY="$KEY" npx tsx scripts/query.ts \
  'mutation { issueDelete(id: "ISSUE_UUID") { success } }'
```

## Structural Documents Checklist

After cleanup, every project should have the structural documents defined in the **document-lifecycle** skill's taxonomy. See [`document-lifecycle/references/document-types.md`](../document-lifecycle/references/document-types.md) for the canonical type definitions, required vs optional classification, naming patterns, and staleness thresholds.

**Quick reference (from document-types.md):**
- **Required:** Key Resources, Decision Log (all projects)
- **Required (conditional):** Research Library Index (projects with `<!-- research-heavy -->`)
- **Optional:** Project Update, ADR, Living Document

Not every project needs all document types. Use `/ccc:hygiene --fix` to create missing structural documents, or `/ccc:hygiene --dry-run` to preview what would be created. Projects can opt out via `<!-- no-auto-docs -->` in their description.

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

> See [references/do-not-rules.md](references/do-not-rules.md) for the 10 hard-won anti-patterns from production cleanup sessions covering label replacement, archival counts, batch limits, verification sweeps, and more.

## Triage Decision Tree

For each issue being triaged, apply these steps IN ORDER. Stop at the first step that matches.

1. **CANCEL** -- Is this issue superseded, irrelevant, or duplicated by another? Cancel it with a comment linking to the superseding issue.
2. **MERGE** -- Is this issue's scope absorbed into another active issue? Cancel this one, add its acceptance criteria to the absorbing issue's description.
3. **MOVE** -- Is this issue in the wrong project? Move it to the correct project per the project assignment rules in CLAUDE.md.
4. **RECLASSIFY** -- Does this issue have the wrong type/tier/labels? Fix metadata: type label, tier classification, exec mode, spec status.
5. **UPDATE** -- Does this issue's spec need updating for current architecture? Mark for spec refresh (keep `arch:pre-pivot` or add `spec:draft`). Do NOT rewrite the spec now.
6. **OK** -- Issue is correctly categorized, scoped, and spec is current. No action needed, remove any triage labels.

**Anti-pattern:** Trying to update specs during triage. Triage is CLASSIFICATION only. Spec updates happen during cycle planning, not during batch triage sessions. Mixing classification and authoring causes context bloat and inconsistent depth across issues.

### T4 Promotion Test

When a T4 (Non-agent) issue seems like it might benefit from agent features, apply these three questions before changing its tier:

1. "Would agent integration fundamentally change how users interact with this feature?" -- If yes, promote to T2.
2. "Does this feature need real-time agent coordination?" -- If yes, promote to T1.
3. "Could a simple tool call or API wrapper add agent convenience?" -- If yes, promote to T3.

If all three answers are No, keep as T4. Document the promotion decision (or the decision to keep T4) in a comment on the issue so future triage sessions don't re-evaluate the same question.

## Estimation Framework

| Points | T-shirt | Complexity | Typical exec mode |
|--------|---------|------------|-------------------|
| 1 | XS | Single file, obvious change | `exec:quick` |
| 2 | S | 2-3 files, clear scope | `exec:quick` or `exec:tdd` |
| 3 | M | Multiple files, some uncertainty | `exec:tdd` |
| 5 | L | Cross-cutting, needs design | `exec:pair` or `exec:checkpoint` |
| 8 | XL | Architectural, multi-session | `exec:checkpoint` or `exec:swarm` |

**Rules:**
- Estimates drive exec mode selection, not the reverse. Assign the estimate first, then pick the exec mode that matches.
- If estimate > 5, consider splitting into sub-issues before scheduling.
- Claude OWNS estimates (complexity assessment leads to exec mode routing). Human OWNS priority and due dates.
- Re-estimate at `spec:ready` if scope has changed since `spec:draft`. Do not carry stale estimates into implementation.

### Consolidation Protocol

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

**Anti-pattern:** Creating new issues without first searching for existing ones that cover the same scope.

## Cross-Skill References

- **issue-lifecycle** -- Ongoing ownership rules vs this skill's one-time normalization
- **spec-workflow** -- Content Classification Matrix determines what enters the funnel as an issue vs a document
- **context-management** -- Batch size limits for cleanup subagents follow the delegation model
