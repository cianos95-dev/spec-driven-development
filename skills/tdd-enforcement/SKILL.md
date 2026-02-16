---
name: tdd-enforcement
description: |
  Enforce TDD red-green-refactor discipline during CCC Stage 5-6 implementation.
  Derives test cases from spec acceptance criteria and PR/FAQ documents rather than
  generic test suggestions. Blocks implementation code before a failing test exists.
  Tracks cycle state across the session and integrates with .ccc-state.json task context.
  Use when implementing features with testable acceptance criteria in the CCC workflow,
  when the execution mode is exec:tdd, or when you need to enforce test-first discipline.
  Trigger with phrases like "enforce TDD", "red green refactor", "test first",
  "write a failing test", "no implementation yet", "TDD cycle", "exec:tdd mode",
  "derive tests from spec", "acceptance criteria to tests".
---

# TDD Enforcement

Strict red-green-refactor discipline for CCC Stage 5-6 implementation. This skill enforces _how_ to do TDD within the CCC workflow. For _when_ to use TDD (mode selection), see the `execution-modes` skill.

## The Problem

Claude's natural tendency is to write implementation first, then tests. This inversion produces:

- Tests that verify the implementation rather than the requirement
- Missing edge cases that would have been caught by writing the test first
- Acceptance criteria that are "covered" but not _tested_ — the test asserts what the code does, not what the spec demands
- Scope drift because implementation runs ahead of verification

TDD enforcement reverses this: the spec drives the tests, and the tests drive the implementation.

## Relationship to Execution Modes

The `execution-modes` skill defines `exec:tdd` as a mode and provides a decision heuristic for _when_ to use it:

> **When:** Well-defined acceptance criteria that can be expressed as automated tests. The requirements are clear enough to write a failing test before writing implementation code.

This skill takes over once `exec:tdd` is selected. It enforces the _discipline_ of the red-green-refactor loop, derives test cases from spec acceptance criteria, and prevents the common shortcuts that undermine TDD.

If you find yourself unable to write a failing test, the scope is not well-defined enough for TDD. Downgrade to `exec:pair` per the execution-modes heuristic.

## The Three Phases

### Phase 1: RED — Write a Failing Test

**Goal:** Express a single acceptance criterion as an automated test that fails.

**Process:**

1. **Read the spec.** Open the PR/FAQ or issue description linked in `.ccc-state.json`. Identify the acceptance criteria checklist.

2. **Select the next uncovered criterion.** Work through criteria in dependency order — test foundational behavior before derived behavior.

3. **Translate the criterion to a test assertion.** The test name should read like the acceptance criterion:
   ```
   AC: "API returns 404 when resource does not exist"
   Test: test_returns_404_when_resource_not_found()
   ```

4. **Write ONLY the test.** No implementation code. No helper functions for the implementation. No "let me just stub out the interface first." The test file is the only file you touch in the RED phase.

