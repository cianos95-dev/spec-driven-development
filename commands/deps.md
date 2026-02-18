---
description: |
  Manage and visualize issue dependency relations. View dependencies for an issue,
  generate milestone dependency graphs, add/remove relations safely, and detect
  implicit dependencies from descriptions.
  Use for dependency management, relation creation, blocker visualization,
  and dependency detection.
  Trigger with phrases like "show dependencies", "add blocker", "dependency graph",
  "what blocks this", "detect dependencies", "remove relation", "milestone graph".
argument-hint: "<issue ID | --milestone \"name\" | --add SRC TYPE TGT | --remove SRC TYPE TGT | --detect ID> [--yes] [--full] [--verbose]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
platforms: [cli, cowork]
---

# Deps -- Dependency Relation Manager

Unified command for viewing, creating, removing, and detecting issue dependency relations. All relation modifications use the `safeUpdateRelations` wrapper from the `dependency-management` skill to prevent accidental data loss.

## Modes

This command supports 5 modes. Each mode is documented with usage, expected output, and error scenarios.

---

### Mode 1: View Issue Dependencies

**Usage:** `/ccc:deps CIA-123`

Show all dependency relations for a single issue.

**Steps:**

1. Validate the issue ID (C2: must match `/^[A-Z]+-\d+$/` or `/^[a-f0-9-]+$/`)
2. Call `get_issue(id, includeRelations: true)`
3. Format and display relations

**Expected output:**

```
Dependencies for CIA-539 — "Build dependency-management skill and command"

Blocks:
  → CIA-540: Wire new skills into existing CCC skills
  → CIA-541: Extend hygiene command with milestone, document, and dependency checks

Blocked by:
  (none)

Related to:
  ↔ CIA-537: Build project-status-update skill and command
  ↔ CIA-536: Build milestone-management skill
```

**Error scenarios:**

| Error | Cause | Output |
|-------|-------|--------|
| Invalid ID format | Input fails regex validation | `Error: Invalid issue ID "abc!@#". Must be "ABC-123" or UUID format.` |
| Issue not found | ID is valid but does not exist | `Error: Issue "CIA-999" not found.` |
| No relations | Issue has no dependency relations | `CIA-123 has no dependency relations.` |

---

### Mode 2: Milestone Dependency Graph

**Usage:** `/ccc:deps --milestone "Linear Mastery"` or `/ccc:deps --milestone "Linear Mastery" --full`

Generate a mermaid dependency graph for all issues in a milestone.

**Steps:**

1. Fetch all issues in the named milestone (delegate to subagent if >10 issues)
2. For each issue, extract relations from `get_issue(includeRelations: true)`
3. Build adjacency list
4. Apply scale limits (I4):
   - <= 30 nodes: full graph
   - \> 30 nodes (no `--full`): truncate to root nodes + first-hop, add `[+N more]` placeholder
   - \> 30 nodes with `--full`: render complete graph (warn about size)
5. Generate mermaid syntax with status-based styling
6. Output the graph

**Expected output:**

```
Dependency graph for milestone "Linear Mastery" (6 issues)

​```mermaid
graph LR
  CIA-536[Build milestone skill] --> CIA-540[Wire into existing skills]
  CIA-537[Build status update] --> CIA-540
  CIA-538[Build document lifecycle] --> CIA-540
  CIA-539[Build dependency mgmt] --> CIA-540
  CIA-539 --> CIA-541[Extend hygiene command]

  style CIA-536 fill:#90EE90
  style CIA-537 fill:#FFD700
​```

Legend: Green = Done | Yellow = In Progress | Default = Todo/Backlog | Red border = Blocked
```

**Truncated output (>30 nodes, no `--full`):**

```
Dependency graph for milestone "Q1 Release" (47 issues, showing 30 + summary)

​```mermaid
graph LR
  ...first 30 nodes...
  MORE["+17 more issues"] -.-> HUB_NODE

  style MORE fill:#eee,stroke:#999,stroke-dasharray: 5 5
​```

Use `/ccc:deps --milestone "Q1 Release" --full` to see all 47 nodes.
```

**Error scenarios:**

| Error | Cause | Output |
|-------|-------|--------|
| Milestone not found | Name does not match any milestone | `Error: Milestone "Unknown" not found. Available milestones: [list]` |
| Empty milestone | Milestone has no issues | `Milestone "Linear Mastery" has no issues.` |
| No relations in milestone | Issues exist but none have relations | `No dependency relations found in milestone "Linear Mastery". All issues are independent.` |

---

### Mode 3: Add Relation

**Usage:** `/ccc:deps --add CIA-123 blocks CIA-456` or `/ccc:deps --add CIA-123 blocks CIA-456 --yes`

Create a dependency relation between two issues using the `safeUpdateRelations` wrapper.

**Steps:**

1. Parse arguments: `sourceId`, `relationType`, `targetId`
2. Validate both IDs (C2)
3. Validate `relationType` is one of: `blocks`, `blockedBy`, `relatedTo`, `duplicateOf`
4. Show confirmation prompt (C3) — skip if `--yes` flag is set:
   ```
   Proposed change:
     CIA-123 --[blocks]--> CIA-456

   Current relations for CIA-123:
     blocks: CIA-789
     blockedBy: (none)

   After change:
     blocks: CIA-789, CIA-456

   Proceed? [y/N]
   ```
