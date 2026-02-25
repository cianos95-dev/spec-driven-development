---
description: |
  Manage CCC plans: promote session plans to durable Linear Documents, list promoted plans.
  Use --promote to elevate the current session plan to a Linear Document accessible from Code, Cowork, and Linear.
  Use --list to see all promoted plan documents for the active project.
  Trigger with phrases like "promote plan", "save plan", "list plans", "plan --promote", "plan --list".
argument-hint: "--promote [CIA-XXX] | --list"
allowed-tools: Read, Write, Edit, Bash
platforms: [cli, cowork]
---

# Plan Management

Manage the lifecycle of CCC session plans. Plans start as ephemeral files (`~/.claude/plans/`) and can be promoted to durable Linear Documents for cross-surface access.

## --promote [CIA-XXX]

Elevate the current session plan to a Linear Document. Invoke the **spec-workflow** skill's plan promotion protocol:

1. **Resolve plan source** -- Read from `~/.claude/plans/` (Code tab) or compose from conversation (Cowork tab).
2. **Resolve target issue** -- Use the provided `CIA-XXX` argument, or infer from `.ccc-state.json`, or ask.
3. **Create/update Linear Document** -- Title: `Plan: CIA-XXX -- <issue title>`. Compose fresh content (never round-trip).
4. **Link to issue** -- Add backlink comment on the Linear issue.
5. **Add local marker** -- Prepend `<!-- Promoted to Linear: <url> -->` to the plan file (Code tab only).
6. **Confirm** -- Show the document URL and access points.

**Examples:**
```
/ccc:plan --promote CIA-418      # Promote current plan, link to CIA-418
/ccc:plan --promote              # Promote current plan, infer issue from state
```

**See:** `spec-workflow` skill (Plan Promotion section) for the full promotion protocol, safety rules, and platform-specific behavior.

## --list

List all promoted plan documents for the active project.

1. Determine the active project from `.ccc-state.json` or the most recently referenced issue.
2. `list_documents(project)` -- filter for titles starting with `Plan:`.
3. Display as a numbered list with links and dates.

**Example output:**
```
CCC Plan Documents:
  1. [Plan: CIA-418 -- Build plan promotion skill](url) -- Feb 19, 2026
  2. [Plan: CIA-567 -- VS Code plan preview spike](url) -- Feb 18, 2026
```

## What If

| Situation | Response |
|-----------|----------|
| No plan file found | "No plan found. Enter Plan Mode to create one, or provide a file path." |
| No issue specified and none in state | Create standalone document in active project. Warn: "No issue link -- creating standalone plan document." |
| Plan already promoted | Update the existing document with fresh content. Don't create a duplicate. |
| Running in Cowork | Compose plan from conversation context instead of reading file. Skip local backlink step. |
| `--list` returns no results | "No promoted plans found for [project]. Use `/ccc:plan --promote` to promote a plan." |
