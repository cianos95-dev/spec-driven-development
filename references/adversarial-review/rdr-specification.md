# Review Decision Record (RDR) Specification

Every review synthesis output (regardless of Option A-H) must end with a **Review Decision Record** table. The RDR is the artifact that Gate 2 operates on -- it transforms implicit approval ("I ran `/decompose` so I guess I approve") into explicit, traceable decisions on each finding.

This format extends the Decision/Response column pattern from CIA-378 (triage tables) to adversarial review findings.

## RDR Table Format

The RDR table has two variants depending on the `style.explanatory` preference:

**Standard format** (`terse` or `balanced`):

```markdown
## Review Decision Record

**Issue:** CIA-XXX | **Review date:** YYYY-MM-DD | **Option:** D/E/F/G/H
**Reviewers:** [names/agents] | **Recommendation:** APPROVE / REVISE / RETHINK

| ID | Severity | Finding | Reviewer | Decision | Response |
|----|----------|---------|----------|----------|----------|
| C1 | Critical | [Finding description] | Challenger | | |
| C2 | Critical | [Finding description] | Security | | |
| I1 | Important | [Finding description] | Devil's Advocate | | |
| I2 | Important | [Finding description] | Security | | |
| N1 | Consider | [Finding description] | Challenger | | |

**Decision values:** `agreed` (will address) | `override` (disagree, see Response) | `deferred` (valid, tracked as new issue) | `rejected` (not applicable)
**Response required for:** override, deferred (with issue link), rejected
**Gate 2 passes when:** All Critical + Important rows have a Decision value
```

**Accessible format** (`detailed` or `educational`):

```markdown
## Review Decision Record

**Issue:** CIA-XXX | **Review date:** YYYY-MM-DD | **Option:** D/E/F/G/H
**Reviewers:** [names/agents] | **Recommendation:** APPROVE / REVISE / RETHINK

| ID | Severity | Finding | Plain English | Reviewer | Decision | Response |
|----|----------|---------|---------------|----------|----------|----------|
| C1 | Critical | [Finding description] | [One-sentence user-facing translation] | Challenger | | |
| C2 | Critical | [Finding description] | [One-sentence user-facing translation] | Security | | |
| I1 | Important | [Finding description] | [One-sentence user-facing translation] | Devil's Advocate | | |
| N1 | Consider | [Finding description] | [One-sentence user-facing translation] | Challenger | | |

**Decision values:** `agreed` (will address) | `override` (disagree, see Response) | `deferred` (valid, tracked as new issue) | `rejected` (not applicable)
**Response required for:** override, deferred (with issue link), rejected
**Gate 2 passes when:** All Critical + Important rows have a Decision value
```

The "Plain English" column translates each finding into a single sentence that a non-technical project owner can understand. Focus on user-visible consequences, not implementation details. Example:
- Finding: "Env var export from session-start.sh cannot reach ccc-stop-handler.sh -- separate process invocations, no shared env"
- Plain English: "The detection result gets lost between steps -- like writing a note that gets thrown away before anyone reads it"

## Decision Vocabulary

| Value | Meaning | Response Required? | Gate 2 Effect |
|-------|---------|-------------------|---------------|
| `agreed` | Will address before implementation | No (optional clarification) | Passes |
| `override` | Disagree with finding, proceeding anyway | Yes (explain rationale) | Passes |
| `deferred` | Valid finding, tracked as separate issue | Yes (include issue link) | Passes |
| `rejected` | Finding is not applicable to this context | Yes (explain why) | Passes |
| (empty) | No decision yet | N/A | **Blocks Gate 2** (Critical/Important only) |

## ID Convention

Severity-initial + sequential number: `C1`, `C2`, `I1`, `I2`, `N1`, `N2`. This matches the existing convention in `sample-review-findings.md` and is stable across re-reviews.

## Inline Decision Collection

When presenting the RDR in-session, offer the human a natural language shorthand:

```
Gate 2 requires decisions on all Critical and Important findings.
Quick options:
  "agree all" -- accept all findings
  "agree all except C2, I3" -- selective override
  "agree C1-C3, override I2: [reason], defer I3 to CIA-456"

Syntax: commas = list (C1, C3), hyphens = range (C1-C3)
```

Parse the human's response, update the RDR table, and re-post the updated table to the project tracker.

## Where the RDR Lives

**Primary: Project tracker comment on the parent issue.** External agents (Option H) already post findings as comments. The human can reply or edit in-place. The `/decompose` command reads the latest RDR comment via the project tracker API.

**Secondary: `REVIEW-GATE-FINDINGS.md`** at feature branch root or in `docs/reviews/`. Committed for repo audit trail after decisions are filled. This preserves the version-controlled record for future reference.

**Why the tracker comment is primary:** (1) External agents already post to the tracker as comments. (2) The human reviewer works in the tracker, not in the IDE. (3) `/decompose` can verify Gate 2 by reading comments. (4) Comments preserve edit history for audit trail.
