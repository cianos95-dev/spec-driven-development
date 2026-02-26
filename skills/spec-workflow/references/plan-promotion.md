# Plan Promotion Reference

Detailed protocol for promoting ephemeral session plans to durable Linear Documents. The parent spec-workflow SKILL.md contains the summary and two-tier architecture. This file has the full step-by-step protocol.

## Promotion Protocol

### Step 1: Resolve Plan Source

**Code tab (file system available):**
1. If a path is specified (`/ccc:plan --promote path/to/plan.md`), use that file.
2. Otherwise, find the current session's plan: `~/.claude/plans/<session-slug>.md`
3. If no plan file found, check for a plan in the current conversation context and offer to compose from it.

**Cowork tab (no file system):**
1. Compose the plan from the current conversation context.
2. Identify the most recent plan-structured content (sections: Context, Scope, Tasks, Verification).
3. Ask the user to confirm: "I'll promote the plan we just discussed. Does this look right?" Show a summary.

**If no plan source found:** Warn: "No plan found to promote. Write a plan first (enter Plan Mode or use `/ccc:go` to start planning)."

### Step 2: Resolve Target Issue

1. Check argument: `/ccc:plan --promote CIA-XXX` — use the specified issue.
2. Check `.ccc-state.json` → `linearIssue` field (Code tab only).
3. Check conversation context for an active issue reference.
4. If no issue found: create a standalone document in the active project (no issue link). Warn: "No issue specified — creating standalone plan document."

### Step 3: Determine Target Project

1. Fetch the issue via `get_issue(issueId)` → extract project name.
2. Use the project for `create_document(project: "...")`.
3. If standalone (no issue): use the most recently active project, or ask the user.

### Step 4: Check for Existing Plan Document

1. `list_documents(project)` — scan titles for `Plan: CIA-XXX` pattern.
2. **If exists:** This is an update. Compose fresh content (see Step 5). Call `update_document(id, fresh_content)`.
3. **If not exists:** This is a creation. Proceed to Step 5.

> **CRITICAL:** When updating, NEVER read the existing document with `get_document` and modify it. Always compose fresh markdown from the plan source. See `document-lifecycle` skill safety rules.

### Step 5: Create or Update the Linear Document

**Document title format:**

1. **H1 heading extraction (preferred):** If the plan source contains an H1 heading (`# ...`), use it as the document title. This preserves the author's intent.
2. **Fallback:** If no H1 heading exists, use `Plan: CIA-XXX — <issue title truncated to 60 chars>`.

```
# Preferred: extracted from plan H1 heading
Plan: CIA-569 — Implement plan and session naming conventions

# Fallback: generated from issue metadata
Plan: CIA-XXX — <issue title truncated to 60 chars>
```

**Document content structure:**
```markdown
<!-- Agent-managed document. Source: session plan promotion. -->
<!-- Promoted from: <session name or plan file path> -->
<!-- Promoted at: <ISO-8601 timestamp> -->

# Plan: CIA-XXX — <issue title>

<Full plan content from the resolved source>

---

*Promoted from session plan. Last updated: <timestamp>.*
*Source: `~/.claude/plans/<file>` (Code tab) or conversation (Cowork tab).*
```

**Pre-update validation (mandatory):**

```
FUNCTION validate_plan_content(content):
  IF content contains "\\n" (literal backslash-n):
    REJECT — round-trip contamination detected
  IF content contains "\\\\n":
    REJECT — double-escaped newline detected
  IF length(content) < 50 characters:
    REJECT — plan appears empty or truncated
  IF content does not contain at least 2 markdown headings:
    WARN — plan may be missing required sections
  PASS
```

### Step 6: Link Document to Issue

If a target issue was resolved in Step 2, add a comment:

```
Plan promoted to Linear Document: [Plan: CIA-XXX — <title>](<document-url>)

Accessible from: Code tab (Linear MCP), Cowork tab (Linear MCP), Linear UI.
```

### Step 7: Add Local Backlink (Code Tab Only)

Prepend to the plan file:
```markdown
<!-- Promoted to Linear: <document-url> -->
<!-- Promoted at: <ISO-8601 timestamp> -->
```

**Cowork tab:** Skip this step (no file system access).

### Step 8: Confirm to User

```
Plan promoted to Linear Document:
  [Plan: CIA-XXX — <issue title>](<document-url>)

Accessible from:
  - Code tab — via Linear MCP or /ccc:plan --list
  - Cowork tab — via Linear MCP (read/update)
  - Linear UI — in project documents
```

## Reading Promoted Plans

```
list_documents(project: "<project>") → find "Plan: CIA-XXX" → get_document(id)
```

**Use cases:**
- **Cowork session:** "Show me the plan for CIA-042" → reads the promoted Linear Document
- **New Code session:** `/ccc:go CIA-042` → preflight detects promoted plan → loads as context
- **Adversarial review:** `/ccc:review CIA-042` → reads plan for architectural context

> **Remember:** `get_document` output is **read-only**. Never feed it back into `update_document`.

## Platform-Specific Behavior

| Capability | Code Tab | Cowork Tab |
|-----------|----------|------------|
| Read plan from file | `~/.claude/plans/` | Not available |
| Compose plan from conversation | Fallback if no file | Primary method |
| Create Linear Document | Via Linear MCP | Via Linear MCP |
| Add issue comment backlink | Via Linear MCP | Via Linear MCP |
| Add local file backlink | File write | Not available |
| Pre-update validation | Enforced | Enforced |
| Hook-based quality injection | SubagentStart hook | Not available |
| Hook-based quality validation | SubagentStop hook | Not available |

**Cowork compensation:** Plans written in Cowork don't benefit from hook-based quality injection. The skill compensates by checking for required CCC sections (Context, Scope, Tasks, Verification) during composition and warning if sections are missing.

## Listing Promoted Plans

`/ccc:plan --list` shows all promoted plan documents for the active project:

```
CCC Plan Documents:
  1. [Plan: CIA-418 — Build plan promotion skill](url) — Feb 19, 2026
  2. [Plan: CIA-567 — VS Code plan preview spike](url) — Feb 18, 2026
```

Implementation: `list_documents(project)` → filter titles starting with `Plan:` → format as numbered list.

## Anti-Patterns

> **DO NOT** promote every plan. Ephemeral plans for quick fixes, exploration, and throwaway sessions should stay in Tier 1.

> **DO NOT** edit a promoted document by reading it with `get_document` and writing back. Always re-promote from the source.

> **DO NOT** promote partial plans. Fix missing sections first or explicitly acknowledge gaps.

> **DO NOT** attach a plan document to both a project AND an issue simultaneously. The Linear API rejects dual attachment. Attach to the project; link to the issue via a comment.
