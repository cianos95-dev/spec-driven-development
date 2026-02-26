---
name: issue-lifecycle-ownership
description: |
  Unified issue and project lifecycle management. Defines agent/human ownership boundaries, closure rules,
  session hygiene, spec lifecycle, project maintenance, status updates, and dependency management.
  Use when determining what the agent can change vs what requires human approval, closing issues, updating
  issue status, managing labels, handling session-end cleanup, maintaining project descriptions, posting
  project updates, managing project resources, cleaning up projects, posting status updates, managing
  dependencies between issues, detecting duplicates, or performing bulk operations.
  Trigger with phrases like "can I close this issue", "who owns priority", "issue ownership rules",
  "session cleanup protocol", "what labels should I set", "closure evidence requirements",
  "project description stale", "post project update", "add resource to project", "update project summary",
  "clean up this project", "normalize project issues", "apply CCC conventions", "post status update",
  "project health", "initiative update", "add dependency", "blocks", "blocked by", "dependency graph",
  "detect dependencies", "link issues", "show blockers", "duplicate issues", "bulk update".
compatibility:
  surfaces: [code, cowork]
  tier: degraded-cowork
  degradation_notes: "Linear ownership rules and MCP operations work in Cowork; hooks, file-system operations, and GraphQL project updates require Code"
---

# Issue Lifecycle Ownership

AI agents and humans have complementary strengths in issue management. This skill defines clear ownership boundaries so the agent acts autonomously where appropriate and defers where human judgement is required.

## Core Principle

The agent owns **process and implementation artifacts** (status, labels, specs, estimates). The human owns **business judgement** (priority, deadlines, capacity). Either can create and assign work. Closure follows a rules matrix based on assignee and complexity.

> See [references/ownership-matrix.md](references/ownership-matrix.md) for the full ownership table, session hygiene rules, and re-open protocol.

## Session Naming for Traceability

Every working session should be named to link it to the issue being worked on. Use `/rename CIA-XXX: <short title>` at session start. This makes plan files traceable to their originating issue and provides provenance when plans are promoted to Linear Documents. The `/ccc:go` command auto-renames the session when loading an issue.

## Closure Rules

Closure is the highest-stakes status transition. The canonical closure matrix — including all AUTO-CLOSE, PROPOSE, and BLOCK conditions, quality gate thresholds, conflict resolution, and recovery commands — lives in `references/closure-rules.md`.

The `/close` command is the **universal entry point** for all closure. It applies the closure rules, computes the quality score, and executes the appropriate action. **Every Done transition requires a closing comment** with evidence per `references/evidence-mandate.md`.

## Spec Lifecycle Labels

| Label | State | Description |
|-------|-------|-------------|
| `spec:draft` | Authoring | Initial spec being written. May be incomplete. |
| `spec:ready` | Review-ready | Spec complete enough for adversarial review. |
| `spec:review` | Under review | Adversarial review in progress. |
| `spec:implementing` | In development | Spec passed review, implementation begun. |
| `spec:complete` | Delivered | Implementation matches spec. Acceptance criteria met. |

**Transition rules:** `draft` → `ready` (agent/human asserts completeness) → `review` (reviewer begins) → `implementing` (review passes) → `complete` (ACs verified). Review can return to `draft` if fundamental gaps found. Spec labels coexist with execution mode labels.

## Execution Context Labels (`ctx:*`)

Track the current execution surface for an issue. Exactly one `ctx:*` label at any time — replace on context transitions. Apply only to Todo, In Progress, and In Review issues. Remove on Done/Canceled.

| Label | When to Apply |
|-------|--------------|
| `ctx:interactive` | Human-present session starts work (Code, Cursor, Cowork, Desktop) |
| `ctx:autonomous` | Issue dispatched to Factory, Codex, Amp, cto.new, or any background agent |
| `ctx:review` | Issue enters automated review (Copilot auto-review, Vercel deploy preview) |
| `ctx:human` | Human working without AI assistance |

**Transition rule:** When an issue moves between contexts (e.g., Factory fails → Claude Code picks up), remove the old `ctx:*` label and apply the new one. Post a comment documenting the transition. History preserved via Linear activity log.

**Mid-session rule:** Apply `ctx:interactive` as soon as marking In Progress in a human-present session. For autonomous dispatch, apply `ctx:autonomous` before dispatching the subagent.

## Issue Naming Convention

Issue titles start with an action verb, lowercase after first word. No bracket prefixes.

**Common verb starters:** Build, Implement, Fix, Add, Create, Evaluate, Survey, Design, Migrate, Configure, Audit, Ship, Set up, Wire up

Non-actionable content (research notes, decisions, session learnings) should be Linear Documents, not issues. Apply the "Can someone mark this Done?" test.

## Carry-Forward Items Protocol

When adversarial review findings or implementation tasks cannot be resolved within the current issue's scope:

