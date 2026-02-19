# Example: CCC Funnel Validation Run

> **Purpose:** Shows the expected output format when dry-running the CCC execution funnel end-to-end on a real issue. Use this as a reference for what a complete validation report looks like.
> **Related:** Execution engine skill, spec-workflow skill, issue-lifecycle skill

---

## Validation Summary

| Stage | Name | Result | Notes |
|-------|------|--------|-------|
| 0 | Universal Intake | PASS | Issue created with verb-first title, labels, estimate, project |
| 1 | Ideation | SKIP | Skipped per `exec:quick` fast path |
| 2 | Analytics Review | SKIP | Skipped per `exec:quick` fast path |
| 3 | PR/FAQ Draft | PASS | `prfaq-quick` template applied; ACs in issue description serve as spec |
| 3.1 | Gate 1: Approve Spec | PASS | `spec:draft` -> `spec:ready` label transition verified |
| 4 | Adversarial Review | SKIP | Skipped per `exec:quick` fast path |
| 4.1 | Gate 2: Accept Findings | SKIP | No RDR generated (review skipped) |
| 5 | Visual Prototype | SKIP | Skipped per `exec:quick` fast path |
| 6 | Implementation | PASS | State files created, stop hook tested, task execution verified |
| 6.1 | Stop Hook: No Signal | PASS | Correctly detected missing TASK_COMPLETE, incremented retry |
| 6.2 | Stop Hook: TASK_COMPLETE | PASS | Advanced task index, reset iteration, built continue prompt |
| 6.3 | Stop Hook: REPLAN | PASS | Detected signal, updated state to replan phase |
| 6.4 | Stop Hook: Last Task | PASS | Cleaned up `.ccc-state.json`, preserved `.ccc-progress.md` |
| 7 | Verification | PASS | Static quality checks pass |
| 7.5 | Issue Closure | PASS | PR created, labels updated to `spec:complete` |
| 8 | Async Handoff | N/A | Not applicable for local execution |

## Findings

Each finding is categorized by severity:
- **CRITICAL** — Blocks the funnel from working correctly
- **IMPORTANT** — Causes confusion or incorrect routing, but has workarounds
- **CONSIDER** — Refinement opportunity, not blocking

### Finding 1 (IMPORTANT): Quick mode routing conflict in `/ccc:go`

**Location:** `commands/go.md` Step 1C routing table vs Step 2 quick mode
**Issue:** The routing table says "Todo + `spec:ready` -> Stage 4: Run `/review`" regardless of execution mode. But the quick mode fast path says skip Stage 4. An `exec:quick` issue with `spec:ready` would be incorrectly routed to adversarial review.
**Fix:** Add an `exec:quick` guard in Step 1C: if issue has `exec:quick` label and `spec:ready`, route directly to decompose/execution instead of review.

### Finding 2 (IMPORTANT): Decompose Gate 2 deadlock for quick mode

**Location:** `commands/decompose.md` Step 1 (Gate 2 Pre-Check)
**Issue:** The decompose command checks for an RDR comment (Review Decision Record). For `exec:quick` issues where review is skipped, there's no RDR. The fallback says "if `spec:implementing`, proceed" — but `spec:implementing` is set during execution, not before decompose. This creates a deadlock: quick issues can't decompose because they have no RDR, and they can't get `spec:implementing` without first decomposing.
**Fix:** Add `exec:quick` to the Gate 2 fallback conditions: if issue has `exec:quick` label, skip the RDR check entirely.

### Finding 3 (CONSIDER): Quick mode spec generation undocumented

**Location:** `commands/go.md` Step 2, spec-workflow fast path table
**Issue:** For `exec:quick`, the issue description with ACs IS the spec, but this isn't explicitly documented. The `/ccc:go` Step 2 says "use `prfaq-quick` template" but doesn't specify that the template is just the issue description format.
**Fix:** Add a note: "For `exec:quick`, the issue description serves as the spec. Ensure acceptance criteria are present in the description before entering execution."

### Finding 4 (CONSIDER): Skipped gates not represented in state model

**Location:** Execution engine skill, `.ccc-state.json` schema
**Issue:** The `gatesPassed` array records passed gates but has no concept of skipped gates. For `exec:quick`, Gate 2 is skipped, not passed. Setting `gatesPassed: [1, 2]` conflates "human approved" with "auto-skipped."
**Fix:** Consider adding a `gatesSkipped` array, or document the convention that skipped gates should be included in `gatesPassed`.

### Finding 5 (CONSIDER): Stop hook task reference is vague

**Location:** `hooks/scripts/ccc-stop-handler.sh` Section 13
**Issue:** The continue prompt says "Execute task N of M from the decomposed task list" without specifying where the task list lives (Linear sub-issues? Local file? `.ccc-progress.md`?).
**Fix:** Include the Linear issue ID in the prompt: "Execute task N of M for CIA-XXX. Read the task from the Linear sub-issues or .ccc-progress.md."

### Finding 6 (CONSIDER): REPLAN signal uses loose substring match

**Location:** `hooks/scripts/ccc-stop-handler.sh` Section 10.5
**Issue:** `grep -q "REPLAN"` matches any substring containing "REPLAN" (e.g., "REPLANNED", "don't REPLAN"). Could cause false positives.
**Fix:** Use word-boundary matching: `grep -qw "REPLAN"` or exact string `grep -qF "REPLAN"` with surrounding context.

## Test Environment

- CCC version: 1.8.2
- Test issue: CIA-576 (1pt `exec:quick` chore)
- Branch: `claude/pedantic-grothendieck`
- Stop hook: `hooks/scripts/ccc-stop-handler.sh` (tested directly via stdin simulation)
