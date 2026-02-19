---
name: insights-pipeline
description: |
  Archive Claude Code Insights reports and extract actionable patterns for CLAUDE.md improvement.
  Uses a graduated 3-phase storage approach: flat Markdown (Phase 0), patterns.json (Phase 1),
  SQLite (Phase 2). Use when archiving an Insights HTML report, extracting patterns from Insights
  data, reviewing trends across multiple reports, or finding CLAUDE.md improvement candidates.
  Trigger with phrases like "archive insights report", "extract patterns from insights",
  "review insights trends", "what did insights suggest", "insights to CLAUDE.md",
  "process insights report".
---

# Insights Pipeline

Archive Claude Code Insights reports as structured Markdown and extract patterns to improve your CLAUDE.md and workflows.

## What This Skill Does

1. **Archives** HTML Insights reports to `~/.claude/insights/YYYY-MM-DD.md` as structured Markdown.
2. **Extracts** actionable patterns: friction points, CLAUDE.md suggestions, feature recommendations, workflow patterns.
3. **Compares** current report against prior archived reports to track improvement trends.
4. **Feeds forward** — surfaces patterns that should become CLAUDE.md rules, custom skills, or hooks.

## Graduated Storage (3 Phases)

The insights pipeline scales its data infrastructure with usage. Don't over-engineer early — start with flat files and graduate when the data warrants it.

### Phase 0: Flat Markdown (Now — reports 1-9)

**This is the current phase.** All insights are stored as individual Markdown files in `~/.claude/insights/`. Pattern matching is done by reading and comparing these files directly.

| Storage | Format | Location |
|---------|--------|----------|
| Archived reports | Markdown with frontmatter | `~/.claude/insights/YYYY-MM-DD.md` |
| Pattern tracking | Manual comparison across files | Agent reads archives on demand |
| Trend detection | Diff-based (compare current vs previous) | Inline during `/ccc:insights` run |

**Why this is enough**: With <10 reports, an agent can read all archives in a single context window. Pattern matching is straightforward string comparison. No index needed.

### Phase 1: patterns.json (At report 10)

When the 10th archived report is created, graduate to a lightweight JSON index for pattern tracking. This avoids re-reading all archives for every query.

| Storage | Format | Location |
|---------|--------|----------|
| Archived reports | Markdown with frontmatter (unchanged) | `~/.claude/insights/YYYY-MM-DD.md` |
| Pattern index | JSON file | `~/.claude/insights/patterns.json` |
| Trend snapshots | JSON array within patterns.json | Embedded in the index |

**patterns.json schema** (indicative — finalize when Phase 1 is needed):

```json
{
  "version": 1,
  "lastUpdated": "2026-03-15T10:00:00Z",
  "patterns": [
    {
      "id": "mcp-tool-confusion",
      "category": "friction",
      "description": "MCP tool name confusion (linear vs github)",
      "matchKey": "mcp__linear vs mcp__github",
      "firstSeen": "2026-02-01",
      "lastSeen": "2026-03-10",
      "frequency": 8,
      "status": "active",
      "resolvedBy": null
    }
  ],
  "trajectorySnapshots": [
    {
      "date": "2026-03-15",
      "frictionCount": 14,
      "outcomeRate": 0.85,
      "reportCount": 12
    }
  ]
}
```

**Trigger to graduate**: The `/ccc:insights` command checks `ls ~/.claude/insights/*.md | wc -l`. At 10+, it initializes `patterns.json` from existing archives.

**Why JSON, not SQLite**: JSON is readable, diffable, and requires no external tools. At 10-49 reports with ~50 patterns, a single JSON file is perfectly adequate.

### Phase 2: SQLite (At report 50+)

When pattern complexity exceeds what flat JSON handles well (50+ reports, cross-report correlations, compaction), graduate to SQLite. This phase is defined in the `pattern-aggregation` skill.

| Storage | Format | Location |
|---------|--------|----------|
| Archived reports | Markdown with frontmatter (unchanged) | `~/.claude/insights/YYYY-MM-DD.md` |
| Pattern index | SQLite database | `~/.claude/insights/index.db` |
| Compaction | Progressive aggregation (daily→weekly→monthly) | Managed by SQLite |

**What Phase 2 adds over Phase 1**:
- SQL queries for complex pattern analysis
- Correlation tables (rule adoption → friction reduction)
- Progressive compaction to control storage growth
- Preference drift detection with snapshot history

**Trigger to graduate**: The `/ccc:insights` command detects 50+ archived reports and offers to migrate `patterns.json` into SQLite.

See the `pattern-aggregation` skill for the full Phase 2 schema, compaction strategy, and correlation engine.

## Archive Format

Each archived report follows this structure:

```markdown
---
source: Claude Code Insights (Anthropic)
period: YYYY-MM-DD to YYYY-MM-DD
messages: N
sessions: N
archived: YYYY-MM-DD
original: [path to source file]
version: 1
---

# Claude Code Insights — [Period]

## At a Glance
## Project Areas
## Usage Stats
## Big Wins
## Friction Points
## CLAUDE.md Suggestions
## Features Recommended
## Patterns to Adopt
## On the Horizon
## Outcomes
## Satisfaction
```

## Storage

- **Default location:** `~/.claude/insights/`
- **Naming:** `YYYY-MM-DD.md` where the date is the end date of the report period.
- **Idempotent:** Re-running on the same report produces the same output. Existing archives are not overwritten unless `--force` is passed.

## Extraction Rules

When converting HTML reports to Markdown:

1. **Strip all CSS and JavaScript.** Extract text content only.
2. **Preserve data fidelity.** Every number, percentage, and metric from the original appears in the archive.
3. **Use tables for structured data.** Charts become tables. Bar charts become `| Label | Value |` tables.
4. **Keep code suggestions verbatim.** CLAUDE.md additions and prompt templates are preserved exactly.
5. **Summarize narratives.** Multi-paragraph prose sections become 2-3 sentence summaries. Link back to original for full text.

## Pattern Extraction

After archiving, extract these actionable outputs:

### CLAUDE.md Candidates
- Any suggestion from the report's "CLAUDE.md Additions" section.
- Any friction pattern that occurred 3+ times (indicates a missing rule).
- Any environment assumption error (indicates missing context in CLAUDE.md).

### Skill Candidates
- Any repeated multi-step workflow mentioned in "Features to Try" or "Patterns".
- Any workflow the user performs manually that could be automated.

### Trend Tracking (Phase 0)

With <10 reports, trends are tracked by direct comparison:

1. Read the most recent 2-3 archives
2. Compare friction point lists — are the same items recurring?
3. Check if previously suggested CLAUDE.md rules have been adopted
4. Report: friction count trend, outcome rate trend, new vs recurring friction

This is sufficient until Phase 1 provides structured tracking.

## Prerequisites

- Claude Code Insights report (HTML format from Anthropic).
- Write access to `~/.claude/insights/`.

## Related

- `/ccc:insights` command — runs the archive-and-learn cycle.
- `pattern-aggregation` skill — Phase 2 cross-session pattern matching, SQLite index, improvement trajectories, and rule effectiveness tracking.
- CLAUDE.md — destination for extracted rules.
- `~/.claude/skills/` — destination for extracted skill candidates.
- CIA-522 — Hook and infrastructure improvements roadmap.
