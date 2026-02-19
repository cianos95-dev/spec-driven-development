# Anthropic Plugin Compatibility Matrix

**Last updated:** 2026-02-19
**Next review:** Quarterly or when Anthropic adds/removes plugins

Track compatibility between CCC and Anthropic's official plugins. Updated when Anthropic publishes new plugins, when CCC adds skills that create overlaps, or when we install/drop an official plugin.

## Relationship Categories

- **Complementary:** No overlap. Safe to install alongside CCC for additional coverage.
- **Adjacent:** Minor overlap in trigger phrases or scope. Both can be installed but some skills may fire for similar prompts.
- **Overlapping:** Significant functional overlap. Choose one or configure skill priority.
- **No overlap:** Different domain entirely. No interaction.

---

## claude-code/plugins (13 plugins)

Source: `github.com/anthropics/claude-code/plugins/`
License: Proprietary (Anthropic PBC). Cannot bundle or redistribute.

| Plugin | Relationship | CCC Equivalent | Overlap Area | Recommendation |
|--------|-------------|---------------|--------------|----------------|
| `agent-sdk-dev` | No overlap | -- | Agent SDK development | Install if building custom agents |
| `claude-opus-4-5-migration` | No overlap | -- | Model migration patterns | Install during model upgrades |
| `code-review` | Adjacent | `code-reviewer` agent, `pr-dispatch` skill | PR code review dispatch | CCC provides spec-aware review (checks acceptance criteria, detects drift). Official plugin provides 5 parallel Sonnet agents for general code quality. Can coexist -- CCC catches spec drift, official catches code quality. |
| `commit-commands` | Adjacent | CLAUDE.md git rules | Git commit conventions | CCC relies on CLAUDE.md for git behavior. Install if you want structured commit commands beyond CLAUDE.md rules. |
| `explanatory-output-style` | No overlap | -- | Output verbosity hooks | Safe to install. CCC's STYLE.md governs output style for CCC-generated content only. |
| `feature-dev` | **Overlapping** | `spec-workflow`, `execution-engine`, `execution-modes` | 7-phase feature development lifecycle | **Do not install alongside CCC.** CCC's Stages 0-7.5 cover the same ground with more granular control. Both will try to manage the feature lifecycle, causing conflicts. |
| `frontend-design` | Complementary | -- | UI/frontend patterns | Install for frontend projects. No CCC equivalent. |
| `hookify` | Complementary | -- | React 19 hooks migration | Install for React modernization. No CCC equivalent. |
| `learning-output-style` | No overlap | -- | Interactive learning mode | Safe to install. Does not affect CCC behavior. |
| `plugin-dev` | Complementary | -- | Plugin authoring toolkit | **Recommended.** Install for CCC plugin development and maintenance. |
| `pr-review-toolkit` | Adjacent | `pr-dispatch`, `review-response`, `code-reviewer` agent | PR review patterns | CCC covers the full review lifecycle (dispatch, structured findings, response triage). Install if you want additional review heuristics. |
| `ralph-wiggum` | Complementary | -- | Personality/style | Safe to install. No CCC interaction. |
| `security-guidance` | Complementary | -- | Security hooks and patterns | Install for security-sensitive projects. CCC's `reviewer-security-skeptic` agent covers spec-level security; this covers code-level. |

## knowledge-work-plugins (12 plugins)

Source: `github.com/anthropics/knowledge-work-plugins/`
License: Proprietary (Anthropic PBC).

| Plugin | Relationship | CCC Equivalent | Overlap Area | Recommendation |
|--------|-------------|---------------|--------------|----------------|
| `bio-research` | No overlap | -- | Biology/life sciences | Install for life sciences research |
| `cowork-plugin-management` | No overlap | -- | Cowork UI plugin management | Desktop-only. No CLI equivalent. |
| `customer-support` | No overlap | -- | Support workflows | Install for customer support teams |
| `data` | No overlap | -- | Data analysis | Install for data-heavy projects |
| `enterprise-search` | Complementary | `research-pipeline`, `research-grounding` | Knowledge discovery | CCC covers public + academic research. Enterprise-search covers internal (Slack, docs, email). See CONNECTORS.md for combined coverage matrix. |
| `finance` | No overlap | -- | Financial analysis | Install for finance teams |
| `legal` | No overlap | -- | Legal documents | Install for legal teams |
| `marketing` | No overlap | -- | Marketing strategy | Install for marketing teams |
| `product-management` | Adjacent | `spec-workflow`, `prfaq-methodology` | PM spec writing | Product-management covers early PM work (Stages 0-3). CCC drives specs through review and implementation (Stages 3-7.5). **Can coexist** -- product-management feeds into CCC's workflow. |
| `productivity` | No overlap | -- | General productivity | Safe to install |
| `sales` | No overlap | -- | Sales workflows | Install for sales teams |

## Claude Code Built-in Features

Features built into Claude Code itself that may overlap with CCC or companion plugins.

| Feature | CCC Equivalent | Status |
|---------|---------------|--------|
| `/code-review` (5 parallel Sonnet agents) | `adversarial-review` Options D-H, `code-reviewer` agent | Adjacent. `/code-review` is general code quality; CCC is spec-aware review. Both valuable. |
| Plan mode (`/plan`, Shift+Tab) | `planning-preflight` + `spec-workflow` | Complementary. Plan mode is the UX container; CCC skills provide methodology within it. |
| `/init` (generate CLAUDE.md) | CCC's CLAUDE.md conventions | No conflict. CCC expects CLAUDE.md to exist. `/init` creates it. |
| Agent Teams | `parallel-dispatch` | Complementary. Agent Teams is the runtime; CCC `parallel-dispatch` governs routing policy. |
| Worktrees | `parallel-dispatch` | Complementary. Worktrees provide isolation; CCC skill governs when to use them. |

---

## Decision Guide

**Starting fresh with CCC?** Install these official plugins alongside CCC:
1. `plugin-dev` (Complementary -- plugin development toolkit)
2. `security-guidance` (Complementary -- code-level security)
3. `frontend-design` (Complementary -- if doing frontend work)

**Avoid:**
- `feature-dev` (Overlapping -- conflicts with CCC spec workflow)

**Safe to install anytime:**
- All knowledge-work-plugins except `product-management` (which is Adjacent but coexists fine)
- `agent-sdk-dev`, `explanatory-output-style`, `learning-output-style`, `ralph-wiggum`, `hookify`

---

## Update Protocol

1. **Quarterly:** Run `gh api repos/anthropics/claude-code/contents/plugins --jq '.[].name'` and `gh api repos/anthropics/knowledge-work-plugins/contents --jq '.[].name'` to check for new plugins.
2. **On CCC skill addition:** Check if new skill creates overlap with any official plugin.
3. **On official plugin update:** Check changelogs for new features that may create overlap.
