# DO NOT Rules

Hard-won anti-patterns from production cleanup sessions. Violating any of these causes data loss, inflated counts, or missed items.

## 1. DO NOT update labels without reading existing labels first

The Linear MCP `update_issue` with a `labels` parameter **REPLACES** the entire label array. It does not append. You must:
1. `get_issue` --> read the current labels array
2. Build the complete array: all existing labels + the new label
3. `update_issue` with the full array

Failure to do this silently drops all existing labels from the issue.

## 2. DO NOT trust `includeArchived:true` for accurate counts

Deleted issues remain in Linear's "Recently deleted" for 30 days and still appear in query results with `includeArchived: true`. Use `includeArchived: false` for accurate active issue counts. If precision matters, verify individual issue status.

## 3. DO NOT batch more than 15 issues per subagent

A full project's label migration in a single subagent will hit context limits for projects with 30+ issues (each issue requires a get + update round-trip). Split into batches of 10-15 issues per subagent, grouped by label operation type.

## 4. DO NOT skip the verification sweep

Always run a full verification pass after the main cleanup phases. In the Alteri cleanup (178 issues), the verification sweep caught 15 additional unlabeled issues, 2 deprecated labels, and 2 bracket prefixes that were missed by all prior batches. The sweep is not optional.

## 5. DO NOT assume migration batches are exhaustive

Issues can be missed by batch queries due to pagination edge cases, status filters, or archival state. The Alteri session had 4 issues that appeared in none of the migration batches and were only found during verification. Always cross-check against the full issue list.

## 6. DO NOT create issues for reference-only content

Research notes, literature reviews, methodology decisions, session learnings -- these are Documents, not issues. They have no "done" state. Creating them as issues bloats the tracker and makes triage noisy. Use the Content Classification Matrix in the parent SKILL.md.

## 7. DO NOT use Linear MCP for deletion

The Linear MCP tool set does not include a delete operation. Deletion requires a GraphQL mutation via the Linear API: `mutation { issueDelete(id: "UUID") { success } }`. Execute via the `query.ts` script or a direct API call with the `LINEAR_API_KEY`.

## 8. DO NOT modify priority, due dates, or cycle assignment during cleanup

These are human-owned fields per the ownership model (see `issue-lifecycle` skill). Cleanup touches: titles, labels, descriptions, project assignment, and status. It does not touch: priority, due dates, cycle/sprint assignment, or assignee (unless routing unassigned issues).

## 9. DO NOT publish README without ship-state verification

Before publishing any README or documentation that claims files, skills, or commands exist:

1. Run `ls` to verify every claimed file actually exists
2. Compare documented counts against actual file counts
3. Remove or mark as "planned" any items that don't yet have implementations

The Alteri cleanup (Feb 10 2026) discovered README claims of 11 skills and 8 commands when only 7 and 6 existed, respectively. Four Linear issues (CIA-293/294/295/296) were marked "Done" but their files never shipped.

## 10. DO NOT write skill/command descriptions without NL activation clauses

Every SKILL.md and command file must include natural language trigger phrases in the `description` field:

```yaml
description: |
  What the skill does...
  Use when [conditions]...
  Trigger with phrases like "phrase 1", "phrase 2", "phrase 3".
```

Without these clauses, skill matching relevance drops from ~90% to ~30% (Plugin Ecosystem Audit, Feb 9 2026).