1. **Create a new issue** for each carry-forward item
2. **Link** as "related to" the source issue
3. **Reference the source** in the new issue description
4. **Add** to the fix-forward summary in the source issue's closing comment
5. **Apply appropriate labels** to the new issue

Never leave findings untracked, close without documenting deferrals, or add carry-forward items to the source issue's scope.

## Sub-Issue Creation and Dependency Wiring

When `/ccc:decompose` creates sub-issues under a parent, the dependency protocol is invoked to wire sequential relations. See the Dependencies section below and [references/dependency-protocol.md](references/dependency-protocol.md) for the `safeUpdateRelations` protocol.

## Project Creation and Document Bootstrap

When a new project is created (or an existing project has no structural documents), invoke the **document-lifecycle** skill to bootstrap required documents. Check `list_documents(project)` for "Key Resources" and "Decision Log" after issue creation. Respect `<!-- no-auto-docs -->` opt-out.

## Linear-Specific Operations

> See [references/linear-operations.md](references/linear-operations.md) for the full Linear operational guidance including triage, cycles, initiatives, templates, estimates, agent delegation, and customer feedback routing.

> See [references/project-hygiene.md](references/project-hygiene.md) for the project hygiene protocol including artifact cadence, description structure, staleness detection, daily update format, and resource management.

> See [references/content-discipline.md](references/content-discipline.md) for issue content discipline rules, anti-patterns, master session plan pattern, and scope limitation handoff protocol.

---

## Maintenance (absorbed from project-cleanup)

One-time structural normalization of a project's issues, documents, and metadata. Distinct from ongoing hygiene (`/ccc:hygiene`) and day-to-day lifecycle ownership.

**When to use:** Convention debt accumulated (bracket prefixes, missing type labels), non-actionable content stored as issues, onboarding a project to CCC conventions, reclaiming tracker slots.

**Core protocol:** Audit → Delete non-actionable → Convert to Documents → Rename (verb-first) → Relabel (`type:*`) → Create structural documents → Verify. Process in batches of 10-15 per subagent.

**Content classification:** Apply the "Can someone mark this Done?" test. If yes → issue. If no → document (with category prefix: `Research:`, `Decision:`, `Session:`, `Template:`).

**Type labels:** Every issue MUST have exactly one `type:*` label: `type:feature`, `type:bug`, `type:chore`, or `type:spike`. Assignment heuristic: Build/Implement → feature, Fix/Resolve → bug, Configure/Migrate → chore, Evaluate/Survey → spike.

> See [references/maintenance-protocol.md](references/maintenance-protocol.md) for the full content classification matrix, type label taxonomy, deprecated label migration table, deletion protocol, and execution phases.

> See [references/do-not-rules.md](references/do-not-rules.md) for 10 hard-won anti-patterns from production cleanup sessions.

---

## Status Updates (absorbed from project-status-update)

Post automated status updates for projects and initiatives in Linear using a two-tier architecture.

**Tier 1 — Initiative updates (MCP native):** `save_status_update(type: "initiative", ...)`. Monday roll-ups or on-demand.

**Tier 2 — Project updates (GraphQL):** `projectUpdateCreate` via `$LINEAR_API_KEY`. Session exit or on-demand. OAuth agent token returns 401 — always use personal API key.

**Algorithm:** Gather affected issues → Group by project → Calculate health signal (Off Track > At Risk > On Track, per `references/project-hygiene.md`) → Compose markdown (Progress/Blocked/Created/Next) → Post with dedup (amend same-day) → Initiative roll-up on Mondays.

**Key rules:** Never block session-exit on update failures. Never use `create_document` for updates (use native Updates tab). Never post empty updates. Apply sensitivity filtering (no credentials, no absolute paths, no stack traces).

> See [references/status-updates.md](references/status-updates.md) for the full posting protocol, sensitivity filtering rules, and error handling matrix.

> See [references/graphql-project-updates.md](references/graphql-project-updates.md) for GraphQL mutation signatures and auth.

---

## Dependencies (absorbed from dependency-management)

Manage issue dependency relations safely. The Linear MCP's `update_issue` with `blocks`/`blockedBy`/`relatedTo` parameters **REPLACES** the entire existing array — it does NOT append. This is the most dangerous operation in the Linear MCP integration.

**Mandatory protocol (`safeUpdateRelations`):** READ existing relations → MERGE (add/remove) → WRITE the full merged array. Never call `update_issue` with relation parameters outside this protocol.

**Auto-relation on decompose:** After `/ccc:decompose` creates sub-issues, identify sequential pairs and propose `blocks` relations. Present summary table for user confirmation before executing.

**Dependency detection:** Scan descriptions for signals like "blocks CIA-123", "depends on CIA-123", "requires [description]". Cross-reference against known issue IDs.

