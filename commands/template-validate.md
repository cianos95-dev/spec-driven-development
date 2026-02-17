---
description: |
  Validate Linear templates against current workspace state. Queries all templates via GraphQL,
  cross-references labelIds/stateId/teamId against live workspace data, reports stale references and drift.
  Use when checking template health, auditing label references, or after modifying workspace labels.
  Trigger with phrases like "validate templates", "check template health", "template audit", "template drift check".
argument-hint: "[--fix] [--ci] [--ci --fix]"
allowed-tools: Bash, Read, Grep
platforms: [cli, cowork]
---

# Template Validate

Validate all Linear templates against the current workspace state. Cross-references template `templateData` fields (labels, states, teams, estimates) against live workspace data to detect drift, stale references, and mismatches.

## Prerequisites

Requires a Linear API token. The command reads the token from one of:
1. `LINEAR_API_KEY` environment variable
2. `LINEAR_AGENT_TOKEN` environment variable
3. The Linear OAuth token from `~/.mcp.json` (parse the `linear` MCP server config)

If no token is found, prompt the user to provide one.

## Step 1: Fetch All Templates via GraphQL

Execute a GraphQL query against `https://api.linear.app/graphql`:

```graphql
{
  templates {
    nodes {
      id
      name
      type
      templateData
      team {
        id
        name
      }
    }
  }
}
```

Parse the response. Each template has:
- `id` — template UUID
- `name` — display name
- `type` — `issue`, `project`, or `document`
- `templateData` — JSON string containing default field values
- `team` — optional team association (null = workspace-level)

Build a template inventory table:

```
Templates found: N
- Issue templates: N
- Project templates: N
- Document templates: N
```

## Step 2: Fetch Workspace Reference Data

Query the Linear MCP for current workspace state:

1. **Labels:** Use `list_issue_labels` (limit: 250) to get all workspace and team labels with their IDs
2. **Teams:** Use `list_teams` to get all teams with their IDs
3. **Issue statuses:** For each team referenced in templates, use `list_issue_statuses` to get valid state IDs

Build lookup maps:
- `labelId → label name`
- `teamId → team name`
- `stateId → state name + team`

## Step 3: Parse and Validate Each Template

