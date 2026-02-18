---
name: resource-freshness
description: |
  Detect stale resources across the CCC ecosystem: project descriptions, initiative status updates,
  milestone health, Linear documents, and plugin reference docs (README, CONNECTORS, plugin-manifest).
  Compares actual plugin state from disk against documented state and flags discrepancies.
  Produces a freshness report with Error/Warning/Info severity ratings.
  Use when running periodic health checks, auditing resource staleness, checking for drift between
  plugin state and documentation, or as part of the /ccc:hygiene pipeline.
  Trigger with phrases like "check resource freshness", "stale resources", "freshness audit",
  "resource drift", "are my docs stale", "plugin manifest drift", "check project descriptions".
---

# Resource Freshness

Detect stale, outdated, or drifted resources across the CCC ecosystem. This skill audits five resource categories — project descriptions, initiative status updates, milestone health, Linear documents, and plugin reference docs — and produces a unified freshness report with severity-rated findings.

The skill operates in **read-only mode by default**. It flags problems but does not auto-remediate. Staleness flags are always advisory — a human decides what to update.

## When to Use

- **Periodic health checks** — Run weekly or before milestone boundaries to catch staleness early.
- **Pre-planning** — Before starting a new cycle, verify all resources are current.
- **Post-milestone** — After completing a milestone, check that project descriptions and docs reflect the new state.
- **Hygiene pipeline** — Invoked automatically by `/ccc:hygiene` as the "Resource Freshness" check group.
- **Ad hoc** — When you suspect a document or description has drifted from reality.

## When NOT to Use

- For one-time project setup — use `project-cleanup` instead.
- For document creation — use `document-lifecycle` instead.
- For milestone carry-forward decisions — use `milestone-management` instead.
- For issue-level staleness (Backlog >30 days, etc.) — that's in the `/ccc:hygiene` Staleness check group, not here.

## The Five Check Categories

### Category 1: Project Description Staleness

Project descriptions are the primary orientation surface for anyone entering a project. Stale descriptions mislead contributors and cause misrouted work.

**Detection logic:**

```
FOR each project in scope:
  FETCH project metadata (description, updatedAt)
  FETCH project milestones (list_milestones)

  days_since_update = today - project.description.updatedAt

  IF days_since_update > staleness_threshold:
    IF any milestone has new Done issues since last description update:
      FLAG as Warning: "Project description may be stale — N issues completed since last update"
    ELSE:
      FLAG as Info: "Project description unchanged for N days (no milestone progress detected)"

  IF project was renamed since last description update:
    FLAG as Error: "Project renamed but description not updated"

  IF milestone count changed since last description update:
    FLAG as Warning: "Milestone structure changed — description may need refresh"
```

**Dynamic thresholds (evidence-based):**

Thresholds are **not hardcoded**. They are computed at runtime from observed update distributions for the workspace, using the P90 × 1.5 formula. This means the skill adapts as the team's cadence changes.

**Threshold computation algorithm:**

```
FUNCTION compute_threshold(resource_type, observed_update_ages):
  IF len(observed_update_ages) < 3:
    RETURN fallback_threshold(resource_type)

  SORT observed_update_ages ascending
  p90_index = floor(len * 0.9)
  p90 = observed_update_ages[p90_index]
  threshold = ceil(p90 * 1.5)

  # Clamp to sensible bounds
  RETURN clamp(threshold, min=3, max=90)

FUNCTION fallback_threshold(resource_type):
  # Used when fewer than 3 data points exist
  MATCH resource_type:
    "project_description" → 20   # Claudian baseline: P90=13, ×1.5=20
    "initiative_update"   → 15   # Claudian baseline: P90=10, ×1.5=15
    "milestone_stall"     → 14   # Operational milestones cycle in ~8-10 days
    "document"            → 9    # Claudian baseline: P90=6, ×1.5=9
```

**Calibration evidence (Claudian workspace, Feb 2026):**

| Resource | N | Median | P75 | P90 | P90×1.5 (threshold) |
|----------|---|--------|-----|-----|---------------------|
| Project descriptions | 5 | 1d | 10d | 13d | **20d** |
| Initiative metadata | 5 | 7d | 8d | 10d | **15d** |
| Documents | 50 | 2d | 6d | 6d | **9d** |
| Milestones (operational) | 4 | 9d | 10d | 10d | **15d** |

