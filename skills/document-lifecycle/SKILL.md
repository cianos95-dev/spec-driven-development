---
name: document-lifecycle
description: |
  Manage Linear document lifecycle: create structural documents, detect staleness, update on triggers,
  and enforce safety rules for document content. Wires up create_document, update_document, get_document,
  and list_documents MCP tools with validation, pagination, and dry-run support.
  Use when creating project documents, checking document freshness, updating Key Resources or Decision Log,
  rotating Decision Log entries, or auditing document health during hygiene runs.
  Trigger with phrases like "create project documents", "check document staleness", "update key resources",
  "rotate decision log", "document hygiene", "list project documents", "create decision log",
  "stale documents", "missing documents".
compatibility:
  surfaces: [code, cowork, desktop]
  tier: universal
---

# Document Lifecycle

Manage the full lifecycle of Linear documents within CCC projects: creation, staleness detection, triggered updates, and safe content handling. This skill governs **how** documents are created, maintained, and audited. For **what** document types exist and their classification rules, see [references/document-types.md](references/document-types.md).

## Safety Rules

> **These rules are non-negotiable. Read them before any document operation.**

### DO NOT: Round-Trip Documents

**NEVER** read a document with `get_document` and feed its content back into `update_document`.

The Linear API returns document content with escaped characters. Each read-write cycle compounds the escaping:

```
Cycle 1: \n  →  \\n
Cycle 2: \\n →  \\\\n
Cycle 3: \\\\n → \\\\\\\\n
```

This corruption is silent and cumulative. After 2-3 round-trips the document becomes unreadable.

**The rule:** `get_document` is **read-only**. When updating a document, always compose fresh markdown from scratch. Never copy, modify, or template from `get_document` output.

### Pre-Update Validation Function

**Every** call to `update_document` MUST pass through this validation before execution.

```
FUNCTION validate_document_content(content):
  IF content contains "\\n" (literal backslash-n, not newline):
    REJECT — "Content contains escaped newline (\\n). Round-trip contamination."
  IF content contains "\\\\n":
    REJECT — "Content contains double-escaped newline (\\\\n). Multi-cycle contamination."
  IF content contains "\\\\\\\\n":
    REJECT — "Content contains triple-escaped newline. Severe contamination."
  PASS — content is safe to write
```

**This function is not optional.** Skipping it risks silent document corruption that compounds over time.

## Document Type Taxonomy

See [references/document-types.md](references/document-types.md) for the complete taxonomy including:
- All 6 document types with staleness thresholds, naming patterns, and per-project requirements
- Classification rules ("Can someone mark this Done?" test)
- Required vs Optional categorization
- Naming pattern enforcement rules

This reference file is the **single source of truth** for document type classification.

## Structural Document Checklist

Required structural documents ensure every project has consistent, discoverable metadata. Runs during project creation, `/ccc:hygiene --fix`, and `/ccc:hygiene --check`.

**Opt-out:** Projects can opt out via `<!-- no-auto-docs -->` (all types) or `<!-- no-auto-docs:[type] -->` (per type) in the project description.

**Workflow:** For each project, list existing documents, match titles (case-insensitive) against required types (Key Resources, Decision Log), and create any missing ones with user confirmation. Supports `--dry-run` for preview.

> See [references/lifecycle-operations.md](references/lifecycle-operations.md) for the full checklist logic, document templates, agent-managed ownership rules, and dry-run mode details.

## Staleness Detection

Staleness detection identifies documents that may have drifted from project reality. It runs **during `/ccc:hygiene` only** — never during session-exit (too expensive for multi-project sessions).

| Context | Runs Staleness Detection? | Rationale |
|---------|--------------------------|-----------|
| `/ccc:hygiene --check` | Yes (report only) | Explicit audit request |
| `/ccc:hygiene --fix` | Yes (report + flag) | Explicit fix request |
| Session-exit protocol | **No** | Too expensive for multi-project sessions |
| Ad-hoc skill invocation | Yes | Direct request to check document health |

For each document, the type's staleness threshold is checked against `updatedAt`. Stale documents offer three options: update now, mark reviewed (`<!-- reviewed: YYYY-MM-DD -->`), or ignore.

> See [references/lifecycle-operations.md](references/lifecycle-operations.md) for the full detection logic, pagination handling, and staleness dismissal details.

## Auto-Update Triggers

Documents are updated in response to specific project events. All updates go through the pre-update validation function. Key artifact creation updates Key Resources (no confirmation). Decision Log writes require user confirmation and are limited to four trigger categories: architectural choices, scope changes, tool adoption/deprecation, and methodology changes.

Decision Log rotation occurs at 50 entries — oldest 30 are archived, newest 20 are retained.

> See [references/lifecycle-operations.md](references/lifecycle-operations.md) for the trigger table, Decision Log write policy, confirmation gate protocol, and rotation procedure.

## MCP Tools Used

| Tool | Purpose | Safety Notes |
|------|---------|-------------|
| `create_document` | Create structural documents from templates | Safe — no existing content to corrupt |
| `update_document` | Update documents on triggers | **Must pass through pre-update validation function** |
| `get_document` | Read document content for display/audit | **Read-only — NEVER feed output to update_document** |
| `list_documents` | Existence checks, staleness detection | Handle pagination; respect 100-doc limit |

> See [references/lifecycle-operations.md](references/lifecycle-operations.md) for detailed usage patterns per operation type.

## Document Versioning

Linear maintains document edit history natively. This skill does **not** implement custom versioning or changelogs. Rely on Linear's built-in document history and CCC's hygiene reports for traceability.

## Integration Points

### With `/ccc:hygiene` Command

| Check | Severity | Rule |
|-------|----------|------|
| Missing required document | Warning | Key Resources or Decision Log not found (and project hasn't opted out) |
| Stale document | Warning | Document's `updatedAt` exceeds type-specific threshold |
| 100+ documents in project | Info | Staleness check was limited; may have missed stale documents |

### With `session-exit` Protocol

Session-exit does **NOT** run staleness detection. However, session-exit may trigger auto-update events (Key Resources on artifact creation, Decision Log on qualifying events with confirmation gate).

### With `issue-lifecycle` Maintenance Section

The `issue-lifecycle` skill's Maintenance section (absorbed from project-cleanup) contains the Content Classification Matrix that determines whether content should be an issue or a document. Once classified as a document, the `document-lifecycle` skill governs the document's lifecycle. The maintenance protocol references [references/document-types.md](references/document-types.md) for type definitions rather than maintaining its own copy (CIA-540 carry-forward).

### With `issue-lifecycle` Skill

Aligns with project-hygiene protocol: Key Resources and Decision Log are "universal" per project, Research Library Index is "research-heavy projects only", Project Update cadence is "end of each active session".

## Cross-Skill References

- **issue-lifecycle** (Maintenance section) -- Content Classification Matrix references document-types.md for classification (I1, CIA-540)
- **issue-lifecycle** -- Project hygiene protocol aligns document artifact cadence
- **hygiene** command -- Structural checklist and staleness detection integrate into hygiene output
- **session-exit** -- Does NOT run staleness; may trigger auto-updates on artifact/decision events (I2)
- **drift-prevention** -- Document updates follow the same fresh-markdown discipline as issue descriptions
- **plan-promotion** -- Consumes safety rules (no round-tripping, pre-update validation) when promoting session plans to Linear Documents
