---
name: debugging-methodology
description: |
  Spec-aware systematic debugging methodology for CCC Stage 5-6 implementation.
  Uses acceptance criteria and .ccc-state.json task context to scope root cause
  investigation and prevent shotgun debugging. Enforces a 4-phase loop: scope,
  hypothesize, test, verify — anchored to the active spec rather than ad hoc guessing.
  Use when a test fails during implementation, when behavior diverges from spec expectations,
  when a bug is discovered during code review, or when debugging a regression.
  Trigger with phrases like "debug this", "systematic debugging", "root cause analysis",
  "why is this failing", "spec-aware debugging", "hypothesis test verify",
  "shotgun debugging", "narrow the scope", "what's the root cause".
compatibility:
  surfaces: [code]
  tier: code-only
---

# Debugging Methodology

Spec-anchored systematic debugging for CCC Stage 5-6. This skill replaces ad hoc "try things until it works" debugging with a structured methodology that uses the active spec as the source of truth for expected behavior.

## The Problem

Debugging without methodology produces:

- **Shotgun fixes:** Random changes hoping something works. Each change introduces a new variable, making the actual root cause harder to isolate.
- **Scope explosion:** Starting with "this test fails" and ending up refactoring three modules because "they looked wrong too." The bug is in the implementation, not in every adjacent file.
- **Assumption recycling:** Trying the same category of fix repeatedly (e.g., type conversions) because the first attempt "almost worked." Two failed approaches in the same category means the root cause is elsewhere.
- **Spec amnesia:** Debugging to match observed behavior rather than specified behavior. The code might be "working" by one definition and completely wrong by the spec's definition.

## The 4-Phase Debugging Loop

Every debugging session follows this loop. No shortcuts, no skipping phases.

```
SCOPE → HYPOTHESIZE → TEST → VERIFY
  ↑                              |
  └──── (hypothesis failed) ─────┘
```

### Phase 1: SCOPE — Define the Problem Boundaries

**Goal:** Establish what is wrong, where it is wrong, and what "correct" looks like — according to the spec.

**Process:**

1. **Read the spec.** Before touching any code, open the PR/FAQ or issue description linked in `.ccc-state.json`. Find the acceptance criterion that the failing behavior relates to.

2. **State the expected behavior.** Write it down explicitly:
   ```
   EXPECTED: API returns 200 with paginated results when query matches
   ACTUAL: API returns 500 with "TypeError: Cannot read property 'map' of undefined"
   SPEC REF: AC #3 — "Results paginated at 20 per page"
   ```

3. **Identify the deviation boundary.** Where does actual behavior diverge from expected? This is not "somewhere in the codebase" — narrow it:
   - Which test fails? (Specific test name and assertion)
   - Which endpoint/function/component? (Specific file and function)
   - At which step in the data flow? (Input transformation? Business logic? Output serialization?)

4. **Set the debugging scope.** The scope is the minimum set of files and functions between the deviation point and the expected behavior. Everything outside this scope is off-limits unless evidence points there.

**Scope boundaries from spec:**

The acceptance criteria define what you are debugging _toward_. If a fix achieves the acceptance criterion, the bug is fixed — even if adjacent code "could be better." Resist the urge to improve code outside the debugging scope.

**Anti-patterns:**

| Behavior | Problem | Fix |
|----------|---------|-----|
| "Let me look at the whole module" | Scope explosion | Identify the specific function that fails |
| "This might be related to X" | Speculation without evidence | Stay in SCOPE until you have a clear boundary |
| "I'll just add some logging everywhere" | Instrumentation spray | Add logging at the deviation boundary only |
| "The error message says TypeError" | Surface-level reading | Trace the TypeError to its origin, not its symptom |

### Phase 2: HYPOTHESIZE — Form a Testable Theory

**Goal:** Propose a specific, falsifiable explanation for the bug.

**Process:**

1. **Review the evidence.** Read the failing test, the error output, the stack trace. Read the code at the deviation boundary identified in SCOPE.

2. **Form exactly one hypothesis.** Not a list of possibilities — one specific theory:
   ```
   HYPOTHESIS: The `results` variable is undefined because `queryDatabase()`
   returns null when the search term contains special characters, but the
   calling code assumes it always returns an array.
   ```