For each template, parse `templateData` (it's a JSON string) and validate:

### 3a: Label References

Extract `labelIds` array from `templateData`. For each label ID:
- **PASS** if the ID exists in the workspace labels lookup
- **FAIL** if the ID does not exist (stale reference — label was deleted or renamed)
- **WARN** if the label exists but belongs to a different team than the template

### 3b: State References

Extract `stateId` from `templateData`. If present:
- **PASS** if the state ID exists in the team's status list
- **FAIL** if the state ID does not exist
- **WARN** if the state belongs to a different team

### 3c: Team References

Extract `teamId` from `templateData`. If present:
- **PASS** if the team ID exists
- **FAIL** if the team ID does not exist

### 3d: Estimate Validation

Extract `estimate` from `templateData`. Cross-reference against the expected estimates from the `issue-lifecycle` skill Template Selection table:

| Template | Expected Estimate |
|----------|-------------------|
| Feature | 3 |
| Bug | (unset) |
| Spike | 3 |
| Chore | 1 |

- **PASS** if estimate matches expected value
- **WARN** if estimate differs from expected value (may be intentional)
- **INFO** if template is not in the reference table (custom template)

### 3e: Required Label Coverage

For issue templates listed in the Template Selection table, verify that the expected labels are present:

| Template | Required Labels |
|----------|----------------|
| Feature | `type:feature`, `spec:draft` |
| Bug | `type:bug` |
| Spike | `type:spike`, `research:needs-grounding` |
| Chore | `type:chore` |

- **PASS** if all required labels are present
- **FAIL** if any required label is missing

## Step 4: Output Health Report

```
## Template Validation Report

**Workspace:** [workspace name]
**Date:** [timestamp]
**Templates validated:** N

### Validation Table

| # | Template | Type | Team | Labels | State | Estimate | Coverage | Status |
|---|----------|------|------|--------|-------|----------|----------|--------|
| 1 | [name]   | issue | [team/workspace] | OK/STALE(n) | OK/STALE | OK/MISMATCH | OK/MISSING(n) | PASS/WARN/FAIL |

### Issues Found

| Template | Severity | Finding | Detail |
|----------|----------|---------|--------|
| [name] | FAIL | Stale label reference | Label ID `abc123` not found in workspace |
| [name] | WARN | Estimate mismatch | Template has 5pt, expected 3pt per issue-lifecycle skill |

### Summary

- PASS: N templates (fully valid)
- WARN: N templates (minor drift)
- FAIL: N templates (stale references or missing required labels)

### Health Score

Score: XX / 100

Scoring:
- Start at 100
- Each FAIL: -15 points
- Each WARN: -5 points
- Floor at 0
```

## Step 5: CI Mode (--ci)

If `--ci` is passed, suppress the human-readable report and output structured JSON instead. The exit code signals pass/fail for CI consumption.

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All templates valid (no FAIL or WARN findings) |
| 1 | Drift detected (at least one FAIL or WARN finding) |

### JSON Output

Write to stdout:

```json
{
  "timestamp": "2026-02-17T12:00:00Z",
  "templatesValidated": 14,
  "healthScore": 85,
  "summary": {
    "pass": 11,
    "warn": 2,
    "fail": 1
  },
  "findings": [
    {
      "template": "Feature",
      "templateId": "abc-123",
      "type": "issue",
      "severity": "FAIL",
      "check": "label_reference",
      "detail": "Label ID xyz-789 not found in workspace",
      "fixable": true
    },
    {
      "template": "Spike",
      "templateId": "def-456",
      "type": "issue",
      "severity": "WARN",
      "check": "estimate_mismatch",
      "detail": "Template has 5pt, expected 3pt",
      "fixable": true
    }
  ]
}
```

Field definitions:
- `findings[]` — only includes non-PASS results. Empty array means clean.
- `fixable` — `true` if `--fix` can auto-correct this finding.
- `severity` — `FAIL` or `WARN`. PASS items are excluded.

### CI + Fix Combined (--ci --fix)

When both flags are passed:

1. Run validation and collect findings (same as Steps 1-4).
2. Auto-apply all fixable FAIL findings **without confirmation** (CI is non-interactive).
3. Re-run validation after fixes.
4. Output the post-fix JSON report.
5. Exit code reflects the post-fix state (0 if all fixes resolved, 1 if unfixable issues remain).

WARN findings are **not** auto-fixed — they may be intentional. Only FAIL findings are corrected.

## Step 6: Fix Mode (--fix)

If `--fix` is passed **without** `--ci`:

1. For each FAIL finding, generate a `templateUpdate` GraphQL mutation to correct the issue:
   - Stale label → remove the stale ID, suggest the correct label ID from the workspace lookup
   - Missing required label → add the label ID
   - Stale state → suggest the correct state ID for the team

2. Present each fix as a diff showing the before/after `templateData` change.

3. **Ask for confirmation before executing.** Never auto-apply fixes in interactive mode.

4. Execute approved fixes via GraphQL `templateUpdate` mutation:

```graphql
mutation {
  templateUpdate(id: "template-id", input: {
    templateData: "{ updated JSON string }"
  }) {
    success
    template {
      id
      name
      templateData
    }
  }
}
```

5. Re-run validation after fixes to confirm resolution.

## CI Integration

### Release Checklist

Run `template-validate --ci` as part of the CCC plugin release process. Add to the pre-tag checklist:

```
Pre-release checklist:
  1. All tests pass
  2. Plugin version bumped in .claude-plugin/plugin.json
  3. template-validate --ci exits 0  ← NEW
  4. Tag release
```

### When to Run

- **Before tagging a release:** Validates that template definitions haven't drifted since the last release.
- **After workspace changes:** Run after modifying labels, statuses, teams, or template defaults.
- **Periodic health check:** Weekly or per-cycle to catch silent drift.

### Auto-Fix in CI

For CI pipelines that should self-heal:

```
template-validate --ci --fix
```

This auto-corrects fixable FAIL findings (stale label/state references, missing required labels) and reports the post-fix state. Unfixable issues still cause exit code 1.

### n8n / Webhook Integration

For automated monitoring, the JSON output from `--ci` can be consumed by an n8n workflow or webhook to:
- Post drift alerts to a Linear comment on the CCC project
- Track health score over time
- Auto-create issues for persistent drift

## What If

| Situation | Response |
|-----------|----------|
| **No Linear token found** | Error: "No Linear API token found. Set LINEAR_API_KEY or LINEAR_AGENT_TOKEN." |
| **GraphQL query fails** | Error with HTTP status and message. Suggest checking token permissions. |
| **No templates exist** | Info: "No templates found in workspace." Report score 100/100 (nothing to validate). |
| **templateData is empty/null** | WARN the template. Some templates may have no default fields. |
| **All templates PASS** | Report score 100/100. Suggest running periodically after label or team changes. |
| **--fix with no FAIL items** | Info: "No fixes needed — all templates are valid." |
| **--ci with no findings** | Output JSON with empty `findings` array, exit 0. |
| **--ci --fix with unfixable FAILs** | Apply what can be fixed, report remaining issues, exit 1. |
| **--ci --fix and all FAILs resolved** | Output post-fix JSON, exit 0. |
