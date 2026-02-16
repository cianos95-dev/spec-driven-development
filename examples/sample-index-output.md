# Example: Codebase Index Output

> **Funnel position:** Pre-funnel utility -- output of `/sdd:index`
> **Purpose:** Produces a structured map of the repository before spec writing or implementation
> **Next step:** Use the index to inform `/sdd:write-prfaq` (Stage 3) or `/sdd:start` (Stage 6)
> **Related:** Codebase awareness skill governs the scanning protocol and index format

This example shows what `/sdd:index --full` produces when run against the SDD plugin repository itself. It demonstrates the Module Map, Patterns, and Integration Points sections, followed by the summary report.

---

## Codebase Index -- claude-command-centre

**Generated:** 2026-02-12T14:32:00Z | **Commit:** a3f7c21

### Module Map

| Module | Purpose | Key Exports | Dependencies |
|--------|---------|-------------|--------------|
| `.claude-plugin/` | Plugin manifest | `plugin.json` (name, version, description) | None |
| `commands/` | Slash command definitions | 7 commands: `anchor`, `close`, `decompose`, `hygiene`, `index`, `review`, `start`, `write-prfaq` | Skills (referenced by name in step descriptions) |
| `skills/adversarial-review/` | Multi-perspective spec review methodology | SKILL.md, 2 GitHub Action reference files | prfaq-methodology (specs to review), issue-lifecycle (carry-forward items) |
| `skills/codebase-awareness/` | Repository scanning and indexing protocol | SKILL.md (index format definition, scanning steps) | None (standalone) |
| `skills/context-management/` | Context window management and subagent delegation | SKILL.md (3-tier model, budget protocol, model mixing) | None (standalone, but referenced by all other skills) |
| `skills/drift-prevention/` | Session anchoring against spec source of truth | SKILL.md (anchoring protocol, drift detection) | execution-modes, context-management, issue-lifecycle |
| `skills/execution-modes/` | 5-mode taxonomy with decision heuristic and T1-T4 classification | SKILL.md (quick, tdd, pair, checkpoint, swarm) | issue-lifecycle (label application) |
| `skills/hook-enforcement/` | Runtime constraint enforcement via Claude Code hooks | SKILL.md (hook inventory, enforcement levels) | All skills (hooks enforce their rules) |
| `skills/issue-lifecycle/` | Agent/human ownership model for issue management | SKILL.md (ownership table, closure matrix, spec labels, project hygiene) | spec-workflow (stage references), execution-modes (label coexistence) |
| `skills/prfaq-methodology/` | Working Backwards spec drafting with 4 templates | SKILL.md, 4 templates: `prfaq-feature`, `prfaq-infra`, `prfaq-quick`, `prfaq-research` | research-grounding (citation requirements) |
| `skills/project-cleanup/` | One-time project normalization protocol | SKILL.md (reclassification, naming, label migration) | issue-lifecycle (naming conventions), spec-workflow (label definitions) |
| `skills/quality-scoring/` | Deterministic rubric for issue completion evaluation | SKILL.md (3-dimension scoring: test 40%, coverage 30%, review 30%) | issue-lifecycle (closure decisions) |
| `skills/research-grounding/` | Research readiness progression and citation standards | SKILL.md (4-level label hierarchy, grounding requirements) | prfaq-methodology (spec citation sections) |
| `skills/research-pipeline/` | End-to-end academic research pipeline | SKILL.md (4-stage: discover, enrich, organize, synthesize) | zotero-workflow (storage stage), research-grounding (readiness labels) |
| `skills/spec-workflow/` | Complete 9-stage development funnel with 3 approval gates | SKILL.md (funnel diagram, stage reference, fast paths, scope discipline) | All other skills (cross-referenced by stage) |
| `skills/zotero-workflow/` | Canonical Zotero library management workflow | SKILL.md (plugin sequencing, enrichment, safety rules) | research-pipeline (storage integration) |
| `hooks/` | Shell scripts for Claude Code hook enforcement | `session-start.sh`, `pre-tool-use.sh`, `post-tool-use.sh`, `stop.sh` | hook-enforcement skill (defines what they check) |
| `examples/` | Annotated example outputs for each command | 5 files: `sample-prfaq`, `sample-review-findings`, `sample-closure-comment`, `sample-index-output`, `sample-anchor-output` | Commands (each example maps to a command output) |
| `docs/` | Supporting documentation | `competitive-analysis.md` | None |

### Patterns