3. **Predict the test outcome.** If your hypothesis is correct, what specific behavior would you observe?
   ```
   PREDICTION: If I log the return value of queryDatabase() with a special
   character input, it will be null instead of an empty array.
   ```

4. **Ensure the hypothesis is falsifiable.** If there is no observation that would disprove your theory, the hypothesis is too vague. Sharpen it.

**Hypothesis quality checklist:**

- [ ] **Specific:** Points to a concrete code location and condition
- [ ] **Falsifiable:** A test can prove it wrong
- [ ] **Consistent:** Explains all observed symptoms, not just one
- [ ] **Minimal:** Does not require multiple independent failures to be true

**One hypothesis at a time.** Testing multiple hypotheses simultaneously (e.g., making 3 changes and seeing if the test passes) destroys the ability to identify the actual cause. If the test passes after 3 changes, which one was the fix? You don't know, and you've potentially introduced unnecessary changes.

### Phase 3: TEST — Validate or Falsify

**Goal:** Execute a targeted test that either confirms or disproves your hypothesis.

**Process:**

1. **Design the test.** Based on your prediction from Phase 2, what is the minimal action that will confirm or deny?
   - Add a targeted log statement at the deviation point
   - Write a unit test that isolates the suspected condition
   - Run the existing failing test with modified input that isolates the variable
   - Use a debugger breakpoint at the hypothesized failure point

2. **Execute the test.** Run it and observe the output. Compare against your prediction.

3. **Evaluate the result:**

   - **Hypothesis confirmed:** The observation matches your prediction. Move to VERIFY.
   - **Hypothesis falsified:** The observation contradicts your prediction. Return to HYPOTHESIZE with the new information. Your evidence set is now larger.
   - **Inconclusive:** The test didn't clearly confirm or deny. The test was too broad or the hypothesis too vague. Sharpen both and retry.

**Instrumentation discipline:**

- Add the minimum instrumentation needed to test your hypothesis
- Remove instrumentation after the test (or before commit)
- Prefer automated tests over manual observation — automated tests are repeatable
- Never leave debug logging in production code

### Phase 4: VERIFY — Confirm the Fix

**Goal:** Ensure the fix resolves the original problem without introducing new problems.

**Process:**

1. **Implement the fix.** Based on the confirmed hypothesis, make the minimum change to correct the behavior.

2. **Run the failing test.** It should now pass. If it doesn't, return to HYPOTHESIZE — your understanding of the root cause is incomplete.

3. **Run the full test suite.** No regressions. If the fix breaks other tests, the fix is too broad or has side effects.

4. **Verify against the spec.** Re-read the acceptance criterion from Phase 1. Does the fix achieve the specified behavior? A fix that makes the test pass but doesn't satisfy the acceptance criterion is not a fix.

5. **Remove debugging artifacts.** Delete log statements, breakpoints, temporary test modifications. The commit should contain only the fix.

6. **Document the root cause.** In the issue comment or commit message:
   ```
   Root cause: queryDatabase() returns null for special character inputs.
   The SQL LIKE clause was not escaping % and _ characters, causing a
   query syntax error that the ORM silently converted to a null return.
   Fix: Added escapeSpecialChars() before LIKE clause construction.
   ```

## Retry Budget Integration

This skill enforces the retry budget from the `execution-modes` skill:

1. **First hypothesis cycle (SCOPE → HYPOTHESIZE → TEST → VERIFY):** Use freely. This is normal debugging.

2. **If the first hypothesis fails:** Document what was tried and why it failed. Form a _different_ hypothesis — not a variation of the same one.

3. **If the second hypothesis fails:** STOP. You have exhausted the 2-approach retry budget. Escalate with evidence:
   ```
   ESCALATION — [Issue ID]

   Approach 1: [hypothesis, test, result, why it was wrong]
   Approach 2: [hypothesis, test, result, why it was wrong]

   Evidence suggests the root cause is outside the current debugging scope.
   Requesting direction: [specific question for the human]
   ```

**The retry budget is per-bug, not per-session.** If a session ends mid-debugging, document the hypothesis state in the issue comment so the next session doesn't repeat dead-end approaches.

## Spec-Aware Debugging Scope

### Using .ccc-state.json

