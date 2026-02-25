# AGENTS.md - Claude Command Centre (CCC)

> Cross-tool agent orchestration rules, model routing, and dispatch reference.
> Consumed by: Codex CLI, Copilot, Cursor, Antigravity, Gemini CLI, Claude Code subagents.

## Repository Overview

Claude Code plugin for spec-driven development methodology. Contains agents, commands, skills, hooks, styles, and tests for the CCC plugin ecosystem.

## Structure

```
claude-command-centre/
├── agents/          # 9 agent definitions (reviewer personas, spec-author, implementer, etc.)
├── commands/        # 17 slash commands
├── skills/          # 39 skills (execution modes, issue lifecycle, adversarial review, etc.)
├── hooks/           # Session and tool hooks (session-start, stop, pre/post-tool-use)
├── styles/          # Output style definitions
├── scripts/         # Repo setup and maintenance
├── tests/           # Static quality checks and outcome validation
├── docs/            # ADRs, Linear setup guide, style guide, upstream monitoring
├── examples/        # Sample outputs (anchor, closure, index, PR/FAQ, review findings)
└── .claude-plugin/  # Plugin manifest (plugin.json, marketplace.json)
```

## Build Commands

| Command | Purpose |
|---------|---------|
| `bash tests/test-static-quality.sh` | Run static quality checks |
| `jq . .claude-plugin/plugin.json` | Validate plugin manifest |

---

## Cross-Tool Dispatch Rules

Seven AI agents operate across the CCC ecosystem. Each has a defined scope, trigger mechanism, and cost profile.

### Agent Catalog

| Agent | Scope | Trigger | Cost |
|-------|-------|---------|------|
| **Claude Code** (local) | Spec writing, adversarial review, implementation, research execution | `/ccc:go CIA-XXX`, `/ccc:start`, manual | Max subscription |
| **Factory** (background) | Background implementation, sandbox execution, auto-PR | Assign/delegate in Linear, REST API | $16/mo flat |
| **Amp** (overflow) | Implementation overflow, spec review | GitHub issue or direct session | Free ($15/day grant) |
| **Copilot code review** | AI code review on PRs | Auto via `copilot-auto-review` ruleset | Free (included models) |
| **Copilot coding agent** | CI fixes, implementation needing dev env (`pnpm install`, tests) | Assign GitHub issue to Copilot | 1 premium req/session |
| **Dependabot** | Dependency version updates + security alerts | Auto via `.github/dependabot.yml` | Free |
| **Claude Desktop Auto-fix** | CI failure auto-fix during active Desktop sessions | Toggle in Desktop PR status bar | Max subscription |
| **claudegbot[bot]** | Repo settings, rulesets, branch protection, file edits via contents API, PR/issue CRUD | `GH_TOKEN=$(~/.claude/scripts/gh-app-token.sh) gh api ...` | Free (GitHub App) |
| **Warp/Oz** (lightweight) | Lightweight implementation | Linear agent | Free (300 credits/mo) |

### Task Routing Decision Tree

```
READ-ONLY (search, status check)?
  → Background subagent (haiku, run_in_background: true)

WELL-SPECIFIED with clear acceptance criteria?
  → Parallel subagents (multi-area) or direct (single area)

NEEDS EXPLORATION (unclear scope)?
  → Plan Mode first, then implement

SIMPLE (single file, obvious fix)?
  → Direct implementation
```

### Agent Selection by Task Type

| Task Type | Primary Agent | Fallback |
|-----------|--------------|----------|
| Spec writing / adversarial review / orchestration | Claude Code (Opus) | Cowork (no subagents) |
| Active coding (edit-run-debug) | Cursor (any model) | Claude Code |
| Large codebase analysis (>100K tokens) | Cursor (Gemini) / Gemini CLI | Claude Code with subagent delegation |
| Multi-agent orchestration | Antigravity (Gemini 3, Manager view) | Claude Code Agent Teams |
| Research + web grounding | Claude Code (MCP pipeline) | Gemini CLI (Google Search) |
| Quick fixes, boilerplate | Cursor (GPT) / Codex CLI | Claude Code (`exec:quick`) |
| Background implementation | Factory | Amp, Copilot coding agent |
| CI/CD fixes (no dev env) | claudegbot[bot] (contents API) | — |
| CI/CD fixes (needs dev env) | Copilot coding agent / Claude Desktop Auto-fix | — |
| Dependency updates | Dependabot | — |
| PR code review | Copilot code review (auto) | Claude Code `/ccc:review` |

