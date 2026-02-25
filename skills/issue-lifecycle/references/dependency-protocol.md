# Dependency Management Protocol (absorbed from dependency-management)

Manage issue dependency relations safely. Provides dependency detection, relation creation/removal, visualization, and auto-linking for decomposed sub-issues.

## CRITICAL SAFETY RULE: `update_issue` REPLACES Relation Arrays

> **`update_issue` `blocks`/`blockedBy`/`relatedTo` parameters REPLACE the entire existing array. They do NOT append.**
>
> Calling `update_issue(blocks: ["CIA-456"])` on an issue that already blocks `CIA-123` and `CIA-789` will **DESTROY** those existing relations, leaving only `CIA-456`.

## Mandatory Protocol: `safeUpdateRelations`

**Every** relation modification MUST use the read-merge-write protocol:

```
1. READ:  get_issue(issueId, includeRelations: true)
2. EXTRACT: current = response.relations[relationType].map(r => r.identifier)
3. MERGE:
   - If add:    merged = deduplicate(current + newRelationIds)
   - If remove: merged = current.filter(id => !newRelationIds.includes(id))
4. VALIDATE: Confirm merged array is correct (log both current and merged)
5. WRITE:  update_issue(id: issueId, [relationType]: merged)
```

**Never** call `update_issue` with `blocks`, `blockedBy`, or `relatedTo` parameters outside this protocol.

## Input Validation

All issue ID inputs MUST be validated before any operation:

| Format | Regex | Example |
|--------|-------|---------|
| Linear identifier | `/^[A-Z]+-\d+$/` | `CIA-539`, `PROJ-42` |
| UUID | `/^[a-f0-9-]+$/` | `bf865975-fc57-42ba-ba55-db9f0421b552` |

Reject invalid inputs immediately. Never pass unvalidated input to shell commands or API calls.

## Confirmation Protocol

All relation modifications require user confirmation before execution.

| Operation | Confirmation Required | Bypass with `--yes` |
|-----------|:--------------------:|:-------------------:|
| `--add` (single relation) | YES | YES |
| `--detect` (accept suggestions) | YES | YES |
| `--remove` (single relation) | ALWAYS | YES |
| Auto-relation on decompose | YES | YES |
| Read-only visualization | NO | N/A |

## Dependency Detection: `detectDependencies`

Shared utility that scans issue descriptions for dependency signals.

**Signal patterns (ordered by confidence):**

| Pattern | Type | Confidence |
|---------|------|-----------|
| `"blocks CIA-123"` | blocks | high |
| `"blocked by CIA-123"`, `"depends on CIA-123"` | blockedBy | high |
| `"related to CIA-123"` | relatedTo | high |
| `"requires CIA-123"`, `"needs CIA-123 first"` | blockedBy | high |
| `"depends on [description]"` (no ID) | blockedBy | medium |
| `"requires [description]"` (no ID) | blockedBy | medium |

**Regex for explicit ID extraction:**
```regex
/(?:blocks?|blocking|blocked\s+by|depends?\s+on|requires?|needs?|related\s+to|see\s+also|after)\s+([A-Z]+-\d+)/gi
```

## Auto-Relation on Decompose

When `/ccc:decompose` creates sub-issues:

1. Receive ordered list of sub-issues
2. Identify sequential dependencies from descriptions
3. Build proposed relations (earlier_task blocks later_task)
4. Present summary table to user for confirmation
5. Execute each relation via `safeUpdateRelations`
6. Skip relations for parallelizable tasks

## Visualization

Generate mermaid dependency graphs for milestones or issues:

| Condition | Behavior |
|-----------|----------|
| <= 30 issues | Full graph — all nodes and edges |
| > 30 issues | Truncated — top-level + first-hop, `[+N more]` nodes |
| `--full` flag | Override limit — render complete graph |

## GraphQL Fallback

MCP-native via `safeUpdateRelations` is the primary path. GraphQL is only for:
- Relation deletion (`issueRelationDelete`)
- Relation type changes (`issueRelationUpdate`)
- Advanced queries

Auth: `$LINEAR_API_KEY` (personal token). Never inline tokens.

See `graphql-relations.md` for mutation signatures and examples.

## Integration Points

| Skill/Command | Integration |
|---------------|-------------|
| `planning-preflight` | Delegates to `detectDependencies` for Step 2c/2d |
| `/ccc:decompose` | Calls auto-relation protocol after creating sub-issues |
| `/ccc:deps` | Command interface routing to dependency functions |
| `/ccc:go --next` | Reads dependency graph to find unblocked tasks |