When `.ccc-state.json` tracks the current task, the debugging scope is constrained:

```json
{
  "current_task": "CIA-123",
  "execution_mode": "tdd",
  "debugging_state": {
    "phase": "HYPOTHESIZE",
    "deviation": "test_pagination_returns_20_items fails with actual=50",
    "spec_criterion": "AC #3: Results paginated at 20 per page",
    "scope_files": ["src/api/search.ts", "src/lib/pagination.ts"],
    "hypothesis_count": 1,
    "hypotheses_tried": [
      {
        "theory": "Page size parameter not passed to query",
        "result": "FALSIFIED — parameter is passed, issue is downstream"
      }
    ]
  }
}
```

### Debugging During TDD

When debugging occurs within a TDD cycle (a test you just wrote fails in an unexpected way):

1. The RED test defines the expected behavior — no need to re-read the spec separately.
2. The SCOPE is the code you wrote in the GREEN phase, not the entire codebase.
3. If the bug is in the test itself, that's a test quality issue, not a code bug. Fix the test and re-enter RED.

### Debugging Review Findings

When debugging is triggered by an adversarial review or code review finding:

1. The reviewer's finding statement replaces "ACTUAL behavior" in SCOPE.
2. The spec acceptance criterion is still the "EXPECTED behavior."
3. If the reviewer's finding contradicts the spec, this is a spec issue, not a code issue — escalate to `review-response` skill.

## Common Failure Modes

### 1. Shotgun Debugging

**Symptom:** Making 5+ changes without running a test between them. "Let me try this… and this… and maybe this too."

**Fix:** One change per TEST phase. Run the test after every change. If you're making multiple changes, you don't have a hypothesis — you're guessing.

### 2. Root Cause Confusion

**Symptom:** Fixing the symptom instead of the cause. The test passes, but the underlying problem will resurface elsewhere.

**Fix:** Ask "why" one more time. If the fix is "add a null check," ask why the value is null. The null check may be necessary, but the root cause is whatever produces the null.

### 3. Scope Creep

**Symptom:** Starting to "fix" code that isn't related to the bug. "While I'm here, this function could be better."

**Fix:** Debugging scope = the deviation boundary from Phase 1. Everything else is a separate issue. Create it if needed, don't fix it now.

### 4. Assumption Anchoring

**Symptom:** Repeatedly testing variations of the same hypothesis. "Maybe it's the encoding… no, maybe it's a different encoding… what about this encoding?"

**Fix:** If two variations of the same hypothesis fail, the root cause is not in that category. Step back to SCOPE and look for a completely different explanation.

### 5. Debug Logging Addiction

**Symptom:** Adding console.log/print statements to every function in the call chain. 200 lines of log output with no clear signal.

**Fix:** Add ONE log statement at the deviation boundary. Move it based on results (binary search the call chain). Remove each log after it provides its information.

### 6. Environment Blame

**Symptom:** "It works on my machine." Assuming the bug is in the environment, not the code.

**Fix:** Environment differences ARE valid hypotheses — but test them like any other hypothesis. If the same test fails in CI but passes locally, the hypothesis is a specific environment difference (e.g., node version, timezone, path separator), not "something about CI."

## Integration with Execution Modes

| Mode | Debugging Scope Adjustment |
|------|---------------------------|
| `exec:tdd` | Scope is limited to code written in the current GREEN phase. The RED test is the authority. |
| `exec:quick` | Scope is the changed files only. For quick fixes, the debugging budget is 1 hypothesis — if it fails, upgrade to `exec:tdd`. |
| `exec:pair` | Share the SCOPE output with the human. Collaborative hypothesis formation. |
| `exec:checkpoint` | Document debugging state at each checkpoint. The human reviews hypotheses tried before approving continuation. |

## Cross-Skill References

- **execution-modes** — Defines the retry budget (max 2 failed approaches before escalation). This skill implements the budget within the debugging loop.
- **drift-prevention** — If debugging leads to changes outside the spec scope, drift-prevention flags it as potential drift.
- **tdd-enforcement** — When debugging during a TDD cycle, the RED test defines the expected behavior. The debugging scope is the GREEN phase code.
- **review-response** — When debugging is triggered by a reviewer finding, review-response handles the triage. This skill handles the technical investigation.
