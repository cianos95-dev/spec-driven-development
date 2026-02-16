---
name: zotero-workflow
description: |
  Canonical Zotero library management workflow: plugin sequencing, metadata enrichment,
  Linter/Cita settings, safety rules, JS verification, and anti-patterns.
  Use when performing any Zotero operation, enriching metadata, resolving DOIs, deduplicating,
  syncing to Supabase, or diagnosing library health issues.
  Trigger with phrases like "enrich Zotero metadata", "resolve DOIs", "run Linter", "Zotero health check",
  "deduplicate library", "sync to Supabase", "Zotero plugin sequence".
---

# Zotero Workflow

> **Principle:** Plugins first, scripts only where plugins can't reach.

This is the single source of truth for all Zotero operations. Do NOT invent new approaches.

## Plugin Sequence (ORDER MATTERS)

```
Step 1: Cita "Get identifiers" (OpenAlex first, then S2)
  → Finds DOIs by title-matching against academic databases
  → Run on items missing DOI only

Step 2: Linter "Retrieve metadata via identifier and lint"
  → Takes existing DOIs and fetches full metadata from CrossRef
  → Fills journal, abstract, date, volume, issue, pages

Step 3: Zoplicate "Find duplicates"
  → Clean up duplicates introduced or exposed

Step 4: zotero-metadata-sync.py sync --all
  → Push updated metadata to Supabase
```

**NEVER reverse this order.** Cita finds DOIs, Linter uses DOIs. Running Linter first wastes API calls.

## Linter Settings (CRITICAL)

| Setting | Value | Why |
|---------|-------|-----|
| Update Mode | **Blank Fields Only** | Prevents overwriting existing good metadata |
| Allow Change Item Type | **OFF** | Prevents unwanted type conversions |
| Concurrency | 20 | Balance speed and rate limits |
| Sentence Case | ON | Standardizes titles |
| ISO 8601 Dates | ON | Standardizes date format |
| ISO4 Journal Abbreviations | ON | Standardizes journal names |

**WARNING:** "All Fields" mode + "Allow Change Item Type" ON will damage your library.

## Cita Settings

- **Primary source for DOI resolution:** OpenAlex (best psychology/social science coverage)
- **Secondary source:** Semantic Scholar (better CS/technical coverage)
- **Skip:** Wikidata (slow, rarely adds DOIs others miss)
- **No progress bar:** Cita doesn't show progress. Just wait.

## JS Console Verification

**ALWAYS verify before AND after any batch plugin operation.** Run in Tools > Developer > Run JavaScript.

Library health check:
```javascript
let items = await Zotero.Items.getAll(Zotero.Libraries.userLibraryID, true);
let stats = { total: 0, hasDOI: 0, hasAbstract: 0, hasDate: 0, hasJournal: 0 };
for (let item of items) {
  if (!item.isRegularItem() || item.deleted) continue;
  stats.total++;
  await item.loadAllData();
  if (item.getField('DOI')) stats.hasDOI++;
  if (item.getField('abstractNote')) stats.hasAbstract++;
  if (item.getField('date')) stats.hasDate++;
  try { if (item.getField('publicationTitle')) stats.hasJournal++; } catch(e) {}
}
return JSON.stringify(stats, null, 2);
```

## Active Scripts (3 total — ceiling)

| Script | Purpose | When to Run |
|--------|---------|-------------|
| `zotero-enrich-abstracts.py` | Fetch missing abstracts (S2 > OpenAlex > CrossRef) | After major imports |
| `zotero-metadata-sync.py` | Sync metadata to Supabase | After batch enrichment |
| `zotero-to-supabase.py` | Upload PDFs to Supabase storage | For NotebookLM access |

All other scripts archived. Do not resurrect.

## Anti-Patterns

| Anti-Pattern | Why It Failed | Do This Instead |
|-------------|---------------|-----------------|
| Custom Python scripts for metadata ops | Fragile, rate limits, duplicates plugin work | Linter + Cita plugins |
| Swarm/multi-agent Zotero operations | Context explosion, no rollback | Single-threaded plugin ops |
| Direct SQLite writes | Corrupts database | NEVER. Use API or plugins |
| Linter on entire library at once | Slow, no progress | Saved searches, ~500-item batches |
| 5+ plugins in one session | Z7 corrupted L10n. Z8 safer but risky | Max 2 plugin installs per session |
| "All Fields" Linter mode | Overwrites good metadata | **Blank Fields Only** |
| Custom classification scripts | Reinvents AI Collection | Use AI Collection plugin |
| Custom citation scripts | Reinvents Cita | Use Cita plugin |

## Safety Rules

- Max 2 plugin installs per session
- NEVER modify `intl.locale.requested` or `general.useragent.locale`
- Claude cannot execute JS in Zotero remotely — guide user through JS console
- Always verify with JS health check before AND after plugin operations
- Batch size limit: ~500 items per operation
- Pilot batch (3 items) before any 10+ item operation

## MCP Status

| MCP | Status | Tools |
|-----|--------|-------|
| zotero | Working (read-only, stdio) | Search, metadata, fulltext, annotations, collections, tags |
| seerai-zotero | Working (HTTP) | search_library, import_paper, related_papers, generate_tags, 8 more |

## Enrichment Source Assessment

| Source | Via | Strength | Use For |
|--------|-----|----------|---------|
| OpenAlex | Cita | Best social science | DOI resolution (primary) |
| Semantic Scholar | Cita, SeerAI | Best CS/technical | DOI resolution (secondary) |
| CrossRef | Linter | Most complete per DOI | Metadata fill |
| Unpaywall | DOI lookup only | OA status, PDF links | OA PDF finding |
