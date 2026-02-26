---
name: session-exit-protocol
description: |
  End-of-session normalization protocol for AI agent sessions. Covers issue status normalization, closing comments with evidence, daily project updates, session summary tables, and context budget warnings. Ensures no session ends with stale issue statuses, missing evidence, or untracked work.
  Use when ending a working session, preparing session summaries, normalizing issue statuses, writing closing comments, or checking context budget thresholds before session exit.
  Trigger with phrases like "session exit", "end of session", "session summary", "normalize statuses", "closing comments", "session cleanup", "wrap up session", "context budget check", "session handoff".
compatibility:
  surfaces: [code]
  tier: code-only
---

# Session Exit Protocol

Every working session must end with explicit normalization. Sessions that end without normalization leave stale issue statuses, missing evidence trails, and orphaned work that the next session must rediscover. This skill defines the exact sequence of actions required before a session concludes.

## Hook Lifecycle: SessionEnd vs Stop

CCC uses two distinct hook events for session lifecycle:

| Event | Fires When | Purpose |
|-------|-----------|---------|
| **SessionEnd** | Explicit session termination (`clear`, `logout`, `exit`) | Session summary, progress archival, analytics |
| **Stop** | Mid-session agent stops (task boundaries, execution loop pauses) | Task loop advancement, conformance checks, hygiene reports |

**SessionEnd** (`hooks/scripts/ccc-session-end.sh`) handles actual session termination:
- Reads `.ccc-state.json` for current task state
- Generates session summary (issue statuses, files changed, progress)
- Fires PostHog `session_ended` event (if `posthog-capture.sh` exists)
- Archives `.ccc-progress.md` to `.ccc-progress-{timestamp}.md`
- Outputs `additionalContext` with session summary for the final response

**Stop** (`hooks/scripts/ccc-stop-handler.sh`, `stop.sh`) remains for the execution loop:
- Drives task advancement across decomposed tasks
- Reports session hygiene and conformance
- Does NOT archive progress or fire session analytics

The session exit protocol described below applies when a session ends (SessionEnd event). The Stop event handles the autonomous task loop between tasks within a session.

## Core Principle

**No session ends silently.** Every session exit produces at minimum: normalized issue statuses, closing comments with evidence on completed items, and a session summary table presented to the human. The protocol scales -- a session that touched one issue takes 2 minutes to close; a session that touched 20 issues takes 10 minutes. But the protocol is never skipped.

## Session Naming Convention

At session start, name the session for traceability using `/rename`. Claude Code v2.1.47+ persists custom session titles across resume and compaction.

**Naming pattern:** `CIA-XXX: <short title>` (e.g., `CIA-567: Plan preview spike`)

**When to rename:**
- `/ccc:go CIA-XXX` loads an issue → auto-rename to `CIA-XXX: <title>`
- Session starts with a known task → rename immediately
- Multiple issues in one session → rename to the primary issue

**Why this matters:** Plan files at `~/.claude/plans/<session-slug>.md` are otherwise opaque. Named sessions make plan files traceable to their originating issue. When a plan is promoted to a Linear Document (CIA-418), the session name provides the provenance link.

**Plan file naming:** When plan files are created during a session, they should follow the naming conventions defined in the `planning-preflight` skill: `CIA-XXX-slug.md` for issue-tied plans, `YYYY-MM-DD-slug.md` for strategic plans. Subagent plans use `{parent-slug}-agent-{hash}.md` and are ephemeral (not promoted).

## Pre-Step: Gather Issue Context Bundle

Before executing the exit sequence, gather the issue context bundle for each affected issue (see `issue-lifecycle/references/issue-context-bundle.md`). Before writing closing comments, read existing comments to avoid duplicating information already posted by prior sessions or dispatch results.

## Exit Sequence

Execute these steps in order. Do not skip steps or reorder them. Each step depends on outputs from the previous step.

### Step 1: Inventory Affected Issues

Identify every issue whose status, labels, description, or linked artifacts changed during the session. This includes:

- Issues explicitly worked on (status changed to In Progress or Done)
- Issues created during the session (new sub-issues, discovered work)
- Issues whose labels were added, removed, or modified
- Issues whose descriptions or specs were updated
- Issues blocked or unblocked by session work

Build a list of issue identifiers. This list drives all subsequent steps.

### Step 2: Verify Issue Statuses

Verify all Linear issue statuses are accurate. The status must reflect reality at session end, not the aspirational state. If any statuses were missed during the session (e.g., an issue should be In Progress but is still Todo), correct them now.

**Anti-pattern: Status batching.** Do not wait until session end to update statuses. Mark In Progress as soon as work begins during the session. Session exit is the safety net, not the primary mechanism.

**Context label verification:** Every In Progress or In Review issue must have exactly one `ctx:*` label. If missing, apply the appropriate context label based on the current session surface:
- Human-present sessions (Code interactive, Cursor, Cowork, Desktop) → `ctx:interactive`
- Autonomous dispatch (Factory, Codex, Amp, background agents) → `ctx:autonomous`
- Automated feedback (Copilot review, Vercel preview) → `ctx:review`
- Manual human work → `ctx:human`

