---
name: pattern-aggregation
description: |
  Cross-session pattern matching and improvement trajectory tracking for the CCC Insights Platform.
  Identifies recurring friction, tracks improvement trajectories, detects preference drift, and
  correlates CLAUDE.md rule adoption with friction reduction across archived insights reports.
  Use when analyzing cross-session trends, checking improvement trajectory, investigating recurring
  friction, detecting preference drift, correlating rule adoption with outcomes, or querying the
  pattern index.
  Trigger with phrases like "cross-session patterns", "improvement trajectory", "am I getting better",
  "recurring friction", "preference drift", "pattern trends", "what keeps going wrong",
  "friction correlation", "rule effectiveness", "insights trajectory", "pattern aggregation",
  "aggregation window", "compaction strategy".
---

# Pattern Aggregation

Cross-session pattern matching to identify recurring friction, track improvement trajectories, and detect preference drift across archived insights reports. This skill is the data layer (Pillar 1) of the CCC Insights Platform (CIA-303). All other pillars depend on the structured data this skill produces.

## What This Skill Does

1. **Matches patterns** across archived insights reports in `~/.claude/insights/archives/` to identify recurring friction, improving areas, and regressions.
2. **Maintains a local index** (SQLite) for efficient querying of historical pattern data without re-parsing archives.
3. **Computes improvement trajectories** using a composite formula that answers "am I getting better?"
4. **Detects preference drift** by monitoring `.ccc-preferences.yaml` changes over time and distinguishing intentional refinement from indecision.
5. **Correlates rule adoption** with friction changes to measure whether CLAUDE.md additions actually help.

## Cross-Session Pattern Matching

### Data Source

Archived insights reports live in `~/.claude/insights/archives/`. Each report follows the format defined in the `insights-pipeline` skill: structured Markdown with frontmatter metadata, friction points, CLAUDE.md suggestions, outcomes, and satisfaction scores.

Pattern matching operates across these archives. A single report is a snapshot; pattern aggregation turns snapshots into trends.

### Pattern Categories

| Category | Description | Detection Signal |
|----------|-------------|-----------------|
| **Friction** | Recurring blockers that appear across multiple reports | Same friction description or same file path/tool appears in 3+ reports |
| **Improvement** | Things that are measurably getting better | Friction frequency decreasing, outcome rates increasing, satisfaction scores rising |
| **Regression** | Things that are measurably getting worse | Friction frequency increasing after a period of stability or improvement |

### Matching Algorithm

Pattern matching uses a two-pass approach:

**Pass 1 -- Exact matching:**
- File paths: identical paths appearing in friction points across reports
- Tool names: identical MCP tool or CLI tool names in friction contexts
- Error signatures: identical error messages or error categories

**Pass 2 -- Semantic similarity:**
- Friction descriptions: fuzzy match on friction text (Levenshtein distance < 0.3 on normalized descriptions)
- Workflow patterns: similar multi-step sequences appearing across reports
- Context patterns: similar context exhaustion scenarios (same project, similar task type)

Exact matches are always preferred. Semantic matches are flagged with lower confidence and require at least 3 occurrences before being promoted to a confirmed pattern.

### Confidence Scoring

Each pattern receives a confidence score calculated as:

```
confidence = frequency_weight(0.4) * recency_weight(0.3) * impact_weight(0.3)
```

| Component | How It's Calculated | Range |
|-----------|-------------------|-------|
| **Frequency** | `min(occurrence_count / 10, 1.0)` -- saturates at 10 occurrences | 0.0 - 1.0 |
| **Recency** | `1.0 - (days_since_last_occurrence / 90)` -- decays over 90 days, floor at 0.0 | 0.0 - 1.0 |
| **Impact** | Derived from friction severity in the source report: high=1.0, medium=0.6, low=0.3 | 0.0 - 1.0 |

Patterns with confidence below 0.2 are pruned during compaction. Patterns with confidence above 0.7 are flagged as "high-confidence" in reports.

## Aggregation Windows

Pattern data is stored at progressively coarser granularity to control storage while preserving trend visibility.

| Window | Granularity | Retention | Trigger |
|--------|-------------|-----------|---------|
| **Daily** | Full detail -- every friction point, every metric, every raw observation | 30 days | Each `/ccc:insights` run |
| **Weekly** | Summary -- aggregated counts, averaged metrics, top-N patterns per category | 30-90 days | Compaction job at 30-day mark |
| **Monthly** | Trends only -- directional indicators, trajectory scores, pattern lifecycle events | Indefinite | Compaction job at 90-day mark |

