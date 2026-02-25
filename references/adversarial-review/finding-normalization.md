# Finding Normalization, Storage, and Fix-Forward

## Finding Normalization Protocol (Option H)

When external agents (cto.new, Codex, Amp, Copilot) post review findings, their output is unstructured -- they do not follow the CCC severity format. The normalization protocol converts agent findings into RDR rows:

1. **Read** the agent's comment on the review sub-issue
2. **Extract** distinct findings (look for bullet points, numbered items, or paragraph-level concerns)
3. **Classify** each finding by severity (Critical / Important / Consider) based on content
4. **Assign** the agent name to the Reviewer column
5. **Append** normalized rows to the parent issue's RDR table
6. **Deduplicate** against existing RDR rows (same finding from different reviewers = note both in Reviewer column, keep higher severity)

When multiple external agents review the same spec, run the normalizer after each agent completes. The final RDR table is the union of all agent findings plus any in-session review findings.

## Review Findings Storage

The Review Decision Record is the primary findings format. For repo audit trail, also store findings in a version-controlled file:

**Pattern:** Create a `REVIEW-GATE-FINDINGS.md` file at the root of the feature branch (or in `docs/reviews/`). This file captures the RDR table with decisions filled in after Gate 2 passes.

**Why a separate file:** Review findings are implementation guidance, not spec content. Keeping them in a dedicated file prevents spec bloat and gives the implementer a checklist to work through. The file is committed to the feature branch and merged with the PR, preserving the review trail.

## Fix-Forward Summary

When adversarial review findings are partially resolved during implementation (some fixed, some deferred), document the resolution in a **fix-forward summary** as a PR comment or issue comment at Stage 7.5 closure.

```markdown
## Fix-Forward Summary

**Review:** [link to REVIEW-GATE-FINDINGS.md or review comment]

### Resolved in this PR
| ID | Finding | Resolution |
|----|---------|------------|
| C1 | [Critical finding] | Fixed in [commit/file] |
| I1 | [Important finding] | Addressed by [approach] |

### Carry-Forward (separate issues created)
| ID | Finding | Deferred To | Rationale |
|----|---------|-------------|-----------|
| I3 | [Important finding] | CIA-XXX | [Why deferred -- scope, risk, dependency] |

### Accepted Risks
| ID | Finding | Decision |
|----|---------|----------|
| R2 | [Consider finding] | Accepted -- [rationale] |
```

This pattern ensures no review findings are silently dropped. Every finding gets one of three dispositions: resolved, deferred (with tracking issue), or explicitly accepted.