5. **Run the test. Confirm it fails.** If the test passes without implementation, either:
   - The behavior already exists (skip this criterion, mark it as already covered)
   - The test is wrong (it's not actually testing the criterion)
   - The assertion is too weak (tighten it)

6. **Verify the failure message is meaningful.** A good RED failure says _what_ is missing. A bad RED failure says "undefined is not a function." If the failure message is unhelpful, improve the test before moving to GREEN.

**Anti-rationalization blocks:**

| Thought | Response |
|---------|----------|
| "Let me just write a quick implementation first" | NO. Write the test first. This is the entire point of TDD. |
| "I need the interface to know what to test" | Write the test as if the interface already exists. The test defines the interface. |
| "This criterion isn't really testable" | If it's in the acceptance criteria, it must be verifiable. Find a way to test it, or flag it as needing spec clarification. |
| "Let me write all the tests at once" | NO. One criterion, one test, one RED-GREEN-REFACTOR cycle. Batching tests defeats the feedback loop. |
| "The test framework needs setup first" | Test infrastructure setup is pre-TDD work. Do it before entering the RED phase. Don't conflate setup with the first test. |

### Phase 2: GREEN — Make It Pass

**Goal:** Write the _minimum_ implementation code to make the failing test pass.

**Process:**

1. **Focus on the single failing test.** Do not think about the next criterion. Do not think about "good design." Make this one test pass.

2. **Write the minimum code.** If a hardcoded return value makes the test pass, that is a valid GREEN step. The refactor phase handles design quality.

3. **Run the test. Confirm it passes.** All previously passing tests must still pass. If a new test breaks an old test, you have a design problem — do not fix it by weakening the old test.

4. **Do not add functionality beyond the test.** No "while I'm here" additions. No "this will obviously be needed later." If it's not required by a failing test, it doesn't exist yet.

**Minimum code principle:**

The GREEN phase deliberately produces "ugly" code. This is correct. Premature design in GREEN leads to:

- Over-engineering beyond what tests require
- Implementation assumptions that haven't been validated by tests
- Scope creep disguised as "good engineering"

Trust the process: RED defines what's needed, GREEN makes it work, REFACTOR makes it clean.

**Anti-rationalization blocks:**

| Thought | Response |
|---------|----------|
| "This code is ugly, let me clean it up" | That's the REFACTOR phase. Make the test pass first. |
| "I should add error handling for edge cases" | Is there a test for those edge cases? No? Then don't add the handling. Write a test first. |
| "Let me also implement the next feature while I'm in this file" | NO. One RED-GREEN-REFACTOR cycle at a time. |
| "This obviously needs a proper abstraction" | Maybe. But that's REFACTOR, not GREEN. Make it work first. |

### Phase 3: REFACTOR — Clean Up

**Goal:** Improve code quality without changing behavior. All tests must remain green throughout.

**Process:**

1. **Run all tests. Confirm green.** This is your baseline. Every refactoring step must maintain this state.

2. **Look for code smells introduced in GREEN:**
   - Duplication across test subjects
   - Magic numbers or hardcoded values
   - Missing abstractions (3+ similar code blocks)
   - Unclear naming
   - Functions doing too many things

3. **Refactor one thing at a time.** After each change, run tests. If any test fails, the refactoring introduced a behavior change — revert and try again.

4. **Refactor tests too.** Test code is production code. Apply the same quality standards: remove duplication, improve naming, extract helpers for repeated setup.

5. **Stop when the code is clean enough.** "Clean enough" means: another developer could read it and understand the intent without comments. Do not gold-plate.

**Anti-rationalization blocks:**

| Thought | Response |
|---------|----------|
| "This refactoring needs a new test" | Then it's not a refactoring — it's a new feature. Go back to RED. |
| "I'll skip refactoring, the code is fine" | You are the worst judge of your own code quality. Spend at least 2 minutes looking for improvements. |
| "Let me refactor the entire module while I'm here" | Refactor only what you touched. Scope creep in refactoring is still scope creep. |

## Spec-Driven Test Derivation

The unique value of TDD within CCC (vs. generic TDD) is that test cases are derived from the spec, not invented ad hoc.

### From Acceptance Criteria to Tests

Each acceptance criterion in the PR/FAQ maps to one or more test cases:

```
Spec AC: "Users can search by keyword with results ranked by relevance"

Test cases derived:
1. test_search_returns_results_matching_keyword()
2. test_search_results_ordered_by_relevance_score()
3. test_search_with_no_matches_returns_empty()
4. test_search_with_special_characters_handled()
```

**Derivation rules:**

1. **Happy path first.** The AC as stated is usually the happy path. Test it directly.
2. **Invert for sad path.** What happens when the precondition fails? (No matches, invalid input, missing resource)
3. **Edge the boundaries.** Empty input, maximum length, off-by-one, concurrent access.
4. **Error the externals.** What if a dependency fails? (Network timeout, database error, API rate limit)

### From PR/FAQ to Test Strategy

The PR/FAQ structure maps to testing layers:

| PR/FAQ Section | Test Layer | What to Test |
|----------------|-----------|--------------|
| Press Release (user outcome) | Integration/E2E | Full user workflow produces stated outcome |
| Customer Problem | Edge cases | Scenarios that recreate the original problem |
| Solution | Unit tests | Individual components implement the solution |
| FAQ - Technical | Unit + Integration | Technical constraints are enforced |
| FAQ - Business | Acceptance | Business rules produce correct results |
| Pre-Mortem | Failure tests | Each failure mode is detected/handled |

### Coverage Tracking

Maintain a mapping between acceptance criteria and test status:

```markdown
## Test Coverage — [Issue ID]

| # | Acceptance Criterion | Test(s) | Status |
|---|---------------------|---------|--------|
| 1 | Users can search by keyword | `test_search_*` (4 tests) | GREEN |
| 2 | Results paginated at 20/page | `test_pagination_*` (3 tests) | RED (current) |
| 3 | Admin can override rankings | — | NOT STARTED |
```

Update this table after each RED-GREEN-REFACTOR cycle. When all criteria reach GREEN, the implementation phase is complete.

## Cycle State Management

TDD state persists across the session. If context compaction occurs or you lose track, reconstruct state from:

1. **Test results:** Run the full test suite. Passing tests = completed criteria. Failing tests = current RED phase.
2. **Git diff:** Uncommitted changes show the current phase (test-only changes = RED, implementation changes = GREEN/REFACTOR).
3. **Coverage table:** If maintained per the template above, shows exactly where you are.

### Session Boundary Protocol

At the end of a session mid-TDD:

1. **Commit the current state** with a message indicating TDD phase:
   ```
   wip(tdd): RED — failing test for [criterion description]
   wip(tdd): GREEN — [criterion] passing, pre-refactor
   wip(tdd): REFACTOR — [criterion] complete
   ```

2. **Update the issue comment** with the coverage table so the next session can resume.

3. **Do not leave in GREEN without REFACTOR.** If time is limited, either complete the refactor or revert to the last clean RED state.

### Integration with .ccc-state.json

When `.ccc-state.json` tracks the current task, the TDD cycle adds context:

```json
{
  "current_task": "CIA-123",
  "execution_mode": "tdd",
  "tdd_state": {
    "phase": "RED",
    "current_criterion": "Results paginated at 20/page",
    "criteria_completed": 1,
    "criteria_total": 5,
    "failing_test": "test_pagination_returns_20_items"
  }
}
```

This state enables drift detection: if implementation changes appear without a corresponding RED test, the drift-prevention skill can flag the violation.

## Common Failure Modes

### 1. "Test After" Disguised as TDD

**Symptom:** Implementation and test written in the same commit. The test passes on first run.

**Fix:** If a test passes without ever failing, it was not written first. Delete the test, delete the implementation, start RED properly.

### 2. Overly Broad Tests

**Symptom:** A single test covers multiple acceptance criteria. Failure doesn't indicate which criterion is broken.

**Fix:** One test per criterion (at minimum). A test that checks 5 things is 5 tests wearing a trench coat.

### 3. Testing Implementation, Not Behavior

**Symptom:** Tests assert internal state (private methods, data structures) rather than observable behavior.

**Fix:** Test the _what_, not the _how_. "It returns the correct result" not "it calls the internal helper method." Implementation details change in REFACTOR — behavior doesn't.

### 4. RED Phase Paralysis

**Symptom:** Spending 20+ minutes on a single test without writing it. Usually caused by unclear acceptance criteria.

**Fix:** The problem is upstream. The acceptance criterion is ambiguous. Flag it in the issue, request clarification, and move to the next testable criterion.

### 5. Skipping REFACTOR

**Symptom:** Rapid RED-GREEN-RED-GREEN cycles without cleanup. Code quality degrades with each cycle.

**Fix:** REFACTOR is mandatory, not optional. Even if "the code is fine," take 2 minutes to look. The habit matters more than any single cleanup.

### 6. Gold-Plating in REFACTOR

**Symptom:** Refactoring session grows to 30+ minutes. Extracting abstractions for patterns that appear twice. Adding generalization "for the future."

**Fix:** Refactoring scope = files touched in GREEN. Time budget = roughly equal to GREEN time. If refactoring takes longer than implementation, you're over-engineering.

## Guard Rails

1. **No implementation without RED.** If you catch yourself writing implementation code without a failing test, stop. Write the test first. This is non-negotiable.

2. **One cycle at a time.** Complete RED-GREEN-REFACTOR for one criterion before starting the next. No batching.

3. **Tests run after every phase change.** After writing the test (RED): run. After implementation (GREEN): run. After refactoring: run. No exceptions.

4. **Failing test count = 1.** During GREEN, exactly one test should be failing (the current one). If multiple tests fail, you've broken something — fix it before continuing.

5. **30-minute escape hatch.** If a single RED-GREEN-REFACTOR cycle takes more than 30 minutes, the criterion is too large. Split it into smaller criteria and test each independently.

## Cross-Skill References

- **execution-modes** — Defines `exec:tdd` mode and the decision heuristic for when TDD is appropriate. This skill assumes `exec:tdd` has already been selected.
- **drift-prevention** — Uses TDD cycle state to detect spec drift. If implementation changes appear without a corresponding failing test, drift-prevention flags it.
- **quality-scoring** — Test coverage from TDD cycles feeds into the quality score's "test coverage" dimension.
- **ship-state-verification** — Final verification that all acceptance criteria have GREEN tests before marking the issue as Done.