*Note: Initiative status updates had 0 formal posts — threshold based on `updatedAt` age. Long-horizon placeholder milestones (conferences, demos >30d) are excluded from calibration; only operational milestones with active issue flow are sampled.*

**The fallback values above are derived from this calibration data.** They are intentionally conservative (round up) so they don't fire on normal cadence. When the skill runs, it attempts to compute live thresholds first; fallbacks are only used when sample size is too small.

**Per-project override:** Projects can pin a static threshold by including an HTML comment in their description:

```
<!-- freshness:N -->
```

Where N is the number of days. This bypasses dynamic computation for that project only. Use for maintenance projects or projects with intentionally slow cadence.

### Category 2: Initiative Status Update Freshness

Initiative status updates track strategic progress. This category checks two signals: formal status updates (via `save_status_update`) and initiative metadata staleness (via `updatedAt` age).

**Detection logic:**

```
FOR each initiative with active projects:
  FETCH status updates (get_status_updates)
  FETCH initiative metadata (updatedAt)

  # Signal 1: Formal status updates
  IF no status updates exist:
    FLAG as Info: "Initiative has no formal status updates — consider posting one"
  ELSE:
    latest_update = most recent status update
    days_since_update = today - latest_update.createdAt
    threshold = compute_threshold("initiative_update", all_initiative_update_gaps)

    IF days_since_update > threshold:
      FLAG as Warning: "Initiative status update overdue — last update N days ago (threshold: M days)"

    IF latest_update.health is "atRisk" or "offTrack":
      FLAG as Info: "Initiative health is [status] — may need attention"

  # Signal 2: Initiative metadata staleness
  initiative_age = today - initiative.updatedAt
  threshold = compute_threshold("initiative_update", all_initiative_ages)

  IF initiative_age > threshold:
    FLAG as Warning: "Initiative [name] metadata stale — last touched N days ago"
```

**Calibration note:** As of Feb 2026, zero formal status updates exist in the Claudian workspace. The threshold for formal updates falls back to 15 days (derived from initiative `updatedAt` P90=10d × 1.5). Once formal updates are posted regularly, the dynamic threshold adapts to the actual posting cadence.

**Integration with `project-status-update` skill:** This category detects *when* updates are missing or overdue. The `project-status-update` skill handles *how* to generate updates. Resource-freshness never generates updates — it only flags their absence.

### Category 3: Milestone Health

Milestones with passed target dates, stalled completion percentages, or orphaned issues indicate execution drift.

**Detection logic:**

```
FOR each project with active milestones:
  FETCH milestones (list_milestones)

  FOR each active milestone (not completed, not archived):
    IF milestone.targetDate < today:
      open_issues = count of non-Done issues in milestone
      IF open_issues > 0:
        FLAG as Warning: "Milestone [name] target date passed with N open issues"
      ELSE:
        FLAG as Info: "Milestone [name] target date passed — all issues Done (mark complete?)"

    IF milestone.targetDate is within near_due_window AND completion < 50%:
      # near_due_window = max(3, median_milestone_lifespan * 0.3)
      # Claudian baseline: operational milestones last ~8-10 days, so 3 days is ~30%
      FLAG as Warning: "Milestone [name] due in N days but only M% complete"

    done_count = count of Done issues
    total_count = count of all issues
    stall_threshold = compute_threshold("milestone_stall", completed_milestone_lifespans)
    IF total_count > 0 AND done_count == 0 AND milestone age > stall_threshold:
      FLAG as Warning: "Milestone [name] has N issues but 0% completion after M days — may be stalled"

    IF milestone has no issues:
      FLAG as Info: "Milestone [name] has no issues assigned — empty milestone"
```

**Delegation:** This category reads milestone data directly. For carry-forward decisions (moving open issues from expired milestones to the next one), defer to the `milestone-management` skill. Resource-freshness detects the problem; `milestone-management` handles the remedy.

### Category 4: Document Staleness

Linear documents have type-specific staleness thresholds defined by the `document-lifecycle` skill. This category delegates to those thresholds and adds ecosystem-level checks.

**Detection logic:**