- **Framework:** Claude Code plugin (`.claude-plugin/plugin.json` manifest, `skills/` + `commands/` + `hooks/` directory convention)
- **Skill format:** Each skill is a directory under `skills/` containing a `SKILL.md` with YAML frontmatter (`name`, `description` with trigger phrases) and Markdown body. Some skills include subdirectories for templates (`prfaq-methodology/templates/`) or references (`adversarial-review/references/`)
- **Command format:** Each command is a single Markdown file under `commands/` with YAML frontmatter (`description`, `argument-hint`) and a step-by-step execution protocol with a "What If" table for edge cases
- **Hook format:** Shell scripts under `hooks/` named by lifecycle event (`session-start`, `pre-tool-use`, `post-tool-use`, `stop`)
- **Example format:** Each example Markdown file starts with a blockquote header showing funnel position, prerequisites, and cross-references to other examples. Examples use realistic fictional project data (PROJ-042 series)
- **Naming:** kebab-case for all files and directories. Skills use `SKILL.md` (uppercase). Plugin manifest uses `plugin.json`
- **Cross-references:** Skills reference each other by name (e.g., "See the **execution-modes** skill"). Commands reference skills by name in step descriptions (e.g., "Execute the codebase-awareness skill's scanning protocol")
- **Placeholder convention:** External tool names wrapped in `~~double-tildes~~` (e.g., `~~project-tracker~~`, `~~version-control~~`, `~~deployment-platform~~`) to remain tool-agnostic
- **Version:** 1.1.0 (from plugin.json)

### Integration Points

- **Project tracker (~~project-tracker~~):** Referenced throughout for issue creation, status transitions, label management, closure rules. No direct API integration -- works through whatever MCP the host environment provides (e.g., Linear MCP)
- **Version control (~~version-control~~):** Referenced for branch creation, PR opening, commit history, diff analysis. No direct integration -- works through host environment (e.g., GitHub MCP)
- **Deployment platform (~~deployment-platform~~):** Referenced in verification stage (Stage 7) for preview deployments and production deploy checks
- **Research library (~~research-library~~):** Referenced in research-grounding and research-pipeline skills for literature search and citation management
- **Analytics platform (~~analytics-platform~~):** Referenced in Stage 2 (Analytics Review) for usage data and metrics
- **Design tool (~~design-tool~~):** Referenced in Stage 5 (Visual Prototype) for UI mockups
- **Remote execution (~~remote-execution~~):** Referenced in Stage 8 (Async Handoff) for dispatching work to remote agents
- **GitHub Actions:** Two reference YAML files in `adversarial-review/references/` define CI pipeline configurations for automated review (Options A and B)
- **No runtime dependencies:** The plugin has no `package.json`, `requirements.txt`, or build system. It is a pure content plugin (Markdown + shell scripts + JSON manifest)

### Warnings

- **Stale reference:** `CONNECTORS.md` exists at the root level but is not referenced by any skill or command. Consider whether it should be linked from the README or removed.
- **Binary asset:** `The AI Context Vault.pdf` and `first insights report.html` exist at the root level. These are not referenced by any skill or command. Consider moving to `docs/` or removing if they are personal artifacts.
- **Example gap:** Commands `decompose`, `hygiene`, and `start` do not have corresponding example output files in `examples/`. Consider adding `sample-decompose-output.md`, `sample-hygiene-output.md`, and `sample-start-output.md`.
- **Template count mismatch:** `prfaq-methodology` SKILL.md references 4 templates. The `templates/` directory contains 4 files. Count is consistent -- no mismatch.
- **Hook count:** 4 hook scripts exist. The `hook-enforcement` SKILL.md documents 4 hook types (session-start, pre-tool-use, post-tool-use, stop). Count is consistent.

---

### Summary

```
Indexed claude-command-centre at a3f7c21:
- 16 modules mapped
- 9 patterns detected
- 8 integration points identified (all placeholder-based, no direct API coupling)
- 3 warnings flagged
- Mode: full
```

---

## Notes on This Example

**What to look for in a good index output:**

1. **Module Map is exhaustive.** Every top-level and key nested directory has an entry. The "Key Exports" column describes what other modules consume from this one -- not just file names, but their purpose.

2. **Patterns are specific.** Instead of generic statements like "uses Markdown", the patterns describe the actual conventions: YAML frontmatter structure, naming schemes, cross-reference style, placeholder conventions.

3. **Integration Points distinguish direct from indirect.** This plugin has no direct API integrations -- everything works through host-provided MCPs. A typical application project would list concrete integration points (database connections, API endpoints, auth providers).

4. **Warnings are actionable.** Each warning identifies a specific issue and suggests a concrete resolution. Warnings are not errors -- they are observations that might indicate drift between documented and actual state.

5. **The summary is machine-parseable.** The final summary block uses a consistent format that other commands (like `/sdd:anchor`) can reference when checking index freshness.