Remove `ctx:*` labels from issues transitioned to Done or Canceled during the session.

### Step 3: Write Closing Comments

Every issue transitioned to Done (or proposed Done) requires a closing comment with evidence. The comment is the audit trail -- it proves the work was completed and provides links for future reference.

**Required closing comment format:**

```markdown
## Completed

**Evidence:**
- PR: [link] (merged, deploy green)
- Files: [list of key files created or modified]
- Tests: [pass/fail status, coverage delta if applicable]

**Summary:** [1-2 sentences describing what was delivered]
```

**For research/design issues without PRs:**

```markdown
## Completed

**Deliverable:** [Document title or artifact name]
- Location: [Linear document link, file path, or URL]
- Key findings: [2-3 bullet summary]

**Summary:** [1-2 sentences describing what was delivered]
```

**Evidence requirements by closure type:**

| Closure Type | Required Evidence |
|-------------|-------------------|
| Auto-close (agent + single PR + merged) | PR link, deploy status |
| Propose-close (multi-PR) | All PR links, their merge status |
| Propose-close (no PR) | Deliverable link, summary of findings |
| Propose-close (pair work) | PR link, explicit human confirmation request |

### Step 4: Post Daily Project Update

If any issue statuses changed during the session, post a project update using the **issue-lifecycle** skill's Status Updates section. This handles both the project-level update (Tier 2, via GraphQL `projectUpdateCreate`) and the initiative roll-up (Tier 1, via MCP `save_status_update`, Mondays only).

**Delegation:** Invoke the `issue-lifecycle` skill's Status Updates protocol with the affected-issues inventory from Step 1. It handles:
- Grouping issues by project
- Calculating health signals (On Track / At Risk / Off Track)
- Composing and posting the update to the native Updates tab (GraphQL)
- Deduplication (amend vs create for same-day updates)
- Initiative roll-up on Mondays

**Failure handling:** Status updates are best-effort. If the status update fails, log a warning and continue to Step 5. **Never block session exit on a status update failure.**

**When to skip:** Sessions that only performed read-only operations (research, exploration) with no status changes. The status updates protocol enforces the "no empty updates" rule internally.

### Step 4a: Suggest Plan Promotion

If a session plan exists at `~/.claude/plans/` and has **not** been promoted (no `<!-- Promoted to Linear -->` marker in the file), suggest promotion before ending:

```
Unpromoted plan detected: ~/.claude/plans/<session-slug>.md
Run `/ccc:plan --promote` to persist to Linear (accessible from Cowork and Linear UI).
```

**When to suggest:**
- Plan file exists for the current session
- Plan references a CIA-XXX issue (not a throwaway exploration)
- Plan has not already been promoted (check for marker comment)

**When to skip:**
- No plan file exists
- Plan already has `<!-- Promoted to Linear -->` marker
- Session was `exec:quick` (quick-mode plans are typically disposable)
- Cowork session (no file system to check)

### Step 5: Present Session Summary Tables

Present the session summary to the human as the final output. This is the session's receipt -- it confirms what happened and provides linked references for follow-up.

**Issues table:**

```markdown
| Title | Status | Context | Assignee | Milestone | Priority | Estimate | Blocking | Blocked By |
|-------|--------|---------|----------|-----------|----------|----------|----------|------------|
| [Issue title](linear-url) | Done | — | Agent | M1 | High | 2 | — | — |
```

- Title must be a markdown link to the Linear issue (desktop app URL format)
- All fields populated from `get_issue(includeRelations: true)`
- Use `—` for empty fields, never leave cells blank
- Include ALL affected issues, not just completed ones
- Verify all fields are accurate and up-to-date before presenting

**Documents table (separate):**

```markdown
| Title | Project |
|-------|---------|
| [Doc title](linear-url) | Project Name |
```

- Include only documents created or modified during the session
- Title must be a linked markdown reference

### Step 5a: Milestone Health Report

After the session summary tables (Step 5), if any milestones were affected during the session (issues assigned to milestones transitioned to Done, new issues created in a milestoned project, or milestone target dates are within 3 days), invoke the **milestone-management** skill to produce a compact health report.

**When to include:**
- Any issue in a milestone was completed (Done) or cancelled during the session
- Any new issue was assigned to a milestone during the session
- Any active milestone target date is within 3 days (At Risk / Overdue check)

**When to skip:**
- Session touched no milestoned issues
- All milestone operations were read-only (no status changes)

**Output:** The `milestone-management` skill produces a milestone health table appended after the session summary:

```
Milestone Health — [Project Name]

| Milestone | Done | In Progress | Todo | Target | Health |
|-----------|------|-------------|------|--------|--------|
| M1: Foundation | 3 | 1 | 2 | 2026-03-01 | On Track |
```

**Failure handling:** If milestone data is unavailable, skip this step silently. Never block session exit on milestone health reporting.

### Step 6: Context Budget Assessment

Before concluding, assess context window usage and communicate the result:

| Usage Level | Action |
|-------------|--------|
| Under 50% | No action needed. Session ended normally. |
| 50% to 70% | Warn the human: "Context at ~X%. Consider starting a new session for the next task." |
| Above 70% | Insist on new session: "Context at ~X%. Strongly recommend a new session. Writing handoff note." |

