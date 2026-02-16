---
description: |
  Draft a PR/FAQ spec using the Working Backwards method, selecting the appropriate template based on scope.
  Use when starting a new feature spec, writing a press release for a proposed change, creating acceptance criteria, or structuring a proposal with pre-mortem and FAQ sections.
  Trigger with phrases like "write a spec for", "draft a PR/FAQ", "new feature proposal", "working backwards document for", "spec this idea", "create acceptance criteria for".
argument-hint: "<feature idea, problem statement, or issue ID>"
platforms: [cowork, cli]
---

# Write PR/FAQ Spec

Draft a PR/FAQ specification using the Working Backwards method. The template is selected based on the nature of the change.

## Step 1: Understand the Scope

Ask the user the following questions to determine the correct template:

- Is this change **customer-facing** (affects end-user experience)?
- Does this require **research grounding** (literature review, methodology validation)?
- Is this an **infrastructure** change (CI/CD, tooling, developer experience)?
- Is this **small scope** (single PR, less than a day of work)?

Select the template based on answers:

| Customer-facing | Research-backed | Infrastructure | Small scope | Template |
|:-:|:-:|:-:|:-:|----------|
| Yes | No | No | No | `prfaq-feature` |
| Yes/No | Yes | No | No | `prfaq-research` |
| No | No | Yes | No | `prfaq-infra` |
| - | - | - | Yes | `prfaq-quick` |

If the input is an issue ID, fetch the issue from the connected project tracker first to pre-populate context.

## Step 1.5: Planning Preflight

Before gathering context in Step 2, invoke the `planning-preflight` skill. The Planning Context Bundle replaces the ad-hoc context gathering in Step 2, making it systematic rather than manual.

1. Run the 5-step preflight protocol.
2. If preflight detects overlapping issues, present the overlap table and ask the user whether to proceed, merge, or adjust scope before drafting.
3. The bundle's codebase state, sibling issues, and strategic context feed directly into Step 2's context gathering -- use them instead of re-querying from scratch.

**Skip preflight when:**
- Invoked from `/sdd:go` with `--quick` flag (quick mode skips preflight)
- Preflight already ran this session (reuse the cached bundle)

## Step 2: Gather Context

Before drafting, gather supporting information:

1. **Project tracker** — Search for related issues, existing specs, and current sprint priorities. Identify duplicates or overlapping work.
2. **Research library** — If a research library is connected and the template is `prfaq-research`, search for relevant literature. Aim for 3+ citations minimum.
3. **Codebase** — If the feature touches existing code, review the relevant modules for constraints and integration points.
4. **Prior specs** — Check `docs/specs/` for related or superseded specifications.

Summarize findings in 3-5 bullets before proceeding.

## Step 3: Draft the Press Release

Write the Press Release section first. This is the Working Backwards principle: start from the customer outcome and work backward to the implementation.

**Rules:**
- The Press Release MUST be 1 page or less.
- The **Problem** section MUST NOT mention the solution. Describe the pain point in the customer's own language.
- The **Solution** section describes what was built, written in past tense as if it already shipped.
- Include a fictional customer quote that captures the emotional benefit.

Present the draft Press Release to the user for feedback before continuing.

## Step 4: Generate FAQ Candidates

Generate 10-15 candidate FAQ questions covering:

- **Customer questions** — "How does this work?", "What if I already use X?"
- **Stakeholder questions** — "How much does this cost?", "What's the timeline?"
- **Technical questions** — "How does this integrate with Y?", "What are the scaling limits?"
- **Skeptic questions** — "Why not just do Z instead?", "What happens if this fails?"

Present the full list to the user. The user selects 6-12 questions for the final FAQ. Draft answers for the selected questions.

## Step 5: Complete Adversarial Sections

### Pre-Mortem
Identify 3+ failure modes. For each:
- What goes wrong
- Probability (Low / Medium / High)
- Impact (Low / Medium / High)
- Mitigation strategy

### Inversion Analysis
Ask: "What would guarantee this project fails?" List 3-5 anti-patterns. Invert each into a positive practice.

### Acceptance Criteria
Derive acceptance criteria from:
- FAQ answers (each answer implies a testable claim)
- Inversion analysis (each anti-pattern implies a guard rail)
- Pre-mortem mitigations (each mitigation implies a verification step)

Write acceptance criteria in Given/When/Then format where possible.

## Step 6: Add Frontmatter

Add spec frontmatter to the top of the document:

```yaml
---
linear: <issue ID if known>
exec: <quick|tdd|pair|checkpoint|swarm>
status: draft
research: <needs-grounding|literature-mapped|methodology-validated|expert-reviewed>  # only for research template
---
```

Select the execution mode based on complexity:
- Single file change, clear requirements → `quick`
- Testable acceptance criteria, moderate scope → `tdd`
- Uncertain scope, needs human judgment → `pair`
- High-risk, multi-milestone → `checkpoint`
- 5+ independent parallel tasks → `swarm`

## Step 7: Review and Iterate

Present the complete draft to the user. Highlight:
- Any sections that feel thin or need more detail
- Open questions that require human decisions
- Suggested next steps (review, decomposition, implementation)

Iterate based on user feedback until the spec is approved. Once approved, update the status to `ready` and sync to the project tracker if connected.

## Next Step

After the PR/FAQ draft is complete and committed:

```
✓ PR/FAQ draft complete. Label set to spec:draft.
  Next: Run `/sdd:go` to continue → will route to Gate 1 (spec approval)
  Or: Run `/sdd:review [issue ID]` directly after human approves the spec
```

The spec needs human approval (Gate 1) before proceeding to adversarial review.

## What If

| Situation | Response |
|-----------|----------|
| **No project tracker connected** | Skip issue lookup in Step 2. Draft the spec locally and note that the user should manually create the tracker issue after approval. Leave the `linear:` frontmatter field blank. |
| **No template clearly matches** | Default to `prfaq-feature`. It is better to over-specify and trim than to under-specify. If the user disagrees, let them override. |
| **User provides only a vague idea** | Spend extra time in Step 1 asking clarifying questions. Do not proceed to the Press Release until the problem is articulated clearly enough that the Problem section can be written without mentioning a solution. |
