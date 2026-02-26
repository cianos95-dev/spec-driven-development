# Linear GraphQL Patterns (MCP Gaps)

> **Created:** 26 Feb 2026
> **Issue:** CIA-745
> **Sources:** CIA-537 (project updates), CIA-539 (dependency management), CIA-571 (velocity), CIA-705 (dispatch server)

The Linear MCP covers most operations. This reference documents patterns that **require direct GraphQL** because the MCP has no equivalent tool.

## Auth Rule

**GraphQL mutations require `$LINEAR_API_KEY` (`lin_api_*`), NOT OAuth tokens.**

The MCP uses OAuth (agent token `dd0797a4`). Direct GraphQL calls use the personal API key from Keychain:

```bash
LINEAR_KEY=$(security find-generic-password -s "claude/linear-api-key" -w)
curl -s -X POST https://api.linear.app/graphql \
  -H "Authorization: $LINEAR_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query": "mutation { ... }"}'
```

OAuth tokens work for reads but mutations on some endpoints require the API key.

---

## 1. Document Delete

**MCP gap:** No `delete_document` tool. MCP only has `create_document`, `update_document`, `get_document`, `list_documents`.

**GraphQL:**
```graphql
mutation {
  documentDelete(id: "document-uuid") {
    success
  }
}
```

**Use case:** Cleaning up archived/stale documents from project Resources. Batch deletion:
```bash
LINEAR_KEY=$(security find-generic-password -s "claude/linear-api-key" -w)
for id in "uuid1" "uuid2" "uuid3"; do
  curl -s -X POST https://api.linear.app/graphql \
    -H "Authorization: $LINEAR_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"query\": \"mutation { documentDelete(id: \\\"$id\\\") { success } }\"}"
done
```

**Discovered:** 26 Feb 2026. Used to delete 34 archived CCC documents.

---

## 2. Project Status Updates

**MCP gap:** `status-update` skill uses `projectUpdateCreate` / `projectUpdateDelete` via GraphQL. MCP only supports initiative updates natively.

**GraphQL:**
```graphql
mutation {
  projectUpdateCreate(input: {
    projectId: "project-uuid"
    body: "## Weekly Update\n\nProgress summary..."
    health: onTrack
  }) {
    projectUpdate { id url }
  }
}
```

Health values: `onTrack`, `atRisk`, `offTrack`.

**Source:** CIA-537

---

## 3. Issue Relation Delete

**MCP gap:** MCP `save_issue` replaces the entire relation array. To delete a single relation without affecting others, use GraphQL.

**GraphQL:**
```graphql
mutation {
  issueRelationDelete(id: "relation-uuid") {
    success
  }
}
```

To find the relation ID, query the issue's relations first:
```graphql
query {
  issue(id: "issue-uuid") {
    relations { nodes { id type relatedIssue { identifier } } }
  }
}
```

**Source:** CIA-539

---

## 4. Velocity Queries

**MCP gap:** No cycle scope/velocity data available through MCP tools.

**GraphQL:**
```graphql
query {
  cycles(filter: { team: { key: { eq: "CIA" } } }, first: 5) {
    nodes {
      id name number
      startsAt endsAt
      scopeHistory
      completedScopeHistory
      issues { nodes { identifier estimate { value } completedAt } }
    }
  }
}
```

`scopeHistory` and `completedScopeHistory` are arrays of daily snapshots — useful for burn-down charts and velocity estimation.

**Source:** CIA-571

---

## 5. Issue History (Audit Trail)

**MCP gap:** No issue history/changelog available through MCP.

**GraphQL:**
```graphql
query {
  issueHistory(issueId: "issue-uuid", first: 20) {
    nodes {
      id createdAt
      fromState { name } toState { name }
      fromAssignee { name } toAssignee { name }
      actor { name }
    }
  }
}
```

Useful for: tracking status transition times, identifying bottlenecks, audit trails.

**Source:** CIA-571

---

## 6. Hook-Driven Writes via Dispatch Server

**MCP gap:** Claude Code hooks can't make HTTP calls to Linear directly. The dispatch server (CIA-705) provides a `/linear-update` route for hook-driven Linear writes.

**Architecture:**
```
Hook script → HTTP POST to localhost:PORT/linear-update → GraphQL mutation → Linear API
```

Currently deferred — dispatch server not yet deployed. Hooks that need Linear writes currently use the MCP tools within the session context.

**Source:** CIA-705

---

## Cross-References

| Skill | Uses GraphQL For |
|-------|-----------------|
| `status-update` | `projectUpdateCreate`, `projectUpdateDelete` |
| `template-sync` | Template CRUD via GraphQL (MCP has no template tools) |
| `template-validate` | Template queries (read-only) |
| `milestone-forecast` | Cycle velocity queries |
| `document-lifecycle` | `documentDelete` (cleanup) |