**If above 70%, write a handoff file** before session ends:

```markdown
# Session Handoff: [Date]

## Completed
- [What was done]

## In Progress
- [What was started but not finished]

## Decisions Made
- [Key decisions and their rationale]

## Open Questions
- [Unresolved items for next session]

## Next Steps
- [What the next session should start with]
```

Write the handoff to the project's working directory or a session-specific file. Tell the human where it was saved.

## Pre-Exit Checkpoint (Optional)

Before executing the exit sequence, consider running `/ccc:checkpoint` if the session is ending mid-task or if context usage is high. The checkpoint command is a CCC-layer complement to `/compact` and `/resume`:

- **`/ccc:checkpoint`** — Captures task state (progress, decisions, blockers, continuation prompt) into `.ccc-progress.md`, optionally snapshots git state, and updates the Linear issue in place. Use before splitting a session mid-task.
- **Recommended order:** `/ccc:checkpoint` → `/compact` → (continue or end session)

The checkpoint protocol (four steps, fail-forward) is defined in [references/checkpoint-protocol.md](references/checkpoint-protocol.md). The command is thin wrapper over this protocol.

**When to checkpoint before exit:**
- Context is at 60%+ and the task is incomplete
- You are at a natural task boundary and want a clean handoff
- The stop hook did not fire at the expected gate

**When to skip checkpoint and go straight to exit:**
- Session completed all planned tasks (use the exit sequence for status normalization)
- Session was read-only / research only (no state to persist)

## Session Persistence

Four mechanisms preserve session state across boundaries:

- **`/ccc:checkpoint`** -- CCC-layer task state capture. Writes `.ccc-progress.md` with continuation prompt, optionally commits in-scope files, updates Linear issue in place. Use before context boundaries or session splits.
- **`/compact`** -- Reduces context window usage by summarizing older conversation turns. Use proactively before hitting 70%.
- **`/resume`** -- Continues a previous session with its full context. Useful for multi-session tasks.
- **CLAUDE.md hierarchy** -- Global and project-level instruction files persist across all sessions automatically.

These are complementary to the session exit protocol, not replacements. Persistence preserves context; the exit protocol preserves status and evidence.

## Integration with Other Skills

The session exit protocol touches several other skills. The boundaries are:

| Skill | Session Exit Responsibility | Other Skill's Responsibility |
|-------|---------------------------|------------------------------|
| **issue-lifecycle** | Execute closure rules, post evidence | Define closure rules matrix, ownership model |
| **issue-lifecycle** (Status Updates) | Invoke at Step 4 with affected-issues inventory | Compose, deduplicate, and post project/initiative updates |
| **milestone-management** | Invoke at Step 5a if milestones were affected | Fetch milestone data, calculate health, produce health table |
| **context-management** | Report context budget at exit | Define delegation tiers, budget thresholds |
| **spec-workflow** | Update spec status labels at exit | Define spec lifecycle stages |
| **drift-prevention** | Verify implementation matches spec at exit | Define drift detection methodology |
| **execution-engine** | Report execution mode effectiveness at exit | Define retry budgets, fresh context patterns |

## Timing Rules

- **Mark In Progress immediately** when work starts. Do not defer to session exit.
- **Write closing comments immediately** when an issue is completed. Do not batch.
- **Session summary tables** are the ONLY item that waits until session end.
- **Daily project update** can be posted at completion of a logical work block or at session end.
- **Context budget check** is performed continuously, with a final assessment at exit.

## Anti-Patterns

**Silent session end.** Closing the session without presenting a summary table. The human has no visibility into what changed and must manually inspect issues.

**Evidence-free closure.** Marking an issue Done without a closing comment. Future sessions cannot verify what was delivered or why it was considered complete.

**Status drift.** Leaving issues In Progress when work has stopped, or leaving issues as Todo when work has started. Every status must reflect the actual state at session end.

**Context exhaustion.** Allowing compaction to occur without warning. Compaction loses context unpredictably. The exit protocol's budget check prevents this by forcing a deliberate session split.

**Deferred normalization.** "I'll update the statuses at the end." This leads to forgotten updates when sessions end abruptly (timeout, error, human departure). Update statuses as they change; session exit is the safety net, not the primary mechanism.

## Cross-Skill References

- **issue-lifecycle** -- Closure rules matrix, ownership model, and daily update format
- **issue-lifecycle** (Status Updates section) -- Invoked at Step 4 to post project/initiative updates; handles all posting logic
- **milestone-management** -- Invoked at Step 5a for milestone health reporting after milestone-affecting sessions
- **spec-workflow** -- Plan promotion (invoked at Step 4a to suggest promotion of unpromoted session plans); spec status label transitions during implementation
- **context-management** -- Context budget protocol, session splitting, handoff files
- **execution-engine** -- Fresh context patterns for multi-session work
- **checkpoint-protocol** (references/) -- Four-step checkpoint protocol (progress persistence, git snapshot, Linear upsert, continuation prompt); invoked by `/ccc:checkpoint` command and stop hook at gate boundaries
