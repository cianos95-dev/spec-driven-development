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

**Every** call to `update_document` MUST pass through this validation before execution. This is mechanical enforcement, not advisory guidance.

**Validation logic:**

```
FUNCTION validate_document_content(content):
  IF content contains "\\n" (literal backslash-n, not newline):
    REJECT — "Content contains escaped newline (\\n). This indicates round-trip contamination. Compose fresh markdown instead."
  IF content contains "\\\\n":
    REJECT — "Content contains double-escaped newline (\\\\n). This indicates multi-cycle round-trip contamination."
  IF content contains "\\\\\\\\n":
    REJECT — "Content contains triple-escaped newline. Severe round-trip contamination detected."
  PASS — content is safe to write
```

**How to apply:** Before calling `update_document(id, content)`, run the content through this validation. If validation fails, do NOT proceed with the update. Instead, reconstruct the content from source data (issue descriptions, session context, structured data) and try again.

**This function is not optional.** Skipping it — even "just this once" — risks silent document corruption that compounds over time.

## Document Type Taxonomy

See [references/document-types.md](references/document-types.md) for the complete taxonomy including:
- All 6 document types with staleness thresholds, naming patterns, and per-project requirements
- Classification rules ("Can someone mark this Done?" test)
- Required vs Optional categorization
- Naming pattern enforcement rules

This reference file is the **single source of truth** for document type classification. Do not duplicate the taxonomy elsewhere.

## Structural Document Checklist

Required structural documents ensure every project has consistent, discoverable metadata. This checklist runs during project creation and `/ccc:hygiene --fix`.

### When This Runs

- On project creation (manual trigger)
- During `/ccc:hygiene --fix` (automated)
- During `/ccc:hygiene --check` (report only, no creation)

### Opt-Out Mechanism

Projects can opt out of auto-created structural documents at two levels:

**Project-level opt-out:** Include this HTML comment **anywhere** in the project description:

```
<!-- no-auto-docs -->
```

This skips all structural document creation for the project.

**Per-document-type opt-out:** Include a type-specific HTML comment:

```
<!-- no-auto-docs:decision-log -->
<!-- no-auto-docs:key-resources -->
```

This skips creation of only the specified document type. Multiple per-type opt-outs can coexist.

**Check before creating:** Before creating any structural document, read the project description and scan for opt-out markers. If `<!-- no-auto-docs -->` is present, skip all creation for that project. If `<!-- no-auto-docs:[type] -->` is present, skip only that type. Log: `"Project [name] has opted out of [scope] document creation."`

### Checklist Logic

```
FOR each project:
  1. Read project description
  2. IF description contains "<!-- no-auto-docs -->":
       LOG "[Project] opted out of auto-document creation"
       SKIP to next project
  3. CALL list_documents(projectId, limit=50) to get existing documents
  4. FOR each required type (Key Resources, Decision Log):
       NORMALIZE title: lowercase, trim whitespace
       MATCH existing document titles (case-insensitive) against naming pattern
       IF match found:
         REPORT "[Required] [Type]: exists (last updated: [date])"
       IF multiple matches found:
         LOG WARNING "Duplicate [Type] documents found in [Project]. Skipping creation."
       ELSE IF no match:
         ADD to creation_list
  5. IF creation_list is non-empty AND NOT --dry-run:
       PRESENT pre-flight summary to user:
         "I will create [N] documents in [Project]: [list]. Proceed?"
       WAIT for user confirmation
       Exception: --yes flag bypasses confirmation for automation
       IF confirmed:
         FOR each document in creation_list:
           CALL create_document with template (see below)
           REPORT "[Required] [Type]: created"
       ELSE:
         REPORT "Document creation skipped by user"
     ELSE IF --dry-run:
       FOR each document in creation_list:
         REPORT "[Required] [Type]: MISSING — would create"
     ELSE (--check):
       FOR each document in creation_list:
         REPORT "[Required] [Type]: MISSING"
  6. FOR each optional type present:
       REPORT "[Optional] [Type]: exists (last updated: [date])"
```

### Output Labeling

In all hygiene output, prefix each document line with its requirement status:

- `[Required]` — Key Resources, Decision Log
- `[Optional]` — Project Update, Research Library Index, ADR, Living Document