### Compaction Strategy

Progressive aggregation preserves trends while controlling storage growth:

**Daily to Weekly (at 30 days):**
1. Group daily records by ISO week
2. Sum friction counts per pattern, average metric values
3. Retain only top 10 patterns per category per week (by confidence score)
4. Delete daily records older than 30 days from the index
5. Preserve the weekly summary record

**Weekly to Monthly (at 90 days):**
1. Group weekly records by calendar month
2. Compute trend direction per pattern: improving, stable, or declining
3. Retain only pattern lifecycle events (first seen, resolved, regressed) and trajectory scores
4. Delete weekly records older than 90 days from the index
5. Preserve the monthly trend record

**Storage budget:** With 50 max active patterns and the compaction schedule above, the index stays under 5MB indefinitely. If the index exceeds 10MB, emit a warning suggesting manual review.

## Local Index

### Database Location

SQLite database at `~/.claude/insights/index.db`. Created on first run. The database is local-only and gitignored -- it can always be rebuilt from archived reports.

### Schema

#### `patterns` Table

```sql
CREATE TABLE patterns (
    id              TEXT PRIMARY KEY,           -- UUID v4
    category        TEXT NOT NULL,              -- 'friction' | 'improvement' | 'regression'
    description     TEXT NOT NULL,              -- Human-readable pattern description
    match_type      TEXT NOT NULL,              -- 'exact_path' | 'exact_tool' | 'exact_error' | 'semantic'
    match_key       TEXT,                       -- The exact string being matched (path, tool name, error sig)
    first_seen      TEXT NOT NULL,              -- ISO 8601 datetime
    last_seen       TEXT NOT NULL,              -- ISO 8601 datetime
    frequency       INTEGER NOT NULL DEFAULT 1, -- Total occurrence count
    impact_score    REAL NOT NULL DEFAULT 0.5,  -- 0.0 to 1.0
    confidence      REAL NOT NULL DEFAULT 0.0,  -- Computed: frequency * recency * impact
    resolution_status TEXT DEFAULT 'active',    -- 'active' | 'resolved' | 'regressed' | 'pruned'
    resolved_by     TEXT,                       -- Reference to the rule/change that resolved it
    schema_version  INTEGER NOT NULL DEFAULT 1, -- For future migrations
    created_at      TEXT NOT NULL,              -- ISO 8601 datetime
    updated_at      TEXT NOT NULL               -- ISO 8601 datetime
);

CREATE INDEX idx_patterns_category ON patterns(category);
CREATE INDEX idx_patterns_status ON patterns(resolution_status);
CREATE INDEX idx_patterns_last_seen ON patterns(last_seen);
```

#### `correlations` Table

```sql
CREATE TABLE correlations (
    id                TEXT PRIMARY KEY,          -- UUID v4
    pattern_id        TEXT NOT NULL,             -- FK to patterns.id
    rule_id           TEXT NOT NULL,             -- Identifier for the CLAUDE.md rule or config change
    correlation_type  TEXT NOT NULL,             -- 'rule_adopted' | 'rule_removed' | 'config_changed' | 'skill_added'
    evidence          TEXT NOT NULL,             -- JSON blob: {before_frequency, after_frequency, delta_pct, window_days}
    strength          REAL DEFAULT 0.0,          -- Correlation strength: -1.0 (inverse) to 1.0 (strong positive)
    schema_version    INTEGER NOT NULL DEFAULT 1,
    created_at        TEXT NOT NULL,             -- ISO 8601 datetime
    FOREIGN KEY (pattern_id) REFERENCES patterns(id) ON DELETE CASCADE
);

CREATE INDEX idx_correlations_pattern ON correlations(pattern_id);
CREATE INDEX idx_correlations_type ON correlations(correlation_type);
```

#### `trajectories` Table

```sql
CREATE TABLE trajectories (
    id              TEXT PRIMARY KEY,           -- UUID v4
    metric_name     TEXT NOT NULL,              -- 'friction_trend' | 'outcome_rate' | 'context_efficiency' | 'preference_stability' | 'composite'
    value           REAL NOT NULL,              -- Normalized 0-100
    components      TEXT,                       -- JSON blob of sub-metric values (for composite only)
    window_start    TEXT NOT NULL,              -- ISO 8601 date (start of measurement window)
    window_end      TEXT NOT NULL,              -- ISO 8601 date (end of measurement window)
    window_type     TEXT NOT NULL DEFAULT 'daily', -- 'daily' | 'weekly' | 'monthly'
    schema_version  INTEGER NOT NULL DEFAULT 1,
    created_at      TEXT NOT NULL               -- ISO 8601 datetime
);

CREATE INDEX idx_trajectories_metric ON trajectories(metric_name);
CREATE INDEX idx_trajectories_window ON trajectories(window_start, window_end);
CREATE INDEX idx_trajectories_type ON trajectories(window_type);
```

