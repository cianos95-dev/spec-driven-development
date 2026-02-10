---
description: |
  Trigger an adversarial review of a spec using one of four review architecture options.
  Use when a spec is ready for critical evaluation, you want structured pushback before implementation, or you need multi-perspective analysis of assumptions and risks.
  Trigger with phrases like "review this spec", "challenge my proposal", "adversarial review of", "is this spec solid", "find weaknesses in this plan", "stress test this design".
argument-hint: "<spec file path or issue ID>"
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

## What If

| Situation | Response |
|-----------|----------|
| **Spec file not found or issue has no description** | Inform the user the spec could not be located. Suggest running `/write-prfaq` first, or ask the user to provide the file path or issue ID explicitly. |
| **Spec is missing required sections** | Warn the user which sections are absent (e.g., no FAQ, no Pre-Mortem). Offer to proceed with a partial review covering only the sections that exist, noting which perspectives will be limited. |
| **CI workflow not configured for Options A-C** | Offer to create the workflow file from the reference templates in `skills/adversarial-review/references/`. If the user declines, fall back to Option D (in-session subagents). |
