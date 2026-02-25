# Companion Plugins

Claude Command Centre (CCC) is an **orchestration hub** -- it teaches the agent how to work through specs, reviews, multi-agent routing, and implementation. It deliberately does not cover code-level execution patterns, domain-specific best practices, or tactical development operations. The plugins below fill those gaps.

None of these are required. CCC works standalone. But each one extends a specific part of the funnel.

## Superseded Plugins

These plugins were previously recommended but have been fully replaced by CCC native skills, Claude Code built-in features, or Anthropic official resources.

| Plugin | Was Used For | Superseded By | Migration |
|--------|-------------|---------------|-----------|
| **superpowers** | Git worktrees, parallel dispatch, debugging, brainstorming, code review, TDD, plan writing, verification | See replacement matrix below | Uninstall. CCC skills auto-match for all use cases. |

### Superpowers Replacement Matrix

Every superpowers skill has a direct replacement:

| Superpowers Skill | Replacement | Source |
|-------------------|-------------|--------|
| `systematic-debugging` | `debugging-methodology` | CCC skill |
| `brainstorming` | Cowork native + `/ccc:write-prfaq` | CCC + Claude Code |
| `requesting-code-review` | `pr-dispatch` | CCC skill |
| `receiving-code-review` | `review-response` | CCC skill |
| `code-reviewer` (agent) | `code-reviewer` agent | CCC agent |
| `test-driven-development` | `tdd-enforcement` | CCC skill |
| `finishing-a-development-branch` | `branch-finish` | CCC skill |
| `verification-before-completion` | `references/evidence-mandate.md` + `branch-finish` (8 pre-checks) | CCC reference + skill |
| `using-git-worktrees` | Native git worktree support | Claude Code |
| `writing-plans` | `/plan` mode (Shift+Tab) | Claude Code |
| `executing-plans` | `execution-engine` + `execution-modes` | CCC skills |
| `dispatching-parallel-agents` | `parallel-dispatch` | CCC skill |
| `subagent-driven-development` | Native Task tool | Claude Code |
| `writing-skills` | [Skill authoring guide (32-page PDF)](https://resources.anthropic.com/hubfs/The-Complete-Guide-to-Building-Skill-for-Claude.pdf) | Anthropic |
| `using-superpowers` | `hook-enforcement` | CCC skill |

## Native Capabilities

These capabilities are built into CCC or Claude Code itself. No companion plugin needed.

| Capability | How to Access | Notes |
|-----------|--------------|-------|
| Git worktree orchestration | Claude Code Desktop checkbox or `--worktree` CLI flag | Agent Teams for multi-session coordination |
| Plan mode | `/plan` or Shift+Tab | Built into Claude Code |
| Parallel agent dispatch | Task tool with multiple tool calls | CCC `parallel-dispatch` skill governs routing |
| Systematic debugging | CCC `debugging-methodology` skill | Triggers on "debug", "investigate", "root cause" |
| Code review dispatch | CCC `pr-dispatch` skill + `code-reviewer` agent | Spec-aware review with acceptance criteria verification |
| TDD enforcement | CCC `tdd-enforcement` skill | Red-green-refactor discipline |

## Recommended Companions

### Process & Workflow

| Plugin | Marketplace | What It Adds to CCC | Install |
|--------|-------------|---------------------|---------|
| **code-operations-skills** | mhattingpete-claude-skills | Bulk code execution, cross-file refactoring, file operations | `claude plugins add code-operations-skills@mhattingpete-claude-skills` |

### Domain Knowledge

| Plugin | Marketplace | What It Adds to CCC | Install |
|--------|-------------|---------------------|---------|
| **developer-essentials** | claude-code-workflows | Auth patterns, monorepo management, SQL optimization, e2e testing, debugging strategies | `claude plugins add developer-essentials@claude-code-workflows` |
| **backend-development** | claude-code-workflows | API design principles, microservices patterns, event sourcing, CQRS, saga orchestration | `claude plugins add backend-development@claude-code-workflows` |
| **python-development** | claude-code-workflows | Async patterns, testing strategies, packaging with uv, performance optimization | `claude plugins add python-development@claude-code-workflows` |

### Output & Documentation

| Plugin | Marketplace | What It Adds to CCC | Install |
|--------|-------------|---------------------|---------|
| **visual-documentation-skills** | mhattingpete-claude-skills | SVG architecture diagrams, flowcharts, timelines, dashboards | `claude plugins add visual-documentation-skills@mhattingpete-claude-skills` |
| **context7-plugin** | context7-marketplace | Up-to-date library documentation lookup during implementation | `claude plugins add context7-plugin@context7-marketplace` |

### SaaS Integration Packs

| Plugin | Marketplace | What It Adds to CCC | Install |
|--------|-------------|---------------------|---------|
| **supabase-pack** | claude-code-plugins-plus | Supabase schema design, RLS policies, migration patterns, debugging | `claude plugins add supabase-pack@claude-code-plugins-plus` |
| **vercel-pack** | claude-code-plugins-plus | Vercel deployment patterns, edge functions, performance tuning | `claude plugins add vercel-pack@claude-code-plugins-plus` |

### Meta

| Plugin | Marketplace | What It Adds to CCC | Install |
|--------|-------------|---------------------|---------|
| **plugin-dev** | claude-plugins-official | Plugin authoring: skill/command/hook/agent development guides | `claude plugins add plugin-dev@claude-plugins-official` |

## Anthropic Official Resources

Anthropic maintains two plugin repositories. CCC users should be aware of these for complementary coverage.

### claude-code/plugins (13 plugins)

| Plugin | CCC Relationship | Notes |
|--------|-----------------|-------|
| `agent-sdk-dev` | No overlap | Agent SDK development guides |
| `claude-opus-4-5-migration` | No overlap | Model migration patterns |
| `code-review` | Adjacent | 5 parallel Sonnet agents for PR review. CCC `code-reviewer` agent provides spec-aware review. Both can coexist. |
| `commit-commands` | Adjacent | Git commit conventions. CCC relies on CLAUDE.md git rules. |
| `explanatory-output-style` | No overlap | Output style hooks |
| `feature-dev` | Overlapping | 7-phase feature development. CCC's spec workflow (Stages 0-7.5) replaces this entirely. Do not install alongside CCC. |
| `frontend-design` | Complementary | UI/frontend patterns. No CCC equivalent. |
| `hookify` | Complementary | React 19 hooks migration. No CCC equivalent. |
| `learning-output-style` | No overlap | Interactive learning mode |
| `plugin-dev` | Complementary | Plugin authoring toolkit. Recommended for CCC development. |
| `pr-review-toolkit` | Adjacent | PR review patterns. CCC `pr-dispatch` and `code-reviewer` cover similar ground. |
| `ralph-wiggum` | Complementary | Personality/style plugin |
| `security-guidance` | Complementary | Security hooks. No CCC equivalent. |

### knowledge-work-plugins (12 plugins)

| Plugin | CCC Relationship | Notes |
|--------|-----------------|-------|
| `bio-research` | No overlap | Biology/life sciences research |
| `cowork-plugin-management` | No overlap | Cowork plugin marketplace UI management |
| `customer-support` | No overlap | Customer support workflows |
| `data` | No overlap | Data analysis patterns |
| `enterprise-search` | Complementary | Internal knowledge discovery (Slack, docs, email). CCC covers public + academic research. See CONNECTORS.md for details. |
| `finance` | No overlap | Financial analysis |
| `legal` | No overlap | Legal document analysis |
| `marketing` | No overlap | Marketing strategy |
| `product-management` | Adjacent | PM spec writing (their Stage 0-3). CCC drives specs through review + implementation (Stages 3-7.5). Can coexist. |
| `productivity` | No overlap | General productivity patterns |
| `sales` | No overlap | Sales workflows |

**Key guidance:** Avoid installing `feature-dev` alongside CCC -- it conflicts with CCC's spec workflow. All other official plugins are safe to install alongside CCC.

## How Companions Fit the Funnel

```
Stage 0-2: Ideation & Analytics
  └── (CCC covers this)

Stage 3: PR/FAQ Draft
  └── (CCC covers this -- /ccc:write-prfaq)

Stage 4: Adversarial Review
  └── (CCC covers this -- spec-level review)

Stage 5: Visual Prototype
  ├── v0 (Code, project-level MCP) → UI component generation, page layouts
  ├── Figma (Cowork/Desktop, OAuth) → high-fidelity mockups, design system
  ├── Pencil MCP (Code) → .pen file design, design system inspection
  └── visual-documentation-skills → architecture diagrams ONLY (not UI prototyping)

Stage 6: Implementation
  ├── developer-essentials:code-review-excellence → conduct PR reviews
  ├── developer-essentials → auth, SQL, testing patterns
  ├── backend-development → API design, microservices
  ├── python-development → async, testing, packaging
  ├── code-operations-skills → bulk refactoring, file ops
  ├── context7-plugin → library documentation lookup
  ├── supabase-pack → database patterns
  └── vercel-pack → deployment patterns

Stage 7: Verification
  └── (CCC covers this -- quality scoring, evidence-based closure)
```

## Overlap Evaluation

These external skills partially overlap with CCC capabilities.

| External Skill | CCC Parallel | Decision | Rationale |
|----------------|-------------|----------|-----------|
| developer-essentials:`code-review-excellence` | adversarial-review | **Companion** | code-review-excellence teaches PR review technique (severity labels, time-boxing, language-specific checklists). CCC adversarial-review is multi-perspective spec stress testing. Different targets (code vs specs), different methodology. |

**Summary:** CCC operates at the spec/methodology layer; companion skills operate at the code/process layer. They complement rather than conflict.