#### `preference_snapshots` Table

```sql
CREATE TABLE preference_snapshots (
    id              TEXT PRIMARY KEY,           -- UUID v4
    snapshot_hash   TEXT NOT NULL,              -- SHA-256 of the preferences file content
    content         TEXT NOT NULL,              -- Full YAML content at time of snapshot
    diff_summary    TEXT,                       -- Human-readable summary of changes from prior snapshot
    captured_at     TEXT NOT NULL,              -- ISO 8601 datetime
    schema_version  INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX idx_snapshots_hash ON preference_snapshots(snapshot_hash);
CREATE INDEX idx_snapshots_captured ON preference_snapshots(captured_at);
```

### Cardinality Limits

To prevent unbounded growth (addresses adversarial review M3):

| Entity | Hard Limit | Enforcement |
|--------|-----------|-------------|
| Active patterns | 50 | When inserting pattern #51, prune the lowest-confidence active pattern |
| Correlations per report | 500 | Truncate to top 500 by strength after each report processing |
| Trajectory records | No hard limit | Controlled by compaction schedule (daily purged at 30d, weekly at 90d) |
| Preference snapshots | 365 | One per day max; oldest pruned beyond 1 year |

### Schema Versioning

Every table includes a `schema_version` integer field (currently `1`). When the schema needs to change:

1. Increment the version number in the new code
2. Add a migration function that checks `SELECT MAX(schema_version) FROM <table>` on startup
3. Run `ALTER TABLE` statements to evolve the schema non-destructively
4. Never delete columns -- only add new ones or change defaults
5. Document migrations in a `migrations/` directory alongside this skill

**Migration template:**

```python
def migrate_v1_to_v2(db):
    """Example migration: add a 'tags' column to patterns."""
    current = db.execute("SELECT MAX(schema_version) FROM patterns").fetchone()[0]
    if current < 2:
        db.execute("ALTER TABLE patterns ADD COLUMN tags TEXT DEFAULT '[]'")
        db.execute("UPDATE patterns SET schema_version = 2")
        db.commit()
```

The rebuild-from-archives guarantee means schema migrations that fail can fall back to dropping the database and rebuilding from source reports.

## Improvement Trajectory

The improvement trajectory answers the question: "Am I getting better at using Claude Code?"

### Composite Formula

```
trajectory = friction_trend(0.4) + outcome_rate(0.3) + context_efficiency(0.2) + preference_stability(0.1)
```

Each component is independently normalized to a 0-100 scale before weighting. The composite score is also 0-100.

### Component Definitions

#### Friction Trend (weight: 0.4)

Measures reduction in recurring friction frequency over a 30-day rolling window.

```
friction_trend = 100 * (1 - (current_30d_friction_count / baseline_friction_count))
```

- **Baseline:** Average friction count from the first 30-day window on record (or the earliest available data).
- **Current:** Friction count in the most recent 30-day window.
- **Floor:** 0 (friction increased or matched baseline). **Ceiling:** 100 (zero friction).
- **No data:** Defaults to 50 (neutral).

#### Outcome Rate (weight: 0.3)

Percentage of sessions where all acceptance criteria were fully achieved.

```
outcome_rate = 100 * (fully_achieved_sessions / total_sessions) over 30-day window
```

- Source: "Outcomes" section of archived insights reports.
- **Fully achieved** means every acceptance criterion marked complete. Partially achieved counts as 0.
- **No data:** Defaults to 50.

#### Context Efficiency (weight: 0.2)

Average context budget remaining at session end, as a percentage.

```
context_efficiency = 100 * average(remaining_context_pct) over 30-day window
```

- Source: Session metadata in insights reports (context usage statistics).
- Higher is better -- ending sessions with 40% context remaining is more efficient than ending at 5%.
- **No data:** Defaults to 50.

#### Preference Stability (weight: 0.1)

Inverse of preference change frequency. Stable preferences indicate the user has found their workflow.

