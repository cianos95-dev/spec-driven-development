# Evidence-First Mandate

> **Canonical reference.** All completion claims, closing comments, and quality assessments must follow this protocol. Referenced by `/close`, `branch-finish`, `quality-scoring`, `session-exit`, and `pr-dispatch`.

## Core Principle

**Never trust claims. Verify with output.** A completion claim is valid only when backed by the actual output of a verification command — not a prediction, belief, or assumption about what the output would be.

## What Counts as Evidence

| Claim | Valid Evidence | NOT Evidence |
|-------|--------------|-------------|
| "Tests pass" | Terminal output showing `X tests passed, 0 failed` | "I ran the tests earlier" |
| "Build succeeds" | Terminal output showing build completion with exit code 0 | "The build should work" |
| "Lint is clean" | Terminal output showing 0 warnings, 0 errors | "I don't think there are lint issues" |
| "File exists" | `ls -la path/to/file` showing the file | "I created it in the last commit" |
| "AC is met" | File:line reference showing the implementation | "This is addressed by the changes" |
| "PR is merged" | PR URL showing "Merged" status | "I submitted the PR" |
| "Deploy is green" | Deploy dashboard status output | "It should deploy fine" |

## Evidence Capture Protocol

Before claiming any task is done, run verification commands and capture their output. The output must be included in the completion claim (closing comment, session summary, or PR description).

```bash
# Evidence capture sequence (adapt to project toolchain)
echo "=== Tests ===" && npm test 2>&1 | tail -20
echo "=== Lint ===" && npm run lint 2>&1 | tail -10
echo "=== Build ===" && npm run build 2>&1 | tail -10
echo "=== Type Check ===" && npx tsc --noEmit 2>&1 | tail -10
```

**The output must be shown, not summarized.** Do not replace command output with "all checks passed." Show the actual lines.

## When Evidence Is Required

Evidence is required at every completion boundary:

| Boundary | Evidence Required |
|----------|------------------|
| Task In Progress → Done | AC references, test output |
| Creating a PR | Test output, lint output, build output |
| Merging a PR | CI status, deploy status |
| Publishing a release | Full verification checklist |
| Claiming an AC is addressed | File:line reference |
| Marking a sub-task complete | Output showing the deliverable |

## Anti-Rationalization Rules

Language models are prone to rationalization — generating plausible claims about system state without verifying them. These rules block the most common patterns.

### Blocked Phrases

The following phrases, when used as justification for a completion claim, indicate rationalization and must be replaced with actual verification:

| Blocked Phrase | What To Do Instead |
|---------------|-------------------|
| "I believe the tests pass" | Run the tests. Show the output. |
| "This should work" | Run it. Show the output. |
| "The build probably succeeds" | Build it. Show the output. |
| "I'm pretty sure this is correct" | Verify it. Show the evidence. |
| "Based on my understanding" | Check the actual state. Show what you found. |
| "I think this addresses the criterion" | Point to the specific file:line. |
| "It looks like it works" | Run the verification command. Show the output. |
| "I expect this to pass" | Run it and find out. Show the result. |
| "This is likely fine" | Check. Show that it's fine. |
| "The change is straightforward" | Straightforward changes still need verification. Run it. |

### Loophole Closures

**"Too Small to Test"** — Small changes are where the most dangerous bugs hide (off-by-one, missing `await`, wrong variable). There is no change too small to verify. If a test suite exists, run it. Acceptable exception: documentation-only changes (markdown, comments) with no code changes may skip test execution, but file existence verification still runs.

**"I Already Ran It"** — Session state is not evidence. Between "earlier" and "now," other files may have changed, dependencies may have updated, or memory may be incorrect. Verification runs at the completion boundary, not 10 minutes before.

**"It's Just a Refactor"** — Refactors are the most common source of subtle breakage (import resolution, circular deps, test mocking). Refactors are not exempt from verification.

**"CI Will Catch It"** — CI is a safety net, not a substitute for local verification. Local verification takes 30-120 seconds; CI takes 5-30 minutes. Never push code that you have not verified locally.

## User Override

User confirmation explicitly bypasses evidence checks for the specific item confirmed. When a user says "yes, close it" or "that's fine, proceed," the evidence requirement for that specific action is satisfied by user authority.

This override applies only to the specific item the user confirmed — it does not grant blanket bypass for all evidence checks in the session. The user's confirmation is itself recorded as the evidence in the closing comment: "Closed per user confirmation (no automated verification for [specific item])."

## Who References This File

- `/close` command — evidence enforcement in closing comments
- `branch-finish` skill — pre-completion verification
- `quality-scoring` skill — evidence required for scoring inputs
- `session-exit` skill — closing comment evidence
- `pr-dispatch` skill — pre-review evidence snapshot
- `tdd-enforcement` skill — evidence at each RED-GREEN-REFACTOR cycle