This helps users distinguish structural requirements from informational documents.

### Document Templates

**Key Resources template:**

```markdown
<!-- Agent-managed document. Manual edits may be overwritten on next agent update. -->
# Key Resources

## Source Code
- [Repository name](repo-url)

## Specs and Plans
- (Add links as specs are created)

## External References
- (Add deployment URLs, documentation links)

## Methodology
- (Add methodology references if applicable)
```

**Decision Log template:**

```markdown
<!-- Agent-managed document. Manual edits may be overwritten on next agent update. -->
# Decision Log

| # | Decision | Status | Date | Context |
|---|----------|--------|------|---------|
| 1 | (First decision) | Open/Closed | YYYY-MM-DD | (Brief context or link to ADR) |
```

### Agent-Managed Ownership

Structural documents (Key Resources, Decision Log) are **agent-managed**. This means:

- The agent composes fresh content on each update (never reads-then-modifies)
- User edits to these documents **may be overwritten** on next agent update
- Each template includes the header comment `<!-- Agent-managed document. Manual edits may be overwritten on next agent update. -->` to signal this to users
- Users who want to maintain a document manually should remove the header comment; the agent will treat documents without the header as user-owned and skip auto-updates

### Dry-Run Mode

When `--dry-run` is passed (via `/ccc:hygiene --dry-run` or direct invocation):

- Run the full checklist logic
- Report what **would** be created, updated, or flagged
- Do NOT call `create_document` or `update_document`
- Output format is identical to `--fix` but with "would create" / "would update" language

## Staleness Detection

Staleness detection identifies documents that may have drifted from project reality. It runs **during `/ccc:hygiene` only** — never during session-exit (too expensive for multi-project sessions).

### Frequency Rule

| Context | Runs Staleness Detection? | Rationale |
|---------|--------------------------|-----------|
| `/ccc:hygiene --check` | Yes (report only) | Explicit audit request |
| `/ccc:hygiene --fix` | Yes (report + flag) | Explicit fix request |
| Session-exit protocol | **No** | Too expensive; multi-project sessions would trigger dozens of `list_documents` calls |
| Ad-hoc skill invocation | Yes | Direct request to check document health |

### Detection Logic

```
FOR each project:
  1. CALL list_documents(projectId, limit=100)
  2. IF results are paginated:
       WHILE next page exists AND total < 100:
         Fetch next page
       IF total >= 100:
         LOG WARNING "Project [name] has 100+ documents. Staleness check limited to first 100."
  3. FOR each document:
       IDENTIFY type by matching title against naming patterns (see document-types.md)
       LOOK UP staleness threshold for that type
       IF type has "No staleness" threshold:
         SKIP (e.g., Project Updates)
       IF type has "Configurable" threshold:
         CHECK project description for custom threshold
         IF not found: use 30 days as default
       CHECK document content for <!-- reviewed: YYYY-MM-DD --> marker
       IF marker present AND marker date is within threshold:
         SKIP — document was manually reviewed recently
       CALCULATE days_since_update = today - document.updatedAt
       IF days_since_update > threshold:
         FLAG "[Type] '[title]' is stale (last updated [days] days ago, threshold: [threshold] days)"
         OFFER three options:
           1. "Update now" — agent composes fresh content based on current project state
           2. "Mark reviewed" — agent adds <!-- reviewed: YYYY-MM-DD --> to document, resetting staleness clock
           3. "Ignore" — no action; will re-flag on next hygiene run
```

### Staleness Dismissal

When a document is flagged as stale, the user can dismiss the warning in three ways:

- **Update now:** The agent composes fresh content and calls `update_document` (through validation function). This resets `updatedAt` naturally.
- **Mark reviewed:** The agent calls `update_document` to prepend `<!-- reviewed: YYYY-MM-DD -->` to the document content. The staleness check looks for this marker and treats it as a freshness signal. The marker date is compared against the type's staleness threshold.
- **Ignore:** No change. The warning will appear again on the next hygiene run. This is the default if the user doesn't respond.

The `<!-- reviewed: ... -->` marker prevents warning fatigue for documents that are intentionally stable (e.g., a Decision Log with no new decisions).

### Pagination Handling

