---
description: |
  Archive a Claude Code Insights report and extract actionable patterns.
  Use when you receive a new Insights report from Anthropic, want to review past insights, or want to check improvement trends.
  Trigger with phrases like "archive my insights", "process insights report", "what did my last insights say", "insights trend".
argument-hint: "[--archive <path> | --review | --trend | --suggest]"
platforms: [cli]
---

# Insights

Archive Claude Code Insights reports and extract actionable improvement patterns.

## Modes

- **`--archive <path>`** — Convert an HTML Insights report to structured Markdown and save to `~/.claude/insights/`.
- **`--review`** — Summarize the most recent archived report. Show key friction points, wins, and open suggestions.
- **`--trend`** — Compare all archived reports. Show how friction counts, satisfaction, and outcomes change over time.
- **`--suggest`** — Extract unapplied CLAUDE.md rules and skill candidates from the latest report.

If no mode is specified, default to `--review`.

## Step 1: Locate Reports

**For `--archive`:** Read the HTML file at the provided path. Validate it is a Claude Code Insights report (check for `<title>Claude Code Insights</title>` or the characteristic section IDs).

**For `--review`, `--trend`, `--suggest`:** Read all `.md` files in `~/.claude/insights/`. Parse frontmatter for period, messages, sessions metadata.

## Step 2: Archive (if `--archive`)

Convert the HTML report to structured Markdown following the `insights-pipeline` skill format.

1. Parse HTML to extract each section's content.
2. Convert charts/bar data to Markdown tables.
3. Preserve all metrics, suggestions, and code blocks verbatim.
4. Write to `~/.claude/insights/YYYY-MM-DD.md` where YYYY-MM-DD is the report period end date.
5. Verify the archive is complete by checking section count matches the original.

**Safety:** Do not overwrite an existing archive unless `--force` is also passed. Report a conflict and ask the user.

## Step 3: Review (if `--review`)

Read the most recent archive (by filename date sort). Present:

```
## Latest Insights — [Period]

**Sessions:** N | **Messages:** N | **Satisfaction:** N% likely satisfied

### Top 3 Friction Points
1. [Type] (N instances) — [one-line summary]
2. [Type] (N instances) — [one-line summary]
3. [Type] (N instances) — [one-line summary]

### Top 3 Wins
1. [Win title] — [one-line summary]
2. [Win title] — [one-line summary]
3. [Win title] — [one-line summary]

### Unapplied Suggestions
- [ ] [Suggestion from report not yet in CLAUDE.md]
- [ ] [Suggestion from report not yet in CLAUDE.md]
```

To check which suggestions are unapplied, read the current CLAUDE.md and compare against the report's suggestion list.

## Step 4: Trend (if `--trend`)

Read all archived reports. Build a comparison table:

```
## Insights Trend

| Report | Sessions | Messages | Wrong Approach | Buggy Code | Fully Achieved | Satisfaction |
|--------|----------|----------|----------------|------------|----------------|-------------|
| Feb 6-10 | 54 | 250 | 28 | 10 | 31 | 55 |
| [next] | ... | ... | ... | ... | ... | ... |
```

Highlight improvements and regressions. If wrong_approach count decreased, note what CLAUDE.md changes were made between reports.

## Step 5: Suggest (if `--suggest`)

Cross-reference the latest report's suggestions against current state:

1. Read CLAUDE.md. Check which suggested rules are already present.
2. Read `~/.claude/skills/`. Check which suggested skills already exist.
3. Read `~/.claude/settings.json` (or `.claude/settings.json`). Check which suggested hooks exist.

Output:

```
## Unapplied Suggestions

### CLAUDE.md Rules
- [ ] [Rule name] — [why, from report]
- [x] [Rule name] — already in CLAUDE.md ✓

### Skill Candidates
- [ ] [Skill name] — [what it would do]
- [x] [Skill name] — already exists ✓

### Hook Candidates
- [ ] [Hook name] — [trigger and action]
```

## What If

| Situation | Response |
|-----------|----------|
| **HTML file is not an Insights report** | Report the error. Suggest the user check the file path. |
| **No archived reports exist** | For `--review`/`--trend`/`--suggest`: report that no archives exist. Suggest running `--archive` first. |
| **Only one archived report** | For `--trend`: report that trends require 2+ reports. Show the single report's metrics as a baseline. |
| **Archive already exists for this date** | Do not overwrite. Report the conflict. User must pass `--force` to replace. |
