# Connectors

This plugin works best with the following data sources connected. Configure them in your global `~/.mcp.json` or through your organization's MCP setup.

> **Note:** This plugin does NOT ship active MCP configs. Plugins expose skills, commands, and agents — not MCP servers. All MCP fragments shown below are **reference configurations** that you merge into your own `~/.mcp.json`. See [Troubleshooting](#troubleshooting) in README.md if you encounter MCP auth errors.

## Required

| Connector | Purpose | Funnel Stage | Default |
|-----------|---------|-------------|---------|
| **~~project-tracker~~** | Issue tracking, status transitions, label management | All stages | [Linear](https://mcp.linear.app/mcp) |
| **~~version-control~~** | Pull requests, code review, spec file management | Stages 3-7 | [GitHub](https://api.githubcopilot.com/mcp/) |

### Linear Setup Checklist (~~project-tracker~~ Reference Implementation)

Linear is the default ~~project-tracker~~ for CCC. Complete this checklist to configure it fully. For detailed guidance on each item, see [docs/LINEAR-SETUP.md](docs/LINEAR-SETUP.md).

**Team & Workspace:**
- [ ] Team created with memorable key prefix (e.g., `CIA`, `PRJ`)
- [ ] Triage mode enabled (new issues land in Triage for review)
- [ ] Cycles enabled (1-week duration, Monday start)
- [ ] Auto-archive set to 3 months after completion

**Label Taxonomy (29 labels):**
- [ ] Type labels created: `type:feature`, `type:bug`, `type:chore`, `type:spike`
- [ ] Spec labels created: `spec:draft`, `spec:ready`, `spec:review`, `spec:implementing`, `spec:complete`
- [ ] Exec labels created: `exec:quick`, `exec:tdd`, `exec:pair`, `exec:checkpoint`, `exec:swarm`
- [ ] Research labels created: `research:needs-grounding`, `research:literature-mapped`, `research:methodology-validated`, `research:expert-reviewed`
- [ ] Template labels created: `template:prfaq-feature`, `template:prfaq-infra`, `template:prfaq-research`, `template:prfaq-quick`
- [ ] Origin labels created: `source:voice`, `source:cowork`, `source:code-session`, `source:direct`, `source:vercel-comments`

**Project & Milestones:**
- [ ] First project created with description template (milestone map, decision log, resources)
- [ ] Initial milestone created (naming: `vX.Y — Description`)
- [ ] Project description includes staleness rules (14-day threshold)

**Estimates & Templates:**
- [ ] Estimates configured: Fibonacci extended (1, 2, 3, 5, 8, 13)
- [ ] "Count unestimated" enabled (1pt default for velocity tracking)
- [ ] Issue templates available: Feature, Bug, Spike, Chore (4 total)
- [ ] Document templates available: PR/FAQ, Research Findings, ADR, Session Plan (4 total)
- [ ] Project template available: Standard Project (1 total)

**Agent Delegation:**
- [ ] Agent guidance configured (Settings > Agents > Additional guidance)
- [ ] Pre-built agents enabled (6 total): Claude, ChatPRD, Codex, Cursor, GitHub Copilot, Sentry
- [ ] All relevant agents enabled on project templates
- [ ] Agent credential patterns documented per CONNECTORS.md Agent Credential Patterns table
- [ ] Triage Intelligence enabled (suggestions-only mode — never auto-apply)

**OAuth App (Programmatic Access):**
- [ ] OAuth app created (Settings > API > OAuth Applications)
- [ ] Actor set to Application (not User)
- [ ] Client Credentials grant enabled
- [ ] Required scopes authorized: `read`, `write`, `issues:create`, `comments:create`
- [ ] Optional scopes considered: `initiative:read`, `initiative:write`
- [ ] Credentials stored in Keychain (`claude/linear-oauth-*`)
- [ ] Token rotation plan in place (30-day expiry)

**Initiatives (Optional — Multi-Project Only):**
- [ ] Initiative created for each strategic theme or time-bound goal
- [ ] Projects linked to relevant initiatives

**Operational Habits:**
- [ ] Daily inbox triage ritual established
- [ ] Monday cycle planning ritual established
- [ ] Session-end project update habit in place

## Recommended

| Connector | Purpose | Funnel Stage | Examples |
|-----------|---------|-------------|----------|
| **~~ci-cd~~** | Automated spec review triggers, deployment checks | Stages 4, 7 | GitHub Actions |
| **~~deployment~~** | Preview deployments, production verification | Stages 5, 7 | Vercel, Netlify, Railway |
| **~~analytics~~** | Data-informed spec drafting, post-launch verification | Stages 2, 7 | PostHog, Amplitude, Mixpanel |
| **~~error-tracking~~** | Production error monitoring, auto-issue creation | Stage 7 | Sentry, Bugsnag |
| **~~component-gen~~** | UI component generation for visual prototyping | Stage 5 | v0.dev, Lovable |
| **~~email-marketing~~** | Mailing list management, subscriber segmentation, campaign triggers | Stages 6-7 | Mailchimp, SendGrid, Resend, ConvertKit |
| **~~geolocation~~** | IP-based region inference, geo-aware features | Stage 6 | Vercel headers (`x-vercel-ip-country`), ipapi.co, MaxMind |

## Optional

| Connector | Purpose | Funnel Stage | Examples |
|-----------|---------|-------------|----------|
| **~~research-library~~** | Literature grounding for research-based features | Stages 1-2 | Zotero |
| **~~web-research~~** | Web data for spec grounding and competitive analysis | Stages 1-2 | Firecrawl |
| **~~academic-search~~** | Paper discovery, citation analysis, author lookup | Stages 1-2 | Semantic Scholar, arXiv, OpenAlex |
| **~~model-registry~~** | ML model/dataset/space search for technical grounding | Stages 1-2 | HuggingFace, Kaggle |
| **~~community-signal~~** | Developer sentiment, launch analysis, tutorial discovery | Stages 1-2 | Hacker News, YouTube |
| **~~communication~~** | Stakeholder notifications, decision tracking | All stages | Slack |
| **~~design~~** | Visual prototyping handoff | Stage 5 | Figma, v0 |
| **~~observability~~** | Traces, metrics, health monitoring | Stage 7 | Honeycomb, Datadog |

## Agent Connectors

External AI agents that integrate with the CCC funnel via ~~project-tracker~~ (Linear) delegation. These are optional accelerators — Claude Code remains the primary agent for all stages.

### Adopted Agents

| Agent | CCC Stages | Dispatch Method | Cost | Free Tier Viable |
|-------|-----------|-----------------|------|------------------|
| **cto.new** (Engine Labs) | 0 (intake), 5-6 (implement) | Linear delegation | Free | Yes |
| **Sentry** | 7 (error verification) | Error tracking integration → auto-issue creation | Free tier | Yes |
| **Cursor** | 6 (implement, exec:tdd) | Linear assignment (native integration) | $20/mo (Pro) | No |
| **GitHub Copilot** | 6 (implement, exec:quick) | GitHub Actions label-based auto-assignment | Free tier | Yes |

### Conditional Agents

Adoption depends on budget and specific workflow needs. Not required for core CCC functionality.

| Agent | CCC Stages | Unique Value | Cost | Condition |
|-------|-----------|--------------|------|-----------|
| **Codex** (OpenAI) | 4 (code review), 6-7 | Structured PR code review with P1/P2 findings — no other agent offers this | $20/mo (ChatGPT Plus) | Adopt if GPT diversity + PR review automation is valued |
| **Cyrus** (Ceedar AI) | 6 (exec:tdd, exec:pair) | Git worktree isolation per issue, self-verification loop, MCP connections, live metrics | Community $0 (self-host CLI), Pro $50/mo (cloud, 5 repos), Team $120/mo (10 repos). Uses Claude Code subscription token. | Validated on Pro trial (CIA-463): delegation → PR in ~5 min. Self-verification not yet tested on non-trivial task. Pro trial expires ~23 Feb 2026. Promote to Adopted after 3+ non-trivial mergeable PRs. |
| **Tembo** (Tembo AI) | Orchestration (Layer 2) | **ADOPTED.** Cloud-hosted agent orchestrator — dispatches Claude Code, Codex, Cursor, Amp, Opencode in isolated VM sandboxes. Production-grade Linear bot (auto-status, repo selection UI), multi-repo coordinated PRs, 25+ models, `@tembo-io/mcp` npm package for dispatch from Claude Code. 4 built-in MCPs + auto-configures Linear/GitHub MCPs for agents. Signed/verified commits. | Pro $60/mo (100 credits/month) | **Adopted (CIA-459 spike complete, 17 Feb 2026).** Default background executor. CCC handles spec/planning/review, Tembo handles background execution. Superseded CIA-484–490 (31pt). Credit burn: ~1 for trivial, 3–8 for features, 8–15+ for complex. BYOK = Enterprise-only (Pro credits cover infra + LLM). |
| **Devin** (Cognition) | 4 (feasibility scoping), 6 (implement) | Batch parallel scoping with confidence scoring. Autonomous PR creation. | Core $20/mo (9 ACUs ≈ 2.25h), Team $500/mo | Adopt if batch feasibility scoping adds value beyond Claude Code estimation. CIA-461 tracks evaluation. |

### Demoted Agents

| Agent | Originally | Demotion Reason |
|-------|-----------|-----------------|
| **ChatPRD** | Stage 0-3 candidate | Does not support PR/FAQ templates; missing adversarial review and research grounding. **Linear integration requires Teams tier ($29/seat/mo, $349/year)** — Pro plan (incl. Lenny's Newsletter annual bundle) only includes Slack, Google Drive, Notion. Not justified for solo workflow. Keep connected but do not invest in CCC integration. Optional Stage 0 supplement only. CIA-462 tracks details. |

### Agent-to-Stage Mapping

| Funnel Stage | Primary Agent | Optional Accelerators |
|---|---|---|
| Stage 0: Intake | Claude (spec-author) | cto.new (plan agent), ChatPRD (optional) |
| Stage 1-3: Ideation → Spec | Claude (spec-author) | — (sole agent) |
| Stage 4: Adversarial Review | Claude (persona panel) | Codex (PR code review) |
| Stage 5: Prototype | Claude (implementer) | cto.new |
| Stage 6: Implementation | Claude Code | cto.new (exec:quick), Cursor (exec:tdd), Copilot (exec:quick), Cyrus (exec:tdd/pair) |
| Stage 7: Verification | Sentry (primary) | Codex (code review), Vercel Agent (if Pro), CI/CD |
| Stage 7.5: Closure | Claude (implementer) | — (sole agent) |

### Agent Credential Patterns

Agent credentials are separate from application runtime credentials. Each agent authenticates via its own mechanism:

| Agent | Auth Method | Credential Location |
|-------|------------|-------------------|
| cto.new | Linear OAuth — initiated FROM cto.new dashboard (Integrations → Linear). Linear UI "Enable" button redirects to docs only. | cto.new account settings → Integrations |
| Sentry | DSN + Linear integration | Sentry project settings → Linear integration |
| Cursor | Linear OAuth (native) | Cursor settings → Integrations |
| GitHub Copilot | GitHub App (automatic) | Repository settings → Copilot |
| Codex | Linear OAuth (via ChatGPT Plus) | ChatGPT settings → Integrations |
| Cyrus | Anthropic API key (BYOK) + GitHub App (`cyrusagent[bot]`) | Cyrus config or Linear integration. GitHub App on `cianos95-dev` org. |
| Vercel Agent | GitHub App (auto via Vercel integration) | Vercel dashboard → Settings → Agent. Requires Pro plan ($20/mo). |

### Agent Dispatch Protocol

All Linear-connected agents follow the same dispatch pattern. There are no agent-specific APIs, webhooks, or dispatch mechanisms — the entire integration runs through Linear's assignment and delegation primitives.

#### Universal Dispatch Flow

```
1. Human (or automation) delegates issue to agent via Linear
   - Use the "Delegate" field (agent dropdown), OR
   - @mention the agent in a comment
2. Agent receives the delegation signal
   - Native agents (cto.new, Cursor, Codex): webhook from Linear → agent server
   - OAuth app agents (Claude): pull-based (session reads delegated issues)
3. Agent reads issue context
   - Description, comments, labels, linked documents
   - Some agents also access the linked repo (Codex reads AGENTS.md, Cursor reads .cursor/rules/)
4. Agent produces output
   - Comment on the issue (findings, analysis, status updates)
   - PR on the linked repository (implementation, code review)
   - Status transition (move issue to next state)
5. Human reviews agent output
   - Accept, reject, or iterate
   - Remove delegation when agent work is complete
```

#### Agent Reactivity Model

Agents differ in how they receive delegation signals. This distinction determines whether dispatch is truly async (push-based) or requires a session (pull-based).

| Reactivity | Agents | How It Works | Latency |
|------------|--------|-------------|---------|
| **Push-based** (fully async) | cto.new, Cursor, Codex, Copilot, Sentry, Cyrus | Agent server receives Linear webhook on delegation. Agent processes autonomously. | Minutes to hours |
| **Hybrid** (push for intents, pull for implementation) | Claude (`dd0797a4`) | Webhook receiver handles `@mention`/`delegateId` for status/expand/help intents. Full implementation requires Claude Code session. | Seconds (intents), next session (implementation) |

**Implication for Claude's agent:** Claude now has a webhook receiver (`/api/agent-session` on the alteri deployment) that converts push events to async GitHub Actions runs. The pipeline: Linear webhook → Vercel Edge → intent parsing → GitHub Actions `workflow_dispatch` → handler execution → Linear response activity. This makes Claude push-based for `@mention` and `delegateId` events.

#### Agent Handoff Patterns

Two complementary primitives enable agent-to-agent handoff in Linear. Use them together for the hybrid pattern.

##### Primary: `delegateId` Handoff

Transfers active ownership of an issue from one agent to another.

```
Agent A completes work
  → issueUpdate(delegateId: agentBId)
    → Linear creates AgentSessionEvent for Agent B
      → Agent B receives webhook, reads promptContext, starts work
```

**Effect:** Agent B becomes the active delegate. Agent A's session is implicitly complete. Linear UI shows the delegation in the activity trail.

**When to use:** Sequential pipeline stages. Spec-author → reviewer → implementer → closer.

##### Secondary: `@mention` Notification

Parallel notification without transferring ownership.

```
Agent A posts comment with @agentB
  → Linear creates AgentSessionEvent for Agent B
    → Agent B receives webhook, responds independently
```

**Effect:** Agent B gets notified but ownership stays with Agent A. Useful for fan-out.

**Constraint:** Max 1 app user `@mention` per comment. Multiple mentions require multiple comments.

**When to use:** Parallel notifications (e.g., notify reviewer while implementer continues). Heads-up alerts.

##### Hybrid Pattern

Combine both for the CCC agent pipeline:

```
spec-author completes spec
  → delegateId to reviewer (primary — transfers ownership)
  → @mention to Codex (secondary — heads-up to prepare code review)

reviewer completes review
  → delegateId to implementer (primary)

implementer completes work
  → delegateId to closer (primary)
```

##### Intent Taxonomy

When Claude receives a webhook (via `@mention` or `delegateId`), the comment text is parsed into intents:

| Intent | Keywords | Handler | Output |
|--------|----------|---------|--------|
| **status** | `status`, `update`, `progress`, `where are we`, `how is` | `handleStatus` | Sub-issues table, linked PRs, recent activity |
| **expand** | `expand`, `spec`, `flesh`, `elaborate`, `detail`, `break down` | `handleExpand` | Acceptance criteria, edge cases, tech considerations |
| **help** | `help`, `what can you do`, `commands`, `capabilities` | `handleHelp` | Available intents and usage examples |
| **unknown** | _(fallback)_ | `handleHelp` | Same as help |

##### Architecture

```
Linear (webhook POST)
  → Vercel Edge (/api/agent-session)
    → Signature verification
    → Intent parsing
    → Ack thought (ephemeral, <5s)
    → GitHub Actions workflow_dispatch
      → Handler execution (status/expand/help)
      → Linear GraphQL: post response activity
```

The Edge function returns 200 within 5 seconds (Linear's deadline). Heavy work runs async in GitHub Actions.

#### Dispatch by CCC Stage

| CCC Stage | Dispatch Action | Expected Agent Output |
|-----------|----------------|----------------------|
| Stage 0 (Intake) | Delegate intake issue to cto.new | Plan comment or spec draft PR |
| Stage 4 (Review) | Delegate spec issue to Codex or cto.new | Review findings as comment (normalize via RDR protocol) |
| Stage 5-6 (Implement) | Delegate implementation issue to Cursor, cto.new, or Copilot | PR with implementation |
| Stage 7 (Verify) | Sentry auto-creates issues from errors | Error issue linked to deploy |

#### Agent Guidance Configuration

Linear supports workspace-level and team-level agent guidance — markdown instructions that agents receive when they work on issues. Configure at:

- **Workspace level:** Settings > Agents > Additional guidance
- **Team level:** Team settings > Agents > Additional guidance

Recommended workspace guidance for CCC:

```markdown
## CCC Workflow Context

This workspace uses Claude Command Centre. Issues follow a funnel:
Stage 0 (Intake) → 1-3 (Spec) → 4 (Review) → 5-6 (Implement) → 7 (Verify) → 7.5 (Close)

When working on an issue:
- Read the full description and all comments before acting
- Check labels for execution mode (exec:quick, exec:tdd, etc.)
- Post findings as structured comments, not inline edits
- Do not close or transition issues — only the primary assignee does that
- Branch naming: use your agent prefix (e.g., cursor/, copilot/) followed by the issue identifier
```

#### Context Files by Agent

| Agent | Reads From Repo | File to Create | Content |
|-------|----------------|---------------|---------|
| Codex | `AGENTS.md` | `AGENTS.md` at repo root | Repo structure, coding conventions, test commands |
| Cursor | `.cursor/rules/` | `.cursor/rules/*.mdc` | Project-specific rules |
| Claude Code | `CLAUDE.md` | `CLAUDE.md` at repo root | Already exists in CCC repos |
| cto.new | Issue description only | None needed | All context via Linear issue |
| Copilot | Repo files (automatic) | None needed | Uses repo context automatically |

**Key distinction:** These repo-level files are for **local editor usage** (when the agent runs inside an IDE on your machine). For **Linear dispatch** (when the agent receives work via Linear assignment), all context comes from the issue description and comments. Repo-level files are a bonus — not a requirement.

#### Agent Routing by Execution Mode

When selecting an agent for a task, first determine the execution mode (see **execution-modes** skill), then use this table to choose an agent:

| Exec Mode | Default Agent | Optional Accelerators | Notes |
|-----------|---------------|----------------------|-------|
| `exec:quick` | Claude Code | **cto.new** (free, ~5 min), Codex ($20/mo), GitHub Copilot (free) | cto.new recommended for async dispatch; Copilot for GitHub-native batch |
| `exec:tdd` | Claude Code | **Cyrus** (self-verification, ~5 min), **Cursor** ($20/mo) | Cyrus validated for delegation pipeline (CIA-463); Cursor for IDE pairing |
| `exec:pair` | Claude Code | Cursor (IDE pairing), Cyrus (async pairing) | Claude Code for interactive; Cursor for IDE context; Cyrus for fully async |
| `exec:checkpoint` | Claude Code | — | Human-gated; no agent substitution appropriate |
| `exec:swarm` | Claude Code | **Tembo** (adopted — multi-agent orchestrator), **Copilot Agent** (label-based dispatch) | Tembo for cross-agent/cross-repo orchestration (default); Copilot Agent for GitHub-native parallel dispatch |

**Claude hybrid model:** Claude Code (`dd0797a4`) handles interactive pair-programming and spec workflow (CCC skills). For background implementation, **Tembo** is the default executor — dispatched via Linear delegation or `mcp__tembo__create_task`. The webhook receiver (GitHub Actions) remains available for intent-based responses but is secondary to Tembo for implementation tasks.

#### Agent Selection Decision Tree

```
Is this an exec:quick task with clear acceptance criteria?
|
+-- YES --> Is latency critical (< 10 min)?
|           |
|           +-- YES --> cto.new (free, async) or Cyrus (~5 min validated)
|           +-- NO  --> cto.new (free) > Copilot (free) > Claude Code (default)
|
+-- NO --> Is this exec:tdd?
|          |
|          +-- YES --> Cyrus (self-verification + async) or Cursor (IDE pairing)
|          |
|          +-- NO --> Is this exec:swarm (batch/parallel)?
|                     |
|                     +-- YES --> **Tembo** (default, adopted) or Copilot Agent (label-based)
|                     +-- NO  --> Claude Code (default for pair/checkpoint)
|
Is this Stage 4 (code review)?
|
+-- YES --> Codex (structured P1/P2 findings) + Claude persona panel (spec review)
```

#### Free Tier Bundle

For CCC's student-friendly zero-cost tier, only these agents are viable:

- **Claude Code** (via Claude Max or API)
- **cto.new** (free, no credit card)
- **GitHub Copilot** (free tier available)
- **Cyrus Community** (free, but requires Anthropic API key — BYOK cost)

All other agents require paid subscriptions. The free tier bundle provides full CCC stage coverage (0-7.5) without any paid agent dependencies.

#### Model-per-Role Architecture

Agents that support model selection should be configured with the optimal model for their role. This reduces cost while maintaining quality (see RouteLLM, arXiv:2406.18510).

**Available model access:**
- **Direct subscriptions:** Claude Max (Opus, Sonnet, Haiku), OpenAI (Codex CLI), GitHub Copilot (free), Cursor Pro (Cloud Agents)
- **OpenRouter (credits-based):** DeepSeek, Gemini, Grok (xAI), Perplexity — available via **Codex CLI** custom endpoint only (not Cursor Cloud Agents)
- **Free hosted:** cto.new (Anthropic/OpenAI/Google, no API key), Copilot Agent (GitHub-hosted)
- **Platform-specific:** NotebookLM (Gemini Pro), Google AI Studio (Gemini), Perplexity (search-augmented)

| Agent | Model Options | Recommended Default | BYOK/OpenRouter? |
|-------|-------------|-------------------|-----------------|
| cto.new | Anthropic, OpenAI, Google | Sonnet (fast + free) | No (free hosted) |
| GitHub Copilot Agent | Claude Sonnet/Opus, GPT-5.x, Auto | Auto | No |
| Codex CLI | 10+ OpenAI models + any API | gpt-5.3-codex | Yes — can point at OpenRouter |
| Cursor Cloud Agents | Codex 5.3, GPT-5.2, Opus 4.6, Sonnet 4.5, Composer 1.5 | Auto (or Opus for quality) | No — fixed model list, no BYOK/OpenRouter |
| Cyrus | Claude Code (BYOK) | Opus (for self-verification quality) | Yes (Anthropic key) |
| Devin | Locked (currently Sonnet) | N/A (no control) | No |
| Claude Code | Opus, Sonnet, Haiku | Opus | Yes (API key) |

**Role-to-model mapping:**

| Role | Recommended Model | Why |
|------|------------------|-----|
| Spec authoring, adversarial review | Claude Opus | Deepest reasoning for complex analysis |
| Quick implementation (cto.new) | Claude Sonnet | Fast enough for well-scoped tasks |
| TDD implementation (Cyrus) | Claude Opus | Self-verification loop needs strong reasoning |
| Async implementation (Cursor) | Auto (Cursor-managed) | Cloud Agents selects from fixed model list — no BYOK/OpenRouter |
| PR code review (Codex) | GPT-5.x Codex | Code-specialized model for structured review |
| Batch coding (Codex CLI) | DeepSeek (OpenRouter) | ~10x cheaper than Opus, competitive code quality. Codex CLI supports custom endpoints. |
| Fast iteration/linting | Gemini Flash (Codex CLI via OpenRouter) | Cheapest + fastest option via Codex CLI custom endpoint |
| Research synthesis | Gemini Pro (NotebookLM/AI Studio) | 1M context, Deep Research, audio overviews |
| Research grounding | Perplexity (OpenRouter) | Search-augmented generation for fact-checking |

**OpenRouter integration points:**

| Agent | Config Method | Best OpenRouter Models |
|-------|--------------|----------------------|
| Cursor Cloud Agents | N/A — fixed model list, no BYOK/OpenRouter | N/A (Cursor IDE supports BYOK but NOT in agent mode) |
| Codex CLI | `config.toml` → custom endpoint | DeepSeek (batch), Perplexity (research) |
| Cyrus | N/A — keep on Opus via Anthropic key | Self-verification quality requires Opus |

> **Important distinction:** "Cursor" in CCC context means Cursor Cloud Agents (push-based, Linear delegation, async). Cursor IDE (local, pull-based, interactive) supports BYOK but NOT in agent mode. OpenRouter models are available through Codex CLI only for automated agent dispatch.

#### Agent Performance Benchmarks

Performance data collected from real delegations. Updated after each agent task.
Full log: [Agent Performance Log](https://linear.app/cianclaude/document/agent-performance-log-ac5691c461f5)

**PR Quality Rubric (0-5):** 0=No PR | 1=Wrong branch/empty | 2=Correct branch, body incomplete | 3=Adequate | 4=Well-documented, tests pass | 5=Comprehensive, self-verified, no revisions

##### Observed Latency

| Agent | Task Type | Avg Time-to-PR | Sample Size | Last Updated |
|-------|-----------|----------------|-------------|-------------|
| Cyrus (Pro) | exec:quick (trivial) | ~5 min | 1 | 2026-02-16 |
| cto.new | — | No data | 0 | — |
| Codex | — | No data | 0 | — |
| Copilot Agent | — | No data | 0 | — |
| Tembo (Pro) | exec:quick (trivial) | ~2 min | 2 | 2026-02-17 |

##### Quality Summary

| Agent | Avg PR Quality (0-5) | Avg Revisions | Sample Size |
|-------|---------------------|---------------|-------------|
| Cyrus (Pro) | 2.0 | 0 | 1 |
| Tembo (Pro) | 3.5 | 0 | 2 (CIA-459 spike: CONNECTORS.md update + CIA-507) |

##### Dispatch Latency Guidance

When selecting an agent, consider latency requirements:
- **< 5 min needed:** Tembo (~2 min observed), Cyrus (~5 min observed), cto.new (expected similar)
- **< 1 hour OK:** Cursor, Codex, Copilot (push-based, variable)
- **Next session OK:** Claude (pull-based, session-required)

**Tembo credit cost guidance:** ~1 credit/trivial task, 1-3/small fix, 3-8/feature, 8-15+/complex refactor. Each `/tembo` PR feedback round = 1-3 additional credits. Budget: 100 credits/month on Pro ($60/mo). BYOK = Enterprise-only.

#### Agent Configuration Status

Tracks per-agent setup progress. Updated as agents are configured and tested.

| Agent | Linear | GitHub | Settings | Status | Blocking |
|-------|--------|--------|----------|--------|----------|
| Claude | OAuth app (`dd0797a4`) | N/A | MCP configured | Active | — |
| Cyrus | App user (Feb 16) | `cyrusagent[bot]` | Partial | Validated (CIA-463) | CIA-464 (non-trivial test) |
| Cursor | App user (Feb 9) | — | Needs default model + repo | Pending config | Select default model + default repo in Cloud Agents dashboard |
| Codex | App user (Feb 15) | — | Needs repo config | Pending config | Verify repo access |
| Copilot | App user (Feb 14) | GitHub App (auto) | Needs Coding Agent enabled | Pending config | Enable on target repos |
| cto.new | OAuth authorized (not App user) | — | Blocked | **Needs cto.new-side setup** | Connect from cto.new dashboard |
| Sentry | App user (Feb 9) | — | Partial | Active (monitoring) | Verify issue creation |
| ChatPRD | App user (Jan 15) | N/A | Default | Low priority | Re-evaluate later |
| Tembo | App user (Feb 16) | GitHub (3 repos) | MCP installed, Pro ($60/mo, 100 credits), Linear + Sentry + Supabase integrations | **Adopted (Pro tier)** | CIA-459 spike complete. Default background executor. Superseded 31pt pipeline (CIA-484–490). |
| Devin | App user (Feb 16) | — | Default | Deferred | $20/mo evaluation |
| Vercel Agent | N/A (GitHub-native) | Vercel GitHub App | OFF (Hobby, out of credit) | Deferred | Pro ($20/mo) + Observability Plus ($10/mo). Revisit when deploying to Vercel. |

#### Feedback Reconciliation Protocol

When two or more agents produce outputs for related issues (e.g., parallel PRs, overlapping reviews), reconcile as follows:

1. **Same issue, multiple agents:** Should not happen — assign exactly one agent per issue. If it does, the later agent's output is advisory only; the primary assignee's output is canonical.
2. **Related issues, different agents:** Human reviews both outputs. If they conflict:
   - Document both approaches in a Linear comment on the parent issue
   - Choose one approach; do not merge conflicting strategies
   - Close the rejected approach's PR with an explanatory comment
3. **Review findings from multiple agents:** Normalize all findings into RDR format (see **adversarial-review** skill, Finding Normalization Protocol). Apply the 2/3 agreement threshold for inclusion, 3/3 for critical findings.

#### Dispatch Issue Template

When delegating an issue to an external agent via Linear, ensure the issue description contains all context the agent needs (external agents do not read CCC skill files):

```markdown
## Context
{Brief description of the task and its purpose}

## Acceptance Criteria
- [ ] {Specific, testable criterion 1}
- [ ] {Specific, testable criterion 2}

## Constraints
- Branch: `{agent-prefix}/{issue-id}-{slug}`
- Do not modify: {list protected files/directories}
- Test command: `{how to verify}`

## References
- Spec: {link to spec document or parent issue}
- Related PRs: {links to any related open PRs}
```

---

## Decided Observability Stack

For teams that want an opinionated starting point, this is the stack validated through real CCC projects. Each tool fills a distinct role — avoid overlap by following the stage mapping.

| Tool | Role | CCC Stage | When to Use |
|------|------|-----------|-------------|
| **PostHog** | Product analytics, feature flags, session replays | Stage 2 (analytics review) + Stage 7 (behavior verification) | Validating that shipped features are actually used. Feature flag rollout during Stage 6. Session replays to debug user-facing issues at Stage 7. |
| **Sentry** | Error tracking, performance monitoring | Stage 7 (error verification) | Monitoring error rates post-deploy. Performance regression detection. Source map integration for actionable stack traces. |
| **Honeycomb** | OTEL traces, distributed tracing | Stage 7 (observability) | Tracing request flows across services. Identifying latency bottlenecks. Custom instrumentation for business-critical paths. |
| **Vercel Analytics** | Web vitals, edge performance | Stage 7 (deployment verification) | Core Web Vitals monitoring. Edge function performance. Real User Monitoring (RUM) for deployment validation. |

### Stage 7 Verification Tool Selection

Not every project needs all four tools. Use this decision heuristic:

| Question | If Yes | If No |
|----------|--------|-------|
| Does the feature have a user-facing UI? | PostHog (analytics) + Vercel Analytics (web vitals) | Skip both |
| Does the feature involve server-side logic? | Sentry (errors) + Honeycomb (traces) | Sentry only (client errors still matter) |
| Is this a multi-service or API-heavy feature? | Honeycomb (distributed tracing) | Sentry performance monitoring is sufficient |
| Is this a feature-flag rollout? | PostHog (flag management + analytics) | Direct deploy |

### Connector-to-Tool Mapping

| Connector Placeholder | Recommended Tool | MCP Available | Fallback |
|----------------------|-----------------|---------------|----------|
| **~~analytics~~** | PostHog | Yes (posthog-mcp) | API key + client SDK |
| **~~error-tracking~~** | Sentry | Yes (sentry-mcp) | DSN + SDK |
| **~~observability~~** | Honeycomb | No (OTEL SDK) | OTEL collector + API key |
| (Web vitals) | Vercel Analytics | Built into Vercel deployment | N/A — deployment platform native |

### Three-Layer Monitoring Stack

Plugin health itself operates at three layers. See the `observability-patterns` skill for full details.

| Layer | Tool | Scope | When |
|-------|------|-------|------|
| **Structural validation** | cc-plugin-eval | Plugin components trigger correctly | Pre-release, CI |
| **Runtime observability** | /insights | Session tool usage, friction | Post-session |
| **App-level analytics** | PostHog/Sentry/Honeycomb | User behavior, errors, performance | Continuous |

---

## Research Connector Stack

For specs grounded in literature, competitive analysis, or ML/data science, this 6-MCP stack provides comprehensive research coverage across Stages 1-2. Firecrawl handles public web; the academic MCPs handle scholarly sources; HuggingFace and Kaggle handle ML assets.

### Pipeline Overview

```
Discovery:  Semantic Scholar / arXiv / OpenAlex  →  papers, citations, trends
Assets:     HuggingFace / Kaggle                 →  models, datasets, code
Storage:    Zotero                                →  annotate, tag, semantic search
Public Web: Firecrawl                             →  scrape, search, extract, map
```

### MCP Server Reference

| MCP Server | Connector Placeholder | npm Package / Source | Purpose | Auth |
|------------|----------------------|---------------------|---------|------|
| **Semantic Scholar** | ~~academic-search~~ | `@xbghc/semanticscholar-mcp` | 200M+ papers, citation graphs, author profiles, recommendations | None (rate-limited) |
| **arXiv** | ~~academic-search~~ | `arxiv-mcp-server` | Preprint search, PDF download, category filtering | None |
| **OpenAlex** | ~~academic-search~~ | `openalex-research-mcp` | 240M+ works, institutions, venues, funders, OA links | None (email for polite pool) |
| **Zotero** | ~~research-library~~ | `zotero-mcp` | Personal library, annotations, semantic search, collections | API key |
| **HuggingFace** | ~~model-registry~~ | `huggingface-mcp-server` | Models, datasets, Spaces, papers, collections | API token |
| **Kaggle** | ~~model-registry~~ | `kaggle-mcp` | Datasets, competitions, model search | API token |

### Integration Patterns by Stage

#### Stage 1: Research Grounding

Use academic MCPs to ground specs in existing literature. The workflow follows a discovery-then-storage pattern:

1. **Discover** — Search Semantic Scholar, arXiv, or OpenAlex for relevant papers
2. **Evaluate** — Check citation counts, recency, relevance to spec scope
3. **Store** — Add to Zotero library with tags matching Linear labels (`research:needs-grounding`, etc.)
4. **Cite** — Reference papers in spec's Research Base section (minimum 3 for `literature-mapped`)

**Which search tool when:**

| Need | Tool | Why |
|------|------|-----|
| Broad topic search | Semantic Scholar `search_papers` | Best relevance ranking, field-of-study filtering |
| Latest preprints | arXiv `search_papers` | Real-time index, category filtering (cs.AI, cs.SE, etc.) |
| Citation analysis | OpenAlex `get_citation_network` | Forward + backward citation in one call |
| Author lookup | Semantic Scholar `get_author` + `get_author_papers` | Richest author profiles |
| Top cited works | OpenAlex `get_top_cited_works` | Built-in citation threshold filtering |
| Trend analysis | OpenAlex `analyze_topic_trends` | Year-over-year publication volume |
| Related papers | Semantic Scholar `get_recommendations` | Positive/negative paper seeding |
| Institutional research | OpenAlex `search_institutions` | Country, type, output filters |

#### Stage 2: Analytics Review & Competitive Analysis

Use HuggingFace and Kaggle for ML/data grounding. Use Firecrawl for competitive landscape.

**ML/Data grounding:**
- HuggingFace `model_search` — find SOTA models for the problem domain
- HuggingFace `paper_search` — semantic search across ML papers
- HuggingFace `dataset_search` — find training/evaluation datasets
- Kaggle `prepare_kaggle_dataset` — download competition datasets for benchmarking

**Competitive landscape (via Firecrawl):**
- Search competitor documentation sites
- Extract feature matrices from comparison pages
- Monitor changelog/release pages for new features

### Firecrawl Integration Patterns

Firecrawl is the primary ~~web-research~~ connector for public web data. It offers four operations, each suited to different research needs.

#### Operations

| Operation | When to Use | Token Cost | Example |
|-----------|------------|------------|---------|
| **search** | Finding relevant pages across the web | Low | `firecrawl_search("AI PM tools comparison 2026")` |
| **scrape** | Extracting content from a known URL | Medium | `firecrawl_scrape("https://example.com/docs/api")` |
| **extract** | Pulling structured data from pages | Medium | `firecrawl_extract(urls, schema={name, price, features})` |
| **map** | Discovering all URLs on a site before scraping | Low | `firecrawl_map("https://docs.example.com")` |

#### Discipline Rules

These rules prevent token waste, credit exhaustion, and context bloat:

1. **Prefer `WebFetch` for single-page reads.** Only use Firecrawl when you need search, batch scrape, structured extraction, or site mapping. `WebFetch` is free and sufficient for one-off page reads.
2. **Always set `onlyMainContent: true`.** Strips navbars, footers, and sidebars. Reduces token cost by 30-60%.
3. **Always set `formats: ["markdown"]`.** Never request `html` or `rawHtml` unless explicitly needed for extraction.
4. **Always set `removeBase64Images: true`.** Prevents base64-encoded images from consuming context.
5. **Search first, scrape selectively.** Use `firecrawl_search` without `scrapeOptions` to find relevant URLs, then `firecrawl_scrape` only the pages you need.
6. **Limit crawl depth.** When using `firecrawl_crawl`, set `limit: 20` max and `maxDiscoveryDepth: 2` to prevent token overflow.
7. **Cache with `maxAge`.** Set `maxAge: 172800000` (48h) for documentation pages that don't change frequently. 500% faster on cache hits.
8. **Delegate to subagent.** All Firecrawl results should be processed by a Task subagent, never pasted into the main context. Subagent summarizes in 2-3 bullets.

#### `.mcp.json` Fragment (Reference Only)

The following is a **reference configuration** — merge it into your global `~/.mcp.json`, do not place it in the repo root (Claude Code treats repo-level `.mcp.json` as active project config, which can conflict with your global MCPs):

```json
{
  "mcpServers": {
    "semanticscholar": {
      "command": "npx",
      "args": ["-y", "@xbghc/semanticscholar-mcp@latest"]
    },
    "arxiv": {
      "command": "npx",
      "args": ["-y", "arxiv-mcp-server@latest"]
    },
    "openalex": {
      "command": "npx",
      "args": ["-y", "openalex-research-mcp@latest"]
    },
    "zotero": {
      "command": "npx",
      "args": ["-y", "zotero-mcp@latest"],
      "env": {
        "ZOTERO_API_KEY": "${ZOTERO_API_KEY}",
        "ZOTERO_USER_ID": "${ZOTERO_USER_ID}"
      }
    },
    "huggingface": {
      "command": "npx",
      "args": ["-y", "huggingface-mcp-server@latest"],
      "env": {
        "HF_TOKEN": "${HF_TOKEN}"
      }
    },
    "kaggle": {
      "command": "npx",
      "args": ["-y", "kaggle-mcp@latest"],
      "env": {
        "KAGGLE_USERNAME": "${KAGGLE_USERNAME}",
        "KAGGLE_KEY": "${KAGGLE_KEY}"
      }
    }
  }
}
```

### Social Media MCPs: Evaluation

These were evaluated as optional ~~community-signal~~ connectors for Stage 1-2 research intake diversification.

| MCP | Verdict | Rationale |
|-----|---------|-----------|
| **Composio** | **REJECT** | Infrastructure overkill. Full integration platform (1000+ APIs) with cloud dependencies and OAuth complexity. Firecrawl already covers web scraping; no Stage 1-2 gap justifies the overhead. |
| **LinkedIn** | **DEFER** | Useful for competitive analysis (PM tool launches, hiring signals) but all implementations rely on unofficial scraping APIs — fragile and ToS-risky. Firecrawl + targeted web searches suffice. Revisit if user friction emerges around LinkedIn-specific research. |
| **YouTube** (`@kirbah/mcp-youtube`) | **ACCEPT (conditional)** | Fills Stage 1-2 gap for developer tutorial/demo analysis — transcripts reveal competitive features that text docs miss. Uses official YouTube Data API v3 (reliable). Install only if video content analysis is needed for your domain. |
| **Hacker News** (`mcp-hacker-news`) | **ACCEPT (conditional)** | Fills Stage 1-2 gap for developer community sentiment — Show HN posts, Ask HN threads, launch discussions. Uses official HN Firebase API (stable). Low cost signal for competitive landscape and early validation. |

**Guidance:** YouTube and Hacker News are accepted as *conditional* connectors — install them when your research grounding benefits from community signal. They are not required for core CCC functionality. Add to the `~~community-signal~~` placeholder in `.mcp.json` when needed.

### Enterprise-Search Compatibility

Anthropic's [`enterprise-search`](https://github.com/anthropics/knowledge-work-plugins/tree/main/enterprise-search) plugin provides `/search` and `/digest` commands with 3 skills (Search Strategy, Source Management, Knowledge Synthesis) for discovering knowledge across internal tools (Slack, MS 365, Notion/Guru, Atlassian, Asana).

**Overlap assessment:** No functional overlap. Enterprise-search addresses *internal knowledge discovery* (chat, email, docs, wikis). CCC's research connectors address *public web and academic* data gathering. The two are complementary.

**Combined coverage:**

| Data Source | CCC Connector | Enterprise-Search |
|-------------|--------------|-------------------|
| Academic papers | S2, arXiv, OpenAlex | -- |
| ML models/datasets | HuggingFace, Kaggle | -- |
| Personal library | Zotero | -- |
| Public web | Firecrawl | -- |
| Internal chat (Slack, Teams) | -- | Slack connector |
| Internal docs (Notion, Confluence) | -- | Atlassian, Notion/Guru connectors |
| Email (Outlook, Gmail) | -- | MS 365 connector |
| Project management (Asana, Jira) | -- | Asana, Atlassian connectors |

**Integration opportunities for teams using both:**
- Enterprise-search could serve as a Stage 1-2 research source for teams with internal knowledge bases (e.g., searching prior specs, design docs, Slack discussions about similar features)
- Enterprise-search's `/digest` (daily/weekly activity rollup) could inform Stage 2 analytics review
- Enterprise-search's Knowledge Synthesis skill (cross-source dedup, confidence scoring) could enhance adversarial review methodology

**No action required** to use both plugins — they operate on different connector categories and do not conflict. Teams adopting enterprise-search alongside CCC get complete research coverage: public + academic + internal.

---

## Customization

Replace `~~placeholder~~` values with your team's specific tools. The plugin's methodology is tool-agnostic -- it works with any project tracker, version control system, or CI/CD platform that has MCP support.

To customize, update the server URLs in your global `~/.mcp.json` to match your organization's tools.

---

## Tool-to-Funnel Reference

How each connector maps to the 9-stage funnel:

| Funnel Stage | Required Connectors | Recommended | Optional | Agent Accelerators |
|---|---|---|---|---|
| Stage 0: Intake | project-tracker | -- | communication | cto.new, ChatPRD |
| Stage 1: Research Grounding | project-tracker | -- | academic-search (S2, arXiv, OpenAlex), research-library (Zotero), web-research (Firecrawl) | -- |
| Stage 2: Analytics Review | project-tracker | analytics | model-registry (HuggingFace, Kaggle), web-research (Firecrawl), community-signal (HN, YouTube) | -- |
| Stage 3: PR/FAQ Draft | project-tracker, version-control | -- | -- | -- |
| Stage 4: Adversarial Review | version-control | ci-cd | -- | Codex (PR review) |
| Stage 5: Visual Prototype | -- | deployment, component-gen | design | cto.new |
| Stage 6: Implementation | version-control | ci-cd, email-marketing | geolocation | cto.new, Cursor, Copilot, Cyrus |
| Stage 7: Verification | version-control | deployment, analytics, error-tracking, email-marketing | observability | Sentry, Codex |
| Stage 7.5: Closure | project-tracker | -- | -- | -- |
| Stage 8: Handoff | project-tracker | -- | communication | -- |

---

## Platform Configuration Checklist

When setting up your tools, verify these key settings. Misconfiguration here causes the most common integration failures.

### Version Control (GitHub example)

| Setting Area | Key Settings | Why It Matters |
|---|---|---|
| **Branches** | Default branch protection, required reviews | Gates for Stage 4 (adversarial review) and Stage 6 (PR review) |
| **Actions** | Workflow permissions, allowed actions | Enables Options A/C for adversarial review |
| **Copilot** | Code review rules, memory | Automated review quality in Option A |
| **Webhooks** | Linear sync, deployment triggers | Bidirectional issue tracking |
| **Environments** | Preview, production with required reviewers | Stage 7 deployment gates |

### Deployment Platform (Vercel example)

| Setting Area | Key Settings | Why It Matters |
|---|---|---|
| **Git integration** | PR comments, commit comments, verified commits | Stage 5 preview feedback loop |
| **Environment variables** | Separate preview/production secrets | Stage 7 verification accuracy |
| **Deployment protection** | Preview protection, production gates | Prevents premature production deployments |
| **Build settings** | Framework detection, output directory | Reliable Stage 7 deploys |

---

## Integration Wiring Guide

### Credential Storage Patterns

Choose the approach that matches your team size:

| Approach | Best For | Setup | Rotation |
|---|---|---|---|
| **OS Keychain** (macOS Keychain, Linux Secret Service) | Solo developer | `security add-generic-password` per key | Manual per key |
| **Secrets Manager** (Doppler, 1Password CLI, Vault) | Teams, multi-environment | Central config, CLI sync to local | One rotation propagates everywhere |
| **Environment files** (.env with .gitignore) | Quick prototyping only | Create `.env`, add to `.gitignore` | Manual, easy to forget |

**Recommendation:** Start with OS Keychain. Migrate to a secrets manager when you need multi-environment sync or team access.

### Bidirectional Sync Patterns

Common integration pairs and how to wire them:

| Integration | Direction | What Syncs | Setup |
|---|---|---|---|
| **Project tracker <-> Version control** | Bidirectional | Issue references in PRs, PR links in issues | Native integration (e.g., Linear-GitHub sync) |
| **Error tracking <-> Deployment** | Error tracking -> Deployment | Release tagging, source map upload | Marketplace integration (e.g., Sentry-Vercel) |
| **Error tracking <-> Project tracker** | Error tracking -> Project tracker | Auto-create issues from new error groups | Native integration (e.g., Sentry-Linear) |
| **Analytics <-> Project tracker** | Manual | Feature flag data informs spec drafting | No direct sync -- analyst reviews data during Stage 2 |
| **Deployment <-> Project tracker** | Manual or webhook | Preview URLs in issue comments, deploy status | Branch naming convention `claude/cia-XXX-*` + Linear-GitHub sync propagates PR links. No native Linear-Vercel integration -- add preview URLs manually or via webhook. |
| **Email marketing <-> Database** | Application -> Both | Dual-write: subscriber data to both email platform and database | API route writes to database first (source of truth), then syncs to email platform. Idempotent PUT to avoid duplicates. |

### Environment Variable Matrix

Track where each credential lives across environments:

| Variable | Local | Preview | Production | CI |
|---|---|---|---|---|
| Project tracker API token | Keychain | N/A (MCP only) | N/A | GitHub Secret |
| Version control token | Git config | N/A | N/A | Automatic |
| Deployment platform token | Keychain | Automatic | Automatic | GitHub Secret |
| Error tracking DSN | Keychain | Platform env var | Platform env var | GitHub Secret |
| Analytics key | Keychain | Platform env var | Platform env var | N/A |

### Runtime vs Agent Credentials

Some integrations require two separate credentials: one for the AI agent's MCP operations during development, and one for the application's own API calls at runtime.

| Integration | Agent Credential | Application Credential | Why Separate |
|---|---|---|---|
| **Project tracker** | MCP OAuth token (agent session, scoped to agent identity) | API key (runtime issue creation from user-facing forms) | Agent token has agent-specific scopes and identity. Application needs programmatic access without MCP. |
| **Deployment** | Git integration (automatic via branch push) | API token (if needed for programmatic deploys) | Usually automatic via Git. Some workflows need explicit API access for status checks. |
| **Analytics** | MCP tool (if available) | Client-side snippet or API key | Agent reads analytics during Stage 2. Application writes events at runtime. Different access patterns. |

**Rule of thumb:** If your application creates, reads, or modifies data in a connected service at runtime (not just during development), it needs its own credential separate from the MCP token.

### Credential Anti-Patterns

Common mistakes observed in real projects:

| Anti-Pattern | Risk | Fix |
|---|---|---|
| Blank secrets in `.env.local` (e.g., `SERVICE_ROLE_KEY=`) | Exposes variable name, signals to attackers that the key exists somewhere | Remove unused variables entirely |
| Unrestricted API keys (no HTTP referrer or IP restriction) | Key can be used from any origin if leaked from client-side bundle | Always set restrictions in the provider's console (Google Cloud, Mapbox, etc.) |
| `NEXT_PUBLIC_` prefix on server-only keys | Exposes key in client-side JavaScript bundles | Remove `NEXT_PUBLIC_` prefix; access only in API routes or server components |
| Same credential for agent and application | Scope creep -- agent token may have higher privileges than the app needs | Separate credentials with minimum-privilege scoping |
| Secrets in `.env` committed to version control | Full credential exposure in git history | Use `.env.local` (auto-gitignored by Next.js) or `.env` with explicit `.gitignore` entry |

---

## Secrets Management

### Decision Framework

| Factor | OS Keychain | Secrets Manager |
|---|---|---|
| Team size | 1 developer | 2+ developers |
| Environments | 1-2 (local + prod) | 3+ (local, preview, staging, prod) |
| Rotation frequency | Quarterly or less | Monthly or more |
| Audit requirements | None | Compliance/SOC2 |
| Cost | Free | Free tier available (Doppler, 1Password) |
| Migration effort from Keychain | N/A | ~1 hour per 20 keys |

### Migration Path

If you start with OS Keychain and later need a secrets manager:

1. Export current keys: `security dump-keychain` (filtered to your service prefix)
2. Import to secrets manager (most support bulk import)
3. Update CI/CD to pull from secrets manager instead of GitHub Secrets
4. Update local shell config to use secrets manager CLI
5. Verify all environments still work
6. Remove old Keychain entries

---

## Real-World Example: Distributor Finder App

A Next.js App Router application with Supabase (database), Google Maps (interactive map), and Vercel (deployment). Solo developer using the CCC funnel with `exec:checkpoint` mode.

### Connectors Actually Used

| Connector | Tool | Stages | Notes |
|---|---|---|---|
| project-tracker | Linear MCP | 0, 6, 7.5 | Issue tracking with `source:*` labels |
| version-control | GitHub MCP | 6 | Feature branch per issue, PR on completion |
| deployment | Vercel (Git integration) | 5, 7 | Auto-preview on push, manual production promote |
| ci-cd | GitHub Actions | 7 | Typecheck, lint, build, test on PR to main |
| web-research | Firecrawl | 1 | Server-side product data scraping |
| analytics | Vercel Analytics | (passive) | Installed but not actively reviewed at Stage 2 |

### Environment Variable Matrix

| Variable | Local (.env.local) | Vercel Preview | Vercel Production | CI (GitHub) |
|---|---|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | `.env.local` | Vercel env var | Vercel env var | N/A (not needed) |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | `.env.local` | Vercel env var | Vercel env var | N/A |
| `NEXT_PUBLIC_GOOGLE_MAPS_API_KEY` | `.env.local` | Vercel env var | Vercel env var | N/A |
| `FIRECRAWL_API_KEY` | `.env.local` | Not set (server-side scraping is local-only) | Not set | N/A |

### Findings

**What worked:** Adversarial review (Stage 4) produced 4 Critical + 13 Important + 8 Consider findings. Fix-forward pattern resolved all Critical items before advancing. Checkpoint execution mode with documented phase gates worked well for multi-phase UI overhaul.

**What was missing:** No error tracking configured (most small apps skip this). Stage 5 was skipped entirely for UI fix/refactor work (not creating new UI). No anchor/drift protocol existed to rebuild context between sessions. Credential anti-patterns found: blank service role key, unrestricted Google Maps API key.

**Connector gaps exposed:** Email marketing (Mailchimp for mailing list), geolocation (region inference for subscriber segmentation), and runtime vs agent credentials (application needs its own Linear API key for user-facing feedback forms, separate from MCP OAuth).

---

## Tembo Integration

> Status: **Evaluating** (CIA-459 spike)

Tembo is being evaluated as the agent orchestration layer for background task execution. If adopted, CCC handles spec/planning/review while Tembo handles sandboxed agent dispatch.

### Integration Points
- CCC `go.md` dispatches background execution tasks to Tembo via MCP
- Tembo runs agent in isolated VM sandbox → PR created
- CCC reviews PR via adversarial review skill

### Decision Pending
- ADOPT: Cancel CIA-484 through CIA-490 (31pt of custom pipeline)
- PASS: Continue with custom webhook pipeline
