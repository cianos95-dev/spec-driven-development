# Scope Discipline & Human Review Gates

Detailed rules for maintaining scope discipline and enforcing human review gates during spec-driven development. The parent SKILL.md contains the overview and gate summary. This file has the full enforcement rules.

## Scope Discipline

Scope creep is the primary risk to session success. These rules enforce predictable execution.

**Pilot batch before bulk operations:**
- When a task affects 10+ items (issues, files, database records, etc.), do a pilot batch of 3-5 first
- Verify results with the human or against expected outcomes
- Then proceed with the remainder
- This catches systematic errors early when they are cheap to fix, not after 50 items are modified

**Approach confirmation:**
- Before executing a plan that touches >5 files or >10 issues, explicitly confirm the approach with the human
- Even if the overall plan is approved, the first batch serves as validation of the specific implementation approach
- "The plan is right" and "my execution of the plan is right" are two different claims

**Scope creep guard:**
- If during execution you discover new work, create a sub-issue immediately
- NEVER add scope to the parent issue or the current session plan
- Document the discovery, link it to the parent, and move on
- The new work enters the funnel at Stage 0 like everything else

**Anti-pattern: "while I'm here":**
- Resist the temptation to fix adjacent issues discovered during implementation
- Log them as new issues with appropriate context, do not fix them in the current session
- Adjacent fixes bypass the spec and review gates, introducing unreviewed changes
- The only exception is trivially mechanical fixes (e.g., a typo on the same line you are editing) that require zero judgment

## Human Review Gates

The three approval gates (Stage 3, Stage 4, Stage 6) are structural requirements, not suggestions. They exist because agent-driven work can move faster than human comprehension of what changed.

**Gate enforcement:**
- No gate can be skipped, even for `quick` execution mode (which still requires Gate 3: PR review)
- Gates are synchronization points: the agent stops, the human catches up, then work resumes
- Passing a gate is an explicit human action (approval comment, PR approval, etc.), never implicit

**Architectural decisions require split sessions:**
- Any change that alters system architecture, data models, or cross-cutting concerns must be split into "propose" and "execute" sessions
- Session 1 produces a proposal (ADR, spec update, or recommendation document)
- Human review between sessions is NOT optional -- it is a structural requirement
- Session 2 executes only what was explicitly approved

**Evidence format for review:**
- Present findings as a summary table, not raw data dumps
- Link to project tracker issues for traceability
- Include an explicit recommendation (approve, revise, reject, or defer)
- Keep the review surface small: the human should be able to make a decision in under 5 minutes of reading
- Never dump evidence tables, audit findings, or spec content into issue comments -- use documents or linked files instead
