# Codebase Scan — CIA-396

**Spec:** Prototype tool capture hooks for spec conformance
**Date:** 2026-02-15
**Repo:** `/Users/cianosullivan/Repositories/spec-driven-development/`

## Scan Objective

Find ALL existing files related to: hooks, PostToolUse, tool capture, drift detection, spec conformance, acceptance criteria comparison.

## Findings

### 1. Hook Infrastructure

**File:** `hooks/hooks.json`
- Defines hook triggers for SessionStart, PreToolUse, PostToolUse, Stop
- PostToolUse has TWO registered hooks:
  1. `hooks/post-tool-use.sh` (main hook)
  2. `hooks/scripts/circuit-breaker-post.sh` (error detection)
- PreToolUse also has TWO hooks:
  1. `hooks/pre-tool-use.sh` (file write alignment check)
  2. `hooks/scripts/circuit-breaker-pre.sh` (destructive operation blocker)

### 2. Existing PostToolUse Hook

**File:** `hooks/post-tool-use.sh` (64 lines)

Current capabilities:
- Logs tool execution to `tool-log-YYYYMMDD.jsonl` (timestamp + status)
- Detects protected branch violations (main/master/production)
- Counts uncommitted files and warns at >20 files
- Has `SDD_STRICT_MODE` for hard enforcement vs warnings

**DOES NOT CURRENTLY:**
- Parse file changes from tool output
- Compare changes against active spec's acceptance criteria
- Log per-criterion conformance
- Calculate false positive rate

### 3. Circuit Breaker PostToolUse Hook

**File:** `hooks/scripts/circuit-breaker-post.sh` (197 lines)

Different purpose — error loop detection, not spec conformance:
- Detects 3+ consecutive identical errors on same tool
- Opens circuit breaker and blocks destructive operations via pre-hook
- Auto-escalates exec mode from `quick` to `pair`
- Writes state to `.sdd-circuit-breaker.json`

### 4. PreToolUse Hook

**File:** `hooks/pre-tool-use.sh` (57 lines)

Pre-flight check (BEFORE write operations):
- Parses file path from tool call JSON
- Checks against `SDD_ALLOWED_PATHS` colon-separated list
- Blocks write if outside spec scope (strict mode) or warns
- Logs pre-write validation

**Relationship to CIA-396:** PreToolUse checks BEFORE write. PostToolUse would check AFTER write and compare actual changes to spec.

### 5. Skills Documentation

**File:** `skills/hook-enforcement/SKILL.md` (165 lines)

Documents hook patterns and enforcement levels:
- Four hooks: SessionStart, PreToolUse, PostToolUse, Stop
- PostToolUse described as checking "ownership boundary violations and log evidence"
- Enforcement levels: Minimal (SessionStart+Stop), Standard (+PostToolUse), Strict (all four)
- Environment vars: `SDD_SPEC_PATH`, `SDD_STRICT_MODE`, `SDD_LOG_DIR`

**File:** `skills/drift-prevention/SKILL.md` (111 lines)

Describes re-anchoring protocol (NOT PostToolUse hook-based):
- Manual `/sdd:anchor` command to re-read spec/git/issue/reviews
- Anchoring triggers: 30+ min session, context compaction, before claiming done
- Output format shows acceptance criteria as checked/unchecked/partially
- Detects drift by comparing implementation against spec

**Key distinction:** drift-prevention is REACTIVE (session boundary check), CIA-396 proposes PROACTIVE (write-time check).

### 6. Tool Capture Reference

**File:** `skills/observability-patterns/SKILL.md` + `references/structural-validation.md`

References `cc-plugin-eval` by sjnims — the source mentioned in CIA-396:
- 4-stage plugin evaluation framework: Analysis, Generation, Execution, Evaluation
- **Stage 3 "Execution"**: "Runs prompts against the plugin and records which components actually triggered"
- Metrics: accuracy, trigger rate, quality score, conflict count
- **DOES NOT** capture file changes or compare against specs