```
preference_stability = 100 * (1 - min(change_count / 10, 1.0)) over 30-day window
```

- **change_count:** Number of `.ccc-preferences.yaml` modifications in the 30-day window (from preference snapshots).
- Saturates at 10 changes (stability = 0 if 10+ changes in 30 days).
- **No data:** Defaults to 75 (assume stable if no preferences file exists).

### Trajectory Direction

| Score | Direction | Interpretation |
|-------|-----------|---------------|
| > 60 | Improving | Workflow is getting measurably better. Stay the course. |
| 40-60 | Stable | No significant change. Look for optimization opportunities. |
| < 40 | Declining | Something is getting worse. Investigate friction trends and recent changes. |

### Trajectory Output Format

```markdown
## Improvement Trajectory — 2026-02-16

| Component | Score | Trend | Detail |
|-----------|-------|-------|--------|
| Friction Trend (40%) | 72 | ↑ | 14 friction points (30d avg: 22) |
| Outcome Rate (30%) | 85 | → | 17/20 sessions fully achieved |
| Context Efficiency (20%) | 61 | ↑ | 38% avg remaining (was 29%) |
| Preference Stability (10%) | 90 | → | 1 change in 30 days |

**Composite: 75 — Improving**

### Top Friction Patterns (active)
1. MCP tool name confusion (linear vs github) — 8 occurrences, last seen 2d ago
2. Context exhaustion in multi-file refactors — 5 occurrences, last seen 5d ago

### Recently Resolved
- Zotero enrichment order errors — resolved by CLAUDE.md rule (14d ago, -100% frequency)
```

## Preference Drift Detection

### Monitoring Mechanism

On each `/ccc:insights` run, the pipeline snapshots `.ccc-preferences.yaml`:

1. Compute SHA-256 hash of current file
2. Compare against the most recent `preference_snapshots` record
3. If hash differs, store a new snapshot with a diff summary
4. Analyze the snapshot history for drift signals

### Drift Signals

| Signal | Threshold | Severity | Interpretation |
|--------|-----------|----------|---------------|
| **High change frequency** | 3+ changes in 30 days | Warning | User is actively experimenting. Monitor but don't alert. |
| **Oscillation** | Same preference toggled back and forth within 14 days | Alert | Indecision detected. Surface in trajectory report with recommendation. |
| **Mode default cycling** | `execution_mode_default` changed 3+ times in 30 days | Alert | Core workflow instability. Suggest reviewing execution-modes skill. |
| **Monotonic refinement** | Changes trend in one direction (e.g., thresholds gradually tightening) | Info | Intentional tuning. Log but do not alert. |

### Distinguishing Refinement from Indecision

The key distinction is **monotonicity**. If a preference moves in one direction over time (e.g., `retry_budget: 3 -> 4 -> 5`), that is refinement. If it oscillates (e.g., `mode: tdd -> quick -> tdd`), that is indecision.

**Detection algorithm:**

1. For each preference key that changed 2+ times in 30 days:
2. Extract the sequence of values: `[v1, v2, v3, ...]`
3. Check monotonicity:
   - Numeric values: all increasing or all decreasing = refinement
   - Enum values: no repeated prior value = refinement; any repeated prior value = oscillation
   - String values: Levenshtein distance from v(n) to v(n-1) always increasing = refinement (progressively different)
4. Tag the drift record: `monotonic_refinement` or `oscillation`

## Cross-Report Correlation

### Purpose

Measure whether changes to CLAUDE.md, skills, or preferences actually reduce friction. This closes the feedback loop: observe friction -> adopt rule -> measure effect.

### Evidence Chain

```
Pattern P identified in Report R1
  → Rule/change C adopted between R1 and R2
    → Pattern P frequency in R2..Rn compared to R1 baseline
      → Correlation record created: {pattern_id: P, rule_id: C, delta_pct: -40%}
```

### How Correlations Are Built

1. **Detect rule adoption:** Compare CLAUDE.md content (or `.ccc-preferences.yaml`, or skill inventory) between consecutive reports. Any addition, modification, or removal is a "change event."
2. **Link to patterns:** For each active friction pattern at the time of the change, create a candidate correlation.
3. **Measure effect:** After 2+ subsequent reports, compute the change in pattern frequency:
   - `delta_pct = (post_frequency - pre_frequency) / pre_frequency * 100`
   - `post_frequency`: average frequency in the 2 reports after the change
   - `pre_frequency`: average frequency in the 2 reports before the change