The `list_documents` MCP tool may return paginated results. Handle pagination as follows:

1. Make initial call with `limit` parameter (if supported)
2. Check response for pagination cursor/token
3. Iterate subsequent pages until no more results or 100-document limit reached
4. If 100-document limit is reached, log a warning and proceed with available data

**Configurable limit:** Default is 100 documents per project. This prevents runaway queries on projects with extensive document history. The limit can be adjusted per-project in the project description's hygiene protocol section.

## Auto-Update Triggers

Documents are updated in response to specific project events. All updates go through the pre-update validation function.

### Trigger Table

| Event | Target Document | Action | Confirmation Required? |
|-------|----------------|--------|----------------------|
| Key artifact shipped (new spec, plan, insights report) | Key Resources | Append link to appropriate section | No |
| Decision Log trigger event (see below) | Decision Log | Append row with decision, status, date, context | **Yes — always** |
| Decision Log reaches 50 entries | Decision Log + Archive | Rotate (see below) | Yes |
| Project renamed | Key Resources | Update project references | No |
| New milestone created | Key Resources | Add milestone reference if applicable | No |

### Decision Log Write Policy

The agent appends to the Decision Log **only** for these specific trigger events:

1. **Architectural choice** — Technology selection, pattern adoption (e.g., "Use Yjs over Automerge")
2. **Scope change** — Milestone restructured, project pivoted, significant acceptance criteria change
3. **Tool/service adoption or deprecation** — Adding or removing a tool from the stack (e.g., "Adopt Factory", "Drop fabric-mcp")
4. **Methodology change** — Process modification (e.g., "Switch from weekly to biweekly cycles")

**If the event does not match one of these four categories, the agent does NOT write to the Decision Log.**

### Decision Log Confirmation Gate

Before **any** Decision Log append, the agent presents the proposed entry to the user:

```
I propose adding to Decision Log:
  Decision: "[decision text]"
  Status: Open
  Date: YYYY-MM-DD
  Context: "[brief context]"

Add to Decision Log? [yes/no]
```

Wait for user confirmation. **No autonomous Decision Log writes are permitted.** If the user declines, log: `"Decision Log entry declined by user."` and continue without writing.

### Decision Log Rotation

When the active Decision Log exceeds 50 entries:

1. **Create archive document:** `Decision Log Archive — [Year]` via `create_document`
2. **Compose archive content:** Fresh markdown containing the oldest 30 entries (entries 1-30)
3. **Compose active content:** Fresh markdown containing the most recent 20 entries (entries 21-50), renumbered starting from 1
4. **Update active log:** Call `update_document` with the fresh active content (through validation function)
5. **Log:** "Decision Log rotated: 30 entries archived to 'Decision Log Archive — [Year]', 20 entries retained in active log"

**Important:** Both the archive content and the updated active content must be composed as fresh markdown. Do NOT read the existing Decision Log via `get_document` and split it. Instead, maintain the decision entries in structured form (from the triggering context) and render them into markdown.

## Project Update Lifecycle

Project Update documents are informational and accumulate over time (one per active session). Without management, they grow without bound.

### Accumulation Thresholds

| Threshold | Action |
|-----------|--------|
| >30 Project Updates in a project | Flag during hygiene: "Project has [N] updates. Consider archiving old updates." |
| Updates older than 90 days | Candidates for archival |

### Archival Process

During `/ccc:hygiene --fix`, if a project exceeds the 30-update threshold:

1. **Propose archival:** "Archive [N] Project Updates older than 90 days to 'Project Updates Archive -- [Year]'?"
2. **If approved:** Create archive document via `create_document` with consolidated monthly summaries
3. **Compose archive content:** Fresh markdown with one section per month, summarizing key updates from that month
4. **Note:** The original Project Update documents remain in Linear (they cannot be deleted via MCP). The archive provides a consolidated view. Mark archived updates with `<!-- archived: YYYY-MM-DD -->` in their content.

The 30-update threshold is checked during the structural document existence check (`list_documents` call) — no additional MCP call required.

## MCP Tools Used

This skill orchestrates four Linear document MCP tools:

