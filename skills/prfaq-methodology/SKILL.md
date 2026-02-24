---
name: prfaq-methodology
description: |
  Working Backwards PR/FAQ methodology for spec drafting with 4 templates, interactive drafting guidance, and structured questioning techniques.
  Use when writing a new spec, choosing a PR/FAQ template, drafting a press release, defining acceptance criteria, or structuring a feature proposal with pre-mortem analysis.
  Trigger with phrases like "write a spec", "PR/FAQ for this feature", "working backwards document", "which template should I use", "draft a press release", "pre-mortem analysis".
compatibility:
  surfaces: [code, cowork, desktop]
  tier: universal
---

# PR/FAQ Methodology

The PR/FAQ (Press Release / Frequently Asked Questions) method forces clear thinking by starting from the customer outcome and working backwards to the solution. Every spec in this funnel begins as a PR/FAQ document.

## Core Principles

### 1. Write the Press Release First

Start from the customer outcome. What would the announcement say if this feature shipped tomorrow? The press release is a maximum of one page and must be understandable by someone with no technical context.

Write it before any design work, architecture discussion, or implementation planning. The press release is the forcing function that clarifies what you are actually building and why anyone would care.

### 2. Problem Section Must Not Mention the Solution

This is the hardest discipline and the most important. The problem statement must articulate the pain, friction, or unmet need without hinting at how you plan to solve it.

Bad: "Users need a dashboard to see their analytics data."
Good: "Users currently have no visibility into how their content performs after publishing. They make decisions about what to write next based on intuition rather than evidence."

The first version has already decided the solution (a dashboard). The second version opens the door to many possible solutions -- a dashboard, email reports, inline metrics, an API, or even a concierge service. Keeping the solution out of the problem statement forces you to validate that the problem is real before committing to a specific fix.

### 3. FAQ Forces Rigorous Questioning

The FAQ section is not filler. It is the primary mechanism for stress-testing the spec.

**Drafting process:** Generate 10-15 candidate questions across these categories:
- Customer questions ("How does this work?" / "What if I already use X?")
- Technical questions ("How does this scale?" / "What are the failure modes?")
- Business questions ("What does this cost?" / "How do we measure success?")
- Skeptic questions ("Why now?" / "What alternatives were considered?")

Then select the best 6-12 questions. "Best" means the ones that are hardest to answer -- those reveal the weakest parts of the proposal. Every selected question must have a substantive answer, not a deflection.

### 4. Pre-Mortem

"Imagine this shipped 6 months ago and failed. What went wrong?"

This inverts the natural optimism bias of spec writing. Instead of arguing why something will work, you argue why it will fail. Generate at least 3 failure modes, each with:

- **Failure scenario:** A specific, plausible story of how this fails
- **Root cause:** The underlying assumption or design flaw that caused it
- **Mitigation:** What you would change in the spec to prevent this failure
- **Detection:** How you would know this failure is happening before it becomes catastrophic

The pre-mortem is not a risk register. It is a narrative exercise. Write each failure as a story, not a bullet point.

### 5. Inversion Analysis

"How would we guarantee this fails?"

This is distinct from the pre-mortem. The pre-mortem asks what could go wrong. Inversion asks what you would do on purpose to make it fail. Then derive design principles from the opposite.

Example:
- To guarantee failure: "Ship without any onboarding. Drop users into a blank screen."
- Design principle derived: "First-run experience must guide users to a meaningful outcome within 60 seconds."

Generate 3-5 inversions. Each one produces a design principle that becomes a constraint on the implementation.

### 6. Acceptance Criteria From FAQ and Inversion

Acceptance criteria are not invented separately. They are derived from:
- FAQ answers (each answer implies a testable behavior)
- Inversion-derived design principles (each principle implies a verifiable constraint)
- Pre-mortem mitigations (each mitigation implies a monitoring or testing requirement)

This ensures acceptance criteria are grounded in the reasoning that produced the spec, not bolted on as an afterthought.

## Templates

Four templates are available in the `templates/` subdirectory. Each encodes the full methodology at a different level of formality.

| Template | Use For | Formality | Key Sections |
|----------|---------|-----------|-------------|
| `prfaq-feature` | Customer-facing product features | Full | Press Release, 12-Q FAQ, Pre-Mortem, Inversion, AC |
| `prfaq-research` | Features requiring literature grounding | Full + Research | Above + Research Base (3+ citations), Methodology Notes |
| `prfaq-infra` | Internal infrastructure changes | Full | Internal Press Release, Before/After table, Rollback plan |
| `prfaq-quick` | Small scope changes, bug fixes | Minimal | One-Liner, Problem, Solution, Key Questions, AC |

### Template Selection Heuristic

Follow this decision tree:

1. Is this backed by academic research or requires literature grounding? --> `prfaq-research`
2. Is this a customer-facing product feature? --> `prfaq-feature`
3. Is this internal tooling, infrastructure, or developer experience? --> `prfaq-infra`
4. Is this a small, well-understood change (bug fix, config change, minor enhancement)? --> `prfaq-quick`

When in doubt, use `prfaq-feature`. It is better to over-specify and trim than to under-specify and discover gaps during implementation.

## Spec Frontmatter

All specs include YAML frontmatter for machine-readable metadata. This frontmatter connects the spec to your ~~project-tracker~~ and drives automation in later stages.

