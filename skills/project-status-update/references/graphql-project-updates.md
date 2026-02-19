# GraphQL Project Updates Reference

GraphQL mutations for Linear project status updates. The MCP `save_status_update` tool only supports `type: "initiative"` — project-level updates require direct GraphQL calls.

## Authentication

All GraphQL requests MUST use the `$LINEAR_API_KEY` environment variable (personal `lin_api_*` token). The OAuth agent token (`$LINEAR_AGENT_TOKEN` / `lin_oauth_*`) returns 401 for project update mutations.

```bash
# Correct — personal API key
curl -s -X POST https://api.linear.app/graphql \
  -H "Content-Type: application/json" \
  -H "Authorization: $LINEAR_API_KEY" \
  -d '{"query": "..."}'
```

```bash
# WRONG — OAuth agent token (returns 401 for project updates)
curl -s -X POST https://api.linear.app/graphql \
  -H "Authorization: $LINEAR_AGENT_TOKEN"
```

For Node.js scripts:

```javascript
// Correct — reads personal API key from environment
const headers = {
  'Content-Type': 'application/json',
  'Authorization': process.env.LINEAR_API_KEY
};
```

## Input Validation

Before constructing any GraphQL query, validate project UUID inputs:

```javascript
function validateUuid(input) {
  if (/^[a-f0-9-]{36}$/.test(input)) return true;
  throw new Error(`Invalid UUID: "${input}". Must be UUID format.`);
}
```

**Always validate before string interpolation in queries.** This prevents injection attacks via malicious inputs.

## Mutations

### `projectUpdateCreate`

Creates a new project status update. Appears in the project's Updates tab and feeds into Pulse/Reviews.

```graphql
mutation ProjectUpdateCreate($input: ProjectUpdateCreateInput!) {
  projectUpdateCreate(input: $input) {
    success
    projectUpdate {
      id
      body
      health
      createdAt
      url
      project {
        id
        name
      }
    }
  }
}
```

**Variables:**

```json
{
  "input": {
    "projectId": "<project-uuid>",
    "body": "## Progress\n- CIA-537: Shipped project-status-update skill\n\n## Next\n- Wire into session-exit",
    "health": "onTrack"
  }
}
```

**Health enum values:** `onTrack` | `atRisk` | `offTrack`

**Shell invocation example:**

```bash
node --input-type=module << 'ENDSCRIPT'
const projectId = "bafaec20-c4fa-4a64-9ad5-5c44ecf6a460";  // Validated UUID

if (!/^[a-f0-9-]+$/.test(projectId)) {
  console.error("Invalid project ID format");
  process.exit(1);
}

const body = `**Health:** On Track

## Progress
- CIA-537: Shipped project-status-update skill and command
- CIA-549: Spike completed — MCP limitation confirmed

## Next
- Wire into session-exit Step 4

Posted by Claude agent | Session: 2026-02-19`;

const query = `
  mutation {
    projectUpdateCreate(input: {
      projectId: "${projectId}",
      body: ${JSON.stringify(body)},
      health: onTrack
    }) {
      success
      projectUpdate { id url health createdAt }
    }
  }
`;

const res = await fetch('https://api.linear.app/graphql', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': process.env.LINEAR_API_KEY
  },
  body: JSON.stringify({ query })
});

const data = await res.json();
if (data.errors) {
  console.error("GraphQL error:", JSON.stringify(data.errors));
  process.exit(1);
}
console.log("Update created:", JSON.stringify(data.data.projectUpdateCreate));
ENDSCRIPT
```

### `projectUpdateUpdate`

Amends an existing project update. Used for same-day deduplication.

```graphql
mutation ProjectUpdateUpdate($id: String!, $input: ProjectUpdateUpdateInput!) {
  projectUpdateUpdate(id: $id, input: $input) {
    success
    projectUpdate {
      id
      body
      health
      updatedAt
    }
  }
}
```

**Variables:**

```json
{
  "id": "<project-update-uuid>",
  "input": {
    "body": "Updated body content...",
    "health": "atRisk"
  }
}
```

### `projectUpdateDelete`

Deletes a project update. Use for removing bad or accidental updates.

```graphql
mutation ProjectUpdateDelete($id: String!) {
  projectUpdateDelete(id: $id) {
    success
  }
}
```

**Variables:**

```json
{
  "id": "<project-update-uuid>"
}
```

## Queries

### Fetch existing same-day project updates (dedup check)

```graphql
query ProjectUpdates($projectId: ID!, $since: DateTime!) {
  projectUpdates(
    filter: {
      project: { id: { eq: $projectId } }
      createdAt: { gte: $since }
    }
    first: 1
    orderBy: createdAt
  ) {
    nodes {
      id
      body
      health
      createdAt
      url
    }
  }
}
```

**Variables:**

```json
{
  "projectId": "<project-uuid>",
  "since": "2026-02-19T00:00:00Z"
}
```

### Fetch latest project update (for --edit / --delete)

```graphql
query LatestProjectUpdate($projectId: ID!) {
  projectUpdates(
    filter: {
      project: { id: { eq: $projectId } }
    }
    first: 1
    orderBy: createdAt
  ) {
    nodes {
      id
      body
      health
      createdAt
      url
    }
  }
}
```

## Error Handling

| Error | Cause | Resolution |
|-------|-------|------------|
| `Entity not found` | Project UUID does not exist | Verify via `get_project` MCP call first |
| `Unauthorized` (401) | Using OAuth token instead of API key | Switch to `$LINEAR_API_KEY` |
| `Rate limited` | Too many requests | Wait and retry with exponential backoff |
| `Invalid input` | Malformed body or invalid health enum | Validate inputs before sending |

**Best-effort principle:** When GraphQL is called during session-exit, surface errors as warnings only. Never block session exit on a project update failure.

## UUID Resolution

GraphQL mutations require project UUIDs, not names. To resolve:

1. **Preferred:** Use MCP `get_project(name: "Claude Command Centre (CCC)")` — returns the project UUID in the `id` field.
2. **Fallback:** GraphQL query:

```graphql
query ResolveProject($name: String!) {
  projects(filter: { name: { containsIgnoreCase: $name } }, first: 1) {
    nodes {
      id
      name
    }
  }
}
```

## Cross-Reference

- **Main skill:** `skills/project-status-update/SKILL.md` — two-tier architecture, status generation algorithm, sensitivity filtering
- **Command:** `commands/status-update.md` — user-facing command with dry-run, post, edit, delete modes
- **Dependency management GraphQL:** `skills/dependency-management/references/graphql-relations.md` — similar pattern for issue relations
- **Spike results:** CIA-549 — confirmed MCP limitation and tested GraphQL path
