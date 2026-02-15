# CIA-303 Pre-Review Codebase Scan

**Scan Date:** 2026-02-15
**Spec:** CIA-303 — Insights-powered adaptive methodology (drift prevention, hooks, indexing, quality scoring)

## Executive Summary

The SDD plugin has **strong foundational implementations** for 6 of 7 capability areas. The 7th (adaptive methodology loop) is architecturally defined but not implemented — that IS CIA-303's scope.

**Three-layer monitoring stack status:**
- Layer 1 (Structural via cc-plugin-eval): Fully implemented
- Layer 2 (Runtime via /sdd:insights): Fully implemented
- Layer 3 (Adaptive loop): Architecture only — CIA-303 scope

## Existing Files by Capability

### 1. Insights Extraction
- `commands/insights.md` — Full command with 4 modes (archive, review, trend, suggest)
- `skills/insights-pipeline/SKILL.md` — Pattern extraction, HTML-to-MD rules
- **Gap:** No example archive file; no preferences config for insights

### 2. Drift Prevention
- `skills/drift-prevention/SKILL.md` — 6-step re-anchoring protocol
- `commands/anchor.md` — Manual trigger with spec/git/issue re-reads
- `hooks/post-tool-use.sh` — Basic drift warning at 20+ uncommitted files
- **Gap:** Hook threshold (20 files) vs skill threshold (30 min / 50% context) not aligned

### 3. Hook Enforcement
- `skills/hook-enforcement/SKILL.md` — SessionStart, PreToolUse, PostToolUse, Stop
- `hooks/hooks.json` — Full configuration with circuit-breaker integration
- `hooks/session-start.sh`, `hooks/post-tool-use.sh`, `hooks/stop.sh`
- `hooks/scripts/circuit-breaker-pre.sh`, `circuit-breaker-post.sh` — Error detection + blocking
- `tests/test-circuit-breaker.sh` — 16 test cases
- **Gap:** PreToolUse scope check is a stub (logic incomplete)

### 4. Codebase Indexing
- `commands/index.md` — Full/incremental scan, staleness tracking
- `skills/codebase-awareness/SKILL.md` — Module map, pattern detection, integration mapping
- `examples/sample-index-output.md` — 16-module realistic example
- **Gap:** None identified

### 5. Quality Scoring
- `skills/quality-scoring/SKILL.md` — 0-100 rubric (test 40%, coverage 30%, review 30%)
- `tests/test-star-grading.sh` — 16 test cases
- **Gap:** None identified

### 6. Plugin Evaluation (Layers 1 & 2)
- `skills/observability-patterns/SKILL.md` — Full 3-layer architecture defined
- `skills/observability-patterns/references/structural-validation.md` — cc-plugin-eval reference
- `.github/workflows/plugin-eval.yml` — CI pipeline (2-stage)
- **Gap:** Layer 3 marked "not yet implemented"

### 7. Adaptive Methodology (Layer 3 — CIA-303 scope)
- Architecture defined in `skills/observability-patterns/SKILL.md` lines 116-124
- Expected inputs/outputs documented
- **No implementation exists** — no script, no skill, no command, no logic

### 8. References/Read-Through Metric
- Partially addressed via quality-scoring evidence trails and closure comments
- **Gap:** No formal metric for re-read frequency or acceptance-criteria-check behavior

## Cross-Capability Dependencies

```
Layer 1 (cc-plugin-eval) ──→ Accuracy %, trigger rates
                              ↘
Layer 2 (/sdd:insights) ──→ Friction patterns, usage ──→ Layer 3 (CIA-303)
                              ↗                            ↓
drift-prevention ──→ context-management                  Methodology adjustments
hook-enforcement ──→ circuit-breaker                     (thresholds, descriptions, rules)
quality-scoring ──→ issue-lifecycle
```

## Potential Conflicts

1. **Circuit breaker exec-mode escalation** not documented in `execution-modes` skill
2. **Drift detection thresholds** misaligned: hook (20 files) vs skill (30 min / 50% context)
3. **Quality score closure eligibility (80+)** vs ownership rules precedence unclear
4. **PreToolUse hook** is a stub — scope validation not functional
5. **Insights archive format** has no schema validation for version stability
