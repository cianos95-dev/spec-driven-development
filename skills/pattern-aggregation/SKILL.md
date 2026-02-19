---
name: pattern-aggregation
description: |
  Cross-session friction pattern aggregation for the CCC Insights Platform.
  Parses archived insights reports, normalizes friction types, calculates trends,
  and produces a structured patterns.json for downstream consumers.
  Graduated approach: Phase 0 (flat archives), Phase 1 (patterns.json), Phase 2 (SQLite).
  Use when analyzing cross-session friction trends, running pattern aggregation,
  checking which friction types recur, or preparing data for the adaptive-methodology skill.
  Trigger with phrases like "aggregate patterns", "cross-session patterns", "friction trends",
  "pattern aggregation", "run pattern aggregation", "what keeps going wrong",
  "recurring friction", "pattern trends", "insights patterns".
---

# Pattern Aggregation

Cross-session friction pattern aggregation for the CCC Insights Platform. This skill is the data layer (Pillar 1) of the Insights Platform (CIA-303). It parses archived insights reports, normalizes friction types, calculates trends, and produces a structured `patterns.json` that downstream skills consume.

**Linear:** [CIA-436](https://linear.app/claudian/issue/CIA-436)
**Spec revision:** Rev 2.1 (Gate 2 passed, 2 rounds of adversarial review, all findings incorporated)

## Graduated Implementation

### Phase 0 — Current State (baseline)

- Flat markdown archives in `~/.claude/insights/archives/`
- Period-over-period deltas computed by reading current + previous report
- No aggregation beyond manual comparison
- This is what existed before this skill was implemented

### Phase 1 — patterns.json (current implementation)

- `aggregate-patterns.sh` performs idempotent full rebuild from all archived reports
- Produces `~/.claude/insights/patterns.json` with structured pattern data
- Trend calculation, normalization, and triage auto-creation
- Appropriate for up to ~50 reports (~1 year of data)

### Phase 2 — SQLite migration (future, report 50+)

- Migrate to SQLite when JSON becomes unwieldy
- Full spec preserved in `SKILL-phase2-draft.md` in this directory
- Schema versioning, compaction, cross-report correlation
- Not current implementation scope

## Script

`aggregate-patterns.sh` in this directory. Bash 3.2 compatible (macOS default). Requires `jq`.

### Usage

```bash
# Full rebuild from archives
bash skills/pattern-aggregation/aggregate-patterns.sh

# Output written to ~/.claude/insights/patterns.json
```

### Run Semantics

Each run is a **full idempotent rebuild**. `patterns.json` is regenerated from scratch by reading all archived reports. This is O(n) in archive count but n < 50 for the entire Phase 1 lifetime, so performance is irrelevant.

**Exception:** The `linear_issue_id` and `triaged_at` fields are preserved across rebuilds via the merge algorithm (see below).

## Parsing Contract

The script extracts friction types from archived reports with varying markdown structures.

### Report Date Extraction

Report date is extracted from the archive filename (`YYYY-MM-DD.md`). This corresponds to the report period end date per the `insights-pipeline` naming convention. Reports are sorted by filename — ISO date format ensures lexicographic order = chronological order.

### Heading Detection

Search for section heading matching regex:

```
/^##\s+(Friction Points|Primary Friction Types)/i
```

### Table Extraction

After the heading, find the next markdown table. Extract rows with minimum required columns:

- Column 1: `Type` (friction category name)
- Column 2: `Count` (integer)
- Column 3: `Pattern` (optional — description, may be absent)

### Normalization

All friction type names are normalized before matching:

1. Trim whitespace
2. Convert to lowercase
3. Replace spaces with underscores

### display_name Derivation

`display_name` is set from the first occurrence of the type across all reports (chronologically), converted to Title Case. Example: if Report 1 has `Wrong approach`, `display_name` becomes `Wrong Approach`. Subsequent reports do not override this — the first-seen form is canonical.

### Canonical Taxonomy

| Raw (from reports) | Canonical key |
|---|---|
| `Wrong approach` / `Wrong Approach` | `wrong_approach` |
| `Buggy code` / `Buggy Code` | `buggy_code` |
| `Misunderstood request` / `Misunderstood Request` | `misunderstood_request` |
| `Excessive changes` / `Excessive Changes` | `excessive_changes` |
| `Tool limitation` / `Tool Limitation` | `tool_limitation` |
| `Tool error` / `Tool Error` | `tool_error` |

New types not in the canonical taxonomy are added automatically using the normalization rule. The taxonomy grows organically — no manual registration required.

### Error Handling

If a report has no matching heading or no valid table after the heading, skip that report with a warning logged to stderr. Never crash on malformed input.

## patterns.json Schema (Phase 1)

```json
{
  "schema_version": 1,
  "generated_at": "2026-02-18T12:00:00Z",
  "report_count": 2,
  "patterns": [
    {
      "type": "wrong_approach",
      "display_name": "Wrong Approach",
      "count": 68,
      "first_seen": "2026-02-10",
      "last_seen": "2026-02-18",
      "per_report": [28, 40],
      "trend": "increasing"
    }
  ]
}
```

### Field Definitions

- `schema_version`: Integer. Always `1` for Phase 1. Enables Phase 2 migration detection.
- `generated_at`: ISO 8601 timestamp of generation.
- `report_count`: Number of archived reports processed.
- `type`: Canonical normalized key (lowercase, underscored).
- `display_name`: Human-readable form (Title Case, from first occurrence).
- `count`: Absolute total across all reports. Note: absolute counts can be misleading when session volumes differ between periods. CIA-437 consumers should compute per-session rates using report metadata if available.
- `first_seen` / `last_seen`: ISO date extracted from archive filename of earliest/latest report containing this type.
- `per_report`: Array of counts per report, chronological order (sorted by filename). Enables trend and rate calculation without needing raw reports.
- `trend`: One of `"increasing"`, `"decreasing"`, `"stable"`, `"new"`.

### Trend Calculation

- `"new"`: Type appears in only 1 report.
- `"increasing"`: Last report count > first report count (for 2 reports) or linear slope > 0 (for 3+ reports).
- `"decreasing"`: Last report count < first report count (for 2 reports) or linear slope < 0 (for 3+ reports).
- `"stable"`: For 2 reports: counts are identical. For 3+ reports: linear slope within +/-10% of mean count.

## linear_issue_id Merge Algorithm

Before rebuild, read existing `patterns.json` (if it exists) and extract a map of `type` to `{linear_issue_id, triaged_at}`. After rebuild, for each pattern in the new output, if the type exists in the map, restore its `linear_issue_id` and `triaged_at`. Patterns no longer present in the rebuild are discarded along with their tracking data. On first run (no existing `patterns.json`), skip the merge step.

## Triage Auto-Creation

When a pattern's `count` reaches >= 3 AND no existing Linear issue tracks it:

### Deduplication

Before creating an issue, check `patterns.json` for a `linear_issue_id` field on the pattern. If set, do not create a duplicate.

### Issue Template

- **Project:** Claude Command Centre (CCC)
- **Labels:** `type:chore`
- **Status:** Triage
- **Title:** `Investigate recurring friction: {display_name} ({count} occurrences)`
- **Description:** Auto-generated summary with count, first/last seen, trend direction.

### Guards

- Maximum 3 auto-created issues per run. If more are eligible, log a warning and create only the top 3 by count.
- After creation, write `linear_issue_id` back to `patterns.json` for that pattern (this is the one mutation — the rebuild preserves this field per merge algorithm above).

### Schema Extension for Triage Tracking

```json
{
  "type": "wrong_approach",
  "linear_issue_id": "CIA-XXX",
  "triaged_at": "2026-02-18T12:00:00Z"
}
```

## Interface Contract to CIA-437

[CIA-437](https://linear.app/claudian/issue/CIA-437) (adaptive-methodology skill) depends on `patterns.json` for input.

### Phase 1 Provides

`type`, `display_name`, `count`, `first_seen`, `last_seen`, `per_report`, `trend` for each pattern, plus top-level `schema_version`, `report_count`, `generated_at`.

### CIA-437 Must Not Depend On

Fields beyond this schema. No SQLite queries, no raw report parsing, no correlation data. If CIA-437 needs richer data, that is a Phase 2 upgrade signal.

### Stability Guarantee

The Phase 1 schema is append-only. New fields may be added but existing fields will not be removed or renamed until Phase 2 migration.

## Prerequisites

- Archived insights reports in `~/.claude/insights/archives/` (created by `insights-pipeline` skill)
- `jq` available on the system (standard on macOS via Homebrew, available on most Linux distributions)
- `bash` 3.2+ (macOS default)
- Write access to `~/.claude/insights/`

## Cross-Skill References

- **insights-pipeline** — Produces the archived reports that feed pattern aggregation. Archive naming convention (`YYYY-MM-DD.md`) is the contract for report date extraction.
- **quality-scoring** — Pattern trend data can supplement quality evidence for issue closure decisions.
- **observability-patterns** — Layer 3 (Adaptive Methodology) consumes pattern data to decide whether methodology parameters should adjust.
- **execution-modes** — Friction pattern trends may inform execution mode selection recommendations.
- **issue-lifecycle** — Triage auto-creation follows issue lifecycle conventions for status and labels.
