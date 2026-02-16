# Connectors

This plugin works best with the following data sources connected. Configure them in `.mcp.json` or through your organization's MCP setup.

## Required

| Connector | Purpose | Funnel Stage | Default |
|-----------|---------|-------------|---------|
| **~~project-tracker~~** | Issue tracking, status transitions, label management | All stages | [Linear](https://mcp.linear.app/mcp) |
| **~~version-control~~** | Pull requests, code review, spec file management | Stages 3-7 | [GitHub](https://api.githubcopilot.com/mcp/) |

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
| **~~communication~~** | Stakeholder notifications, decision tracking | All stages | Slack |
| **~~design~~** | Visual prototyping handoff | Stage 5 | Figma, v0 |
| **~~observability~~** | Traces, metrics, health monitoring | Stage 7 | Honeycomb, Datadog |

## Agent Connectors

External AI agents that integrate with the SDD funnel via ~~project-tracker~~ (Linear) assignment or webhook dispatch. These are optional accelerators — Claude Code remains the primary agent for all stages.

### Adopted Agents

| Agent | SDD Stages | Dispatch Method | Cost | Free Tier Viable |
|-------|-----------|-----------------|------|------------------|
| **cto.new** (Engine Labs) | 0 (intake), 5-6 (implement) | Linear assignment or MCP webhook (`mcp.enginelabs.ai/mcp`) | Free | Yes |
| **Sentry** | 7 (error verification) | Error tracking integration → auto-issue creation | Free tier | Yes |
| **Cursor** | 6 (implement, exec:tdd) | Linear assignment (native integration) | $20/mo (Pro) | No |
| **GitHub Copilot** | 6 (implement, exec:quick) | GitHub Actions label-based auto-assignment | Free tier | Yes |

### Conditional Agents

Adoption depends on budget and specific workflow needs. Not required for core SDD functionality.

| Agent | SDD Stages | Unique Value | Cost | Condition |
|-------|-----------|--------------|------|-----------|
| **Codex** (OpenAI) | 4 (code review), 6-7 | Structured PR code review with P1/P2 findings — no other agent offers this | $20/mo (ChatGPT Plus) | Adopt if GPT diversity + PR review automation is valued |
| **Cyrus** (Ceedar AI) | 6 (exec:tdd, exec:pair) | Git worktree isolation per issue, 3-iteration self-verification loop | Free (BYOK — requires Anthropic API key) | Adopt if Claude consistency + self-verification is valued; accept 3-5x token cost |

### Deferred Agents

| Agent | Role | Why Deferred | Revisit When |
|-------|------|-------------|--------------|
| **Tembo** | Meta-orchestrator (wraps Cursor, Codex, Claude Code) | 1-repo limit on free tier; not validated for SDD workflow | Post-conference evaluation; potential Phase 3 orchestration backend |

### Demoted Agents

| Agent | Originally | Demotion Reason |
|-------|-----------|-----------------|
| **ChatPRD** | Stage 0-3 candidate | Does not support PR/FAQ templates; missing adversarial review and research grounding. Keep connected but do not invest in SDD integration. Optional Stage 0 supplement only. |

### Agent-to-Stage Mapping

| Funnel Stage | Primary Agent | Optional Accelerators |
|---|---|---|
| Stage 0: Intake | Claude (spec-author) | cto.new (plan agent), ChatPRD (optional) |
| Stage 1-3: Ideation → Spec | Claude (spec-author) | — (sole agent) |
| Stage 4: Adversarial Review | Claude (persona panel) | Codex (PR code review) |
| Stage 5: Prototype | Claude (implementer) | cto.new |
| Stage 6: Implementation | Claude Code | cto.new (exec:quick), Cursor (exec:tdd), Copilot (exec:quick), Cyrus (exec:tdd/pair) |
| Stage 7: Verification | Sentry (primary) | Codex (code review), CI/CD |
| Stage 7.5: Closure | Claude (implementer) | — (sole agent) |

### Agent Credential Patterns

Agent credentials are separate from application runtime credentials. Each agent authenticates via its own mechanism:

| Agent | Auth Method | Credential Location |
|-------|------------|-------------------|
| cto.new | Linear OAuth (automatic on enable) | Linear workspace settings |
| Sentry | DSN + Linear integration | Sentry project settings → Linear integration |
| Cursor | Linear OAuth (native) | Cursor settings → Integrations |
| GitHub Copilot | GitHub App (automatic) | Repository settings → Copilot |
| Codex | Linear OAuth (via ChatGPT Plus) | ChatGPT settings → Integrations |
| Cyrus | Anthropic API key (BYOK) | Cyrus config or Linear integration |

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
| **Push-based** (fully async) | cto.new, Cursor, Codex, Copilot, Sentry | Agent server receives Linear webhook on delegation. Agent processes autonomously. | Minutes to hours |
| **Pull-based** (session-required) | Claude (`dd0797a4`) | Claude reads delegated issues when a Claude Code session starts. No webhook server. | Next session start |

**Implication for Claude's agent:** Claude cannot reactively process Linear events without a session. To achieve push-based dispatch for Claude, you would need either:
- A webhook receiver (e.g., n8n workflow, Cloudflare Worker) that receives Linear delegation events and invokes the Claude API
- A polling service that periodically checks for newly delegated issues

Neither is required for the SDD workflow — Claude's pull-based model works well when sessions are frequent. Push-based dispatch is a future enhancement (see CIA-431 Option C).

#### Dispatch by SDD Stage

| SDD Stage | Dispatch Action | Expected Agent Output |
|-----------|----------------|----------------------|
| Stage 0 (Intake) | Delegate intake issue to cto.new | Plan comment or spec draft PR |
| Stage 4 (Review) | Delegate spec issue to Codex or cto.new | Review findings as comment (normalize via RDR protocol) |
| Stage 5-6 (Implement) | Delegate implementation issue to Cursor, cto.new, or Copilot | PR with implementation |
| Stage 7 (Verify) | Sentry auto-creates issues from errors | Error issue linked to deploy |

#### Agent Guidance Configuration

Linear supports workspace-level and team-level agent guidance — markdown instructions that agents receive when they work on issues. Configure at:

- **Workspace level:** Settings > Agents > Additional guidance
- **Team level:** Team settings > Agents > Additional guidance

Recommended workspace guidance for SDD:

```markdown
## SDD Workflow Context

This workspace uses Spec-Driven Development. Issues follow a funnel:
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
| Claude Code | `CLAUDE.md` | `CLAUDE.md` at repo root | Already exists in SDD repos |
| cto.new | Issue description only | None needed | All context via Linear issue |
| Copilot | Repo files (automatic) | None needed | Uses repo context automatically |

**Key distinction:** These repo-level files are for **local editor usage** (when the agent runs inside an IDE on your machine). For **Linear dispatch** (when the agent receives work via Linear assignment), all context comes from the issue description and comments. Repo-level files are a bonus — not a requirement.

---

## Decided Observability Stack

For teams that want an opinionated starting point, this is the stack validated through real SDD projects. Each tool fills a distinct role — avoid overlap by following the stage mapping.

| Tool | Role | SDD Stage | When to Use |
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

## Customization

Replace `~~placeholder~~` values with your team's specific tools. The plugin's methodology is tool-agnostic -- it works with any project tracker, version control system, or CI/CD platform that has MCP support.

To customize, edit `.mcp.json` and update the server URLs to match your organization's tools.

---

## Tool-to-Funnel Reference

How each connector maps to the 9-stage funnel:

| Funnel Stage | Required Connectors | Recommended | Optional | Agent Accelerators |
|---|---|---|---|---|
| Stage 0: Intake | project-tracker | -- | communication | cto.new, ChatPRD |
| Stage 1-2: Ideation + Analytics | project-tracker | analytics | research-library, web-research | -- |
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

A Next.js App Router application with Supabase (database), Google Maps (interactive map), and Vercel (deployment). Solo developer using the SDD funnel with `exec:checkpoint` mode.

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
