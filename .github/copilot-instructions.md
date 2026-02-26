# Copilot Instructions — Claude Command Centre

> For the full universal agent rules, see AGENTS.md at the repo root.

## Repository Context

This is a Claude Code plugin repo for spec-driven development. Skills, agents, and commands are defined in YAML/Markdown — no TypeScript or compiled code. The plugin contains 39 skills, 19 commands, and 9 agents.

## Code Review Focus Areas

### Security (Critical Priority)

- Flag any hardcoded secrets, API keys, tokens, or credentials
- Flag any internal URLs, IP addresses, or infrastructure endpoints
- Flag any hardcoded Linear user IDs, workspace IDs, or agent IDs
- Verify no credential material appears in YAML frontmatter, Markdown content, or JSON config
- Environment variables preferred for all sensitive configuration

### Structural Integrity

- Skills must have YAML frontmatter with `name` and `description` fields
- Agent definitions must specify `name`, `description`, and `allowedTools`
- Commands must have frontmatter with at minimum a `description` field
- Hook scripts must handle exit codes properly (0 = allow/fail-open; non-zero = hook failure/deny as implemented by that hook — note: some PermissionRequest/PreToolUse hooks expect 2 for explicit deny)
- All JSON files must be valid and parseable
- Template JSON files must conform to `templates/schema.json`

### Plugin Architecture

- Skills are loaded via the Skill tool, never via Read
- Plugin manifest (`marketplace.json`) must declare all skills, agents, and hooks
- Every skill/agent/command on disk must have a corresponding manifest entry (no orphans)
- Every manifest entry must point to an existing file on disk (no dangling references)
- Marketplace wrapper required for distribution; `github` source = production, `directory` = dev-only
- Minimum skill depth: 8192 characters (enforced by CI)

### Cross-Reference Validation

- Skills referencing other skills must use valid skill names from the manifest
- Cross-references use backtick-quoted names followed by "skill" (e.g., `execution-modes` skill)
- Broken cross-references should be flagged

### Forbidden Patterns

- No duplicate skills — verify against existing skills in `marketplace.json`
- No TypeScript or compiled code
- No modification of `plugin.json` version without explicit instruction
- No bundling multiple Linear issues into one PR
- No direct push to `main`

## PR Conventions

- One PR per Linear issue (CIA-XXX)
- Include `Closes CIA-XXX` in PR body for auto-linking
- Squash merge only
- Branch naming: `{agent}/{issue-id}-{slug}`

## Testing

- `bash tests/test-static-quality.sh` must pass before merge
- `jq . .claude-plugin/plugin.json` must produce valid JSON
- Skill content should be self-contained and testable
- Hook scripts should be idempotent
