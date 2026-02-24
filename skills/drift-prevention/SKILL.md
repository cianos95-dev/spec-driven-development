---
name: drift-prevention
description: |
  Session anchoring protocol that prevents spec drift in long-running implementation sessions.
  Re-reads active spec, git state, issue state, and review comments to rebuild ground truth from
  source artifacts rather than relying on accumulated session context.
  Use when sessions exceed 30 minutes, after context compaction, before resuming paused work,
  when implementation feels misaligned with acceptance criteria, or when switching between tasks.
  Trigger with phrases like "anchor to spec", "re-read the spec", "am I drifting", "check alignment",
  "reload context", "what was I working on", "session too long".
---

# Drift Prevention

Long sessions accumulate context that gradually diverges from the source of truth. This skill defines a re-anchoring protocol that rebuilds ground truth from artifacts rather than trusting session memory.

## The Problem

After 30+ minutes of implementation, agents commonly:

- Forget specific acceptance criteria while chasing implementation details
- Lose track of which criteria are met vs outstanding
- Drift from the spec when encountering unexpected complexity
- Accumulate stale assumptions from earlier in the session that no longer hold

This is a direct consequence of treating agents as logic engines with perfect memory rather than orchestrators with finite attention. The anchoring protocol below rebuilds ground truth from source artifacts, not session memory. Source: Pierce Lamb Deep Trilogy — "treat Claude as an orchestrator with finite attention, not a logic engine."

## Pre-Step: Gather Issue Context Bundle

Before executing this skill, gather the issue context bundle (see `issue-lifecycle/references/issue-context-bundle.md`). Include comment context in drift checks — comments may contain decisions that change scope, human overrides that alter acceptance criteria, or dispatch results that affect what remains to be done.

## Anchoring Protocol

Before every task (or when triggered), re-read these four sources in order:

### 1. Active Spec

Read the PR/FAQ or spec document linked in the issue's `linear` frontmatter field:

- **Frontmatter** -- `exec` mode, `status`, `research` readiness
- **Acceptance criteria** -- The complete checklist. Mark each as addressed/not-addressed.
- **Open questions** -- Any unresolved questions that might affect implementation

### 2. Git State

Check the current implementation state:

- `git diff --stat` since last commit
- Uncommitted changes and their alignment with acceptance criteria
- Current branch and its relationship to the target branch
- Any stashed changes that might be relevant

### 3. Issue State

Read the current issue from the project tracker:

- **Status** -- Should be In Progress if work is active
- **Labels** -- `exec:*` mode, `spec:*` lifecycle stage, any blockers
- **Assignment** -- Confirm the agent is the assignee
- **Comments** -- Recent updates, human feedback, or scope changes

### 4. Review Comments

Check for unresolved feedback:

- Adversarial review findings (from `/ccc:review` output)
- PR review threads with unresolved comments
- Carry-forward items from previous implementation rounds

## When to Anchor

| Trigger | Action |
|---------|--------|
| Session exceeds 30 minutes | Auto-suggest anchoring |
| Context compaction occurs | Mandatory anchor before continuing |
| Switching between tasks | Anchor to the new task's spec |
| After debugging a tangent | Anchor to verify you're back on track |
| Before claiming "done" | Final anchor to verify all criteria met |
| Manual trigger (`/ccc:anchor`) | Full protocol execution |

## Anchor Output Format

After re-reading all sources, produce a concise alignment summary:

```markdown
## Anchor Check — [Issue ID]

**Spec:** [spec title] | **Mode:** [exec mode] | **Status:** [spec status]

### Acceptance Criteria
- [x] Criterion 1 — implemented in [file:line]
- [ ] Criterion 2 — not yet started
- [~] Criterion 3 — partially implemented, [what remains]

### Drift Detected
- [Any misalignment between implementation and spec]
- [Any scope creep beyond acceptance criteria]

### Open Items
- [Unresolved review comments]
- [Open questions from spec]

### Next Action
- [The single most important next step]
```

## Automatic vs Manual

- **Automatic**: The skill activates as a background check when session length or context usage crosses thresholds. It surfaces a warning if drift is detected.
- **Manual**: `/ccc:anchor` runs the full protocol and produces the alignment summary output.

## Integration with Other Skills

- **execution-modes**: Anchor protocol adapts to the current `exec:*` mode. In `exec:tdd`, it also checks test state. In `exec:checkpoint`, it verifies gate status.
- **context-management**: When context exceeds 50%, anchoring becomes mandatory before each new task unit.
- **issue-lifecycle**: Anchor checks confirm status transitions are warranted before the agent proposes them.