```
FOR each project in scope:
  IF project description contains "<!-- no-auto-docs -->":
    SKIP document checks for this project
    REPORT: "Document freshness: skipped ([project] opted out)"

  FETCH documents (list_documents, limit: 100)

  FOR each document:
    IDENTIFY type by title pattern (per document-lifecycle taxonomy)
    LOOK UP staleness threshold for type

    CHECK content for <!-- reviewed: YYYY-MM-DD --> marker
    IF marker present AND within threshold:
      SKIP (recently reviewed)

    days_since_update = today - document.updatedAt
    IF days_since_update > threshold:
      FLAG as Warning: "Document [title] stale — last updated N days ago (threshold: M days)"

  IF document count >= 100:
    FLAG as Info: "Document freshness limited to first 100 documents — audit may be incomplete"
```

**Staleness thresholds:**

For typed documents, use `document-lifecycle` taxonomy thresholds as the primary signal. For untyped documents, apply the dynamic P90 × 1.5 threshold computed from the workspace document corpus.

| Document Type | Threshold Source | Calibrated Value (Claudian Feb 2026) | Pattern |
|--------------|-----------------|--------------------------------------|---------|
| Key Resources | `document-lifecycle` taxonomy | 14 days | exact: `Key Resources` |
| Decision Log | `document-lifecycle` taxonomy | 14 days | exact: `Decision Log` |
| Project Update | No staleness | — | prefix: `Project Update — ` |
| Research Library Index | `document-lifecycle` taxonomy | 30 days | exact: `Research Library Index` |
| ADR | `document-lifecycle` taxonomy | 60 days | prefix: `ADR: ` |
| Untyped / Living Document | Dynamic P90×1.5 | **9 days** (P90=6d) | project-specific |

*The untyped document threshold of 9 days reflects that the Claudian workspace's 50 documents have a median age of 2 days and P90 of 6 days — a very active corpus. In a slower workspace, the dynamic computation would produce a higher threshold automatically.*

**Per-document override** in project description:

```
<!-- staleness:document-slug:N -->
```

### Category 5: Plugin Reference Doc Drift

Plugin reference documents (README.md, CONNECTORS.md, docs/plugin-manifest.md) can drift from the actual plugin state on disk. This category compares documented state against authoritative sources (`marketplace.json`, filesystem).

**Detection logic:**

```
READ marketplace.json → extract authoritative counts:
  actual_skills = len(plugins[0].skills)
  actual_commands = len(plugins[0].commands)
  actual_agents = len(plugins[0].agents)
  actual_version = plugins[0].version

READ README.md → extract documented counts:
  PARSE "N skills, N commands, N agents, N hooks" pattern
  PARSE version badge or version string

READ CONNECTORS.md → extract agent status fields:
  FOR each documented agent/connector:
    CHECK status field (Evaluating/Adopted/Deprecated)
    CHECK cost estimates
    CHECK trial/adoption dates

READ docs/plugin-manifest.md → extract documented counts and version:
  PARSE skill/command/agent/hook counts
  PARSE version number

COMPARE actual vs documented:
  IF skill count mismatch:
    FLAG as Error: "README skill count (N) != manifest (M)"
  IF command count mismatch:
    FLAG as Error: "README command count (N) != manifest (M)"
  IF agent count mismatch:
    FLAG as Error: "README agent count (N) != manifest (M)"
  IF version mismatch:
    FLAG as Warning: "README version (X) != marketplace.json version (Y)"

  IF CONNECTORS.md has stale status fields:
    FLAG as Warning: "CONNECTORS.md agent [name] status may be stale"
  IF docs/plugin-manifest.md counts differ from manifest:
    FLAG as Warning: "plugin-manifest.md counts drift from marketplace.json"
```

**What counts as "drift":**

| Check | Source of Truth | Documented In | Severity |
|-------|----------------|---------------|----------|
| Skill count | marketplace.json `skills[]` | README.md | Error |
| Command count | marketplace.json `commands[]` | README.md | Error |
| Agent count | marketplace.json `agents[]` | README.md | Error |
| Hook count | `hooks/scripts/*.sh` on disk | README.md | Error |
| Plugin version | marketplace.json `version` | README.md, plugin-manifest.md | Warning |
| Agent status | Actual usage (Evaluating/Adopted/Deprecated) | CONNECTORS.md | Warning |
| Skill list | marketplace.json `skills[]` | docs/plugin-manifest.md | Warning |

## Freshness Report Output Format

The skill produces a structured report following the same severity model used across all CCC hygiene checks.

