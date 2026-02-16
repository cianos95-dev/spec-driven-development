# Session Economics & Checkpoint Decision Rules

Every session has a fixed context budget. These constraints prevent the common failure mode where ambitious plans collapse at 70% context with work half-persisted.

## Context Budget Allocation

| Phase | Target % | Cumulative | Action |
|-------|:--------:|:----------:|--------|
| Planning + startup | ~15% | 15% | Approve plan, set up context |
| Core work batches | ~40-45% | 55-60% | Execute in batched subagent calls |
| Wrap-up + persistence | ~5-7% | 60-67% | Persist results, write summaries |
| **Buffer** | 3-7% | 67-70% | Safety margin before hard stop |

### Hard Rules

- **Plan wrap-up by 60% context.** Begin persistence and summarization.
- **Hard stop at 67%.** Everything must be persisted by this point.
- **Compaction at ~70% is catastrophic.** It loses context in unpredictable ways. Never let it happen silently.
- **Subagent output caps:**
  - Classification/metadata tasks: keep under 3KB per subagent return
  - Research/synthesis tasks: 15KB maximum per subagent return
- **Max 6 subagent spawns per research session.** Each spawn costs overhead for setup and return processing. Beyond 6, coordination overhead exceeds the benefit.

### Decision Rules at Checkpoints

Use these when evaluating whether to continue or split:

| Checkpoint | If Over Target | Action |
|------------|:-------------:|--------|
| After ~37% | >40% | Compress batch summaries before continuing |
| After ~54% | >58% | Skip remaining batches, persist what exists, split to next session |
| At 67% | Any | Persist all results immediately, write exit summary |

## Checkpoint Decision Rules

Context checkpoints are not suggestions. They are hard gates that require explicit evaluation and action.

### 30% Context: Working Memory Audit

Evaluate whether working details from completed phases can be discarded. At this point, early-phase outputs (search results, intermediate classifications, draft tables) may still be in context but are no longer needed for reasoning.

- **Keep:** Outcomes, decisions, file paths, issue IDs
- **Discard mentally:** Raw search results, intermediate drafts, superseded plans
- **Action:** If context feels heavy, delegate the next phase to a subagent instead of running it inline

### 50% Context: Caution Threshold

This is the first mandatory warning point.

- **Warn the human** about context usage level
- **Tighten delegation:** Move all Tier 2 operations into subagents regardless of item count
- **Summarize aggressively:** Reference previous decisions instead of restating them

### 56% Context: Handoff Evaluation

If remaining work is substantial (more than one major phase), write a session handoff file now rather than risking compaction later.

- **Handoff file contents:** Completed phases, remaining work items, all issue IDs with current status, decisions made, open questions
- **Location:** `~/.claude/plans/` with the session's animal name
- **Consider starting a new session** if the remaining work involves research or bulk operations

### 70% Context: Hard Stop

Do NOT continue working. This is not a warning, it is a stop signal.

1. **Write handoff file** with: completed phases, remaining work, issue IDs pending, file paths modified
2. **Persist all in-progress work** to files (not just in context)
3. **Tell the human** what was completed and what remains
4. **Do NOT let compaction happen.** A deliberate split preserves continuity. Compaction destroys it.

## Authoring Session Detection

When a session involves editing more than 3 files within the plugin itself, it qualifies as an "authoring session." Authoring sessions consume context faster because both the source material and the edit targets compete for the same window.

### Rules for Authoring Sessions

- **Source files over 100 lines:** NEVER read in the main context. Delegate to a subagent.
- **Subagent workflow:** The subagent reads the source file plus the existing target file, then either writes edits directly or returns edit instructions to the main context.
- **Main context receives only:**
  - File paths and line counts
  - Issue IDs and their new status
  - Error summaries (if edits failed)
- **Plan file size limit:** Keep the plan itself under 100 lines. Supporting detail (appendices, reference tables, raw data) goes in separate files.

### Why This Matters

A 200-line source file read into the main context costs ~2-3% of the window. Across 5 source files, that is 10-15% consumed before any reasoning happens. Delegating the reads to subagents keeps the main context free for decision-making while the subagents handle the mechanical read-summarize-edit cycle.
