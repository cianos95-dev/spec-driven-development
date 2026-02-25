# GraphQL Relations Reference

GraphQL mutations for Linear issue relations. Used as a fallback when MCP-native relation management is insufficient (relation deletion, relation type changes, advanced queries).

**Primary path is MCP-native** (via `safeUpdateRelations` in the skill). Use GraphQL only when MCP cannot perform the operation.

## Authentication (I6)

All GraphQL requests MUST use the `$LINEAR_API_KEY` environment variable (personal `lin_api_*` token). The OAuth agent token (`$LINEAR_AGENT_TOKEN` / `lin_oauth_*`) returns 401 for many GraphQL mutations. Never inline tokens.

```bash
# Correct — personal API key via env var
curl -s -X POST https://api.linear.app/graphql \
  -H "Content-Type: application/json" \
  -H "Authorization: $LINEAR_API_KEY" \
  -d '{"query": "..."}'
```

```bash
# WRONG — token inlined (NEVER do this)
curl -s -X POST https://api.linear.app/graphql \
  -H "Authorization: lin_oauth_f0915e10..."
```

For Node.js scripts:

```javascript
// Correct — reads from environment
const headers = {
  'Content-Type': 'application/json',
  'Authorization': process.env.LINEAR_API_KEY
};
```

## Input Validation (C2)

Before constructing any GraphQL query, validate all issue ID inputs:

```javascript
function validateIssueId(input) {
  if (/^[A-Z]+-\d+$/.test(input)) return { valid: true, format: 'identifier' };
  if (/^[a-f0-9-]+$/.test(input)) return { valid: true, format: 'uuid' };
  throw new Error(`Invalid issue ID: "${input}". Must be "ABC-123" or UUID format.`);
}
```

**Always validate before string interpolation in queries.** This prevents injection attacks via malicious issue ID inputs.

## Relation Types

Linear supports these relation types in the `IssueRelationType` enum:

| Type | Meaning | Inverse |
|------|---------|---------|
| `blocks` | Source blocks target | Target is `blockedBy` source |
| `duplicate` | Source duplicates target | Target is `duplicateOf` source |
| `related` | Bidirectional relation | Same |

Note: `blockedBy` is not a separate GraphQL type — it is the inverse of `blocks`. To create "A blockedBy B", create "B blocks A".

## Mutations

### `issueRelationCreate`

Creates a new relation between two issues.

```graphql
mutation IssueRelationCreate($input: IssueRelationCreateInput!) {
  issueRelationCreate(input: $input) {
    success
    issueRelation {
      id
      type
      issue {
        id
        identifier
        title
      }
      relatedIssue {
        id
        identifier
        title
      }
    }
  }
}
```

**Variables:**

```json
{
  "input": {
    "issueId": "<source-issue-uuid>",
    "relatedIssueId": "<target-issue-uuid>",
    "type": "blocks"
  }
}
```

**Shell invocation example:**

```bash
node --input-type=module << 'ENDSCRIPT'
const issueId = "bf865975-fc57-42ba-ba55-db9f0421b552";    // Validated UUID
const relatedId = "7e0cc04f-202a-4de9-9eef-d7e71902093c";  // Validated UUID

// Validate inputs before use
if (!/^[a-f0-9-]+$/.test(issueId) || !/^[a-f0-9-]+$/.test(relatedId)) {
  console.error("Invalid issue ID format");
  process.exit(1);
}

const query = `
  mutation {
    issueRelationCreate(input: {
      issueId: "${issueId}",
      relatedIssueId: "${relatedId}",
      type: blocks
    }) {
      success
      issueRelation { id type }
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
console.log("Relation created:", JSON.stringify(data.data.issueRelationCreate));
ENDSCRIPT
```

### `issueRelationUpdate`

Updates an existing relation (e.g., change type from `related` to `blocks`).

```graphql
mutation IssueRelationUpdate($id: String!, $input: IssueRelationUpdateInput!) {
  issueRelationUpdate(id: $id, input: $input) {
    success
    issueRelation {
      id
      type
      issue {
        identifier
      }
      relatedIssue {
        identifier
      }
    }
  }
}
```

**Variables:**

```json
{
  "id": "<relation-uuid>",
  "input": {
    "type": "blocks"
  }
}
```

**Note:** You need the relation UUID, not the issue UUID. Obtain it from `issueRelationCreate` response or by querying the issue's relations.

### `issueRelationDelete`

Deletes an existing relation. **Required for `--remove` operations** when `safeUpdateRelations` (MCP-native) is insufficient.

```graphql
mutation IssueRelationDelete($id: String!) {
  issueRelationDelete(id: $id) {
    success
  }
}
```

**Variables:**

```json
{
  "id": "<relation-uuid>"
}
```

**Finding the relation UUID:**

To delete a specific relation, first query the issue to find the relation ID:

```graphql
query IssueRelations($id: String!) {
  issue(id: $id) {
    relations {
      nodes {
        id
        type
        relatedIssue {
          id
          identifier
          title
        }
      }
    }
    inverseRelations {
      nodes {
        id
        type
        issue {
          id
          identifier
          title
        }
      }
    }
  }
}
```

**Shell invocation for relation deletion:**

```bash
node --input-type=module << 'ENDSCRIPT'
const relationId = "abc12345-1234-5678-abcd-1234567890ab";  // Validated UUID

if (!/^[a-f0-9-]+$/.test(relationId)) {
  console.error("Invalid relation ID format");
  process.exit(1);
}

const query = `
  mutation {
    issueRelationDelete(id: "${relationId}") {
      success
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
console.log("Relation deleted:", data.data.issueRelationDelete.success);
ENDSCRIPT
```

## Error Handling

| Error | Cause | Resolution |
|-------|-------|------------|
| `Entity not found` | Issue UUID does not exist | Verify the issue exists; may need to resolve identifier → UUID first |
| `Relation already exists` | Duplicate relation | Skip silently — the relation is already in place |
| `Unauthorized` | Token invalid or expired | Check `$LINEAR_API_KEY` is set and valid. OAuth token (`$LINEAR_AGENT_TOKEN`) returns 401 for many mutations. |
| `Rate limited` | Too many requests | Wait and retry with exponential backoff |

**Unified interface (I5):** When GraphQL is used as a fallback, surface these errors only in verbose/debug mode. In normal mode, the user sees: "Relation creation failed. Use `--verbose` for details."

## Identifier-to-UUID Resolution

GraphQL mutations require UUIDs, not identifiers like `CIA-539`. To resolve:

```graphql
query ResolveIdentifier($filter: IssueFilter!) {
  issues(filter: $filter) {
    nodes {
      id
      identifier
    }
  }
}
```

With variables:

```json
{
  "filter": {
    "team": { "key": { "eq": "CIA" } },
    "number": { "eq": 539 }
  }
}
```

**Note:** The MCP's `get_issue` accepts identifiers directly and returns the UUID in the `id` field. Prefer MCP for resolution when possible.

## Cross-Reference

- **Main skill:** `skills/issue-lifecycle/SKILL.md` (Dependencies section) — `safeUpdateRelations` wrapper, detection utility, confirmation protocol
- **Command:** `commands/deps.md` — user-facing command with 5 modes
- **Linear API patterns:** `~/.claude/skills/linear/api.md` — general GraphQL patterns, timeout handling, shell compatibility notes