| Tool | Purpose | Safety Notes |
|------|---------|-------------|
| `create_document` | Create structural documents from templates | Safe — no existing content to corrupt |
| `update_document` | Update documents on triggers | **Must pass through pre-update validation function** |
| `get_document` | Read document content for display/audit | **Read-only — NEVER feed output to update_document** |
| `list_documents` | Existence checks, staleness detection | Handle pagination; respect 100-doc limit |

### Usage Patterns

**Creating a structural document:**
```
1. Check project opt-out (<!-- no-auto-docs --> or <!-- no-auto-docs:[type] -->)
2. Call list_documents to get existing documents
3. Title-normalized comparison: lowercase + trim, case-insensitive match
4. If document already exists: skip. If duplicates found: log warning.
5. If creation needed: present pre-flight summary and wait for confirmation
6. Call create_document with template content (includes agent-managed header)
```

**Updating a document on trigger:**
```
1. Compose fresh markdown from source data (NEVER from get_document output)
2. For Decision Log: present entry and wait for user confirmation
3. Run content through pre-update validation function
4. IF validation passes: call update_document
5. IF validation fails: reconstruct content and retry
```

**Reading a document:**
```
1. Call get_document to retrieve content
2. Display or analyze content
3. DO NOT store content for later use in update_document
```

**Auditing documents:**
```
1. Call list_documents with pagination handling
2. Match against document-types.md taxonomy
3. Check staleness thresholds
4. Report findings with [Required]/[Optional] labels
```

## Document Versioning

Linear maintains document edit history natively. This skill does **not** implement custom versioning or changelogs.

- **Version tracking:** Rely on Linear's built-in document history (accessible via the Linear UI)
- **No custom changelog:** Adding a "Last modified" footer or revision table to document content is unnecessary and creates maintenance burden
- **Audit trail:** The combination of Linear's document history and CCC's hygiene reports provides sufficient traceability

## Integration Points

### With `/ccc:hygiene` Command

This skill extends the hygiene command with two new check categories:

1. **Structural completeness:** Are required documents present for each project?
2. **Staleness:** Are existing documents within their freshness thresholds?

Both checks integrate into the existing hygiene report format (Errors/Warnings/Info) and scoring model.

| Check | Severity | Rule |
|-------|----------|------|
| Missing required document | Warning | Key Resources or Decision Log not found (and project hasn't opted out) |
| Stale document | Warning | Document's `updatedAt` exceeds type-specific threshold |
| 100+ documents in project | Info | Staleness check was limited; may have missed stale documents |

### With `session-exit` Protocol

Session-exit does **NOT** run staleness detection. However, session-exit may trigger auto-update events:

- If a key artifact was shipped during the session, update Key Resources
- If a Decision Log trigger event occurred (architectural choice, scope change, tool adoption, methodology change), propose the entry with confirmation gate

These are trigger-based updates, not staleness scans. They are lightweight and appropriate for session-exit context. Decision Log writes always require user confirmation, even at session-exit.

### With `project-cleanup` Skill

The `project-cleanup` skill's Content Classification Matrix determines whether content should be an issue or a document. Once classified as a document, the `document-lifecycle` skill governs the document's lifecycle. `project-cleanup` should reference [references/document-types.md](references/document-types.md) for type definitions rather than maintaining its own copy (CIA-540 carry-forward).

### With `issue-lifecycle` Skill

The `issue-lifecycle` skill's project-hygiene protocol defines project artifacts and their cadence. This skill aligns with those definitions:

- Key Resources and Decision Log are "universal" per project-hygiene.md
- Research Library Index is "research-heavy projects only" per project-hygiene.md
- Project Update cadence ("end of each active session") is unchanged

## Cross-Skill References

- **project-cleanup** -- Content Classification Matrix references document-types.md for classification (I1, CIA-540)
- **issue-lifecycle** -- Project hygiene protocol aligns document artifact cadence
- **hygiene** command -- Structural checklist and staleness detection integrate into hygiene output
- **session-exit** -- Does NOT run staleness; may trigger auto-updates on artifact/decision events (I2)
- **drift-prevention** -- Document updates follow the same fresh-markdown discipline as issue descriptions
- **plan-promotion** -- Consumes safety rules (no round-tripping, pre-update validation) when promoting session plans to Linear Documents