```markdown
## Resource Freshness Report

**Date:** [timestamp]
**Projects audited:** N
**Initiatives audited:** N
**Documents audited:** N
**Reference docs checked:** N

### Summary
- Errors: N
- Warnings: N
- Info: N

### Category Coverage
| Category | Checks Run | Errors | Warnings | Info |
|----------|-----------|--------|----------|------|
| Project Descriptions | N | N | N | N |
| Initiative Updates | N | N | N | N |
| Milestone Health | N | N | N | N |
| Document Staleness | N | N | N | N |
| Reference Doc Drift | N | N | N | N |

### Errors (must fix)
| Resource | Category | Details | Suggested Fix |
|----------|----------|---------|---------------|
| [resource name] | [category] | [what's wrong] | [what to do] |

### Warnings (should fix)
| Resource | Category | Details | Suggested Fix |
|----------|----------|---------|---------------|
| [resource name] | [category] | [what's wrong] | [what to do] |

### Info (nice to fix)
| Resource | Category | Details | Suggested Fix |
|----------|----------|---------|---------------|
| [resource name] | [category] | [what's wrong] | [what to do] |
```

**Severity scoring** (same as `/ccc:hygiene`):

| Level | Label | Score Impact | Action Required |
|-------|-------|-------------|-----------------|
| Error | must fix | -10 per finding | Blocking — should be resolved before next cycle |
| Warning | should fix | -3 per finding | Advisory — resolve during current cycle |
| Info | nice to fix | -1 per finding | Informational — resolve when convenient |

**Suppress clean categories:** If a category has zero findings, omit it from the Errors/Warnings/Info tables (but keep it in the Category Coverage table with zeroes). This follows the `planning-preflight` convention of suppressing clean results.

## Hygiene Integration

Resource freshness integrates with `/ccc:hygiene` as an additional check group that runs after the existing six groups.

**Check group order (updated):**

1. Label Consistency
2. Metadata Completeness
3. Staleness (issue-level)
4. Milestone Health (delegates to `milestone-management`)
5. Document Health (delegates to `document-lifecycle`)
6. Dependency Health (delegates to `dependency-management`)
7. **Resource Freshness** (delegates to this skill)

**How it's invoked:**

The hygiene command calls the resource-freshness skill after dependency health checks. The skill returns findings in the standard `{severity, resource, category, details, suggested_fix}` format. The hygiene command merges these findings into the overall hygiene report and adjusts the hygiene score accordingly.

**Session cache:** The resource-freshness skill uses session cache when available. If `list_milestones`, `list_documents`, or `get_status_updates` have already been called in the current session (by earlier hygiene check groups), reuse those results. Do NOT re-fetch.

## Scope Control

**Default scope:** All projects in the current team.

**Narrow scope:** When invoked with a specific project name (e.g., "check freshness for CCC"), limit to that project only. Skip initiative-level checks unless the initiative contains the specified project.

**Plugin reference doc checks** (Category 5) only run when the current working directory is a CCC plugin repository (detected by presence of `.claude-plugin/marketplace.json`). Outside a plugin repo, Category 5 is skipped with a note: "Reference doc drift: skipped (not a plugin repository)."

## Graceful Degradation

Every data source can fail. The skill must continue when individual sources are unavailable.

| Failure | Response |
|---------|----------|
| Linear API unavailable | Skip Categories 1-4. Report: "Linear API unavailable — skipped project/initiative/milestone/document checks." Run Category 5 (local disk) only. |
| `list_milestones` fails for a project | Skip milestone health for that project. Report: "Milestone health: skipped for [project] (API error)." Continue with other projects. |
| `get_status_updates` fails | Skip initiative checks. Report: "Initiative freshness: skipped (API error)." Continue with other categories. |
| `list_documents` fails for a project | Skip document checks for that project. Report: "Document freshness: skipped for [project] (API error)." Continue with other projects. |
| README.md missing | Skip README drift checks. Report: "README drift: skipped (file not found)." |
| CONNECTORS.md missing | Skip CONNECTORS drift checks. Report: "CONNECTORS drift: skipped (file not found)." |
| docs/plugin-manifest.md missing | Skip plugin-manifest drift checks. Report: "Plugin manifest doc drift: skipped (file not found)." |
| marketplace.json missing | Skip ALL Category 5 checks. Report: "Reference doc drift: skipped (no marketplace.json found)." |
| `.ccc-preferences.yaml` missing | Use default thresholds. No warning needed — defaults are sensible. |

**Principle:** Never block the entire freshness run because one data source is unavailable. Report what you can, skip what you can't, and be transparent about what was skipped.