**Visualization:** Generate mermaid dependency graphs (full for ≤30 issues, truncated with `[+N more]` beyond that).

> See [references/dependency-protocol.md](references/dependency-protocol.md) for the full `safeUpdateRelations` protocol, input validation, confirmation protocol, detection patterns, and visualization specs.

> See [references/graphql-relations.md](references/graphql-relations.md) for GraphQL fallback mutation signatures.

---

## Overlap and Duplicate Detection

Before creating a new issue, check for existing issues that cover the same scope.

**Detection heuristic:**
1. **Title similarity:** Query `list_issues(project, query: "<key terms>")` with 2-3 distinctive terms from the proposed title
2. **Label overlap:** Same `type:*` label + same milestone = higher duplicate risk
3. **Description keyword match:** If >60% of proposed acceptance criteria terms appear in an existing issue's description, flag as potential duplicate
4. **Stale duplicate:** Issues with identical titles but different statuses (one Done, one Todo) are NOT duplicates — the Todo may be intentional follow-up

**Resolution protocol:**
- **Exact duplicate:** Mark as `duplicateOf` via `update_issue(duplicateOf: "SURVIVOR_ID")`. Close the duplicate.
- **Partial overlap:** Merge acceptance criteria into the survivor. Link as `relatedTo`. Cancel the less-complete issue.
- **Intentional split:** Add a comment documenting why both issues exist. Link as `relatedTo`.

**Anti-pattern:** Creating new issues without first searching for existing ones that cover the same scope.

---

## Bulk Operations

Patterns for batch-modifying issues efficiently.

### Batch Status Update

```
1. list_issues(project, state: "SOURCE_STATE", limit: 50)
2. For each issue: update_issue(id, state: "TARGET_STATE")
3. Rate limit: max 10 updates per batch, 1-second pause between batches
4. Log: "Moved N issues from SOURCE_STATE to TARGET_STATE"
```

### Batch Label Application

```
1. list_issues(project, label: "OLD_LABEL" or no label filter)
2. For each issue:
   a. get_issue(id) → read current labels
   b. Build merged label array (existing + new, or existing - removed)
   c. update_issue(id, labels: merged_array)
3. CRITICAL: Never omit step 2a — labels REPLACE, not append (same as relations)
```

### Batch Estimation

For unestimated issues in a milestone:

```
1. list_issues(project, milestone: "...", limit: 100)
2. Filter to unestimated (estimate == null)
3. Apply estimation heuristic per title verb and type label
4. update_issue(id, estimate: N) for each
```

**Safety rules for all bulk ops:**
- Process in batches of 10-15 (context limit protection)
- Always read before write (labels and relations REPLACE)
- Log every modification for audit trail
- Pause between batches to avoid rate limiting

---

## Administrative Maintenance Automation

Patterns for periodic housekeeping tasks.

### Stale Issue Detection

```
1. list_issues(project, state: "In Progress", updatedAt: "-P14D")
2. For each stale issue:
   a. list_comments(issueId, limit: 5) — check for recent activity
   b. If no comments in 14 days: flag as stale
   c. Post comment: "This issue has been In Progress for 14+ days with no updates."
3. Never auto-close — propose to human for review
```

### Milestone Boundary Cleanup

Before each milestone boundary:

1. **Archive completed:** Move Done issues to archived state
2. **Consolidate duplicates:** Run overlap detection on all open issues
3. **Verify labels:** Ensure every open issue has `type:*` and appropriate `exec:*` labels
4. **Update project description:** Refresh milestone map if milestones changed
5. **Post status update:** Capture milestone completion metrics

### Orphaned Issue Detection

```
1. list_issues(team: "...", project: null, limit: 100)
2. For each unassigned-to-project issue:
   a. Infer project from labels, title keywords, or parent issue
   b. Propose project assignment to user
3. Issues without a clear project → flag for triage
```

---

## Cross-Skill References

- **`/close`** — Universal closure entry point. Applies `references/closure-rules.md` matrix and quality gate.
- **references/closure-rules.md** — Canonical closure matrix (AUTO-CLOSE/PROPOSE/BLOCK conditions, quality thresholds, recovery commands)
- **references/evidence-mandate.md** — Evidence requirements for all completion claims and closing comments
- **branch-finish** — Git operations and pre-completion verification. Marks "closure-ready" after merge; `/close` executes closure.
- **spec-workflow** — Stage 7.5 (issue closure) is governed by the closure rules
- **context-management** — Session exit summary tables follow the format defined in that skill
- **execution-engine** — Execution loop updates issue status per the ownership model defined here
- **document-lifecycle** — Invoked after project-level issue creation to bootstrap Key Resources and Decision Log structural documents
- **milestone-management** — Delegates milestone assignment during issue creation
- **LINEAR-SETUP.md** — Full Linear platform configuration guide
