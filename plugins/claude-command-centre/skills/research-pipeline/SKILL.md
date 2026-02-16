---
name: research-pipeline
description: |
  End-to-end academic research pipeline: discovery via Semantic Scholar, arXiv, and OpenAlex;
  supplementary resource discovery via HuggingFace, Kaggle, and CatalyzeX; storage and enrichment
  via Zotero; literature notes via Obsidian; synthesis via NotebookLM.
  Use when starting a literature review, finding papers on a topic, discovering code/datasets
  for a paper, creating literature notes, or understanding the research tool stack.
  Trigger with phrases like "find papers on", "literature review", "what research tools do we have",
  "discover datasets for", "find code implementations", "research pipeline", "supplementary resources".
---

# Research Pipeline

A 4-stage pipeline for academic research: discover, enrich, organize, synthesize. Each stage has specific tools and protocols.

## Pipeline Architecture

```
Stage 1: Discovery (S2 / arXiv / OpenAlex)
  ↓
Stage 1.5: Supplementary Resources (HuggingFace / Kaggle / CatalyzeX)
  ↓
Stage 2: Storage & Enrichment (Zotero + plugins)
  ↓
Stage 3: Literature Notes (Obsidian vault)
  ↓
Stage 4: Synthesis (NotebookLM — manual)
```

## Stage 1: Paper Discovery

### Tool Selection

| Tool | Strength | Use For |
|------|----------|---------|
| Semantic Scholar | 200M+ papers, citation graphs, recommendations | Focused paper search, citation analysis, author profiles |
| arXiv | Preprint search, PDF extraction, category filtering | CS/ML/physics papers, latest preprints |
| OpenAlex | 240M+ works, institutions, venues, OA links | Broad scholarly search, institutional analysis, trend analysis |

### Discovery Protocol

1. **Start with OpenAlex** for broad topic scoping (trend analysis, top-cited works)
2. **Narrow with Semantic Scholar** for focused searches (specific authors, citation chains)
3. **Check arXiv** for latest preprints and PDF access
4. **Cross-reference** using DOI or arXiv ID across all three sources

### Search Strategy

- Use quoted phrases for exact matches: `"multi-agent systems"`
- Combine with field-specific search: `ti:"transformer" AND abs:"attention"`
- Filter by date, citation count, and category
- For foundational work: use `date_to` parameter to find classic papers

## Stage 1.5: Supplementary Resource Discovery

After finding papers, discover linked code, datasets, and models:

### Automated (Claude via MCP)

| Source | MCP Tool | What It Finds |
|--------|----------|---------------|
| HuggingFace | `get_paper_info(arxiv_id)` | Linked models, datasets, spaces |
| HuggingFace | `search_datasets/models(query)` | Related resources by keyword |
| HF Daily Papers | `get_today_papers()` | Curated daily feed |
| Kaggle | `search_datasets(query)` | Competition datasets, notebooks |

### Semi-Automated (Claude in Chrome)

- **CatalyzeX + Scholar**: Navigate to `catalyzex.com/paper/{slug}/code`, extract `window.__NEXT_DATA__` for GitHub repos
- **HuggingFace collections**: WebFetch on HF API for collection items (MCP has slug bug)

### Manual (Cian via browser)

- CatalyzeX arXiv Labs overlay, DagsHub experiment repos, Google Scholar BibTeX export, HuggingFace web UI bookmarks

## Stage 2: Zotero Storage & Enrichment

**Detailed workflow:** See `zotero-workflow` skill.

Summary:
1. Browser Connector saves papers with metadata
2. Cita resolves DOIs (OpenAlex first, then S2)
3. Linter fills metadata (Blank Fields Only mode)
4. Zoplicate deduplicates
5. `zotero-metadata-sync.py` pushes to Supabase

## Stage 3: Obsidian Literature Notes

### Literature Note Frontmatter Schema

```yaml
---
type: literature-note
zotero-key: "ABC123"
doi: "10.1234/example"
authors: ["Smith, J.", "Doe, A."]
year: 2025
methods: ["qualitative", "thematic-analysis"]
relevance: ["limerence", "attachment-theory"]
status: unprocessed | processed | synthesized
tags: [literature, psychology]
---
```

### Creation Flow

**Tier 1 (Filesystem — works now):**
1. `zotero_get_item_metadata(item_key)` for metadata
2. Map Zotero fields to frontmatter schema
3. Write tool creates `~/Vaults/ObsidianVault/03-Knowledge/Literature/{title}.md`
4. Include frontmatter + abstract + empty sections for user annotation

**Tier 2 (Obsidian CLI — when available):**
- `obsidian create`, `obsidian search`, `obsidian backlinks`, `obsidian property:set`

### Path Convention

| Content | Path |
|---------|------|
| Literature notes | `03-Knowledge/Literature/` |
| Readwise highlights | `03-Knowledge/Readwise/` |
| Concept notes | `03-Knowledge/Concepts/` |

## Stage 4: NotebookLM Synthesis

- No API. Manual upload only.
- Sources: PDFs from Supabase + processed Obsidian notes
- ~50 document limit per notebook
- Best for: multi-source synthesis, audio overviews

## Integration Points

| Tool | MCP | Role |
|------|-----|------|
| Semantic Scholar | semanticscholar | Paper search, citations, recommendations |
| arXiv | arxiv | Paper search, PDF extraction |
| OpenAlex | openalex | Broad scholarly search, trends, institutions |
| HuggingFace | huggingface | Models, datasets, spaces, paper info |
| HF Daily Papers | huggingface-daily-papers | Curated daily feed |
| Kaggle | kaggle | Datasets, competitions, notebooks |
| Zotero | zotero + seerai-zotero | Metadata, citation data, library management |
| Obsidian | Filesystem / CLI | Knowledge management, literature notes |
| Firecrawl | firecrawl | Grey literature, web sources |
| NotebookLM | Manual | Multi-source synthesis |

## Rules

- **No new scripts.** Zotero has 3 scripts (ceiling). Obsidian uses CLI or Write tool.
- **No Obsidian MCP.** Community servers are fragile. CLI replaces them.
- **Frontmatter is contract.** The YAML schema is the interface between Zotero and Obsidian.
- **Pilot batch first.** 3-item minimum before any 10+ item operation.
- **MCP-first principle.** Use MCPs over scripts wherever possible.
