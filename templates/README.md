# Template Manifests

Template-as-code definitions for Linear workspace templates. Each JSON file in this directory represents a single Linear template with **symbolic names** instead of raw UUIDs, making templates portable across workspaces and version-controllable.

## Directory Layout

```
templates/
├── schema.json                # JSON Schema for manifest validation
├── README.md                  # This file
├── issue-feature.json         # Feature issue template (default)
├── issue-bug.json             # Bug report template
├── issue-spike.json           # Research/evaluation spike
├── issue-chore.json           # Maintenance/cleanup
├── issue-prfaq-feature.json   # Full PR/FAQ Working Backwards template
├── issue-expanded-spec.json   # Expanded specification template
├── issue-voice-memo.json      # Quick voice memo capture
├── issue-idea-dump.json       # Raw idea dump for batch processing
├── doc-prfaq.json             # PR/FAQ document template
├── doc-adr.json               # Architecture Decision Record
├── doc-session-plan.json      # Session planning document
├── doc-idea-dump.json         # Idea dump document template
├── doc-research-findings.json # Research findings document
├── doc-project-update.json    # End-of-session project status update
├── doc-key-resources.json     # Agent-managed project resource index
├── doc-decision-log.json      # Agent-managed decision tracking table
├── doc-review-findings.json   # Adversarial review output (RDR)
├── doc-dispatch-plan.json     # Multi-session parallel dispatch plan
├── doc-milestone-status.json  # Milestone health report
└── project-standard.json      # Standard project template
```

## Manifest Format

Each manifest file follows `schema.json`. Required fields:

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Template display name in Linear UI |
| `type` | `"issue"` \| `"document"` \| `"project"` | Linear template type |
| `templateData` | object | Default field values with symbolic names |

Optional fields:

