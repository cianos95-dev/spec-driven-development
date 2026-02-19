---
name: insights-pipeline
description: |
  Guide for archiving Claude Code Insights HTML reports as structured Markdown and
  extracting actionable patterns to improve CLAUDE.md and workflows.
  Use when archiving an Insights report, reviewing past archives, extracting CLAUDE.md
  improvement candidates, or comparing trends across reports.
  Trigger with phrases like "archive insights report", "review insights", "insights trend",
  "what did insights suggest", "insights to CLAUDE.md".
---

# Insights Pipeline

Archive Claude Code Insights reports as structured Markdown and extract patterns to improve your CLAUDE.md and workflows.

This is a methodology skill — it guides the agent through archiving and analysis using standard file tools (Read, Write, Edit, Grep, Glob). There is no runtime or database involved.

## What This Skill Does

1. **Archives** HTML Insights reports to `~/.claude/insights/YYYY-MM-DD.md` as structured Markdown.
2. **Extracts** actionable patterns: friction points, CLAUDE.md suggestions, feature recommendations, workflow patterns.
3. **Compares** current report against prior archived reports to identify improvement trends.

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

- **Location:** `~/.claude/insights/`
- **Naming:** `YYYY-MM-DD.md` where the date is the end date of the report period.
- **Idempotent:** Re-running on the same report produces the same output. Do not overwrite an existing archive unless the user explicitly requests it.

## Extraction Rules

When converting HTML reports to Markdown:

1. **Strip all CSS and JavaScript.** Extract text content only.
2. **Preserve data fidelity.** Every number, percentage, and metric from the original appears in the archive.
3. **Use tables for structured data.** Charts become tables. Bar charts become `| Label | Value |` tables.
4. **Keep code suggestions verbatim.** CLAUDE.md additions and prompt templates are preserved exactly.
5. **Summarize narratives.** Multi-paragraph prose sections become 2-3 sentence summaries.

## Pattern Extraction

After archiving, extract these actionable outputs:

### CLAUDE.md Candidates

- Any suggestion from the report's "CLAUDE.md Suggestions" section.
- Any friction pattern that occurred 3+ times (indicates a missing rule).
- Any environment assumption error (indicates missing context in CLAUDE.md).

### Skill Candidates

- Any repeated multi-step workflow mentioned in "Features Recommended" or "Patterns to Adopt".
- Any workflow the user performs manually that could be codified as a skill.

### Trend Comparison

When multiple archived reports exist in `~/.claude/insights/`, compare them using `patterns.json` (produced by the `pattern-aggregation` skill):

- Are wrong-approach friction counts decreasing? (Check `trend` field in `patterns.json`)
- Is the ratio of fully-achieved outcomes improving?
- Which CLAUDE.md suggestions were adopted and did friction decrease afterward?

For structured cross-session trend analysis, run `aggregate-patterns.sh` (from the `pattern-aggregation` skill) to rebuild `~/.claude/insights/patterns.json` from all archived reports. This provides normalized friction types, per-report counts, and trend calculations. For quick single-report comparisons, reading the archived Markdown files directly is sufficient.

## Prerequisites

- Claude Code Insights report (HTML format from Anthropic).
- Write access to `~/.claude/insights/`.

## Related

- `/ccc:insights` command — runs the archive-and-learn cycle with `--archive`, `--review`, `--trend`, and `--suggest` modes.
- CLAUDE.md — destination for extracted rules.
- `pattern-aggregation` skill — cross-session friction pattern aggregation, produces `patterns.json` from archived reports.
