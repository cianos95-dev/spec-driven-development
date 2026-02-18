---
description: |
  Bootstrap a fresh Linear workspace with all CCC templates, labels, and project structure.
  Reads template manifests from templates/*.json, resolves symbolic names to workspace IDs,
  creates templates via GraphQL, and updates manifests with returned linearIds.
  Idempotent — safe to run on already-configured workspaces (skips existing).
  Use when setting up a new workspace, verifying workspace completeness, or after resetting templates.
  Trigger with phrases like "bootstrap workspace", "provision workspace", "setup templates", "sync templates".
argument-hint: "[--dry-run] [--labels-only] [--templates-only] [--projects-only]"
allowed-tools: Bash, Read, Write, Edit, Grep, Glob
platforms: [cli, cowork]
---

# Template Bootstrap

Provision a fresh Linear workspace with the full CCC configuration: labels, templates, and default project structure. All definitions are read from the `templates/` directory manifests — these are the source of truth.

## Test Scenarios

Before implementing, verify the command handles these scenarios correctly. After implementation, re-run each scenario to confirm.

### TS-1: Fresh workspace (no labels, no templates)

**Given:** A workspace with no CCC labels and no templates.
**When:** `/ccc:template-bootstrap` is run.
**Then:**
- All 29 labels are created
- All 20 templates are created with resolved label/state/team IDs
- Each manifest file is updated with the returned `linearId`
- Summary shows 29 labels created, 0 skipped; 20 templates created, 0 skipped

### TS-2: Fully configured workspace (idempotent re-run)

**Given:** A workspace where all labels and templates already exist, and all manifests have `linearId` populated.
**When:** `/ccc:template-bootstrap` is run.
**Then:**
- No labels created (all 29 skipped as existing)
- No templates created (all 20 skipped — matched by `linearId`)
- Summary shows 0 created, 29 labels skipped; 0 templates created, 20 skipped

### TS-3: Partial workspace (some labels missing, some templates missing)

**Given:** A workspace with 20/29 labels and 8/20 templates.
**When:** `/ccc:template-bootstrap` is run.
**Then:**
- 9 missing labels are created
- 6 missing templates are created
- Existing labels and templates are untouched
- Summary accurately counts created vs skipped

### TS-4: Dry run mode

**Given:** Any workspace state.
**When:** `/ccc:template-bootstrap --dry-run` is run.
**Then:**
- No mutations executed (no labels created, no templates created, no files written)
- Report shows what WOULD be created/skipped
- Each action prefixed with `[DRY RUN]`

### TS-5: Unresolvable symbolic name

**Given:** A manifest references label `type:nonexistent` which doesn't exist in the workspace.
**When:** `/ccc:template-bootstrap` is run and label creation is for some reason skipped.
**Then:**
- Resolution fails for that specific template
- Error reported: "Cannot resolve label 'type:nonexistent' for template 'X'"
- Other templates that CAN resolve continue to be processed
- Summary includes error count

### TS-6: Document templates (no labels/state)

**Given:** Document template manifests (doc-prfaq.json, doc-adr.json, etc.) with no `labels`, `state`, or `team` fields.
**When:** Bootstrap processes these templates.
**Then:**
- Templates are created with only `title` and `descriptionData`
- No resolution needed — `templateData` passed through as-is
- No errors about missing labels/state

### TS-7: Project templates (projectTemplateData)

**Given:** project-standard.json with `projectTemplateData` containing `leadId`, `statusId`, `teamIds`.
**When:** Bootstrap processes this template.
**Then:**
- `projectTemplateData` symbolic names are resolved (leadId → user UUID, teamIds → team UUIDs)
- Template created with both `templateData` and resolved project fields

### TS-8: Manifest linearId write-back

**Given:** A manifest with `"linearId": null`.
**When:** Bootstrap creates the template and gets back a UUID.
**Then:**
- The manifest file is updated with the returned `linearId`
- Only the `linearId` field changes — all other content preserved exactly
- File is valid JSON after update

## Prerequisites

Requires a Linear API token. The command reads the token from one of:
1. `LINEAR_API_KEY` environment variable
2. `LINEAR_AGENT_TOKEN` environment variable
3. The Linear OAuth token from `~/.mcp.json` (parse the `linear` MCP server config)

If no token is found, prompt the user to provide one.

## Step 0: Parse Flags

| Flag | Effect |
|------|--------|
| `--dry-run` | Report what would happen without executing mutations |
| `--labels-only` | Only provision labels, skip templates and projects |
| `--templates-only` | Only provision templates (assumes labels exist) |
| `--projects-only` | Only provision default projects (assumes labels and templates exist) |

If no flag is passed, run all phases in order: labels → templates → projects.

## Step 1: Fetch Workspace Reference Data

Query the current workspace state to build lookup maps. These are used both for idempotency checks (what already exists) and for symbolic name resolution.

### 1a: Fetch All Labels

Use `list_issue_labels` (limit: 250) to get all workspace and team labels.

Build lookup map: `labelName → { id, name, isGroup, parentId }`

### 1b: Fetch All Teams

Use `list_teams` to get all teams.

Build lookup map: `teamName → { id, name, key }`

### 1c: Fetch Issue Statuses

For each team, use `list_issue_statuses(team)` to get valid states.

Build lookup map: `teamName:stateName → { id, name, type }`

### 1d: Fetch Existing Templates

Execute a GraphQL query to get all existing templates:

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

Build lookup map: `templateId → { id, name, type }`

### 1e: Fetch Users (for assignee/lead resolution)

Use `list_users` to get workspace members.

Build lookup map: `userName → { id, name, email }`

## Step 2: Provision Labels

The CCC label taxonomy consists of 29 labels organized into domain-based groups. Create any that don't already exist.

### Label Definitions

```
Type (required on every issue):
  type:feature
  type:bug
  type:spike
  type:chore

Spec stage:
  spec:draft
  spec:ready
  spec:review
  spec:implementing
  spec:complete

Execution mode:
  exec:quick
  exec:tdd
  exec:pair
  exec:checkpoint
  exec:swarm

Research:
  research:needs-grounding
  research:literature-mapped
  research:methodology-validated
  research:expert-reviewed

Template:
  template:prfaq-feature
  template:prfaq-infra
  template:prfaq-research
  template:prfaq-quick

Origin:
  source:voice
  source:cowork
  source:code-session
  source:direct
  source:vercel-comments

Auto:
  auto:implement

Architecture:
  arch:pre-pivot
```

### Label Creation Algorithm

For each label in the taxonomy:

1. Check if `labelName` exists in the labels lookup map from Step 1a.
2. **If exists:** Skip. Log: `[SKIP] Label "type:feature" already exists (id: abc-123)`
3. **If not exists:** Create via `create_issue_label(name, description)`. Log: `[CREATE] Label "type:feature" created (id: new-456)`
4. **If `--dry-run`:** Log: `[DRY RUN] Would create label "type:feature"` and skip the mutation.

After creating new labels, refresh the label lookup map (re-fetch all labels) so that Step 3 can resolve the newly created labels.

### Label Groups

The label prefix (before the colon) defines the group. Linear label groups are optional but improve the UI. If the workspace supports label groups, create group labels for each prefix:

| Group | Labels Under Group |
|-------|--------------------|
| Type | type:feature, type:bug, type:spike, type:chore |
| Spec | spec:draft, spec:ready, spec:review, spec:implementing, spec:complete |
| Exec | exec:quick, exec:tdd, exec:pair, exec:checkpoint, exec:swarm |
| Research | research:needs-grounding, research:literature-mapped, research:methodology-validated, research:expert-reviewed |
| Template | template:prfaq-feature, template:prfaq-infra, template:prfaq-research, template:prfaq-quick |
| Source | source:voice, source:cowork, source:code-session, source:direct, source:vercel-comments |
| Auto | auto:implement |
| Architecture | arch:pre-pivot |

**Note:** Label group creation is best-effort. If the API doesn't support `isGroup` or `parentId`, skip grouping and create flat labels. The labels themselves are the critical output — grouping is cosmetic.

## Step 3: Provision Templates

Read all manifest files from `templates/*.json` (excluding `schema.json` and `README.md`), resolve symbolic names, and create templates that don't already exist.

### 3a: Read Manifest Files

```
Glob: templates/*.json
Exclude: schema.json
```

For each manifest file, parse JSON and validate against `schema.json` structure (required fields: `name`, `type`, `templateData`).

### 3b: Check Idempotency

For each manifest:

1. **If `linearId` is not null:** Check if that ID exists in the template lookup from Step 1d.
   - **Exists:** Skip this template. Log: `[SKIP] Template "Feature" already exists (id: 9ba890c6-...)`
   - **Not found:** The `linearId` is stale (template was deleted from Linear). Clear the `linearId` and proceed to create.
2. **If `linearId` is null:** This template needs to be created.
   - **Additional check:** Search existing templates by `name` and `type` to avoid duplicates even without a `linearId`. If a match is found, write back the `linearId` and skip. Log: `[LINK] Template "Feature" found by name, linked (id: xyz-789)`

### 3c: Resolve Symbolic Names

For each manifest that needs creation, resolve the `templateData`:

**Issue templates:**
1. `labels` → `labelIds`: For each label name, look up the UUID from the label map. Error if any label name is unresolvable.
2. `state` → `stateId`: Look up the state UUID from the team-scoped state map. Requires `team` to be resolved first.
3. `team` → `teamId`: Look up the team UUID from the team map.
4. `assignee` → `assigneeId`: Look up the user UUID from the user map. Skip if null.
5. Preserve all other fields (`title`, `priority`, `estimate`, `descriptionData`) as-is.
6. Remove the symbolic fields (`labels`, `state`, `team`, `assignee`) from the output.
7. Serialize as JSON string (Linear expects `templateData` as a string).

**Document templates:**
1. No symbolic resolution needed — document templates typically only have `title` and `descriptionData`.
2. Serialize `templateData` as JSON string.

**Project templates:**
1. Resolve `templateData` same as issue templates (if it has labels/state/team).
2. Additionally resolve `projectTemplateData`:
   - `leadId` → user UUID
   - `statusId` → project status (note: project statuses differ from issue statuses — use "Backlog" as-is if it's the status name)
   - `teamIds` → array of team UUIDs
   - `labelIds` → array of label UUIDs (these are project-level labels, not issue labels)
   - `memberIds` → array of user UUIDs
   - `initiativeIds` → array of initiative UUIDs (skip if empty)
3. Serialize both as JSON strings.

### 3d: Create Templates via GraphQL

For each resolved template, execute the `templateCreate` mutation:

**Issue template:**
```graphql
mutation {
  templateCreate(input: {
    name: "Feature"
    type: "issue"
    description: "New functionality or capability"
    templateData: "{\"labelIds\":[...],\"stateId\":\"...\",\"teamId\":\"...\",\"estimate\":3,\"priority\":0,\"title\":\"[Verb] [what]\",\"descriptionData\":{...}}"
    teamId: "ee778ac4-..."
  }) {
    success
    template {
      id
      name
      type
    }
  }
}
```

**Document template:**
```graphql
mutation {
  templateCreate(input: {
    name: "PR/FAQ"
    type: "document"
    templateData: "{\"title\":\"PR/FAQ\",\"descriptionData\":{...}}"
  }) {
    success
    template {
      id
      name
      type
    }
  }
}
```

**Project template:**
```graphql
mutation {
  templateCreate(input: {
    name: "Standard Project"
    type: "project"
    templateData: "{\"title\":\"...\",\"description\":\"...\",\"priority\":0,\"descriptionData\":{...}}"
  }) {
    success
    template {
      id
      name
      type
    }
  }
}
```

**Notes on the GraphQL mutation:**
- The `teamId` in the `input` is the team the template belongs to (for team-scoped templates). For workspace-level templates, omit `teamId`.
- The `templateData` field is a **JSON string**, not an object. Serialize the resolved template data object to a string.
- The `type` field in `input` uses the same values as the manifest: `"issue"`, `"document"`, `"project"`.

If `--dry-run`, log the mutation that WOULD be executed but do not send it.

### 3e: Write Back linearId

After successful creation, update the manifest file with the returned template ID:

1. Read the manifest file.
2. Parse JSON.
3. Set `linearId` to the returned `template.id`.
4. Write back with the same formatting (2-space indent, trailing newline).

If `--dry-run`, skip the file write. Log: `[DRY RUN] Would write linearId "abc-123" to templates/issue-feature.json`

## Step 4: Provision Default Projects

Create the default project structure if projects don't already exist. This step uses the Standard Project template from Step 3.

### Default Projects

The CCC workspace expects these projects:

| Project | Purpose |
|---------|---------|
| Claude Command Centre (CCC) | Plugin development, PM/Dev workflows |
| Ideas & Prototypes | New ideas, evaluations, immature concepts |

**Note:** Other projects (Alteri, Cognito SoilWorx, Cognito Playbook) are domain-specific and should NOT be auto-created. They are created manually when needed.

### Project Creation Algorithm

For each default project:

1. Check if a project with that name already exists. Use the Linear MCP `list_projects(query: "project name")`.
2. **If exists:** Skip. Log: `[SKIP] Project "Claude Command Centre (CCC)" already exists`
3. **If not exists:** Create via `create_project(name, team, description)`. Apply the Standard Project template's `descriptionData` as the initial description.
4. **If `--dry-run`:** Log what would be created.

## Step 5: Output Bootstrap Report

```
## Bootstrap Report

**Workspace:** [workspace name]
**Date:** [ISO-8601 timestamp]
**Mode:** [full | labels-only | templates-only | projects-only | dry-run]

### Labels

| Status | Count | Details |
|--------|-------|---------|
| Created | N | [list of created label names] |
| Skipped | N | (already existed) |
| Errors | N | [list of errors] |

### Templates

| # | Manifest | Type | Status | Linear ID |
|---|----------|------|--------|-----------|
| 1 | issue-feature.json | issue | CREATED | abc-123 |
| 2 | issue-bug.json | issue | SKIPPED | def-456 |
| 3 | doc-prfaq.json | document | CREATED | ghi-789 |
| ... | ... | ... | ... | ... |

Summary: N created, N skipped, N linked, N errors

### Projects

| Project | Status |
|---------|--------|
| Claude Command Centre (CCC) | SKIPPED (exists) |
| Ideas & Prototypes | CREATED |

### Next Steps

- Run `/ccc:template-validate` to verify template health
- Run `/ccc:template-validate --fix` to correct any drift
```

## Step 6: Post-Bootstrap Validation

After all phases complete (unless `--dry-run`), automatically run the validation logic from `template-validate`:

1. Fetch all live templates.
2. Cross-reference against manifest files.
3. Report health score.

If the health score is < 100, suggest running `/ccc:template-validate --fix`.

## Execution via Bash

The Linear MCP tools (`list_issue_labels`, `list_teams`, `list_issue_statuses`, `create_issue_label`, `list_projects`, `create_project`) handle most operations. The GraphQL mutations for template creation require direct API calls:

```bash
# Example: Create a template via GraphQL
curl -s -X POST https://api.linear.app/graphql \
  -H "Authorization: Bearer $LINEAR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation($input: TemplateCreateInput!) { templateCreate(input: $input) { success template { id name type } } }",
    "variables": {
      "input": {
        "name": "Feature",
        "type": "issue",
        "description": "New functionality or capability",
        "templateData": "{...}",
        "teamId": "ee778ac4-..."
      }
    }
  }'
```

```bash
# Example: Fetch existing templates
curl -s -X POST https://api.linear.app/graphql \
  -H "Authorization: Bearer $LINEAR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"query": "{ templates { nodes { id name type templateData team { id name } } } }"}'
```

### Token Resolution

```bash
# Priority order for token
LINEAR_TOKEN="${LINEAR_API_KEY:-${LINEAR_AGENT_TOKEN:-}}"
if [ -z "$LINEAR_TOKEN" ]; then
  # Try extracting from ~/.mcp.json
  LINEAR_TOKEN=$(cat ~/.mcp.json | jq -r '.mcpServers.linear.env.LINEAR_API_KEY // empty' 2>/dev/null)
fi
if [ -z "$LINEAR_TOKEN" ]; then
  # Try Authorization header from Linear MCP config
  LINEAR_TOKEN=$(cat ~/.mcp.json | jq -r '.mcpServers.linear.headers.Authorization // empty' 2>/dev/null | sed 's/^Bearer //')
fi
```

## What If

| Situation | Response |
|-----------|----------|
| **No Linear token found** | Error: "No Linear API token found. Set LINEAR_API_KEY, LINEAR_AGENT_TOKEN, or configure Linear MCP in ~/.mcp.json." |
| **GraphQL mutation fails** | Log the error, continue with next template. Include in error count. |
| **Label already exists with different casing** | Linear label names are case-sensitive. Create the new label — the user may want both. Log a WARN. |
| **Template name collision** | If a template with the same name and type exists but different ID than manifest's `linearId`, log WARN and skip. Don't create duplicates. |
| **Manifest file is invalid JSON** | Log error, skip that manifest, continue with others. |
| **Missing schema.json** | Not a blocker — schema validation is advisory. Continue without validation. |
| **Workspace has no teams** | Error: "No teams found in workspace. Create at least one team before bootstrapping." |
| **`--dry-run` with `--labels-only`** | Both flags combine: show what labels would be created, nothing else. |
| **Rate limiting** | Linear API rate limits are generous (1500 req/hr). If hit, wait 60s and retry once. |
| **Partial failure mid-bootstrap** | Safe to re-run — idempotency ensures completed items are skipped on retry. |
| **`projectTemplateData` resolution fails** | Log error for that field, create the project template without the unresolvable field. Best-effort. |