4. **Score strength:** Correlation strength ranges from -1.0 (change made things worse) to 1.0 (change fully resolved the friction).
   - `strength = -delta_pct / 100` (clamped to [-1.0, 1.0])
   - Positive strength = friction decreased after change (good)
   - Negative strength = friction increased after change (bad)
5. **Require minimum evidence:** Correlations are only created when at least 2 post-change reports exist. Single-report comparisons are too noisy.

### Correlation Output Format

```markdown
## Rule Effectiveness — Last 30 Days

| Rule/Change | Pattern Affected | Before | After | Delta | Strength |
|-------------|-----------------|--------|-------|-------|----------|
| Added Zotero enrichment order rule | Zotero metadata errors | 4.5/report | 0.5/report | -89% | 0.89 |
| Changed exec default to tdd | Incomplete test coverage | 3.0/report | 1.5/report | -50% | 0.50 |
| Removed deprecated labels | Label confusion errors | 2.0/report | 2.5/report | +25% | -0.25 |
```

### Actionable Thresholds

| Strength | Interpretation | Suggested Action |
|----------|---------------|-----------------|
| > 0.7 | Strong positive correlation | Rule is working. Keep it. Document as evidence for the rule. |
| 0.3 - 0.7 | Moderate positive | Rule likely helps. Monitor for another cycle. |
| -0.3 - 0.3 | Weak / no correlation | Rule may not be addressing root cause. Review. |
| < -0.3 | Negative correlation | Rule may be harmful. Consider reverting or revising. |

## Integration Points

### Feeds Into (Downstream Consumers)

| Consumer | What It Reads | How |
|----------|--------------|-----|
| **adaptive-methodology** (P2) | Trajectory scores, drift signals | Queries trajectories table for composite score; reads drift alerts to adjust methodology defaults |
| **`/ccc:insights --trajectory`** | Full trajectory report | Calls trajectory computation, formats output per the template above |
| **`/ccc:insights --patterns`** | Active pattern list with confidence | Queries patterns table filtered by `resolution_status = 'active'`, ordered by confidence |
| **claudemd-lifecycle** (P3) | Correlation data | Queries correlations table to measure rule effectiveness; informs rule deprecation decisions |

### Reads From (Upstream Sources)

| Source | What It Provides | Format |
|--------|-----------------|--------|
| **insights-pipeline** archives | Raw friction points, outcomes, metrics per report | Structured Markdown in `~/.claude/insights/archives/` |
| **`.ccc-preferences.yaml`** | Current preference state | YAML file in project root |
| **CLAUDE.md** | Current rule set (for change detection) | Markdown file |
| **skill inventory** | Current skill list (for change detection) | Directory listing of `skills/` |

### Referenced By

| Skill | Reference Purpose |
|-------|------------------|
| **claudemd-lifecycle** (P3) | Uses correlation data to decide when to deprecate, strengthen, or refine CLAUDE.md rules |
| **observability-patterns** | Layer 3 (Adaptive Methodology) depends on trajectory data from this skill |
| **insights-pipeline** | Cross-references this skill for correlation building and schema version alignment |

## Rebuild Guarantee

The SQLite index is a cache, not a source of truth. The source of truth is the archived insights reports in `~/.claude/insights/archives/`. If the database is corrupted or deleted:

1. Delete `~/.claude/insights/index.db`
2. Run `/ccc:insights --rebuild-index`
3. The pipeline re-parses all archived reports and reconstructs the patterns, correlations, and trajectories tables
4. Preference snapshots are rebuilt from git history of `.ccc-preferences.yaml` (if available) or started fresh

Rebuild time scales linearly with archive count. Expect ~1 second per 10 archived reports.

## Prerequisites

- Archived insights reports in `~/.claude/insights/archives/` (created by `insights-pipeline` skill)
- SQLite3 available on the system (standard on macOS and most Linux distributions)
- Write access to `~/.claude/insights/`

## Cross-Skill References

- **insights-pipeline** -- Produces the archived reports that feed pattern matching. Schema version alignment ensures compatibility.
- **quality-scoring** -- Trajectory scores can supplement quality evidence for issue closure decisions.
- **observability-patterns** -- Layer 3 (Adaptive Methodology) consumes trajectory data to decide whether methodology parameters should adjust.
- **execution-modes** -- Preference drift detection monitors execution mode defaults; oscillation alerts reference this skill's mode definitions.
- **issue-lifecycle** -- Correlation evidence (rule effectiveness) can be cited in closure comments as evidence of impact.
