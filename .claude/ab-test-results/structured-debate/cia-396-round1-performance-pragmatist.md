# Round 1 Review — Performance Pragmatist (Orange)

**Spec:** CIA-396 — Prototype tool capture hooks for spec conformance
**Reviewer:** Performance Pragmatist
**Date:** 2026-02-15

## Review Lens

Scaling limits, caching, resource budgets, latency impact, O() complexity.

---

## Critical Findings

### C1: Unbounded Latency on Every Write Operation

**Severity:** HIGH

PostToolUse hook fires AFTER every file write (Write, Edit, MultiEdit, NotebookEdit). The spec proposes comparing changes against acceptance criteria on every write. Complexity:

```
O(writes) × O(criteria) × O(matching_complexity)
```

For a 20-criterion spec with 50 writes per session:
- 1,000 conformance checks
- If each check takes 10ms (spec parsing + diff parsing + matching): **10 seconds of added latency per session**

**Impact:**
- Slows every write operation
- Blocks agent progress while hook executes
- User-perceivable lag if hook is slow

**Mitigation:**
1. Cache parsed spec in memory (parse once per session, not per write)
2. Use incremental diffing (only check changed lines, not full file)
3. Set hook timeout (e.g., 1 second max) and skip conformance check if exceeded
4. Consider batching: check conformance every N writes, not every write

---

### C2: Spec Parsing on Hot Path

**Severity:** HIGH

The hook needs to read and parse the active spec to extract acceptance criteria. If `SDD_SPEC_PATH` points to a large PR/FAQ document (500+ lines), parsing markdown on every write is expensive.

Worst case: 50 writes × 500ms spec parse = **25 seconds** wasted on parsing alone.

**Mitigation:**
1. Parse spec once at SessionStart hook, cache criteria in `.sdd-session-state.json`
2. PostToolUse hook reads cached criteria, not raw spec file
3. Invalidate cache if spec file mtime changes

---

### C3: No Resource Budget

**Severity:** MEDIUM

The spec has no CPU, memory, or time budget for the hook. If conformance checking is expensive (e.g., regex matching against large diffs), the hook could consume significant resources with no upper bound.

**Impact:**
- Degrades system performance
- Causes timeout errors in CI environments with strict resource limits
- Makes laptop fans spin up during development

**Mitigation:**
1. Set hook execution timeout (1-2 seconds)
2. Limit diff size processed (e.g., skip conformance check for files >10KB changed)
3. Profile hook execution during 10-issue sample test and document resource usage

---

## Important Findings

### I1: False Positive Measurement is O(n²)

**Severity:** MEDIUM

To measure false positive rate, the spec proposes testing on a "10-issue sample." This requires:
1. Running all writes for 10 issues
2. Recording conformance check results
3. Manually reviewing each flagged drift to determine if it's a true positive or false positive

For 10 issues × 50 writes/issue × 20 criteria/spec = **10,000 conformance checks to review**.

Manual review is not feasible at this scale. Automated review requires ground truth, which is expensive to generate.

**Mitigation:**
- Limit false positive measurement to HIGH-CONFIDENCE flags only (e.g., confidence > 0.8)
- Use sampling: measure FP rate on 10% of writes, extrapolate
- Accept that FP measurement is approximate, not exact

---

### I2: Log File Growth

**Severity:** LOW-MEDIUM

If conformance logs are written per-write to `.sdd-conformance-log.jsonl`, log size grows linearly with writes:

- 50 writes/session × 20 criteria/write × 200 bytes/entry = **200KB/session**
- Over 100 sessions: **20MB of logs**

Not a disaster, but unbounded growth will eventually cause disk issues.

**Mitigation:**
- Rotate logs (keep last 30 days)
- Compress old logs
- Or write summary stats instead of per-write records

---

### I3: Git Diff Overhead

**Severity:** MEDIUM

To extract file changes, the hook likely needs to run `git diff HEAD -- <file>` per write. Git is fast, but not free:

- 50 writes × 50ms git diff = **2.5 seconds per session**

For large files (e.g., package-lock.json), git diff can take seconds.

**Mitigation:**
1. Skip conformance check for known large files (package-lock, yarn.lock, etc.)
2. Use git diff --stat for size check before running full diff
3. Cache git diff results if same file is written multiple times in one session

---

## Consider

### S1: Caching Invalidation

If spec criteria are cached at SessionStart, changes to the spec during the session won't be detected. This is probably acceptable (specs shouldn't change mid-session), but worth noting.

---

### S2: Parallelization Opportunity

If conformance checking becomes a bottleneck, criteria matching could be parallelized (check multiple criteria concurrently). However, this adds complexity and isn't needed until the basic prototype proves valuable.

---

### S3: Incremental Conformance

Instead of checking ALL criteria on EVERY write, check only criteria likely to be affected by the current file. Example: if criterion is "Implement authentication in auth.ts", only check when auth.ts changes.

This requires mapping criteria to file patterns, which adds complexity but could reduce checks by 90%.

---

## What the Spec Gets Right

1. **Prototype-first approach** — Building a working prototype before committing to the pattern is smart. Allows empirical performance measurement.

2. **Decision gate** — "Adopt, modify, or reject" acknowledges this might not work. Better than blind rollout.

3. **10-issue sample** — Will surface performance issues during testing if the hook is too slow.

4. **False positive threshold** — <10% is reasonable and measurable.

---

## Quality Score

| Dimension | Score (1-5) | Rationale |
|-----------|-------------|-----------|
| **Performance** | 2 | No caching, no timeout, unbounded O(writes × criteria) complexity |
| **Scalability** | 2 | Will not scale to large specs or high write volume |
| **Resource Efficiency** | 2 | No resource budget, no profiling plan |
| **Practicality** | 4 | Prototype approach is pragmatic, but perf concerns make it unlikely to succeed |
| **Testability** | 4 | 10-issue sample will reveal perf problems empirically |

**Overall:** 2.8 / 5.0

---

## Recommendation

**REVISE**

The concept is interesting, but the spec ignores performance entirely. As written, the hook will be too slow to use in practice.

**Required changes:**
1. Add acceptance criterion: "Hook execution time per write <100ms (p95)"
2. Add acceptance criterion: "Spec parsed once per session and cached"
3. Add acceptance criterion: "Large files (>10KB diff) skipped or sampled"
4. Add to validation criteria: "Measure hook latency during 10-issue sample (p50, p95, p99)"

Without these, the prototype will fail performance testing and be rejected, wasting implementation effort.

**Architectural suggestion:** Consider moving conformance checking to a background process that runs asynchronously, so it doesn't block writes. PostToolUse hook logs writes to a queue, and a separate daemon processes conformance checks offline.
