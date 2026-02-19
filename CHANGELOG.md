# Changelog

All notable changes to the Claude Command Centre plugin.

Format follows [Keep a Changelog](https://keepachangelog.com/). Versions follow [Semantic Versioning](https://semver.org/).

## [1.8.3] - 2026-02-19

### Fixed
- Rewrote `skills/hook-enforcement/SKILL.md` to document all 14 hook scripts across 7 event types, matching the actual implementation in `hooks/scripts/` (CIA-528)
- Rewrote `skills/insights-pipeline/SKILL.md` to remove references to non-existent `pattern-aggregation` skill, SQLite index, and programmatic data processing; accurately describes the methodology-only skill (CIA-528)
- Tembo integration verified

## [1.8.0] - 2026-02-18

### Added
- `tembo-dispatch` skill: Dispatch well-specified issues to Tembo for background agent execution with Dispatch Prompt Template v1, credit estimation, and post-dispatch monitoring (CIA-564)

## [1.6.1] - 2026-02-18

### Added
- `template-sync` command registered in manifest (was orphaned on disk)
- `CHANGELOG.md` with backfill from git history

### Fixed
- State files (`.ccc-state.json`, `.ccc-progress.md`, `.ccc-circuit-breaker.json`, `.ccc-preferences.yaml`) added to `.gitignore`
- `plugin-eval.yml` component counts now derived dynamically from `marketplace.json` (were hardcoded at stale v1.0.0 values)
- `pre-tool-use.sh` JSON parsing migrated from fragile `sed` to `jq` with fallback

## [1.6.0] - 2026-02-16

### Added
- `pr-dispatch` skill: Stage 6 spec-aware PR review dispatch
- `branch-finish` skill: Stage 6-7.5 bridge for branch completion and Linear closure
- Strengthened `ship-state-verification` with phantom deliverable detection

## [1.5.0] - 2026-02-16

### Added
- `tdd-enforcement` skill: RED-GREEN-REFACTOR discipline with spec-derived test cases
- `debugging-methodology` skill: 4-phase spec-aware debugging loop
- `review-response` skill: RUVERI protocol for review response triage
- `template-validate` command with `--ci` and `--fix` modes
- `template-bootstrap` command for first-time template provisioning
- `template-sync` command for ongoing template drift correction

## [1.4.1] - 2026-02-16

### Fixed
- Plugin cache refresh bump (no functional changes)

## [1.4.0] - 2026-02-16

### Added
- `allowed-tools` metadata on all commands
- Updated command and skill tables in README

### Fixed
- Replace PCRE regex with POSIX-compatible equivalents (CIA-412)

## [1.3.0] - 2026-02-15

### Added
- `plugin.json` manifest for plugin-dev standard
- `/ccc:go` unified entry point with execution engine stop hook (CIA-406)
- `/ccc:config` preferences system with `.ccc-preferences.yaml` (CIA-407)
- `/ccc:self-test` in-session plugin validation (CIA-424)
- `session-exit` and `ship-state-verification` skills (CIA-372, CIA-373)
- `parallel-dispatch` skill with UI launch mode mapping (CIA-387)
- `planning-preflight` skill with codebase indexing and overlap detection
- `pattern-aggregation` skill for Insights Platform (CIA-436)
- `observability-patterns` skill for Stage 7 verification (CIA-302)
- Persona panel reviewer agents: security-skeptic, performance-pragmatist, architectural-purist, ux-advocate (CIA-395)
- Structured adversarial debate protocol (CIA-394)
- Review Decision Record (RDR) for Gate 2 approval
- Circuit breaker hooks with auto-escalation (CIA-389)
- Star grading quality scoring (CIA-390)
- `cc-plugin-eval` CI workflow (CIA-413)

### Changed
- Extracted execution-engine, spec-workflow, issue-lifecycle, context-management, project-cleanup references for progressive disclosure
- Rebranded SDD to Claude Command Centre (CCC)
- Flattened repo to root-level single-plugin pattern (CIA-442, CIA-443)

### Fixed
- Plugin.json author must be object, removed invalid hooks field
- Set `strict: true` to resolve conflicting manifests error
- Hygiene staleness check to use assignee pattern (CIA-367)
- Spec-author agent project auto-assignment (CIA-420)

## [1.2.0] - 2026-02-12

### Added
- 15 encoded patterns from 5 sessions
- Reconciled README with actual capabilities

## [1.1.0] - 2026-02-12

### Added
- Research skills: `research-grounding`, `research-pipeline`, `zotero-workflow`
- Accuracy gap fixes from session validation

## [1.0.0] - 2026-02-09

### Added
- Initial release: 17 skills, 3 agents, 11 commands
- 9-stage delivery funnel (Intake through Closure)
- Adversarial review with 4 architecture options
- PR/FAQ Working Backwards methodology with 4 templates
- Execution modes: quick, tdd, pair, checkpoint, swarm
- Issue lifecycle with ownership model and closure rules
- Quality scoring (0-100 rubric)
- Hook-based enforcement (session start, pre-tool-use, post-tool-use, stop)
