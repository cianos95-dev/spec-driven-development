# Document Lifecycle Operations Reference

Detailed operational logic for document lifecycle management. The parent SKILL.md contains the core rules (safety, taxonomy link, overviews). This file has the full procedural details.

## Structural Document Checklist Logic

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

Structural documents (Key Resources, Decision Log) are **agent-managed**:

- The agent composes fresh content on each update (never reads-then-modifies)
- User edits to these documents **may be overwritten** on next agent update
- Each template includes the header comment `<!-- Agent-managed document. Manual edits may be overwritten on next agent update. -->` to signal this
- Users who want to maintain a document manually should remove the header comment; the agent will treat documents without the header as user-owned and skip auto-updates

### Dry-Run Mode

When `--dry-run` is passed (via `/ccc:hygiene --dry-run` or direct invocation):

- Run the full checklist logic
- Report what **would** be created, updated, or flagged
- Do NOT call `create_document` or `update_document`
- Output format is identical to `--fix` but with "would create" / "would update" language

## Staleness Detection Logic

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

- **Update now:** The agent composes fresh content and calls `update_document` (through validation function). This resets `updatedAt` naturally.
- **Mark reviewed:** The agent calls `update_document` to prepend `<!-- reviewed: YYYY-MM-DD -->` to the document content. The marker date is compared against the type's staleness threshold.
- **Ignore:** No change. The warning will appear again on the next hygiene run.

The `<!-- reviewed: ... -->` marker prevents warning fatigue for documents that are intentionally stable.

### Pagination Handling

1. Make initial call with `limit` parameter (if supported)
2. Check response for pagination cursor/token
3. Iterate subsequent pages until no more results or 100-document limit reached
4. If 100-document limit is reached, log a warning and proceed with available data

**Configurable limit:** Default is 100 documents per project. This prevents runaway queries on projects with extensive document history.

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
3. **Tool/service adoption or deprecation** — Adding or removing a tool from the stack
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

Wait for user confirmation. **No autonomous Decision Log writes are permitted.**

### Decision Log Rotation

When the active Decision Log exceeds 50 entries:

1. **Create archive document:** `Decision Log Archive — [Year]` via `create_document`
2. **Compose archive content:** Fresh markdown containing the oldest 30 entries (entries 1-30)
3. **Compose active content:** Fresh markdown containing the most recent 20 entries (entries 21-50), renumbered starting from 1
4. **Update active log:** Call `update_document` with the fresh active content (through validation function)

**Important:** Both the archive content and the updated active content must be composed as fresh markdown. Do NOT read the existing Decision Log via `get_document` and split it.

## Project Update Lifecycle

### Accumulation Thresholds

| Threshold | Action |
|-----------|--------|
| >30 Project Updates in a project | Flag during hygiene: "Project has [N] updates. Consider archiving old updates." |
| Updates older than 90 days | Candidates for archival |

### Archival Process

During `/ccc:hygiene --fix`, if a project exceeds the 30-update threshold:

1. **Propose archival:** "Archive [N] Project Updates older than 90 days to 'Project Updates Archive -- [Year]'?"
2. **If approved:** Create archive document with consolidated monthly summaries
3. **Compose archive content:** Fresh markdown with one section per month
4. **Note:** Original Project Update documents remain in Linear (cannot be deleted via MCP). The archive provides a consolidated view. Mark archived updates with `<!-- archived: YYYY-MM-DD -->` in their content.

## MCP Tools Usage Patterns

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
