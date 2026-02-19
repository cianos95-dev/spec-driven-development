# Closure Rules Matrix

> **Canonical reference.** All closure logic (`/close`, `branch-finish`, `issue-lifecycle`, session-exit) must reference this file — never inline a duplicate matrix.

Closure is the highest-stakes status transition. These rules prevent premature closure while allowing full agent autonomy for clear-cut cases.

## Decision Matrix

| # | Condition | Action | Rationale |
|---|-----------|--------|-----------|
| 1 | Agent assignee + single PR + merged + deploy green | **AUTO-CLOSE** | Agent owns end-to-end. Merge is the quality gate. Deploy green confirms no regression. |
| 2 | Agent assignee + single PR + merged + no deploy pipeline | **AUTO-CLOSE** with note | Same as #1 but note that deployment was not verified. |
| 3 | Agent assignee + multiple PRs + all merged | **PROPOSE** with PR summary | Multi-PR efforts are complex enough to warrant human sign-off. List all PRs and their status. |
| 4 | Agent assignee + PR open (not merged) | **BLOCK** | Cannot close while PR is in review. |
| 5 | Human assignee (any condition) | **NEVER** auto-close | Human-owned issues are closed by humans. Agent may comment with evidence but must not change status. |
| 6 | `needs:human-decision` label present | **PROPOSE** | A human decision is explicitly pending. Agent cannot resolve unilaterally. |
| 7 | `exec:pair` label present | **PROPOSE** with evidence | Shared ownership requires explicit sign-off from the human participant. |
| 8 | Agent assignee + no PR + (`type:spike` OR `type:chore`) + all ACs checked | **AUTO-CLOSE** with deliverable summary | Non-code tasks with evidence. Spikes produce knowledge, chores produce config/cleanup. |
| 9 | Agent assignee + no PR + (`type:feature` OR `type:bug`) | **PROPOSE** with deliverable summary | A PR is expected for features and bugs. Missing PR needs explanation. |
| 10 | No PR linked (other types) | **PROPOSE** with deliverable summary | No merge trigger. Summarize what was delivered and ask for confirmation. |
| 11 | Unresolved comments or discussion | **BLOCK** | Flag unresolved threads. Cannot close with open questions. |

## Conflict Resolution

If multiple conditions apply, use the **most restrictive** action. The hierarchy is:

```
BLOCK > NEVER auto-close > PROPOSE > AUTO-CLOSE
```

Example: Agent assignee + single PR merged + deploy green (→ AUTO-CLOSE) but `exec:pair` label present (→ PROPOSE). Result: **PROPOSE**.

## Quality Gate

Before applying the matrix, the quality score must be evaluated:

| Score | Eligibility |
|-------|-------------|
| 80-100 | Auto-close eligible (apply matrix above) |
| 60-79 | Propose closure (regardless of matrix result) |
| 0-59 | Block closure (specific deficiencies listed) |

Quality score is calculated as:

```
total = (test_score * W_test) + (coverage_score * W_coverage) + (review_score * W_review)
```

Default weights: `W_test = 0.40`, `W_coverage = 0.30`, `W_review = 0.30`.

Projects may override weights in `.ccc-preferences.yaml`:

```yaml
quality:
  weights:
    test: 0.50
    coverage: 0.30
    review: 0.20
  thresholds:
    auto_close: 90
    propose: 70
```

If no overrides exist, defaults apply.

## Evidence Requirement

**Every Done transition requires a closing comment.** The comment must include evidence: PR link, deliverable reference, test output, decision rationale, or explicit human confirmation. Status changes without evidence are not permitted. See `references/evidence-mandate.md` for the full evidence protocol.

## Recovery Commands

When `/close` returns BLOCK, include the appropriate recovery command in the output:

| Block Reason | Recovery Command |
|-------------|-----------------|
| PR not merged | `gh pr checks <PR#>` — check CI status, then `gh pr merge <PR#> --squash` if green |
| PR failing CI | `gh pr checks <PR#>` — identify failing checks, fix and push |
| Unresolved comments | `gh pr view <PR#> --comments` — review and resolve each thread |
| Quality score < 60 | Run `/ccc:review` to identify gaps, then address each deficiency |
| Quality score 60-79 | List specific gaps. Fix or confirm acceptable with user. |

## Who References This File

- `/close` command — Step 2 closure evaluation
- `branch-finish` skill — merge mode marks "closure-ready" per these rules
- `issue-lifecycle` skill — ownership and closure guidance
- `session-exit` skill — end-of-session closure sweep
