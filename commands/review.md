---
description: |
  Trigger an adversarial review of a spec using one of four review architecture options.
  Use when a spec is ready for critical evaluation, you want structured pushback before implementation, or you need multi-perspective analysis of assumptions and risks.
  Trigger with phrases like "review this spec", "challenge my proposal", "adversarial review of", "is this spec solid", "find weaknesses in this plan", "stress test this design".
argument-hint: "<spec file path or issue ID>"
allowed-tools: Read, Grep, Glob
platforms: [cli]
---

# Adversarial Spec Review

Trigger a structured adversarial review of a specification. Multiple review architectures are supported depending on infrastructure and urgency.

## Step 1: Identify Spec

Locate the spec to review using one of these methods (in priority order):

1. **Explicit path** — If the argument is a file path, read the spec from disk.
2. **Issue ID** — If the argument is an issue identifier, fetch the spec from the project tracker description or linked documents.
3. **Most recent** — If no argument is provided, find the most recently modified spec in `docs/specs/` and confirm with the user.

Verify the spec has the required sections (Press Release, FAQ, Pre-Mortem, Acceptance Criteria) before proceeding. If sections are missing, warn the user and offer to proceed with a partial review.

## Step 2: Select Review Option

Present the four review architecture options with a brief tradeoff summary:

| Option | Name | Speed | Cost | Depth | Setup |
|--------|------|-------|------|-------|-------|
| **A** | CI Agent Free | Async | Free | Medium | Requires CI config |
| **B** | Premium Agents | Async | Paid | High | Requires CI + API keys |
| **C** | API Actions | Async | Paid | High | Requires webhook config |
| **D** | In-Session Subagents | Immediate | Session context | High | None |

**Default to Option D** for immediate in-session review unless the user requests otherwise.

## Step 3: Execute Review

### Option D: In-Session Subagents (Default)

Launch 3 parallel review perspectives. Each reviewer operates independently and produces a structured critique.

**Reviewer 1: Challenger**
- Role: Question every assumption in the spec.
- Focus: Are the claimed problems real? Is the proposed solution the right one? Are there simpler alternatives? Does the FAQ dodge hard questions?
- Output: List of challenged assumptions with severity ratings.

**Reviewer 2: Security Reviewer**
- Role: Identify security, privacy, and reliability risks.
- Focus: Data exposure, authentication gaps, failure cascading, dependency risks, compliance concerns.
- Output: Risk register with likelihood and impact ratings.

**Reviewer 3: Devil's Advocate**
- Role: Argue against shipping the feature entirely.
- Focus: Opportunity cost, maintenance burden, user confusion, scope creep potential, organizational readiness.
- Output: "Case against" brief with counter-arguments.

Use an appropriate model mix for subagents: fast models for scanning, capable models for deep analysis.

### Options A-C: CI/CD-Based Review

For Options A, B, or C:

1. Check if the repository has the required CI configuration (`.github/workflows/spec-review.yml` or equivalent).
2. If not configured, offer to create the workflow file.
3. If configured, trigger the review pipeline and inform the user to check results asynchronously.
4. Provide the expected timeline for results.

## Step 4: Synthesize Findings

Consolidate outputs from all three reviewers into a single structured review. Categorize every finding:

- **Critical** — Must address before implementation. The spec has a gap that would cause failure, security exposure, or significant rework.
- **Important** — Should address. The spec would benefit meaningfully from this change but implementation could proceed cautiously without it.
- **Consider** — Nice to have. A refinement that improves quality but is not blocking.

For each finding, include:
- The reviewer who raised it
- The specific section of the spec it applies to
- A concrete suggestion for how to address it

## Step 5: Present Results

Output the consolidated review in a structured format:

```
## Review Summary
- Critical: N findings
- Important: N findings
- Consider: N findings

## Critical Findings
### [Finding title]
**Reviewer:** [Challenger | Security | Devil's Advocate]
**Section:** [Press Release | FAQ | Pre-Mortem | Acceptance Criteria]
**Issue:** [Description]
**Suggestion:** [How to fix]

## Important Findings
...

## Consider
...
```

After presenting results, offer two actions:
1. **Update the spec** — Apply the critical and important findings directly to the spec document.
2. **Create follow-up issues** — Create issues in the project tracker for findings the user wants to address separately.

## Step 5.5: Post Review Decision Record

After presenting the review findings, generate a **Review Decision Record (RDR)** table and post it to the project tracker.

1. **Generate the RDR table** — Convert the synthesized findings into the canonical RDR format (see the `adversarial-review` skill, "Review Decision Record" section). Every Critical, Important, and Consider finding gets a row with ID, Severity, Finding, and Reviewer columns. Leave Decision and Response columns empty.

2. **Post to the project tracker** — Add the RDR table as a comment on the parent issue. If the spec was identified by issue ID (Step 1, method 2), post directly. If identified by file path, inform the user to post manually or provide the issue ID.

3. **Collect inline decisions** — Prompt the human to fill in decisions:

```
✓ Review Decision Record posted to [issue ID].

Gate 2 requires decisions on all Critical and Important findings.
Quick options:
  "agree all" — accept all findings
  "agree all except C2, I3" — selective override
  "agree C1-C3, override I2: [reason], defer I3 to CIA-456"

Or review in the project tracker and come back.
```

4. **Parse and update** — If the human provides inline decisions, parse their natural language response (commas = list, hyphens = range), update the RDR table, and re-post the updated table to the project tracker comment.

5. **Verify Gate 2** — If all Critical and Important findings have decisions, confirm Gate 2 is passed. If any remain unfilled, report which findings still need decisions.

## Next Step

After the Review Decision Record is posted:

```
✓ Adversarial review complete. Review Decision Record posted.
  → Fill decisions on Critical/Important findings to pass Gate 2
  → Then: Run `/ccc:go` to continue → will verify Gate 2 and route to decomposition
  → Or: Run `/ccc:decompose [issue ID]` after Gate 2 decisions are filled
```

Gate 2 is passed when all Critical and Important findings in the RDR have a Decision value (`agreed`, `override`, `deferred`, or `rejected`).

## What If

| Situation | Response |
|-----------|----------|
| **Spec file not found or issue has no description** | Inform the user the spec could not be located. Suggest running `/write-prfaq` first, or ask the user to provide the file path or issue ID explicitly. |
| **Spec is missing required sections** | Warn the user which sections are absent (e.g., no FAQ, no Pre-Mortem). Offer to proceed with a partial review covering only the sections that exist, noting which perspectives will be limited. |
| **CI workflow not configured for Options A-C** | Offer to create the workflow file from the reference templates in `skills/adversarial-review/references/`. If the user declines, fall back to Option D (in-session subagents). |
| **Issue is a spike, chore, or docs-only change** | Check the adversarial-review skill's "When to Review Liberally" section. Reduce review ceremony based on issue type. For spikes, focus on scope and time-box validity rather than implementation gaps. For chores, static quality checks are sufficient. |
