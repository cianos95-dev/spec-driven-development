# Claude Command Centre (CCC)

## Agent Dispatch

When working on this repo, use these conventions:

| Task Type | Agent | Trigger |
|-----------|-------|---------|
| Feature implementation | Claude Code (local) | `/ccc:go CIA-XXX` |
| Background implementation | Factory / Claude Web (`--remote`) | Assign in Linear or `& prefix` |
| PR code review | GitHub Copilot | Auto on PR |
| Spec drafting | Claude Code (local) | `/ccc:start` |

## Repo Structure

- `agents/` — Agent definitions (9 agents: reviewer personas, spec-author, implementer, debate-synthesizer, code-reviewer)
- `commands/` — Slash commands (17 commands: go, start, close, review, decompose, etc.)
- `hooks/` — Session and tool hooks (session-start, stop, pre/post-tool-use)
- `skills/` — Skill definitions (36 skills: execution modes, issue lifecycle, adversarial review, etc.)
- `styles/` — Output style definitions (explanatory, educational)
- `scripts/` — Repo setup and maintenance scripts
- `tests/` — Static quality checks and outcome validation tests
- `docs/` — ADRs, Linear setup guide, style guide, upstream monitoring
- `examples/` — Sample outputs (anchor, closure, index, PR/FAQ, review findings)
- `.claude-plugin/` — Plugin manifest (`plugin.json`, `marketplace.json`)

## Git Rules

Branch protection is ON for `main`. No direct push allowed.

- **Every session must end with `git push` + `gh pr create`**. This enables the zero-touch loop: Push → PR → Copilot auto-review → CI → Auto-merge → Linear close.
- **[DONE = MERGED]**: Never mark a Linear issue Done until its PR is merged to main. Commit ≠ Done. PR open ≠ Done. Only merged = Done.
- **[ONE PR PER ISSUE]**: Each CIA issue gets its own branch and PR. Don't bundle multiple issues.
- **[RESUME PRE-FLIGHT]**: On session start or resume, run `git log --all --grep="CIA-XXX"` to check for existing work before writing code.
- **[WORKTREE PR]**: Every worktree session must create a PR before ending. No orphan branches.
- **[BRANCH CLEANUP]**: Use `gh pr merge --squash --delete-branch` to auto-delete after merge.
- **[MAIN CHECKOUT]**: Before dispatching worktree sessions, ensure the main working directory is on `main`.
- **[REVIEW GATE]**: If adversarial review returns REVISE, the issue cannot move to Done until findings are addressed.

## Testing

Run the static quality checks before submitting changes:

```bash
bash tests/test-static-quality.sh
```

## MCP Access in Subagents

When dispatching Task subagents from this repo (including worktree sessions):

| Context | MCP Tools (Linear, GitHub, etc.) | ToolSearch needed? |
|---------|----------------------------------|-------------------|
| Main context | ✅ Works | Yes (deferred tools) |
| Foreground subagent (Task, no `run_in_background`) | ✅ Works | No (pre-loaded) |
| Background subagent (`run_in_background: true`) | ❌ Permission denied | N/A |

**Rule:** Never use `run_in_background: true` for tasks needing Linear, GitHub, or other MCP access. Foreground subagents launched in the same message block still run concurrently — use multiple Task calls without `run_in_background` for parallel MCP work.

## Linear

- **Team:** Claudian (key: CIA)
- **Project:** Claude Command Centre (CCC) — always include `(CCC)` suffix in queries
- Always set `project` when creating issues
- Never round-trip descriptions through `get_issue` → `update_issue` (double-escaping bug)
- `update_issue` labels param REPLACES all labels — include existing ones
