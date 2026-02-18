# Plan File Format Reference

Standards for plan files produced by CCC planning skills and Plan Mode sessions.

## Issue Reference Format

### Inline References

Always use clickable markdown links when mentioning an issue:

```markdown
[CIA-XXX: Issue Title](https://linear.app/claudian/issue/CIA-XXX)
```

**Example:** [CIA-546: Add accessible explanation layer](https://linear.app/claudian/issue/CIA-546) shipped output styles for review agents.

### Table References

In tables, use the short form in the ID column with the title in a separate column:

```markdown
| ID | Title | Status | Estimate |
|----|-------|--------|----------|
| [CIA-546](https://linear.app/claudian/issue/CIA-546) | Add accessible explanation layer | Done | 5pt |
| [CIA-547](https://linear.app/claudian/issue/CIA-547) | Per-role explanation depth overrides | Backlog | 3pt |
```

### Linear Document References

```markdown
[Document Title](https://linear.app/claudian/document/document-slug-id)
```

### Rule

**Plain text issue IDs (e.g., `CIA-546` without a link) are not permitted in plan files.** Every reference must be a clickable markdown link.

## Required Plan Sections

Every master plan or session plan file should include these sections (omit if genuinely not applicable):

### 1. Header

```markdown
# Plan Title

**Parent issue:** [CIA-XXX: Title](https://linear.app/claudian/issue/CIA-XXX)
**Date:** YYYY-MM-DD
**Session:** session-name (if applicable)
**Supersedes:** [previous plan file or issue, if any]
```

### 2. Issue Registry

Table of all issues referenced in this plan, with current status:

```markdown
## Issue Registry

| ID | Title | Status | Exec | Est | Depends On |
|----|-------|--------|------|-----|-----------|
| [CIA-XXX](url) | Title | Todo | tdd | 3pt | -- |
| [CIA-YYY](url) | Title | In Progress | quick | 2pt | CIA-XXX |
```

### 3. Phase Map

Ordered roadmap showing what happens when:

```markdown
## Phase Map

| Phase | Issues | Focus | Batch | Dependencies |
|-------|--------|-------|-------|-------------|
| 1A | [CIA-XXX](url) | Foundation | 1 | None |
| 1B | [CIA-YYY](url) | Integration | 1 | None (parallel with 1A) |
| 2A | [CIA-ZZZ](url) | Verification | 2 | 1A, 1B |
```

### 4. Session Registry (Multi-Session Plans)

Track which session handles which work:

```markdown
## Session Registry

| Session Name | Issue | Phase | Agent | Status |
|--------------|-------|-------|-------|--------|
| composed-crunching-raven | [CIA-413](url) | 1A | Claude Code | Done |
| luminous-meandering-zephyr | [CIA-387](url) | 1B | Tembo | Active |
```

### 5. Verification Checklist

```markdown
## Verification

- [ ] All Phase 1 sub-issues Done
- [ ] PRs merged without conflicts
- [ ] Tests passing on main
- [ ] Linear statuses updated
```

### 6. Key Files

```markdown
## Key Files

| File | Purpose |
|------|---------|
| `skills/review-response/SKILL.md` | Review Finding Dispatch protocol |
| `CONNECTORS.md` | Agent routing source of truth |
```

## Dispatch Sub-Issue Tables

When creating dispatch sub-issues (see `parallel-dispatch/SKILL.md`), the parallel dispatch table uses linked IDs:

```markdown
| Session | Issue | Focus | Mode | Est. Cost | Agent | Branch |
|---------|-------|-------|------|-----------|-------|--------|
| S-A | [CIA-550](url) | Session exit skill | quick | ~$2 | Claude Code | claude/cia-550-session-exit |
| S-B | [CIA-551](url) | Dispatch rules | tdd | ~$5 | Tembo | tembo/cia-551-dispatch-rules |
```