**Interpretation:** "tool capture" in cc-plugin-eval context means capturing which PLUGIN COMPONENTS trigger, not capturing file changes from tools. CIA-396 proposes extending this idea to file-level change capture.

### 7. Competitive Landscape

**File:** `docs/competitive-analysis.md` (lines 1-150 scanned)

Mentions related patterns from competitors:
- **cc-spec-driven (mkhrdev):** Hook enforcement at runtime (SessionStart, PostToolUse, Stop) — architecturally stronger than prompt-based
- **gmickel/flow-next:** Re-anchoring before tasks, drift detection
- Gap identified: "No drift detection / re-anchoring" — Priority: High

Table shows drift detection as a gap for this plugin, with gmickel/flow-next having the best implementation.

### 8. Structured Debate on Hook Enforcement

**File:** `.claude/ab-test-results/structured-debate/cia-303-*.md`

Previous structured debate on circuit breaker mechanism (CIA-303):
- Addressed PostToolUse error detection
- NOT related to spec conformance checking

## Gap Analysis

### What Exists

1. PostToolUse hook infrastructure (hook registration, shell script execution)
2. Tool execution logging (timestamp, status)
3. Error loop detection (circuit breaker)
4. Protected branch detection
5. Uncommitted file counting
6. PreToolUse scope checking (file path allowlists)

### What Does NOT Exist (CIA-396 Requirements)

1. File change extraction from PostToolUse tool output
2. Active spec parsing (from `SDD_SPEC_PATH` or frontmatter)
3. Acceptance criteria comparison against file changes
4. Per-criterion conformance scoring
5. False positive rate measurement
6. 10-issue sample drift detection test harness

## Relevant Patterns to Leverage

### 1. Tool Input/Output Structure

From `circuit-breaker-post.sh`:
```bash
TOOL_OUTPUT=$(cat)
TOOL_NAME=$(echo "$TOOL_OUTPUT" | jq -r '.tool_name // empty')
TOOL_ERROR=$(echo "$TOOL_OUTPUT" | jq -r '.tool_result.is_error // false')
ERROR_MSG=$(echo "$TOOL_OUTPUT" | jq -r '.tool_result.content // empty')
```

CIA-396 would need:
```bash
FILE_PATH=$(echo "$TOOL_OUTPUT" | jq -r '.tool_result.file_path // empty')
FILE_CHANGES=$(echo "$TOOL_OUTPUT" | jq -r '.tool_result.diff // empty')
```

### 2. State File Pattern

Circuit breaker uses `.sdd-circuit-breaker.json` for persistent state. CIA-396 could use `.sdd-conformance-log.jsonl` for per-write conformance records:
```json
{"timestamp": "...", "file": "...", "criterion": "...", "matched": true, "confidence": 0.9}
```

### 3. Environment Variables

Existing:
- `SDD_SPEC_PATH` — path to active spec (currently used by PreToolUse)
- `SDD_STRICT_MODE` — enforcement level
- `SDD_LOG_DIR` — where to write logs

CIA-396 would need:
- `SDD_CONFORMANCE_THRESHOLD` — false positive rate threshold (default: 0.10)

### 4. Git Integration

Post-tool-use.sh already uses:
```bash
UNCOMMITTED=$(git status --porcelain | wc -l)
CURRENT_BRANCH=$(git branch --show-current)
```

CIA-396 would need:
```bash
git diff HEAD -- "$FILE_PATH"  # Get actual changes
```

## Conclusion

**Codebase has:** Hook infrastructure, tool I/O parsing patterns, state file patterns, git integration primitives.

**Codebase lacks:** Spec parsing, acceptance criteria extraction, change-to-criterion matching logic, false positive rate measurement, test harness for 10-issue sample.

**Architecture fit:** CIA-396 extends existing PostToolUse hook with new logic. Can reuse tool I/O patterns from circuit-breaker, environment vars from pre-tool-use, and logging patterns from both.

**Key design question:** How to parse acceptance criteria from spec and match them against file changes? Current hooks use bash + jq. Spec acceptance criteria are markdown checklists. Would need markdown parsing (possibly via external tool or embedded Python).
