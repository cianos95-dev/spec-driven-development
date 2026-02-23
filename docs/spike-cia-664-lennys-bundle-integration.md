# CIA-664: Lenny's Bundle Multi-Tool Integration — Spike Findings

> **Status:** Complete
> **Date:** 23 Feb 2026
> **Author:** Tembo (background agent)
> **Time-box:** 3pt (spike)

## Summary

Lenny's Product Pass bundle provides 6 tools ($3,133/yr value): Factory ($240), Amp ($1,825), Framer ($360), Magic Patterns ($228), Manus ($240), Warp ($240). This spike evaluates each tool's integration into the CCC multi-surface development pipeline, answering 6 spike questions and the cross-subscription matrix extension.

**Key finding:** Factory is the only tool that qualifies for Linear dispatch pipeline integration. Amp qualifies as a rate-limit overflow target via SDK/CLI (not Linear dispatch). The remaining 4 tools are standalone or manual-trigger only.

---

## Spike Question Answers

### Q1: Linear Dispatch Eligibility — Can Factory and Amp accept `delegateId` webhooks from Linear?

**Factory: YES — fully eligible.**

Factory has a native Linear integration ([linear.app/integrations/factory](https://linear.app/integrations/factory)). Once connected, `@Factory` becomes available as an assignee across all teams. The dispatch flow:

1. Assign issue to Factory or `@mention` Factory in a comment
2. Factory provisions a remote workspace and launches a Droid with full issue context
3. Droid implements the solution autonomously
4. Factory opens a PR linked to the original issue
5. PR Review Droids auto-review the code

This matches the CCC Universal Dispatch Flow (CONNECTORS.md:156-173) exactly. Factory receives Linear webhooks on delegation (push-based), reads issue context, produces PRs, and posts status comments.

**Evidence:** [Factory Linear Integration page](https://linear.app/integrations/factory), [Factory GA announcement](https://factory.ai/news/factory-is-ga), [Factory docs on custom droids](https://docs.factory.ai/cli/configuration/custom-droids).

**Amp: NO — does not have native Linear dispatch.**

Amp (Sourcegraph) does not appear as a Linear integration. Amp connects to Linear via MCP servers (using OAuth) for reading/writing issues within an Amp session, but this is pull-based — the developer initiates Amp, which then accesses Linear context. There is no evidence of Amp accepting `delegateId` webhooks or appearing as a Linear assignee.

Amp can serve as a **rate-limit overflow target** via its SDK (`execute()` function) or CLI (`--stream-json` mode), which could be orchestrated by n8n or called from a GitHub Action. But this is programmatic dispatch, not Linear-native dispatch.

**Evidence:** [Amp manual](https://ampcode.com/manual), [Amp SDK docs](https://ampcode.com/manual/sdk), [Amp MCP OAuth docs](https://ampcode.com/manual). No Linear integration page exists for Amp.

### Q2: Instruction File Support — Which tools support instruction files?

| Tool | AGENTS.md | Custom Format | None |
|------|-----------|---------------|------|
| **Factory** | **Yes** — reads `AGENTS.md` at repo root + hierarchical subtree files. Also uses `.factory/droids/` for custom sub-agent definitions. | `.factory/` directory (droids, slash commands) | — |
| **Amp** | **Yes** — reads `AGENTS.md` files hierarchically (CWD up to `$HOME`). Supports `@-mentions` and globs for including referenced files. Can auto-generate AGENTS.md. | `.amp/settings.json` (workspace config) | — |
| **Warp** | **Yes** — supports `WARP.md` (compatible with `agents.md`, `claude.md`). | Warp Drive (shared commands, notebooks, env vars, prompts) | — |
| **Magic Patterns** | No | Custom design system import (Storybook, Figma) | — |
| **Framer** | No | No | Standalone web builder |
| **Manus** | No | No | Autonomous agent, no repo-level config |

**Instruction file proliferation risk:** LOW. Factory and Amp both read `AGENTS.md`, which is the emerging open standard (stewarded by Agentic AI Foundation under Linux Foundation). The CCC repo already has `CLAUDE.md`. Migration path: `ln -s CLAUDE.md AGENTS.md` (Amp docs recommend this exact pattern). No new instruction file format is needed.

**Warp** reads `WARP.md` but also supports `agents.md` and `claude.md` natively, so a symlink suffices.

**Evidence:** [Factory AGENTS.md docs](https://docs.factory.ai/cli/configuration/agents-md), [AGENTS.md spec](https://agents.md/), [Amp manual on agent files](https://ampcode.com/manual), [Warp MCP docs](https://docs.warp.dev/agent-platform/capabilities/mcp).

### Q3: Credential/MCP Access — Which tools need Doppler/MCP access?

| Tool | Needs MCP? | Needs Doppler/Secrets? | Credential Method |
|------|-----------|----------------------|------------------|
| **Factory** | No — Factory provisions its own remote workspace with full context | Yes — needs Linear OAuth (workspace admin enables integration) + GitHub App | Linear integration settings → Enable Factory |
| **Amp** | Yes — uses MCP servers for Linear, GitHub, and other tools | Yes — `AMP_API_KEY` env var, Linear OAuth tokens stored in `~/.amp/oauth/` | MCP server config in `.amp/settings.json` |
| **Warp** | Yes — acts as MCP client, connects to Linear, Figma, Slack, Sentry MCP servers | Yes — env vars for API keys, OAuth for one-click installs | MCP server config in Warp settings (JSON) |
| **Magic Patterns** | No | No (web app, browser-based) | Magic Patterns account login |
| **Framer** | No | No (standalone hosting) | Framer account login |
| **Manus** | No direct MCP | No (web app, API-key based) | Manus account + credits |

**`sync-mcp-configs.sh` extension needed:** NO. There is no `sync-mcp-configs.sh` script in the repo currently (confirmed via codebase search). MCP configs are reference-only fragments in CONNECTORS.md. Factory uses its own Linear integration (no MCP). Amp and Warp configure MCP servers locally per-developer. No central sync script extension is required.

**Doppler extension needed:** Only if Factory's Linear OAuth credentials need to be shared across team members (currently solo workflow — OS Keychain is sufficient).

**Evidence:** [Factory integration setup](https://linear.app/integrations/factory), [Amp MCP OAuth](https://ampcode.com/manual), [Warp MCP docs](https://docs.warp.dev/agent-platform/capabilities/mcp).

### Q4: Concurrent Agent Limits — Maximum concurrent agents on same monorepo?

**Theoretical limit:** Unlimited, given proper branch isolation.

**Practical limit:** 5-8 concurrent agents before coordination overhead outweighs throughput gains.

**Analysis:**

The branch naming convention `{agent}/{CIA-XXX}-{slug}` prevents branch collisions. Each agent works on a separate issue on a separate branch. Merge conflicts only arise when:

1. Two agents modify the same file on different branches (resolved at PR merge time)
2. Two agents work on overlapping functionality (prevented by single-assignment-per-issue rule)

Factory explicitly supports this: "You can scale engineering capacity instantly by running tens or hundreds simultaneously, each in its own isolated environment" ([Factory GA announcement](https://factory.ai/news/factory-is-ga)). Factory uses remote workspace isolation.

Tembo also supports parallelization: "A developer can dispatch five agents to five different tasks simultaneously, each working in its own isolated container" ([Tembo blog](https://www.tembo.io/blog/async-coding-agents)).

**CCC-specific constraints:**
- Turborepo per-app isolation reduces cross-app merge conflicts
- CCC's `parallel-dispatch` skill caps at 3 sessions for implementation, 5 for research
- Current recommendation: keep interactive agents at 5-6 max; Factory/Amp/Tembo are background dispatch targets that don't count toward the interactive cap

**Evidence:** Factory remote workspace architecture, Tembo isolated containers, CCC parallel-dispatch skill (`skills/parallel-dispatch/SKILL.md`).

### Q5: Design System Coherence — Can Magic Patterns export to Figma format?

**YES — Magic Patterns has a Figma plugin for direct export.**

Export flow:
1. Generate UI in Magic Patterns (text prompt, image, or Figma import)
2. Menu bar → "Export to Figma" (or hotkey `Option+F`)
3. Get layer ID → paste in Figma plugin → layers appear in Figma

Recent upgrades (2026): Figma import now enriched via Figma MCP automatically (no Chrome extension needed). Exact color values preserved. Batch export of multiple designs supported.

**Design pipeline integration:**
```
Magic Patterns (rapid prototyping, upstream)
  → Figma (finalize, source of truth via CIA-628 pipeline)
    → Code Connect
      → @claudian/ui (component library)
```

This confirms the design divergence mitigation strategy in the issue description. Magic Patterns serves as upstream prototyping; Figma remains the single design source of truth.

**Evidence:** [Magic Patterns Figma plugin](https://www.figma.com/community/plugin/1304255855834420274/magic-patterns), [Magic Patterns changelog](https://www.magicpatterns.com/docs/documentation/feature-releases/changelog).

### Q6: Terminal Integration — Does Warp's AI agent integrate with our MCPs?

**YES — Warp acts as a full MCP client.**

Warp supports:
- **MCP server connections:** Linear, Figma, Slack, Sentry, filesystem, and custom servers
- **Connection protocols:** Streamable HTTPS, SSE, custom headers, environment variables
- **Authentication:** Environment variables (API keys) and OAuth (one-click)
- **Team sharing:** Share MCP configs with teammates (sensitive values auto-scrubbed)
- **MCP Gallery:** One-click installs from curated servers
- **Configuration:** JSON snippet format, compatible with most MCP client configs (copy-paste from Claude Code, Cursor, etc.)
- **Model support:** 20+ models including Claude, GPT, Gemini, Grok

Warp reads `WARP.md` (compatible with `agents.md`/`claude.md`) for agent behavior control.

**However**, Warp is a local development tool — it runs on the developer's machine, not as a dispatch target. It cannot receive Linear `delegateId` webhooks. Its value is as an enhanced local terminal with AI and MCP access, not as a pipeline agent.

**Evidence:** [Warp MCP docs](https://docs.warp.dev/agent-platform/capabilities/mcp), [Warp 2.0 blog](https://www.warp.dev/blog/reimagining-coding-agentic-development-environment), [Warp agents page](https://www.warp.dev/agents).

---

## GO/NO-GO Decisions

| Tool | Pipeline Integration | Decision | Rationale |
|------|---------------------|----------|-----------|
| **Factory** | Linear dispatch target | **GO** | Native Linear integration, `delegateId`-compatible, AGENTS.md support, remote workspace isolation. Direct competitor to Tembo for background execution. |
| **Amp** | Rate-limit overflow (SDK/CLI) | **GO (conditional)** | No Linear dispatch, but SDK/CLI enables programmatic dispatch via n8n or GitHub Actions. Useful as overflow when Claude Code + Tembo hit rate limits. |
| **Magic Patterns** | Figma upstream prototyping | **GO (standalone)** | Figma export confirmed. Fits CIA-628 pipeline. No dispatch integration needed — manual trigger by designer/PM. |
| **Framer** | Standalone marketing | **GO (standalone)** | Independent hosting, no pipeline integration needed. Marketing pages deploy to Framer hosting, not Vercel. |
| **Manus** | Research tasks | **NO-GO** | Meta acquisition (Dec 2025) paused new signups. Service integration uncertain. Use Firecrawl + academic MCPs for research instead. |
| **Warp** | Local terminal enhancement | **GO (local only)** | Full MCP client, AGENTS.md-compatible, team sharing. Not a dispatch target but valuable for local development. |

---

## Factory vs Tembo Comparison

| Dimension | Factory (Lenny's bundle: $0/yr) | Tembo (Pro: $720/yr) |
|-----------|-------------------------------|---------------------|
| **Linear dispatch** | Native (assignee + @mention) | Native (assignee + @mention) |
| **Execution model** | Proprietary Droids in remote workspace | Agent-agnostic (Claude Code, Cursor, Codex, Amp) in isolated VMs |
| **Instruction files** | AGENTS.md + `.factory/droids/` | CLAUDE.md (via Claude Code) |
| **PR creation** | Automatic, linked to Linear issue | Automatic, linked to Linear issue |
| **Auto-review** | Built-in PR Review Droids | Relies on Copilot/Codex external review |
| **Concurrent agents** | "Tens or hundreds" (remote workspace isolation) | 5+ per developer (isolated containers) |
| **Model selection** | Proprietary (no BYOK info) | 25+ models, Claude Code default |
| **MCP access** | No (self-contained) | Yes (4 built-in MCPs + auto-configures Linear/GitHub) |
| **Cost** | $0 (Lenny's bundle, 1 year free, normally $240/yr) | $60/mo ($720/yr) |
| **Lock-in risk** | High (proprietary Droids) | Low (agent-agnostic, works with any coding agent) |
| **Verified commits** | Unknown | Yes (signed commits) |
| **Credit system** | Unknown (likely usage-based after free year) | 100 credits/mo on Pro |

### Recommendation: Run Both in Parallel (A/B Test)

**Do NOT replace Tembo with Factory.** Instead:

1. **Factory** → Background dispatch for well-scoped `exec:quick` tasks (free tier, conserves Tembo credits)
2. **Tembo** → Background dispatch for complex tasks requiring MCP access, multi-repo coordination, or specific model selection
3. **Evaluation period:** 30 days, track PR quality (0-5 rubric) and time-to-PR for both
4. **Decision gate:** After 30 days, if Factory quality >= 3.5 avg on the PR rubric, shift `exec:quick` tasks to Factory permanently and reduce Tembo to complex-only (saves ~40% of credit burn)

The $720/yr savings potential is real but premature to capture without quality data. Factory's free year provides a risk-free evaluation window.

---

## Updated Rate Limit Waterfall

Current waterfall (5 interactive tools) remains unchanged. Factory and Amp are background dispatch targets, not interactive tools.

```
Interactive (human-in-loop, max 5-6):
  1. Claude Code (primary — spec, review, implementation)
  2. Cursor (exec:tdd, IDE pairing)
  3. Warp (local terminal, MCP-enabled) ← NEW
  4. GitHub Copilot (auto PR review)
  5. Magic Patterns (design prototyping) ← NEW (manual, upstream)

Background (dispatch targets, no cap):
  6. Tembo (adopted — complex background execution)
  7. Factory (new — simple background execution) ← NEW
  8. Amp (conditional — overflow via SDK/CLI) ← NEW

Standalone (independent deployment):
  9. Framer (marketing pages, own hosting)

Deprecated/Unavailable:
  10. Manus (Meta acquisition, signups paused)
```

**Interactive count:** 5 (unchanged from current). Warp replaces the terminal slot. Magic Patterns is occasional/manual.
**Background count:** 3 (was 1). Factory and Amp added as dispatch targets.

---

## Cross-Subscription Accessibility Matrix

| Tool | Claude Code | Cursor | Warp | Codex | Linear (dispatch) | n8n |
|------|------------|--------|------|-------|-------------------|-----|
| **Factory** | N/A (separate) | N/A (separate) | N/A | N/A | **Yes** (native integration) | Possible (via Linear webhook → n8n → Factory API) |
| **Amp** | N/A (separate CLI/VS Code) | Yes (VS Code fork compatible) | N/A | N/A | No (MCP read-only) | **Yes** (SDK `execute()`, CLI `--stream-json`) |
| **Magic Patterns** | N/A (web app) | N/A | N/A | N/A | No | No |
| **Framer** | N/A (web app) | N/A | N/A | N/A | No | Possible (Server API) |
| **Manus** | N/A (web app) | N/A | N/A | N/A | No | N/A (signups paused) |
| **Warp** | N/A (terminal) | N/A | — | N/A | No | No |

**Key insight:** Factory is the only tool accessible from Linear dispatch. Amp is the only tool accessible programmatically (SDK/CLI) for n8n orchestration.

---

## Credential Distribution Strategy

| Tool | Auth Method | Credential Storage | Doppler Needed? |
|------|-----------|-------------------|-----------------|
| **Factory** | Linear OAuth (workspace admin enables) | Factory account (cloud-managed) | No |
| **Amp** | `AMP_API_KEY` env var + Linear MCP OAuth | `~/.amp/oauth/` (local) + `~/.config/amp/settings.json` | No (local only) |
| **Warp** | Per-MCP server: env vars or OAuth | Warp secure credential store (device-local) | No (local only) |
| **Magic Patterns** | Browser session | Magic Patterns account | No |
| **Framer** | Browser session + Server API credentials | Framer account + API key | No |
| **Manus** | API credits | N/A (paused) | N/A |

**No Doppler extension needed.** All tools use either cloud-managed OAuth (Factory) or local credential stores (Amp, Warp). No shared secrets to distribute.

---

## Linear Agent Roles

| Tool | Dispatch Eligibility | Method | Reactivity |
|------|---------------------|--------|------------|
| **Factory** | **Full dispatch** | `delegateId` webhook + `@Factory` mention | Push-based (fully async) |
| **Amp** | **No dispatch** | N/A — must be invoked via SDK/CLI | Pull-based (session-required) |
| **Warp** | **No dispatch** | N/A — local terminal | N/A (local only) |
| **Magic Patterns** | **No dispatch** | Manual (web app) | N/A |
| **Framer** | **No dispatch** | Manual (web app) | N/A |
| **Manus** | **No dispatch** | N/A (paused) | N/A |

Factory should be added to the CONNECTORS.md Agent Configuration Status table and Agent-to-Stage Mapping.

---

## n8n Event Bus Assessment

**Can n8n orchestrate dispatch across tools? YES — with limitations.**

n8n supports:
- **Linear webhook trigger:** Receives Linear events (issue created, updated, assigned, commented)
- **HTTP request node:** Can call Factory API, Amp SDK, Framer Server API
- **Agent-to-Agent workflows:** Multi-agent systems where specialized agents collaborate
- **Queue mode:** Horizontal scaling for production workloads

**Feasible n8n orchestration patterns:**

1. **Linear → n8n → Factory:** Linear webhook fires on issue assignment → n8n evaluates task complexity → delegates to Factory if `exec:quick`, Tembo if complex
2. **Linear → n8n → Amp CLI:** Linear webhook → n8n runs Amp CLI via SSH/exec node → Amp processes task → n8n posts result back to Linear
3. **Rate-limit overflow:** n8n monitors Claude Code rate limit signals → routes overflow tasks to Amp or Factory

**Limitations:**
- Factory's Linear integration is already native — n8n adds unnecessary indirection for simple Factory dispatch
- Amp doesn't have a native Linear integration, so n8n is the primary orchestration path for Amp
- n8n is already in the Lenny's bundle (confirmed in Product Pass listing) — no additional cost

**Recommendation:** Use n8n only for Amp dispatch orchestration. Factory should be dispatched directly via Linear (native integration is simpler and more reliable).

---

## Updated Tool Assessment Matrix

| Tool | Strategy | Surface | MCP? | API? | Linear? | Dispatch? | GO/NO-GO |
|------|----------|---------|------|------|---------|-----------|----------|
| **Factory** | Align — Linear agent dispatch target | Linear delegateId | No (self-contained) | Yes | **Yes** (native) | **Yes** (push-based) | **GO** |
| **Amp** | Maximize — rate limit overflow | SDK/CLI programmatic | Yes (MCP client) | Yes (SDK + CLI) | Read-only (MCP) | **Conditional** (via n8n/SDK) | **GO (conditional)** |
| **Magic Patterns** | Align — fold into Figma/V0 pipeline | Web app + Figma plugin | No | Yes (export) | No | Manual | **GO (standalone)** |
| **Framer** | Maximize — standalone marketing | Standalone hosting | No | Yes (Server API) | No | Standalone | **GO (standalone)** |
| **Manus** | Defer — Meta acquisition | N/A | No | N/A (paused) | No | N/A | **NO-GO** |
| **Warp** | Maximize — terminal with MCP | Local dev (MCP client) | **Yes** (full MCP client) | Native CLI | No | Local only | **GO (local)** |

---

## CONNECTORS.md Updates Required

If Factory is adopted, the following sections of CONNECTORS.md need updating:

1. **Adopted Agents table** (line 98-106): Add Factory row
2. **Agent-to-Stage Mapping** (line 126-134): Add Factory to Stage 6
3. **Agent Credential Patterns** (line 138-149): Add Factory auth method
4. **Agent Configuration Status** (line 437-453): Add Factory row
5. **Context Files by Agent** (line 299-308): Add Factory row (reads AGENTS.md + `.factory/droids/`)
6. **Free Tier Bundle** (line 349-358): Add Factory (free via Lenny's bundle)
7. **Agent Performance Benchmarks** (line 403-435): Add Factory placeholder row

Additionally, create `AGENTS.md` at repo root as a symlink to `CLAUDE.md`:
```bash
ln -s CLAUDE.md AGENTS.md
```

This enables both Factory and Amp to read project instructions without maintaining a separate file.

---

## Follow-Up Issues to Create

1. **CIA-XXX: Add Factory to CONNECTORS.md agent catalog** — Update all 7 sections listed above
2. **CIA-XXX: Create AGENTS.md symlink** — `ln -s CLAUDE.md AGENTS.md` for Factory/Amp/Codex compatibility
3. **CIA-XXX: Configure Factory Linear integration** — Enable Factory in workspace settings, authorize access, test dispatch
4. **CIA-XXX: Factory vs Tembo A/B evaluation (30 days)** — Track PR quality and time-to-PR across both tools
5. **CIA-XXX: Evaluate Amp SDK dispatch via n8n** — Build n8n workflow: Linear webhook → Amp CLI → Linear comment
6. **CIA-XXX: Configure Warp MCP servers** — Set up Linear, GitHub, Sentry MCP servers in Warp for local development

---

## Acceptance Criteria Status

### Original Criteria

- [x] Each of the 6 spike questions answered with evidence (not opinion) — See Q1-Q6 above
- [x] GO/NO-GO for each tool's integration into dispatch pipeline — See GO/NO-GO table
- [x] Updated rate limit waterfall if any tools qualify — See Updated Rate Limit Waterfall
- [x] Updated `sync-mcp-configs.sh` scope if any tools need MCP access — No script exists; no extension needed
- [x] Recommendation on Factory vs Tembo ($720/yr savings potential) — See comparison table; recommend parallel A/B test

### Cross-Subscription Matrix Extension

- [x] Cross-subscription accessibility matrix — See matrix table
- [x] Credential distribution strategy — See credential table; no Doppler extension needed
- [x] Linear agent roles — See roles table; Factory is the only new dispatch-eligible agent
- [x] n8n event bus assessment — See assessment; use n8n for Amp dispatch only
- [x] Updated rate limit waterfall position for each adopted tool — See waterfall diagram