5. Execute via `safeUpdateRelations(sourceId, relationType, [targetId], "add")`
   - Read current relations
   - Merge new relation
   - Write merged array
6. On MCP failure: fall back to GraphQL `issueRelationCreate`
7. Report result

**Expected output (success):**

```
Relation created: CIA-123 --[blocks]--> CIA-456
```

**Expected output (already exists):**

```
Relation already exists: CIA-123 --[blocks]--> CIA-456. No change needed.
```

**Error scenarios:**

| Error | Cause | Output |
|-------|-------|--------|
| Invalid ID | Source or target fails validation | `Error: Invalid issue ID "bad-id!".` |
| Invalid relation type | Type not in allowed set | `Error: Invalid relation type "requires". Must be: blocks, blockedBy, relatedTo, duplicateOf.` |
| Issue not found | Valid ID but issue doesn't exist | `Error: Issue "CIA-999" not found.` |
| Self-reference | Source == Target | `Error: Cannot create relation from CIA-123 to itself.` |
| User declined | User answered N to confirmation | `Aborted. No relations changed.` |

---

### Mode 4: Remove Relation

**Usage:** `/ccc:deps --remove CIA-123 blocks CIA-456` or `/ccc:deps --remove CIA-123 blocks CIA-456 --yes`

Remove a dependency relation. Always requires confirmation (destructive operation).

**Steps:**

1. Parse arguments: `sourceId`, `relationType`, `targetId`
2. Validate both IDs (C2)
3. Verify the relation exists: `get_issue(sourceId, includeRelations: true)`
4. If relation does not exist, report and exit
5. Show confirmation prompt (C3) — `--remove` always confirms unless `--yes`:
   ```
   Remove relation:
     CIA-123 --[blocks]--> CIA-456

   Current relations for CIA-123:
     blocks: CIA-456, CIA-789

   After removal:
     blocks: CIA-789

   This is a destructive operation. Proceed? [y/N]
   ```
6. Execute via `safeUpdateRelations(sourceId, relationType, [targetId], "remove")`
   - If MCP-native removal is insufficient (e.g., `duplicateOf`): fall back to GraphQL `issueRelationDelete`
7. Report result

**Expected output (success):**

```
Relation removed: CIA-123 --[blocks]--> CIA-456
```

**Error scenarios:**

| Error | Cause | Output |
|-------|-------|--------|
| Relation not found | The specified relation does not exist | `No "blocks" relation found from CIA-123 to CIA-456. Nothing to remove.` |
| User declined | User answered N to confirmation | `Aborted. No relations changed.` |
| GraphQL fallback failed | `issueRelationDelete` error | `Error: Relation removal failed.` (verbose: include GraphQL error) |

---

### Mode 5: Detect Dependencies

**Usage:** `/ccc:deps --detect CIA-123` or `/ccc:deps --detect CIA-123 --yes`

Analyze an issue's description for implicit dependency signals and suggest relations.

**Steps:**

1. Validate the issue ID (C2)
2. Fetch the issue: `get_issue(id)`
3. Fetch sibling issues in the same project/milestone for cross-referencing
4. Run `detectDependencies(description, siblingIds)` (shared utility from the skill)
5. Present suggestions grouped by confidence

**Expected output:**

```
Dependency detection for CIA-502 — "Build API endpoints"

Detected signals (3 total):

HIGH confidence:
  blockedBy CIA-501 — "depends on CIA-501" found in description
  blocks CIA-504 — "CIA-504 requires this" found in description

MEDIUM confidence:
  blockedBy CIA-500 — description mentions "database schema" which matches CIA-500 title

Accept suggestions?
  [1] Accept all (3 relations)
  [2] Accept high confidence only (2 relations)
  [3] Review individually
  [4] Cancel
```

If the user accepts suggestions, execute via `safeUpdateRelations` with the confirmation protocol (C3). With `--yes`, accept all suggestions without prompting.

**Expected output (no signals):**

```
No dependency signals detected in CIA-502's description.
```

**Error scenarios:**

| Error | Cause | Output |
|-------|-------|--------|
| No description | Issue has no description text | `CIA-123 has no description to analyze.` |
| No sibling issues | No issues in same project for cross-referencing | `Detection ran in standalone mode (no sibling issues for cross-referencing). Only explicit ID references can be detected.` |

---

## Global Flags

| Flag | Effect | Applies To |
|------|--------|-----------|
| `--yes` | Skip confirmation prompts | `--add`, `--remove`, `--detect` |
| `--full` | Disable 30-node graph limit | `--milestone` |
| `--verbose` | Show backend-specific errors and debug info | All modes |

## Cross-Reference

- **Skill:** `skills/dependency-management/SKILL.md` — `safeUpdateRelations` wrapper, `detectDependencies` utility, DO NOT rule (C1)
- **GraphQL reference:** `skills/dependency-management/references/graphql-relations.md` — fallback mutations
- **Related commands:** `/ccc:decompose` (auto-relations), `/ccc:go --next` (consumes dependency data), `/ccc:hygiene` (dependency health audits)