### Intent x Agent Eligibility

When dispatching via Linear (@mention, delegateId, assignee), this matrix defines which agents can handle which intents:

| Intent | Claude | Factory | Cursor | Copilot | Codex | cto.new | Amp | Warp/Oz |
|--------|:------:|:-------:|:------:|:-------:|:-----:|:-------:|:---:|:------:|
| `review` | Y | — | — | Y (PR) | — | — | — | — |
| `implement` | Y | Y | Y | — | Y | Y | Y | Y |
| `gate2` | Y | — | — | — | — | — | — | — |
| `dispatch` | Y | Y | — | — | — | — | — | — |
| `status` | Y | — | — | — | — | — | — | — |
| `expand` | Y | — | — | — | — | — | — | — |
| `close` | Y | — | — | — | — | — | — | — |
| `spike` | Y | Y | — | — | — | — | — | — |
| `spec-author` | Y | — | — | — | — | — | — | — |

### Rate Limit Waterfall

When the primary tool hits rate limits, overflow to the next available:

```
Claude (Max 20x, 5hr window)
  → Cursor (non-Claude model)
    → Antigravity (Gemini 3, free)
      → Gemini CLI
        → Codex CLI
          → Claude resets
```

Session handoff: `handoff` alias (TUI picker), `overflow` alias (quick to Gemini). Uses `cli-continues`.

---

## Model Routing

### Session-Level Routing by Execution Mode

| Exec Mode | Session Model | Rationale |
|-----------|--------------|-----------|
| `exec:quick` | Default (single model) | No planning phase; model switching overhead not justified |
| `exec:tdd` | Default (single model) | Red-green-refactor is implementation-heavy; consistent model |
| `exec:pair` | **opusplan** | Opus plans + discusses; Sonnet implements after approval |
| `exec:checkpoint` | **opusplan** | Opus reasons through gates; Sonnet executes between gates |
| `exec:swarm` | Default (single model) | Subagent tier mix handles routing; orchestrator stays consistent |
| `exec:spike` | Default (single model) | Research is reading + synthesis; one model produces coherent analysis |

Activate opusplan: `/model opusplan` in Claude Code session.

### Subagent Model Routing

When delegating to Task subagents, match model tier to cognitive demand:

| Model Tier | Examples | Use For |
|------------|----------|---------|
| **Fast** (haiku) | File scanning, data retrieval, bulk reads, simple search | Lowest cost, highest throughput |
| **Balanced** (sonnet) | Code review synthesis, PR summaries, test analysis, research | Good quality-to-cost ratio |
| **Highest quality** (opus) | Critical implementation, complex reasoning, architectural decisions | Reserve for correctness-critical tasks |

### Subagent Routing by Execution Mode

| Exec Mode | Subagent Routing |
|-----------|-----------------|
| `exec:quick` | No subagent needed — direct execution |
| `exec:tdd` | Fast for test scaffolding, opus for implementation logic |
| `exec:pair` | Opus for all interactions (human is watching) |
| `exec:checkpoint` | Opus for implementation, sonnet for review summaries |
| `exec:swarm` | Fast for independent leaf tasks, sonnet for reconciliation |
| `exec:spike` | Sonnet for research, fast for bulk reads (repo scanning, API surveys) |

### Effort Level Injection

The CCC stop handler auto-injects `CLAUDE_CODE_EFFORT_LEVEL` based on execution mode:

| Exec Mode | Effort Level | Behavior |
|-----------|-------------|----------|
| `exec:quick` | `low` | Minimize latency |
| `exec:tdd` | `medium` | Structured implementation |
| `exec:spike` | `medium` | Balanced research depth |
| `exec:pair` | `high` | Maximum reasoning quality |
| `exec:checkpoint` | `high` | Thoroughness over speed |
| `exec:swarm` | `high` | Full orchestration reasoning |

