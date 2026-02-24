---
name: quality-scoring
description: |
  Deterministic quality rubric for evaluating issue completion across test coverage, acceptance
  criteria coverage, and review resolution. Produces a star-graded score that drives closure decisions.
  Use when evaluating whether an issue is ready to close, understanding why closure was blocked,
  calibrating quality expectations for a project, or customizing scoring weights.
  Trigger with phrases like "quality score", "is this ready to close", "why was closure blocked",
  "evaluate completion", "score this issue", "quality rubric", "closure criteria".
compatibility:
  surfaces: [code, cowork, desktop]
  tier: universal
---

# Quality Scoring

A deterministic rubric for evaluating issue completion. The score drives closure decisions: auto-close, propose, or block.

## Star Grading Scale

Scores are displayed as stars by default. Use `--verbose` to see numeric scores alongside stars.

| Grade | Range | Label | Action |
|-------|-------|-------|--------|
| ★★★★★ | 90-100 | Exemplary | Auto-close eligible |
| ★★★★ | 80-89 | Strong | Auto-close eligible |
| ★★★ | 70-79 | Acceptable | Propose closure |
| ★★ | 60-69 | Needs Work | Propose closure |
| ★ | <60 | Inadequate | Block closure |

**Display format:** Configurable via `.ccc-preferences.yaml`:

```yaml
scoring:
  display_format: stars    # stars (default) | numeric | letter | percentage
```

| Format | Example Output |
|--------|---------------|
| `stars` | ★★★★ Strong (default) |
| `numeric` | 85 |
| `letter` | B+ |
| `percentage` | 85% |

When `--verbose` is used, both the display format and the underlying numeric score are shown:
`★★★★ Strong (85/100)`.

## Scoring Dimensions

| Dimension | Weight | What It Measures |
|-----------|--------|-----------------|
| **Test** | 40% | Test coverage, tests passing, edge cases addressed |
| **Coverage** | 30% | Acceptance criteria addressed, scope completeness |
| **Review** | 30% | Review comments resolved, adversarial findings addressed |

## Dimension Rubrics

### Test (40%)

| Score | Criteria |
|-------|----------|
| 100 | All acceptance criteria have corresponding tests; all tests pass; edge cases covered |
| 80 | Core acceptance criteria tested; all tests pass; some edge cases missing |
| 60 | Tests exist but incomplete; all tests pass |
| 40 | Tests exist but some fail |
| 20 | Minimal tests, partial failures |
| 0 | No tests or all tests fail |

**Adjustments:**
- `-10` if test coverage decreased from baseline
- `+10` if regression tests added for previously-discovered bugs
- For `exec:quick` mode: test requirement relaxed to 60 threshold (tests encouraged but not mandatory)

### Coverage (30%)

| Score | Criteria |
|-------|----------|
| 100 | Every acceptance criterion explicitly addressed with evidence |
| 80 | All criteria addressed; minor gaps in evidence |
| 60 | Most criteria addressed; 1-2 criteria partially met |
| 40 | Half of criteria addressed |
| 20 | Fewer than half addressed |
| 0 | No criteria addressed |

**Assessment method:** Read the spec's acceptance criteria checklist. For each criterion, verify:
1. Implementation exists (code change, config change, or documented decision)
2. Evidence exists (test, screenshot, manual verification, or reviewer confirmation)

### Review (30%)

| Score | Criteria |
|-------|----------|
| 100 | All review comments resolved; all adversarial findings addressed or carry-forwarded |
| 80 | All blocking comments resolved; minor comments acknowledged |
| 60 | Blocking comments resolved; some minor comments unaddressed |
| 40 | Some blocking comments unresolved |
| 20 | Most blocking comments unresolved |
| 0 | No review conducted or all comments unresolved |

**Note:** If no adversarial review was conducted (e.g., `exec:quick` mode), this dimension scores based on self-review or defaults to 70 (neutral).

## Score Calculation

```
total = (test_score * 0.40) + (coverage_score * 0.30) + (review_score * 0.30)
```

## Threshold Actions

| Grade | Score | Action | Rationale |
|-------|-------|--------|-----------|
| ★★★★-★★★★★ | **80-100** | Auto-close eligible | Quality gates met. Apply closure rules from issue-lifecycle. |
| ★★-★★★ | **60-79** | Propose closure | Close enough, but evidence gaps exist. List gaps in proposal. |
| ★ | **0-59** | Block closure | Specific deficiencies listed. Issue stays In Progress. |

**Important:** Score >= 80 makes the issue *eligible* for auto-close, but the closure rules matrix from `issue-lifecycle` still applies. A ★★★★★ score on a human-assigned issue still requires human confirmation.

## Scoring Output Format

### Default (star grading)

```markdown
## Quality Score — [Issue ID]

| Dimension | Grade | Evidence |
|-----------|-------|----------|
| Test (40%) | ★★★★ | 8/10 criteria tested, all passing, 2 edge cases missing |
| Coverage (30%) | ★★★★★ | 9/10 acceptance criteria met with evidence |
| Review (30%) | ★★★★★ | All 3 adversarial findings resolved |

**Overall: ★★★★★ Exemplary** — Auto-close eligible

### Gaps
- [ ] Edge case: empty input validation (test dimension)
- [ ] AC #7: partial — needs screenshot evidence (coverage dimension)
```

### Verbose mode (`--verbose`)

```markdown
## Quality Score — [Issue ID]

| Dimension | Grade | Score | Evidence |
|-----------|-------|-------|----------|
| Test (40%) | ★★★★ | 85 | 8/10 criteria tested, all passing, 2 edge cases missing |
| Coverage (30%) | ★★★★★ | 90 | 9/10 acceptance criteria met with evidence |
| Review (30%) | ★★★★★ | 100 | All 3 adversarial findings resolved |

**Overall: ★★★★★ Exemplary (90/100)** — Auto-close eligible

### Gaps
- [ ] Edge case: empty input validation (test dimension)
- [ ] AC #7: partial — needs screenshot evidence (coverage dimension)
```

## Star Grading Conversion Rules

When converting a numeric score to stars:

1. Calculate the weighted total as before (0-100 scale)
2. Map to star grade using the threshold table above
3. Per-dimension scores also get star grades for display
4. The label (Exemplary/Strong/Acceptable/Needs Work/Inadequate) always accompanies stars

**Letter grade mapping** (when `scoring.display_format: letter`):

| Grade | Range |
|-------|-------|
| A+ | 95-100 |
| A | 90-94 |
| B+ | 85-89 |
| B | 80-84 |
| C+ | 75-79 |
| C | 70-74 |
| D | 60-69 |
| F | <60 |

## Per-Project Customization

Projects can override default weights and thresholds in their CLAUDE.md:

```yaml
# Quality scoring overrides
sdd_quality:
  weights:
    test: 0.50      # Higher test weight for safety-critical projects
    coverage: 0.30
    review: 0.20
  thresholds:
    auto_close: 90   # Stricter threshold
    propose: 70
  adjustments:
    exec_quick_test_floor: 50  # Lower test floor for quick mode
```

If no overrides exist, the defaults from this skill apply.

## Integration with Closure

The `/ccc:close` command calls quality scoring as its first step:

1. Calculate score across all three dimensions
2. Convert to star grade (or configured display format)
3. Apply threshold rules to determine action (auto-close, propose, block)
4. If auto-close eligible, check closure rules matrix (issue-lifecycle skill)
5. Execute the appropriate action with the grade as evidence in the closing comment
