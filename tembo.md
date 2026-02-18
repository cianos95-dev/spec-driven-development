# Tembo Agent Instructions — Claude Command Centre

## Repository Overview

CCC is a Claude Code plugin (skills, commands, agents, hooks). It is a **markdown/config-only repo** — no build toolchain, no JS/TS source, no package manager.

## Repository Structure

```
claude-command-centre/
├── .claude-plugin/        # Plugin manifest (plugin.json)
├── agents/                # Agent definitions (*.md)
├── commands/              # Slash commands (*.md)
├── hooks/                 # Hook scripts (*.sh, *.md)
│   └── scripts/           # Shell scripts for hooks
├── skills/                # Skill definitions (*/SKILL.md)
├── docs/                  # ADRs, specs, guides
├── CONNECTORS.md          # Agent connector documentation
├── COMPANIONS.md          # Companion agent documentation
└── CHANGELOG.md           # Version history
```

## Branch & Commit Convention

- Branch: `tembo/<task-slug>` (e.g., `tembo/update-connectors-docs`)
- Commits: Conventional style — `fix:`, `feat:`, `chore:`, `docs:`
- PR body must include `Closes CIA-XXX` referencing the Linear issue

## Key Rules

- **No build chain** — do not create `package.json`, `tsconfig.json`, or install dependencies
- **Version bump**: If adding/removing/renaming a skill, command, agent, or hook, bump the version in `.claude-plugin/plugin.json` and add a CHANGELOG.md entry
- **Skill format**: Each skill lives in `skills/<name>/SKILL.md` with YAML frontmatter (`name`, `description`)
- **Agent format**: Each agent lives in `agents/<name>.md` with YAML frontmatter
- **Command format**: Each command lives in `commands/<name>.md` with YAML frontmatter
- **File paths**: Use kebab-case for directories and files
- **Markdown**: Use GitHub-flavored markdown

## Linear Project

All issues belong to **Claudian** team, project **Claude Command Centre (CCC)**.

## Multi-Project Routing

When dispatching Tembo tasks from Linear issues, the issue's **project** field determines which repository to target. All projects belong to the **Claudian** team.

| Linear Project | Repository | Working Directory | Notes |
|----------------|------------|-------------------|-------|
| Claude Command Centre (CCC) | `claude-command-centre` | `/` (repo root) | Markdown/config only — no build chain |
| Alteri | `alteri` | `/` (repo root) | Next.js + R — run `pnpm install` post-clone |
| Ideas & Prototypes | `prototypes` | `/` (repo root) | Turborepo monorepo — app selection via task prompt |
| Cognito SoilWorx | `prototypes` | `apps/soilworx` | Monorepo sub-app — scope work to this directory |
| Cognito Playbook | `prototypes` | `apps/job-search` | Monorepo sub-app — scope work to this directory |

### Repository URLs

| Repository | GitHub URL |
|------------|-----------|
| `claude-command-centre` | `https://github.com/cianos95-dev/claude-command-centre` |
| `alteri` | `https://github.com/cianos95-dev/alteri` |
| `prototypes` | `https://github.com/cianos95-dev/prototypes` |

### Routing Rules

1. **Read the issue's project field** from Linear before dispatching.
2. **Map project → repository** using the table above.
3. **For monorepo sub-apps** (Cognito SoilWorx, Cognito Playbook): include the working directory in the task prompt so Tembo scopes changes to the correct app.
4. **Unrecognized projects**: Do not dispatch. Flag for human review.
5. **Cross-project issues**: Rare. If an issue spans multiple repos, create separate Tembo tasks per repo.