The `/fast` toggle is orthogonal — it controls output speed, not reasoning depth.

---

## Execution Mode Selection

### The 5 Modes

| Mode | When | Guard Rail |
|------|------|------------|
| `exec:quick` | Small, well-understood, no ambiguity | Upgrade if >30 min or unexpected complexity |
| `exec:tdd` | Clear acceptance criteria expressible as tests | Drop to `exec:pair` if can't write a failing test |
| `exec:pair` | Uncertain scope, complex logic, learning opportunity | Define exit criteria up front |
| `exec:checkpoint` | High-risk: security, data, breaking changes | If checkpoint reveals wrong approach, revert — don't push through |
| `exec:swarm` | 5+ independent parallel tasks | If tasks have dependencies, sequence them |
| `exec:spike` | Output is knowledge, not code | Time-box to 1 session; split if longer needed |

### Decision Heuristic

```
Is it exploration (output = knowledge, not code)?
  → exec:spike

Is scope well-defined with clear acceptance criteria?
  ├── 5+ independent tasks? → exec:swarm
  ├── Testable (can write failing test)? → exec:tdd
  └── Not testable? → exec:quick

Is it high-risk (security, data, breaking)?
  → exec:checkpoint

Else → exec:pair (safest default — human in the loop)
```

### Estimate Mapping

| Story Points | Default Mode |
|-------------|-------------|
| 1-2 pt | `exec:quick` |
| 3 pt | `exec:tdd` |
| 5 pt | `exec:tdd` or `exec:pair` |
| 8 pt | `exec:pair` or `exec:checkpoint` |
| 13 pt | `exec:checkpoint` (decompose first) |

### Retry Budget

- **Max 2 failed approaches** before escalation (per issue, not per session)
- After 1st failure: try different approach, document what failed and why
- After 2nd failure: STOP. Escalate with evidence of both attempts
- Anti-pattern: retrying same approach 3+ times hoping for different results

---

## Parallelism Rules

### Two Parallelism Layers

| | Agent Teams | CCC Parallel-Dispatch |
|---|---|---|
| **Scope** | In-session | Cross-session (worktrees) |
| **Primitives** | `TeamCreate`, `SendMessage`, shared task list | Independent Claude Code sessions on separate branches |
| **Coordination** | Real-time messaging within one instance | Fully isolated — no cross-talk |
| **Best for** | Research, review, multi-file changes in same repo | Multi-issue implementation, CI-gated work |
| **Branch model** | Single branch (shared working tree) | One branch per session (worktree isolation) |

### Decision Guide

```
Work within one session and one repo?
  ├── Can share working tree? → Agent Teams
  └── File conflicts? → Parallel-Dispatch (worktrees)

Spans branches, repos, or needs CI isolation?
  → Parallel-Dispatch
```

### Session Caps

| Type | Max Parallel Sessions |
|------|----------------------|
| Implementation (worktree) | 3 |
| Research (read-only) | 5 |
| Batch >3 phases | Group into batches of 2-3; complete Batch 1 before Batch 2 |

### Branch Naming

`{agent}/{issue-id}-{slug}` — e.g., `claude/cia-387-dispatch-rules`

### Research-First Sequencing

1. Spikes first — any `exec:spike` runs before dependent implementation
2. Independent spikes run concurrently
3. Implementation waits for unresolved spikes that inform its design

---

## MCP Access Rules

### Subagent MCP Access

| Context | MCP Tools (Linear, GitHub, etc.) | ToolSearch Needed? |
|---------|----------------------------------|-------------------|
| Main context | Works | Yes (deferred tools) |
| **Foreground subagent** (Task, no `run_in_background`) | Works | No (pre-loaded) |
| **Background subagent** (`run_in_background: true`) | Permission denied | N/A |

**Rule:** Never use `run_in_background: true` for tasks needing Linear, GitHub, or other MCP access. Foreground subagents launched in the same message block still run concurrently.

### Context Management Thresholds