```yaml
---
linear: ~~PREFIX-XXX
exec: quick|tdd|pair|checkpoint|swarm|spike
status: draft
created: YYYY-MM-DDTHH:mm:ssZ
updated: YYYY-MM-DDTHH:mm:ssZ
research: needs-grounding|literature-mapped|methodology-validated|expert-reviewed
---
```

**Field definitions:**

- `linear` (or your tracker prefix): The ~~project-tracker~~ issue ID. Replace `~~PREFIX~~` with your team's issue prefix.
- `exec`: The execution mode for implementation. See the `execution-modes` skill. Set during spec drafting based on complexity assessment.
- `status`: Spec lifecycle state. Starts as `draft`, progresses through `ready` (approved), `implementing`, and `complete`.
- `created`: ISO 8601 timestamp when the spec was first drafted. Set once at creation, never updated.
- `updated`: ISO 8601 timestamp of the most recent substantive edit. Updated by the agent on each content change.
- `research`: Only include for research-backed features (`prfaq-research` template). Tracks the research grounding progression.

## Interactive Drafting Process

When drafting a PR/FAQ interactively (e.g., in a collaborative session), follow this question sequence. Do not skip steps or batch questions.

### Phase 1: Problem Discovery (3-5 minutes)

1. "Who is the user and what are they trying to accomplish?"
2. "What is frustrating, slow, or impossible about how they do it today?"
3. "How do they currently work around this problem?"
4. "What happens if we do nothing -- does the problem get worse?"

Capture answers as the Problem section. Verify: does the problem statement mention any solution? If yes, rewrite.

### Phase 2: Press Release (5-10 minutes)

5. "If this shipped tomorrow, what would the one-sentence announcement say?"
6. "What is the single most important benefit to the user?"
7. "What quote would a satisfied user give about this?"

Draft the press release from these answers. Keep it under one page. Read it back and ask: "Would someone outside the team understand why this matters?"

### Phase 3: FAQ Generation (10-15 minutes)

8. "What would a skeptical engineer ask about this?"
9. "What would a new user ask about this?"
10. "What would a competitor point to as a weakness?"
11. "What is the most expensive or risky part of building this?"

Generate 10-15 candidate questions. Select the 6-12 hardest to answer. Draft substantive answers for each.

### Phase 4: Stress Testing (5-10 minutes)

12. "Imagine this failed 6 months from now. Tell me three stories of how it failed."
13. "How would you deliberately make this fail?"
14. "What would you change in the spec to prevent each failure?"

Capture as Pre-Mortem and Inversion Analysis sections.

### Phase 5: Acceptance Criteria (5 minutes)

15. "Based on the FAQ answers and inversion principles, what are the testable criteria for done?"

Derive acceptance criteria. Each criterion must be independently verifiable.

### Phase 6: Metadata

16. Select execution mode based on complexity.
17. Assign ~~project-tracker~~ issue.
18. Set `status: draft` and appropriate `research:` level if applicable.

## Research Grounding (prfaq-research only)

For research-backed features, the `research:` frontmatter field tracks grounding progression:

- `needs-grounding`: Idea exists but no literature support yet
- `literature-mapped`: 3+ relevant papers identified and cited in Research Base section
- `methodology-validated`: Research instruments, statistical methods, and study design documented
- `expert-reviewed`: A domain expert (human) has reviewed the research grounding

Progression from `methodology-validated` to `expert-reviewed` always requires human judgment -- it cannot be automated.

The Research Base section must include:
- At least 3 citations with relevance to the proposed feature, formatted as Evidence Objects (see the `research-grounding` skill for the `[EV-001]` structured format with type, source, claim, and confidence)
- A brief note on how each citation supports or challenges the approach
- Any contradictions in the literature and how the spec resolves them
- At least 1 Evidence Object of `type: empirical`

### Mandatory Non-Goals

Every PR/FAQ MUST include a Non-Goals section listing what the feature explicitly will NOT do. Purpose: prevent scope creep and reinvention of existing tools.

**Required content:**
- At least 3 explicit non-goals per feature
- Each non-goal must cite WHY it's excluded (e.g., "existing tool X handles this", "out of scope for target user", "deferred to Phase N")
- Anti-pattern: vague non-goals like "won't be too complex" — non-goals must be specific and falsifiable

**Template field (add after Pre-Mortem):**
```
## Non-Goals
1. [Specific thing] — [Reason it's excluded]
2. [Specific thing] — [Reason it's excluded]
3. [Specific thing] — [Reason it's excluded]
```

### Solution-Scale Constraint

Every spec must declare its target scale. Solution complexity must match user scale — personal tool ≠ enterprise infrastructure.

**Scale categories:**
- **Personal** (1 user): Simple, local-first, minimal infra
- **Team** (2-10 users): Shared state, basic auth, simple deployment
- **Organization** (10-100 users): Multi-tenant, RBAC, monitoring
- **Platform** (100+ users): Distributed, high-availability, compliance

**Rule:** If the declared scale is "Personal" or "Team", reject any solution that requires:
- Kubernetes or container orchestration
- Message queues or event buses
- Microservices (monolith is correct)
- Custom auth systems (use existing providers)

Anti-pattern: "enterprise architecture for a personal tool" — the most common over-engineering failure mode.
