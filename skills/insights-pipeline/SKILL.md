---
name: insights-pipeline
description: Archive Claude Code Insights reports and extract actionable patterns for CLAUDE.md improvement.
---

# Insights Pipeline

Archive Claude Code Insights reports as structured Markdown and extract patterns to improve your CLAUDE.md and workflows.

## What This Skill Does

1. **Archives** HTML Insights reports to `~/.claude/insights/YYYY-MM-DD.md` as structured Markdown.
2. **Extracts** actionable patterns: friction points, CLAUDE.md suggestions, feature recommendations, workflow patterns.
3. **Compares** current report against prior archived reports to track improvement trends.
4. **Feeds forward** — surfaces patterns that should become CLAUDE.md rules, custom skills, or hooks.

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

### Trend Tracking
- Compare friction counts across archived reports. Are wrong_approach counts decreasing?
- Compare satisfaction scores. Is the ratio of fully-achieved outcomes improving?
- Track which CLAUDE.md suggestions were adopted and whether friction decreased.

## Prerequisites

- Claude Code Insights report (HTML format from Anthropic).
- Write access to `~/.claude/insights/`.

## Related

- `/sdd:insights` command — runs the archive-and-learn cycle.
- CLAUDE.md — destination for extracted rules.
- `~/.claude/skills/` — destination for extracted skill candidates.