| Threshold | Action |
|-----------|--------|
| Any tool returning >1KB | Delegate to Task subagent |
| >50% context used | Warn user, consider checkpointing |
| >70% context used | Insist on session split |
| 80% (autocompact) | Safety net — should not reach this |

### Linear MCP Discipline

- Never `list_issues` without `limit` (default returns 100KB+). Always `limit: 10` or less.
- Never `list_issues` in main context — always delegate to subagent returning markdown table.
- Single `get_issue` OK directly. 2+ issues → subagent.
- Subagent summaries: 3-5 sentences, max 200 words.

---

## Dispatch Safety Rules

These rules are non-negotiable for all agents operating in the CCC ecosystem:

| Rule | Description |
|------|-------------|
| **DONE = MERGED** | Never mark issue Done until PR is merged to main. Commit ≠ Done. PR open ≠ Done. |
| **SESSION EXIT** | Every session must push + create PR before ending. Enables zero-touch loop. |
| **SESSION FEEDBACK** | Before ending, post a structured comment on the Linear issue (see format below). |
| **RESUME PRE-FLIGHT** | On session start: `git log --all --grep="CIA-XXX"` to check for existing work. |
| **ONE PR PER ISSUE** | Each CIA issue gets its own branch and PR. Never bundle. |
| **WORKTREE PR** | Every worktree session must create a PR before ending. No orphan branches. |
| **MAIN CHECKOUT** | Before dispatching worktree sessions, ensure main working directory is on `main`. |
| **REVIEW GATE** | If adversarial review returns REVISE, issue cannot move to Done until addressed. |
| **UPSTREAM REPOS** | Never file issues/PRs/comments on upstream repos without explicit user approval. |
| **GITHUB IDENTITY** | Use `~/.claude/scripts/gh-app-token.sh` for PR/issue creation (appears as `claudegbot[bot]`). |

### Structured Session Feedback

Every agent session working on a Linear issue **must** post a comment before ending. Use this format:

```markdown
## Session Report: [tool] ([model])

### What was done
- [Concrete deliverables: files changed, PRs created, research completed]

### Decisions made
- [Any architectural or implementation choices, with reasoning]

### Blockers found
- [Issues that prevented progress, or "None"]

### Next steps
- [What remains to complete the issue]
```

Post via the dispatch server `/linear-update` route:
```bash
curl -X POST http://localhost:5679/linear-update \
  -H 'Content-Type: application/json' \
  -d '{"issueId": "CIA-XXX", "body": "## Session Report: ..."}'
```

Or via Linear MCP `create_comment` if available in the tool.

---

## CLAUDE.md Reference Patterns

### Instruction File Hierarchy

Each AI tool reads its own instruction file. All files exist per-repo:

| File | Consumed By | Purpose |
|------|------------|---------|
| `CLAUDE.md` | Claude Code, Claude Desktop | Project-level instructions, MCP config, git rules |
| `AGENTS.md` | Codex CLI, Copilot, all agents | Cross-tool dispatch rules, model routing (this file) |
| `GEMINI.md` | Gemini CLI, Antigravity | Gemini-specific instructions, shared format |
| `.antigravity/rules.md` | Antigravity | Optional per-project Antigravity rules |
| `.cursorrules` / `.cursor/rules` | Cursor | Cursor-specific project rules |
| `.github/copilot-instructions.md` | GitHub Copilot | Copilot-specific instructions |

### Global vs Project-Level

```
~/.claude/CLAUDE.md              ← Global (all projects)
~/Repositories/<repo>/CLAUDE.md  ← Project-level (checked into repo)
```

Global CLAUDE.md provides: task routing, dispatch safety, MCP config, session management, multi-AI routing.
Project CLAUDE.md provides: repo-specific git rules, testing commands, Linear integration, agent dispatch table.

### Context Flow Between Surfaces

No surface operates in isolation. Context flows through artifacts:

| Bridge | Flow | What Transfers |
|--------|------|---------------|
| **Linear issues** | Any surface → Any surface | Specs, status, decisions, assignments |
| **Linear plan documents** | Code → Linear → Cowork | Promoted session plans |
| **GitHub specs** | Code ↔ Cowork | `docs/specs/` files via GitHub MCP |
| **Desktop Project Files** | Chat → Cowork | Domain docs, instructions, memory |
| **CLAUDE.md** | Repo → Code | Project instructions, MCP config |