## Advisory-Only Principle

Resource freshness follows the CCC-wide pattern: **detect → flag → present to human → wait for decision**.

The skill NEVER:
- Auto-updates project descriptions
- Auto-posts initiative status updates
- Auto-carries-forward milestone issues
- Auto-updates documents
- Auto-edits README, CONNECTORS, or plugin-manifest.md

It ONLY:
- Reads current state
- Compares against thresholds and authoritative sources
- Reports findings with suggested fixes
- Contributes to the hygiene score

## Configuration

### Threshold Strategy: Dynamic First, Override Second

The skill computes thresholds dynamically from observed data using the P90 × 1.5 formula. This is the **primary** threshold mechanism — no configuration needed for normal operation.

Configuration is only needed to **override** the dynamic thresholds in special cases.

### `.ccc-preferences.yaml` Overrides

Static overrides pin thresholds when dynamic computation is inappropriate (e.g., a project with irregular cadence that shouldn't adapt):

```yaml
resource_freshness:
  # Pin static thresholds (bypasses dynamic computation)
  # Only set these if you need to override the P90×1.5 defaults
  project_description_threshold_days: null  # null = use dynamic (default)
  initiative_update_threshold_days: null
  milestone_stall_threshold_days: null
  document_default_threshold_days: null

  # Category 5 toggle
  reference_doc_drift_enabled: true

  # Dynamic computation parameters
  dynamic:
    multiplier: 1.5         # Applied to P90 (default: 1.5)
    min_sample_size: 3      # Below this, use fallback thresholds
    min_threshold_days: 3   # Floor clamp
    max_threshold_days: 90  # Ceiling clamp
```

**Resolution order:** Per-project HTML override → `.ccc-preferences.yaml` static override → dynamic P90×1.5 → fallback threshold.

### Per-Project Overrides

In the project description, use HTML comments:

```
<!-- freshness:N -->              # Pin project description threshold to N days
<!-- staleness:doc-slug:N -->     # Pin specific document threshold (from document-lifecycle)
<!-- no-auto-docs -->             # Opt out of document checks entirely
<!-- no-freshness -->             # Opt out of ALL resource freshness checks for this project
```

## Performance Budget

| Operation | Expected Cost | Budget |
|-----------|--------------|--------|
| List projects | 1 API call | Cached |
| Project descriptions | 1 call per project | Max 10 projects |
| Initiative status updates | 1 call per initiative | Max 5 initiatives |
| List milestones (per project) | 1 call per project | Session cached |
| List documents (per project) | 1 call per project | Session cached, limit: 100 |
| Local file reads (Cat 5) | 4 file reads | Instant (disk) |

**Total budget:** ~25 API calls for a typical workspace. Well within the standard session budget.

**Session cache integration:** Milestone and document data fetched by earlier hygiene check groups (Milestone Health, Document Health) should be reused. The resource-freshness skill checks for cached results before making API calls.

## Cross-Skill References

- **document-lifecycle** -- Provides document type taxonomy and staleness thresholds for Category 4. Resource-freshness delegates document classification to this skill's `references/document-types.md`.
- **milestone-management** -- Handles milestone carry-forward decisions when Category 3 detects expired milestones with open issues. Resource-freshness detects the problem; `milestone-management` provides the remedy.
- **project-status-update** -- Generates initiative and project status updates. Resource-freshness (Category 2) detects when updates are missing or overdue; `project-status-update` handles the generation.
- **project-cleanup** -- One-time project normalization vs. resource-freshness's ongoing monitoring. Use `project-cleanup` for initial setup, resource-freshness for maintenance.
- **planning-preflight** -- Both skills detect staleness but at different levels. `planning-preflight` focuses on issue-level staleness (IQR-based detection). Resource-freshness focuses on resource-level staleness (descriptions, docs, milestones).
- **issue-lifecycle** -- Defines project hygiene protocol with staleness thresholds for project descriptions. Resource-freshness replaces the static 14-day threshold with a dynamic P90×1.5 computation calibrated from observed workspace data.
- **observability-patterns** -- Layer 2 (runtime) monitors skill trigger frequency. Resource-freshness can detect dormant reference docs that may indicate the observability layer is not being consulted.
- **quality-scoring** -- Freshness findings feed into the quality score's "documentation health" dimension. Zero errors + zero warnings in resource-freshness contributes to a higher quality score.