| Field | Type | Description |
|-------|------|-------------|
| `description` | string \| null | Short description shown in template picker |
| `linearId` | string \| null | Linear template UUID (populated after first sync) |
| `projectTemplateData` | object | Additional project-specific fields (project templates only) |
| `variants` | array | Project-scoped overrides (see [Variants](#project-scoped-variants)) |

### templateData Fields

| Field | Type | Description | Resolution |
|-------|------|-------------|------------|
| `title` | string | Default title template | None (literal) |
| `priority` | integer | 0=None, 1=Urgent, 2=High, 3=Normal, 4=Low | None (literal) |
| `estimate` | integer | Point estimate (Fibonacci: 1,2,3,5,8,13) | None (literal) |
| `labels` | string[] | Symbolic label names | Resolved to `labelIds` UUIDs |
| `state` | string | Symbolic state name (e.g., "Backlog") | Resolved to `stateId` UUID |
| `team` | string \| null | Symbolic team name | Resolved to `teamId` UUID |
| `assignee` | string \| null | Name, email, or "me" | Resolved to `assigneeId` UUID |
| `descriptionData` | object | ProseMirror document structure | Passed through as-is |

## Symbolic Name Conventions

Symbolic names replace UUIDs to make manifests human-readable and portable. The naming conventions are:

### Labels

Labels use the exact name as displayed in Linear, including the namespace prefix:

```json
"labels": ["type:feature", "spec:draft"]
```

Label categories in use:
- **Type** (required): `type:feature`, `type:bug`, `type:spike`, `type:chore`
- **Spec stage**: `spec:draft`, `spec:ready`, `spec:review`, `spec:implementing`, `spec:complete`
- **Execution mode**: `exec:quick`, `exec:tdd`, `exec:pair`, `exec:checkpoint`, `exec:swarm`
- **Research**: `research:needs-grounding`, `research:literature-mapped`, `research:methodology-validated`, `research:expert-reviewed`
- **Template**: `template:prfaq-feature`, `template:prfaq-infra`, `template:prfaq-research`, `template:prfaq-quick`
- **Origin**: `source:voice`, `source:cowork`, `source:code-session`, `source:direct`, `source:vercel-comments`
- **Auto**: `auto:implement`
- **Architecture**: `arch:pre-pivot`

### States

States use the exact display name from the team's workflow:

```json
"state": "Backlog"
```

Available states: `Backlog`, `Todo`, `In Progress`, `In Review`, `Done`, `Canceled`, `Duplicate`

### Teams

Teams use the display name:

```json
"team": "Claudian"
```

Use `null` for workspace-level templates that aren't team-scoped.

### Assignees

Assignees use name or email:

```json
"assignee": "Cian O'Sullivan"
```

## Label Resolution

At sync time, symbolic names must be resolved to workspace-specific UUIDs. The resolution algorithm:

### Input
- A manifest file with symbolic label/state/team names
- Access to the target workspace's Linear API

### Resolution Steps

1. **Fetch workspace labels**: Call `list_issue_labels` (limit: 250) to get all labels with `{id, name}`.
2. **Fetch team statuses**: For each unique `team` value in the manifest, call `list_issue_statuses(team)` to get `{id, name}`.
3. **Fetch teams**: Call `list_teams` to get all teams with `{id, name}`.
4. **Build lookup maps**:
   - `labelNameToId`: Map label display name → UUID
   - `stateNameToId`: Map state display name → UUID (scoped per team)
   - `teamNameToId`: Map team display name → UUID

5. **Resolve each manifest field**:
   ```
   labels: ["type:feature", "spec:draft"]
   → labelIds: ["5da48c87-...", "52ce89a2-..."]

   state: "Backlog"
   → stateId: "50ec6d13-..."

   team: "Claudian"
   → teamId: "ee778ac4-..."
   ```

6. **Error on unresolved names**: If any symbolic name doesn't match a workspace entity, the resolution fails with a clear error message listing the unresolvable names.

### Resolution Output

The resolved output is a valid Linear `templateData` JSON string ready for `templateCreate` or `templateUpdate` GraphQL mutations. The resolution function:

- Replaces `labels` → `labelIds` (array of UUIDs)
- Replaces `state` → `stateId` (single UUID)
- Replaces `team` → `teamId` (single UUID)
- Replaces `assignee` → `assigneeId` (single UUID)
- Preserves all other fields (`title`, `priority`, `estimate`, `descriptionData`) as-is
- Serializes the result as a JSON string (Linear expects `templateData` as a string, not an object)

### Example

**Manifest input:**
```json
{
  "labels": ["type:spike", "research:needs-grounding"],
  "state": "Backlog",
  "team": "Claudian",
  "estimate": 3,
  "priority": 0
}
```

**Resolved output (for Linear API):**
```json
"{\"labelIds\":[\"cc518715-...\",\"0c1d0867-...\"],\"stateId\":\"50ec6d13-...\",\"teamId\":\"ee778ac4-...\",\"estimate\":3,\"priority\":0}"
```

## Workflow

### Bootstrapping a New Workspace

Use `/claude-command-centre:template-bootstrap` to provision a fresh workspace from zero to fully CCC-configured:

```
/ccc:template-bootstrap           # Full bootstrap: labels → templates → projects
/ccc:template-bootstrap --dry-run # Preview what would be created
/ccc:template-bootstrap --labels-only     # Only create missing labels
/ccc:template-bootstrap --templates-only  # Only create missing templates
```

The bootstrap command:
1. Creates all 29 CCC labels (idempotent — skips existing)
2. Reads each manifest file, resolves symbolic names to workspace UUIDs
3. Creates templates via `templateCreate` GraphQL mutation
4. Writes back the returned `linearId` to each manifest file
5. Creates default projects (CCC, Ideas & Prototypes)
6. Reports a summary of what was created/skipped

**Idempotent:** Safe to re-run on an already-configured workspace. Existing labels, templates, and projects are detected and skipped.

### Exporting from Linear

1. Query templates via GraphQL: `{ templates { nodes { id name type templateData description } } }`
2. Parse each template's `templateData` JSON string
3. Replace UUIDs with symbolic names using the reverse lookup maps
4. Save as `templates/{type}-{slug}.json`

### Syncing to Linear

1. Read all `templates/*.json` manifest files
2. Resolve symbolic names to UUIDs (see Label Resolution above)
3. For each manifest:
   - If `linearId` is set: `templateUpdate(id, input)` with resolved `templateData`
   - If `linearId` is null: `templateCreate(input)` and write back the new `linearId`
4. Run `template-validate` to confirm health

### Validating

Run `/claude-command-centre:template-validate` to check all templates against live workspace state. The validate command uses these manifest files as the source of truth for expected labels, estimates, and coverage.

### Recommended Workflow

For a new workspace:
```
1. /ccc:template-bootstrap              # Provision everything
2. /ccc:template-validate               # Verify health (should be 100/100)
3. git add templates/ && git commit     # Version the linearId write-backs
```

For ongoing maintenance:
```
1. Edit templates/*.json manifests      # Change template definitions
2. /ccc:template-bootstrap --templates-only  # Sync changes to Linear
3. /ccc:template-validate               # Verify no drift
4. git add templates/ && git commit     # Version the changes
```

## Project-Scoped Variants

Templates can include **variants** — project-scoped overrides that customize the base template for specific projects. Variants are defined inline in the manifest file, not as separate files.

### Why Variants?

Without variants, `spec-author` must manually assign projects and apply project-specific defaults (like `delegateId`) via if/else logic. Variants make project routing declarative:

```
User says "Build feature X for CCC"
→ spec-author detects project = CCC
→ Selects "Feature (CCC)" variant
→ Issue created with projectId, delegateId, and exec:tdd label pre-set
```

### Variant Structure

```json
{
  "name": "Feature",
  "type": "issue",
  "templateData": { "...base fields..." },
  "variants": [
    {
      "name": "Feature (CCC)",
      "project": "Claude Command Centre (CCC)",
      "overrides": {
        "delegateId": "Claude",
        "labels": ["+exec:tdd"]
      }
    },
    {
      "name": "Feature (Alteri)",
      "project": "Alteri",
      "overrides": {
        "delegateId": "Claude"
      }
    }
  ]
}
```

### Variant Fields

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `name` | Yes | string | Display name, e.g., "Feature (CCC)" |
| `project` | Yes | string | Symbolic project name. Resolved to `projectId` UUID at sync time. |
| `overrides` | No | object | templateData field overrides (see below) |

### Override Semantics

Overrides are shallow-merged with the base `templateData`:

| Override Type | Behaviour |
|---------------|-----------|
| **Scalar** (estimate, priority, state, assignee) | Replaces the base value |
| **Labels (full array)** | Replaces the base labels entirely |
| **Labels (`+` prefix)** | Adds to base labels. `["+exec:tdd"]` adds `exec:tdd` to base labels. |
| **Labels (`-` prefix)** | Removes from base labels. `["-spec:draft"]` removes `spec:draft`. |
| **Labels (mixed)** | `+` and `-` prefixed labels processed against base; unprefixed labels in the same array trigger full replacement. Do not mix prefix and non-prefix in the same array. |
| **descriptionData** | Full replacement (no deep merge of ProseMirror nodes) |
| **delegateId** | New field — sets the agent delegate for the issue |

### Resolution Algorithm

When `spec-author` or `template-sync` resolves a variant:

1. Start with a copy of the base `templateData`
2. Apply `overrides`:
   - For `labels` with `+`/`-` prefixes: process additive/removal against base labels
   - For all other fields: direct replacement
3. Add `projectId` resolved from the variant's `project` name
4. If `overrides.delegateId` is present, resolve to agent user UUID and add `delegateId`
5. Result is a complete `templateData` ready for issue creation

### Variant Selection

`spec-author` selects a variant using this algorithm:

1. Determine the target project from user context (explicit mention, CLAUDE.md routing table, or prior issues)
2. Look up the base template's `variants` array
3. Find the variant where `project` matches the target project name
4. If found: resolve and return the variant's merged templateData
5. If not found: return the base templateData with `projectId` set (fallback — project assigned, no other overrides)

### Current Variants

| Base Template | Variant | Project | Key Overrides |
|---------------|---------|---------|---------------|
| Feature | Feature (CCC) | Claude Command Centre (CCC) | `delegateId: Claude`, `+exec:tdd` |
| Feature | Feature (Alteri) | Alteri | `delegateId: Claude` |
| Bug | Bug (CCC) | Claude Command Centre (CCC) | `delegateId: Claude` |
| Bug | Bug (Alteri) | Alteri | `delegateId: Claude` |
| Spike | Spike (CCC) | Claude Command Centre (CCC) | `delegateId: Claude` |
| Spike | Spike (Alteri) | Alteri | `delegateId: Claude` |
| Chore | Chore (CCC) | Claude Command Centre (CCC) | `delegateId: Claude` |
| Chore | Chore (Alteri) | Alteri | `delegateId: Claude` |

### Adding New Variants

To add a variant for a new project:

1. Open the base template manifest (e.g., `issue-feature.json`)
2. Add an entry to the `variants` array:
   ```json
   {
     "name": "Feature (NewProject)",
     "project": "New Project Name",
     "overrides": {
       "delegateId": "Claude"
     }
   }
   ```
3. Run `template-validate` to verify the project reference resolves
4. Commit the manifest change

## File Naming Convention

```
{type}-{slug}.json
```

- `type`: `issue`, `doc`, or `project`
- `slug`: Kebab-case template name (e.g., `feature`, `prfaq-feature`, `standard`)

Examples: `issue-feature.json`, `doc-adr.json`, `project-standard.json`