**Linear is the universal state bus.** All surfaces have Linear MCP access. When handing off between surfaces, ensure the Linear issue contains current state.

### Platform Routing (Quick Reference)

| Workflow Stage | Best Platform | Why |
|----------------|--------------|-----|
| Spec drafting (interactive) | Cowork | Artifact generation, interactive connectors |
| Adversarial review | Claude Code | Requires subagent Task tool for parallel reviewers |
| Implementation / TDD | Claude Code | Hooks, git, full MCP stack |
| Research execution | Claude Code | Zotero, arXiv, S2, OpenAlex are stdio MCPs (CLI-only) |
| Issue triage / sprint planning | Cowork | Linear connector interactive mode |
| Agent dispatch (@mention) | Linear | Native webhook mechanism |
| Quick questions / brainstorming | Desktop Chat | Lightweight, fast turnaround |

---

## CCC Pipeline Agents (Internal)

The CCC plugin defines 9 internal agents for the spec-driven workflow:

| Agent | CCC Stage | Role |
|-------|-----------|------|
| **spec-author** | 0-3 | Intake → normalize → PR/FAQ template → draft spec → Gate 1 |
| **reviewer** | 4 | Adversarial review → severity-rated findings → PASS/REVISE/REJECT |
| **reviewer-security-skeptic** | 4 | Security persona: attack vectors, auth gaps, compliance |
| **reviewer-architectural-purist** | 4 | Architecture persona: coupling, abstractions, maintainability |
| **reviewer-performance-pragmatist** | 4 | Performance persona: scaling cliffs, connection math, caching |
| **reviewer-ux-advocate** | 4 | UX persona: cognitive load, error recovery, accessibility |
| **debate-synthesizer** | 4 | Reconcile 4 persona outputs → UNANIMOUS/MAJORITY/SPLIT findings |
| **implementer** | 5-7.5 | Execution mode routing → build-test-verify → drift prevention → closure |
| **code-reviewer** | 6 | Spec-aware code review: AC checklist, drift detection, severity findings |

### CCC Stage Flow

```
Ideation → Spec Draft → Adversarial Review → Implementation → Verification → Closure
  (0-1)      (2-3)          (4)               (5-6)           (7)          (7.5)
         Gate 1          Gate 2                            Gate 3
```

---

## Agent Instructions (for external agents working on this repo)

### Git Rules (CRITICAL)

- Branch protection ON for `main` — no direct push
- Every session: `git push` + PR creation before ending
- Branch naming: `claude/cia-XXX-description`
- Commits: `Closes CIA-XXX` in PR body for auto-linking
- Squash merge only: `gh pr merge --squash --delete-branch`
- One PR per Linear issue — never bundle

### Before Implementation

1. Run `git log --all --grep="CIA-XXX"` to check for existing work
2. Read the relevant skill/agent/command files before modifying
3. Check `plugin.json` for current version and structure

### During Implementation

- All content files are YAML/Markdown — no TypeScript in this repo
- Skill descriptions must trigger on natural language (see existing patterns)
- Agent definitions include `allowedTools` constraints
- Hook files follow `pre-tool-use`/`post-tool-use`/`session-start`/`stop` naming

### Before Completion

```bash
bash tests/test-static-quality.sh    # Must pass
jq . .claude-plugin/plugin.json      # Must be valid JSON
```

## Linear Integration

- Team: Claudian (CIA)
- Project: Claude Command Centre (CCC) — always use full `(CCC)` suffix
- Never round-trip descriptions through get_issue → update_issue (double-escaping bug)
- `update_issue` labels REPLACES all labels — include existing ones

## Do Not

1. Push directly to `main`
2. Modify `plugin.json` version without explicit instruction
3. Create duplicate skills — check existing 39 skills first
4. Bundle multiple issues into one PR
5. Use `run_in_background: true` for tasks needing MCP access
6. Dispatch to upstream repos without explicit user approval
7. Mark issues Done before PR is merged
