# Instruction Surface Maintenance Protocol

> Defines when, how, and by whom each agent instruction surface is updated.

## Instruction Surfaces Inventory

| Surface | File/Location | Visibility | Consumed By |
|---------|--------------|------------|-------------|
| AGENTS.md | Repo root | Public (in repo) | All agents: Factory, Cursor, Codex, Copilot, Claude Code, Amp, Warp/Oz, cto.new |
| CLAUDE.md | Repo root | Public (in repo) | Claude Code, Claude Desktop |
| GEMINI.md | Repo root | Public (in repo) | Gemini CLI, Antigravity |
| .cursor/rules/ | `.cursor/rules/` | Public (in repo) | Cursor IDE |
| copilot-instructions.md | `.github/copilot-instructions.md` | Public (in repo) | GitHub Copilot |
| Linear workspace guidance | Linear Settings > Security | Private (workspace) | All Linear-connected agents |
| Cloud Templates | Factory API | Secret-capable (Doppler) | Factory |

## Update Triggers

### When to Update Each Surface

| Trigger Event | Surfaces to Update | Action |
|--------------|-------------------|--------|
| New skill added | AGENTS.md (skill count), marketplace.json, README.md | Add skill entry, update counts |
| New agent added | AGENTS.md (agent count), marketplace.json, README.md | Add agent entry, update counts |
| New command added | AGENTS.md (command count), marketplace.json, README.md | Add command entry, update counts |
| Architecture change | AGENTS.md, CLAUDE.md | Update structure section, conventions |
| New agent platform connected | AGENTS.md (Agent Catalog), platform-specific config | Add to matrix, create platform config |
| Security rule change | AGENTS.md (Security Rules, Forbidden Patterns) | Update all relevant surfaces |
| Git workflow change | AGENTS.md, CLAUDE.md, copilot-instructions.md, .cursor/rules/ | Sync across all surfaces |
| New repo created | Create AGENTS.md from template | Use this repo's AGENTS.md as reference |
| Plugin manifest change | Verify AGENTS.md structure section still accurate | Update counts and paths |

### Quarterly Audit Checklist

- [ ] AGENTS.md structure section matches actual directory layout
- [ ] Component counts in AGENTS.md match marketplace.json
- [ ] Agent Catalog in AGENTS.md reflects currently connected agents
- [ ] Security Rules section covers all current threat vectors
- [ ] Forbidden Patterns section is current with operational learnings
- [ ] .cursor/rules/ aligns with AGENTS.md conventions
- [ ] .github/copilot-instructions.md aligns with AGENTS.md review criteria
- [ ] GEMINI.md key rules match AGENTS.md
- [ ] Linear workspace guidance references correct persona definitions
- [ ] Cloud Templates have correct environment variables

## Ownership

| Surface | Owner | Approval Required |
|---------|-------|-------------------|
| AGENTS.md | Repo maintainer (Cian) | PR review |
| CLAUDE.md | Repo maintainer (Cian) | PR review |
| GEMINI.md | Repo maintainer (Cian) | PR review |
| .cursor/rules/ | Repo maintainer (Cian) | PR review |
| .github/copilot-instructions.md | Repo maintainer (Cian) | PR review |
| Linear workspace guidance | Workspace admin (Cian) | Direct (no PR) |
| Cloud Templates | Factory admin (Cian) | REST API (programmatic) |

## Content Boundaries

Each instruction surface has a specific scope. No duplication between files.

| Surface | Scope | Must NOT Contain |
|---------|-------|-----------------|
| AGENTS.md | Universal behavioral rules for ANY agent | Claude-specific hooks/MCP config, API keys, internal URLs |
| CLAUDE.md | Claude Code-specific instructions | Cursor/Copilot rules, universal conventions already in AGENTS.md |
| GEMINI.md | Gemini-specific instructions | Claude/Cursor rules |
| .cursor/rules/ | Cursor IDE-specific rules | MCP config, Linear integration details |
| copilot-instructions.md | Copilot review criteria and PR workflow conventions relevant to code review | Non-review operational runbooks (deploys, oncall), global behavioral rules already covered in AGENTS.md |
| Linear guidance | Cross-agent workspace rules | Repo-specific code conventions |
| Cloud Templates | Environment setup (deps, runtime) | Behavioral instructions |

## Verification Procedures

### After AGENTS.md Change

1. Run `bash tests/test-static-quality.sh` to verify structural integrity
2. Verify no secrets, internal URLs, or credentials were introduced
3. Check that component counts match actual counts
4. Dispatch a test task to at least 2 different agents and verify behavior aligns

### After Platform-Specific Config Change

1. For .cursor/rules/: Open repo in Cursor, verify rules load and apply
2. For copilot-instructions.md: Create a test PR, verify Copilot review follows new instructions
3. For Linear guidance: Create a test issue, verify agent response format matches guidance
4. For Cloud Templates: Trigger a Factory build, verify setup completes without error

### After New Agent Platform Connected

1. Verify all 3 layers are configured:
   - Environment: Cloud Template or local setup documented
   - Behavior: AGENTS.md readable by the agent
   - Runtime: Linear workspace guidance applies (if Linear-connected)
2. Run a test task through the new agent
3. Update the Agent Platform Matrix in the Linear issue (CIA-726)

## Cross-Platform Persona Export

Agent personas are defined in `~/.claude/agents/*.md` (private, local). When injecting personas into other platforms:

- Linear workspace guidance: Reference persona definitions by name, not by content
- Factory/Codex: Personas applied via AGENTS.md agent-specific sections
- Cursor: Personas not applicable (IDE-based, no persona model)
- Copilot: Personas not applicable (review-only, uses severity scale from AGENTS.md)

For canonical persona format and export adapters, see CIA-638 and CIA-734.
